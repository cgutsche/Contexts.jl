contextualFunctions = Dict()
"""
    clean(expr)

Clean up generated Julia AST:
- remove redundant begin/end blocks,
- flatten nested blocks,
- convert symbol-only blocks to tuples,
- *preserve* all macro calls.
"""
function clean(ex)
    # Preserve all macro calls as-is
    if ex isa Expr && ex.head == :macrocall
        return Expr(:macrocall, (clean.(ex.args))...)
    end
    # Simplify blocks
    if ex isa Expr && ex.head == :block
        # Clean child expressions
        items = map(clean, ex.args)

        # Filter out `nothing` (if any are produced)
        items = filter(!isnothing, items)

        # If the block contains only symbols → tuple
        if all(item -> item isa Symbol, items)
            return Expr(:tuple, items...)
        end
        # If block has a single expression → unwrap it
        if length(items) == 1
            return items[1]
        end

        # Otherwise return a block
        return Expr(:block, items...)
    end

    # Recurse inside expressions
    if ex isa Expr
        return Expr(ex.head, (clean.(ex.args))...)
    end

    # Everything else unchanged (symbols, numbers, strings)
    return ex
end

function prettyPrint(outputPath::String, retExpr::Expr)
    retExpr = clean(retExpr)
    open(outputPath, "w") do io
        print(io, retExpr)
    end
    lines = readlines(outputPath)
    newLines = String[]
    stack = []
    lastLine = ""
    for (idx, line) in enumerate(lines)
        if startswith(strip(line), "begin")
            n = findfirst(!isspace, line)
            n_leading_spaces = isnothing(n) ? 0 : n - 1
            push!(stack, n_leading_spaces)
        elseif startswith(strip(line), "end")
            n = findfirst(!isspace, line)
            n_leading_spaces = isnothing(n) ? 0 : n - 1
            if (length(stack) != 0) && !(n_leading_spaces == stack[end])
                push!(newLines, line)
            else
                pop!(stack)
            end
        elseif startswith(strip(line), "#= ") && endswith(strip(line), " =#")
            lastLine = line
        elseif startswith(strip(line), "#= ")
            newLine = string(split(line, " =#")[2])
            push!(newLines, newLine)
        else
            if lastLine != ""
                push!(newLines, lastLine)
                lastLine = ""
            end
            push!(newLines, line)
        end
    end
    write(outputPath, join(newLines, "\n"))
    format_file(outputPath, SciMLStyle())
end

function extractArgs(expr::Vector{T}) where T<:Union{Symbol, Expr} 
	function contextList(e::Symbol)
		return [e]  # Return a single-element array containing the symbol
	end
	
	function contextList(e::Expr)
		list = contextList.(filter(x -> (x != :(!)) & (x != :(&)) & (x != :(|)), e.args))
		if list == []
			return [e]  # If no arguments, return the expression itself
		end
		list = reduce(vcat, list)
		return list
	end
	# Extracts all arguments from a vector of expressions
	args = Set{Symbol}()
	for e in expr
		symbols = contextList(e)
		push!(args, symbols...)
	end
	return collect(args)
end

