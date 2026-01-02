
"""
    Context management is done by using Closures to encapsulate the existence 
	and activeness of contexts. The main functions to manage contexts are defined here.
"""
function __contextManagement()
	contexts::Vector{Context} = []
	activeContexts::Vector{Context} = []
	function addContext(context::Context)
		push!(contexts, context)
		true
	end
	function getContexts()
		contexts
	end
	function getActiveContexts()
		activeContexts
	end
	function activateContext(context::T) where {T <: Context}
		if !(context in activeContexts) 
			push!(activeContexts, context)
			for pn in getCompiledControlPN()
				runPN(pn)
			end
		end
		true
	end
	function activateContextWithoutPN(context::T) where {T <: Context}
		if !(context in activeContexts) push!(activeContexts, context) end
		true
	end
	function deactivateContext(context::T) where {T <: Context}
		deleteat!(activeContexts, findall(x->x==context, activeContexts))
		for pn in getCompiledControlPN()
			runPN(pn)
		end
		true
	end
	function deactivateContextWithoutPN(context::T) where {T <: Context}
		deleteat!(activeContexts, findall(x->x==context, activeContexts))
		true
	end
	function deactivateAllContexts()
		activeContexts = []
		true
	end
	return (
		getContexts,
		getActiveContexts,
		addContext,
		activateContext,
		activateContextWithoutPN,
		deactivateContext,
		deactivateContextWithoutPN,
		deactivateAllContexts
	)
end

"""
    Context Control with Petri nets is done by using Closures to encapsulate defined
	Petro nets. Function to add and get Petri nets are defined.

"""
@with_kw mutable struct ContextControl
	contextPN::Vector{PetriNet} = [PetriNet()]
	contextPNcompiled::Vector{Union{CompiledPetriNet, Nothing}} = Union{CompiledPetriNet, Nothing}[nothing]
end

function __contextControl()
	contextPN::Vector{PetriNet} = [PetriNet()]
	contextPNcompiled::Vector{Union{CompiledPetriNet, Nothing}} = Union{CompiledPetriNet, Nothing}[nothing]
	function setControlPNs(pn::PetriNet, cpn::CompiledPetriNet)
		contextPN = [pn]
		contextPNcompiled = [cpn]
	end
	function getControlPN()
		contextPN
	end
	function getCompiledControlPN()
		contextPNcompiled
	end
	function addPNToControlPN(pn::PetriNet; priority::Int=1)
		if priority < 1
			error("Priority must be >= 1 but $priority was specified.")
		end
		if length(contextPN) < priority
			while priority - length(contextPN) > 0
				push!(contextPN, PetriNet())
				push!(contextPNcompiled, nothing)
			end
		end
		cpn = compile(pn)
		contextPN[priority].places == [] ? contextPN[priority].places = pn.places : push!(contextPN[priority].places, pn.places...)
		contextPN[priority].transitions == [] ? contextPN[priority].transitions = pn.transitions : push!(contextPN[priority].transitions, pn.transitions...)
		contextPN[priority].arcs == [] ? contextPN[priority].arcs = pn.arcs : push!(contextPN[priority].arcs, pn.arcs...)
		contextPNcompiled[priority] = mergeCompiledPetriNets(contextPNcompiled[priority], cpn)
	end
	return (
		setControlPNs,
		getControlPN,
		getCompiledControlPN,
		addPNToControlPN
	)
end


#### Functions and macros ####


const setControlPNs,
		getControlPN,
		getCompiledControlPN,
		addPNToControlPN = __contextControl()

"""
    setControlPNs(pn::PetriNet, cpn::CompiledPetriNet)

Sets the control PetriNet and its compiled version in the global context controller.
"""

"""
    getControlPN()

Returns the current control PetriNet(s) from the global context controller.
"""

"""
    getCompiledControlPN()

Returns the current compiled control PetriNet(s) from the global context controller.
"""


"""
    addPNToControlPN(pn::PetriNet; priority::Int=1)

Adds a PetriNet to the control PetriNet list at the given priority.
Compiles and merges the PetriNet as needed.
"""

const getContexts,
	  getActiveContexts,
	  addContext,
	  activateContext,
	  activateContextWithoutPN,
	  deactivateContext,
	  deactivateContextWithoutPN,
	  deactivateAllContexts = __contextManagement()


"""
    getContexts()

Returns the list of all defined contexts.
"""

"""
    addContext(context::T) where {T <: Context}

Adds a new context to the context manager.
"""

"""
    getActiveContexts()

Returns the list of currently active contexts.
"""

"""
    activateContextWithoutPN(context::T) where {T <: Context}

Activates a context without running PetriNet logic.
Mainly used for internal. Should be used with caution
"""

"""
    deactivateContextWithoutPN(context::T) where {T <: Context}

Deactivates a context without running PetriNet logic.
Mainly used for internal. Should be used with caution
"""

"""
    activateContext(context::T) where {T <: Context}

Activates a context and runs compiled PetriNet.
"""

"""
    deactivateContext(context::T) where {T <: Context}

Deactivates a context and runs compiled PetriNet.
"""

"""
    deactivateAllContexts()

Deactivates all contexts.
Should be used with caution as it does not run PetriNet logic.
"""

"""
    isActive(context::T) where {T <: Context}

Checks if a context is currently active.
Returns `true` if active, `false` otherwise.
"""
function isActive(context::Context)
	context in getActiveContexts()
end

