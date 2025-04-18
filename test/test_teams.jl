@testset "Teams" begin
    @testset "Static Teams" begin
        @newContext TeamContext
        
        # Define a test team
        @context TeamContext @newTeam TestTeam begin
            @relationalAttributes begin
                name::String    
            end

            @role Role1 << Int64 begin
                value::Int
            end
            
            @role Role2 << String begin
                text::String
            end
        end

        # Test team creation
        @test TestTeam <: Team
        @test Role1 <: Role
        @test Role2 <: Role

        # Test role assignment
        obj1 = 42
        obj2 = "test"
        team = assignRoles(TeamContext, TestTeam("TestTeam"), 
            obj1 => Role1(100),
            obj2 => Role2("test")
        )
        
        @test hasRole(TeamContext, obj1, Role1, TestTeam)
        @test hasRole(TeamContext, obj2, Role2, TestTeam)
        
        # Test role retrieval
        @test getObjectOfRole(TeamContext, TestTeam, Role1) == [obj1]
        @test getObjectOfRole(TeamContext, TestTeam, Role2) == [obj2]
        
        # Test role disassignment
        disassignRoles(TeamContext, team, Role1=>obj1, Role2=>obj2)
        @test !hasRole(TeamContext, obj1, Role1, TestTeam)
        @test !hasRole(TeamContext, obj2, Role2, TestTeam)
    end

    @testset "Dynamic Teams" begin
        @newContext DynTeamContext
        
        @newDynamicTeam DynTeamContext TestDynTeam begin
            @IDAttribute id::Int
            
            @relationalAttributes begin
                name::String
            end
            
            @role DynRole1<<Int64 [1..3] begin
                value::Int
            end
            
            @role DynRole2<<String [1..2] begin
                text::String
            end
        end

        # Test team creation and role assignment
        obj1 = 42
        obj2 = "test"
        team = assignRoles(DynTeamContext, TestDynTeam(1, "TestDynTeam"), 
            obj1 => DynRole1(100),
            obj2 => DynRole2("test")
        )
        
        @test hasRole(DynTeamContext, obj1, DynRole1, team)
        @test hasRole(DynTeamContext, obj2, DynRole2, team)
        
        # Test team retrieval by ID
        @test getDynamicTeam(DynTeamContext, TestDynTeam, 1) == team
        
        # Test role disassignment
        disassignRoles(DynTeamContext, team)
        @test getDynamicTeam(DynTeamContext, TestDynTeam, 1) === nothing
    end
end 