using Parameters

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
    contexts::Union{Nothing, <:AbstractContext}
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
	teamsAndRoles::Dict{Union{Context, Nothing}, Dict{Any, Dict{DataType, DataType}}} = Dict()
	roleDB::Dict{Any, Dict{Union{Context, Nothing}, Dict{Union{Team, DynamicTeam}, Role}}} = Dict()
	teamDB::Dict{Union{Context, Nothing}, Dict{Team, Vector{Dict{DataType, Any}}}} = Dict()
	dynTeamDB::Dict{Union{Context, Nothing}, Dict{DynamicTeam, Dict{DataType, Vector}}} = Dict()
	dynTeamsAndData::Dict{Union{Context, Nothing}, Dict{Any, Dict{DataType, Dict}}} = Dict()
	dynTeamsProp::Dict{Union{Context, Nothing}, Dict{Any, Any}} = Dict()
end

@with_kw mutable struct ContextControl
	contextPN::Vector{PetriNet} = [PetriNet()]
	contextPNcompiled::Vector{Union{CompiledPetriNet, Nothing}} = Union{CompiledPetriNet, Nothing}[nothing]
end

global contextManager = ContextManagement()
global contextControler = ContextControl()

#### Functions and macros ####

function setControlPNs(pn::PetriNet, cpn::CompiledPetriNet)
	contextControler.contextPN = [pn]
	contextControler.contextPNcompiled = [cpn]
end

function getControlPN()
	contextControler.contextPN
end

function getCompiledControlPN()
	contextControler.contextPNcompiled
end

function addPNToControlPN(pn::PetriNet; priority::Int=1)
	if priority < 1
		error("Priority must be >= 1 but $priority was specified.")
	end
	if length(contextControler.contextPN) < priority
		while priority - length(contextControler.contextPN) > 0
			push!(contextControler.contextPN, PetriNet())
			push!(contextControler.contextPNcompiled, nothing)
		end
	end
	cpn = compile(pn)
	contextControler.contextPN[priority].places == [] ? contextControler.contextPN[priority].places = pn.places : push!(contextControler.contextPN[priority].places, pn.places...)
	contextControler.contextPN[priority].transitions == [] ? contextControler.contextPN[priority].transitions = pn.transitions : push!(contextControler.contextPN[priority].transitions, pn.transitions...)
	contextControler.contextPN[priority].arcs == [] ? contextControler.contextPN[priority].arcs = pn.arcs : push!(contextControler.contextPN[priority].arcs, pn.arcs...)
	contextControler.contextPNcompiled[priority] = mergeCompiledPetriNets(contextControler.contextPNcompiled[priority], cpn)
end

function ContextGroup(subContexts::Context...)
	alternative(subContexts...)
	ContextGroup([subContexts...])
end
(contextGroup::ContextGroup)() = filter(subContext -> isActive(subContext), contextGroup.subContexts)[1]

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
	if !(context in contextManager.activeContexts) 
		push!(contextManager.activeContexts, context)
		for pn in contextControler.contextPNcompiled	
			runPN(pn)
		end
	end
	true
end

function deactivateContext(context::T) where {T <: Context}
	deleteat!(contextManager.activeContexts, findall(x->x==context, contextManager.activeContexts))
	for pn in contextControler.contextPNcompiled	
		runPN(pn)
	end
	true
end

function deactivateAllContexts()
	contextManager.activeContexts = []
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

function addTeam(context::Union{Context, Nothing}, team, rolesAndTypes::Dict{DataType, DataType})
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

function addDynamicTeam(context::Union{Context, Nothing}, team::DataType, rolesAndData::Dict{DataType, Dict{String, Any}}, id, min, max)
	if context in keys(contextManager.dynTeamsAndData)
		if team in keys(contextManager.dynTeamsAndData[context])
			error("Context already contains team with name")
		else
			contextManager.dynTeamsAndData[context][team] = rolesAndData
			contextManager.dynTeamsProp[context][team] = Dict("ID" => id, "min" => min, "max" => max)
		end
	else
		contextManager.dynTeamsAndData[context] = Dict((team)=>rolesAndData)
		contextManager.dynTeamsProp[context] = Dict((team)=>Dict("ID" => id, "min" => min, "max" => max))
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

function getObjectsOfMixin(context::Context, mixin::Type)
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

function getObjectOfRole(context::Union{Context, Nothing}, team::Type, role::Type)
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

function getObjectOfRole(context::Union{Context, Nothing}, team::DynamicTeam, role::Role)
	for obj in keys(contextManager.roleDB)
		if context in keys(roleDB[obj])
			if contextManager.roleDB[obj][context][team] == role
					return obj
			end
		end
	end
end
function getObjectOfRole(team::DynamicTeam, role::Role)
	getObjectOfRole(nothing, team, role)
end

