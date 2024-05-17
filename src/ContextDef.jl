using Parameters

#### Context regarded type definitions ####

abstract type Mixin end

abstract type Role end

abstract type Team end

abstract type Context end

#### Context rule (condition) regarded type definitions ####

abstract type AbstractContextRule end

struct AndContextRule <: AbstractContextRule
	c1::Union{<:Context, <:AbstractContextRule}
	c2::Union{<:Context, <:AbstractContextRule}
end

struct OrContextRule <: AbstractContextRule
	c1::Union{<:Context, <:AbstractContextRule}
	c2::Union{<:Context, <:AbstractContextRule}
end

struct NotContextRule <: AbstractContextRule
	c::Union{<:Context, <:AbstractContextRule}
end

#### Petri Net type definitions ####

abstract type PNObject end

mutable struct Place <: PNObject 
    const name::String
    token::Real
end 

@enum UpdateValue on off

mutable struct Update
    context::Context
    updateValue::UpdateValue
end 

function Base.:(=>)(context::Context, updateValue::UpdateValue)
	Update(context, updateValue)
end

struct Transition <: PNObject 
    name::String
    contexts::Union{<:Context, Any, <:AbstractContextRule}
    updates::AbstractArray{Update}
end

abstract type Arc end

Base.@kwdef mutable struct NormalArc <: Arc
    const from::PNObject
    const to::PNObject
    weight::Real
    priority::Int = 0
end
mutable struct InhibitorArc <: Arc
    const from::Place
    const to::Transition
    weight::Real
end
mutable struct TestArc <: Arc
    const from::Place
    const to::Transition
    weight::Real
end

Base.@kwdef mutable struct PetriNet
    places::Vector{Union{Any, Place}} = []
    transitions::Vector{Union{Any, Transition}} = []
    arcs::Vector{Union{Any, <:Arc}} = []
end

mutable struct CompiledPetriNet
    WeightMatrix_in::Matrix
    WeightMatrix_out::Matrix
    WeightMatrix_inhibitor::Matrix
    WeightMatrix_test::Matrix
    tokenVector::Vector
    PrioritiesMatrix::Matrix
    ContextMatrices::Vector
    UpdateMatrix::Matrix
    ContextMap::Dict
end

#### Management definitions ####

@with_kw mutable struct ContextManagement
	contexts::Vector{Context} = []
	activeContexts::Vector{Context} = []
	mixins::Dict{Context, Dict{Any, Vector{DataType}}} = Dict()
	mixinTypeDB::Dict{Any, Dict{Context, DataType}} = Dict()
	mixinDB::Dict{Any, Dict{Context, Vector{Any}}} = Dict()
	teamsAndRoles::Dict{Context, Dict{Any, Dict{DataType, DataType}}} = Dict()
	roleDB::Dict{Any, Dict{Context, Dict{Any, Role}}} = Dict()
	teamDB::Dict{Context, Dict{Any, Vector{Dict{DataType, Any}}}} = Dict()
end

@with_kw mutable struct ContextControl
	contextPN::PetriNet = PetriNet()
	contextPNcompiled::Union{CompiledPetriNet, Nothing} = nothing
end

global contextManager = ContextManagement()
global contextControler = ContextControl()

#### Functions and macros ####

function setControlPNs(pn::PetriNet, cpn::CompiledPetriNet)
	contextControler.contextPN = pn
	contextControler.contextPNcompiled = cpn
end

function getControlPN()
	contextControler.contextPN
end

function getCompiledControlPN()
	contextControler.contextPNcompiled
end

function addPNToControlPN(pn::PetriNet)
	cpn = compile(pn)
	contextControler.contextPN.places == [] ? contextControler.contextPN.places = pn.places : push!(contextControler.contextPN.places, pn.places...)
	contextControler.contextPN.transitions == [] ? contextControler.contextPN.transitions = pn.transitions : push!(contextControler.contextPN.transitions, pn.transitions...)
	contextControler.contextPN.arcs == [] ? contextControler.contextPN.arcs = pn.arcs : push!(contextControler.contextPN.arcs, pn.arcs...)
	contextControler.contextPNcompiled = mergeCompiledPetriNets(contextControler.contextPNcompiled, cpn)
end

function getContexts()
	contextManager.contexts
end

function addContext(context::T) where {T <: Context}
	push!(contextManager.contexts, eval(context))
end

function getActiveContexts()
	contextManager.activeContexts
end

function activateContextWithoutPN(context::T) where {T <: Context}
	if !(context in contextManager.activeContexts) push!(contextManager.activeContexts, context) end
	true
