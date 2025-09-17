
"""
    @newContext(contextName)

Macro to define a new context type and singleton instance.
Accepts a `String`, `Symbol`, or an expression of multiple names.
Creates a struct subtype of `Context` and registers it.

Example:
	@newContext("MyContext")
	@newContext(AnotherContext)
	@newContext FirstContext, SecondContext
"""
macro newContext(contextName)
	if typeof(contextName) == String || typeof(contextName) == Symbol
		if typeof(contextName) == String
			contextName = Meta.parse(contextName)
		end
		contextTypeNameSymbol = Symbol(contextName, :ContextType)

		structDefExpr = :(struct $(contextTypeNameSymbol) <: Context end;)
		SingletonDefExpr = :($(contextName)::$contextTypeNameSymbol = $contextTypeNameSymbol())

		return esc(:($structDefExpr; $SingletonDefExpr; addContext($contextName)))
	else
		structDefExpr = quote end
		SingletonDefExpr = quote end
		addContextExpr = quote end
		for cname in contextName.args
			if typeof(cname) == String
				cname = Meta.parse(cname)
			end
			contextTypeNameSymbol = Symbol(cname, :ContextType)

			push!(structDefExpr.args, :(struct $(contextTypeNameSymbol) <: Context end;))
			push!(SingletonDefExpr.args, :($(cname) = $contextTypeNameSymbol()))
			push!(addContextExpr.args, :(addContext($(cname))))
		end
		return esc(:($structDefExpr; $SingletonDefExpr; $ addContextExpr))
		#error("Argument of @newContext must be a String or a Symbol")
	end
end

"""
    ContextGroup(subContexts::Context...)

Creates a group of contexts, allowing alternative activation, meaning exactly one 
context of the grouped contexts must be active.
Returns a `ContextGroup` object containing the provided contexts.

	Calling the `ContextGroup` object returns the currently active context in the group.
"""
function ContextGroup(subContexts::Context...)
	alternative(subContexts...)
	ContextGroup([subContexts...])
end
"""
    (contextGroup::ContextGroup)()

Returns the currently active context from the group.
"""
(contextGroup::ContextGroup)() = filter(subContext -> isActive(subContext), contextGroup.subContexts)[1]

"""
    struct ContextStateMachine

Represents a state machine over contexts.
- `variables`: Dict of variable names to value/type pairs.
- `transitions`: Dict mapping contexts to transition expressions.
- `subContexts`: Dict of context names to context instances.
"""
struct ContextStateMachine
	variables::Dict{Symbol, Pair{Any, Type}}
	transitions::Dict{Context, Vector{QuoteNode}}
	subContexts::Dict{Symbol, Context}
end

"""
    checkStateMachineCondition(csm::ContextStateMachine)

Helper function for `ContextStateMachine`. Is called whenever a variable is set.

Checks and enforces the state machine's transition conditions.
Evaluates transitions and detects loops.
Throws an error if a loop is detected.
"""
function checkStateMachineCondition(csm::ContextStateMachine)
	firstContext = csm()
	flag = false
	variables = csm.variables
	for (key, value) in variables
			eval(quote $key = $(value[1]) end)
	end
	for (key, value) in csm.subContexts
			eval(quote $key = $value end)
	end
	while true
		oldContext = csm()
		transitions = csm.transitions[oldContext]
		newContext = nothing
		for transition in transitions
			eval(eval(transition))
			newContext = csm()
			if newContext != oldContext
				break
			end
		end
		if newContext == oldContext
			break
		elseif newContext == firstContext
			if flag
				error("ContextStateMachine with contexts $(csm.subContexts) has a loop. Check the transition conditions.")
			end
			flag = true
		else
			oldContext = newContext
		end
	end
end

"""
    Base.setproperty!(csm::ContextStateMachine, property::Symbol, v)

Sets a variable value of one of the state machine's variables.
If a variable is set, its type is checked and converted if necessary.
Checks state machine conditions after assignment.
"""
function Base.setproperty!(csm::ContextStateMachine, property::Symbol, v)
	if property in keys(csm.variables)
		if !(v isa csm.variables[property][2])
			convert(csm.variables[property][2], v)
		end
		csm.variables[property] = Pair{Any, Type}(v, csm.variables[property][2])
	elseif property in [:transitions, :subContexts]
		csm[property] = v
	else
		error("Property $property not found in ContextStateMachine variables.")
	end
	checkStateMachineCondition(csm)
	true
