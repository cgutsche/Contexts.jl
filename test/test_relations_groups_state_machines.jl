
@testset "Context Relations, Groups and State Machines" begin
    @testset "weakInclusion" begin
        @newContext WI_Ctx1, WI_Ctx2, WI_Ctx3, WI_Ctx4, WI_Ctx5
        
        # Basic case: weakInclusion
        weakInclusion(WI_Ctx1 => WI_Ctx2)
        activateContext(WI_Ctx1)
        @test isActive(WI_Ctx1)
        @test isActive(WI_Ctx2)  # Should be activated when WI_Ctx1 is activated
        deactivateContext(WI_Ctx1)
        @test !isActive(WI_Ctx1)
        @test !isActive(WI_Ctx2)  # Should be deactivated when WI_Ctx1 is deactivated
        
        # Case with boolean expression
        weakInclusion(WI_Ctx1 & WI_Ctx3 => WI_Ctx4)
        activateContext(WI_Ctx1)
        @test !isActive(WI_Ctx4)  # WI_Ctx3 not active
        activateContext(WI_Ctx3)
        @test isActive(WI_Ctx4)  # Both WI_Ctx1 and WI_Ctx3 active
        deactivateContext(WI_Ctx1)
        @test !isActive(WI_Ctx4)  # WI_Ctx1 deactivated
        
        # Multiple relations: weakInclusion with weakExclusion
        @newContext WI_WE_Ctx1, WI_WE_Ctx2, WI_WE_Ctx3
        weakInclusion(WI_WE_Ctx1 => WI_WE_Ctx2)
        weakExclusion(WI_WE_Ctx2, WI_WE_Ctx3)
        activateContext(WI_WE_Ctx1)
        @test isActive(WI_WE_Ctx2)
        @test !isActive(WI_WE_Ctx3)
        # Activating WI_WE_Ctx3 should deactivate WI_WE_Ctx2 due to weakExclusion
        activateContext(WI_WE_Ctx3)
        @test !isActive(WI_WE_Ctx2)
        @test isActive(WI_WE_Ctx3)
        # Deactivating WI_WE_Ctx1 should deactivate WI_WE_Ctx2, allowing reactivation
        deactivateContext(WI_WE_Ctx1)
        @test !isActive(WI_WE_Ctx2)
        activateContext(WI_WE_Ctx2)
        @test isActive(WI_WE_Ctx2)
        @test !isActive(WI_WE_Ctx3)
    end
    
    @testset "strongInclusion" begin
        @newContext SI_Ctx1, SI_Ctx2, SI_Ctx3, SI_Ctx4
        
        # Basic case: strongInclusion
        strongInclusion(SI_Ctx1 => SI_Ctx2)
        activateContext(SI_Ctx1)
        @test isActive(SI_Ctx1)
        @test isActive(SI_Ctx2)
        # Deactivating SI_Ctx2 should deactivate SI_Ctx1
        deactivateContext(SI_Ctx2)
        @test !isActive(SI_Ctx1)
        @test !isActive(SI_Ctx2)
        
        # Case with OR boolean expression
        strongInclusion((SI_Ctx1 | SI_Ctx3) => SI_Ctx4)
        activateContext(SI_Ctx1)
        @test isActive(SI_Ctx4)
        deactivateContext(SI_Ctx1)
        @test !isActive(SI_Ctx4)  # SI_Ctx1 and SI_Ctx3 not active
        activateContext(SI_Ctx3)
        @test isActive(SI_Ctx4)
        deactivateContext(SI_Ctx4)
        @test !isActive(SI_Ctx1)
        @test !isActive(SI_Ctx3)
        
        # Multiple relations: strongInclusion with requirement
        @newContext SI_R_Ctx1, SI_R_Ctx2, SI_R_Ctx3
        strongInclusion(SI_R_Ctx1 => SI_R_Ctx2)
        requirement(SI_R_Ctx2 => SI_R_Ctx3)
        activateContext(SI_R_Ctx3)
        activateContext(SI_R_Ctx1)
        @test isActive(SI_R_Ctx1)
        @test isActive(SI_R_Ctx2)
        @test isActive(SI_R_Ctx3)
        # Deactivating SI_R_Ctx3 should deactivate SI_R_Ctx2 and thus SI_R_Ctx1
        deactivateContext(SI_R_Ctx3)
        @test !isActive(SI_R_Ctx1)
        @test !isActive(SI_R_Ctx2)
        @test !isActive(SI_R_Ctx3)
    end
    
    @testset "requirement" begin
        @newContext Req_Ctx1, Req_Ctx2, Req_Ctx3
        
        # Basic case: requirement
        requirement(Req_Ctx1 => Req_Ctx2)
        # Cannot activate Req_Ctx1 without Req_Ctx2
        activateContext(Req_Ctx1)
        @test !isActive(Req_Ctx1)
        activateContext(Req_Ctx2)
        activateContext(Req_Ctx1)
        @test isActive(Req_Ctx1)
        @test isActive(Req_Ctx2)
        # Deactivating Req_Ctx2 should deactivate Req_Ctx1
        deactivateContext(Req_Ctx2)
        @test !isActive(Req_Ctx1)
        @test !isActive(Req_Ctx2)
        
        # Case with boolean expression
        requirement(Req_Ctx1 => (Req_Ctx2 & Req_Ctx3))
        activateContext(Req_Ctx2)
        activateContext(Req_Ctx1)
        @test !isActive(Req_Ctx1)  # Req_Ctx3 not active
        activateContext(Req_Ctx3)
        activateContext(Req_Ctx1)
        @test isActive(Req_Ctx1)
        deactivateContext(Req_Ctx2)
        @test !isActive(Req_Ctx1)
        
        # Multiple relations: requirement with weakExclusion
        @newContext Req_Ex_Ctx1, Req_Ex_Ctx2, Req_Ex_Ctx3
        requirement(Req_Ex_Ctx1 => Req_Ex_Ctx2)
        weakExclusion(Req_Ex_Ctx2, Req_Ex_Ctx3)
        activateContext(Req_Ex_Ctx2)
        activateContext(Req_Ex_Ctx1)
        @test isActive(Req_Ex_Ctx1)
        @test isActive(Req_Ex_Ctx2)
        @test !isActive(Req_Ex_Ctx3)
        # Activating Req_Ex_Ctx3 should deactivate Req_Ex_Ctx2 and thus Req_Ex_Ctx1
        activateContext(Req_Ex_Ctx3)
        @test !isActive(Req_Ex_Ctx1)
        @test !isActive(Req_Ex_Ctx2)
        @test isActive(Req_Ex_Ctx3)
    end
    
    @testset "exclusion" begin
        @newContext Ex_Ctx1, Ex_Ctx2, Ex_Ctx3
        

        # Basic case: exclusion (strict mutual exclusion)
        exclusion(Ex_Ctx1, Ex_Ctx2)
        exclusion(Ex_Ctx1, Ex_Ctx3)
        activateContext(Ex_Ctx1)
        @test isActive(Ex_Ctx1)
        @test !isActive(Ex_Ctx2)
        # Activating Ex_Ctx2 should be blocked by Ex_Ctx1
        activateContext(Ex_Ctx2)
        @test !isActive(Ex_Ctx2)
        @test isActive(Ex_Ctx1)
        # Activating Ex_Ctx3 should be blocked by Ex_Ctx1
        activateContext(Ex_Ctx3)
        @test isActive(Ex_Ctx1)
        @test !isActive(Ex_Ctx2)
        @test !isActive(Ex_Ctx3)
        
        # Multiple relations: exclusion with weakInclusion
        @newContext Ex_WI_Ctx1, Ex_WI_Ctx2, Ex_WI_Ctx3
        exclusion(Ex_WI_Ctx1, Ex_WI_Ctx2)
        weakInclusion(Ex_WI_Ctx3 => Ex_WI_Ctx1)
        activateContext(Ex_WI_Ctx3)
        @test isActive(Ex_WI_Ctx1)
        @test !isActive(Ex_WI_Ctx2)
        # Activating Ex_WI_Ctx2 is blocked by Ex_WI_Ctx1
        activateContext(Ex_WI_Ctx2)
        @test isActive(Ex_WI_Ctx1)
        @test !isActive(Ex_WI_Ctx2)
        # Since Ex_WI_Ctx3 is still active, weakInclusion should reactivate Ex_WI_Ctx1
        deactivateContext(Ex_WI_Ctx3)
        activateContext(Ex_WI_Ctx2)
        @test !isActive(Ex_WI_Ctx1)
        @test isActive(Ex_WI_Ctx2)
        @test !isActive(Ex_WI_Ctx3)
        activateContext(Ex_WI_Ctx3)
        @test !isActive(Ex_WI_Ctx1)
    end
    
    @testset "directedExclusion" begin
        @newContext DE_Ctx1, DE_Ctx2, DE_Ctx3
        
        # Basic case: directedExclusion
        directedExclusion(DE_Ctx1 => DE_Ctx2)
        activateContext(DE_Ctx1)
        activateContext(DE_Ctx2)
        @test isActive(DE_Ctx1)
        @test !isActive(DE_Ctx2)  # DE_Ctx2 should be deactivated when DE_Ctx1 activates
        
        # Multiple directed exclusions
        directedExclusion(DE_Ctx1 => DE_Ctx3)
        activateContext(DE_Ctx3)
        @test isActive(DE_Ctx1)
        @test !isActive(DE_Ctx2)
        @test !isActive(DE_Ctx3)  # DE_Ctx3 should be deactivated
        
        # Multiple relations: directedExclusion with requirement
        @newContext DE_Req_Ctx1, DE_Req_Ctx2, DE_Req_Ctx3
        directedExclusion(DE_Req_Ctx1 => DE_Req_Ctx2)
        requirement(DE_Req_Ctx2 => DE_Req_Ctx3)
        activateContext(DE_Req_Ctx3)
        activateContext(DE_Req_Ctx2)
        @test isActive(DE_Req_Ctx2)
        @test isActive(DE_Req_Ctx3)
        activateContext(DE_Req_Ctx1)
        @test isActive(DE_Req_Ctx1)
        @test !isActive(DE_Req_Ctx2)  # Deactivated by directedExclusion
        @test isActive(DE_Req_Ctx3)
    end
    
    @testset "weakExclusion" begin
        @newContext WE_Ctx1, WE_Ctx2, WE_Ctx3
        
        # Basic case: weakExclusion
        weakExclusion(WE_Ctx1, WE_Ctx2)
        activateContext(WE_Ctx1)
        @test isActive(WE_Ctx1)
        @test !isActive(WE_Ctx2)
        # With weak exclusion, we can reactivate the other context
        activateContext(WE_Ctx2)
        @test !isActive(WE_Ctx1)
        @test isActive(WE_Ctx2)
        
        # Multiple weak exclusions
        weakExclusion(WE_Ctx1, WE_Ctx3)
        activateContext(WE_Ctx1)
        @test isActive(WE_Ctx1)
        @test !isActive(WE_Ctx2)
        @test !isActive(WE_Ctx3)
        activateContext(WE_Ctx3)
        @test !isActive(WE_Ctx1)
        @test !isActive(WE_Ctx2)
        @test isActive(WE_Ctx3)
        
        # Multiple relations: weakExclusion with weakInclusion
        @newContext WE_WI_Ctx1, WE_WI_Ctx2, WE_WI_Ctx3
        weakExclusion(WE_WI_Ctx1, WE_WI_Ctx2)
        weakInclusion(WE_WI_Ctx3 => WE_WI_Ctx1)
        activateContext(WE_WI_Ctx3)
        @test isActive(WE_WI_Ctx1)
        @test !isActive(WE_WI_Ctx2)
        activateContext(WE_WI_Ctx2)
        @test !isActive(WE_WI_Ctx1)
        @test isActive(WE_WI_Ctx2)
        deactivateContext(WE_WI_Ctx3)
        # Activating WE_WI_Ctx3 should reactivate WE_WI_Ctx1 due to weakInclusion, even though WE_WI_Ctx2 is active
        # WE_WI_Ctx2 should be deactivated due to weakExclusion
        activateContext(WE_WI_Ctx3)
        @test isActive(WE_WI_Ctx1)
        @test !isActive(WE_WI_Ctx2)
    end
    
    @testset "alternative" begin
        @newContext Alt_Ctx1, Alt_Ctx2, Alt_Ctx3
        
        # Basic case: alternative (exactly one active)
        alternative(Alt_Ctx1, Alt_Ctx2, Alt_Ctx3)
        # Initially, should have exactly one active (implementation dependent)
        activateContext(Alt_Ctx2)
        @test isActive(Alt_Ctx2)
        @test !isActive(Alt_Ctx1)
        @test !isActive(Alt_Ctx3)
        # Activating another should deactivate the current one
        activateContext(Alt_Ctx3)
        @test !isActive(Alt_Ctx2)
        @test !isActive(Alt_Ctx1)
        @test isActive(Alt_Ctx3)
        # Deactivating the active context should not work
        deactivateContext(Alt_Ctx3)
        @test !isActive(Alt_Ctx1)
        @test !isActive(Alt_Ctx2)
        @test isActive(Alt_Ctx3)
        
        # Multiple relations: alternative with weakInclusion
        @newContext Alt_WI_Ctx1
        weakInclusion(Alt_WI_Ctx1 => Alt_Ctx1)
        activateContext(Alt_WI_Ctx1)
        @test isActive(Alt_WI_Ctx1)
        @test isActive(Alt_Ctx1)
        @test !isActive(Alt_Ctx2)
        @test !isActive(Alt_Ctx3)
        # Alternative will prevent Alt_Ctx1 from being deactivated
        activateContext(Alt_WI_Ctx1)
        @test isActive(Alt_WI_Ctx1)
        @test isActive(Alt_Ctx1)
        @test !isActive(Alt_Ctx2)
        @test !isActive(Alt_Ctx3)
    end
    
    @testset "Context Groups" begin
        @newContext GroupCtx1, GroupCtx2, GroupCtx3
        activateContext(GroupCtx1)
        # Create a context group
        group = ContextGroup(GroupCtx1, GroupCtx2, GroupCtx3)
        @test group isa ContextGroup
        @test GroupCtx1 in group.subContexts
        @test GroupCtx2 in group.subContexts
        @test GroupCtx3 in group.subContexts
        
        # group returns activated context
        @test group() == GroupCtx1

        # Activate another context and test group returns it
        activateContext(GroupCtx2)
        @test group() == GroupCtx2
        
        # Activating another should deactivate the first (alternative activation)
        activateContext(GroupCtx1)
        @test !isActive(GroupCtx2)
        @test isActive(GroupCtx1)
        @test group() == GroupCtx1
        
        # Test that contexts in group cannot be in another group
        @newContext OtherCtx
        @test_throws ErrorException ContextGroup(GroupCtx1, OtherCtx)
    end
    
    @testset "Context State Machines" begin
        @newContext StateA, StateB, StateC
        
        # Define a state machine
        @ContextStateMachine TestStateMachine begin
            @variable x::Int = 0
            @variable y::Float64 = 1.0
            @contexts StateA, StateB, StateC
            @initialState StateA
            @transition StateA => StateB : (x > 5)
            @transition StateB => StateC : (y < 0.5)
            @transition StateC => StateA : (x <= 5 && y >= 0.5)
        end
        
        @test TestStateMachine isa ContextStateMachine
        @test isActive(StateA)
        @test !isActive(StateB)
        @test !isActive(StateC)
        @test TestStateMachine() == StateA
        
        # Test transition StateA => StateB
        TestStateMachine.x = 10  # x > 5 should trigger transition
        @test !isActive(StateA)
        @test isActive(StateB)
        @test !isActive(StateC)
        @test TestStateMachine() == StateB
        
        # Test transition StateB => StateC
        TestStateMachine.y = 0.3  # y < 0.5 should trigger transition
        @test !isActive(StateA)
        @test !isActive(StateB)
        @test isActive(StateC)
        @test TestStateMachine() == StateC
        
        # Test transition StateC => StateA
        TestStateMachine.x = 3
        # StateC => StateA requires x <= 5 and y >= 0.5
        # As y is currently 0.3, this should not trigger the transition
        @test !isActive(StateA)
        @test !isActive(StateB)
        @test isActive(StateC)
        TestStateMachine.y = 0.6  # Now y >= 0.5 should trigger transition
        @test isActive(StateA)
        @test !isActive(StateB)
        @test !isActive(StateC)
        @test TestStateMachine() == StateA
        
        # Test variable access
        @test TestStateMachine.x == 3
        @test TestStateMachine.y == 0.6
    end
end