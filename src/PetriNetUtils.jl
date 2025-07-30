
function mergeCompiledPetriNets(pn1::Union{Nothing, CompiledPetriNet}, pn2::Union{Nothing, CompiledPetriNet})
    typeof(pn1) == Nothing ? pn2 : pn1
end

function mergeCompiledPetriNets(pn1::CompiledPetriNet, pn2::CompiledPetriNet)
    size_pn1_dim1 = size(pn1.WeightMatrix_in)[1]
    size_pn2_dim1 = size(pn2.WeightMatrix_in)[1]
    size_pn1_dim2 = size(pn1.WeightMatrix_in)[2]
    size_pn2_dim2 = size(pn2.WeightMatrix_in)[2]

    WeightMatrix_in_merge = zeros(size_pn1_dim1+size_pn2_dim1, size_pn1_dim2+size_pn2_dim2)
    WeightMatrix_in_merge[1:size_pn1_dim1, 1:size_pn1_dim2] = pn1.WeightMatrix_in
    WeightMatrix_in_merge[size_pn1_dim1+1:end, size_pn1_dim2+1:end] = pn2.WeightMatrix_in
    
    WeightMatrix_out_merge = zeros(size_pn1_dim1+size_pn2_dim1, size_pn1_dim2+size_pn2_dim2)
    WeightMatrix_out_merge[1:size_pn1_dim1, 1:size_pn1_dim2] = pn1.WeightMatrix_out
    WeightMatrix_out_merge[size_pn1_dim1+1:end, size_pn1_dim2+1:end] = pn2.WeightMatrix_out

    WeightMatrix_inhibitor_merge = zeros(size_pn1_dim1+size_pn2_dim1, size_pn1_dim2+size_pn2_dim2) .+ Inf
    WeightMatrix_inhibitor_merge[1:size_pn1_dim1, 1:size_pn1_dim2] = pn1.WeightMatrix_inhibitor
    WeightMatrix_inhibitor_merge[size_pn1_dim1+1:end, size_pn1_dim2+1:end] = pn2.WeightMatrix_inhibitor

    WeightMatrix_test_merge = zeros(size_pn1_dim1+size_pn2_dim1, size_pn1_dim2+size_pn2_dim2)
    WeightMatrix_test_merge[1:size_pn1_dim1, 1:size_pn1_dim2] = pn1.WeightMatrix_test
    WeightMatrix_test_merge[size_pn1_dim1+1:end, size_pn1_dim2+1:end] = pn2.WeightMatrix_test    

    tokenVector_merge = vcat(pn1.tokenVector, pn2.tokenVector)

    PrioritiesMatrix_merge = zeros(size_pn1_dim1+size_pn2_dim1, size_pn1_dim2+size_pn2_dim2)
    PrioritiesMatrix_merge[1:size_pn1_dim1, 1:size_pn1_dim2] = pn1.PrioritiesMatrix
    PrioritiesMatrix_merge[size_pn1_dim1+1:end, size_pn1_dim2+1:end] = pn2.PrioritiesMatrix    

    ContextMatrices_merge = vcat(pn1.ContextMatrices, pn2.ContextMatrices)

    ContextMap_merge = merge(pn1.ContextMap, pn2.ContextMap)
    if length(pn1.ContextMatrices[1]) != length(pn2.ContextMatrices[1])
        if length(pn1.ContextMatrices[1]) < length(pn2.ContextMatrices[1])
            for i in 1:length(pn1.ContextMatrices)
                ContextMatrices_merge[i] = hcat(pn1.ContextMatrices[i], zeros(size(pn1.ContextMatrices[i])[1], length(ContextMap_merge)-size(pn1.ContextMatrices[i])[2]))
            end
        else
            for i in length(pn1.ContextMatrices)+1:length(pn1.ContextMatrices)+length(pn2.ContextMatrices)
                ContextMatrices_merge[i] = hcat(pn2.ContextMatrices[i-length(pn1.ContextMatrices)], zeros(size(pn2.ContextMatrices[i-length(pn1.ContextMatrices)])[1], length(ContextMap_merge)-size(pn2.ContextMatrices[i-length(pn1.ContextMatrices)])[2]))
            end
        end
    end

    UpdateMatrix_cast1 = zeros(length(ContextMap_merge), size_pn1_dim2+size_pn2_dim2)
    UpdateMatrix_cast2 = zeros(length(ContextMap_merge), size_pn1_dim2+size_pn2_dim2)
    if size(pn1.UpdateMatrix)[1] < size(pn2.UpdateMatrix)[1]
        UpdateMatrix_cast1[1:size(pn1.UpdateMatrix)[1], 1:size_pn1_dim2] = pn1.UpdateMatrix
        UpdateMatrix_cast2[1:end, size_pn1_dim2+1:end] = pn2.UpdateMatrix
    else
        UpdateMatrix_cast1[1:end, 1:size_pn1_dim2] = pn1.UpdateMatrix
        UpdateMatrix_cast2[1:size(pn2.UpdateMatrix)[1], size_pn1_dim2+1:end] = pn2.UpdateMatrix
    end
    UpdateMatrix_merge = sign.(UpdateMatrix_cast1 .+ UpdateMatrix_cast2)

    CompiledPetriNet(WeightMatrix_in_merge,
                     WeightMatrix_out_merge,
                     WeightMatrix_inhibitor_merge,
                     WeightMatrix_test_merge,
                     tokenVector_merge,
                     PrioritiesMatrix_merge,
                     ContextMatrices_merge,
                     UpdateMatrix_merge,
                     ContextMap_merge)