function getObjectOfRole(context::Union{Context, Nothing}, role::Role)
	for obj in keys(contextManager.roleDB)
		if context in keys(contextManager.roleDB[obj])
			for role_i in values(contextManager.roleDB[obj][context])
				if role_i == role
					return obj
				end
			end
		end
	end
end
function getObjectOfRole(role::Role)
	getObjectOfRole(nothing, role)
end

function getObjectsOfRole(context::Union{Context, Nothing}, team::DynamicTeam, role::Type)
	if !(context in keys(contextManager.dynTeamDB))
		return []
	end
	if !(team in keys(contextManager.dynTeamDB[context]))
		return []
	end
	if !(role in keys(contextManager.dynTeamDB[context][team]))
		return []
	end
	contextManager.dynTeamDB[context][team][role]
end
function getObjectsOfRole(team::DynamicTeam, role::Type)
	getObjectsOfRole(nothing, team, role)
end

function hasRole(context::Union{Context, Nothing}, obj, role::Type, team::Team)
	#if role in typeof.(collect(keys(contextManager.roleDB[obj][context][team])))
	for concreteRole in getRoles(context, obj, team)
		if typeof(concreteRole) == role
			return true
		end
	end
	false
end

function hasRole(context::Union{Context, Nothing}, obj, role::Type, team::DynamicTeam)
	role == typeof(getRole(context, obj, team))
end

function hasRole(obj, role::Type, team::DynamicTeam)
	hasRole(nothing, obj, role, team)
end


function hasRole(context::Union{Context, Nothing}, obj, roleType::Type, teamType::Type)
	return length(getRoles(context, obj, roleType, teamType)) != 0
end

function hasRole(obj, roleType::Type, teamType::Type)
	return length(getRoles(nothing, obj, roleType, teamType)) != 0
end


function getRoles(context::Union{Context, Nothing}, obj, role::Type, teamType::Type)
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

function getRoles(context::Union{Context, Nothing}, obj, role::Type)
	roles = []
	for team in contextManager.roleDB[obj][context]
		concreteRole = contextManager.roleDB[obj][context][team]
		if typeof(concreteRole) == role
			push!(roles, concreteRole)
		end
	end
	return roles
end

function getRole(context::Union{Context, Nothing}, obj::T, team::DynamicTeam) where T
	if !(haskey(contextManager.roleDB, obj))
		return nothing
	elseif !(haskey(contextManager.roleDB[obj], context))
		return nothing
	elseif !(haskey(contextManager.roleDB[obj][context], team))
		return nothing
	end
	contextManager.roleDB[obj][context][team]
end

function getRole(obj::T, team::DynamicTeam) where T
	getRole(nothing, obj, team)
end

function getRoles(context::Union{Context, Nothing}, obj)
	if haskey(contextManager.roleDB, obj)
		return contextManager.roleDB[obj][context]
	end
	return nothing
end

function getRoles(obj)
	if haskey(contextManager.roleDB, obj)
		return contextManager.roleDB[obj]
	end
	return nothing
end

function getRolesOfTeam(context::Union{Context, Nothing}, team::Team)
	contextManager.teamDB[context][team]
end

function getRolesOfTeam(team::Team)
	contextManager.teamDB[nothing][team]
end

function getRolesOfTeam(context::Union{Context, Nothing}, team::DynamicTeam)
	contextManager.dynTeamDB[context][team]
end

function getRolesOfTeam(team::DynamicTeam)
	contextManager.dynTeamDB[nothing][team]
end

function getTeam(context::Union{Context, Nothing}, teamType::Type, rolePairs...)
	teams = []
	if !(context in keys(contextManager.teamDB))
		return nothing
	end
	for (team, rolesObjs ) in contextManager.teamDB[context]
		roleDict = Dict(rolePairs...)
		if roleDict in rolesObjs
			return team
		end
	end
	nothing
end

function getDynamicTeam(context::Union{Context, Nothing}, role::Role)
	if !(context in keys(contextManager.dynTeamDB))
		return nothing
	end
	for obj in keys(contextManager.roleDB)
		for team in keys(contextManager.roleDB[obj][context])
			if contextManager.roleDB[obj][context][team] == role
				return team
			end
		end
	end
	return nothing
end

function getDynamicTeam(role::Role)
	getDynamicTeam(nothing, role)
end

function getDynamicTeamID(context::Union{Context, Nothing}, team::DynamicTeam)
	contextManager.dynTeamsProp[context][team]
end

function getDynamicTeamID(team::DynamicTeam)
	contextManager.dynTeamsProp[nothing][team]
end

function getDynamicTeam(context::Union{Context, Nothing}, teamType::DataType, id::T) where T
	d = get!(contextManager.dynTeamDB, context, Dict())
	idName = contextManager.dynTeamsProp[context][teamType]["ID"]
	for team in keys(d)
		if typeof(team) == teamType
			if getfield(team, idName) == id
				return team
			end	
		end
	end
	nothing
