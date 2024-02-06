using Parameters

#### Context regarded type definitions ####

abstract type Mixin end

abstract type Context end

#### Context rule (condition) regarded type definitions ####

abstract type AbstractContextRule end

struct AndContextRule <: AbstractContextRule
	c1::Union{<:Context, <:AbstractContextRule}
	c2::Union{<:Context, <:AbstractContextRule}
end

struct OrContextRule <: AbstractContextRule
	c1::Union{<:Context, <:AbstractContextRule}
	c2::Union{<:Context, <:AbstractContextRule}
end

struct NotContextRule <: AbstractContextRule
	c::Union{<:Context, <:AbstractContextRule}
end

#### Petri Net type definitions ####

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

struct Transition <: PNObject 
    name::String
    contexts::Union{<:Context, Any, <:AbstractContextRule}
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

#### Management definitions ####

@with_kw mutable struct ContextManagement
	contexts::Vector{Context} = []
	activeContexts::Vector{Context} = []
	mixins::Dict{Context, Dict{Any, Vector{DataType}}} = Dict()
	mixinTypeDB::Dict{Any, Dict{Context, DataType}} = Dict()
	mixinDB::Dict{Any, Dict{Context, Any}} = Dict()
end

@with_kw mutable struct ContextControl
	contextPN::PetriNet = PetriNet()
	contextPNcompiled::Union{CompiledPetriNet, Nothing} = nothing
end

global contextManager = ContextManagement()
global contextControler = ContextControl()

#### Functions and macros ####

function setControlPNs(pn::PetriNet, cpn::CompiledPetriNet)
	contextControler.contextPN = pn
	contextControler.contextPNcompiled = cpn
end

function getControlPN()
	contextControler.contextPN
end

function getCompiledControlPN()
	contextControler.contextPNcompiled
end

function addPNToControlPN(pn::PetriNet)
	cpn = compile(pn)
	contextControler.contextPN.places == [] ? contextControler.contextPN.places = pn.places : push!(contextControler.contextPN.places, pn.places...)
	contextControler.contextPN.transitions == [] ? contextControler.contextPN.transitions = pn.transitions : push!(contextControler.contextPN.transitions, pn.transitions...)
	contextControler.contextPN.arcs == [] ? contextControler.contextPN.arcs = pn.arcs : push!(contextControler.contextPN.arcs, pn.arcs...)
	contextControler.contextPNcompiled = mergeCompiledPetriNets(contextControler.contextPNcompiled, cpn)
end

function getContexts()
	contextManager.contexts
end

function addContext(context::T) where {T <: Context}
	push!(contextManager.contexts, eval(context))
	push!(contextManager.activeContexts, eval(context))
end

function getActiveContexts()
	contextManager.activeContexts
end

function activateContextWithoutPN(context::T) where {T <: Context}
	if !(context in contextManager.activeContexts) push!(contextManager.activeContexts, context) end
	true
end

function deactivateContextWithoutPN(context::T) where {T <: Context}
	deleteat!(contextManager.activeContexts, findall(x->x==context, contextManager.activeContexts))
	true
end

function activateContext(context::T) where {T <: Context}
	if !(context in contextManager.activeContexts) push!(contextManager.activeContexts, context) end
	runPN(contextControler.contextPNcompiled)
	true
end

function deactivateContext(context::T) where {T <: Context}
	deleteat!(contextManager.activeContexts, findall(x->x==context, contextManager.activeContexts))
	runPN(contextControler.contextPNcompiled)
	true
end

function deactivateAllContexts()
	contextManager.activeContexts = []
	runPN(contextControler.contextPNcompiled)
	true
end

function isActive(context::T) where {T <: Context}
	context in contextManager.activeContexts
end

function addMixin(context, contextualType, mixinNameSymbol)
	if (context) in keys(contextManager.mixins)
		if (contextualType) in keys(contextManager.mixins[context])
			push!(contextManager.mixins[context][contextualType], mixinNameSymbol)
		else
			contextManager.mixins[context][contextualType] = [mixinNameSymbol]
		end
	else
		contextManager.mixins[context] = Dict((contextualType)=>[mixinNameSymbol])
	end
end

function getMixins()
	contextManager.mixins
end

function getMixins(type)
	contextManager.mixinDB[type]
end

function getMixin(type, context::T) where {T <: Context}
	(contextManager.mixinDB[type])[context]
end

macro newContext(contextName)
	if typeof(contextName) == String || typeof(contextName) == Symbol
		if typeof(contextName) == String
			contextName = Meta.parse(contextName)
		end
		contextTypeNameSymbol = Symbol(contextName, :ContextType)

		structDefExpr = :(struct $(contextTypeNameSymbol) <: Context end;)
		SingletonDefExpr = :($(contextName) = $contextTypeNameSymbol())

		return esc(:($structDefExpr; $SingletonDefExpr; addContext($contextName)))
	else
		error("Argument of @newContext must be a String or a Symbol")
	end
