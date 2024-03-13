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
	assignRoles(context, Mariage("01.01.2020", "Dresden"),
						p1=>Husband(),
						p2=>Wife())
	commonIncome = p1.income + p2.income
	p1.income = commonIncome
	p2.income = commonIncome
end

@context Family function setIncome(person::Person, newIncome::Number)
	if hasRole(context, person, Husband, Mariage) | hasRole(context, person, Wife, Mariage)
		person.income = newIncome
		type = hasRole(context, person, Husband, Mariage) ? Husband : Wife
		partnerType = type == Husband ? Wife : Husband
		partner = (getTeamPartners(context, person, type, Mariage))[1][partnerType]
		partner.income = newIncome
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
println("Income of Jake after Mariage: ", jake.income)
println()

@context Family setIncome(john, 6000)
@context Family setIncome(jake, 5500)

println("Income of John after pay rise: ", john.income)
println("Income of Jane after pay rise: ", jane.income)
println("Income of Jake after pay rise: ", jake.income)
println()

@context Family setIncome(jane, 6200)

println("Income of John after second pay rise: ", john.income)
println("Income of Jane after second pay rise: ", jane.income)
println("Income of Jake after second pay rise: ", jake.income)