using Test
using Contexts

@testset "Context Basics" begin
    # Test context creation and management
    @testset "Context Creation" begin
        @newContext TestContext
        @test TestContext isa Context
        @test TestContext in getContexts()
    end

    @testset "Context Activation" begin
        @newContext ActiveContext
        @test !isActive(ActiveContext)
        @test activateContext(ActiveContext)
        @test isActive(ActiveContext)
        @test deactivateContext(ActiveContext)
        @test !isActive(ActiveContext)
    end

    @testset "Multiple Contexts" begin
        @newContext("Context1", "Context2")
        @test Context1 in getContexts()
        @test Context2 in getContexts()
    end
end 