end

function deactivateContextWithoutPN(context::T) where {T <: Context}
	deleteat!(contextManager.activeContexts, findall(x->x==context, contextManager.activeContexts))
	true
end

function activateContext(context::T) where {T <: Context}
	if !(context in contextManager.activeContexts) push!(contextManager.activeContexts, context) end
	runPN(contextControler.contextPNcompiled)
	true
end

function deactivateContext(context::T) where {T <: Context}
	deleteat!(contextManager.activeContexts, findall(x->x==context, contextManager.activeContexts))
	runPN(contextControler.contextPNcompiled)
	true
end

function deactivateAllContexts()
	contextManager.activeContexts = []
	runPN(contextControler.contextPNcompiled)
	true
end

function isActive(context::T) where {T <: Context}
	context in contextManager.activeContexts
end

function addMixin(context, contextualType, mixinNameSymbol)
	if context in keys(contextManager.mixins)
		if contextualType in keys(contextManager.mixins[context])
			push!(contextManager.mixins[context][contextualType], mixinNameSymbol)
		else
			contextManager.mixins[context][contextualType] = [mixinNameSymbol]
		end
	else
		contextManager.mixins[context] = Dict((contextualType)=>[mixinNameSymbol])
	end
end

function addTeam(context, team, rolesAndTypes::Dict{DataType, DataType})
	if context in keys(contextManager.teamsAndRoles)
		if team in keys(contextManager.teamsAndRoles[context])
			error("Context already contains team with name")
		else
			contextManager.teamsAndRoles[context][team] = rolesAndTypes
		end
	else
		contextManager.teamsAndRoles[context] = Dict((team)=>rolesAndTypes)
	end
end

function hasMixin(context::Context, obj, mixin::Type)
	if obj in keys(contextManager.mixinDB)
		if context in keys(contextManager.mixinDB[obj])
			if mixin in [typeof(m) for m in contextManager.mixinDB[obj][context]]
				return true
			end
		end
	end
	false
end

function getMixins()
	contextManager.mixins
end

function getMixins(type)
	contextManager.mixinDB[type]
end

function getMixins(context::Context, type)
	if !(type in keys(contextManager.mixinDB))
		return []
	end
	(contextManager.mixinDB[type])[context]
end

function getMixin( context::Context, type, mixin::Type)
	if !(mixin in contextManager.mixins[context][typeof(type)])
		error("Mixin $mixin not defined in context $context for type $(typeof(type))")
	end
	for m in (contextManager.mixinDB[type])[context]
		if typeof(m) == mixin
			return m
		end
	end
	nothing
end

function getObjectsOfMixin( context::Context, mixin::Type)
	l = []
	for obj in keys(contextManager.mixinDB)
		for mixin_i in values(contextManager.mixinDB[obj][context])
			if typeof(mixin_i) == mixin
				push!(l, obj)
			end
		end
	end
	l
end

function getObjectOfRole(context::Context, team::Type, role::Type)
	objs = []
	for obj in keys(contextManager.roleDB)
		for (team_i, role_i) in contextManager.roleDB[obj][context]
			if (typeof(role_i) == role) & (typeof(team_i) == team)
				push!(objs, obj)
			end
		end
	end
	objs
end

function hasRole(context::Context, obj, role::Type, team::Team)
	for concreteRole in getRoles(context, obj, team)
		if typeof(concreteRole) == role
			return true
		end
	end
	false
end

function hasRole(context::Context, obj, roleType::Type, teamType::Type)
	return length(getRoles(context, obj, roleType, teamType)) != 0
end

function getRoles(context::Context, obj, role::Type, teamType::Type)
	roles = []
	if !(obj in keys(contextManager.roleDB))
		return []
	end
	for team in keys(contextManager.roleDB[obj][context])
		if typeof(team) == teamType
			concreteRole = contextManager.roleDB[obj][context][team]
			if typeof(concreteRole) == role
				push!(roles, concreteRole)
			end
		end
	end
	return roles
end

function getRoles(context::Context, obj, role::Type)
	roles = []
	for team in contextManager.roleDB[obj][context]
		concreteRole = contextManager.roleDB[obj][context][team]
		if typeof(concreteRole) == role
			push!(roles, concreteRole)
		end
	end
	return roles
end

function getRoles(context::Context, obj)
	return contextManager.roleDB[obj][context]
end

function getRoles(obj)
	return contextManager.roleDB[obj]
end

function getRoles(context::Context, team::Team)
	contextManager.teamDB[context][team]
