"""
    PNObject

Abstract supertype for all Petri net objects (places, transitions).
"""
abstract type PNObject end

"""
    Place <: PNObject

Represents a place in a Petri net, holding tokens.

Fields:
- `name`: Name of the place
- `token`: Number of tokens

Example:
    Place("p1", 1)
"""
mutable struct Place <: PNObject 
    const name::String
    token::Real
end 

"""
    UpdateValue

Enum for context update values in Petri net transitions.
Possible values: `on`, `off`.
"""
@enum UpdateValue on off

"""
    Update

Represents an update action for a context in a Petri net transition.

Fields:
- `context`: Context to update
- `updateValue`: UpdateValue (on/off)

Example:
    Update(ctx, on)
"""
mutable struct Update
    context::Context
    updateValue::UpdateValue
end 

"""
    Base.:(=>)(context::Context, updateValue::UpdateValue)

Creates an Update object using the => operator.

Arguments:
- `context`: Context to update
- `updateValue`: UpdateValue (on/off)

Returns an Update object.

Example:
    ctx => on
"""
function Base.:(=>)(context::Context, updateValue::UpdateValue)
	Update(context, updateValue)
end

"""
    Transition <: PNObject

Represents a transition in a Petri net.

Fields:
- `name`: Name of the transition
- `contexts`: Contexts or context rules for the transition
- `updates`: Array of Update actions

Example:
    Transition("t1", ctx, [Update(ctx, on)])
"""
struct Transition <: PNObject 
    name::String
    contexts::Union{Nothing, <:AbstractContext}
    updates::AbstractArray{Update}
end

"""
    Arc

Abstract supertype for all Petri net arc types.
"""
abstract type Arc end

"""
    NormalArc <: Arc

Represents a normal arc between Petri net objects.

Fields:
- `from`: Source PNObject
- `to`: Target PNObject
- `weight`: Arc weight
- `priority`: Arc priority (default 0)

Example:
    NormalArc(from=obj1, to=obj2, weight=1)
"""
Base.@kwdef mutable struct NormalArc <: Arc
    const from::PNObject
    const to::PNObject
    weight::Real
    priority::Int = 0
end

"""
    InhibitorArc <: Arc

Represents an inhibitor arc from a place to a transition.

Fields:
- `from`: Source Place
- `to`: Target Transition
- `weight`: Arc weight

Example:
    InhibitorArc(p, t, 1)
"""
mutable struct InhibitorArc <: Arc
    const from::Place
    const to::Transition
    weight::Real
end

"""
    TestArc <: Arc

Represents a test arc from a place to a transition.

Fields:
- `from`: Source Place
- `to`: Target Transition
- `weight`: Arc weight

Example:
    TestArc(p, t, 1)
"""
mutable struct TestArc <: Arc
    const from::Place
    const to::Transition
    weight::Real
end

"""
    PetriNet

Represents a Petri net with places, transitions, and arcs.

Fields:
- `places`: Vector of places
- `transitions`: Vector of transitions
- `arcs`: Vector of arcs

Example:
    PetriNet(places=[p1], transitions=[t1], arcs=[a1])
"""
Base.@kwdef mutable struct PetriNet
    places::Vector{Union{Any, Place}} = []
    transitions::Vector{Union{Any, Transition}} = []
    arcs::Vector{Union{Any, <:Arc}} = []
end

"""
    CompiledPetriNet

Represents a compiled Petri net for efficient execution.

Fields:
- `WeightMatrix_in`, `WeightMatrix_out`, `WeightMatrix_inhibitor`, `WeightMatrix_test`: Matrices for arc weights
- `tokenVector`: Vector of tokens
- `PrioritiesMatrix`: Matrix of priorities
- `ContextMatrices`: Vector of context matrices
- `UpdateMatrix`: Matrix of updates
- `ContextMap`: Mapping of contexts

Example:
    CompiledPetriNet(...)
"""
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