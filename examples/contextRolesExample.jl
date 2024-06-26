include("../src/Contexts.jl")
using .Contexts


struct Person 
	name::String
	age::Int
end

john = Person("John", 25)
jane = Person("Jane", 27)
jack = Person("Jack", 2)
jake = Person("Jake", 4)
jordan = Person("Jordan", 53)
jason = Person("Jason", 54)
jim = Person("Jim", 53)
julia = Person("Julia", 55)
jonathan = Person("Jonathan", 79)
joanne = Person("Joanne", 77)

@newContext Family
activateContext(Family)

# Roles must be defined within Teams because they only exist together with other roles.
# The Team itself can have attributes, defined with the @relationalAttributes block 
# Hint: If you do not want to model the counter part, have a look at mixins in contextExample.jl
@context Family @newTeam Mariage begin
	@relationalAttributes begin
		dayOfMariage::String
		placeOfMariage::String
	end
	@role Husband << Person begin
		nameAtBirth::String
	end
	@role Wife << Person begin
		nameAtBirth::String
	end
end

# The << operator return true, if Husband is a role, a Person can play
println("Husband is a Role of the Type Person: ", Husband << Person)
println("Attributes of the role Husband: ", fieldnames(Husband))
println("Attributes of the team Mariage: ", fieldnames(Mariage))


# Teams and roles do not need to have attributes if you are only interested in 
# context-dependent, team-dependent or role-dependet behavior 
@context Family @newTeam ParentsAndChild begin
	@role Father << Person begin
		end
	@role Mother << Person begin
		end
	@role Child << Person begin
		end
end

# Note that two struct objects with the same name and the same attribute values are
# not distinguishable. Therefore, structs with no attributes will only create
# singleton objects: if a = Father() and b = Father(), a == b is true, even a === b

# This would fail, because only one role is defined. Maybe try a mixin, if this
# seems to be the best way to model your system.
#	@context Family @newTeam Fatherhood begin
#		@relationalAttributes begin
#			dayOfChildbirth::String
#		end
#		@role Father << Person begin
#			end
#	end

# You can now assign roles withing their corresponding team
# The team is specified by their team-object with the attributes (e.g. Mariage("01.01.2020", "Dresden"))
# and  the exact role-assignement.
@context Family assignRoles(Mariage("01.01.2020", "Dresden"),
							john=>Husband("test"),
							jane=>Wife("test"))

@context Family assignRoles(Mariage("01.01.2020", "Dresden"),
							jason=>Husband("test"),
							jordan=>Wife("test"))

# calling this again, would fail since team Mariage with identical roles are alredy assigned:
# @context Family assignRoles(Mariage("02.01.2020", "Dresden"),
#							[john=>Husband("test"),
#							jane=>Wife("test")])

# This will not work, since roles must be assigned together within their team:
# @context Family john >> Husband("test")

println("Mariage teams, where Jason is Husband and Jordan is Wife:")
println(getTeam(Family, Mariage, Husband=>jason, Wife=>jordan))

# to dissasign roles, you must define the exact team and which objects play which roles
@context Family disassignRoles(Mariage, Husband=>jason, Wife=>jordan)

println("Mariage teams, where Jason is Husband and Jordan is Wife:")
println(@context Family getTeam(Mariage, Husband=>jason, Wife=>jordan))

@context Family assignRoles(ParentsAndChild(),
							john=>Father(),
							jane=>Mother(),
							jake => Child())

@context Family assignRoles(ParentsAndChild(),
							john=>Father(),
							jane=>Mother(),
							jack=>Child())

@context Family assignRoles(ParentsAndChild(),
							jason=>Father(),
							jordan=>Mother(),
							john=>Child())

@context Family assignRoles(ParentsAndChild(),
							jim=>Father(),
							julia=>Mother(),
							jane=>Child())

println(getTeamPartners(Family, john, Father, ParentsAndChild))

println(getTeam(Family, ParentsAndChild, Father=>john, Mother=>jane, Child=>jack))

println(getRoles(Family, john, Father, ParentsAndChild))

# jack got adopted by another family
@context Family disassignRoles(ParentsAndChild, Father=>john, Mother=>jane, Child=>jack)

println(getTeamPartners(Family, john, Father, ParentsAndChild))
println(getTeam(Family, ParentsAndChild, Father=>john, Mother=>jane, Child=>jack))
println(getTeam(Family, ParentsAndChild, Father=>john, Mother=>jane, Child=>jake))

# The @assignRoles macro can be used for clearer syntax
@context Family @assignRoles Mariage begin
	dayOfMariage = "11.11.2020"
	placeOfMariage = "Dresden"
	jim >> Husband("test")
	julia >> Wife("test")
end

@context Family @assignRoles ParentsAndChild begin
	joanne >> Mother()
	jonathan >> Father()
	jordan>> Child()
end

println(getTeam(Family, Mariage, Husband=>jim, Wife=>julia))

# Here are some examples how to use roles in functions:

@context Family function getFamilyTree(p::Person)
	familyTree = []
	if !(hasRole(context, p, Child, ParentsAndChild))
		return ""
	end
	parents = (@context Family getTeamPartners(p, Child, ParentsAndChild))[1]
	"$(p.name) is the child of $(parents[Mother].name) and $(parents[Father].name). " * getFamilyTree(context, parents[Mother]) * (@context context getFamilyTree(parents[Father]))
end

println(@context Family getFamilyTree(jake))



@context Family function getMariageDate(p1::Person, p2::Person)
	if hasRole(context, p1, Husband, Mariage)
		team = getTeam(context, Mariage, Husband=>p1, Wife=>p2)
		team == nothing ? date = nothing : date = team.dayOfMariage
		return date
	elseif hasRole(context, p1, Wife, Mariage)
		team = getTeam(context, Mariage, Husband=>p2, Wife=>p1)
		team == nothing ? date = nothing : date = team.dayOfMariage
		return date
	else
		return nothing
	end
end

println(@context Family getMariageDate(john, jane))
println(@context Family getMariageDate(julia, jim))
println(@context Family getMariageDate(julia, john))

@context Family function getPartner(person::Person)
	partner = nothing
	if hasRole(context, person, Husband, Mariage) 
		partner = (@context Family getTeamPartners(person, Husband, Mariage))[1][Wife]
	end
	if hasRole(context, person, Wife, Mariage)
		partner = (@context Family getTeamPartners(person, Wife, Mariage))[1][Husband]
	end
	partner
end

println(@context Family getPartner(john))
println(@context Family getPartner(jane))
