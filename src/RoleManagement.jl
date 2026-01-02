
"""
    RoleManagement

Holds all context-related data structures, including:
- `contexts`: All defined contexts.
- `activeContexts`: Currently active contexts.
- `mixins`, `mixinTypeDB`, `mixinDB`: Mixin management.
- `teamsAndRoles`, `roleDB`, `teamDB`, `dynTeamDB`, `dynTeamsAndData`, `dynTeamsProp`: Team and role management.
"""

@with_kw mutable struct RoleManagement
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
global roleManager = RoleManagement()

"""
    addMixin(context, contextualType, mixinNameSymbol)

Adds a mixin within a context for a given contextual type to the manager.

Arguments:
- `context`: Context
- `contextualType`: Type to associate the mixin with
- `mixinNameSymbol`: Symbol of the mixin type

Example:
    addMixin(MyContext, MyType, :MyMixin)
"""
function addMixin(context, contextualType, mixinNameSymbol)
	if context in keys(roleManager.mixins)
		if contextualType in keys(roleManager.mixins[context])
			push!(roleManager.mixins[context][contextualType], mixinNameSymbol)
		else
			roleManager.mixins[context][contextualType] = [mixinNameSymbol]
		end
	else
		roleManager.mixins[context] = Dict((contextualType)=>[mixinNameSymbol])
	end
end

"""
    addTeam(context::Union{Context, Nothing}, team, rolesAndTypes::Dict{DataType, DataType})

Adds a team definition to a context, specifying roles and their types.

Arguments:
- `context`: Context or nothing
- `team`: Team type
- `rolesAndTypes`: Dict mapping role types to object types

Example:
    addTeam(MyContext, MyTeam, Dict(RoleA=>Person, RoleB=>Manager))
"""
function addTeam(context::Union{Context, Nothing}, team, rolesAndTypes::Dict{DataType, DataType})
	if context in keys(roleManager.teamsAndRoles)
		if team in keys(roleManager.teamsAndRoles[context])
			error("Context already contains team with name")
		else
			roleManager.teamsAndRoles[context][team] = rolesAndTypes
		end
	else
		roleManager.teamsAndRoles[context] = Dict((team)=>rolesAndTypes)
	end
end

"""
    addDynamicTeam(context::Union{Context, Nothing}, team::DataType, rolesAndData::Dict{DataType, Dict{String, Any}}, id, min, max)

Adds a dynamic team definition to a context, specifying roles, cardinalities, and team id.

Arguments:
- `context`: Context or nothing
- `team`: DynamicTeam type
- `rolesAndData`: Dict mapping role types to data dicts
- `id`: Team id
- `min`: Minimum number of players
- `max`: Maximum number of players

Example:
    addDynamicTeam(MyContext, MyDynTeam, Dict(RoleA=>Dict(...)), :teamid, 2, 5)
"""
function addDynamicTeam(context::Union{Context, Nothing}, team::DataType, rolesAndData::Dict{DataType, Dict{String, Any}}, id, min, max)
	if context in keys(roleManager.dynTeamsAndData)
		if team in keys(roleManager.dynTeamsAndData[context])
			error("Context already contains team with name")
		else
			roleManager.dynTeamsAndData[context][team] = rolesAndData
			roleManager.dynTeamsProp[context][team] = Dict("ID" => id, "min" => min, "max" => max)
		end
	else
		roleManager.dynTeamsAndData[context] = Dict((team)=>rolesAndData)
		roleManager.dynTeamsProp[context] = Dict((team)=>Dict("ID" => id, "min" => min, "max" => max))
	end
end

"""
    hasMixin(context::Context, obj, mixin::Type)

Checks if an object has a mixin of the given type in a context.

Arguments:
- `context`: Context
- `obj`: Object
- `mixin`: Mixin type

Returns true or false.

Example:
    hasMixin(MyContext, obj, MyMixin)
"""
function hasMixin(context::Context, obj, mixin::Type)
	if obj in keys(roleManager.mixinDB)
		if context in keys(roleManager.mixinDB[obj])
			if mixin in [typeof(m) for m in roleManager.mixinDB[obj][context]]
				return true
			end
		end
	end
	false
end

"""
    getMixins()

Returns all mixin definitions for all contexts.

Example:
    getMixins()
"""
function getMixins()
	roleManager.mixins
end

"""
    getMixins(type)

Returns all mixin instances for a given type.

Arguments:
- `type`: Type

Example:
    getMixins(MyType)
"""
function getMixins(type)
	roleManager.mixinDB[type]
end

