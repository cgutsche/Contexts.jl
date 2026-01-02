"""
    Base.:(<<)(mixin::DataType, type::DataType)

Checks if a mixin or role can be assigned to a natural type using the << operator.
Returns true if assignment is valid, false otherwise.

Arguments:
- `mixin`: Mixin or Role type
- `type`: Target type

Returns true or false.

Example:
    MyMixin << MyType
"""
function Base.:(<<)(mixin::DataType, type::DataType)
	if mixin <: Mixin
		for entry in values(roleManager.mixins)
			for (key, list) in entry
				if (key == type) & (mixin in list)
					return true
				end
			end
		end
	elseif mixin <: Role
		for entry in values(roleManager.teamsAndRoles)
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

"""
    assignMixin(context::Context, pair::Pair)

Assigns a mixin to a type in a given context.

Arguments:
- `context`: Context
- `pair`: Pair of (type, mixin)

Example:
    assignMixin(ctx, MyType => MyMixin())
"""
function assignMixin(context::Context, pair::Pair)
	type = pair[1]
	mixin = pair[2]
	if !(typeof(mixin) in roleManager.mixins[context][typeof(type)])
		error("Mixin $mixin can not be assigned to Type $type")
	end
	if type in keys(roleManager.mixinDB)
		if context in keys(roleManager.mixinDB[type])
			push!(roleManager.mixinDB[type][context], mixin)
		else
			roleManager.mixinDB[type][context] = [mixin]
		end
	else
		roleManager.mixinDB[type] = Dict(context => [mixin])
	end
	if type in keys(roleManager.mixinTypeDB)
		roleManager.mixinTypeDB[type][context] = typeof(mixin)
	else
		roleManager.mixinTypeDB[type] = Dict(context => typeof(mixin))
	end
end

"""
    disassignMixin(context::Context, pair::Pair)

Removes a mixin assignment from a type in a given context.

Arguments:
- `context`: Context
- `pair`: Pair of (type, mixin)

Example:
    disassignMixin(ctx, MyType => MyMixin())
"""
function disassignMixin(context::Context, pair::Pair)
	type = pair[1]
	mixin = pair[2]
	if type in keys(roleManager.mixinDB)
		delete!(roleManager.mixinDB[type], context)
	else
		error("Mixin is not assigned to type "*repr(type))
	end
	if type in keys(roleManager.mixinTypeDB)
		delete!(roleManager.mixinTypeDB[type], context)
	else
		error("Mixin is not assigned to type "*repr(type))
	end
end

"""
    @assignRoles(context, team, attrs)

Macro to assign roles to objects in a team within a context.

Arguments:
- `context`: Context
- `team`: Team type
- `attrs`: Block of assignments (object >> Role)

Example:
    @assignRoles(ctx, MyTeam, begin
        obj1 >> RoleA
        obj2 >> RoleB
    end)
"""
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

"""
    @assignRoles(team, attrs)

Macro to assign roles to objects in a team (no context).

Arguments:
- `team`: Team type
- `attrs`: Block of assignments (object >> Role)

Example:
    @assignRoles(MyTeam, begin
        obj1 >> RoleA
        obj2 >> RoleB
    end)
"""
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

"""
    @disassignRoles(context, team, attrs)

Macro to remove role assignments from objects in a team within a context.

Arguments:
- `context`: Context
- `team`: Team type
- `attrs`: Block of assignments (Role >> object)

Example:
    @disassignRoles(ctx, MyTeam, begin
        RoleA >> obj1
        RoleB >> obj2
    end)
"""
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

"""
    @disassignRoles(team, attrs)

Macro to remove role assignments from objects in a team (no context).

Arguments:
- `team`: Team type
- `attrs`: Block of assignments (Role >> object)

Example:
    @disassignRoles(MyTeam, begin
        RoleA >> obj1
        RoleB >> obj2
    end)
"""
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

"""
    @changeRoles(context, team, id, attrs)

Macro to change role assignments and disassignments in a dynamic team within a context.

Arguments:
- `context`: Context
- `team`: DynamicTeam type
- `id`: Team id
- `attrs`: Block of assignments (object >> Role, object << Role)

Example:
    @changeRoles(ctx, MyDynTeam, 1, begin
        obj1 >> RoleA
        obj2 << RoleB
    end)
"""
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

