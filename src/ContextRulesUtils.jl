function isActive(contextRule::T) where {T <: AbstractContextRule}
	if contextRule isa AndContextRule
		isActive(contextRule.c1) & isActive(contextRule.c2)
	elseif contextRule isa OrContextRule
		isActive(contextRule.c1) | isActive(contextRule.c2)
	else
		!isActive(contextRule.c)
	end
end


function getContextsOfRule(context::Context)
	[context]
end

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

function isActive(context::Nothing)
	true
end

function Base.:&(c1::CT1, c2::CT2) where {CT1, CT2 <: Union{AbstractContext}}
    AndContextRule(c1, c2)
end

function Base.:|(c1::CT1, c2::CT2) where {CT1, CT2 <: Union{AbstractContext}}
    OrContextRule(c1, c2)
end

function Base.:!(c::CT) where {CT <: Union{AbstractContext}}
    NotContextRule(c)
end