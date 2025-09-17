
"""
    ContextManagement

Holds all context-related data structures, including:
- `contexts`: All defined contexts.
- `activeContexts`: Currently active contexts.
- `mixins`, `mixinTypeDB`, `mixinDB`: Mixin management.
- `teamsAndRoles`, `roleDB`, `teamDB`, `dynTeamDB`, `dynTeamsAndData`, `dynTeamsProp`: Team and role management.
"""
@with_kw mutable struct ContextManagement
	contexts::Vector{Context} = []
	activeContexts::Vector{Context} = []
	mixins::Dict{Context, Dict{Any, Vector{DataType}}} = Dict()
	mixinTypeDB::Dict{Any, Dict{Context, DataType}} = Dict()
	mixinDB::Dict{Any, Dict{Context, Vector{Any}}} = Dict()
	teamsAndRoles::Dict{Union{Context, Nothing}, Dict{Any, Dict{DataType, DataType}}} = Dict()
	roleDB::Dict{Any, Dict{Union{Context, Nothing}, Dict{Union{Team, DynamicTeam}, Role}}} = Dict()
	teamDB::Dict{Union{Context, Nothing}, Dict{Team, Vector{Dict{DataType, Any}}}} = Dict()
	dynTeamDB::Dict{Union{Context, Nothing}, Dict{DynamicTeam, Dict{DataType, Vector}}} = Dict()
	dynTeamsAndData::Dict{Union{Context, Nothing}, Dict{Any, Dict{DataType, Dict}}} = Dict()
	dynTeamsProp::Dict{Union{Context, Nothing}, Dict{Any, Any}} = Dict()
end

"""
    ContextControl

Stores Petri nets for context control.
- `contextPN`: List of PetriNet objects.
- `contextPNcompiled`: List of compiled PetriNet objects.
"""
@with_kw mutable struct ContextControl
	contextPN::Vector{PetriNet} = [PetriNet()]
	contextPNcompiled::Vector{Union{CompiledPetriNet, Nothing}} = Union{CompiledPetriNet, Nothing}[nothing]
end

global contextManager = ContextManagement()
global contextControler = ContextControl()

#### Functions and macros ####

"""
    setControlPNs(pn::PetriNet, cpn::CompiledPetriNet)

Sets the control PetriNet and its compiled version in the global context controller.
"""
function setControlPNs(pn::PetriNet, cpn::CompiledPetriNet)
	contextControler.contextPN = [pn]
	contextControler.contextPNcompiled = [cpn]
end

"""
    getControlPN()

Returns the current control PetriNet(s) from the global context controller.
"""
function getControlPN()
	contextControler.contextPN
end

"""
    getCompiledControlPN()

Returns the current compiled control PetriNet(s) from the global context controller.
"""
function getCompiledControlPN()
	contextControler.contextPNcompiled
end

"""
    addPNToControlPN(pn::PetriNet; priority::Int=1)

Adds a PetriNet to the control PetriNet list at the given priority.
Compiles and merges the PetriNet as needed.
"""
function addPNToControlPN(pn::PetriNet; priority::Int=1)
	if priority < 1
		error("Priority must be >= 1 but $priority was specified.")
	end
	if length(contextControler.contextPN) < priority
		while priority - length(contextControler.contextPN) > 0
			push!(contextControler.contextPN, PetriNet())
			push!(contextControler.contextPNcompiled, nothing)
		end
	end
	cpn = compile(pn)
	contextControler.contextPN[priority].places == [] ? contextControler.contextPN[priority].places = pn.places : push!(contextControler.contextPN[priority].places, pn.places...)
	contextControler.contextPN[priority].transitions == [] ? contextControler.contextPN[priority].transitions = pn.transitions : push!(contextControler.contextPN[priority].transitions, pn.transitions...)
	contextControler.contextPN[priority].arcs == [] ? contextControler.contextPN[priority].arcs = pn.arcs : push!(contextControler.contextPN[priority].arcs, pn.arcs...)
	contextControler.contextPNcompiled[priority] = mergeCompiledPetriNets(contextControler.contextPNcompiled[priority], cpn)
end

"""
    getContexts()

Returns the list of all defined contexts.
"""
function getContexts()
	contextManager.contexts
end

"""
    addContext(context::T) where {T <: Context}

Adds a new context to the context manager.
"""
function addContext(context::T) where {T <: Context}
	push!(contextManager.contexts, eval(context))
end

"""
    getActiveContexts()

Returns the list of currently active contexts.
"""
function getActiveContexts()
	contextManager.activeContexts
end

"""
    activateContextWithoutPN(context::T) where {T <: Context}

Activates a context without running PetriNet logic.
Mainly used for internal. Should be used with caution
"""
function activateContextWithoutPN(context::T) where {T <: Context}
	if !(context in contextManager.activeContexts) push!(contextManager.activeContexts, context) end
	true
end

"""
    deactivateContextWithoutPN(context::T) where {T <: Context}

Deactivates a context without running PetriNet logic.
Mainly used for internal. Should be used with caution
"""
function deactivateContextWithoutPN(context::T) where {T <: Context}
	deleteat!(contextManager.activeContexts, findall(x->x==context, contextManager.activeContexts))
	true
end

"""
    activateContext(context::T) where {T <: Context}

Activates a context and runs compiled PetriNet.
"""
function activateContext(context::T) where {T <: Context}
	if !(context in contextManager.activeContexts) 
		push!(contextManager.activeContexts, context)
		for pn in contextControler.contextPNcompiled	
			runPN(pn)
		end
	end
	true
end

"""
    deactivateContext(context::T) where {T <: Context}

Deactivates a context and runs compiled PetriNet.
"""
function deactivateContext(context::T) where {T <: Context}
	deleteat!(contextManager.activeContexts, findall(x->x==context, contextManager.activeContexts))
	for pn in contextControler.contextPNcompiled	
		runPN(pn)
	end
	true
end

"""
    deactivateAllContexts()

Deactivates all contexts.
Should be used with caution as it does not run PetriNet logic.
"""
function deactivateAllContexts()
	contextManager.activeContexts = []
	true
end


"""
    isActive(context::T) where {T <: Context}

Checks if a context is currently active.
Returns `true` if active, `false` otherwise.
"""
function isActive(context::T) where {T <: Context}
	context in contextManager.activeContexts
end

