@testset "Mixins" begin
    @newContext MixinContext

    # Define a test mixin
    @newMixin MixinContext TestMixin<<Int64 begin
        value::Int
    end

    @testset "Mixin Creation and Assignment" begin
        # Test mixin creation
        @test TestMixin <: Mixin
        
        # Test mixin assignment
        obj = 42
        @context MixinContext obj >> TestMixin(100)
        
        @test hasMixin(MixinContext, obj, TestMixin)
        @test getMixin(MixinContext, obj, TestMixin).value == 100
        
        # Test mixin retrieval
        @test obj in getObjectsOfMixin(MixinContext, TestMixin)
        
        # Test mixin disassignment
        disassignMixin(MixinContext, obj=>TestMixin)
        @test !hasMixin(MixinContext, obj, TestMixin)
    end
end 