"""
    getMixins(context::Context, type)

Returns all mixin instances for a type in a context.

Arguments:
- `context`: Context
- `type`: Type

Example:
    getMixins(MyContext, MyType)
"""
function getMixins(context::Context, type)
	if !(type in keys(roleManager.mixinDB))
		return []
	end
	(roleManager.mixinDB[type])[context]
end

"""
    getMixin(context::Context, type, mixin::Type)

Returns the mixin instance of a given type for a type in a context.

Arguments:
- `context`: Context
- `type`: Type
- `mixin`: Mixin type

Example:
    getMixin(MyContext, MyType, MyMixin)
"""
function getMixin( context::Context, type, mixin::Type)
	if !(mixin in roleManager.mixins[context][typeof(type)])
		error("Mixin $mixin not defined in context $context for type $(typeof(type))")
	end
	for m in (roleManager.mixinDB[type])[context]
		if typeof(m) == mixin
			return m
		end
	end
	nothing
end

"""
    getObjectsOfMixin(context::Context, mixin::Type)

Returns all objects in a context that have a mixin of the given type.

Arguments:
- `context`: Context
- `mixin`: Mixin type

Example:
    getObjectsOfMixin(MyContext, MyMixin)
"""
function getObjectsOfMixin(context::Context, mixin::Type)
	l = []
	for obj in keys(roleManager.mixinDB)
		for mixin_i in values(roleManager.mixinDB[obj][context])
			if typeof(mixin_i) == mixin
				push!(l, obj)
			end
		end
	end
	l
end

"""
    getObjectOfRole(context::Union{Context, Nothing}, team::Type, role::Type)

Returns all objects in a context that have a specific role in a specific team.

Arguments:
- `context`: Context or nothing
- `team`: Team type
- `role`: Role type

Example:
    getObjectOfRole(MyContext, MyTeam, Manager)
"""
function getObjectOfRole(context::Union{Context, Nothing}, team::Type, role::Type)
	objs = []
	for obj in keys(roleManager.roleDB)
		for (team_i, role_i) in roleManager.roleDB[obj][context]
			if (typeof(role_i) == role) & (typeof(team_i) == team)
				push!(objs, obj)
			end
		end
	end
	objs
end

"""
    getObjectOfRole(context::Union{Context, Nothing}, team::DynamicTeam, role::Role)

Returns the object in a context that has a specific role in a specific dynamic team.

Arguments:
- `context`: Context or nothing
- `team`: DynamicTeam type
- `role`: Role type

Example:
    getObjectOfRole(MyContext, MyDynTeam, Manager)
"""
function getObjectOfRole(context::Union{Context, Nothing}, team::DynamicTeam, role::Role)
	for obj in keys(roleManager.roleDB)
		if context in keys(roleDB[obj])
			if roleManager.roleDB[obj][context][team] == role
					return obj
			end
		end
	end
end
"""
    getObjectOfRole(team::DynamicTeam, role::Role)

Convenience function to getObjectOfRole with no context.

Arguments:
- `team`: DynamicTeam type
- `role`: Role type

Example:
    getObjectOfRole(MyDynTeam, Manager)
"""
function getObjectOfRole(team::DynamicTeam, role::Role)
	getObjectOfRole(nothing, team, role)
end

"""
    getObjectOfRole(context::Union{Context, Nothing}, role::Role)

Returns the object in a context that has a specific role.

Arguments:
- `context`: Context or nothing
- `role`: Role type

Example:
    getObjectOfRole(MyContext, Manager)
"""
function getObjectOfRole(context::Union{Context, Nothing}, role::Role)
	for obj in keys(roleManager.roleDB)
		if context in keys(roleManager.roleDB[obj])
			for role_i in values(roleManager.roleDB[obj][context])
				if role_i == role
					return obj
				end
			end
		end
	end
end
"""
    getObjectOfRole(role::Role)

Convenience function to getObjectOfRole with no context.

Arguments:
- `role`: Role type

Example:
    getObjectOfRole(Manager)
"""
function getObjectOfRole(role::Role)
	getObjectOfRole(nothing, role)
end

"""
    getObjectsOfRole(context::Union{Context, Nothing}, team::DynamicTeam, role::Type)

Returns all objects in a context that have a specific role in a specific dynamic team.

Arguments:
- `context`: Context or nothing
- `team`: DynamicTeam type
- `role`: Role type

Example:
    getObjectsOfRole(MyContext, MyDynTeam, Manager)
"""
function getObjectsOfRole(context::Union{Context, Nothing}, team::DynamicTeam, role::Type)
	if !(context in keys(roleManager.dynTeamDB))
		return []
	end
	if !(team in keys(roleManager.dynTeamDB[context]))
		return []
	end
	if !(role in keys(roleManager.dynTeamDB[context][team]))
		return []
	end
	roleManager.dynTeamDB[context][team][role]