end

function getDynamicTeam(teamType::DataType, id::T) where T
	getDynamicTeam(nothing, teamType, id)
end

function getDynamicTeams(context::Union{Context, Nothing}, teamType::Type)
	if !(context in keys(contextManager.dynTeamDB))
		return nothing
	end
	teams = []
	for team in keys(contextManager.dynTeamDB[context])
		if typeof(team) == teamType
			push!(teams, team)
		end
	end
	teams
end

function getDynamicTeams(teamType::Type)
	getDynamicTeams(nothing, teamType)
end

function getTeamPartners(context::Union{Context, Nothing}, obj::Any, roleType::Type, team::Team)
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

function getTeamPartners(context::Union{Context, Nothing}, obj::Any, roleType::Type, teamType::Type)
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
		SingletonDefExpr = :($(contextName)::$contextTypeNameSymbol = $contextTypeNameSymbol())

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
	teamSuperType = :Team
	if typeof(contextName) == String || typeof(contextName) == Symbol
		if typeof(contextName) == String
			contextName = Meta.parse(contextName)
		end
	else
		error("Context argument must be a String or a Symbol")
	end
	if typeof(teamName) == String || typeof(teamName) == Symbol
		if typeof(teamName) == String
			teamName = Meta.parse(teamName)
		end
	elseif typeof(teamName) == Expr
		if teamName.head == :(<:)
			teamSuperType = teamName.args[2]
			teamName = teamName.args[1]
		else
			error("Supertyping of Teams must be done with <:")
		end
	else
		error("Team argument must be a String or a Symbol")
	end

	returnExpr = quote end

	Base.remove_linenums!(teamContent)
	relationalArgExpr = quote end
	roles = Dict()
	rolesAndTypes = Dict()
	supertypes = Dict()
	for arg in teamContent.args
		if !(arg.head == :macrocall)
			error("Block must begin with @relationalAttributes or @roles")
		end
		if arg.args[1] === Symbol("@relationalAttributes")
			push!(relationalArgExpr.args, ((arg.args[3]).args)...)
		elseif arg.args[1] === Symbol("@role")
			if arg.args[3].head == :(<:)
				if arg.args[3].args[1].args[1] != :(<<)
					error("Type of objects that can play a role must be specified by <<")
				end
				role = arg.args[3].args[1].args[2]
				contextualType = arg.args[3].args[1].args[3]
				roleSuperType = arg.args[3].args[2]
			elseif (length(arg.args[3].args) == 3) & (arg.args[3].args[1] == :(<<))
				role = arg.args[3].args[2]
				contextualType = arg.args[3].args[3]
				roleSuperType = :Role
			else
				error("Syntax error.")
			end
			if role in keys(roles)
				error("Role names of team must be unique")
			end
			roles[role] = arg.args[4]
			rolesAndTypes[role] = contextualType
			supertypes[role] = roleSuperType
		else
			error("Block must begin with @relationalAttributes or @roles")
		end
	end

	if length(roles) < 2
		error("Team definition must at least contain two roles")
	end

	push!(returnExpr.args, quote mutable struct $teamName <: $(teamSuperType)
							 	     $relationalArgExpr
							     end
								 if !($(teamSuperType) <: Team)
									error("Supertype of Teams must be Team or a subtype of Team but ", $(teamSuperType), " (Supertype of ", $teamName, ") is not.")
								end
							end)

	for (role, attrs) in roles
		roleDef = quote mutable struct $role <: $(supertypes[role])
				$attrs
			end
			if !($(supertypes[role]) <: Role)
				error("Supertype of concrete roles must be Role or a subtype of Role but ", $(supertypes[role]), " (Supertype of ", $role, ") is not.")
			end
		end
		push!(returnExpr.args, roleDef)
	end

	rolesAndTypesExpr = :(Dict())
	for (role, type) in rolesAndTypes
		push!(rolesAndTypesExpr.args, :($role => $type))
	end

	push!(returnExpr.args, :(addTeam($contextName, $teamName, $rolesAndTypesExpr)))	
	return esc(returnExpr)
end

macro newTeam(teamName, teamContent)
	returnExpr = quote newTeam(nothing, $teamName, $teamContent) end
	esc(returnExpr)
end