end

function reduceRuleToElementary(cr::AndContextRule)
	a = reduceRuleToElementary(cr.c1)
	b = reduceRuleToElementary(cr.c2)
	if (typeof(a) == OrContextRule) | (typeof(b) == OrContextRule)
		if (typeof(a) == OrContextRule) & (typeof(b) != OrContextRule)
			return OrContextRule(reduceRuleToElementary(AndContextRule(a.c1, b)), reduceRuleToElementary(AndContextRule(a.c2, b)))
		elseif (typeof(a) != OrContextRule) & (typeof(b) == OrContextRule)
			return OrContextRule(reduceRuleToElementary(AndContextRule(a, b.c1)), reduceRuleToElementary(AndContextRule(a, b.c2)))
		else
			return OrContextRule(OrContextRule(reduceRuleToElementary(AndContextRule(a.c1, b.c1)), reduceRuleToElementary(AndContextRule(a.c1, b.c2))),
								 OrContextRule(reduceRuleToElementary(AndContextRule(a.c2, b.c1)), reduceRuleToElementary(AndContextRule(a.c2, b.c2))))
		end
	end
	AndContextRule(a, b)
end

function reduceRuleToElementary(cr::OrContextRule)
	OrContextRule(reduceRuleToElementary(cr.c1), reduceRuleToElementary(cr.c2))
end

function reduceRuleToElementary(c::Context)
	c
end

function reduceRuleToElementary(c::Nothing)
	nothing
end

function reduceRuleToElementary(cr::NotContextRule)
	if typeof(cr.c) == AndContextRule
		return reduceRuleToElementary(OrContextRule(!(cr.c.c1), !(cr.c.c2)))
	end
	if typeof(cr.c) == OrContextRule
		return reduceRuleToElementary(AndContextRule(!(cr.c.c1), !(cr.c.c2)))
	end
	if typeof(cr.c) == NotContextRule
		return reduceRuleToElementary(cr.c.c)
	end
	if typeof(cr.c) <: Context
		return cr
	end
end

function getCDNF(cr::AbstractContextRule)
	function removeDoubleTerms(cr::AbstractContextRule)
		function getAndRules(cr::OrContextRule, l)
			push!(l, cr.c1)
			if typeof(cr.c2) == OrContextRule
				l = getAndRules(cr.c2, l)
			else
				push!(l, cr.c2)
			end
			l
		end
		function genOrRule(l)
			if length(l) == 1
				return l[1]
			end
			OrContextRule(l[1], genOrRule(l[2:end]))
		end
		if typeof(cr) == OrContextRule
			andRules = getAndRules(cr, [])
			contexts = getContextsOfRule(andRules[1])
			c = Dict()
			for (i, context) in enumerate(contexts)
				c[context] = i
			end
			z = zeros(length(contexts))
			d = Dict()
			for a in andRules
				i = genContextRuleMatrix(a, c, length(contexts))
				d[i] = a
			end
			cr = genOrRule(collect(values(d)))
		end
		cr
	end
	function addContextToRule(cr::OrContextRule, context::Context)
		if !(context in getContextsOfRule(cr.c1))
			newRule_p = AndContextRule(cr.c1, context)
			newRule_n = AndContextRule(cr.c1, !context)
			return OrContextRule(newRule_p, OrContextRule(newRule_n, addContextToRule(cr.c2, context)))
		end
		OrContextRule(cr.c1, addContextToRule(cr.c2, context))
	end
	function addContextToRule(cr::AndContextRule, context::Context)
		if !(context in getContextsOfRule(cr))
			newRule_p = AndContextRule(cr, context)
			newRule_n = AndContextRule(cr, !context)
			return OrContextRule(newRule_p, newRule_n)
		end
		cr
	end
	function addContextToRule(cr::NotContextRule, context::Context)
		if !(context in getContextsOfRule(cr))
			newRule_p = AndContextRule(cr.c, context)
			newRule_n = AndContextRule(cr.c, !context)
			return OrContextRule(newRule_p, newRule_n)
		end
		cr
	end
	function addContextToRule(cr::Context, context::Context)
		if !(context in getContextsOfRule(cr))
			newRule_p = AndContextRule(cr, context)
			newRule_n = AndContextRule(cr, !context)
			return OrContextRule(newRule_p, newRule_n)
		end
		cr
	end

	cr = reduceRuleToElementary(cr)

	if (typeof(cr) != OrContextRule)
		return cr
	end

	contexts = getContextsOfRule(cr)
	containedContexts = getContextsOfRule(cr.c1)

	for c in contexts
		cr = addContextToRule(cr, c)
	end

	cr = removeDoubleTerms(cr)
