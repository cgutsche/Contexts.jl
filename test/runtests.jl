using Test
include("../src/Contexts.jl")
using .Contexts

# Include specific test files
@testset "Context.jl global tests" begin
    include("test_context_basics.jl")
    include("test_context_rules.jl")
    include("test_teams.jl")
    include("test_mixins.jl")
    include("test_petri_nets.jl")
    include("test_relations_groups_state_machines.jl")
end
