include("../src/Contexts.jl")
using .Contexts

mutable struct Person 
	name::String
	age::Int
	income::Float32
end

@newContext(Family)

@context Family @newTeam Mariage begin
	@relationalAttributes begin
		dayOfMariage::String
		placeOfMariage::String
		commonIncome::Float32
	end
	@role Husband << Person begin
		end
	@role Wife << Person begin
		end
end

john = Person("John", 34, 2500)
jane = Person("Jane", 42, 3000)
jake = Person("Jake", 24, 5000)

@context Family function marry(p1::Person, p2::Person)
	assignRoles(context, Mariage("01.01.2020", "Dresden", p1.income+p2.income),
						p1=>Husband(),
						p2=>Wife())
end

@context Family function setIncome(person::Person, newIncome::Number)
	if hasRole(context, person, Husband, Mariage) | hasRole(context, person, Wife, Mariage)
		person.income = newIncome
		type = hasRole(context, person, Husband, Mariage) ? Husband : Wife
		partnerType = type == Husband ? Wife : Husband
		partner = (getTeamPartners(context, person, type, Mariage))[1][partnerType]
		mariage = type == Husband ? getTeam(Family, Mariage, Husband=>person, Wife=>partner) : getTeam(Family, Mariage, Husband=>partner, Wife=>person)
		mariage.commonIncome = person.income + partner.income
	else
		person.income = newIncome
	end
end

println("Income of John before Mariage: ", john.income)
println("Income of Jane before Mariage: ", jane.income)
println("Income of Jake before Mariage: ", jake.income)
println()

@context Family marry(john, jane)

println("Income of John after Mariage: ", john.income)
println("Income of Jane after Mariage: ", jane.income)
println("common income after Mariage: ", (getTeam(Family, Mariage, Husband=>john, Wife=>jane)).commonIncome)
println("Income of Jake after Mariage: ", jake.income)
println()

@context Family setIncome(john, 3000)
@context Family setIncome(jake, 5500)

println("Income of John after pay rise: ", john.income)
println("Income of Jane after pay rise: ", jane.income)
println("common income after Mariage: ", (getTeam(Family, Mariage, Husband=>john, Wife=>jane)).commonIncome)
println("Income of Jake after pay rise: ", jake.income)
println()

@context Family setIncome(jane, 4000)

println("Income of John after second pay rise: ", john.income)
println("Income of Jane after second pay rise: ", jane.income)
println("common income after second pay rise: ", (getTeam(Family, Mariage, Husband=>john, Wife=>jane)).commonIncome)
println("Income of Jake after second pay rise: ", jake.income)