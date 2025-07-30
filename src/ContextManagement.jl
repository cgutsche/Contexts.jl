using Parameters

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

@with_kw mutable struct ContextControl
	contextPN::Vector{PetriNet} = [PetriNet()]
	contextPNcompiled::Vector{Union{CompiledPetriNet, Nothing}} = Union{CompiledPetriNet, Nothing}[nothing]
end

global contextManager = ContextManagement()
global contextControler = ContextControl()

#### Functions and macros ####

function setControlPNs(pn::PetriNet, cpn::CompiledPetriNet)
	contextControler.contextPN = [pn]
	contextControler.contextPNcompiled = [cpn]
end

function getControlPN()
	contextControler.contextPN
end

function getCompiledControlPN()
	contextControler.contextPNcompiled
end

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


function getContexts()
	contextManager.contexts
end

function addContext(context::T) where {T <: Context}
	push!(contextManager.contexts, eval(context))
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
	if !(context in contextManager.activeContexts) 
		push!(contextManager.activeContexts, context)
		for pn in contextControler.contextPNcompiled	
			runPN(pn)
		end
	end
	true
end

function deactivateContext(context::T) where {T <: Context}
	deleteat!(contextManager.activeContexts, findall(x->x==context, contextManager.activeContexts))
	for pn in contextControler.contextPNcompiled	
		runPN(pn)
	end
	true
end

function deactivateAllContexts()
	contextManager.activeContexts = []
	true
end

function isActive(context::T) where {T <: Context}
	context in contextManager.activeContexts
end

