include("ContextDef.jl")

export runPN

function nonNeg(x)
    sign.(sign.(x) .+ 1)
end

function pos(x)
    sign.(sign.(x) .- 1) .+ 1
end

function neg(x)
    1 .- nonNeg(x)
end

function matrixify(v, N)
    transpose(transpose(v) .* ones(N))
end

function runPN(pn::Nothing)
    true
end

function runPN(pn::CompiledPetriNet)
    nContexts = size(pn.ContextMatrices[1])[2]
    nTransitions = size(pn.WeightMatrix_in)[2]
    a = zeros(nContexts)
    for context in getActiveContexts()
        a[pn.ContextMap[context]] = 1
    end

    ContextVector = Vector{Union{<:Context, <:AbstractContextRule}}(undef, nContexts)
    for context in keys(pn.ContextMap)
        ContextVector[pn.ContextMap[context]] = context
    end
    while true
        T = matrixify(pn.tokenVector, size(pn.WeightMatrix_in)[2])
        f_normal = nonNeg(findmin(T .- pn.WeightMatrix_out, dims=1)[1])
        f_inhibitor = neg(findmax(pn.WeightMatrix_inhibitor .* (T .- pn.WeightMatrix_inhibitor), dims=1)[1])
        f_test = nonNeg(findmin(T .- pn.WeightMatrix_test, dims=1)[1])
        f_context = zeros(1, nTransitions)
        for i in 1:nTransitions
            h1 = pos(transpose(pn.ContextMatrices[i]))
            h2 = -neg(transpose(pn.ContextMatrices[i]))
            b1 = (findmin(findmax(h1 .- (h1 .* matrixify(a, size(pn.ContextMatrices[i])[1])), dims=1)[1], dims=2)[1])[1] == 0
            b2 = (findmax(findmin(h2 .* matrixify(a, size(pn.ContextMatrices[i])[1]), dims=1)[1], dims=2)[1])[1] == 0
            f_context[1, i] = 1 * b1 * b2
        end
        f = f_normal .* f_inhibitor .* f_test .* f_context
        c = neg(pn.tokenVector .- pn.WeightMatrix_out * transpose(f))
        while sum(c) > 0
            m = findmax(pn.PrioritiesMatrix, dims=2)[1]
            f = f .- pos(findmax(pn.PrioritiesMatrix .- matrixify(m, size(pn.WeightMatrix_in)[2]) .+ matrixify(c, size(pn.WeightMatrix_in)[2]), dims=1)[1])
            c = neg(pn.tokenVector .- pn.WeightMatrix_out * transpose(f))
        end
        if sum(f) == 0
            break 
        end
        u = sign.(pn.UpdateMatrix * transpose(f))
        a = pos(a + u)
        for context in ContextVector[Bool.(dropdims(a, dims=2))]
            activateContextWithoutPN(context)
        end
        for context in ContextVector[Bool.(dropdims((a .- 1).^2, dims=2))]
            deactivateContextWithoutPN(context)
        end
        pn.tokenVector = vec(pn.tokenVector .+ (pn.WeightMatrix_in .- pn.WeightMatrix_out) * transpose(f))
    end
end

function runPN(pn::CompiledPetriNet, N::Int, activeContexts::AbstractVector=[])
    nContexts = size(pn.ContextMatrices[1])[2]
    nTransitions = size(pn.WeightMatrix_in)[2]
    a = zeros(nContexts)
    for context in getActiveContexts()
        a[pn.ContextMap[context]] = 1
    end

    ContextVector = Vector{Union{<:Context, <:AbstractContextRule}}(undef, nContexts)
    for context in keys(pn.ContextMap)
        ContextVector[pn.ContextMap[context]] = context
    end
    for i in 1:N
        T = matrixify(pn.tokenVector, size(pn.WeightMatrix_in)[2])
        f_normal = nonNeg(findmin(T .- pn.WeightMatrix_out, dims=1)[1])
        f_inhibitor = neg(findmax(pn.WeightMatrix_inhibitor .* (T .- pn.WeightMatrix_inhibitor), dims=1)[1])
        f_test = nonNeg(findmin(T .- pn.WeightMatrix_test, dims=1)[1])
        f_context = zeros(1, nTransitions)
        for i in 1:nTransitions
            h1 = pos(transpose(pn.ContextMatrices[i]))
            h2 = -neg(transpose(pn.ContextMatrices[i]))
            b1 = (findmin(findmax(h1 .- (h1 .* matrixify(a, size(pn.ContextMatrices[i])[1])), dims=1)[1], dims=2)[1])[1] == 0
            b2 = (findmax(findmin(h2 .* matrixify(a, size(pn.ContextMatrices[i])[1]), dims=1)[1], dims=2)[1])[1] == 0
            f_context[1, i] = 1 * b1 * b2
        end
        f = f_normal .* f_inhibitor .* f_test .* f_context
        c = neg(pn.tokenVector .- pn.WeightMatrix_out * transpose(f))
        while sum(c) > 0
            m = findmax(pn.PrioritiesMatrix, dims=2)[1]
            f = f .- pos(findmax(pn.PrioritiesMatrix .- matrixify(m, size(pn.WeightMatrix_in)[2]) .+ matrixify(c, size(pn.WeightMatrix_in)[2]), dims=1)[1])
            c = neg(pn.tokenVector .- pn.WeightMatrix_out * transpose(f))
        end
        if sum(f) == 0
            println("Petri net is dead.")
            break 
        end
        u = sign.(pn.UpdateMatrix * transpose(f))
        a = pos(a + u)
        for context in ContextVector[Bool.(dropdims(a, dims=2))]
            activateContextWithoutPN(context)
        end
        for context in ContextVector[Bool.(dropdims((a .- 1).^2, dims=2))]
            deactivateContextWithoutPN(context)
        end
        pn.tokenVector = vec(pn.tokenVector .+ (pn.WeightMatrix_in .- pn.WeightMatrix_out) * transpose(f))
    end
end
