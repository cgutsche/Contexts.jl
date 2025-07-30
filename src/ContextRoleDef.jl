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