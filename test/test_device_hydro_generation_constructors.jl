@testset "Renewable data misspecification" begin
    # See https://discourse.julialang.org/t/how-to-use-test-warn/15557/5 about testing for warning throwing
    warn_message = "The data doesn't include devices of type HydroEnergyReservoir, consider changing the device models"
    model = DeviceModel(HydroEnergyReservoir, HydroDispatchRunOfRiver)
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, build_system("c_sys5"))
    @test_logs (:warn, warn_message) construct_device!(op_problem, :Hydro, model)
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, build_system("c_sys14"))
    @test_logs (:warn, warn_message) construct_device!(op_problem, :Hydro, model)
end

@testset "Hydro DCPLossLess FixedOutput" begin
    model = DeviceModel(HydroDispatch, FixedOutput)
    c_sys5_hy = build_system("c_sys5_hy")

    # Parameters Testing
    op_problem =
        OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_hy; use_parameters = true)
    construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, true, 0, 0, 0, 0, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_hy)
    construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 0, 0, 0, 0, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(
        TestOpProblem,
        DCPPowerModel,
        c_sys5_hy;
        use_forecast_data = false,
    )
    construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 0, 0, 0, 0, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

end

@testset "Hydro DCPLossLess HydroDispatch with HydroDispatchRunOfRiver formulations" begin
    model = DeviceModel(HydroDispatch, HydroDispatchRunOfRiver)
    c_sys5_hyd = build_system("c_sys5_hyd")

    # Parameters Testing
    op_problem =
        OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_hyd; use_parameters = true)
    construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, true, 0, 0, 0, 0, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_hyd)
    construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 0, 0, 0, 0, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)
end

@testset "Hydro ACPPowerModel HydroDispatch with HydroDispatchRunOfRiver formulations" begin
    model = DeviceModel(HydroDispatch, HydroDispatchRunOfRiver)
    c_sys5_hyd = build_system("c_sys5_hyd")

    # Parameters Testing
    op_problem =
        OperationsProblem(TestOpProblem, ACPPowerModel, c_sys5_hyd; use_parameters = true)
    construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, true, 0, 0, 0, 0, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(TestOpProblem, ACPPowerModel, c_sys5_hyd)
    construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 0, 0, 0, 0, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(
        TestOpProblem,
        ACPPowerModel,
        c_sys5_hyd;
        use_forecast_data = false,
    )
    construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 0, 0, 0, 0, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

end

@testset "Hydro DCPLossLess HydroEnergyReservoir with FixedOutput formulations" begin
    model = DeviceModel(HydroEnergyReservoir, FixedOutput)
    c_sys5_hy = build_system("c_sys5_hy")

    # Parameters Testing
    op_problem =
        OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_hy; use_parameters = true)
    construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, true, 0, 0, 0, 0, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_hy)
    construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 0, 0, 0, 0, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(
        TestOpProblem,
        DCPPowerModel,
        c_sys5_hy;
        use_forecast_data = false,
    )
    construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 0, 0, 0, 0, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

end

@testset "Hydro DCPLossLess HydroEnergyReservoir with HydroDispatchRunOfRiver formulations" begin
    model = DeviceModel(HydroEnergyReservoir, HydroDispatchRunOfRiver)
    c_sys5_hyd = build_system("c_sys5_hyd")

    # Parameters Testing
    op_problem =
        OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_hyd; use_parameters = true)
    construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, true, 24, 0, 24, 0, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_hyd)
    construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 24, 0, 24, 0, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(
        TestOpProblem,
        DCPPowerModel,
        c_sys5_hyd;
        use_forecast_data = false,
    )
    construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 1, 0, 1, 1, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

end

@testset "Hydro ACPPowerModel HydroEnergyReservoir with HydroDispatchRunOfRiver formulations" begin
    model = DeviceModel(HydroEnergyReservoir, HydroDispatchRunOfRiver)
    c_sys5_hyd = build_system("c_sys5_hyd")

    # Parameters Testing
    op_problem =
        OperationsProblem(TestOpProblem, ACPPowerModel, c_sys5_hyd; use_parameters = true)
    construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, true, 48, 0, 48, 24, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(TestOpProblem, ACPPowerModel, c_sys5_hyd)
    construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 48, 0, 48, 24, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(
        TestOpProblem,
        ACPPowerModel,
        c_sys5_hyd;
        use_forecast_data = false,
    )
    construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 2, 0, 2, 2, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

end

@testset "Hydro DCPLossLess HydroEnergyReservoir with HydroDispatchReservoirFlow Formulations" begin
    model = DeviceModel(HydroEnergyReservoir, HydroDispatchReservoirFlow)
    c_sys5_hy_uc = build_system("c_sys5_hy_uc")

    # Parameters Testing
    op_problem =
        OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_hy_uc; use_parameters = true)
    construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, true, 24, 0, 25, 24, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_hy_uc)
    construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 24, 0, 25, 24, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(
        TestOpProblem,
        DCPPowerModel,
        c_sys5_hy_uc;
        use_forecast_data = false,
    )
    construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 1, 0, 2, 1, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

end

