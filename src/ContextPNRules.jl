include("ContextDef.jl")

export exclusion, directedExclusion, strongInclusion, weakInclusion, requirement

function exclusion(c1::T1, c2::T2) where {T1, T2 <: Context}
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
	addPNToControlPN(pn)
	true
end

function weakExclusion(c1::T1, c2::T2) where {T1, T2 <: Context}
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
	addPNToControlPN(pn)
	true
end

function directedExclusion(p::Pair{T1, T2}) where {T1, T2 <: Context}
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
	addPNToControlPN(pn)
	true
end

function weakInclusion(p::Pair{T1, T2}) where {T1 <: Union{AbstractContextRule, Context}, T2 <: Context}
	c1 = p[1]
	c2 = p[2]
	p1 = Place("p", 0)
	t1 = Transition("activator", c1, [Update(c2, on)])
	t2 = Transition("deactivator", !c1, [Update(c2, off)])
	arcs = [NormalArc(t1, p1, 1, 1), 
			NormalArc(p1, t2, 1, 1),  
			InhibitorArc(p1, t1, 1)]

	pn = PetriNet([p1], [t1, t2], arcs)
	addPNToControlPN(pn)
	true
end

function strongInclusion(p::Pair{T1, T2}) where {T1 <: Union{OrContextRule, Context}, T2 <: Context}
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
	addPNToControlPN(pn)
	true
end

function requirement(p::Pair{T1, T2}) where {T1 <: Context, T2 <: Union{AbstractContextRule, Context}}
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
	addPNToControlPN(pn)
	true
end