end


macro newMixin(mixin, attributes, context)
	contextualType = Symbol(strip((split(repr(mixin), "<:")[2])[1:end-1]))
	mixin = Symbol(strip((split(repr(mixin), " <: ")[1])[3:end]))
	Base.remove_linenums!(attributes)

	newStructExpr = :(struct $mixin <: Mixin
		$attributes
	end)

	return esc(:($newStructExpr; addMixin($context, $contextualType, $mixin)))
end

function assignMixin(pair::Pair, context::T) where {T<:Context}
	type = pair[1]
	mixin = pair[2]
	if type in keys(contextManager.mixinDB)
		if context in keys(contextManager.mixinDB[type])
			@warn(repr(type)*" already has Mixin in context "*repr(context)*". Previous Mixin will be overwritten!")
		end
		contextManager.mixinDB[type][context] = mixin
	else
		contextManager.mixinDB[type] = Dict(context => mixin)
	end
	if type in keys(contextManager.mixinTypeDB)
		contextManager.mixinTypeDB[type][context] = typeof(mixin)
	else
		contextManager.mixinTypeDB[type] = Dict(context => typeof(mixin))
	end
end

function disassignMixin(pair::Pair, context::T) where {T<:Context}
	type = pair[1]
	mixin = pair[2]
	if type in keys(contextManager.mixinDB)
		delete!(contextManager.mixinDB[type], context)
	else
		error("Mixin is not assigned to type "*repr(type))
	end
	if type in keys(contextManager.mixinTypeDB)
		delete!(contextManager.mixinTypeDB[type], context)
	else
		error("Mixin is not assigned to type "*repr(type))
	end
end

macro context(cname, expr)
	if typeof(expr) != Expr
		error("Second argument of @context must be a function or macro call or function definition")
	else
		if expr.head == :function
			functionHeaderString = repr(expr.args[1])
			if endswith(repr(expr.args[1]), "())")
				functionHeaderString = functionHeaderString[1:end-2] * "context::" * repr(cname)[2:end] * "ContextType))"
			else
				functionHeaderString = functionHeaderString[1:end-2] * ", " * "context::" * repr(cname)[2:end] * "ContextType))"
			end
			expr.args[1] = eval(Meta.parse(functionHeaderString))
			return esc(expr)
		elseif expr.head == :call
			callString = repr(expr)
			contextString = repr(cname)
			if endswith(callString, "())")
				callString = callString[1:end-2] *  contextString[2:end] * "))"
			else
				callString = callString[1:end-2] * ", " * contextString[2:end] * "))"
			end
			callExpr = Meta.parse(callString)
			return esc(eval(callExpr))
		elseif expr.head == :macrocall
			callString = repr(expr)
			contextString = repr(cname)
			callString = callString[3:end-1] * " " * contextString[2:end] 
			callExpr = Meta.parse(callString)
			return esc(callExpr)
		else
			error("Second argument of @context must be a function or macro call or function definition")
		end
	end
end

function isActive(contextRule::T) where {T <: AbstractContextRule}
	if contextRule isa AndContextRule
		isActive(contextRule.c1) & isActive(contextRule.c2)
	elseif contextRule isa OrContextRule
		isActive(contextRule.c1) | isActive(contextRule.c2)
	else
		!isActive(contextRule.c)
	end
end

function getContextsOfRule(contextRule::T) where {T <: AbstractContextRule}
	contexts = []
	if ((contextRule isa AndContextRule) | (contextRule isa OrContextRule))
		if typeof(contextRule.c1) <: AbstractContextRule
			append!(contexts, getContextsOfRule(contextRule.c1))
		else
			append!(contexts, [contextRule.c1])
		end
		if typeof(contextRule.c2) <: AbstractContextRule
			append!(contexts, getContextsOfRule(contextRule.c2))
		else
			append!(contexts, [contextRule.c2])
		end
	else
		if typeof(contextRule.c) <: AbstractContextRule
			append!(contexts, getContextsOfRule(contextRule.c))
		else
			append!(contexts, [contextRule.c])
		end
	end
	union(contexts)
end

function isActive(context::Nothing)
	true
end

function Base.:&(c1::CT1, c2::CT2) where {CT1, CT2 <: Union{Context, AbstractContextRule}}
    AndContextRule(c1, c2)
end

function Base.:|(c1::CT1, c2::CT2) where {CT1, CT2 <: Union{Context, AbstractContextRule}}
    OrContextRule(c1, c2)