end

function getTeam(context::Context, teamType::Type, rolePairs...)
	teams = []
	if !(context in keys(contextManager.teamDB))
		return nothing
	end
	for (team, rolesObjs ) in contextManager.teamDB[context]
		roleDict = Dict(rolePairs...)
		if  roleDict in rolesObjs
			return team
		end
	end
	nothing
end

function getTeamPartners(context::Context, obj::Any, roleType::Type, team::Team)
	groups = contextManager.teamDB[context][team]
	partners = Dict()
	for group in groups
		if roleType in keys(group)
			if group[roleType] == obj
				partners = group
			end
		end
	end
	if roleType in keys(partners) 
		delete!(partners, roleType)
	else
		error("Role $roleType not assigned to $obj for team $team in context $context")
	end
	partners
end

function getTeamPartners(context::Context, obj::Any, roleType::Type, teamType::Type)
	groups = []
	for team in contextManager.teamDB[context]
		if typeof(team[1]) == teamType
			push!(groups, (contextManager.teamDB[context][team[1]])...)
		end
	end
	partners = []
	for group in groups
		if roleType in keys(group)
			if group[roleType] == obj
				push!(partners, copy(group))
			end
		end
	end
	for partnerGroup in partners
		if roleType in keys(partnerGroup) 
			delete!(partnerGroup, roleType)
		else
			error("Role $roleType not assigned to $obj for team $teamType in context $context")
		end
	end
	partners
end

macro newContext(contextName)
	if typeof(contextName) == String || typeof(contextName) == Symbol
		if typeof(contextName) == String
			contextName = Meta.parse(contextName)
		end
		contextTypeNameSymbol = Symbol(contextName, :ContextType)

		structDefExpr = :(struct $(contextTypeNameSymbol) <: Context end;)
		SingletonDefExpr = :($(contextName) = $contextTypeNameSymbol())

		return esc(:($structDefExpr; $SingletonDefExpr; addContext($contextName)))
	else
		structDefExpr = quote end
		SingletonDefExpr = quote end
		addContextExpr = quote end
		for cname in contextName.args
			if typeof(cname) == String
				cname = Meta.parse(cname)
			end
			contextTypeNameSymbol = Symbol(cname, :ContextType)

			push!(structDefExpr.args, :(struct $(contextTypeNameSymbol) <: Context end;))
			push!(SingletonDefExpr.args, :($(cname) = $contextTypeNameSymbol()))
			push!(addContextExpr.args, :(addContext($(cname))))
		end
		return esc(:($structDefExpr; $SingletonDefExpr; $ addContextExpr))
		#error("Argument of @newContext must be a String or a Symbol")
	end
end

macro newMixin(context, mixin, attributes)
	typeMixinList = split(repr(mixin), "<<")
	contextualType = Symbol(strip((typeMixinList[2])[1:end-1]))
	mixin = Symbol(strip((typeMixinList[1])[3:end]))
	Base.remove_linenums!(attributes)

	newStructExpr = :(mutable struct $mixin <: Mixin
		$attributes
	end)

	return esc(:($newStructExpr; addMixin($context, $contextualType, $mixin)))
end

macro newTeam(contextName, teamName, teamContent)
	if typeof(contextName) == String || typeof(contextName) == Symbol
		if typeof(contextName) == String
			contextName = Meta.parse(contextName)
		end
	else
		error("Last argument must be a String or a Symbol")
	end
	if typeof(teamName) == String || typeof(teamName) == Symbol
		if typeof(teamName) == String
			teamName = Meta.parse(teamName)
		end
	else
		error("First argument must be a String or a Symbol")
	end

	returnExpr = quote end

	Base.remove_linenums!(teamContent)
	relationalArgExpr = quote end
	roles = Dict()
	rolesAndTypes = Dict()
	for arg in teamContent.args
		if !(arg.head == :macrocall)
			error("Block must begin with @relationalAttributes or @roles")
		end
		if arg.args[1] === Symbol("@relationalAttributes")
			push!(relationalArgExpr.args, ((arg.args[3]).args)...)
		elseif arg.args[1] === Symbol("@role")
			typeRoleList = split(repr(arg.args[3]), "<<")
			contextualType = Symbol(strip((typeRoleList[2])[1:end-1]))
			role = Symbol(strip((typeRoleList[1])[3:end]))
			if role in keys(roles)
				error("Role names of team must be unique")
			end
			roles[role] = arg.args[4]
			rolesAndTypes[role] = contextualType
		else
			error("Block must begin with @relationalAttributes or @roles")
		end
	end

	if length(roles) < 2
		error("Team definition must at least contain two roles")
	end

	push!(returnExpr.args, :(mutable struct $teamName <: Team 
							 	$relationalArgExpr
							 end))

	for (role, attrs) in roles
		roleDef = :(mutable struct $role <: Role
			$attrs
		end)
		push!(returnExpr.args, roleDef)
	end

	rolesAndTypesExpr = :(Dict())
	for (role, type) in rolesAndTypes
		push!(rolesAndTypesExpr.args, :($role => $type))
	end

	push!(returnExpr.args, :(addTeam($contextName, $teamName, $rolesAndTypesExpr)))	
	return esc(returnExpr)
