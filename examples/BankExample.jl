include("../src/Contexts.jl")
using .Contexts



struct Person
	name::String
end

mutable struct Account
	idlol::Integer
	balance::Float64
end

@newContext Banking
		
@context Banking function increase(acc::Account, amount::Float64)
			acc.balance = acc.balance + amount
end

@context Banking function decrease(acc::Account, amount::Float64)
			acc.balance = acc.balance - amount
end

#### Transaction Definitions

@context Banking @newTeam Transaction begin
	@relationalAttributes begin
		amount::Float64
	end
	@role Source << Account begin
	end
	@role Target << Account begin
	end
end

@context Banking function execute(transaction::Transaction)
	@context Banking withdraw(getRoles(Banking, transaction)[1][Source], transaction.amount)
	@context Banking deposite(getRoles(Banking, transaction)[1][Target], transaction.amount)
end

@context Banking function withdraw(source::Account, amount::Float64)
	@context Banking decrease(source, amount)
end

@context Banking function deposite(target::Account, amount::Float64)
	@context Banking increase(target, amount)
end

##### Bank definitions

mutable struct Bank
	name::String
	moneyTransfers::Vector{Transaction}
end

@context Banking function addMoneyTransfer(bank::Bank, transaction::Transaction)
	push!(bank.moneyTransfers, transaction)
end

@context Banking @newTeam BankAndCustomer begin
	@role Customer << Person begin
		account::Account
	end
	@role AccountProvider << Bank begin
	end
end

@context Banking function executeTransactions(bank::Bank)
	for transaction in bank.moneyTransfers
		@context Banking execute(transaction)
	end
end

##### Example

N_players = 5
N_transactions = 10

players = [Person("Name$i") for i in 1:N_players]
bank = Bank("DresdenBank", [])

for (i, player) in enumerate(players)
	@context Banking @assignRoles BankAndCustomer begin
		player >> Customer(Account(i, 100.00))
		bank >> AccountProvider()
	end
end


randPairs = [0=>0]
for i in 1:N_transactions
	rand1 = 0
	rand2 = 0
	while (rand1=>rand2) in randPairs
		rand1 = rand(1:N_players)
		rand2 = rand(1:N_players)
		while rand1 == rand2
			rand2  = rand(1:N_players)
		end
	end
	push!(randPairs, rand1=>rand2)
	println("$(players[rand1].name) sends 10€ to $(players[rand2].name)")
	account1 = getRoles(Banking, players[rand1], Customer, BankAndCustomer)[1].account
	account2 = getRoles(Banking, players[rand2], Customer, BankAndCustomer)[1].account
	
	@context Banking @assignRoles Transaction begin
		amount = 10
		account1 >> Source()
		account2 >> Target()
	end

	thisTransaction = getTeam(Banking, Transaction, Source=>account1, Target=>account2)
	@context Banking addMoneyTransfer(bank, thisTransaction)
end



@context Banking executeTransactions(bank)

for player in players
	println("Account of player $(player.name): ", getRoles(Banking, player, Customer, BankAndCustomer)[1].account)
end