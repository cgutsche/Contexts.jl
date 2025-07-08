abstract type Constraint end

struct Exclusion <: Constraint
    contexts::Vector{Context}
end
struct Requirement <: Constraint
    contexts::Pair{Context, AbstractContext}
end
struct Inclusion <: Constraint
    contexts::Pair{AbstractContext, Context}
end
struct Alternative <: Constraint
    contexts::Vector{Context}
end
@with_kw mutable struct ContextRuleManagement
	constraints::Vector{Constraint} = []
end
contextRuleManager = ContextRuleManagement()

"""
Note that constraints and Rules are not the same thing.
A Constraint must always be true, e.g. An Exclusion between to ru
"""

addConstraint(constraint::Constraint) = push!(contextRuleManager.constraints, constraint)
getConstraints() = contextRuleManager.constraints

"""
    exclusion(c1::T1, c2::T2) where {T1, T2 <: Context}

Creates a strict mutual exclusion rule between two contexts. When one context is active,
the other context will be forced to deactivate and cannot be activated.

Arguments:
- `c1`, `c2`: Two contexts of any type that inherits from Context

Returns `true` after creating and adding the Petri net rule to the control network.
"""
function exclusion(c1::T1, c2::T2; priority::Int=1) where {T1, T2 <: Context}
	p1 = Place("p1", 0)
	t1 = Transition("activator1", c1, [])
	t2 = Transition("updater1", c2, [Update(c2, off)])
	t3 = Transition("deactivator1", !c1, [])
	p2 = Place("p2", 0)
	t4 = Transition("activator2", c2, [])
	t5 = Transition("updater2", c1, [Update(c1, off)])
	t6 = Transition("deactivator2", !c2, [])
	arcs = [NormalArc(t1, p1, 1, 1), 
			TestArc(p1, t2, 1), 
			NormalArc(p1, t3, 1, 1),  
			InhibitorArc(p1, t1, 1),
			InhibitorArc(p1, t4, 1),
			NormalArc(t4, p2, 1, 1), 
			TestArc(p2, t5, 1), 
			NormalArc(p2, t6, 1, 1),  
			InhibitorArc(p2, t4, 1),
			InhibitorArc(p2, t1, 1)]

	pn = PetriNet([p1, p2], [t1, t2, t3, t4, t5, t6], arcs)
	addPNToControlPN(pn; priority=priority)
	addConstraint(Exclusion([c1, c2]))
	true
end

"""
    weakExclusion(c1::T1, c2::T2) where {T1, T2 <: Context}

Creates a weak mutual exclusion rule between two contexts. When one context becomes active,
it will deactivate the other context, but the other context can be reactivated.

Arguments:
- `c1`, `c2`: Two contexts of any type that inherits from Context

Returns `true` after creating and adding the Petri net rule to the control network.
"""
function weakExclusion(c1::T1, c2::T2; priority::Int=1) where {T1, T2 <: Context}
	p1 = Place("p1", 0)
	t1 = Transition("activator1", c1, [])
	t2 = Transition("updater1", c2, [Update(c1, off)])
	t3 = Transition("deactivator1", !c1, [])
	p2 = Place("p2", 0)
	t4 = Transition("activator2", c2, [])
	t5 = Transition("updater2", c1, [Update(c2, off)])
	t6 = Transition("deactivator2", !c2, [])
	arcs = [NormalArc(t1, p1, 1, 1),
			InhibitorArc(p1, t1, 1),
			NormalArc(p1, t3, 1, 1),  
			NormalArc(p1, t2, 1, 1),
			NormalArc(t2, p2, 1, 1),
			InhibitorArc(p1, t4, 1),
			NormalArc(t4, p2, 1, 1), 
			InhibitorArc(p2, t4, 1), 
			NormalArc(p2, t6, 1, 1),  
			NormalArc(p2, t5, 1, 1),
			NormalArc(t5, p1, 1, 1),
			InhibitorArc(p2, t1, 1)]

	pn = PetriNet([p1, p2], [t1, t2, t3, t4, t5, t6], arcs)
	addPNToControlPN(pn; priority=priority)
	addConstraint(Exclusion([c1, c2]))
	true