end

function Base.:!(c::CT) where {CT <: Union{Context, AbstractContextRule}}
    NotContextRule(c)
end

function mergeCompiledPetriNets(pn1::Union{Nothing, CompiledPetriNet}, pn2::Union{Nothing, CompiledPetriNet})
    typeof(pn1) == Nothing ? pn2 : pn1
end

function mergeCompiledPetriNets(pn1::CompiledPetriNet, pn2::CompiledPetriNet)
    size_pn1_dim1 = size(pn1.WeightMatrix_in)[1]
    size_pn2_dim1 = size(pn2.WeightMatrix_in)[1]
    size_pn1_dim2 = size(pn1.WeightMatrix_in)[2]
    size_pn2_dim2 = size(pn2.WeightMatrix_in)[2]

    WeightMatrix_in_merge = zeros(size_pn1_dim1+size_pn2_dim1, size_pn1_dim2+size_pn2_dim2)
    WeightMatrix_in_merge[1:size_pn1_dim1, 1:size_pn1_dim2] = pn1.WeightMatrix_in
    WeightMatrix_in_merge[size_pn1_dim1+1:end, size_pn1_dim2+1:end] = pn2.WeightMatrix_in
    
    WeightMatrix_out_merge = zeros(size_pn1_dim1+size_pn2_dim1, size_pn1_dim2+size_pn2_dim2)
    WeightMatrix_out_merge[1:size_pn1_dim1, 1:size_pn1_dim2] = pn1.WeightMatrix_out
    WeightMatrix_out_merge[size_pn1_dim1+1:end, size_pn1_dim2+1:end] = pn2.WeightMatrix_out

    WeightMatrix_inhibitor_merge = zeros(size_pn1_dim1+size_pn2_dim1, size_pn1_dim2+size_pn2_dim2) .+ Inf
    WeightMatrix_inhibitor_merge[1:size_pn1_dim1, 1:size_pn1_dim2] = pn1.WeightMatrix_inhibitor
    WeightMatrix_inhibitor_merge[size_pn1_dim1+1:end, size_pn1_dim2+1:end] = pn2.WeightMatrix_inhibitor

    WeightMatrix_test_merge = zeros(size_pn1_dim1+size_pn2_dim1, size_pn1_dim2+size_pn2_dim2)
    WeightMatrix_test_merge[1:size_pn1_dim1, 1:size_pn1_dim2] = pn1.WeightMatrix_test
    WeightMatrix_test_merge[size_pn1_dim1+1:end, size_pn1_dim2+1:end] = pn2.WeightMatrix_test    

    tokenVector_merge = vcat(pn1.tokenVector, pn2.tokenVector)

    PrioritiesMatrix_merge = zeros(size_pn1_dim1+size_pn2_dim1, size_pn1_dim2+size_pn2_dim2)
    PrioritiesMatrix_merge[1:size_pn1_dim1, 1:size_pn1_dim2] = pn1.PrioritiesMatrix
    PrioritiesMatrix_merge[size_pn1_dim1+1:end, size_pn1_dim2+1:end] = pn2.PrioritiesMatrix    

    ContextMatrices_merge = vcat(pn1.ContextMatrices, pn2.ContextMatrices)

    ContextMap_merge = merge(pn1.ContextMap, pn2.ContextMap)
    
    if length(pn1.ContextMatrices[1]) != length(pn2.ContextMatrices[1])
        if length(pn1.ContextMatrices[1]) < length(pn2.ContextMatrices[1])
            for i in 1:length(pn1.ContextMatrices)
                ContextMatrices_merge[i] = hcat(pn1.ContextMatrices[i], zeros(size(pn1.ContextMatrices[i])[1], length(ContextMap_merge)-size(pn1.ContextMatrices[i])[2]))
            end
        else
            for i in length(pn1.ContextMatrices)+1:length(pn1.ContextMatrices)+length(pn2.ContextMatrices)
                ContextMatrices_merge[i] = hcat(pn2.ContextMatrices[i], zeros(size(pn2.ContextMatrices[i])[1], length(ContextMap_merge)-size(pn2.ContextMatrices[i])[2]))
            end
        end
    end

    UpdateMatrix_cast1 = zeros(length(ContextMap_merge), size_pn1_dim2+size_pn2_dim2)
    UpdateMatrix_cast2 = zeros(length(ContextMap_merge), size_pn1_dim2+size_pn2_dim2)
    if size(pn1.UpdateMatrix)[1] < size(pn2.UpdateMatrix)[1]
        UpdateMatrix_cast1[1:size(pn1.UpdateMatrix)[1], 1:size_pn1_dim2] = pn1.UpdateMatrix
        UpdateMatrix_cast2[1:end, size_pn1_dim2+1:end] = pn2.UpdateMatrix
    else
        UpdateMatrix_cast1[1:end, 1:size_pn1_dim2] = pn1.UpdateMatrix
        UpdateMatrix_cast2[1:size(pn2.UpdateMatrix)[1], size_pn1_dim2+1:end] = pn2.UpdateMatrix
    end
    UpdateMatrix_merge = sign.(UpdateMatrix_cast1 .+ UpdateMatrix_cast2)

    CompiledPetriNet(WeightMatrix_in_merge,
                     WeightMatrix_out_merge,
                     WeightMatrix_inhibitor_merge,
                     WeightMatrix_test_merge,
                     tokenVector_merge,
                     PrioritiesMatrix_merge,
                     ContextMatrices_merge,
                     UpdateMatrix_merge,
                     ContextMap_merge)