end
"""
    getObjectsOfRole(team::DynamicTeam, role::Type)

Convenience function to getObjectsOfRole with no context.

Arguments:
- `team`: DynamicTeam type
- `role`: Role type

Example:
    getObjectsOfRole(MyDynTeam, Manager)
"""
function getObjectsOfRole(team::DynamicTeam, role::Type)
	getObjectsOfRole(nothing, team, role)
end

"""
    hasRole(context::Union{Context, Nothing}, obj, role::Type, team::Team)

Checks if an object has a specific role in a specific team in a context.

Arguments:
- `context`: Context or nothing
- `obj`: Object
- `role`: Role type
- `team`: Team type

Returns true or false.

Example:
    hasRole(MyContext, obj, Manager, MyTeam)
"""
function hasRole(context::Union{Context, Nothing}, obj, role::Type, team::Team)
	#if role in typeof.(collect(keys(roleManager.roleDB[obj][context][team])))
	for concreteRole in getRoles(context, obj, team)
		if typeof(concreteRole) == role
			return true
		end
	end
	false
end

"""
    hasRole(context::Union{Context, Nothing}, obj, role::Type, team::DynamicTeam)

Checks if an object has a specific role in a specific dynamic team in a context.

Arguments:
- `context`: Context or nothing
- `obj`: Object
- `role`: Role type
- `team`: DynamicTeam type

Returns true or false.

Example:
    hasRole(MyContext, obj, Manager, MyDynTeam)
"""
function hasRole(context::Union{Context, Nothing}, obj, role::Type, team::DynamicTeam)
	role == typeof(getRole(context, obj, team))
end

"""
    hasRole(obj, role::Type, team::DynamicTeam)

Convenience function to hasRole with no context.

Arguments:
- `obj`: Object
- `role`: Role type
- `team`: DynamicTeam type

Returns true or false.

Example:
    hasRole(obj, Manager, MyDynTeam)
"""
function hasRole(obj, role::Type, team::DynamicTeam)
	hasRole(nothing, obj, role, team)
end


"""
    hasRole(context::Union{Context, Nothing}, obj, roleType::Type, teamType::Type)

Checks if an object has any role of a given type in a team of a given type in a context.

Arguments:
- `context`: Context or nothing
- `obj`: Object
- `roleType`: Role type
- `teamType`: Team type

Returns true or false.

Example:
    hasRole(MyContext, obj, Manager, ProjectTeam)
"""
function hasRole(context::Union{Context, Nothing}, obj, roleType::Type, teamType::Type)
	return length(getRoles(context, obj, roleType, teamType)) != 0
end

"""
    hasRole(obj, roleType::Type, teamType::Type)

Convenience function to hasRole with no context.

Arguments:
- `obj`: Object
- `roleType`: Role type
- `teamType`: Team type

Returns true or false.

Example:
    hasRole(obj, Manager, ProjectTeam)
"""
function hasRole(obj, roleType::Type, teamType::Type)
	return length(getRoles(nothing, obj, roleType, teamType)) != 0
end


"""
    getRoles(context::Union{Context, Nothing}, obj, role::Type, teamType::Type)

Returns all roles of a given type in a team of a given type for an object in a context.

Arguments:
- `context`: Context or nothing
- `obj`: Object
- `role`: Role type
- `teamType`: Team type

Example:
    getRoles(MyContext, obj, Manager, ProjectTeam)
"""
function getRoles(context::Union{Context, Nothing}, obj, role::Type, teamType::Type)
	roles = []
	if !(obj in keys(roleManager.roleDB))
		return []
	end
	for team in keys(roleManager.roleDB[obj][context])
		if typeof(team) == teamType
			concreteRole = roleManager.roleDB[obj][context][team]
			if typeof(concreteRole) == role
				push!(roles, concreteRole)
			end
		end
	end
	return roles
end

"""
    getRoles(context::Union{Context, Nothing}, obj, role::Type)

Returns all roles of a given type for an object in a context.

Arguments:
- `context`: Context or nothing
- `obj`: Object
- `role`: Role type

Example:
    getRoles(MyContext, obj, Manager)
"""
function getRoles(context::Union{Context, Nothing}, obj, role::Type)
	roles = []
	for team in roleManager.roleDB[obj][context]
		concreteRole = roleManager.roleDB[obj][context][team]
		if typeof(concreteRole) == role
			push!(roles, concreteRole)
		end
	end
	return roles
