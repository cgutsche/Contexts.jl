# Petri Nets

## Why Petri Nets?

In large-scale systems with many contexts, the control of the activeness of all contexts can be a formidable challenge. Simple logical rules with nested and cascaded `if`-statements might get to complex and messy. Advanced control mechanisms like state charts are sometimes not flexible enough. An intersting candidate for a safe and in the best case even varifyable context control is the Petri net.

A Petri net is a graph consisting of places and transitions that can be connected by arcs. A place can contain tokens and arcs are weighted. A transition can fire if for all places that are connected to the transition with incoming arcs, the token number is greater or equal to the arc's weight. When a transition fires, the the token number of the connected places is reduced by the arcs weight and the token number of places, connected via outgoing arcs is increased by their corresponding weight.

Contexts.jl uses Petri nets to manage context activation and transitions. Petri nets are defined by places, transitions, and arcs. Use the provided types and functions to build, compile, and manage Petri nets for your context logic.

## Contextual Petri Nets

To implement Petri nets that can control contexts, a Petri net similar to the one defined in 
*“Feature petri nets”* by R. Muschevici, D. Clarke and J. Proenca from 2010 is implemented. The Features are context in the case discussed here. Additionally to the firing conditions of a basic Petri net, the firing of a transition can be blocked by the (de)activeness of contexts. Also, the firing can update the context's activeness which allows real context control.

### Places

```@docs
Place
```

A Place should be defined with a name an a start token number:

```julia
p1 = Place("p1", 7)
p2 = Place("p2", 0)
p3 = Place("p3", 1)
```

### Transitions

```@docs
Transition
Update
=>(::Context, ::Contexts.UpdateValue)
```

A transition also has a name an Context that can block the firing as well as a list of context updates that are performed when firing:
```julia
t1 = Transition("t1", C1, [])
t2 = Transition("t2", C2, [Update(C1, off)])
t3 = Transition("t3", nothing, [C1 => off])
```
If there should not be a blocking context, `nothing` should be inserted. A transition without any Updates can be defined by an empty update list.

### Arcs

```@docs
NormalArc
InhibitorArc
TestArc
```

For arcs there are three types:
* NormalArc: a normal Petri nets arc that can connect a place with a transition or the other way around. The third argument is the arc's weight. A normal arc will only allow firing if the token number is greater than or equal to the arc's weight. The 4th argument is a priority that makes sense when there are mutliple outgoing arcs at a place. Priorities can prevent conflicts in the token deletion.
* InhibitorArc: a inhibitor arc can only connect a place to a transition. Inhibitor arcs allow firing when the token number is smaller than the arc's weight and do not cause token decreasement in this place.
* TestArc: a test arc can also only connect a place to a transition. Test arcs allow firing when the token number is larger than the arc's weight and do not cause token decreasement in this place just like an inhibitor arc.


The definition in julia look like the following way:
```julia
arcs = [NormalArc(p1, t1, 2, 1),
		NormalArc(p1, t2, 1, 2), 
		NormalArc(t1, p2, 1, 1), 
		InhibitorArc(p3, t2, 3), 
		TestArc(p2, t2, 2)]
```

### Composing the Petri Net

```@docs
PetriNet
```

When all components are defined, the Petri net object can be defined with a list of contained places, transitions and arcs:
```julia
pn = PetriNet([p1, p2, p3], [t1, t2, t3], arcs)
```

If you want to run the Petri net, such a component-based definition is not very computation friendly. One way to calculate the states of a running Petri net is based on a matrix representation of the Petri net. To get this matrices, the `compile(::PetriNet)` function can be used:

```@docs
compile(::PetriNet)
```

```julia
compiled_pn = compile(pn)
```

```@docs
CompiledPetriNet
```

The weights of the arcs, the tokens and also the contexts, updates and priorities are converted to a matrix (or vector) representation. 


### Running the Petri Net

```@docs
runPN
```

With this representation the states of the Petri net can be calculated step-wise. In the implementation here, every transition, that can fire simultaneously without creating conflicts, fires. If only `N` steps of the Petri net's time evolution should be calculated, use:
```julia
runPN(compiled_pn, N)
```
If you want to let the Petri net run until no transitions can fire anymore, use:

```julia
runPN(compiled_pn)
```
!!! warning "Infinite PN run"
    Be careful, Petri nets do not necessarily need to have reachable dead states. In this case the program would not finish.

### Adding Petri Net to Context Control

Custom defined Petri nets can be added to the context control logic, if the constraints are not sufficient:

```@docs
Contexts.addPNToControlPN(::PetriNet)
```

