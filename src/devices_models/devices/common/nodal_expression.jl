struct NodalExpressionInputs
    forecast_label::String
    # TODO: Remove this hack
    parameter_name::Union{String, Symbol}
    peak_value_function::Function
    multiplier::Float64
    update_ref::Type
end

"""
Construct NodalExpressionInputs for specific types.
"""
function make_nodal_expression_inputs(
    ::Type{T},
    ::Type{U},
    use_forecasts::Bool,
) where {T <: PSY.Device, U <: PM.AbstractPowerModel}
    error("make_nodal_expression_inputs is not implemented for type $T/$U")
end

"""
Default implementation to add nodal expressions.

Users of this function must implement a method for [`make_nodal_expression_inputs`](@ref)
for their specific types.
Users may also implement custom nodal_expression! methods.
"""
function nodal_expression!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::Type{U},
) where {T <: PSY.Device, U <: PM.AbstractPowerModel}
    nodal_expression!(psi_container, devices, PM.AbstractActivePowerModel)
    _nodal_expression!(psi_container, devices, U, :nodal_balance_reactive)
    return
end

function nodal_expression!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::Type{U},
) where {T <: PSY.Device, U <: PM.AbstractActivePowerModel}
    _nodal_expression!(psi_container, devices, U, :nodal_balance_active)
    return
end

function _nodal_expression!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::Type{U},
    expression_name::Symbol,
) where {T <: PSY.Device, U <: PM.AbstractPowerModel}
    # Run the Active Power Loop.
    parameters = model_has_parameters(psi_container)
    use_forecast_data = model_uses_forecasts(psi_container)
    inputs = make_nodal_expression_inputs(T, U, use_forecast_data)
    forecast_label = use_forecast_data ? inputs.forecast_label : ""
    constraint_infos = Vector{DeviceTimeSeriesConstraintInfo}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        ts_vector = get_time_series(psi_container, d, forecast_label)
        constraint_info =
            DeviceTimeSeriesConstraintInfo(d, inputs.peak_value_function, ts_vector)
        constraint_infos[ix] = constraint_info
    end
    if parameters
        @debug inputs.update_ref, inputs.parameter_name forecast_label
        include_parameters(
            psi_container,
            constraint_infos,
            UpdateRef{inputs.update_ref}(inputs.parameter_name, forecast_label),
            expression_name,
            inputs.multiplier,
        )
        return
    else
        for constraint_info in constraint_infos
            for t in model_time_steps(psi_container)
                add_to_expression!(
                    psi_container.expressions[expression_name],
                    constraint_info.bus_number,
                    t,
                    inputs.multiplier *
                    constraint_info.multiplier *
                    constraint_info.timeseries[t],
                )
            end
        end
    end
end
