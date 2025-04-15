"""
    nonNeg(x)

Returns a vector of the same size as x where each element is:
- 1 if x[i] ≥ 0
- 0 if x[i] < 0

Used for Petri net calculations to check non-negative conditions.
"""
function nonNeg(x)
    sign.(sign.(x) .+ 1)
end

"""
    pos(x)

Returns a vector of the same size as x where each element is:
- 1 if x[i] > 0
- 0 if x[i] ≤ 0

Used for Petri net calculations to check strictly positive conditions.
"""
function pos(x)
    sign.(sign.(x) .- 1) .+ 1
end

"""
    neg(x)

Returns a vector of the same size as x where each element is:
- 1 if x[i] < 0
- 0 if x[i] ≥ 0

Used for Petri net calculations to check negative conditions.
"""
function neg(x)
    1 .- nonNeg(x)
end

"""
    matrixify(v, N)

Creates a matrix by repeating vector v N times as columns.
Returns a matrix of size (length(v) × N) where each column is v.

Arguments:
- `v`: Vector to be repeated
- `N`: Number of times to repeat the vector as columns
"""
function matrixify(v, N)
    transpose(transpose(v) .* ones(N))
end

"""
    runPN(pn::Nothing)

Null case for running a Petri net when no net is provided.
Returns `true` without doing anything.
"""
function runPN(pn::Nothing)
    true
end

"""
    runPN(pn::CompiledPetriNet)

Executes a compiled Petri net until it reaches a dead state (no more transitions can fire).
Updates context states based on the Petri net execution.

Arguments:
- `pn`: A compiled Petri net containing the network structure and current state

Returns nothing, but modifies the Petri net state and context activations.
"""
function runPN(pn::CompiledPetriNet)
    # Get number of contexts dimensions of the Petri net
    nContexts::Int64 = size(pn.ContextMatrices[1])[2]
    nTransitions::Int64 = size(pn.WeightMatrix_in)[2]
    
    # Initialize context activation vector
    a::Vector{Float64} = zeros(nContexts)
    for context in getActiveContexts()
        if context in keys(pn.ContextMap)
            a[pn.ContextMap[context]] = 1
        end
    end

    # Create vector to map indices back to context objects
    ContextVector::Vector{Union{<:Context, <:AbstractContextRule}} = Vector{Union{<:Context, <:AbstractContextRule}}(undef, nContexts)
    for context in keys(pn.ContextMap)
        ContextVector[pn.ContextMap[context]] = context
    end

    while true
        # Create token matrix for calculations
        T::Matrix{Float64} = matrixify(pn.tokenVector, size(pn.WeightMatrix_in)[2])
        
        # Calculate firing conditions for different arc types:
        # Check if enough tokens are available for normal arcs
        f_normal::Matrix{Float64} = nonNeg(findmin(T .- pn.WeightMatrix_out, dims=1)[1])
        # Check if inhibitor arcs prevent firing
        f_inhibitor::Matrix{Float64} = neg(findmax(pn.WeightMatrix_inhibitor .* (T .- pn.WeightMatrix_inhibitor), dims=1)[1])
        # Check if test arcs conditions are met
        f_test::Matrix{Float64} = nonNeg(findmin(T .- pn.WeightMatrix_test, dims=1)[1])
        
        # Calculate context-based firing conditions
        f_context::Matrix{Float64} = zeros(1, nTransitions)
        for i in 1:nTransitions
            # Extract positive and negative context conditions
            h1::Matrix{Float64} = pos(transpose(pn.ContextMatrices[i]))
            h2::Matrix{Float64} = -neg(transpose(pn.ContextMatrices[i]))
            # Check if all required contexts are active
            b1::Bool = (findmin(findmax(h1 .- (h1 .* matrixify(a, size(pn.ContextMatrices[i])[1])), dims=1)[1], dims=2)[1])[1] == 0
            # Check if all forbidden contexts are inactive
            b2::Bool = (findmax(findmin(h2 .* matrixify(a, size(pn.ContextMatrices[i])[1]), dims=1)[1], dims=2)[1])[1] == 0
            f_context[1, i] = 1 * b1 * b2
        end

        # Combine all firing conditions
        f::Matrix{Float64} = f_normal .* f_inhibitor .* f_test .* f_context
        
        # Handle transition priorities
        c::Matrix{Float64} = neg(pn.tokenVector .- pn.WeightMatrix_out * transpose(f))
        while sum(c) > 0
            m::Int = findmax(pn.PrioritiesMatrix, dims=2)[1]
            f = f .- pos(findmax(pn.PrioritiesMatrix .- matrixify(m, size(pn.WeightMatrix_in)[2]) .+ matrixify(c, size(pn.WeightMatrix_in)[2]), dims=1)[1])
            c = neg(pn.tokenVector .- pn.WeightMatrix_out * transpose(f))
        end

        # Exit if no transitions can fire (dead state)
        if sum(f) == 0
            break 
        end

        # Update context activity based on fired transitions
        u::Vector{Float64} = vec(sign.(pn.UpdateMatrix * transpose(f)))
        a = pos(a + u)
        
        # Activate/deactivate contexts based on new state
        for context in ContextVector[Bool.(a)]
            activateContextWithoutPN(context)
        end
        for context in ContextVector[Bool.((a .- 1).^2)]
            deactivateContextWithoutPN(context)
        end

        # Update token counts based on fired transitions
        pn.tokenVector = vec(pn.tokenVector .+ (pn.WeightMatrix_in .- pn.WeightMatrix_out) * transpose(f))
    end