macro newDynamicTeam(contextName, teamName, teamContent)
	teamSuperType = :DynamicTeam
	if typeof(contextName) == String || typeof(contextName) == Symbol
		if typeof(contextName) == String
			contextName = Meta.parse(contextName)
		end
	else
		error("Context argument must be a String or a Symbol")
	end
	if typeof(teamName) == String || typeof(teamName) == Symbol
		if typeof(teamName) == String
			teamName = Meta.parse(teamName)
		end
	elseif typeof(teamName) == Expr
		if teamName.head == :(<:)
			teamSuperType = teamName.args[2]
			teamName = teamName.args[1]
		else
			error("Supertyping of Teams must be done with <:")
		end
	else
		error("Team argument must be a String or a Symbol")
	end

	returnExpr = quote end

	Base.remove_linenums!(teamContent)
	relationalArgExpr = quote end
	roles = Dict()
	supertypes = Dict()
	minPlayers = 2
	maxPlayers = Inf
	id = nothing
	for arg in teamContent.args
		if !(arg.head == :macrocall)
			error("Block must begin with @IDAttribute, @relationalAttributes, @maxPlayers, @minPlayers or @role")
		end
		if arg.args[1] === Symbol("@relationalAttributes")
			push!(relationalArgExpr.args, ((arg.args[3]).args)...)
		elseif arg.args[1] === Symbol("@minPlayers")
			if arg.args[3] < 2
				error("Minimum Number of Players must be at least 2.")
			end
			minPlayers = arg.args[3]
		elseif arg.args[1] === Symbol("@maxPlayers")
			maxPlayers = arg.args[3]
		elseif arg.args[1] === Symbol("@IDAttribute")
			id = arg.args[3]
			push!(relationalArgExpr.args, id)
		elseif arg.args[1] === Symbol("@role")
			cardinalityList = split(repr(arg.args[4]), "..")
			if length(arg.args[3].args) == 2
				if arg.args[3].args[1].args[1] != :(<<)
					error("Type of objects that can play a role must be specified by <<")
				end
				role = arg.args[3].args[1].args[2]
				contextualType = arg.args[3].args[1].args[3]
				roleSuperType = arg.args[3].args[2]
			elseif (length(arg.args[3].args) == 3) & (arg.args[3].args[1] == :(<<))
				role = arg.args[3].args[2]
				contextualType = arg.args[3].args[3]
				roleSuperType = :Role
			else
				error("Syntax error.")
			end
			if role in keys(roles)
				error("Role names of team must be unique")
			end
			supertypes[role] = roleSuperType
			if length(cardinalityList) > 1
				minRoles = cardinalityList[1][4:end]
				maxRoles = cardinalityList[2][1:end-2]
			else
				minRoles = cardinalityList[1][4:end-2]
				maxRoles = cardinalityList[1][4:end-2]
			end
			minRoles = occursin("Inf", minRoles) ? parse(Float64, minRoles) : parse(Int64, minRoles)
			if minRoles < 0 error("Cardinality of Role can not be negative!") end
			maxRoles = occursin("Inf", maxRoles) ? parse(Float64, maxRoles) : parse(Int64, maxRoles)
			if minRoles > maxRoles error("Minimum cardinality must be smaller than maximum!") end
			if role in keys(roles)
				error("Role names of team must be unique")
			end
			roles[role] = Dict("attrs" => arg.args[5],
							   "natType" => contextualType,
							   "min" => minRoles,
							   "max" => maxRoles)
		else
			error("Block must begin with @IDAttribute, @relationalAttributes, @maxPlayers, @minPlayers or @role")
		end
	end

	if id === nothing
		error("You must define an uniquely indentifying attribute with @IDAttribute")
	end

	if length(roles) < 2
		if roles[collect(keys(roles))[1]]["min"] < 2
			error("Team definition must at least contain two roles.")
		end
	end

	push!(returnExpr.args, quote mutable struct $teamName <: $(teamSuperType)
							 	     $relationalArgExpr
							     end
								 if !($(teamSuperType) <: DynamicTeam)
									error("Supertype of DynamicTeams must be DynamicTeam or a subtype of DynamicTeam but ", $(teamSuperType), " (Supertype of ", $teamName, ") is not.")
								end
							end)

	for role in keys(roles)
		attrs = roles[role]["attrs"]
		roleDef = quote mutable struct $role <: $(supertypes[role])
				$attrs
			end
			if !($(supertypes[role]) <: Role)
				error("Supertype of concrete roles must be Role or a suptype of Role but ", $(supertypes[role]), " (Supertype of ", $role, ") is not.")
			end
		end
		push!(returnExpr.args, roleDef)
	end

	rolesAndDataExpr = :(Dict())
	for role in keys(roles)
		data = roles[role]
		delete!(data, "attrs")
		push!(returnExpr.args, :($data["natType"] = eval($data["natType"])))
		push!(rolesAndDataExpr.args, :($role => $data))
	end

	idName = quote  $(Expr(:quote, id.args[1])) end

	push!(returnExpr.args, :(Contexts.addDynamicTeam($contextName, $teamName, $rolesAndDataExpr, $idName, $minPlayers, $maxPlayers)))	
	return esc(returnExpr)
end

macro newDynamicTeam(teamName, teamContent)
	returnExpr = quote @newDynamicTeam(nothing, $teamName, $teamContent) end
	esc(returnExpr)
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

macro assignRoles(team, attrs)
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
	return esc(:(assignRoles(nothing, $teamExpr, $roleExpr...)))
