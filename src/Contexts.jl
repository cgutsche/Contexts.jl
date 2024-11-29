 __precompile__()
module Contexts

include("ContextDef.jl")
export addContext, getActiveContexts, isActive, activateContext, deactivateContext, deactivateAllContexts, addMixin, addTeam, getTeam, getDynamicTeam, getDynamicTeams, getRoles, getObjectOfRole, getObjectsOfRole, hasRole, getTeamPartners, getContexts, getMixins, getMixin, getRole, @newContext, @newTeam, @newMixin, @team, @context, @activeContext, @assignRoles, @disassignRoles, @changeRoles, @newDynamicTeam, <<, >>, changeRoles, assignRoles, disassignRoles, assignMixin, disassignMixin, Context, Mixin, Role, Team, DynamicTeam, AndContextRule, OrContextRule, NotContextRule, reduceRuleToElementary, getCDNF, addPNToControlPN, getObjectsOfMixin, hasMixin
export CompiledPetriNet, PetriNet, Place, Transition, NormalArc, InhibitorArc, TestArc, compile, on, off, Update, mergeCompiledPetriNets

include("ContextualPNCalculation.jl")
export runPN

include("ContextPNRules.jl")
export exclusion, weakExclusion, directedExclusion, strongInclusion, weakInclusion, requirement


end