end

"""
    Base.getproperty(csm::ContextStateMachine, property::Symbol)

Gets a property value from the state machine.
Returns variable values or internal fields.
"""
function Base.getproperty(csm::ContextStateMachine, property::Symbol)
	if property in keys(getfield(csm, :variables))
		return csm.variables[property][1]
	elseif property in [:transitions, :subContexts, :variables]
		return getfield(csm, property)
	else
		error("Property $property not found in ContextStateMachine variables.")
	end
end

"""
    (csm::ContextStateMachine)()

Returns the currently active context from the state machine's subContexts.
"""
(csm::ContextStateMachine)() = filter(subContext -> isActive(subContext), collect(values(csm.subContexts)))[1]

"""
    @ContextStateMachine(name, body)

Macro to define a context state machine.
Accepts a name and a body containing:
- `@variable` declarations
- `@contexts` declarations
- `@initialState` declaration
- `@transition` rules

Generates a `ContextStateMachine` instance with specified configuration.

Conditions of transitions are evaluated whenever a variable is set.
Only Boolean expressions containing variables specified with @variable are allowed as conditions.

Example:
	@ContextStateMachine MyStateMachine begin
		@variable x::Int = 0
		@variable y::Float64 = 1.0
		@contexts StateA, StateB, StateC
		@initialState StateA
		@transition StateA => StateB : x > 10
		@transition StateB => StateC : y < 0.5
		@transition StateC => StateA : x <= 10 && y >= 0.5
	end
"""
macro ContextStateMachine(name, body)
	Base.remove_linenums!(body)
	initalExpr = quote end
	variables::Expr = quote Dict{Symbol, Pair{Any, Type}}() end
	subContexts::Expr = quote Dict{Symbol, Context}() end
	transitions::Expr = quote Dict{Context, Vector{QuoteNode}}() end
	typechecks::Expr = quote end
	transitionHelpDict = Dict{Symbol, Vector{QuoteNode}}()
	for arg in body.args
		if !(arg isa Expr && arg.head == :macrocall)
			error("ContextStateMachine macro requires @variable, @contexts, @initialState, and @transition expressions. Found $arg")
		end
		if arg.args[1] == Symbol("@variable")
			var = QuoteNode(Symbol("$(arg.args[3].args[1].args[1])"))
			val = arg.args[3].args[2]
			type = arg.args[3].args[1].args[2]
			push!(typechecks.args,
			quote if !(($val) isa ($type))
				convert(($type), ($val))
			end end)
			push!(variables.args[2].args, :($var => ($val => $type)))
		elseif arg.args[1] == Symbol("@contexts")
			clist = quote [] end
			for c in arg.args[3].args
				if !(c isa Symbol)
					error("Contexts must be defined with symbols. Found $c")
				end
				s = QuoteNode(Symbol("$c"))
				push!(clist.args[2].args, :($s => $c))
			end
			push!(subContexts.args[2].args, clist)
		elseif arg.args[1] == Symbol("@initialState")
			initalExpr = quote activateContext(($(arg.args[3]))) end
		elseif arg.args[1] == Symbol("@transition")
			if !(arg.args[3].args[1] == Symbol("=>") && arg.args[3].args[2] isa Symbol)
				error("Transition must be in the form 'Context1 => Context2 : condition'")
			end
			fromContext = arg.args[3].args[2]
			toContext = arg.args[3].args[3].args[2]
			condition = arg.args[3].args[3].args[3]
			expr = QuoteNode(quote
				if isActive($fromContext) && $condition
					activateContext($toContext)
				end
			end)
			transitionHelpDict[fromContext] = push!(get(transitionHelpDict, fromContext, Vector{QuoteNode}()), expr)
		else
			error("ContextStateMachine macro requires @variables, @contexts, @initialState, and @transition expressions. Found $arg")
		end
	end
	for (fromContext, exprs) in transitionHelpDict
		push!(transitions.args[2].args, :($fromContext => $exprs))
	end

	returnExpr = quote
		$initalExpr
		ContextGroup(collect(values($subContexts))...)
		$typechecks
		$name = ContextStateMachine($variables, $transitions, $subContexts)
	end
	return esc(returnExpr)
end