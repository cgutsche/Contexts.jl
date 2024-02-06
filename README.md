## Contexts.jl -- A simple Library for Context-Oriented Programming

### Available Functions and Macros to define Contexts and Mixins

`@newContext <<Context Name>>`
Creates a new Type `<<Context Name>>ContextType` and an Object `<<Context Name>>` of this type

`@newMixin <<Mixin Name>> <<List of Attributes>>  <<Context, mixin lives in>>  <<Type, mixin can be assigned to>>`
Creates a new Struct `<<Mixin Name>>` with the Attributes defined in `<<List of Attributes>>`

`@context <<Context Name>> <<function Definition>>`
Creates a function, specifically defined for the context <<Context Name>>. Note that, the variable `context` will be available inside the function by default.

`@context <<Context Name>> <<function call>>`
Calls a function, that was defined via `@context <<Context Name>> <<function Definition>>`. Note that, the variable `context` will be available inside the function by default.

`assignMixin(<<Type>> => <<Mixin Name>>(<<Mixin Attributes>>), <<Context Name>>)`
`@context <<Context Name>> assignMixin(<<Type>> => <<Mixin Name>>(<<Mixin Attributes>>))`
Assigns a Mixin <<Mixin Name>> to a <<Type>> in the context <<Context Name>>

`disassignMixin(<<Type>> => <<Mixin Name>>(<<Mixin Attributes>>), <<Context Name>>)`
`@context <<Context Name>> disassignMixin(<<Type>> => <<Mixin Name>>(<<Mixin Attributes>>))`
Disassigns a Mixin <<Mixin Name>> to a <<Type>> in the context <<Context Name>>

`getContexts()`
Returns a list of all defined Contexts.

`getMixins()`
Returns a `Dict{Context, Dict{Any, Vector{DataType}}}` of all defined Mixins. E.g.: {<<Context Name 1>> => {<<Class Name 1>> => [<<Mixin 1>>], <<Class Name 2>> => [<<Mixin 2>>]}, <<Context Name 2>>=>{<<Class Name 1>> => [<<Mixin 3>>, <<Mixin 4>>]}}

`getMixins(<<Object Name>>)`
Returns a `Dict{Context, DataType}` for a specific object <<Object Name>>.

`getMixin(<<Object Name>>, <<Context Name>>)`
Returns the Mixin, that <<Object Name>> is playing in the context <<Context Name>>.

### Example

For an Example, look into `contextExample.jl`

### Contextual Petri Nets

to be added...