end

function genContextRuleMatrix(cr::T, cdict::Dict, nc::Int) where {T <: Union{Context, Any, AbstractContextRule}}
    matrix = zeros(1, nc)
    if typeof(cr) <: AbstractContextRule
        if cr isa AndContextRule
            a = genContextRuleMatrix(cr.c1, cdict, nc)
            b = genContextRuleMatrix(cr.c2, cdict, nc)
            matrix = nothing
            c = 0
            for i in 1:size(a)[1]
                for j in 1:size(b)[1]
                    findmin((a[i, :] .- b[j, :]) .* b[j, :])[1] < -1 ? c = zeros(1, size(a)[2]) : c = a[i, :] .+ b[j, :]
                    c = reshape(c, 1, length(c))
                    matrix == nothing ? matrix = [c;] : matrix = [matrix; c]
                end            
            end       
        elseif cr isa OrContextRule
            matrix = [genContextRuleMatrix(cr.c1, cdict, nc); genContextRuleMatrix(cr.c2, cdict, nc)]
        else
            matrix = -genContextRuleMatrix(cr.c, cdict, nc)
        end
    elseif typeof(cr) <: Context
        matrix[cdict[cr]] = 1
    end
    matrix
end

function compile(pn::PetriNet)
    # should test here if name is given two times
    # should test here if arcs are connected correctly (not place to place etc.)
    np = length(pn.places)                              # number of places
    nt = length(pn.transitions)                         # number of transitions
    nc = length(getContexts())                          # number of contexts
    W_i = zeros(Float64, np, nt)                        # Input Arc weights matrix (to place)
    W_o = zeros(Float64, np, nt)                        # Output Arc weights matrix(from place)
    W_inhibitor = zeros(Float64, np, nt) .+ Inf         # Inhibitor Arc weights matrix
    W_test = zeros(Float64, np, nt)                     # Test Arc weights matrix
    t = zeros(Float64, np)                              # Token vector
    P = zeros(Float64, np, nt)                          # Priority matrix
    pdict = Dict()                                      # dictionary of places and corresponding index
    tdict = Dict()                                      # dictionary of transitions and corresponding index
    cdict = Dict()                                      # dictionary of contexts and corresponding index

    for (i, place) in enumerate(pn.places)
        t[i] = place.token
        pdict[place] = i
    end
    for (i, transition) in enumerate(pn.transitions)
        tdict[transition] = i
    end
    for (i, context) in enumerate(getContexts())
        cdict[context] = i
    end


    C = nothing                                         # Context matrix
    U = zeros(Float64, nc, nt)                          # Update matrix
    for transition in pn.transitions
        c = sign.(genContextRuleMatrix(transition.contexts, cdict, nc))
        C == nothing ? C = [c] : C = [C; [c]]
        for update in transition.updates
            if update.updateValue == on
                U[cdict[update.context], tdict[transition]] = 1
            else
                U[cdict[update.context], tdict[transition]] = -1
            end
        end 
    end
    for arc in pn.arcs
        if arc.from isa Place
            if arc isa NormalArc
                W_o[pdict[arc.from], tdict[arc.to]] = arc.weight
                if !(arc.priority in P[pdict[arc.from]])
                    P[pdict[arc.from], tdict[arc.to]] = arc.priority
                else
                    print("check priority of place ", arc.from)
                end
            elseif arc isa InhibitorArc
                W_inhibitor[pdict[arc.from], tdict[arc.to]] = arc.weight
            else
                W_test[pdict[arc.from], tdict[arc.to]] = arc.weight
            end
        else
            W_i[pdict[arc.to], tdict[arc.from]] = arc.weight
        end
    end
    CompiledPetriNet(W_i, W_o, W_inhibitor, W_test, t, P, C, U, cdict)
end