end

"""
    getRole(context::Union{Context, Nothing}, obj::T, team::DynamicTeam) where T

Returns the role for an object in a dynamic team in a context.

Arguments:
- `context`: Context or nothing
- `obj`: Object
- `team`: DynamicTeam type

Example:
    getRole(MyContext, obj, MyDynTeam)
"""
function getRole(context::Union{Context, Nothing}, obj::T, team::DynamicTeam) where T
	if !(haskey(roleManager.roleDB, obj))
		return nothing
	elseif !(haskey(roleManager.roleDB[obj], context))
		return nothing
	elseif !(haskey(roleManager.roleDB[obj][context], team))
		return nothing
	end
	roleManager.roleDB[obj][context][team]
end

"""
    getRole(obj::T, team::DynamicTeam) where T

Convenience function to getRole with no context.

Arguments:
- `obj`: Object
- `team`: DynamicTeam type

Example:
    getRole(obj, MyDynTeam)
"""
function getRole(obj::T, team::DynamicTeam) where T
	getRole(nothing, obj, team)
end

"""
    getRoles(context::Union{Context, Nothing}, obj)

Returns all roles for an object in a context.

Arguments:
- `context`: Context or nothing
- `obj`: Object

Example:
    getRoles(MyContext, obj)
"""
function getRoles(context::Union{Context, Nothing}, obj)
	if haskey(roleManager.roleDB, obj)
		return roleManager.roleDB[obj][context]
	end
	return nothing
end

"""
    getRoles(obj)

Returns all roles for an object.

Arguments:
- `obj`: Object

Example:
    getRoles(obj)
"""
function getRoles(obj)
	if haskey(roleManager.roleDB, obj)
		return roleManager.roleDB[obj]
	end
	return nothing
end

"""
    getRolesOfTeam(context::Union{Context, Nothing}, team::Team)

Returns all roles in a team in a context.

Arguments:
- `context`: Context or nothing
- `team`: Team type

Example:
    getRolesOfTeam(MyContext, MyTeam)
"""
function getRolesOfTeam(context::Union{Context, Nothing}, team::Team)
	roleManager.teamDB[context][team]
end

"""
    getRolesOfTeam(team::Team)

Convenience function to getRolesOfTeam with no context.

Arguments:
- `team`: Team type

Example:
    getRolesOfTeam(MyTeam)
"""
function getRolesOfTeam(team::Team)
	roleManager.teamDB[nothing][team]
end

"""
    getRolesOfTeam(context::Union{Context, Nothing}, team::DynamicTeam)

Returns all roles in a dynamic team in a context.

Arguments:
- `context`: Context or nothing
- `team`: DynamicTeam type

Example:
    getRolesOfTeam(MyContext, MyDynTeam)
"""
function getRolesOfTeam(context::Union{Context, Nothing}, team::DynamicTeam)
	roleManager.dynTeamDB[context][team]
end

"""
    getRolesOfTeam(team::DynamicTeam)

Convenience function to getRolesOfTeam with no context.

Arguments:
- `team`: DynamicTeam type

Example:
    getRolesOfTeam(MyDynTeam)
"""
function getRolesOfTeam(team::DynamicTeam)
	roleManager.dynTeamDB[nothing][team]
end

"""
    getTeam(context::Union{Context, Nothing}, teamType::Type, rolePairs...)

Returns the first team in a context that matches the given role pairs.

Arguments:
- `context`: Context or nothing
- `teamType`: Team type
- `rolePairs`: Vararg of role type and object type pairs

Example:
    getTeam(MyContext, MyTeam, RoleA=>Person, RoleB=>Manager)
"""
function getTeam(context::Union{Context, Nothing}, teamType::Type, rolePairs...)
	teams = []
	if !(context in keys(roleManager.teamDB))
		return nothing
	end
	for (team, rolesObjs ) in roleManager.teamDB[context]
		roleDict = Dict(rolePairs...)
		if roleDict in rolesObjs
			return team
		end
	end
	nothing
end

"""
    getDynamicTeam(context::Union{Context, Nothing}, role::Role)

Returns the dynamic team in a context that has a specific role.

Arguments:
- `context`: Context or nothing
- `role`: Role type

Example:
    getDynamicTeam(MyContext, Manager)
"""
function getDynamicTeam(context::Union{Context, Nothing}, role::Role)
	if !(context in keys(roleManager.dynTeamDB))
		return nothing
	end
	for obj in keys(roleManager.roleDB)
		for team in keys(roleManager.roleDB[obj][context])
			if roleManager.roleDB[obj][context][team] == role
				return team
			end
		end
	end
	return nothing
