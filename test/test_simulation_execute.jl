function get_deserialized(sim::Simulation, stage_info)
    path = mktempdir()
    directory = PSI.serialize(sim; path = path)
    return Simulation(directory, stage_info)
end

function test_load_simulation(file_path::String)

    c_sys5_uc = build_system("c_sys5_uc")
    single_stage_definition =
        Dict("ED" => Stage(GenericOpProblem, template_ed, c_sys5_uc, ipopt_optimizer))

    single_sequence = SimulationSequence(
        step_resolution = Hour(1),
        order = Dict(1 => "ED"),
        horizons = Dict("ED" => 12),
        intervals = Dict("ED" => (Hour(1), Consecutive())),
        ini_cond_chronology = IntraStageChronology(),
    )

    sim_single = Simulation(
        name = "consecutive",
        steps = 2,
        stages = single_stage_definition,
        stages_sequence = single_sequence,
        simulation_folder = file_path,
    )
    build!(sim_single)
    res = execute!(sim_single)

    @testset "Single stage sequential tests" begin
        stage_single = PSI.get_stage(sim_single, "ED")
        @test JuMP.termination_status(stage_single.internal.psi_container.JuMPmodel) in
              [MOI.OPTIMAL, MOI.LOCALLY_SOLVED]

    end

    stage_info = Dict(
        "UC" => Dict("optimizer" => GLPK_optimizer, "jump_model" => nothing),
        "ED" => Dict("optimizer" => ipopt_optimizer),
    )
    # Tests of a Simulation without Caches
    duals = [:CopperPlateBalance]
    c_sys5_hy_uc = build_system("c_sys5_hy_uc")
    c_sys5_hy_ed = build_system("c_sys5_hy_ed")
    stages_definition = Dict(
        "UC" => Stage(
            GenericOpProblem,
            template_hydro_basic_uc,
            c_sys5_hy_uc,
            stage_info["UC"]["optimizer"];
            constraint_duals = duals,
        ),
        "ED" => Stage(
            GenericOpProblem,
            template_hydro_ed,
            c_sys5_hy_ed,
            stage_info["ED"]["optimizer"];
            constraint_duals = duals,
        ),
    )

    sequence = SimulationSequence(
        step_resolution = Hour(24),
        order = Dict(1 => "UC", 2 => "ED"),
        feedforward_chronologies = Dict(("UC" => "ED") => Synchronize(periods = 24)),
        horizons = Dict("UC" => 24, "ED" => 12),
        intervals = Dict(
            "UC" => (Hour(24), Consecutive()),
            "ED" => (Hour(1), Consecutive()),
        ),
        feedforward = Dict(
            ("ED", :devices, :Generators) => SemiContinuousFF(
                binary_source_stage = PSI.ON,
                affected_variables = [PSI.ACTIVE_POWER],
            ),
            ("ED", :devices, :HydroEnergyReservoir) => IntegralLimitFF(
                variable_source_stage = PSI.ACTIVE_POWER,
                affected_variables = [PSI.ACTIVE_POWER],
            ),
        ),
        ini_cond_chronology = InterStageChronology(),
    )
    sim = Simulation(
        name = "aggregation",
        steps = 2,
        stages = stages_definition,
        stages_sequence = sequence,
        simulation_folder = file_path,
    )

    # Run twice, once building normally, once after deserializing.
    for i in 1:2
        output_dir = "test" * string(i)
        if i == 2
            sim = get_deserialized(sim, stage_info)
        end

        build!(sim; output_dir = output_dir, recorders = [:simulation])
        sim_results = execute!(sim)

        stage_names = keys(sim.stages)
        step = ["step-1", "step-2"]

        @testset "All stages executed - No Cache" begin
            for name in stage_names
                stage = PSI.get_stage(sim, name)
                @test JuMP.termination_status(stage.internal.psi_container.JuMPmodel) in
                      [MOI.OPTIMAL, MOI.LOCALLY_SOLVED]
            end
        end

        @testset "Test reading and writing to the results folder" begin
            for name in stage_names
                files = collect(readdir(sim_results.results_folder))
                for f in files
                    rm("$(sim_results.results_folder)/$f")
                end
                rm(sim_results.results_folder)
                res = load_simulation_results(sim_results, name)
                !ispath(res.results_folder) && mkdir(res.results_folder)
                write_results(res)
                loaded_res = load_operation_results(sim_results.results_folder)
                @test loaded_res.variable_values == res.variable_values
                @test loaded_res.parameter_values == res.parameter_values
            end
        end

        @testset "Test file names" begin
            for name in stage_names
                files = collect(readdir(sim_results.results_folder))
                for f in files
                    rm("$(sim_results.results_folder)/$f")
                end
                res = load_simulation_results(sim_results, name)
                write_results(res)
                variable_list = String.(PSI.get_variable_names(sim, name))
                variable_list = [
                    variable_list
                    "dual_CopperPlateBalance"
                    "optimizer_log"
                    "time_stamp"
                    "check"
                    "base_power"
                    "parameter_P_InterruptibleLoad"
                    "parameter_P_PowerLoad"
                    "parameter_P_RenewableDispatch"
                    "parameter_P_HydroEnergyReservoir"
                ]
                file_list = collect(readdir(sim_results.results_folder))
                for name in file_list
                    variable = splitext(name)[1]
                    @test any(x -> x == variable, variable_list)
                end
            end
        end

        @testset "Test argument errors" begin
            for name in stage_names
                res = load_simulation_results(sim_results, name)
                if isdir(res.results_folder)
                    files = collect(readdir(res.results_folder))
                    for f in files
                        rm("$(res.results_folder)/$f")
                    end
                    rm("$(res.results_folder)")
                end
                @test_throws IS.ConflictingInputsError write_results(res)
            end
        end

        @testset "Test simulation output serialization and deserialization" begin
            output_path = joinpath(dirname(sim_results.results_folder), "output_references")
            sim_output = collect(readdir(output_path))
            @test sim_output == [
                "base_power.json",
                "chronologies.json",
                "results_folder.json",
                "stage-ED",
                "stage-UC",
            ]
            sim_test = PSI.deserialize_sim_output(dirname(output_path))
            @test sim_test.ref == sim_results.ref
        end

        @testset "Test load simulation results between the two methods of load simulation" begin
            for name in stage_names
                variable = PSI.get_variable_names(sim, name)
                results = load_simulation_results(sim_results, name)
                res = load_simulation_results(sim_results, name, step, variable)
                @test results.variable_values == res.variable_values
                @test results.parameter_values == res.parameter_values
            end
        end

        @testset "Test verify length of time_stamp" begin
            for name in keys(sim.stages)
                results = load_simulation_results(sim_results, name)
                @test size(unique(results.time_stamp), 1) == size(results.time_stamp, 1)
            end
        end

        @testset "Test verify no gaps in the time_stamp" begin
            for name in keys(sim.stages)
                stage = sim.stages[name]
                results = load_simulation_results(sim_results, name)
                resolution = convert(Dates.Millisecond, PSI.get_resolution(stage))
                time_stamp = results.time_stamp
                length = size(time_stamp, 1)
                test = results.time_stamp[1, 1]:resolution:results.time_stamp[length, 1]
                @test time_stamp[!, :Range] == test
            end
        end
        ###########################################################

        @testset "Test dual constraints in results" begin
            res = PSI.load_simulation_results(sim_results, "ED")
            dual =
                JuMP.dual(sim.stages["ED"].internal.psi_container.constraints[:CopperPlateBalance][1])
            @test isapprox(
                dual,
                res.dual_values[:dual_CopperPlateBalance][1, 1],
                atol = 1.0e-4,
            )
            !ispath(res.results_folder) && mkdir(res.results_folder)
            PSI.write_to_CSV(res)
            @test !isempty(res.results_folder)
        end

        @testset "Test verify parameter feedforward for consecutive UC to ED" begin
            P_keys = [
                (PSI.ACTIVE_POWER, PSY.HydroEnergyReservoir),
                #(PSI.ON, PSY.ThermalStandard),
                #(PSI.ACTIVE_POWER, PSY.HydroEnergyReservoir),
            ]

            vars_names = [
                PSI.variable_name(PSI.ACTIVE_POWER, PSY.HydroEnergyReservoir),
                #PSI.variable_name(PSI.ON, PSY.ThermalStandard),
                #PSI.variable_name(PSI.ACTIVE_POWER, PSY.HydroEnergyReservoir),
            ]
            for (ik, key) in enumerate(P_keys)
                variable_ref = PSI.get_reference(sim_results, "UC", 1, vars_names[ik])[1] # 1 is first step
                array = PSI.get_parameter_array(PSI.get_parameter_container(
                    sim.stages["ED"].internal.psi_container,
                    Symbol(key[1]),
                    key[2],
                ))
                parameter = collect(values(value.(array.data)))  # [device, time] 1 is first execution
                raw_result = Feather.read(variable_ref)
                for j in 1:size(parameter, 1)
                    result = raw_result[end, j] # end is last result [time, device]
                    initial = parameter[1] # [device, time]
                    @test isapprox(initial, result)
                end
            end
        end

        @testset "Test verify time gap for Consecutive" begin
            names = ["UC"]
            for name in names
                variable_list = PSI.get_variable_names(sim, name)
                reference_1 = PSI.get_reference(sim_results, name, 1, variable_list[1])[1]
                reference_2 = PSI.get_reference(sim_results, name, 2, variable_list[1])[1]
                time_file_path_1 = joinpath(dirname(reference_1), "time_stamp.feather") #first line, file path
                time_file_path_2 = joinpath(dirname(reference_2), "time_stamp.feather")
                time_1 = convert(Dates.DateTime, Feather.read(time_file_path_1)[end, 1]) # first time
                time_2 = convert(Dates.DateTime, Feather.read(time_file_path_2)[1, 1])
                @test time_2 == time_1
            end
        end

        @testset "Test verify initial condition feedforward for consecutive ED to UC" begin
            ic_keys = [PSI.ICKey(PSI.DevicePower, PSY.ThermalStandard)]
            vars_names = [PSI.variable_name(PSI.ACTIVE_POWER, PSY.ThermalStandard)]
            for (ik, key) in enumerate(ic_keys)
                variable_ref = PSI.get_reference(sim_results, "ED", 1, vars_names[ik])[24]
                initial_conditions =
                    get_initial_conditions(PSI.get_psi_container(sim, "UC"), key)
                for ic in initial_conditions
                    raw_result =
                        Feather.read(variable_ref)[end, Symbol(PSI.device_name(ic))] # last value of last hour
                    initial_cond = value(PSI.get_value(ic))
                    @test isapprox(raw_result, initial_cond; atol = 1e-2)
                end
            end
        end

        @testset "Verify simulation events" begin
            file = joinpath(
                file_path,
                PSI.get_name(sim),
                output_dir,
                "recorder",
                "simulation.log",
            )
            @test isfile(file)
            events = PSI.list_simulation_events(
                PSI.InitialConditionUpdateEvent,
                joinpath(file_path, "aggregation", output_dir);
                step = 1,
            )
            @test length(events) == 0
            events = PSI.list_simulation_events(
                PSI.InitialConditionUpdateEvent,
                joinpath(file_path, "aggregation", output_dir);
                step = 2,
            )
            @test length(events) == 10
            PSI.show_simulation_events(
                devnull,
                PSI.InitialConditionUpdateEvent,
                joinpath(file_path, "aggregation", output_dir);
                step = 2,
            )
            events = PSI.list_simulation_events(
                PSI.InitialConditionUpdateEvent,
                joinpath(file_path, "aggregation", output_dir);
                step = 1,
                stage = 1,
            )
            @test length(events) == 0
            events = PSI.list_simulation_events(
                PSI.InitialConditionUpdateEvent,
                joinpath(file_path, "aggregation", output_dir);
                step = 2,
                stage = 1,
            )
            @test length(events) == 10
            PSI.show_simulation_events(
                devnull,
                PSI.InitialConditionUpdateEvent,
                joinpath(file_path, "aggregation", output_dir);
                step = 2,
                stage = 1,
            )
        end
    end

    ####################
    stages_definition = Dict(
        "UC" => Stage(
            GenericOpProblem,
            template_hydro_basic_uc,
            c_sys5_hy_uc,
            GLPK_optimizer,
        ),
        "ED" =>
            Stage(GenericOpProblem, template_hydro_ed, c_sys5_hy_ed, ipopt_optimizer),
    )

    sequence = SimulationSequence(
        order = Dict(1 => "UC", 2 => "ED"),
        step_resolution = Hour(1),
        feedforward_chronologies = Dict(("UC" => "ED") => RecedingHorizon()),
        horizons = Dict("UC" => 24, "ED" => 12),
        intervals = Dict(
            "UC" => (Hour(1), RecedingHorizon()),
            "ED" => (Minute(5), RecedingHorizon()),
        ),
        feedforward = Dict(
            ("ED", :devices, :Generators) => SemiContinuousFF(
                binary_source_stage = PSI.ON,
                affected_variables = [PSI.ACTIVE_POWER],
            ),
        ),
        ini_cond_chronology = InterStageChronology(),
    )

    sim = Simulation(
        name = "receding_results",
        steps = 2,
        stages = stages_definition,
        stages_sequence = sequence,
        simulation_folder = file_path,
    )
    build!(sim)
    sim_results = execute!(sim)

    @testset "Test verify time gap for Receding Horizon" begin
        names = ["UC"] # TODO why doesn't this work for ED??
        for name in names
            variable_list = PSI.get_variable_names(sim, name)
            reference_1 = PSI.get_reference(sim_results, name, 1, variable_list[1])[1]
            reference_2 = PSI.get_reference(sim_results, name, 2, variable_list[1])[1]
            time_file_path_1 = joinpath(dirname(reference_1), "time_stamp.feather") #first line, file path
            time_file_path_2 = joinpath(dirname(reference_2), "time_stamp.feather")
            time_1 = convert(Dates.DateTime, Feather.read(time_file_path_1)[1, 1]) # first time
            time_2 = convert(Dates.DateTime, Feather.read(time_file_path_2)[1, 1])
            time_change = time_2 - time_1
            interval = PSI.get_stage_interval(PSI.get_sequence(sim), name)
            @test Dates.Hour(time_change) == Dates.Hour(interval)
        end
    end

    @testset "Test verify parameter feedforward for Receding Horizon" begin
        P_keys = [(PSI.ON, PSY.ThermalStandard)]
        vars_names = [PSI.variable_name(PSI.ON, PSY.ThermalStandard)]
        for (ik, key) in enumerate(P_keys)
            variable_ref = PSI.get_reference(sim_results, "UC", 2, vars_names[ik])[1]
            raw_result = Feather.read(variable_ref)
            ic = PSI.get_parameter_array(PSI.get_parameter_container(
                sim.stages["ED"].internal.psi_container,
                Symbol(key[1]),
                key[2],
            ))
            for name in DataFrames.names(raw_result)
                result = raw_result[1, name] # first time period of results  [time, device]
                initial = value(ic[String(name)]) # [device, time]
                @test isapprox(initial, result, atol = 1.0e-4)
            end
        end
    end

    @testset "Test verify initial condition feedforward for Receding Horizon" begin
        results = load_simulation_results(sim_results, "ED")
        ic_keys = [PSI.ICKey(PSI.DevicePower, PSY.ThermalStandard)]
        vars_names = [PSI.variable_name(PSI.ACTIVE_POWER, PSY.ThermalStandard)]
        ed_horizon = PSI.get_stage_horizon(sim.sequence, "ED")
        no_steps = PSI.get_steps(sim)
        for (ik, key) in enumerate(ic_keys)
            initial_conditions =
                get_initial_conditions(PSI.get_psi_container(sim, "UC"), key)
            vars = results.variable_values[vars_names[ik]] # change to getter function
            for ic in initial_conditions
                output = vars[ed_horizon * (no_steps - 1), Symbol(PSI.device_name(ic))] # change to getter function
                initial_cond = value(PSI.get_value(ic))
                @test isapprox(output, initial_cond, atol = 1.0e-4)
            end
        end
    end
    @testset "Test print methods" begin
        list = [sim, sim_results, sim.sequence, sim_single.sequence, res, sim.stages["UC"]]
        _test_plain_print_methods(list)
        _test_html_print_methods([res])
    end
    @testset "Test print methods of sequence ascii art" begin

        sequence_2 = SimulationSequence(
            order = Dict(1 => "UC", 2 => "ED"),
            step_resolution = Hour(1),
            feedforward_chronologies = Dict(("UC" => "ED") => RecedingHorizon(periods = 2)),
            horizons = Dict("UC" => 24, "ED" => 12),
            intervals = Dict(
                "UC" => (Hour(1), RecedingHorizon()),
                "ED" => (Minute(5), RecedingHorizon()),
            ),
            feedforward = Dict(
                ("ED", :devices, :Generators) => SemiContinuousFF(
                    binary_source_stage = PSI.ON,
                    affected_variables = [PSI.ACTIVE_POWER],
                ),
            ),
            ini_cond_chronology = InterStageChronology(),
        )

        sequence_4 = SimulationSequence(
            order = Dict(1 => "UC", 2 => "ED"),
            step_resolution = Hour(1),
            feedforward_chronologies = Dict(("UC" => "ED") => RecedingHorizon(periods = 4)),
            horizons = Dict("UC" => 24, "ED" => 12),
            intervals = Dict(
                "UC" => (Hour(1), RecedingHorizon()),
                "ED" => (Minute(5), RecedingHorizon()),
            ),
            feedforward = Dict(
                ("ED", :devices, :Generators) => SemiContinuousFF(
                    binary_source_stage = PSI.ON,
                    affected_variables = [PSI.ACTIVE_POWER],
                ),
            ),
            ini_cond_chronology = InterStageChronology(),
        )

        sequence_3 = SimulationSequence(
            order = Dict(1 => "UC", 2 => "ED"),
            step_resolution = Hour(1),
            feedforward_chronologies = Dict(("UC" => "ED") => RecedingHorizon(periods = 3)),
            horizons = Dict("UC" => 24, "ED" => 12),
            intervals = Dict(
                "UC" => (Hour(1), RecedingHorizon()),
                "ED" => (Minute(5), RecedingHorizon()),
            ),
            feedforward = Dict(
                ("ED", :devices, :Generators) => SemiContinuousFF(
                    binary_source_stage = PSI.ON,
                    affected_variables = [PSI.ACTIVE_POWER],
                ),
            ),
            ini_cond_chronology = InterStageChronology(),
        )

        sequence_5 = SimulationSequence(
            order = Dict(1 => "UC", 2 => "ED"),
            step_resolution = Hour(1),
            feedforward_chronologies = Dict(("UC" => "ED") => RecedingHorizon(periods = 2)),
            horizons = Dict("UC" => 24, "ED" => 12),
            intervals = Dict(
                "UC" => (Hour(1), RecedingHorizon()),
                "ED" => (Minute(5), RecedingHorizon()),
            ),
            feedforward = Dict(
                ("ED", :devices, :Generators) => RangeFF(
                    variable_source_stage_ub = PSI.ON,
                    variable_source_stage_lb = PSI.ON,
                    affected_variables = [PSI.ACTIVE_POWER],
                ),
            ),
            ini_cond_chronology = InterStageChronology(),
        )

        sequence_13 = SimulationSequence(
            order = Dict(1 => "UC", 2 => "ED"),
            step_resolution = Hour(1),
            feedforward_chronologies = Dict(
                ("UC" => "ED") => RecedingHorizon(periods = 13),
            ),
            horizons = Dict("UC" => 24, "ED" => 12),
            intervals = Dict(
                "UC" => (Hour(1), RecedingHorizon()),
                "ED" => (Minute(5), RecedingHorizon()),
            ),
            feedforward = Dict(
                ("ED", :devices, :Generators) => SemiContinuousFF(
                    binary_source_stage = PSI.ON,
                    affected_variables = [PSI.ACTIVE_POWER],
                ),
            ),
            ini_cond_chronology = InterStageChronology(),
        )
        list = [sequence_2, sequence_3, sequence_4, sequence_5, sequence_13]
        _test_plain_print_methods(list)
        stage_1 = FakeStagesStruct(Dict(1 => 1, 2 => 2, 3 => 3, 4 => 4, 5 => 5, 6 => 6)) # testing 5 stages
        stage_3 = FakeStagesStruct(Dict(1 => 1, 2 => 100)) #testing 3 digits
        stage_4 = FakeStagesStruct(Dict(1 => 1, 2 => 1000)) #testing 4 digits
        stage_12 = FakeStagesStruct(Dict(1 => 1, 2 => 12, 3 => 5, 4 => 6))
        list = [stage_1, stage_3, stage_4, stage_12]
        _test_plain_print_methods(list)

    end

    ####################
    @testset "negative test checking total sums" begin
        stage_names = keys(sim.stages)
        for name in stage_names
            files = collect(readdir(sim_results.results_folder))
            for f in files
                rm("$(sim_results.results_folder)/$f")
            end
            variable_list = PSI.get_variable_names(sim, name)
            res = load_simulation_results(sim_results, name)
            write_results(res)
            _file_path = joinpath(sim_results.results_folder, "$(variable_list[1]).feather")
            rm(_file_path)
            fake_df = DataFrames.DataFrame(:A => Array(1:10))
            Feather.write(_file_path, fake_df)
            @test_logs(
                (:error, r"hash mismatch"),
                match_mode = :any,
                @test_throws(
                    IS.HashMismatchError,
                    check_file_integrity(dirname(_file_path))
                )
            )
        end
        for name in stage_names
            variable_list = PSI.get_variable_names(sim, name)
            check_file_path = PSI.get_reference(sim_results, name, 1, variable_list[1])[1]
            rm(check_file_path)
            time_length = sim_results.chronologies["stage-$name"]
            fake_df = DataFrames.DataFrame(:A => Array(1:time_length))
            Feather.write(check_file_path, fake_df)
            @test_logs(
                (:error, r"hash mismatch"),
                match_mode = :any,
                @test_throws(
                    IS.HashMismatchError,
                    check_file_integrity(dirname(check_file_path))
                )
            )
        end
    end

    @testset "Simulation with Cache" begin
        stages_definition = Dict(
            "UC" => Stage(
                GenericOpProblem,
                template_hydro_st_standard_uc,
                #template_uc,
                c_sys5_hy_uc,
                #c_sys5_uc,
                GLPK_optimizer,
            ),
            "ED" => Stage(
                GenericOpProblem,
                template_hydro_st_ed,
                #template_ed,
                c_sys5_hy_ed,
                #c_sys5_ed,
                GLPK_optimizer,
            ),
        )

        sequence_cache = SimulationSequence(
            step_resolution = Hour(24),
            order = Dict(1 => "UC", 2 => "ED"),
            feedforward_chronologies = Dict(("UC" => "ED") => Synchronize(periods = 24)),
            horizons = Dict("UC" => 24, "ED" => 12),
            intervals = Dict(
                "UC" => (Hour(24), Consecutive()),
                "ED" => (Hour(1), Consecutive()),
            ),
            feedforward = Dict(
                ("ED", :devices, :Generators) => SemiContinuousFF(
                    binary_source_stage = PSI.ON,
                    affected_variables = [PSI.ACTIVE_POWER],
                ),
                ("ED", :devices, :HydroEnergyReservoir) => IntegralLimitFF(
                    variable_source_stage = PSI.ACTIVE_POWER,
                    affected_variables = [PSI.ACTIVE_POWER],
                ),
            ),
            cache = Dict(
                ("UC",) => TimeStatusChange(PSY.ThermalStandard, PSI.ON),
                ("UC", "ED") => StoredEnergy(PSY.HydroEnergyReservoir, PSI.ENERGY),
            ),
            ini_cond_chronology = InterStageChronology(),
        )
        sim_cache = Simulation(
            name = "cache",
            steps = 2,
            stages = stages_definition,
            stages_sequence = sequence_cache,
            simulation_folder = file_path,
        )
        build!(sim_cache)
        sim_cache_results = execute!(sim_cache)
        var_names =
            axes(PSI.get_stage(sim_cache, "UC").internal.psi_container.variables[:On__ThermalStandard])[1]
        for name in var_names
            var =
                PSI.get_stage(sim_cache, "UC").internal.psi_container.variables[:On__ThermalStandard][
                    name,
                    24,
                ]
            cache = PSI.get_cache(
                sim_cache,
                PSI.CacheKey(TimeStatusChange, PSY.ThermalStandard),
            ).value[name]
            @test JuMP.value(var) == cache[:status]
        end

        @testset "Test verify initial condition update using StoredEnergy cache" begin
            ic_keys = [PSI.ICKey(PSI.EnergyLevel, PSY.HydroEnergyReservoir)]
            vars_names = [PSI.variable_name(PSI.ENERGY, PSY.HydroEnergyReservoir)]
            for (ik, key) in enumerate(ic_keys)
                variable_ref =
                    PSI.get_reference(sim_cache_results, "ED", 1, vars_names[ik])[end]
                initial_conditions =
                    get_initial_conditions(PSI.get_psi_container(sim_cache, "UC"), key)
                for ic in initial_conditions
                    raw_result =
                        Feather.read(variable_ref)[end, Symbol(PSI.device_name(ic))] # last value of last hour
                    initial_cond = value(PSI.get_value(ic))
                    @test isapprox(raw_result, initial_cond)
                end
            end
        end
    end

    @testset "" begin
        single_stage_definition = Dict(
            "ED" => Stage(
                GenericOpProblem,
                template_hydro_st_ed,
                c_sys5_hy_ed,
                GLPK_optimizer,
            ),
        )

        single_sequence = SimulationSequence(
            step_resolution = Hour(1),
            order = Dict(1 => "ED"),
            horizons = Dict("ED" => 12),
            intervals = Dict("ED" => (Hour(1), Consecutive())),
            cache = Dict(("ED",) => StoredEnergy(PSY.HydroEnergyReservoir, PSI.ENERGY)),
            ini_cond_chronology = IntraStageChronology(),
        )

        sim_single = Simulation(
            name = "cache_st",
            steps = 2,
            stages = single_stage_definition,
            stages_sequence = single_sequence,
            simulation_folder = file_path,
        )
        build!(sim_single)
        sim_cache_results = execute!(sim_single)

        @testset "Test verify initial condition update using StoredEnergy cache" begin
            ic_keys = [PSI.ICKey(PSI.EnergyLevel, PSY.HydroEnergyReservoir)]
            vars_names = [PSI.variable_name(PSI.ENERGY, PSY.HydroEnergyReservoir)]
            for (ik, key) in enumerate(ic_keys)
                variable_ref =
                    PSI.get_reference(sim_cache_results, "ED", 1, vars_names[ik])[1]
                initial_conditions =
                    get_initial_conditions(PSI.get_psi_container(sim_single, "ED"), key)
                for ic in initial_conditions
                    raw_result =
                        Feather.read(variable_ref)[end, Symbol(PSI.device_name(ic))] # last value of last hour
                    initial_cond = value(PSI.get_value(ic))
                    @test isapprox(raw_result, initial_cond)
                end
            end
        end
    end
end

@testset "Test load simulation" begin
    # Use spaces in this path because that has caused failures.
    path = (joinpath(pwd(), "test reading results"))
    !isdir(path) && mkdir(path)

    try
        test_load_simulation(path)
    finally
        @info("removing test files")
        rm(path, force = true, recursive = true)
    end
end