"""
    @changeRoles(team, id, attrs)

Macro to change role assignments and disassignments in a dynamic team (no context).

Arguments:
- `team`: DynamicTeam type
- `id`: Team id
- `attrs`: Block of assignments (object >> Role, object << Role)

Example:
    @changeRoles(MyDynTeam, 1, begin
        obj1 >> RoleA
        obj2 << RoleB
    end)
"""
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

"""
    changeRoles(context::Union{Context, Nothing}, team::DynamicTeam, roleAssignment::Vector{Any}, roleDisassignment::Vector{Pair{T, DataType}})

Changes role assignments and disassignments in a dynamic team within a context.

Arguments:
- `context`: Context or nothing
- `team`: DynamicTeam
- `roleAssignment`: Vector of assignments (object, Role)
- `roleDisassignment`: Vector of disassignments (object, Role type)

Example:
    changeRoles(ctx, team, [(obj1, RoleA)], [(obj2, RoleB)])
"""
function changeRoles(context::Union{Context, Nothing}, team::DynamicTeam, roleAssignment::Vector{Any}, roleDisassignment::Vector{Pair{T, DataType}}) where T
	roles = roleManager.dynTeamDB[context][team]
	roleProps = roleManager.dynTeamsAndData[context][typeof(team)]
	teamProps = roleManager.dynTeamsProp[context][typeof(team)]
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
		if haskey(roleManager.roleDB, roleObj)
			error("Role $(roleObj) plays another role. You must diassign it before dissolving the team.")
		end
		get!(get!(roleManager.roleDB, obj, Dict()), context, Dict())
		if !(haskey(roleManager.roleDB[obj][context], team))
			error("$obj does not play role $role in team $team.")
		end
		if isa(roleManager.roleDB[obj][context][team], role)
			delete!(roleManager.roleDB[obj][context], team)
		else
			error("$obj does not play role $role.")
		end
		filter!(x -> x != obj, roles[role])
		if isempty(roleManager.roleDB[obj][context])
			delete!(roleManager.roleDB[obj], context)
			if isempty(roleManager.roleDB[obj])
			delete!(roleManager.roleDB, obj)
			end
		end
	end
end

"""
    changeRoles(context::Union{Context, Nothing}, team::DynamicTeam, roleAssignment::Vector{Pair{T, R}}, roleDisassignment::Vector{Any}) where T where R <: Role

Changes role assignments in a dynamic team within a context.

Arguments:
- `context`: Context or nothing
- `team`: DynamicTeam
- `roleAssignment`: Vector of assignments (object, Role)
- `roleDisassignment`: Vector of objects to disassign

Example:
    changeRoles(ctx, team, [(obj1, RoleA)], [obj2])
"""
function changeRoles(context::Union{Context, Nothing}, team::DynamicTeam, roleAssignment::Vector{Pair{T, R}}, roleDisassignment::Vector{Any}) where T where R <: Role
	roles = roleManager.dynTeamDB[context][team]
	roleProps = roleManager.dynTeamsAndData[context][typeof(team)]
	teamProps = roleManager.dynTeamsProp[context][typeof(team)]
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
		if !(isa(obj, roleManager.dynTeamsAndData[context][typeof(team)][typeof(role)]["natType"]))
			error("Role $(typeof(role)) can not be assigned to Type $(typeof(obj))")
		end
		d = get!(get!(roleManager.roleDB, obj, Dict()), context, Dict())
		if haskey(d, team)
			error("$obj already plays role in team $team.")
		end
		d[team] = role
		push!(roles[typeof(role)], obj)
	end
end