end

function Base.:(<<)(mixin::DataType, type::DataType)
	if mixin <: Mixin
		for entry in values(contextManager.mixins)
			for (key, list) in entry
				if (key == type) & (mixin in list)
					return true
				end
			end
		end
	elseif mixin <: Role
		for entry in values(contextManager.teamsAndRoles)
			for teamEntry in values(entry)
				for (key, value) in teamEntry
					if (key == mixin) & (value == type)
						return true
					end
				end
			end
		end
	end
	false
end

function assignMixin(context::Context, pair::Pair)
	type = pair[1]
	mixin = pair[2]
	if !(typeof(mixin) in contextManager.mixins[context][typeof(type)])
		error("Mixin $mixin can not be assigned to Type $type")
	end
	if type in keys(contextManager.mixinDB)
		if context in keys(contextManager.mixinDB[type])
			push!(contextManager.mixinDB[type][context], mixin)
		else
			contextManager.mixinDB[type][context] = [mixin]
		end
	else
		contextManager.mixinDB[type] = Dict(context => [mixin])
	end
	if type in keys(contextManager.mixinTypeDB)
		contextManager.mixinTypeDB[type][context] = typeof(mixin)
	else
		contextManager.mixinTypeDB[type] = Dict(context => typeof(mixin))
	end
end

function disassignMixin(context::Context, pair::Pair)
	type = pair[1]
	mixin = pair[2]
	if type in keys(contextManager.mixinDB)
		delete!(contextManager.mixinDB[type], context)
	else
		error("Mixin is not assigned to type "*repr(type))
	end
	if type in keys(contextManager.mixinTypeDB)
		delete!(contextManager.mixinTypeDB[type], context)
	else
		error("Mixin is not assigned to type "*repr(type))
	end
end

macro assignRoles(context, team, attrs)
	teamExpr = :($team())
	roleExpr = :()
	Base.remove_linenums!(attrs)
	for arg in attrs.args
		distingArray = split(repr(arg), "=")
		assignment = split(distingArray[1], ">>")
		if length(assignment) > 1
			assignment = split(repr(arg), ">>")
			push!(roleExpr.args, Meta.parse(assignment[1][3:end]*" => "*assignment[2][1:end-1]))
		else
			push!(teamExpr.args, arg)
		end
	end
	return esc(:(assignRoles($context, $teamExpr, $roleExpr...)))
end

function assignRoles(context::Context, team::Team, roles...)
	roleTypes = []
	for pair in roles
		push!(roleTypes, typeof(pair[2]) => pair[1])
	end
	currentTeam = getTeam(context, typeof(team), roleTypes)
	if (typeof(team) == typeof(getTeam(context, typeof(team), roleTypes)))
		error("Team $(typeof(team)) is already assigned with the roles $roles")
	end

	for rolePair in roles
		obj = rolePair[1]
		role = rolePair[2]
		if !(typeof(obj) == contextManager.teamsAndRoles[context][typeof(team)][typeof(role)])
			error("Role $(typeof(role)) can not be assigned to Type $(typeof(obj))")
		end
		if !(obj in keys(contextManager.roleDB))
			contextManager.roleDB[obj] = Dict()
		end
		if !(context in keys(contextManager.roleDB[obj]))
			contextManager.roleDB[obj][context] = Dict()
		end
		contextManager.roleDB[obj][context][team] = role
	end

	if !(context in keys(contextManager.teamDB))
		contextManager.teamDB[context] = Dict()
	end
	if !(team in keys(contextManager.teamDB[context]))
		contextManager.teamDB[context][team] = [Dict(roleTypes...)]
	else
		push!(contextManager.teamDB[context][team], Dict(roleTypes...))
	end
end

