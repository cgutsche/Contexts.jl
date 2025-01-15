using Test
include("../src/Contexts.jl")
using .Contexts

# Include specific test files
include("test_context_basics.jl")
include("test_context_rules.jl")
include("test_teams.jl")
include("test_mixins.jl")
include("test_petri_nets.jl")