function get_atomic_models(exprs::Vector{Union{Symbol, Expr}})
	function alternative(exprs::BoolExpr...)
		alts = []
		for expr in exprs
			push!(alts, and(expr, and([not.(filter(x -> repr(x) != repr(expr), exprs))...])))
		end
		or(alts)
	end
	function exclusion(exprs::BoolExpr...)
		exprs = collect(exprs)
		excls = []
		for i in 1:(length(exprs)-1)
			for j in (i+1):length(exprs)
				push!(excls, or(not(exprs[i]), not(exprs[j])))
			end
		end
		if length(excls) == 1
			return excls[1]
		end
		and(excls)
	end
	function free(exprs::BoolExpr...)
		or([not(exprs[1]), exprs...])
	end
	function requirement(expr1::BoolExpr, expr2::BoolExpr)
		or(not(expr1), expr2)
	end
	function strongInclusion(expr1::BoolExpr, expr2::BoolExpr)
		or(not(expr1), expr2)
	end
	function getContextsFromConstraint(constraint::Contexts.Constraint)
		contextsInConstraints = Meta.parse.([String.(s...) for s in split.(repr.(constraint.contexts), "ContextType()"; keepempty=false)])
	end
	function addConstraint(constraint::Contexts.Exclusion, contextList::Vector{Symbol})
		exclusion([contexts[var_map[context]] for context in contextList]...)
	end
	function addConstraint(constraint::Contexts.Alternative, contextList::Vector{Symbol})
		alternative([contexts[var_map[context]] for context in contextList]...)
	end
	function addConstraint(constraint::Contexts.Requirement, contextList::Vector{Symbol})
		requirement(contexts[var_map[contextList[1]]], contexts[var_map[contextList[2]]])
	end
	function addConstraint(constraint::Contexts.Inclusion, contextList::Vector{Symbol})
		strongInclusion(contexts[var_map[contextList[1]]], contexts[var_map[contextList[2]]])
		
	end
	function convertExpr(expr::Union{Symbol, Expr})
		if expr isa Symbol
			return contexts[var_map[expr]]
		elseif expr isa Expr
			if expr.head == :(call)
				if expr.args[1] == :(!)
					return not(convertExpr(expr.args[2]))
				elseif expr.args[1] == :(&)
					return and(convertExpr.(expr.args[2:end])...)
				elseif expr.args[1] == :(|)
					return or(convertExpr.(expr.args[2:end])...)
				else
					error("Unsupported expression type: $(typeof(expr))")
				end
			else
				error("Unsupported expression type: $(typeof(expr))")
			end
		end
	end

	variables = extractArgs(exprs)

	# translate Contexts.jl-constraints to boolean expressions

	constraintList = Contexts.getConstraints()
	contextsInConstraints = nothing
	for constraint in constraintList
		contextsInConstraints = getContextsFromConstraint(constraint)
		if any(x -> x in variables, contextsInConstraints)
			if !issubset(contextsInConstraints, variables)
				push!(variables, filter(x -> !(x in variables), contextsInConstraints)...)
			end
		end
	end

	n = size(variables, 1)
	var_map = Dict{Symbol, Int}(variables[i] => i for i in 1:n)
	@satvariable(contexts[1:n], Bool)

	constraints = []
	containedContexts = Set{Symbol}()
	for constraint in constraintList
		contextsInConstraints = getContextsFromConstraint(constraint)
		if any(x -> x in variables, contextsInConstraints)
			newConstraint = addConstraint(constraint, contextsInConstraints)
			push!(constraints, newConstraint)
			push!(containedContexts, contextsInConstraints...)
		end
	end
	
	# Add all contexts that are not in the constraints
	missingContexts = filter(x -> !(x in containedContexts), variables)
	if length(missingContexts) != 0
		push!(constraints, free([contexts[var_map[c]] for c in missingContexts]...))
	end
	

	# Convert expressions to boolean variables
	conditions = Dict([expr => convertExpr(expr) for expr in exprs])
	solutions::Dict{Dict{Union{Expr, Symbol}, Bool}, Vector{Union{Symbol, Expr}}} = Dict()
	for (expr, cond) in conditions
		local_constraints = copy(constraints)
		# Add the condition to the constraints
		push!(local_constraints, cond)
		open(Z3()) do interactive_solver 
			assert!(interactive_solver, local_constraints...)
			i = 1
			status, assignment = sat!(interactive_solver)
			while status == :SAT
				# Try to solve the problem
				assign!(contexts, assignment)
				if haskey(solutions, Dict([k => value(contexts[v]) for (k, v) in var_map]))
					push!(solutions[Dict([k => value(contexts[v]) for (k, v) in var_map])], expr)
				else
					solutions[Dict([k => value(contexts[v]) for (k, v) in var_map])] = Union{Symbol, Expr}[expr]
				end
				# Use assert! to exclude the solution we just found. 
				assert!(interactive_solver, not(and(contexts .== value(contexts))))
				status, assignment = sat!(interactive_solver)
				i += 1
			end
		end
	end
	model_conditions = Dict()
	for (c, d) in solutions
		if haskey(model_conditions, d)
			push!(model_conditions[d], c)
		else
			model_conditions[d] = [c]
		end
	end
	return model_conditions
end



macro contextual(expr)
    retExpr = __contextual(expr)
    #Base.remove_linenums!(retExpr)
    esc(retExpr)
end

