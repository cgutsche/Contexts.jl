# Mixins

## Why Mixins and Roles?

Just like contexts, mixins and roles is a concept to enhance the possibilities for modeling dynamic systems. In classical object-oriented programming (OOP), a person and an employee, both would be represented as a class. But there is a natural difference: while a person is a person for their entire life, a person might become an employee and quit the job multiple times during lifetime. Classical OOP is too restricted to sufficiently represent those dynamics. Roles and mixins is a concept to deal with that.

## Mixins

```@docs
Mixin
@newMixin(context, mixin, attributes)
addMixin(::Context, ::Type, ::Symbol)
assignMixin(::Context, ::Pair)
disassignMixin(::Context, ::Pair)
hasMixin(::Context, obj, ::Type)
getMixins
getObjectsOfMixin(::Context, ::Type)
```

Mixins allow you to extend types with context-dependent behavior. Use `@newMixin` to define mixin types, and `assignMixin`/`disassignMixin` to manage mixin assignments in contexts.

See also: [`assignMixin`](@ref), [`getMixins`](@ref)
