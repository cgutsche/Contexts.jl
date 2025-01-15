using Test
using Contexts

@testset "Context Rules" begin
    @testset "Basic Rules" begin
        @newContext RuleContext1
        @newContext RuleContext2
        
        # Test AND rule
        rule_and = RuleContext1 & RuleContext2
        @test rule_and isa AndContextRule
        @test !isActive(rule_and)
        activateContext(RuleContext1)
        @test !isActive(rule_and)
        activateContext(RuleContext2)
        @test isActive(rule_and)

        # Test OR rule
        rule_or = RuleContext1 | RuleContext2
        @test rule_or isa OrContextRule
        @test isActive(rule_or)
        deactivateContext(RuleContext1)
        @test isActive(rule_or)
        deactivateContext(RuleContext2)
        @test !isActive(rule_or)

        # Test NOT rule
        rule_not = !RuleContext1
        @test rule_not isa NotContextRule
        @test isActive(rule_not)
        activateContext(RuleContext1)
        @test !isActive(rule_not)
    end

    @testset "Complex Rules" begin
        @newContext C1
        @newContext C2
        @newContext C3

        complex_rule = (C1 & C2) | !C3
        @test complex_rule isa OrContextRule
        
        activateContext(C1)
        activateContext(C2)
        activateContext(C3)
        @test isActive(complex_rule)
    end
end 