end

macro disassignRoles(context, team, attrs)
	teamExpr = :($team())
	roleExpr = :()
	Base.remove_linenums!(attrs)
	for arg in attrs.args
		distingArray = split(repr(arg), "=")
		assignment = split(distingArray[1], ">>")
		if length(assignment) > 1
			assignment = split(repr(arg), ">>")
			push!(roleExpr.args, Meta.parse(assignment[2][1:end-1]*" => "*assignment[1][3:end]))
		else
			push!(teamExpr.args, arg)
		end
	end
	return esc(:(disassignRoles($context, $teamExpr, $roleExpr...)))
end

macro disassignRoles(team, attrs)
	teamExpr = :($team())
	roleExpr = :()
	Base.remove_linenums!(attrs)
	for arg in attrs.args
		distingArray = split(repr(arg), "=")
		assignment = split(distingArray[1], ">>")
		if length(assignment) > 1
			assignment = split(repr(arg), ">>")
			push!(roleExpr.args, Meta.parse(assignment[2][1:end-1]*" => "*assignment[1][3:end]))
		else
			push!(teamExpr.args, arg)
		end
	end
	return esc(:(disassignRoles(nothing, $teamExpr, $roleExpr...)))
end

macro changeRoles(context, team, id, attrs)
	roleAssignmentExpr = :([])
	roleDisassignmentExpr = :([])
	Base.remove_linenums!(attrs)
	for arg in attrs.args
		distingArray = split(repr(arg), "=")
		assignment = split(distingArray[1], ">>")
		disassignment = split(distingArray[1], "<<")
		if length(assignment) > 1
			assignment = split(repr(arg), ">>")
			push!(roleAssignmentExpr.args, Meta.parse(assignment[1][3:end]*" => "*assignment[2][1:end-1]))
		elseif length(disassignment) > 1
			disassignment = split(repr(arg), "<<")
			push!(roleDisassignmentExpr.args, Meta.parse(disassignment[1][3:end]*" => "*disassignment[2][1:end-1]))
		else
			error("False assignement when changing roles for " , arg)
		end
	end
	teamObject = :(getDynamicTeam($context, $team, $id))
	return esc(:(changeRoles($context, $teamObject, $roleAssignmentExpr, $roleDisassignmentExpr)))
end

macro changeRoles(team, id, attrs)
	roleAssignmentExpr = :([])
	roleDisassignmentExpr = :([])
	Base.remove_linenums!(attrs)
	for arg in attrs.args
		distingArray = split(repr(arg), "=")
		assignment = split(distingArray[1], ">>")
		disassignment = split(distingArray[1], "<<")
		if length(assignment) > 1
			assignment = split(repr(arg), ">>")
			push!(roleAssignmentExpr.args, Meta.parse(assignment[1][3:end]*" => "*assignment[2][1:end-1]))
		elseif length(disassignment) > 1
			disassignment = split(repr(arg), "<<")
			push!(roleDisassignmentExpr.args, Meta.parse(disassignment[1][3:end]*" => "*disassignment[2][1:end-1]))
		else
			error("False assignement when changing roles for " , arg)
		end
	end
	teamObject = :(getDynamicTeam(nothing, $team, $id))
	return esc(:(changeRoles(nothing, $teamObject, $roleAssignmentExpr, $roleDisassignmentExpr)))
end

function changeRoles(context::Union{Context, Nothing}, team::DynamicTeam, roleAssignment::Vector{Any}, roleDisassignment::Vector{Pair{T, DataType}}) where T
	roles = contextManager.dynTeamDB[context][team]
	roleProps = contextManager.dynTeamsAndData[context][typeof(team)]
	teamProps = contextManager.dynTeamsProp[context][typeof(team)]
	count = sum(length(v) for v in values(roles))
	#disassignmentsDict = Dict{DataType, Int64}([r[2] => 0 for r in roleDisassignment])
	disassignmentsDict = Dict{DataType, Int64}()
	for r in roleDisassignment
		disassignmentsDict[r[2]] = get(disassignmentsDict, r[2], 0) + 1
		#setindex!(disassignmentsDict, getindex(disassignmentsDict, r[2]) + 1, r[2])
	end
	for role in keys(disassignmentsDict)
		min = roleProps[role]["min"]
	 	max = roleProps[role]["max"]
		curAssigned = length(get(roles, role, []))
		disassigned = get(disassignmentsDict, role, 0)
		if min > curAssigned- disassigned
			error("Minimum assigned roles of type $(role) is $(min), current is $(curAssigned + - disassigned).")
		end
		if max < curAssigned- disassigned
			error("Maximum assigned roles of type $(role) is $(max), current is $(curAssigned + - disassigned).")
		end
		count -= disassigned
	end

	if teamProps["min"] > count
		error("Set minimum assigned roles is $(teamProps["min"]), current is $(count).")
	end
	if teamProps["max"] < count
		error("Set maximum assigned roles is $(teamProps["max"]), current is $(count).")
	end
	for rolePair in roleDisassignment
		role = rolePair[2]
		obj = rolePair[1]
		roleObj = getRole(context, obj, team)
		if haskey(contextManager.roleDB, roleObj)
			error("Role $(roleObj) plays another role. You must diassign it before dissolving the team.")
		end
		get!(get!(contextManager.roleDB, obj, Dict()), context, Dict())
		if !(haskey(contextManager.roleDB[obj][context], team))
			error("$obj does not play role $role in team $team.")
		end
		if isa(contextManager.roleDB[obj][context][team], role)
			delete!(contextManager.roleDB[obj][context], team)
		else
			error("$obj does not play role $role.")
		end
		filter!(x -> x != obj, roles[role])
		if isempty(contextManager.roleDB[obj][context])
			delete!(contextManager.roleDB[obj], context)
			if isempty(contextManager.roleDB[obj])
			delete!(contextManager.roleDB, obj)
			end
		end
	end