end

"""
    weakExclusion(c1::T1, c2::T2, args...) where {T1, T2 <: Context}

Creates weak mutual exclusion rules between multiple contexts. Applies weakExclusion
to every pair of contexts in the provided list.

Arguments:
- `c1`, `c2`: First two contexts
- `args...`: Additional contexts

Returns `true` after creating all Petri net rules.
"""
function weakExclusion(c1::T1, c2::T2, args...; priority::Int=1) where {T1, T2 <: Context}
	contextList::Vector{<:Context} = [c1, c2, args...] 
	for i in eachindex(contextList)[1:end-1]
		for j in eachindex(contextList)[i+1:end]
			weakExclusion(contextList[i], contextList[j]; priority=priority)
		end
	end
	addConstraint(Exclusion(contextList))
	true
end

"""
    directedExclusion(p::Pair{T1, T2}) where {T1, T2 <: Context}

Creates a one-way exclusion rule. When the first context becomes active,
it forces the second context to deactivate.

Arguments:
- `p`: A Pair where first element is the controlling context and second is the controlled context

Returns `true` after creating and adding the Petri net rule.
"""
function directedExclusion(p::Pair{T1, T2}; priority::Int=1) where {T1, T2 <: Context}
	c1 = p[1]
	c2 = p[2]
	p1 = Place("p", 0)
	t1 = Transition("activator", c1, [])
	t2 = Transition("updater", c2, [Update(c2, off)])
	t3 = Transition("deactivator", !c1, [])
	arcs = [NormalArc(t1, p1, 1, 1), 
			TestArc(p1, t2, 1), 
			NormalArc(p1, t3, 1, 1),  
			InhibitorArc(p1, t1, 1)]

	pn = PetriNet([p1], [t1, t2, t3], arcs)
	addPNToControlPN(pn; priority=priority)
	true
end

"""
    weakInclusion(p::Pair{T1, T2}) where {T1 <: Union{AbstractContextRule, Context}, T2 <: Context}

Creates a weak inclusion rule. When the first context/rule becomes active,
it activates the second context. When first becomes inactive, it deactivates the second.

Arguments:
- `p`: A Pair where first element can be a Context or ContextRule, and second must be a Context

Returns `true` after creating and adding the Petri net rule.
"""
function weakInclusion(p::Pair{T1, T2}; priority::Int=1) where {T1 <: Union{AbstractContextRule, Context}, T2 <: Context}
	c1 = p[1]
	c2 = p[2]
	p1 = Place("p", 0)
	t1 = Transition("activator", c1, [Update(c2, on)])
	t2 = Transition("deactivator", !c1, [Update(c2, off)])
	arcs = [NormalArc(t1, p1, 1, 1), 
			NormalArc(p1, t2, 1, 1),  
			InhibitorArc(p1, t1, 1)]

	pn = PetriNet([p1], [t1, t2], arcs)
	addPNToControlPN(pn; priority=priority)
	true
end

"""
    strongInclusion(p::Pair{T1, T2}) where {T1 <: Union{OrContextRule, Context}, T2 <: Context}

Creates a strong inclusion rule. Similar to weak inclusion, but also deactivates the first context
if the second context becomes inactive while first is active.

Arguments:
- `p`: A Pair where first element must be either a Context or OrContextRule, second must be a Context

Returns `true` after creating and adding the Petri net rule.
Throws an error if first element contains non-OR operations.
"""
function strongInclusion(p::Pair{T1, T2}; priority::Int=1) where {T1 <: Union{OrContextRule, Context}, T2 <: Context}
	function checkOR(c1::Context) end
	function checkOR(c1::OrContextRule)
		if c1 isa OrContextRule
			checkOR(c1.c1)
			checkOR(c1.c2)
		end
	end
	function checkOR(c1::AbstractContextRule)
		error("First element of strongInclusion argument may only include contexts or contexts linked with OR operators.")
	end
	c1 = p[1]
	c2 = p[2]

	checkOR(c1)

	p1 = Place("p", 0)
	t1 = Transition("activator", c1, [Update(c2, on)])
	t2 = Transition("deactivator", !c1, [Update(c2, off)])
	t3 = Transition("deactivator", (!c2)&c1, [Update(c, off) for c in getContextsOfRule(c1)])
	arcs = [NormalArc(t1, p1, 1, 1), 
			NormalArc(p1, t2, 1, 1), 
			NormalArc(p1, t3, 1, 1),  
			InhibitorArc(p1, t1, 1)]

	pn = PetriNet([p1], [t1, t2, t3], arcs)
	addPNToControlPN(pn; priority=priority)
	addConstraint(Inclusion([c1, c2]))
	true