"""
    changeRoles(context::Union{Context, Nothing}, team::DynamicTeam, roleAssignment::Vector{Pair{T1, R}}, roleDisassignment::Vector{Pair{T2, DataType}}) where T1 where T2 where R <: Role

Changes role assignments and disassignments in a dynamic team within a context.

Arguments:
- `context`: Context or nothing
- `team`: DynamicTeam
- `roleAssignment`: Vector of assignments (object, Role)
- `roleDisassignment`: Vector of disassignments (object, Role type)

Example:
    changeRoles(ctx, team, [(obj1, RoleA)], [(obj2, RoleB)])
"""
function changeRoles(context::Union{Context, Nothing}, team::DynamicTeam, roleAssignment::Vector{Pair{T1, R}}, roleDisassignment::Vector{Pair{T2, DataType}}) where T1 where T2 where R <: Role
	roles = roleManager.dynTeamDB[context][team]
	roleProps = roleManager.dynTeamsAndData[context][typeof(team)]
	teamProps = roleManager.dynTeamsProp[context][typeof(team)]
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
		if haskey(roleManager.roleDB, roleObj)
			error("Role $(roleObj) plays another role. You must diassign it before dissolving the team.")
		end
		get!(get!(roleManager.roleDB, obj, Dict()), context, Dict())
		if !(haskey(roleManager.roleDB[obj][context], team))
			error("$obj does not play role $role in team $team.")
		end
		if isa(roleManager.roleDB[obj][context][team], role)
			delete!(roleManager.roleDB[obj][context], team)
		else
			error("$obj does not play role $role.")
		end
		#filter!(x -> x != obj, roleManager.dynTeamDB[context][team][role])
		deleteat!(roles[role], findfirst(isequal(obj), roles[role]))
		if isempty(roleManager.roleDB[obj][context])
			delete!(roleManager.roleDB[obj], context)
			if isempty(roleManager.roleDB[obj])
			delete!(roleManager.roleDB, obj)
			end
		end
	end

	for rolePair in roleAssignment
		role = rolePair[2]
		obj = rolePair[1]
		if !(isa(obj, roleManager.dynTeamsAndData[context][typeof(team)][typeof(role)]["natType"]))
			error("Role $(typeof(role)) can not be assigned to Type $(typeof(obj))")
		end
		d = get!(get!(roleManager.roleDB, obj, Dict()), context, Dict())
		if haskey(d, team)
			error("$obj already plays role in team $team.")
		end
		d[team] = role
		push!(roles[typeof(role)], obj)
	end
end

"""
    assignRoles(context::Union{Context, Nothing}, team::Team, roles...)

Assigns roles to objects in a team within a context.

Arguments:
- `context`: Context or nothing
- `team`: Team
- `roles...`: Pairs of (object, Role)

Example:
    assignRoles(ctx, team, obj1 => RoleA, obj2 => RoleB)
"""
function assignRoles(context::Union{Context, Nothing}, team::Team, roles...)
	roleTypes = []
	for pair in roles
		push!(roleTypes, typeof(pair[2]) => pair[1])
	end
	if (typeof(team) == typeof(getTeam(context, typeof(team), roleTypes)))
		error("Team $(typeof(team)) is already assigned with the roles $roles")
	end

	roleList = collect(keys(roleManager.teamsAndRoles[context][typeof(team)]))
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
		if !(typeof(obj) == roleManager.teamsAndRoles[context][typeof(team)][typeof(role)])
			error("Role $(typeof(role)) can not be assigned to Type $(typeof(obj))")
		end
		if !(obj in keys(roleManager.roleDB))
			roleManager.roleDB[obj] = Dict()
		end
		if !(context in keys(roleManager.roleDB[obj]))
			roleManager.roleDB[obj][context] = Dict()
		end
		roleManager.roleDB[obj][context][team] = role
	end

	if !(context in keys(roleManager.teamDB))
		roleManager.teamDB[context] = Dict()
	end
	if !(team in keys(roleManager.teamDB[context]))
		roleManager.teamDB[context][team] = [Dict(roleTypes...)]
	else
		push!(roleManager.teamDB[context][team], Dict(roleTypes...))
	end
	team
end

