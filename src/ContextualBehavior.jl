"""
    @team(teamType, id, functionCall)

Macro to inject team role access into a function call for a dynamic team.
Replaces @role macro calls in the function call with getRole lookups for the given team and id.

Arguments:
- `teamType`: The type of the dynamic team
- `id`: The team id
- `functionCall`: The function call expression containing @role macros

Example:
    @team MyTeam 1 myfunc(@role obj1, obj2, @role obj3)
"""
macro team(teamType, id, functionCall)
	if typeof(functionCall) != Expr
		error("Must be called on a function call")
	else
		Base.remove_linenums!(functionCall)
		for (i, arg) in enumerate(functionCall.args)
			if typeof(arg) == Expr
				Base.remove_linenums!(arg)
				if arg.head == :macrocall
					if arg.args[1] == Symbol("@role")
						newArg = quote
							getRole($(arg.args[3]), getDynamicTeam($teamType, $id))
						end
						functionCall.args[i] = newArg
					end
				end
			end
		end
	end
	esc(functionCall)
end

"""
    @context(cname, expr)

Macro to inject context information into a function or macro call or function definition.
Adds context type or name as an argument to the function or macro.

A generic context type can be specified with `Any`.

Arguments:
- `cname`: Context name or type
- `expr`: Function, macro call, or function definition

Example:
    @context MyContext function myfunc(x::myType)
		...
	end
	@context Any function myfunc(x::myType)
		...
	end
    @context MyContext myfunc(x)
"""
macro context(cname, expr)
	if typeof(expr) != Expr
		error("Second argument of @context must be a function or macro call or function definition")
	else
		Base.remove_linenums!(expr)
		if expr.head == :function
            if cname isa Symbol
                ctype = Symbol(cname, :ContextType)
            elseif cname == :Any
                ctype = :Any
            else
                typelist = quote [] end
                Base.remove_linenums!(cname)
                for typearg in cname.args
                    sub_ctype = Symbol(typearg, :ContextType)
                    push!(typelist.args[2].args, sub_ctype)
                end
                ctype = quote Tuple{$typelist...} end 
            end
			arg = :(context::$ctype)
			insert!(expr.args[1].args, 2, arg)
			return esc(expr)
		elseif expr.head == :call
			insert!(expr.args, 2, cname)
			return esc(expr)
		elseif expr.head == :.
			if !(expr.args[1].head == :call)
				error("Second argument of @context must be a function or macro call or function definition")
			end
			insert!((expr.args[1]).args, 2, cname)
			return esc(expr)
		elseif expr.head == :macrocall
			insert!(expr.args, 3, cname)
			return esc(expr)
		else
			error("Second argument of @context must be a function or macro call or function definition")
		end
	end
end

"""
    @activeContext(cname, expr)

Macro to conditionally execute a function or macro call only if the context is active.
Wraps the call in an if isActive(context) block.

Arguments:
- `cname`: Context name or type
- `expr`: Function or macro call

Example:
    @activeContext(MyContext, myfunc(x))
"""
macro activeContext(cname, expr)
	if typeof(expr) != Expr
		error("Second argument of @context must be a function or macro call or function definition")
	else
		Base.remove_linenums!(expr)
		if expr.head == :call
			insert!(expr.args, 2, cname)
			ifExpr = quote if isActive($cname)
					$expr
				end
			end

			return esc(ifExpr)
		elseif expr.head == :.
			if !(expr.args[1].head == :call)
				error("Second argument of @context must be a function or macro call")
			end
			insert!((expr.args[1]).args, 2, cname)
			return esc(if isActive(cname) expr end)
		elseif expr.head == :macrocall
			insert!(expr.args, 3, cname)
			return esc(if isActive(cname) expr end)
		else
			error("Second argument of @context must be a function or macro call")
		end
	end
end