@testset "Hydro ACPPowerModel HydroEnergyReservoir with HydroDispatchReservoirFlow Formulations" begin
    model = DeviceModel(HydroEnergyReservoir, HydroDispatchReservoirFlow)
    c_sys5_hy_uc = build_system("c_sys5_hy_uc")

    # Parameters Testing
    op_problem =
        OperationsProblem(TestOpProblem, ACPPowerModel, c_sys5_hy_uc; use_parameters = true)
    construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, true, 48, 0, 49, 48, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(TestOpProblem, ACPPowerModel, c_sys5_hy_uc)
    construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 48, 0, 49, 48, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(
        TestOpProblem,
        ACPPowerModel,
        c_sys5_hy_uc;
        use_forecast_data = false,
    )
    construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 2, 0, 3, 2, 0, false)
    psi_checkobjfun_test(op_problem, GAEVF)

end

#=
# All Hydro UC formulations are currently not supported
@testset "Hydro DCPLossLess HydroEnergyReservoir with HydroCommitmentRunOfRiver Formulations" begin
    model = DeviceModel(HydroEnergyReservoir, HydroCommitmentRunOfRiver)

    # Parameters Testing
    op_problem =
        OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_hyd; use_parameters = true)
    construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, true, 96, 0, 72, 0, 24, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_hyd)
    construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 96, 0, 48, 0, 24, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast Testing
    op_problem = OperationsProblem(
        TestOpProblem,
        DCPPowerModel,
        c_sys5_hyd;
        use_parameters = true,
        use_forecast_data = false,
    )
    construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, true, 4, 0, 3, 0, 1, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(
        TestOpProblem,
        DCPPowerModel,
        c_sys5_hyd;
        use_forecast_data = false,
    )
    construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 4, 0, 2, 1, 1, true)
    psi_checkobjfun_test(op_problem, GAEVF)

end

@testset "Hydro DCPLossLess HydroEnergyReservoir with HydroCommitmentReservoirlFlow Formulations" begin
    model = DeviceModel(HydroEnergyReservoir, HydroCommitmentReservoirFlow)

    # Parameters Testing
    op_problem =
        OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_hyd; use_parameters = true)
    construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, true, 96, 0, 72, 0, 24, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_hyd)
    construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 96, 0, 48, 0, 24, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast Testing
    op_problem = OperationsProblem(
        TestOpProblem,
        DCPPowerModel,
        c_sys5_hyd;
        use_parameters = true,
        use_forecast_data = false,
    )
    construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, true, 4, 0, 3, 0, 1, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(
        TestOpProblem,
        DCPPowerModel,
        c_sys5_hyd;
        use_forecast_data = false,
    )
    construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 4, 0, 2, 1, 1, true)
    psi_checkobjfun_test(op_problem, GAEVF)

end
=#

@testset "Hydro DCPLossLess HydroEnergyReservoir with HydroDispatchReservoirStorage Formulations" begin
    model = DeviceModel(HydroEnergyReservoir, HydroDispatchReservoirStorage)
    c_sys5_hyd = build_system("c_sys5_hyd")

    # Parameters Testing
    op_problem =
        OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_hyd; use_parameters = true)
    construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, true, 72, 0, 24, 24, 24, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_hyd)
    construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 72, 0, 24, 24, 24, false)
    psi_checkobjfun_test(op_problem, GAEVF)
end

@testset "Hydro DCPLossLess HydroEnergyReservoir with HydroDispatchReservoirCascade Formulations" begin
    model = DeviceModel(HydroEnergyReservoir, HydroDispatchReservoirCascade)
    c_sys5_hyd_cascade = build_system("c_sys5_hyd_cascade")

    # Parameters Testing
    op_problem =
        OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_hyd_cascade; use_parameters = true)
    construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, true, 144, 0, 48, 48, 48, false)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_hyd_cascade)
    construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 144, 0, 48, 48, 48, false)
    psi_checkobjfun_test(op_problem, GAEVF)
end

#=
# All Hydro UC formulations are currently not supported
@testset "Hydro DCPLossLess HydroEnergyReservoir with HydroCommitmentReservoirStorage Formulations" begin
    model = DeviceModel(HydroEnergyReservoir, HydroCommitmentReservoirStorage)

    # Parameters Testing
    op_problem =
        OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_hyd; use_parameters = true)
    construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, true, 96, 0, 72, 0, 24, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Parameters Testing
    op_problem = OperationsProblem(TestOpProblem, DCPPowerModel, c_sys5_hyd)
    construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 96, 0, 48, 0, 24, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast Testing
    op_problem = OperationsProblem(
        TestOpProblem,
        DCPPowerModel,
        c_sys5_hyd;
        use_parameters = true,
        use_forecast_data = false,
    )
    construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, true, 4, 0, 3, 0, 1, true)
    psi_checkobjfun_test(op_problem, GAEVF)

    # No Forecast - No Parameters Testing
    op_problem = OperationsProblem(
        TestOpProblem,
        DCPPowerModel,
        c_sys5_hyd;
        use_forecast_data = false,
    )
    construct_device!(op_problem, :Hydro, model)
    moi_tests(op_problem, false, 4, 0, 2, 1, 1, true)
    psi_checkobjfun_test(op_problem, GAEVF)

end
=#
