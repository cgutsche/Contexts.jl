"""
    isActive(contextRule::T) where {T <: AbstractContextRule}

Evaluates whether a context rule is active.
Supports And, Or, and Not context rules.

Arguments:
- `contextRule`: An AbstractContextRule (And, Or, Not)

Returns `true` if the rule is active, `false` otherwise.

Example:
    isActive(C1 & C2)
"""
function isActive(contextRule::T) where {T <: AbstractContextRule}
	if contextRule isa AndContextRule
		isActive(contextRule.c1) & isActive(contextRule.c2)
	elseif contextRule isa OrContextRule
		isActive(contextRule.c1) | isActive(contextRule.c2)
	else
		!isActive(contextRule.c)
	end
end


"""
    getContextsOfRule(context::Context)

Helper function.
Returns a vector containing the given context.

Arguments:
- `context`: A Context instance

Returns a vector with the context.

Example:
    getContextsOfRule(ctx)
"""
function getContextsOfRule(context::Context)
	[context]
end

"""
    getContextsOfRule(contextRule::T) where {T <: AbstractContextRule}

Returns all contexts involved in a context rule, recursively.

Arguments:
- `contextRule`: An AbstractContextRule (And, Or, Not)

Returns a vector of contexts.

Example:
    getContextsOfRule(C1 & (C2 | !C3))
"""
function getContextsOfRule(contextRule::T) where {T <: AbstractContextRule}
	contexts = []
	if ((contextRule isa AndContextRule) | (contextRule isa OrContextRule))
		if typeof(contextRule.c1) <: AbstractContextRule
			append!(contexts, getContextsOfRule(contextRule.c1))
		else
			append!(contexts, [contextRule.c1])
		end
		if typeof(contextRule.c2) <: AbstractContextRule
			append!(contexts, getContextsOfRule(contextRule.c2))
		else
			append!(contexts, [contextRule.c2])
		end
	else
		if typeof(contextRule.c) <: AbstractContextRule
			append!(contexts, getContextsOfRule(contextRule.c))
		else
			append!(contexts, [contextRule.c])
		end
	end
	union(contexts)
end

"""
    isActive(context::Nothing)

Returns `true` for a Nothing context (used for default cases).

Arguments:
- `context`: Nothing

Returns `true`.

Example:
    isActive(nothing)
"""
function isActive(context::Nothing)
	true
end

"""
    Base.:&(c1::CT1, c2::CT2) where {CT1, CT2 <: Union{AbstractContext}}

Creates an AndContextRule from two contexts or context rules using the & operator.

Arguments:
- `c1`, `c2`: Contexts or context rules

Returns an AndContextRule.

Example:
    ctx1 & ctx2
"""
function Base.:&(c1::CT1, c2::CT2) where {CT1, CT2 <: Union{AbstractContext}}
    AndContextRule(c1, c2)
end

"""
    Base.:|(c1::CT1, c2::CT2) where {CT1, CT2 <: Union{AbstractContext}}

Creates an OrContextRule from two contexts or context rules using the | operator.

Arguments:
- `c1`, `c2`: Contexts or context rules

Returns an OrContextRule.

Example:
    ctx1 | ctx2
"""
function Base.:|(c1::CT1, c2::CT2) where {CT1, CT2 <: Union{AbstractContext}}
    OrContextRule(c1, c2)
end

"""
    Base.:!(c::CT) where {CT <: Union{AbstractContext}}

Creates a NotContextRule from a context or context rule using the ! operator.

Arguments:
- `c`: Context or context rule

Returns a NotContextRule.

Example:
    !ctx
"""
function Base.:!(c::CT) where {CT <: Union{AbstractContext}}
    NotContextRule(c)
end