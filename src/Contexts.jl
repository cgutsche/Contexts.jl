 __precompile__()
module Contexts
using Parameters

include("ContextTypeDef.jl")
include("PetriNetTypeDef.jl")
include("ContextManagement.jl")
include("RoleManagement.jl")
include("ContextDef.jl")
include("ContextualBehavior.jl")
include("ContextRoleDef.jl")
include("ContextRulesUtils.jl")
include("RoleChanges.jl")
include("PetriNetUtils.jl")

export addContext, getActiveContexts, isActive, activateContext, deactivateContext, deactivateAllContexts, addMixin, addTeam, getTeam, getDynamicTeam, getDynamicTeams, getRoles, getRolesOfTeam, getObjectOfRole, getDynamicTeamID, getObjectsOfRole, hasRole, getTeamPartners, getContexts, getMixins, getMixin, getRole, <<, >>, changeRoles, assignRoles, disassignRoles, assignMixin, disassignMixin
export @newContext, @newTeam, @newMixin, @team, @context, @activeContext, @assignRoles, @disassignRoles, @changeRoles, @newDynamicTeam
export Context, ContextGroup, Mixin, Role, Team, DynamicTeam, AndContextRule, OrContextRule, NotContextRule, reduceRuleToElementary, getCDNF, addPNToControlPN, getObjectsOfMixin, hasMixin
export CompiledPetriNet, PetriNet, Place, Transition, NormalArc, InhibitorArc, TestArc, compile, on, off, Update, mergeCompiledPetriNets

export @ContextStateMachine, ContextStateMachine

include("ContextualPNCalculation.jl")
export runPN

include("ContextPNRules.jl")
export exclusion, weakExclusion, directedExclusion, strongInclusion, weakInclusion, requirement, alternative
export getConstraints


end