include("../src/Contexts.jl")
using .Contexts

struct Person 
	name::String
	age::Int
end

struct Animal 
	name::String
	age::Int
end

# Defining new contexts with the @newContext macro
@newContext "Business"
@newContext("Volunteering")
@newContext(Family)
@newContext University

println("Contexts: ", getContexts())
println("First element is Business: ", getContexts()[1] == Business)

# Defining new mixins with the @newMixin macro
# Note that every mixin has to be defined in a context
@context University @newMixin Professor << Person begin
	UniversityName::String
	Chair::String
end

@context Family @newMixin Husband << Person begin
	partner::Person
	dayOfMariage::String
end

@context Family @newMixin Wife << Person begin
	partner::Person
	dayOfMariage::String
end

@context Business @newMixin Employee << Person begin
	CompanyName::String
	partner::Person
end

@context Business @newMixin Employer << Person begin
	CompanyName::String
end

@context Family @newMixin Teenager << Person begin
end

@context Family @newMixin Adult << Person begin
end

@context Family @newMixin Pet << Animal begin
end

println(" ")
println("Husband attributes:", fieldnames(Husband))
println("Wife attributes:", fieldnames(Wife))
println("Employee attributes:", fieldnames(Employee))
println(" ")
println("Empolyer is a subtype of Mixin: ", Employer <: Mixin)
println("Empolyer is a subtype of Person: ", Employer <: Person)
println("Empolyer is a mixin of Person: ", Employer << Person)
println("Empolyer is a mixin of Animal: ", Employer << Animal)
println("Pet is a mixin of Animal: ", Pet << Animal)

println(" ")
println(getMixins())
println(" ")

John = Person("John", 34)
Jane = Person("Jane", 42)
Jake = Person("Jake", 24)

# now, mixins can be assigned to objects
assignMixin(Business, John => Employee("Test Inc.", Jake))
# you can also use the >> operator in combination with the @context
@context Family John >> Adult()

# This would fail, because Pet can only be assigned to Object of type Animal: 
# @context Family John >> Pet()

println("Professor is Subtype of Mixin: ", Professor <: Mixin)
println("Professor is Mixin of Person: ", Professor << Person)
println("John has assigned Mixin Employee: ", John >> Employee)

# Note that this example might be modeled with roles as seen in the
# contextRolesExample.jl file
function marry(p1::Person, p2::Person, dayOfMariage::String)
	assignMixin(Family, p1=>Husband(p2, dayOfMariage))
	@context Family assignMixin(p2=>Wife(p1, dayOfMariage))
end

marry(John, Jane, "10.10.2020")

println(" ")
println("Mixins of John: ", getMixins(John))
println(" ")

@context University assignMixin(Jane => Professor("TU Dresden", "Chair of Context Oriented Programming"))

println(getMixins())

println(" ")
println("Mixins of Jane: ", getMixins(Jane))
println(" ")

@context Family function getPartner(person::Person)
	for mixin in getMixins(context, person)
		if (typeof(mixin) == Husband) | (typeof(mixin) == Wife )
			return mixin.partner
		end
	end
	nothing
end

@context Business function getPartner(person::Person)
	@context context getMixin(person, Employee).partner
end

println("John's Family Partner: ", @context Family getPartner(John))
println("John's Business Partner: ", @context Business getPartner(John))
println("Jane's Family Partner: ", getPartner(Family, Jane))

println("John's Business Partner: ", isActive(Business) ? (@context Business getPartner(John)) : nothing)
deactivateContext(Business)
println("John's Business Partner: ", @context Business getPartner(John))
println("John's Business Partner: ", isActive(Business) ? (@context Business getPartner(John)) : nothing)

function divorce(p1::Person, p2::Person)
	@context Family disassignMixin(p1=>Husband)
	@context Family disassignMixin(p2=>Wife)
end

divorce(John, Jane)

println(" ")
println("Mixins of John: ", getMixins(John))
println(" ")

assignMixin(Business, John=>Employer("Test2 Inc."))
marry(Jane, Jake, "01.01.2023")

(getMixins(Business, John)[2]).CompanyName = "NewCompany"
println(getMixins(Business, John)[2])

getIncome(context::Married.., person::Person)
	
end

setIncome(person::Person)
	if hasRole(Husband) | hasRole(Wife) 

	else
end