
abstract type PNObject end

mutable struct Place <: PNObject 
    const name::String
    token::Real
end 

@enum UpdateValue on off

mutable struct Update
    context::Context
    updateValue::UpdateValue
end 

function Base.:(=>)(context::Context, updateValue::UpdateValue)
	Update(context, updateValue)
end

struct Transition <: PNObject 
    name::String
    contexts::Union{Nothing, <:AbstractContext}
    updates::AbstractArray{Update}
end

abstract type Arc end

Base.@kwdef mutable struct NormalArc <: Arc
    const from::PNObject
    const to::PNObject
    weight::Real
    priority::Int = 0
end
mutable struct InhibitorArc <: Arc
    const from::Place
    const to::Transition
    weight::Real
end
mutable struct TestArc <: Arc
    const from::Place
    const to::Transition
    weight::Real
end

Base.@kwdef mutable struct PetriNet
    places::Vector{Union{Any, Place}} = []
    transitions::Vector{Union{Any, Transition}} = []
    arcs::Vector{Union{Any, <:Arc}} = []
end

mutable struct CompiledPetriNet
    WeightMatrix_in::Matrix
    WeightMatrix_out::Matrix
    WeightMatrix_inhibitor::Matrix
    WeightMatrix_test::Matrix
    tokenVector::Vector
    PrioritiesMatrix::Matrix
    ContextMatrices::Vector
    UpdateMatrix::Matrix
    ContextMap::Dict
end