
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