function disassignRoles(context::Context, teamType::Type, roles...)
	if !(context in keys(contextManager.teamDB))
		error("No team is assigned context $(context) is not assigned to context $(context)")
	end
	if !(teamType in typeof.(keys(contextManager.teamDB[context])))
		error("Team $teamType is not assigned to context $(context)")
	end
	rolesMirrored = []
	team = getTeam(context, teamType, roles...)
	for rolePair in roles
		role = rolePair[1]
		obj = rolePair[2]
		push!(rolesMirrored, role=>obj)
		if !(obj in keys(contextManager.roleDB))
			error("Role $role is not assigned to $(repr(obj)) in context $(context)")
		end
		if !(context in keys(contextManager.roleDB[obj]))
			error("Role $role is not assigned to $(repr(obj)) in context $(context)")
		end
		if !(teamType in typeof.(keys(contextManager.roleDB[obj][context])))
			error("Role $role is not assigned to $(repr(obj)) in context $(context)")
		end
		delete!(contextManager.roleDB[obj][context], team)
	end
	for (i, roleGroup) in enumerate(contextManager.teamDB[context][team])
		if roleGroup == Dict(rolesMirrored...)
			deleteat!(contextManager.teamDB[context][team], i)
			break
		end
	end	
end

function Base.:(>>)(context::Context, t, mixin::Mixin)
	assignMixin(context, t=>mixin)
end

function Base.:(>>)(t, mixinType::DataType)
	for t_mixin in [(values(getMixins(t))...)...]
		if typeof(t_mixin) == mixinType
			return true
		end
	end
	false
end

macro context(cname, expr)
	if typeof(expr) != Expr
		error("Second argument of @context must be a function or macro call or function definition")
	else
		Base.remove_linenums!(expr)
		if expr.head == :function
			functionHeaderString = repr(expr.args[1])
			ctype = cname == :Any ? Symbol(cname) : Symbol(cname, :ContextType)
			arg = :(context::$ctype)
			insert!(expr.args[1].args, 2, arg)
			return esc(expr)
		elseif expr.head == :call
			insert!(expr.args, 2, cname)
			return esc(expr)
		elseif expr.head == :.
			if !(expr.args[1].head == :call)
				error("Second argument of @context must be a function or macro call or function definition")
			end
			insert!((expr.args[1]).args, 2, cname)
			return esc(expr)
		elseif expr.head == :macrocall
			insert!(expr.args, 3, cname)
			return esc(expr)
		else
			error("Second argument of @context must be a function or macro call or function definition")
		end
	end
end

macro activeContext(cname, expr)
	if typeof(expr) != Expr
		error("Second argument of @context must be a function or macro call or function definition")
	else
		Base.remove_linenums!(expr)
		if expr.head == :call
			insert!(expr.args, 2, cname)
			ifExpr = quote if isActive($cname)
					$expr
				end
			end

			return esc(ifExpr)
		elseif expr.head == :.
			if !(expr.args[1].head == :call)
				error("Second argument of @context must be a function or macro call")
			end
			insert!((expr.args[1]).args, 2, cname)
			return esc(if isActive(cname) expr end)
		elseif expr.head == :macrocall
			insert!(expr.args, 3, cname)
			return esc(if isActive(cname) expr end)
		else
			error("Second argument of @context must be a function or macro call")
		end
	end
end

function isActive(contextRule::T) where {T <: AbstractContextRule}
	if contextRule isa AndContextRule
		isActive(contextRule.c1) & isActive(contextRule.c2)
	elseif contextRule isa OrContextRule
		isActive(contextRule.c1) | isActive(contextRule.c2)
	else
		!isActive(contextRule.c)
	end
end


#### Functions relating to Context Rules ####

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

function Base.:&(c1::CT1, c2::CT2) where {CT1, CT2 <: Union{Context, AbstractContextRule}}
    AndContextRule(c1, c2)
end

function Base.:|(c1::CT1, c2::CT2) where {CT1, CT2 <: Union{Context, AbstractContextRule}}
    OrContextRule(c1, c2)
end

function Base.:!(c::CT) where {CT <: Union{Context, AbstractContextRule}}
    NotContextRule(c)
end


#### Function relating to Petri Nets ####

function mergeCompiledPetriNets(pn1::Union{Nothing, CompiledPetriNet}, pn2::Union{Nothing, CompiledPetriNet})
    typeof(pn1) == Nothing ? pn2 : pn1
end

