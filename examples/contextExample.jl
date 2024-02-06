include("../src/Contexts.jl")
using .Contexts

struct Person 
	name::String
	age::Int
end

@newContext "Business"
@newContext("Volunteering")
@newContext(Family)
@newContext University

println("Contexts: ", getContexts())
println("First element is Business: ", getContexts()[1] == Business)

@context University @newMixin Professor <: Person begin
	UniversityName::String
	Chair::String
end

@context Family @newMixin Husband <: Person begin
	partner::Person
	dayOfMariage::String
end

@context Family @newMixin Wife <: Person begin
	partner::Person
	dayOfMariage::String
end

@context Business @newMixin Employee <: Person begin
	CompanyName::String
	partner::Person
end

@context Business @newMixin Employer <: Person begin
	CompanyName::String
end

@context Family @newMixin Teenager <: Person begin
end


println(" ")
println("Husband attributes:", fieldnames(Husband))
println("Wife attributes:", fieldnames(Wife))
println("Employee attributes:", fieldnames(Employee))

println(" ")
println(getMixins())
println(" ")

John = Person("John", 34)
Jane = Person("Jane", 42)
Jake = Person("Jake", 24)

assignMixin(John=>Employee("Test Inc.", Jake), Business)

function marry(p1::Person, p2::Person, dayOfMariage::String)
	assignMixin(p1=>Husband(p2, dayOfMariage), Family)
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
	(@context context getMixin(person)).partner
end

@context Business function getPartner(person::Person)
	getMixin(person, context).partner
end

println("John's Family Partner: ", @context Family getPartner(John))
println("John's Business Partner: ", @context Business getPartner(John))
println("Janes's Family Partner: ", getPartner(Jane, Family))

function divorce(p1::Person, p2::Person)
	disassignMixin(p1=>Husband, Family)
	disassignMixin(p2=>Wife, Family)
end

divorce(John, Jane)

println(" ")
println("Mixins of John: ", getMixins(John))
println(" ")

assignMixin(John=>Employer("Test Inc."), Business)
marry(Jane, Jake, "01.01.2023")
