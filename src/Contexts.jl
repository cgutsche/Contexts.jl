module Contexts

include("ContextDef.jl")
export addContext, getActiveContexts, isActive, activateContext, deactivateContext, deactivateAllContexts, addMixin, addTeam, getTeams, getRoles, hasRole, getTeamPartners, getContexts, getMixins, getMixin, getRole, @newContext, @newTeam, @newMixin, @context, @assignRoles, <<, >>, assignRoles, disassignRoles, assignMixin, disassignMixin, Context, Mixin, Role, Team, AndContextRule, OrContextRule, NotContextRule, reduceRuleToElementary
export CompiledPetriNet, PetriNet, Place, Transition, NormalArc, InhibitorArc, TestArc, compile, on, off, Update, mergeCompiledPetriNets

include("ContextualPNCalculation.jl")
export runPN

include("ContextPNRules.jl")
export exclusion, weakExclusion, directedExclusion, strongInclusion, weakInclusion, requirement


end