"""
    assignRoles(context::Union{Context, Nothing}, team::DynamicTeam, roles...)

Assigns roles to objects in a dynamic team within a context.

Arguments:
- `context`: Context or nothing
- `team`: DynamicTeam
- `roles...`: Pairs of (object, Role)

Example:
    assignRoles(ctx, team, obj1 => RoleA, obj2 => RoleB)
"""
function assignRoles(context::Union{Context, Nothing}, team::DynamicTeam, roles...)
	roleTypes = Dict([r => Vector{roleManager.dynTeamsAndData[context][typeof(team)][r]["natType"]}() for r in keys(roleManager.dynTeamsAndData[context][typeof(team)])]...)
	for pair in roles
		push!(roleTypes[typeof(pair[2])], pair[1])
	end

	roleCnt = Dict([r => 0 for r in keys(roleManager.dynTeamsAndData[context][typeof(team)])]...)
	for type in roleTypes
		if !(type[1] in keys(roleManager.dynTeamsAndData[context][typeof(team)]))
			error("Dynamic team must be assigned with all roles being played within the cardinality they are defined with.")
		else
			roleCnt[type[1]] += length(type[2])
		end
	end

	totalCount = sum(values(roleCnt))
	teamProps = roleManager.dynTeamsProp[context][typeof(team)]
	if teamProps["min"] > totalCount
		error("Set minimum assigned roles is $(teamProps["min"]), current is $(totalCount).")
	end
	if teamProps["max"] < totalCount
		error("Set maximum assigned roles is $(teamProps["max"]), current is $(totalCount).")
	end
	for (r, c) in roleCnt
		minimum = roleManager.dynTeamsAndData[context][typeof(team)][r]["min"]
		maximum = roleManager.dynTeamsAndData[context][typeof(team)][r]["max"]
		if !(minimum <= c <= maximum)
			error("Dynamic team must be assigned with all roles being played within the cardinality they are defined with.")
		end
	end

	for rolePair in roles
		obj = rolePair[1]
		role = rolePair[2]
		if !(typeof(obj) <: roleManager.dynTeamsAndData[context][typeof(team)][typeof(role)]["natType"])
			error("Role $(typeof(role)) can not be assigned to Type $(typeof(obj))")
		end
		if !(obj in keys(roleManager.roleDB))
			roleManager.roleDB[obj] = Dict()
		end
		if !(context in keys(roleManager.roleDB[obj]))
			roleManager.roleDB[obj][context] = Dict()
		end
		roleManager.roleDB[obj][context][team] = role
	end

	if !(context in keys(roleManager.dynTeamDB))
		roleManager.dynTeamDB[context] = Dict()
	end
	roleManager.dynTeamDB[context][team] = Dict(roleTypes)
	team
end

"""
    disassignRoles(context::Union{Context, Nothing}, t::Team, roles::Pair...)

Removes role assignments from objects in a team within a context.

Arguments:
- `context`: Context or nothing
- `t`: Team
- `roles...`: Pairs of (Role, object)

Example:
    disassignRoles(ctx, team, RoleA => obj1, RoleB => obj2)
"""
function disassignRoles(context::Union{Context, Nothing}, t::Team, roles::Pair...)
	teamType = typeof(t)
	if !(context in keys(roleManager.teamDB))
		error("No team is assigned context $(context) is not assigned to context $(context)")
	end
	if !(teamType in typeof.(keys(roleManager.teamDB[context])))
		error("Team $teamType is not defined in context $(context)")
	end
	rolesMirrored = []
	team = getTeam(context, teamType, roles...)
	for rolePair in roles
		role = rolePair[1]
		obj = rolePair[2]
		push!(rolesMirrored, role=>obj)
		if !(obj in keys(roleManager.roleDB))
			error("Role $role is not assigned to $(repr(obj)) in context $(context)")
		end
		if !(context in keys(roleManager.roleDB[obj]))
			error("Role $role is not assigned to $(repr(obj)) in context $(context)")
		end
		if !(teamType in typeof.(keys(roleManager.roleDB[obj][context])))
			error("Role $role is not assigned to $(repr(obj)) in context $(context)")
		end
		delete!(roleManager.roleDB[obj][context], team)
		if isempty(roleManager.roleDB[obj][context])
			delete!(roleManager.roleDB[obj], context)
			if isempty(roleManager.roleDB[obj])
			delete!(roleManager.roleDB, obj)
			end
		end
	end
	for (i, roleGroup) in enumerate(roleManager.teamDB[context][team])
		if roleGroup == Dict(rolesMirrored...)
			deleteat!(roleManager.teamDB[context][team], i)
			break
		end
	end	
end

"""
    disassignRoles(context::Union{Context, Nothing}, teamType::Type, roles::Pair...)

Removes role assignments from objects in a team type within a context.

Arguments:
- `context`: Context or nothing
- `teamType`: Team type
- `roles...`: Pairs of (Role, object)

Example:
    disassignRoles(ctx, TeamType, RoleA => obj1)
"""
function disassignRoles(context::Union{Context, Nothing}, teamType::Type, roles::Pair...)
	if !(context in keys(roleManager.teamDB))
		error("No team is assigned context $(context) is not assigned to context $(context)")
	end
	if !(teamType in typeof.(keys(roleManager.teamDB[context])))
		error("Team $teamType is not defined in context $(context)")
	end
	rolesMirrored = []
	team = getTeam(context, teamType, roles...)
	for rolePair in roles
		role = rolePair[1]
		obj = rolePair[2]
		push!(rolesMirrored, role=>obj)
		if !(obj in keys(roleManager.roleDB))
			error("Role $role is not assigned to $(repr(obj)) in context $(context)")
		end
		if !(context in keys(roleManager.roleDB[obj]))
			error("Role $role is not assigned to $(repr(obj)) in context $(context)")
		end
		if !(teamType in typeof.(keys(roleManager.roleDB[obj][context])))
			error("Role $role is not assigned to $(repr(obj)) in context $(context)")
		end
		delete!(roleManager.roleDB[obj][context], team)
		if isempty(roleManager.roleDB[obj][context])
			delete!(roleManager.roleDB[obj], context)
			if isempty(roleManager.roleDB[obj])
			delete!(roleManager.roleDB, obj)
			end
		end
	end
	for (i, roleGroup) in enumerate(roleManager.teamDB[context][team])
		if roleGroup == Dict(rolesMirrored...)
			deleteat!(roleManager.teamDB[context][team], i)
			break
		end
	end	