end

"""
    requirement(p::Pair{T1, T2}) where {T1 <: Context, T2 <: Union{AbstractContextRule, Context}}

Creates a requirement rule. The first context can only be active if the second context/rule is active.
If second becomes inactive, first is forced to deactivate.

Arguments:
- `p`: A Pair where first element must be a Context, second can be Context or ContextRule

Returns `true` after creating and adding the Petri net rule.
"""
function requirement(p::Pair{T1, T2}; priority::Int=1) where {T1 <: Context, T2 <: Union{AbstractContext}}
	c1 = p[1]
	c2 = p[2]
	p1 = Place("p", 0)
	t1 = Transition("activator", c1, [])
	t2 = Transition("deactivator", !c2, [Update(c1, off)])
	t3 = Transition("deactivator", !c1, [])
	arcs = [NormalArc(t1, p1, 1, 1), 
			NormalArc(p1, t2, 1, 2),
			NormalArc(p1, t3, 1, 1),  
			InhibitorArc(p1, t1, 1)]
	pn = PetriNet([p1], [t1, t2, t3], arcs)
	addPNToControlPN(pn; priority=priority)
	addConstraint(Requirement(c1 => c2))
	true
end

"""
    alternative(contexts::Context...)

Creates a rule ensuring exactly one context is active at all times from the given set of contexts.
When one context is activated, any previously active context is deactivated. If the active
context is deactivated, the deactivation is prevented.

Arguments:
- `contexts...`: Variable number of Context arguments

Returns `true` after creating and adding the Petri net rule to the control network.
Throws an error if less than 2 contexts are provided.
"""
function alternative(contexts::Context...; priority::Int=1)
	if length(contexts) < 2
		error("alternative() requires at least 2 contexts")
	end
	for c in contexts
		if length(filter(x -> c==x, contexts)) > 1
			error("alternative() contains $c more thean once.")
		end
	end

	places = []
	transitions = []
	arcs = []

	# For each context, create activation and deactivation transitions
	for (i, ctx) in enumerate(contexts)
		# Create a place to track if this context is active
		p_active = Place("p_active_$i", isActive(ctx) ? 1 : 0)  # Initialize first context as active
		push!(places, p_active)

		# Activation transition: Activates this context and deactivates others
		t_activate = Transition("activator_$i", ctx, [Update(c, c === ctx ? on : off) for c in contexts])
		
		# Deactivation transition
		t_deactivate = Transition("deactivator_$i", !ctx, [])
		
		# Reactivation transition: Fires when no context is active
		oneContextActive = reduce(|, [c for c in contexts])
		t_reactivate = Transition("reactivator_$i", !oneContextActive, [Update(ctx, on)])
		
		push!(transitions, t_activate, t_deactivate, t_reactivate)
		
		# Arcs for activation mechanism
		push!(arcs, 
			NormalArc(t_activate, p_active, 1, 1),
			InhibitorArc(p_active, t_activate, 1),  # Prevent activation if already active
			NormalArc(p_active, t_deactivate, 1, 1),  # Remove active marker on deactivation
			TestArc(p_active, t_reactivate, 1))  # Only reactivate the last active context
	end

	pn = PetriNet(places, transitions, arcs)
	addPNToControlPN(pn; priority=priority)
	addConstraint(Alternative(collect(contexts)))
	true
end
