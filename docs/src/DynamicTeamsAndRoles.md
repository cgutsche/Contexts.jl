# Dynamic Teams and Roles

```@docs
DynamicTeam
@newDynamicTeam
assignRoles
disassignRoles
@changeRoles
changeRoles
getDynamicTeam
getDynamicTeams
getDynamicTeamID
getObjectsOfRole
getRolesOfTeam
hasRole(::Context, obj, ::Type, ::DynamicTeam)
```

Dynamic teams allow runtime changes in team composition and cardinality. Use `@newDynamicTeam` to define dynamic teams, and `assignRoles`, `disassignRoles`, and `changeRoles` to manage role assignments. Query dynamic teams and their roles with the provided functions.

See also: [`assignRoles`](@ref), [`changeRoles`](@ref)
