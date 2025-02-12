include("../src/Contexts.jl")
using .Contexts

"""
This example show how Petri Nets can be used with priotities.
Priorites tell the context control, which PN needs to be run first.

This can be helpful to avoid unwanted behavior caused by the concurrency of the Petri net.

Lets look at two examples with the same structure:
3 Contexts C1, C2, C3
C1 and C2 exclude each other (one can not be activated if the other is active)
C2 and C3 weakly exclude each other (C3 gets deactivated if C2 gets activated and vice versa)

Note that the Petri nets DO NOT check if a contexts can be activated but if an activation was valid and will then get the system into a valid configuration again.

If you run the code, you will see that the versions with and without specified priorities behave differently.
(C1x is modeled without different priorities, C2x is modelled with the exclusion as prio 1 and weak exclusion as prio 2)

Without different priorities:
C12 get activated. The exclusion and weak exclusion rule will be checked simultaneously.
Therefore, C13 and C12 will be deactivated.

With different priorities:
C12 get activated. The exclusion rule will be checked first.
Therefore, C12 will be deactivated again. Afterwards the weak exclusion is checked. Since C12 is not active anymore, C13 stays active.

What is more correct? Well, this depends on what you want to model.

"""

@newContext C11, C12, C13
@newContext C21, C22, C23

exclusion(C11, C12)
exclusion(C21, C22)

weakExclusion(C12, C13)
weakExclusion(C22, C23; priority = 2)

activateContext(C11)
activateContext(C21)
activateContext(C13)
activateContext(C23)

println(getActiveContexts())
activateContext(C12)
activateContext(C22)
println(getActiveContexts())