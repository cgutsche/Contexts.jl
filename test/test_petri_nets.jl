@testset "Petri Nets" begin
    @testset "Basic Petri Net Operations" begin
        # Create places
        p1 = Place("p1", 1.0)
        p2 = Place("p2", 0.0)
        
        # Create context and transition
        @newContext PNContext
        t1 = Transition("t1", PNContext, [PNContext=>on])
        
        # Create arcs
        a1 = NormalArc(from=p1, to=t1, weight=1.0, priority=1)
        a2 = NormalArc(from=t1, to=p2, weight=1.0, priority=1)
        
        # Create Petri net
        pn = PetriNet(
            places=[p1, p2],
            transitions=[t1],
            arcs=[a1, a2]
        )
        
        # Test compilation
        cpn = compile(pn)
        @test cpn isa CompiledPetriNet
        @test size(cpn.WeightMatrix_in) == (2,1)
        @test size(cpn.WeightMatrix_out) == (2,1)
        
        # Test merging
        pn2 = PetriNet(
            places=[Place("p3", 0.0)],
            transitions=[Transition("t2", PNContext, [PNContext=>off])],
            arcs=[]
        )
        cpn2 = compile(pn2)
        
        merged_cpn = mergeCompiledPetriNets(cpn, cpn2)
        @test size(merged_cpn.WeightMatrix_in) == (3,2)
    end
end 