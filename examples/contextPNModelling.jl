include("../src/Contexts.jl")
using .Contexts

p1 = Place("p1", 7)
p2 = Place("p2", 0)
p3 = Place("p3", 1)
@newContext C1
@newContext C2
@newContext C3
t1 = Transition("t1", C1, [])
t2 = Transition("t2", C1 & C2, [])
t3 = Transition("t3", nothing, [Update(C1, off)])
arcs = [NormalArc(p1, t1, 2, 1), 
		NormalArc(t1, p2, 1, 1), 
		NormalArc(p2, t3, 2, 1), 
		NormalArc(t1, p3, 1, 1), 
		NormalArc(t2, p1, 1, 1), 
		InhibitorArc(p3, t2, 3)]


a = !(C1 & (C2 | C3))
println(a)
b = reduceRuleToElementary(a)
println(b)

pn = PetriNet([p1, p2, p3], [t1, t2, t3], arcs)
compiled_pn = compile(pn)

println()
println("inital token:", compiled_pn.tokenVector)
println()
println("0 ", getActiveContexts())

runPN(compiled_pn)
println("inital token after PN run:", compiled_pn.tokenVector)
println("1 ", getActiveContexts())
activateContext(C1)
println()
println("inital token after reactivation of C1:", compiled_pn.tokenVector)
println("2 ", getActiveContexts())

runPN(compiled_pn)
println()
println("3 ", getActiveContexts())
runPN(compiled_pn)
println("inital token after PN run:", compiled_pn.tokenVector)