end

"""
    runPN(pn::CompiledPetriNet, N::Int)

Executes a compiled Petri net for a maximum of N steps or until it reaches a dead state.
Updates context states based on the Petri net execution.

Arguments:
- `pn`: A compiled Petri net containing the network structure and current state
- `N`: Maximum number of steps to execute

Prints "Petri net is dead." if no transitions can fire before N steps.
Returns nothing, but modifies the Petri net state and context activations.
"""
function runPN(pn::CompiledPetriNet, N::Int)
    # Get number of contexts and transitions in the Petri net
    nContexts = size(pn.ContextMatrices[1])[2]
    nTransitions = size(pn.WeightMatrix_in)[2]
    
    # Initialize context activation vector
    a = zeros(nContexts)
    for context in getActiveContexts()
        if context in keys(pn.ContextMap)
            a[pn.ContextMap[context]] = 1
        end
    end

    # Create vector to map indices back to context objects
    ContextVector = Vector{Union{<:Context, <:AbstractContextRule}}(undef, nContexts)
    for context in keys(pn.ContextMap)
        ContextVector[pn.ContextMap[context]] = context
    end

    # Run for at most N steps
    for i in 1:N
        # Create token matrix for calculations
        T = matrixify(pn.tokenVector, size(pn.WeightMatrix_in)[2])
        
        # Calculate firing conditions for different arc types:
        # Check if enough tokens are available for normal arcs
        f_normal = nonNeg(findmin(T .- pn.WeightMatrix_out, dims=1)[1])
        # Check if inhibitor arcs prevent firing
        f_inhibitor = neg(findmax(pn.WeightMatrix_inhibitor .* (T .- pn.WeightMatrix_inhibitor), dims=1)[1])
        # Check if test arcs conditions are met
        f_test = nonNeg(findmin(T .- pn.WeightMatrix_test, dims=1)[1])
        
        # Calculate context-based firing conditions
        f_context = zeros(1, nTransitions)
        for i in 1:nTransitions
            # Extract positive and negative context conditions
            h1 = pos(transpose(pn.ContextMatrices[i]))
            h2 = -neg(transpose(pn.ContextMatrices[i]))
            # Check if all required contexts are active
            b1 = (findmin(findmax(h1 .- (h1 .* matrixify(a, size(pn.ContextMatrices[i])[1])), dims=1)[1], dims=2)[1])[1] == 0
            # Check if all forbidden contexts are inactive
            b2 = (findmax(findmin(h2 .* matrixify(a, size(pn.ContextMatrices[i])[1]), dims=1)[1], dims=2)[1])[1] == 0
            f_context[1, i] = 1 * b1 * b2
        end

        # Combine all firing conditions
        f = f_normal .* f_inhibitor .* f_test .* f_context
        
        # Handle transition priorities
        c = neg(pn.tokenVector .- pn.WeightMatrix_out * transpose(f))
        while sum(c) > 0
            m = findmax(pn.PrioritiesMatrix, dims=2)[1]
            f = f .- pos(findmax(pn.PrioritiesMatrix .- matrixify(m, size(pn.WeightMatrix_in)[2]) .+ matrixify(c, size(pn.WeightMatrix_in)[2]), dims=1)[1])
            c = neg(pn.tokenVector .- pn.WeightMatrix_out * transpose(f))
        end

        # Exit with message if no transitions can fire (dead state)
        if sum(f) == 0
            @info "Petri net is dead."
            break 
        end

        # Update context activity based on fired transitions
        u = sign.(pn.UpdateMatrix * transpose(f))
        a = pos(a + u)
        
        # Activate/deactivate contexts based on new state
        for context in ContextVector[Bool.(dropdims(a, dims=2))]
            activateContextWithoutPN(context)
        end
        for context in ContextVector[Bool.(dropdims((a .- 1).^2, dims=2))]
            deactivateContextWithoutPN(context)
        end

        # Update token counts based on fired transitions
        pn.tokenVector = vec(pn.tokenVector .+ (pn.WeightMatrix_in .- pn.WeightMatrix_out) * transpose(f))
    end
end
