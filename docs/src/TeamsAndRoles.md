# Teams and Roles

## Why Roles?

The difference of a Role compared to a Mixin is the following. While a Mixin can be defined single standing, a role is always defined within a group with other roles, which is called team. Roles can therefore only get assigned to an object, if all roles of this team are assigned at the same time. The team itself can have attributes that are connected to all roles of the team, e.g. the company, an employee, and an employer are working at.

```@docs
Role
Team
@newTeam
assignRoles(::Union{Context, Nothing}, ::Team, ::Any...)
disassignRoles(::Context, ::Team, ::Pair...)
getRoles(::Context, ::Any, ::Type, ::Type)
getRole(::Context, ::Any, ::DynamicTeam)
getRolesOfTeam(::Context, ::Team)
getTeam
hasRole(::Context, ::Any, ::Type, ::Team)
getTeamPartners(::Context, ::Any, ::Type, ::Team)
Contexts.getObjectOfRole(::Union{Nothing, Context}, ::Type, ::Type)
Contexts.getObjectOfRole(::Union{Nothing, Context}, ::Role)
Contexts.getObjectOfRole(::Role)
```

Teams and roles allow you to model collaborative structures in contexts. Use `@newTeam` to define teams and their roles, and `assignRoles`/`disassignRoles` to manage role assignments. Query roles and teams with the provided functions.

See also: [`assignRoles`](@ref), [`getRoles`](@ref)