function __contextual(expr)
    function getContextsFromConstraint(constraint::Contexts.Constraint)
        Meta.parse.([String.(s...) for s in split.(repr.(constraint.contexts), "ContextType()"; keepempty=false)])
    end

    # placeholder: will be filled after scanning Contexts.getConstraints()
    contextsInConstraints = Vector{Vector{Symbol}}()
    # global helper visible to nested functions: returns true if set `s` violates any constraint
    violates_constraint(s::Set{Union{Expr, Symbol}}) = any(length(intersect(s, Set(con))) > 1 for con in contextsInConstraints)

    # combine two ordered context-vectors preserving discovery order (no sorting)
    function merge_keys(existing::Vector{T}, added::Vector{U}) where {T, U <: Union{Expr, Symbol}}
        if isempty(existing)
            return collect(added)
        end
        res::Vector{Union{Expr, Symbol}} = collect(existing)
        for a in added
            if !(a in res)
                push!(res, a)
            end
        end
        return res
    end

    function slotFinder(contexts::Union{Vector{Symbol}, Vector{Expr}}, expr::Expr)
        push!(toBeDeleted, contexts)
        resDict = OrderedDict{Vector{Union{Symbol, Expr}}, Expr}()
        slotDict = Dict()
        foundSlot = false
        prevs = Set()
        for (i, arg) in enumerate(expr.args)
            if arg isa Expr
                if arg.args[1] == Symbol("@slot")
                    foundSlot = true
                    slotDict[arg.args[3]] = Vector()
                     for (context, code) in slotDefMap[arg.args[3]]   
                        codeVariants = slotFinder([context], code)
                        push!(slotDict[arg.args[3]], collect(keys(codeVariants))...)
                        for (newKey, newcode) in codeVariants
                            if size(collect(keys(slotDict)))[1] == 1
                                push!(toBeDeleted, newKey)
                                oldKey = merge_keys(contexts, collect(newKey))
                                resDict[oldKey] = copy(expr)
                                resDict[oldKey].args[i] = newcode
                            else 
                                 for (s, keys) in slotDict
                                     if (s == arg.args[3])
                                         continue
                                     else
                                         for k in keys
                                            push!(toBeDeleted, newKey)
                                            prev = merge_keys(contexts, collect(k))
                                            push!(prevs, prev)
                                            oldKey = merge_keys(contexts, vcat(collect(k), collect(newKey)))
                                            resDict[oldKey] = copy(resDict[prev])
                                            resDict[oldKey].args[i] = newcode
                                         end
                                     end
                                 end
                             end
                         end       
                     end
                end
            end
        end
        if foundSlot == false
            resDict[contexts] = expr
        end
        for prev in prevs
            delete!(resDict, prev)
        end
        return resDict
    end

    function slotFinderRecursive(expr::Expr)
        # Precompute constraint sets once per call (shared with outer helpers)
        cons_sets = [Set(c) for c in contextsInConstraints]

        resDict = OrderedDict{Vector{Union{Symbol, Expr}}, Expr}()

        for (i, arg) in enumerate(expr.args)
            if !(arg isa Expr)
                continue
            end

            if arg.args[1] == Symbol("@slot")
                # gather ordered variants for this @slot
                all_variants = OrderedDict{Vector{Union{Symbol, Expr}}, Expr}()
                for (context, code) in slotDefMap[arg.args[3]]
                    codeVariants = slotFinder([context], code)
                    for (k, v) in codeVariants
                        keyvec = collect(k)
                        # skip single-variant if it violates constraints alone
                        if any(length(intersect(Set(keyvec), con)) > 1 for con in cons_sets)
                            continue
                        end
                        all_variants[keyvec] = v
                    end
                end

                if isempty(all_variants)
                    continue
                end

                if isempty(resDict)
                    # initialize from variants preserving insertion order
                    for (key, newcode) in all_variants
                        cp = deepcopy(expr)
                        cp.args[i] = deepcopy(newcode)
                        resDict[key] = cp
                    end
                else
                    newMap = OrderedDict{Vector{Union{Symbol, Expr}}, Expr}()
                    for (existingKey, existingExpr) in resDict
                        for (key, newcode) in all_variants
                            merged_key = merge_keys(existingKey, key)
                            if any(length(intersect(Set(merged_key), con)) > 1 for con in cons_sets)
                                continue
                            end
                            newExpr = deepcopy(existingExpr)
                            newExpr.args[i] = deepcopy(newcode)
                            newMap[merged_key] = newExpr
                        end
                    end
                    empty!(resDict)
                    for (k,v) in newMap
                        resDict[k] = v
                    end
                end

            else
                # recurse into sub-expression
                newCodeMap = slotFinderRecursive(arg)
                if isempty(newCodeMap)
                    continue
                end

                if isempty(resDict)
                    for (contexts, newcode) in newCodeMap
                        cp = deepcopy(expr)
                        cp.args[i] = deepcopy(newcode)
                        resDict[contexts] = cp
                    end
                else
                    newMap = OrderedDict{Vector{Union{Symbol, Expr}}, Expr}()
                    for (existingKey, existingExpr) in resDict
                        for (contexts, newcode) in newCodeMap
                            merged_key = merge_keys(existingKey, contexts)
                            if any(length(intersect(Set(merged_key), con)) > 1 for con in cons_sets)
                                continue
                            end
                            newExpr = deepcopy(existingExpr)
                            newExpr.args[i] = deepcopy(newcode)
                            newMap[merged_key] = newExpr
                        end
                    end
                    empty!(resDict)
                    for (k,v) in newMap
                        resDict[k] = v
                    end
                end
            end
        end
        return resDict
    end

    function slotFinder(expr::Expr)
        # Precompute constraint sets once per call
        cons_sets = [Set(c) for c in contextsInConstraints]

        # Fast prune of existing entries that violate constraints:
        if !isempty(contextCodeMap)
            # collect keys once (avoid iterating dict while deleting)
            existing_keys = collect(keys(contextCodeMap))
            # cache key -> Set
            existing_key_sets = Dict{Vector{Union{Symbol, Expr}}, Set{Symbol}}()
            to_remove = Vector{Vector{Union{Symbol, Expr}}}()
            for k in existing_keys
                ks = Set(k)
                existing_key_sets[k] = ks
                for conset in cons_sets
                    # skip if intersection size > 1
                    if length(intersect(ks, conset)) > 1
                        push!(to_remove, k)
                        break
                    end
                end
            end
            for k in to_remove
                delete!(contextCodeMap, k)
                delete!(existing_key_sets, k)
            end
        end

        # Walk expression and expand @slot occurrences
        for (i, arg) in enumerate(expr.args)
            if !(arg isa Expr)
                continue
            end
            if arg.args[1] == Symbol("@slot")
                # gather all variants for this @slot: Dict{Vector{Symbol}, Expr}
                all_variants = OrderedDict{Vector{Union{Symbol, Expr}}, Expr}()
                for (context, code) in slotDefMap[arg.args[3]]
                    codeVariants = slotFinder([context], code)   # returns Dict{Vector{Symbol}, Expr}
                    for (k, v) in codeVariants
                        keyvec = collect(k)
                        all_variants[keyvec] = v
                    end
                end

                # If no prior variants, initialize contextCodeMap from all_variants
                if isempty(contextCodeMap)
                    for (key, newcode) in all_variants
                        # skip if key alone violates any constraint
                        violates = false
                        kset = Set(key)
                        for conset in cons_sets
                            if length(intersect(kset, conset)) > 1
                                violates = true
                                break
                            end
                        end
                        if violates
                            continue
                        end
                        cp = copy(expr)
                        cp.args[i] = copy(newcode)
                        contextCodeMap[collect(key)] = cp
                    end
                else
                    # combine existing entries with new variants -> build new map
                    # cache existing key sets
                    existing_keys = collect(keys(contextCodeMap))
                    existing_key_sets = Dict{Vector{Union{Symbol, Expr}}, Set{Union{Symbol, Expr}}}()
                    for ek in existing_keys
                        existing_key_sets[ek] = Set(ek)
                    end
                    newMap = OrderedDict{Vector{Union{Symbol, Expr}}, Expr}()
                    for existingKey in existing_keys
                        existingExpr = contextCodeMap[existingKey]
                        for (key, newcode) in all_variants
                            # early skip if new variant alone violates constraint
                            if any(length(intersect(Set(key), con)) > 1 for con in cons_sets)
                                continue
                            end
                            merged_key = merge_keys(existingKey, collect(key))
                            if violates_constraint(Set(merged_key))
                                continue
                            end
                            newExpr = copy(existingExpr)
                            newExpr.args[i] = copy(newcode)
                            newMap[merged_key] = newExpr
                        end
                    end

                    # replace contextCodeMap in one assignment
                    empty!(contextCodeMap)
                    for (k, v) in newMap
                        contextCodeMap[k] = v
                    end
                end
            else
                if arg isa Symbol
                    continue
                end
                # recurse into sub-expression
                newCodeMap = slotFinderRecursive(arg)
                if isempty(newCodeMap)
                    continue
                end
                # merge existing contextCodeMap entries with newCodeMap preserving discovery order
                existing_pairs = collect(contextCodeMap)  # Vector{Pair{Vector{Symbol},Expr}}
                for (newContexts, newcode) in newCodeMap
                    for (existingKey, existingExpr) in existing_pairs
                        merged_key = merge_keys(existingKey, newContexts)
                        if any(length(intersect(Set(merged_key), con)) > 1 for con in cons_sets)
                            continue
                        end
                        newExpr = copy(existingExpr)
                        newExpr.args[i] = copy(newcode)
                        contextCodeMap[merged_key] = newExpr
                    end
                end
            end
        end
    end

    function slotFinder(expr::Symbol)
        return expr
    end

    retExpr = quote end
    Base.remove_linenums!(retExpr)
    header = expr.args[1]
    fname = header.args[1]
    fargs = length(header.args) > 1 ? (header.args[2:end]) : []
    body = expr.args[2]
    
    toBeDeleted = Set()

    skeleton = nothing
    contextCodeMap = OrderedDict{Vector{Union{Symbol, Expr}}, Expr}()
    # keep insertion order of contexts for each slot -> OrderedDict values
    slotDefMap = Dict{Symbol, OrderedDict{Union{Expr, Symbol}, Expr}}()
    outputPath = nothing
    contextList = Vector{Symbol}()

    function processSlotDef(slotExpr::Expr)
        slot = slotExpr.args[3]
        bodyExpr = slotExpr.args[4]
        od = get!(slotDefMap, slot, OrderedDict{Union{Expr, Symbol}, Expr}())

        # recursive scan for nested @slotDef inside arbitrary code
        function scanNestedSlotDefs(e)
            if !(e isa Expr)
                return
            end
            for sub in e.args
                if sub isa Expr
                    if sub.args[1] == Symbol("@slotDef")
                        processSlotDef(sub)
                    else
                        scanNestedSlotDefs(sub)
                    end
                end
            end
        end

        for inner in bodyExpr.args
            if inner isa Expr
                if inner.args[1] == Symbol("@context")
                    ctx = inner.args[3]
                    code = inner.args[4]
                    od[ctx] = code
                    # collect atomic symbols from the context expression
                    newContexts = extractArgs([ctx])
                    for c in newContexts
                        if !(c in contextList)
                            push!(contextList, c)
                        end
                    end
                    # scan code for nested @slotDef definitions
                    scanNestedSlotDefs(code)
                elseif inner.args[1] == Symbol("@slotDef")
                    # nested slotDef sibling
                    processSlotDef(inner)
                end
            end
        end
    end

    for arg in body.args 
        if !(arg isa Expr)
            continue
        end
        if arg.args[1] == Symbol("@skeleton")
            if isnothing(skeleton)
                skeleton = arg.args[3]
            else
                error("More than one skeleton is defined.")
            end
        elseif arg.args[1] == Symbol("@slotDef")
            processSlotDef(arg)
        elseif arg.args[1] == Symbol("@output")
            if isnothing(outputPath)
                outputPath = repr(arg.args[3])[2:end-1]
                println("saving code in: ", outputPath)
            else
                error("More than one skeleton is defined.")
            end
        else
            error("Block must start with @skeleton, @slotDef, or @output.")
        end
    end 

    constraintList = Contexts.getConstraints()
    contextsInConstraints::Vector{Vector{Symbol}} = Vector{Vector{Symbol}}()

    for constraint in constraintList
        cons = getContextsFromConstraint(constraint)
		push!(contextsInConstraints, cons)
	end
    
    slotFinder(skeleton)

    # prune subset keys: keep only keys that are not a subset of any other key
    keys_list = collect(keys(contextCodeMap))
    # precompute sets for fast issubset checks
    key_sets = Dict{Vector{Union{Expr, Symbol}}, Set{Union{Expr, Symbol}}}()
    for k in keys_list
        key_sets[k] = Set(k)
    end

    # process larger (superset) keys first so smaller subset keys can be dropped quickly
    sorted_keys = sort(keys_list, by = x -> -length(x))

    kept = Vector{Vector{Union{Expr, Symbol}}}()
    for k in sorted_keys
        ks = key_sets[k]
        # if ks is subset of any already kept key, skip it
        is_subset_of_kept = false
        for j in kept
            if issubset(ks, key_sets[j])
                is_subset_of_kept = true
                break
            end
        end
        if !is_subset_of_kept
            push!(kept, k)
        end
    end

    # rebuild contextCodeMap to contain only kept entries
    newMap = Dict{Vector{Union{Expr, Symbol}}, Expr}()
    for k in kept
        newMap[k] = contextCodeMap[k]
    end
    for (k, v) in newMap
        contextCodeMap[k] = v
    end
    
    foundContexts = [(collect(keys(contextCodeMap))...)...]
    exprs::Vector{Union{Symbol, Expr}} = foundContexts
    atomic_models = get_atomic_models(exprs)
    foundContextsSet = Set(keys(collect(values(atomic_models))[1][1]))
    foundContextsSetModified = Set{Symbol}()
    
    groups = Dict{Symbol, ContextGroup}()
    for x in foundContextsSet
        push!(foundContextsSetModified, Symbol(x, :(ContextType())))
    end
    groupList = Vector{ContextGroup}()
    for (c, g) in Contexts.contextRuleManager.groups
        if Symbol(repr(c)) in foundContextsSetModified
            sym = Symbol(string(split(repr(c), "ContextType()")[1]))
            groups[sym] = g
            !(g in groupList) && push!(groupList, g)
        end
    end
    groupList = collect(groupList)
    newGroupList = Vector{ContextGroup}()
    for c in contextList
        for g in groupList
            if (groups[c] == g) && !(g in newGroupList)
                push!(newGroupList, g)
            end
        end
    end
    groupList = newGroupList
    newMap = Dict{Vector{Union{Expr, Symbol}}, Expr}()
    for (k, v) in atomic_models
        for (contexts, code) in contextCodeMap
            if contexts ⊆ k
                for pairs in v
                    newKey = []
                    for g in groupList
                        for (context, val) in pairs
                            if val && (groups[context] == g) 
                                push!(newKey, context)
                            end
                        end
                    end
                    newMap[newKey] = code
                end
            end
        end
    end
    contextCodeMap = newMap
    for (contexts, content) in contextCodeMap
        if length(contexts) > 1
            context = quote
                ($(contexts...))
            end
        else
            context = contexts[1]
        end
        Base.remove_linenums!(context)
        functiondef =   quote 
                           @context $context function $fname($(fargs...))
                               $content
                           end
                           push!(get!(contextualFunctions, $fname, []), $contexts)
                       end
        if functiondef.args[1] isa LineNumberNode
            deleteat!(functiondef.args, 1)  
        end
        if functiondef.args[1].args[4].args[2].args[1] isa LineNumberNode
            deleteat!(functiondef.args[1].args[4].args[2].args, 1)   
        end
        push!(retExpr.args, functiondef)   
    end
    contexts::Vector{Symbol} = collect(keys(contextCodeMap))[1]
    Base.remove_linenums!(groups)
    if length(contexts) > 1
        context = quote
            $(contexts...)
        end
    else
        context = contexts[1]
    end
    Base.remove_linenums!(context)
    args = [x.args[1] for x in fargs]
    functiondef =   quote 
                        function $fname($(fargs...))
                            contexts::Tuple = Tuple([Contexts.contextRuleManager.groups[c]() for c in $context])
                            $fname(contexts, $(args...))
                        end
                    end
    Base.remove_linenums!(functiondef)
    push!(retExpr.args, functiondef) 
    if !isnothing(outputPath)
        prettyPrint(outputPath, retExpr)
        newRetExpr = quote include($outputPath) end
        return newRetExpr
    else
        return retExpr
    end    
end