end

function changeRoles(context::Union{Context, Nothing}, team::DynamicTeam, roleAssignment::Vector{Pair{T, R}}, roleDisassignment::Vector{Any}) where T where R <: Role
	roles = contextManager.dynTeamDB[context][team]
	roleProps = contextManager.dynTeamsAndData[context][typeof(team)]
	teamProps = contextManager.dynTeamsProp[context][typeof(team)]
	count = sum(length(v) for v in values(roles))
	#assignmentsDict = Dict{DataType, Int64}([typeof(r[2]) => 0 for r in roleAssignment])
	assignmentsDict = Dict{DataType, Int64}()
	for r in roleAssignment
		assignmentsDict[typeof(r[2])] = get(assignmentsDict, typeof(r[2]), 0) + 1
		#setindex!(assignmentsDict, getindex(assignmentsDict, typeof(r[2])) + 1, typeof(r[2]))
	end
	for role in keys(assignmentsDict)
		min = roleProps[role]["min"]
	 	max = roleProps[role]["max"]
		curAssigned = length(get(roles, role, []))
		assigned = get(assignmentsDict, role, 0)
		if min > curAssigned + assigned
			error("Minimum assigned roles of type $(role) is $(min), current is $(curAssigned + assigned).")
		end
		if max < curAssigned + assigned
			error("Maximum assigned roles of type $(role) is $(max), current is $(curAssigned + assigned).")
		end
		count += assigned
	end

	if teamProps["min"] > count
		error("Set minimum assigned roles is $(teamProps["min"]), current is $(count).")
	end
	if teamProps["max"] < count
		error("Set maximum assigned roles is $(teamProps["max"]), current is $(count).")
	end

	for rolePair in roleAssignment
		role = rolePair[2]
		obj = rolePair[1]
		if !(isa(obj, contextManager.dynTeamsAndData[context][typeof(team)][typeof(role)]["natType"]))
			error("Role $(typeof(role)) can not be assigned to Type $(typeof(obj))")
		end
		d = get!(get!(contextManager.roleDB, obj, Dict()), context, Dict())
		if haskey(d, team)
			error("$obj already plays role in team $team.")
		end
		d[team] = role
		push!(roles[typeof(role)], obj)
	end
end