end

"""
    getDynamicTeam(role::Role)

Convenience function to getDynamicTeam with no context.

Arguments:
- `role`: Role type

Example:
    getDynamicTeam(Manager)
"""
function getDynamicTeam(role::Role)
	getDynamicTeam(nothing, role)
end

"""
    getDynamicTeamID(context::Union{Context, Nothing}, team::DynamicTeam)

Returns the properties of a dynamic team in a context.

Arguments:
- `context`: Context or nothing
- `team`: DynamicTeam type

Example:
    getDynamicTeamID(MyContext, MyDynTeam)
"""
function getDynamicTeamID(context::Union{Context, Nothing}, team::DynamicTeam)
	roleManager.dynTeamsProp[context][team]
end

"""
    getDynamicTeamID(team::DynamicTeam)

Convenience function to getDynamicTeamID with no context.

Arguments:
- `team`: DynamicTeam type

Example:
    getDynamicTeamID(MyDynTeam)
"""
function getDynamicTeamID(team::DynamicTeam)
	roleManager.dynTeamsProp[nothing][team]
end

"""
    getDynamicTeam(context::Union{Context, Nothing}, teamType::DataType, id::T) where T

Returns a dynamic team by id in a context.

Arguments:
- `context`: Context or nothing
- `teamType`: Team type
- `id`: Id value

Example:
    getDynamicTeam(MyContext, MyDynTeam, :teamid, 123)
"""
function getDynamicTeam(context::Union{Context, Nothing}, teamType::DataType, id::T) where T
	d = get!(roleManager.dynTeamDB, context, Dict())
	idName = roleManager.dynTeamsProp[context][teamType]["ID"]
	for team in keys(d)
		if typeof(team) == teamType
			if getfield(team, idName) == id
				return team
			end	
		end
	end
	nothing
end

"""
    getDynamicTeam(teamType::DataType, id::T) where T

Convenience function to getDynamicTeam with no context.

Arguments:
- `teamType`: Team type
- `id`: Id value

Example:
    getDynamicTeam(MyDynTeam, 123)
"""
function getDynamicTeam(teamType::DataType, id::T) where T
	getDynamicTeam(nothing, teamType, id)
end

"""
    getDynamicTeams(context::Union{Context, Nothing}, teamType::Type)

Returns all dynamic teams of a given type in a context.

Arguments:
- `context`: Context or nothing
- `teamType`: Team type

Example:
    getDynamicTeams(MyContext, MyDynTeam)
"""
function getDynamicTeams(context::Union{Context, Nothing}, teamType::Type)
	if !(context in keys(roleManager.dynTeamDB))
		return nothing
	end
	teams = []
	for team in keys(roleManager.dynTeamDB[context])
		if typeof(team) == teamType
			push!(teams, team)
		end
	end
	teams
end

"""
    getDynamicTeams(teamType::Type)

Convenience function to getDynamicTeams with no context.

Arguments:
- `teamType`: Team type

Example:
    getDynamicTeams(MyDynTeam)
"""
function getDynamicTeams(teamType::Type)
	getDynamicTeams(nothing, teamType)
end

"""
    getTeamPartners(context::Union{Context, Nothing}, obj::Any, roleType::Type, team::Team)

Returns the partner object in a team for the specified object and role type in a context.

Arguments:
- `context`: Context or nothing
- `obj`: Object to find partner for
- `roleType`: Role type
- `team`: Team type

Returns a partner group (Dict).

Example:
    getTeamPartners(ctx, alice, Manager, MyTeam)
"""
function getTeamPartners(context::Union{Context, Nothing}, obj::Any, roleType::Type, team::Team)
	groups = roleManager.teamDB[context][team]
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

"""
    getTeamPartners(context::Union{Context, Nothing}, obj::Any, roleType::Type, teamType::Type)

Returns all partner objects in teams of the given type, for the specified object and role type in a context.
Removes the roleType from the returned partner groups.

Arguments:
- `context`: Context or nothing
- `obj`: Object to find partners for
- `roleType`: Role type
- `teamType`: Team type

Returns a vector of partner groups (Dicts).

Example:
    getTeamPartners(ctx, alice, Manager, ProjectTeam)
"""
function getTeamPartners(context::Union{Context, Nothing}, obj::Any, roleType::Type, teamType::Type)
	groups = []
	for team in roleManager.teamDB[context]
		if typeof(team[1]) == teamType
			push!(groups, (roleManager.teamDB[context][team[1]])...)
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