function mergeCompiledPetriNets(pn1::CompiledPetriNet, pn2::CompiledPetriNet)
    size_pn1_dim1 = size(pn1.WeightMatrix_in)[1]
    size_pn2_dim1 = size(pn2.WeightMatrix_in)[1]
    size_pn1_dim2 = size(pn1.WeightMatrix_in)[2]
    size_pn2_dim2 = size(pn2.WeightMatrix_in)[2]

    WeightMatrix_in_merge = zeros(size_pn1_dim1+size_pn2_dim1, size_pn1_dim2+size_pn2_dim2)
    WeightMatrix_in_merge[1:size_pn1_dim1, 1:size_pn1_dim2] = pn1.WeightMatrix_in
    WeightMatrix_in_merge[size_pn1_dim1+1:end, size_pn1_dim2+1:end] = pn2.WeightMatrix_in
    
    WeightMatrix_out_merge = zeros(size_pn1_dim1+size_pn2_dim1, size_pn1_dim2+size_pn2_dim2)
    WeightMatrix_out_merge[1:size_pn1_dim1, 1:size_pn1_dim2] = pn1.WeightMatrix_out
    WeightMatrix_out_merge[size_pn1_dim1+1:end, size_pn1_dim2+1:end] = pn2.WeightMatrix_out

    WeightMatrix_inhibitor_merge = zeros(size_pn1_dim1+size_pn2_dim1, size_pn1_dim2+size_pn2_dim2) .+ Inf
    WeightMatrix_inhibitor_merge[1:size_pn1_dim1, 1:size_pn1_dim2] = pn1.WeightMatrix_inhibitor
    WeightMatrix_inhibitor_merge[size_pn1_dim1+1:end, size_pn1_dim2+1:end] = pn2.WeightMatrix_inhibitor

    WeightMatrix_test_merge = zeros(size_pn1_dim1+size_pn2_dim1, size_pn1_dim2+size_pn2_dim2)
    WeightMatrix_test_merge[1:size_pn1_dim1, 1:size_pn1_dim2] = pn1.WeightMatrix_test
    WeightMatrix_test_merge[size_pn1_dim1+1:end, size_pn1_dim2+1:end] = pn2.WeightMatrix_test    

    tokenVector_merge = vcat(pn1.tokenVector, pn2.tokenVector)

    PrioritiesMatrix_merge = zeros(size_pn1_dim1+size_pn2_dim1, size_pn1_dim2+size_pn2_dim2)
    PrioritiesMatrix_merge[1:size_pn1_dim1, 1:size_pn1_dim2] = pn1.PrioritiesMatrix
    PrioritiesMatrix_merge[size_pn1_dim1+1:end, size_pn1_dim2+1:end] = pn2.PrioritiesMatrix    

    ContextMatrices_merge = vcat(pn1.ContextMatrices, pn2.ContextMatrices)

    ContextMap_merge = merge(pn1.ContextMap, pn2.ContextMap)
    if length(pn1.ContextMatrices[1]) != length(pn2.ContextMatrices[1])
        if length(pn1.ContextMatrices[1]) < length(pn2.ContextMatrices[1])
            for i in 1:length(pn1.ContextMatrices)
                ContextMatrices_merge[i] = hcat(pn1.ContextMatrices[i], zeros(size(pn1.ContextMatrices[i])[1], length(ContextMap_merge)-size(pn1.ContextMatrices[i])[2]))
            end
        else
            for i in length(pn1.ContextMatrices)+1:length(pn1.ContextMatrices)+length(pn2.ContextMatrices)
                ContextMatrices_merge[i] = hcat(pn2.ContextMatrices[i-length(pn1.ContextMatrices)], zeros(size(pn2.ContextMatrices[i-length(pn1.ContextMatrices)])[1], length(ContextMap_merge)-size(pn2.ContextMatrices[i-length(pn1.ContextMatrices)])[2]))
            end
        end
    end

    UpdateMatrix_cast1 = zeros(length(ContextMap_merge), size_pn1_dim2+size_pn2_dim2)
    UpdateMatrix_cast2 = zeros(length(ContextMap_merge), size_pn1_dim2+size_pn2_dim2)
    if size(pn1.UpdateMatrix)[1] < size(pn2.UpdateMatrix)[1]
        UpdateMatrix_cast1[1:size(pn1.UpdateMatrix)[1], 1:size_pn1_dim2] = pn1.UpdateMatrix
        UpdateMatrix_cast2[1:end, size_pn1_dim2+1:end] = pn2.UpdateMatrix
    else
        UpdateMatrix_cast1[1:end, 1:size_pn1_dim2] = pn1.UpdateMatrix
        UpdateMatrix_cast2[1:size(pn2.UpdateMatrix)[1], size_pn1_dim2+1:end] = pn2.UpdateMatrix
    end
    UpdateMatrix_merge = sign.(UpdateMatrix_cast1 .+ UpdateMatrix_cast2)

    CompiledPetriNet(WeightMatrix_in_merge,
                     WeightMatrix_out_merge,
                     WeightMatrix_inhibitor_merge,
                     WeightMatrix_test_merge,
                     tokenVector_merge,
                     PrioritiesMatrix_merge,
                     ContextMatrices_merge,
                     UpdateMatrix_merge,
                     ContextMap_merge)
