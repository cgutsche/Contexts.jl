
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