function changeRoles(context::Union{Context, Nothing}, team::DynamicTeam, roleAssignment::Vector{Pair{T1, R}}, roleDisassignment::Vector{Pair{T2, DataType}}) where T1 where T2 where R <: Role
	roles = contextManager.dynTeamDB[context][team]
	roleProps = contextManager.dynTeamsAndData[context][typeof(team)]
	teamProps = contextManager.dynTeamsProp[context][typeof(team)]
	count = sum(length(v) for v in values(roles))
	#assignmentsDict = Dict{DataType, Int64}([typeof(r[2]) => 0 for r in roleAssignment])
	assignmentsDict = Dict{DataType, Int64}()
	for r in roleAssignment
		assignmentsDict[typeof(r[2])] = get(assignmentsDict, typeof(r[2]), 0) + 1
		#setindex!(assignmentsDict, getindex(assignmentsDict, typeof(r[2])) + 1, typeof(r[2]))
	end
	#disassignmentsDict = Dict{DataType, Int64}([r[2] => 0 for r in roleDisassignment])
	disassignmentsDict = Dict{DataType, Int64}()
	for r in roleDisassignment
		disassignmentsDict[r[2]] = get(disassignmentsDict, r[2], 0) + 1
		#setindex!(disassignmentsDict, getindex(disassignmentsDict, r[2]) + 1, r[2])
	end
	for role in keys(merge(assignmentsDict, disassignmentsDict))
		min = roleProps[role]["min"]
	 	max = roleProps[role]["max"]
		curAssigned = length(get(roles, role, []))
		assigned = get(assignmentsDict, role, 0)
		disassigned = get(disassignmentsDict, role, 0)
		if min > curAssigned + assigned - disassigned
			error("Minimum assigned roles of type $(role) is $(min), current is $(curAssigned + assigned - disassigned).")
		end
		if max < curAssigned + assigned - disassigned
			error("Maximum assigned roles of type $(role) is $(max), current is $(curAssigned + assigned - disassigned).")
		end
		count += assigned - disassigned
	end

	if teamProps["min"] > count
		error("Set minimum assigned roles is $(teamProps["min"]), current is $(count).")
	end
	if teamProps["max"] < count
		error("Set maximum assigned roles is $(teamProps["max"]), current is $(count).")
	end

	for rolePair in roleDisassignment
		role = rolePair[2]
		obj = rolePair[1]
		roleObj = getRole(context, obj, team)
		if haskey(contextManager.roleDB, roleObj)
			error("Role $(roleObj) plays another role. You must diassign it before dissolving the team.")
		end
		get!(get!(contextManager.roleDB, obj, Dict()), context, Dict())
		if !(haskey(contextManager.roleDB[obj][context], team))
			error("$obj does not play role $role in team $team.")
		end
		if isa(contextManager.roleDB[obj][context][team], role)
			delete!(contextManager.roleDB[obj][context], team)
		else
			error("$obj does not play role $role.")
		end
		#filter!(x -> x != obj, contextManager.dynTeamDB[context][team][role])
		deleteat!(roles[role], findfirst(isequal(obj), roles[role]))
		if isempty(contextManager.roleDB[obj][context])
			delete!(contextManager.roleDB[obj], context)
			if isempty(contextManager.roleDB[obj])
			delete!(contextManager.roleDB, obj)
			end
		end
	end

	for rolePair in roleAssignment
		role = rolePair[2]
		obj = rolePair[1]
		if !(isa(obj, contextManager.dynTeamsAndData[context][typeof(team)][typeof(role)]["natType"]))
			error("Role $(typeof(role)) can not be assigned to Type $(typeof(obj))")
		end
		d = get!(get!(contextManager.roleDB, obj, Dict()), context, Dict())
		if haskey(d, team)
			error("$obj already plays role in team $team.")
		end
		d[team] = role
		push!(roles[typeof(role)], obj)
	end
end

function assignRoles(context::Union{Context, Nothing}, team::Team, roles...)
	roleTypes = []
	for pair in roles
		push!(roleTypes, typeof(pair[2]) => pair[1])
	end
	if (typeof(team) == typeof(getTeam(context, typeof(team), roleTypes)))
		error("Team $(typeof(team)) is already assigned with the roles $roles")
	end

	roleList = collect(keys(contextManager.teamsAndRoles[context][typeof(team)]))
	for type in roleTypes
		if !(type[1] in roleList)
			error("Team must be assigned with all roles being played exactly once.")
		else
			deleteat!(roleList, findall(x->x==type[1], roleList))
		end
	end
	if roleList != []
		error("Team must be assigned with all roles being played exactly once.")
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
	team
end

function assignRoles(context::Union{Context, Nothing}, team::DynamicTeam, roles...)
	roleTypes = Dict([r => Vector{contextManager.dynTeamsAndData[context][typeof(team)][r]["natType"]}() for r in keys(contextManager.dynTeamsAndData[context][typeof(team)])]...)
	for pair in roles
		push!(roleTypes[typeof(pair[2])], pair[1])
	end

	roleCnt = Dict([r => 0 for r in keys(contextManager.dynTeamsAndData[context][typeof(team)])]...)
	for type in roleTypes
		if !(type[1] in keys(contextManager.dynTeamsAndData[context][typeof(team)]))
			error("Dynamic team must be assigned with all roles being played within the cardinality they are defined with.")
		else
			roleCnt[type[1]] += length(type[2])
		end
	end

	totalCount = sum(values(roleCnt))
	teamProps = contextManager.dynTeamsProp[context][typeof(team)]
	if teamProps["min"] > totalCount
		error("Set minimum assigned roles is $(teamProps["min"]), current is $(totalCount).")
	end
	if teamProps["max"] < totalCount
		error("Set maximum assigned roles is $(teamProps["max"]), current is $(totalCount).")
	end
	for (r, c) in roleCnt
		minimum = contextManager.dynTeamsAndData[context][typeof(team)][r]["min"]
		maximum = contextManager.dynTeamsAndData[context][typeof(team)][r]["max"]
		if !(minimum <= c <= maximum)
			error("Dynamic team must be assigned with all roles being played within the cardinality they are defined with.")
		end
	end

	for rolePair in roles
		obj = rolePair[1]
		role = rolePair[2]
		if !(typeof(obj) <: contextManager.dynTeamsAndData[context][typeof(team)][typeof(role)]["natType"])
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

	if !(context in keys(contextManager.dynTeamDB))
		contextManager.dynTeamDB[context] = Dict()
	end
	contextManager.dynTeamDB[context][team] = Dict(roleTypes)
	team
