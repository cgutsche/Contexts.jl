# Contexts

## Why Contexts?

Contexts are an interesting approach to achieve dynamic behavior of objects. Let's think of a program, controling a robot. A robot may act differently when a human is nearby or not. Another example is an energy system that should behave differently on a sunny summer day than on a cloudy and snowy winter day. The context, in which such a program runs could be defined as `sunnyDay`, `warmWeather` or `humanNearby`. It describes the properties of the environment or situation in which the software runs.


## Context Definition in Contexts.jl

In `Contexts.jl`, `Context` is an abstract type.

```@docs
Context
```
By defining a new Context, a new struct `<ContextName>ContextType` will be created as a subtype of `Context`:

```julia
struct <ContextName>ContextType <: Context end
```

and then, a singleton object of this type is defined:
```julia
 <ContextName> = <ContextName>ContextType()
```

In that way, contexts are available as arguments of methods to be utilized by the multiple dispatch.

## Context Usage

### Defining new Contexts with @newContext Macro

To create a new context, use the `@newContext` macro:
```julia
@newContext Context1
```

```@docs
@newContext
```

### Context-dependent Behavior with the @context Macro

Since `Context1` is now available as a variable representing a value of the context-specific type `Context1ContextType`, it can be used in function arguments and using the multiple dispatch, context-dependent behavior is realized. For easier Syntax, the macro `@context` is defined. Depending on its usage, it fulfills different tasks.

Calling `@context` on a function definition will define a context depening function, by adding an attribute of type `Context1ContextType` as the first function argument:
```julia
@context Context1 function HelloWorld()
	println("Hello World in Context 1!")
end 
```
```julia
@context Context2 function HelloWorld()
	println("Hello World in Context 2!")
end 
```

Calling `@context` on a function (or macro) call will add the context as the first attribute.
```julia
@context Context1 HelloWorld()
```
will therefore print `Hello World in Context 1!` and 
```julia
@context Context2 HelloWorld()
```
will print `Hello World in Context 2!`. This also means that executing `HelloWorld(Context1)` would also print `Hello World in Context 1!`. Also the variable `context` is available in functions.

```@docs
@context
```

!!! tip "Functions for multiple contexts"
    It is also possible to use a tuple of multiple contexts:
    ```julia
    @context (Context1, Context2) HelloWorld()
    ```

## Activeness of Contexts

When programming with contexts, you might want to define all possible contexts at the beginning, but only some of them are active at the same time. Therefore the contexts in Contexts.jl can be activated and deactivated by  
```@docs
activateContext
deactivateContext
```
After the definition of a context, the context will be deactive. When a clean start is needed, the function
```julia
deactivateAllContexts()
```
can help.

Note, that functions can of course also run when a deactivated context is handed as a function argument. The activeness of a context can be checked with:
```@docs
isActive(::Context)
```
This can be used in `if`-statements to avoid calling functions with deactivated contexts or to have varying functionality depending on activeness.

```julia
@context Context1 function printContext()
	isActive(context) ? println("Context is active") : println("Context is not active")
end
```
The macro `@activeContext` only calls the function if the context is active:
```@docs
@activeContext
```

!!! tip "Context Groups and State machines"
    A more conventient way to work with contexts and context-specific functions is via context groups and state machines, see [`ContextGroup`](@ref) and [`ContextStateMachine`](@ref).

As explained in [Context Modeling](@ref), activating contexts will run Petri nets that check the compliance of the contexts' activeness with constraints. However, it is also possible to (de-)activate contexts without the Petri net. This can be helpful to reach valid initial states.

```@docs
Contexts.activateContextWithoutPN
Contexts.deactivateContextWithoutPN
```

!!! warning "(De)Activating contexts without PN"
    (de)activating contexts without Petri nets can lead to reaching invalid states that are not correctly healed after running the PN.


## Boolean Expressions on Contexts

The `|`,  `&` and  `!` operators can be used to create Boolean expressions on Contexts.

```@docs
Contexts.OrContextRule
Contexts.AndContextRule
Contexts.NotContextRule
Base.:|(::Contexts.AbstractContext, ::Contexts.AbstractContext)
Base.:&(::Contexts.AbstractContext, ::Contexts.AbstractContext)
Base.:!(::Contexts.AbstractContext)
```

---

Those expressions can be checked for activeness.

```@docs
isActive(::Contexts.AbstractContextRule)
```
```julia
isActive(C1 & (C2 | !C3)) # returns true or false
```