end

function reduceRuleToElementary(cr::AndContextRule)
	a = reduceRuleToElementary(cr.c1)
	b = reduceRuleToElementary(cr.c2)
	if (typeof(a) == OrContextRule) | (typeof(b) == OrContextRule)
		if (typeof(a) == OrContextRule) & (typeof(b) != OrContextRule)
			return OrContextRule(reduceRuleToElementary(AndContextRule(a.c1, b)), reduceRuleToElementary(AndContextRule(a.c2, b)))
		elseif (typeof(a) != OrContextRule) & (typeof(b) == OrContextRule)
			return OrContextRule(reduceRuleToElementary(AndContextRule(a, b.c1)), reduceRuleToElementary(AndContextRule(a, b.c2)))
		else
			return OrContextRule(OrContextRule(reduceRuleToElementary(AndContextRule(a.c1, b.c1)), reduceRuleToElementary(AndContextRule(a.c1, b.c2))),
								 OrContextRule(reduceRuleToElementary(AndContextRule(a.c2, b.c1)), reduceRuleToElementary(AndContextRule(a.c2, b.c2))))
		end
	end
	AndContextRule(a, b)
end

function reduceRuleToElementary(cr::OrContextRule)
	OrContextRule(reduceRuleToElementary(cr.c1), reduceRuleToElementary(cr.c2))
end

function reduceRuleToElementary(c::Context)
	c
end

function reduceRuleToElementary(c::Nothing)
	nothing
end

function reduceRuleToElementary(cr::NotContextRule)
	if typeof(cr.c) == AndContextRule
		return reduceRuleToElementary(OrContextRule(!(cr.c.c1), !(cr.c.c2)))
	end
	if typeof(cr.c) == OrContextRule
		return reduceRuleToElementary(AndContextRule(!(cr.c.c1), !(cr.c.c2)))
	end
	if typeof(cr.c) == NotContextRule
		return reduceRuleToElementary(cr.c.c)
	end
	if typeof(cr.c) <: Context
		return cr
	end
end

function getCDNF(cr::AbstractContextRule)
	function removeDoubleTerms(cr::AbstractContextRule)
		function getAndRules(cr::OrContextRule, l)
			push!(l, cr.c1)
			if typeof(cr.c2) == OrContextRule
				l = getAndRules(cr.c2, l)
			else
				push!(l, cr.c2)
			end
			l
		end
		function genOrRule(l)
			if length(l) == 1
				return l[1]
			end
			OrContextRule(l[1], genOrRule(l[2:end]))
		end
		if typeof(cr) == OrContextRule
			andRules = getAndRules(cr, [])
			contexts = getContextsOfRule(andRules[1])
			c = Dict()
			for (i, context) in enumerate(contexts)
				c[context] = i
			end
			z = zeros(length(contexts))
			d = Dict()
			for a in andRules
				i = genContextRuleMatrix(a, c, length(contexts))
				d[i] = a
			end
			cr = genOrRule(collect(values(d)))
		end
		cr
	end
	function addContextToRule(cr::OrContextRule, context::Context)
		if !(context in getContextsOfRule(cr.c1))
			newRule_p = AndContextRule(cr.c1, context)
			newRule_n = AndContextRule(cr.c1, !context)
			return OrContextRule(newRule_p, OrContextRule(newRule_n, addContextToRule(cr.c2, context)))
		end
		OrContextRule(cr.c1, addContextToRule(cr.c2, context))
	end
	function addContextToRule(cr::AndContextRule, context::Context)
		if !(context in getContextsOfRule(cr))
			newRule_p = AndContextRule(cr, context)
			newRule_n = AndContextRule(cr, !context)
			return OrContextRule(newRule_p, newRule_n)
		end
		cr
	end
	function addContextToRule(cr::NotContextRule, context::Context)
		if !(context in getContextsOfRule(cr))
			newRule_p = AndContextRule(cr.c, context)
			newRule_n = AndContextRule(cr.c, !context)
			return OrContextRule(newRule_p, newRule_n)
		end
		cr
	end
	function addContextToRule(cr::Context, context::Context)
		if !(context in getContextsOfRule(cr))
			newRule_p = AndContextRule(cr, context)
			newRule_n = AndContextRule(cr, !context)
			return OrContextRule(newRule_p, newRule_n)
		end
		cr
	end

	cr = reduceRuleToElementary(cr)

	if (typeof(cr) != OrContextRule)
		return cr
	end

	contexts = getContextsOfRule(cr)
	containedContexts = getContextsOfRule(cr.c1)

	for c in contexts
		cr = addContextToRule(cr, c)
	end

	cr = removeDoubleTerms(cr)