end

"""
    disassignRoles(context::Union{Context, Nothing}, team::DynamicTeam)

Removes all role assignments from a dynamic team within a context.

Arguments:
- `context`: Context or nothing
- `team`: DynamicTeam

Example:
    disassignRoles(ctx, team)
"""
function disassignRoles(context::Union{Context, Nothing}, team::DynamicTeam)
	if team in keys(roleManager.roleDB)
		error("Team $(team) is currently playing a role. You must disassign it before dissolving the team.")
	end
	roles = roleManager.dynTeamDB[context][team]
	for rolePair in roles
		role = rolePair[1]
		objs = rolePair[2]
		for obj in objs
			for c in getContexts()
				roleObj = getRole(c, obj, team)
				if roleObj in keys(roleManager.roleDB)
					error("Role $(roleObj) plays another role. You must diassign it before dissolving the team.")
				end
			end											
			if !(obj in keys(roleManager.roleDB))
				error("Role $role is not assigned to $(repr(obj)) in context $(context)")
			end
			if !(context in keys(roleManager.roleDB[obj]))
				error("Role $role is not assigned to $(repr(obj)) in context $(context)")
			end
			if !(typeof(team) in typeof.(keys(roleManager.roleDB[obj][context])))
				error("Role $role is not assigned to $(repr(obj)) in context $(context)")
			end
			delete!(roleManager.roleDB[obj][context], team)
			if isempty(roleManager.roleDB[obj][context])
				delete!(roleManager.roleDB[obj], context)
				if isempty(roleManager.roleDB[obj])
					delete!(roleManager.roleDB, obj)
				end
			end
		end
	end
	delete!(roleManager.dynTeamDB[context], team)
	if isempty(roleManager.dynTeamDB[context])
		delete!(roleManager.roleDB, context)
	end
end

"""
    disassignRoles(team::DynamicTeam)

Removes all role assignments from a dynamic team (no context).

Arguments:
- `team`: DynamicTeam

Example:
    disassignRoles(team)
"""
function disassignRoles(team::DynamicTeam)
	disassignRoles(nothing, team)
end

"""
    disassignRoles(context::Union{Context, Nothing}, teamType::Type, id)

Removes all role assignments from a dynamic team by type and id within a context.

Arguments:
- `context`: Context or nothing
- `teamType`: Team type
- `id`: Team id

Example:
    disassignRoles(ctx, TeamType, 1)
"""
function disassignRoles(context::Union{Context, Nothing}, teamType::Type, id)
	disassignRoles(context, getDynamicTeam(context, teamType, id))
end

"""
    disassignRoles(teamType::Type, id)

Removes all role assignments from a dynamic team by type and id (no context).

Arguments:
- `teamType`: Team type
- `id`: Team id

Example:
    disassignRoles(TeamType, 1)
"""
function disassignRoles(teamType::Type, id)
	disassignRoles(nothing, teamType, id)
end

"""
    Base.:(>>)(context::Context, t, mixin::Mixin)

Assigns a mixin to a type in a context using the >> operator.

Arguments:
- `context`: Context
- `t`: Type
- `mixin`: Mixin

Example:
    ctx >> MyType >> MyMixin()
"""
function Base.:(>>)(context::Context, t, mixin::Mixin)
	assignMixin(context, t=>mixin)
end

"""
    Base.:(>>)(t, mixinType::DataType)

Checks if a type has a mixin of the given type using the >> operator.

Arguments:
- `t`: Type
- `mixinType`: Mixin type

Returns true or false.

Example:
    MyType >> MyMixin
"""
function Base.:(>>)(t, mixinType::DataType)
	for t_mixin in [(values(getMixins(t))...)...]
		if typeof(t_mixin) == mixinType
			return true
		end
	end
	false
end