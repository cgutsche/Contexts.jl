#### Context regarded type definitions ####

abstract type Mixin end

abstract type Role end

abstract type Team end

abstract type DynamicTeam end

abstract type AbstractContext end

abstract type Context <: AbstractContext end

struct ContextGroup
	subContexts::Vector{Context}
end

#### Context rule (condition) regarded type definitions ####

abstract type AbstractContextRule <: AbstractContext end

struct AndContextRule <: AbstractContextRule
	c1::Union{<:AbstractContext}
	c2::Union{<:AbstractContext}
end

struct OrContextRule <: AbstractContextRule
	c1::Union{<:AbstractContext}
	c2::Union{<:AbstractContext}
end

struct NotContextRule <: AbstractContextRule
	c::Union{<:AbstractContext}
end