end

function disassignRoles(context::Union{Context, Nothing}, t::Team, roles::Pair...)
	teamType = typeof(t)
	if !(context in keys(contextManager.teamDB))
		error("No team is assigned context $(context) is not assigned to context $(context)")
	end
	if !(teamType in typeof.(keys(contextManager.teamDB[context])))
		error("Team $teamType is not defined in context $(context)")
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
		if isempty(contextManager.roleDB[obj][context])
			delete!(contextManager.roleDB[obj], context)
			if isempty(contextManager.roleDB[obj])
			delete!(contextManager.roleDB, obj)
			end
		end
	end
	for (i, roleGroup) in enumerate(contextManager.teamDB[context][team])
		if roleGroup == Dict(rolesMirrored...)
			deleteat!(contextManager.teamDB[context][team], i)
			break
		end
	end	
end

function disassignRoles(context::Union{Context, Nothing}, teamType::Type, roles::Pair...)
	if !(context in keys(contextManager.teamDB))
		error("No team is assigned context $(context) is not assigned to context $(context)")
	end
	if !(teamType in typeof.(keys(contextManager.teamDB[context])))
		error("Team $teamType is not defined in context $(context)")
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
		if isempty(contextManager.roleDB[obj][context])
			delete!(contextManager.roleDB[obj], context)
			if isempty(contextManager.roleDB[obj])
			delete!(contextManager.roleDB, obj)
			end
		end
	end
	for (i, roleGroup) in enumerate(contextManager.teamDB[context][team])
		if roleGroup == Dict(rolesMirrored...)
			deleteat!(contextManager.teamDB[context][team], i)
			break
		end
	end	
end

function disassignRoles(context::Union{Context, Nothing}, team::DynamicTeam)
	if team in keys(contextManager.roleDB)
		error("Team $(team) is currently playing a role. You must disassign it before dissolving the team.")
	end
	roles = contextManager.dynTeamDB[context][team]
	for rolePair in roles
		role = rolePair[1]
		objs = rolePair[2]
		for obj in objs
			for c in getContexts()
				roleObj = getRole(c, obj, team)
				if roleObj in keys(contextManager.roleDB)
					error("Role $(roleObj) plays another role. You must diassign it before dissolving the team.")
				end
			end											
			if !(obj in keys(contextManager.roleDB))
				error("Role $role is not assigned to $(repr(obj)) in context $(context)")
			end
			if !(context in keys(contextManager.roleDB[obj]))
				error("Role $role is not assigned to $(repr(obj)) in context $(context)")
			end
			if !(typeof(team) in typeof.(keys(contextManager.roleDB[obj][context])))
				error("Role $role is not assigned to $(repr(obj)) in context $(context)")
			end
			delete!(contextManager.roleDB[obj][context], team)
			if isempty(contextManager.roleDB[obj][context])
				delete!(contextManager.roleDB[obj], context)
				if isempty(contextManager.roleDB[obj])
					delete!(contextManager.roleDB, obj)
				end
			end
		end
	end
	delete!(contextManager.dynTeamDB[context], team)
	if isempty(contextManager.dynTeamDB[context])
		delete!(contextManager.roleDB, context)
	end
end

function disassignRoles(team::DynamicTeam)
	disassignRoles(nothing, team)
end

function disassignRoles(context::Union{Context, Nothing}, teamType::Type, id)
	disassignRoles(context, getDynamicTeam(context, teamType, id))
end

function disassignRoles(teamType::Type, id)
	disassignRoles(nothing, teamType, id)
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

macro team(teamType, id, functionCall)
	if typeof(functionCall) != Expr
		error("Must be called on a function call")
	else
		Base.remove_linenums!(functionCall)
		for (i, arg) in enumerate(functionCall.args)
			if typeof(arg) == Expr
				Base.remove_linenums!(arg)
				if arg.head == :macrocall
					if arg.args[1] == Symbol("@role")
						newArg = quote
							getRole($(arg.args[3]), getDynamicTeam($teamType, $id))
						end
						functionCall.args[i] = newArg
					end
				end
			end
		end
	end
	esc(functionCall)
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

function Base.:&(c1::CT1, c2::CT2) where {CT1, CT2 <: Union{AbstractContext}}
    AndContextRule(c1, c2)
end

function Base.:|(c1::CT1, c2::CT2) where {CT1, CT2 <: Union{AbstractContext}}
    OrContextRule(c1, c2)
end

function Base.:!(c::CT) where {CT <: Union{AbstractContext}}
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

function genContextRuleMatrix(cr::T, cdict::Dict, nc::Int) where {T <: Union{AbstractContext, Nothing}}
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