# Context Modeling

## Context Constraints

Context constraints define relationships between contexts, such as mutual exclusion, requirements, and alternatives. Use these functions to model rules for context activation. Note that, e.g., an exclusion between two contexts C1 and C2 does not mean that C1 will not be activated if C2 is already active. Instead, after activating C1, a Petri net will check if this activation complies with the defined constraints. If constraints are not fulfilled, the Petri net will heal the state by deactivating it again.

The following constraints are defined:

```@docs
exclusion(::Context, ::Context)
weakExclusion(::Context, ::Context)
weakExclusion(::Context, ::Context, args...)
directedExclusion(::Pair{<:Context, <:Context})
requirement
Contexts.weakExclusion(::Union{Tuple{T2}, Tuple{T1}, Tuple{T1, T2}} where {T1, T2<:Context})
Contexts.weakExclusion(::Union{Tuple{T2}, Tuple{T1}, Tuple{T1, T2, Vararg{Any}}} where {T1, T2<:Context})
strongInclusion(::Pair{<:Union{OrContextRule, Context}, <:Context})
alternative(contexts::Context...)
```

---

## Context Groups

```@docs
ContextGroup
ContextGroup(::Context...)
```

Context groups allow you to bundle contexts for alternative activation. Only one context in a group can be active at a time.

Calling a context group returns the currently active context of this group. This can be helpful in combination with the `@context` macro:



---

## Context State Machines

```@docs
@ContextStateMachine(name, body)
ContextStateMachine
```

Context state machines allow you to model transitions between contexts based on variable values and transition rules. Use the `@ContextStateMachine` macro to define a state machine, and `checkStateMachineCondition` to enforce transitions.
