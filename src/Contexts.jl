module Contexts

include("ContextDef.jl")
export addContext, getActiveContexts, isActive, activateContext, deactivateContext, deactivateAllContexts, addMixin, getContexts, getMixins, getMixin, @newContext, @newMixin, @context, assignMixin, disassignMixin, Context, Mixin, AndContextRule, OrContextRule, NotContextRule
export CompiledPetriNet, PetriNet, Place, Transition, NormalArc, InhibitorArc, TestArc, compile, on, off, Update, mergeCompiledPetriNets

include("ContextualPNCalculation.jl")
export runPN

include("ContextPNRules.jl")
export exclusion, directedExclusion, strongInclusion, weakInclusion, requirement


end