end

function genContextRuleMatrix(cr::T, cdict::Dict, nc::Int) where {T <: Union{Context, Any, AbstractContextRule}}
    matrix = zeros(1, nc)
    if typeof(cr) <: AbstractContextRule
        if cr isa AndContextRule
            a = genContextRuleMatrix(cr.c1, cdict, nc)
            b = genContextRuleMatrix(cr.c2, cdict, nc)
            matrix = nothing
            c = 0
            for i in 1:size(a)[1]
                for j in 1:size(b)[1]
                    findmin((a[i, :] .- b[j, :]) .* b[j, :])[1] < -1 ? c = zeros(1, size(a)[2]) : c = a[i, :] .+ b[j, :]
                    c = reshape(c, 1, length(c))
                    matrix == nothing ? matrix = [c;] : matrix = [matrix; c]
                end            
            end       
        elseif cr isa OrContextRule
            matrix = [genContextRuleMatrix(cr.c1, cdict, nc); genContextRuleMatrix(cr.c2, cdict, nc)]
        else
            matrix = -genContextRuleMatrix(cr.c, cdict, nc)
        end
    elseif typeof(cr) <: Context
        matrix[cdict[cr]] = 1
    end
    matrix
end

function compile(pn::PetriNet)
    # should test here if name is given two times
    # should test here if arcs are connected correctly (not place to place etc.)
    np = length(pn.places)                              # number of places
    nt = length(pn.transitions)                         # number of transitions
    nc = length(getContexts())                          # number of contexts
    W_i = zeros(Float64, np, nt)                        # Input Arc weights matrix (to place)
    W_o = zeros(Float64, np, nt)                        # Output Arc weights matrix(from place)
    W_inhibitor = zeros(Float64, np, nt) .+ Inf         # Inhibitor Arc weights matrix
    W_test = zeros(Float64, np, nt)                     # Test Arc weights matrix
    t = zeros(Float64, np)                              # Token vector
    P = zeros(Float64, np, nt)                          # Priority matrix
    pdict = Dict()                                      # dictionary of places and corresponding index
    tdict = Dict()                                      # dictionary of transitions and corresponding index
    cdict = Dict()                                      # dictionary of contexts and corresponding index

    for (i, place) in enumerate(pn.places)
        t[i] = place.token
        pdict[place] = i
    end
    for (i, transition) in enumerate(pn.transitions)
        tdict[transition] = i
    end
    for (i, context) in enumerate(getContexts())
        cdict[context] = i
    end


    C = nothing                                         # Context matrix
    U = zeros(Float64, nc, nt)                          # Update matrix
    for transition in pn.transitions
        c = sign.(genContextRuleMatrix(reduceRuleToElementary(transition.contexts), cdict, nc))
        C == nothing ? C = [c] : C = [C; [c]]
        for update in transition.updates
            if update.updateValue == on
                U[cdict[update.context], tdict[transition]] = 1
            else
                U[cdict[update.context], tdict[transition]] = -1
            end
        end 
    end
    for arc in pn.arcs
        if arc.from isa Place
            if arc isa NormalArc
                W_o[pdict[arc.from], tdict[arc.to]] = arc.weight
                if !(arc.priority in P[pdict[arc.from]])
                    P[pdict[arc.from], tdict[arc.to]] = arc.priority
                else
                    print("check priority of place ", arc.from)
                end
            elseif arc isa InhibitorArc
                W_inhibitor[pdict[arc.from], tdict[arc.to]] = arc.weight
            else
                W_test[pdict[arc.from], tdict[arc.to]] = arc.weight
            end
        else
            W_i[pdict[arc.to], tdict[arc.from]] = arc.weight
        end
    end
    CompiledPetriNet(W_i, W_o, W_inhibitor, W_test, t, P, C, U, cdict)
end