end

function genContextRuleMatrix(cr::T, cdict::Dict, nc::Int) where {T <: Union{AbstractContext, Nothing}}
    matrix = zeros(1, nc)
    if typeof(cr) <: AbstractContextRule
        if cr isa AndContextRule
            a = genContextRuleMatrix(cr.c1, cdict, nc)
            b = genContextRuleMatrix(cr.c2, cdict, nc)
            matrix = nothing
            c = 0
            for i in 1:size(a)[1]
                for j in 1:size(b)[1]
                    findmin((a[i, :] .- b[j, :]) .* b[j, :])[1] < -1 ? c = zeros(1, size(a)[2]) : c = a[i, :] .+ b[j, :]
                    c = reshape(c, 1, length(c))
                    matrix == nothing ? matrix = [c;] : matrix = [matrix; c]
                end            
            end       
        elseif cr isa OrContextRule
            matrix = [genContextRuleMatrix(cr.c1, cdict, nc); genContextRuleMatrix(cr.c2, cdict, nc)]
        else
            matrix = -genContextRuleMatrix(cr.c, cdict, nc)
        end
    elseif typeof(cr) <: Context
        matrix[cdict[cr]] = 1
    end
    matrix
end

function compile(pn::PetriNet)
    # should test here if name is given two times
    # should test here if arcs are connected correctly (not place to place etc.)
    np = length(pn.places)                              # number of places
    nt = length(pn.transitions)                         # number of transitions
    nc = length(getContexts())                          # number of contexts
    W_i = zeros(Float64, np, nt)                        # Input Arc weights matrix (to place)
    W_o = zeros(Float64, np, nt)                        # Output Arc weights matrix(from place)
    W_inhibitor = zeros(Float64, np, nt) .+ Inf         # Inhibitor Arc weights matrix
    W_test = zeros(Float64, np, nt)                     # Test Arc weights matrix
    t = zeros(Float64, np)                              # Token vector
    P = zeros(Float64, np, nt)                          # Priority matrix
    pdict = Dict()                                      # dictionary of places and corresponding index
    tdict = Dict()                                      # dictionary of transitions and corresponding index
    cdict = Dict()                                      # dictionary of contexts and corresponding index

    for (i, place) in enumerate(pn.places)
        t[i] = place.token
        pdict[place] = i
    end
    for (i, transition) in enumerate(pn.transitions)
        tdict[transition] = i
    end
    for (i, context) in enumerate(getContexts())
        cdict[context] = i
    end


    C = nothing                                         # Context matrix
    U = zeros(Float64, nc, nt)                          # Update matrix
    for transition in pn.transitions
        c = sign.(genContextRuleMatrix(reduceRuleToElementary(transition.contexts), cdict, nc))
        C == nothing ? C = [c] : C = [C; [c]]
        for update in transition.updates
            if update.updateValue == on
                U[cdict[update.context], tdict[transition]] = 1
            else
                U[cdict[update.context], tdict[transition]] = -1
            end
        end 
    end
    for arc in pn.arcs
        if arc.from isa Place
            if arc isa NormalArc
                W_o[pdict[arc.from], tdict[arc.to]] = arc.weight
                if !(arc.priority in P[pdict[arc.from]])
                    P[pdict[arc.from], tdict[arc.to]] = arc.priority
                else
                    print("check priority of place ", arc.from)
                end
            elseif arc isa InhibitorArc
                W_inhibitor[pdict[arc.from], tdict[arc.to]] = arc.weight
            else
                W_test[pdict[arc.from], tdict[arc.to]] = arc.weight
            end
        else
            W_i[pdict[arc.to], tdict[arc.from]] = arc.weight
        end
    end
    CompiledPetriNet(W_i, W_o, W_inhibitor, W_test, t, P, C, U, cdict)
end