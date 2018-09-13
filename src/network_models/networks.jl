abstract type AbstractDCPowerModel <: PM.AbstractPowerFormulation end

abstract type AbstractACPowerModel <: PM.AbstractPowerFormulation end

abstract type StandardAC <: AbstractACPowerModel end

abstract type CopperPlatePowerModel <: AbstractDCPowerModel end

abstract type AbstractFlowForm <: AbstractDCPowerModel end

abstract type StandardPTDF <: AbstractFlowForm end

abstract type StandardPTDFLosses <: AbstractFlowForm end

#This line is from PowerModels, needs to be removed later
abstract type DCPlosslessForm <: PM.AbstractDCPForm end