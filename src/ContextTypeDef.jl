#### Context regarded type definitions ####

"""
    Mixin

Abstract supertype for all mixin types.
Mixins allow context-dependent extension of types.

Concrete mixins should be defined with the `@mixin` macro.
"""
abstract type Mixin end

"""
    Role

Abstract supertype for all role types.
Roles represent context-dependent behaviors or responsibilities.

Concrete roles should be defined within the `@newTeam` and `@newDynamicTeam` macro.
"""
abstract type Role end

"""
    Team

Abstract supertype for all team types.
Teams group roles and their relationships in a relational context.


Concrete teams should be defined within the `@newTeam` and `@newDynamicTeam` macro.
"""
abstract type Team end

"""
    DynamicTeam

Abstract supertype for all dynamic team types.
Dynamic Teams group roles and their relationships in a relational context.
Dynamic teams allow runtime changes in team composition and cardinality.

Concrete teams should be defined within the `@newTeam` and `@newDynamicTeam` macro.
"""
abstract type DynamicTeam end

"""
    AbstractContext

Abstract supertype for all context types and context rules.
"""
abstract type AbstractContext end

"""
    Context <: AbstractContext

Abstract supertype for all concrete context types.
"""
abstract type Context <: AbstractContext end

"""
    ContextGroup

Groups multiple contexts for alternative activation.

Fields:
- `subContexts`: Vector of Contexts in the group.

Example:
    ContextGroup([ctx1, ctx2])
"""
struct ContextGroup
    subContexts::Vector{Context}
end

#### Context rule (condition) regarded type definitions ####

"""
    AbstractContextRule <: AbstractContext

Abstract supertype for all context rule types (And, Or, Not).
"""
abstract type AbstractContextRule <: AbstractContext end

"""
    AndContextRule <: AbstractContextRule

Represents a logical AND between two contexts or context rules.

Fields:
- `c1`, `c2`: Contexts or context rules.

Example:
    AndContextRule(ctx1, ctx2)
"""
struct AndContextRule <: AbstractContextRule
    c1::Union{<:AbstractContext}
    c2::Union{<:AbstractContext}
end

"""
    OrContextRule <: AbstractContextRule

Represents a logical OR between two contexts or context rules.

Fields:
- `c1`, `c2`: Contexts or context rules.

Example:
    OrContextRule(ctx1, ctx2)
"""
struct OrContextRule <: AbstractContextRule
    c1::Union{<:AbstractContext}
    c2::Union{<:AbstractContext}
end

"""
    NotContextRule <: AbstractContextRule

Represents a logical NOT of a context or context rule.

Fields:
- `c`: Context or context rule.

Example:
    NotContextRule(ctx)
"""
struct NotContextRule <: AbstractContextRule
    c::Union{<:AbstractContext}
end