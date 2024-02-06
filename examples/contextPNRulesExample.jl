include("../src/Contexts.jl")
using .Contexts

@newContext BatteryFull
@newContext BatteryCharging
@newContext BatteryLow
@newContext EnergySaving
@newContext BatteryEmpty
@newContext BatteryDischarging

directedExclusion(BatteryFull => BatteryCharging)
directedExclusion(BatteryEmpty => BatteryDischarging)
directedExclusion(BatteryEmpty => BatteryLow)
directedExclusion(BatteryDischarging => BatteryFull)
directedExclusion(BatteryCharging => BatteryEmpty)
weakInclusion(BatteryLow => EnergySaving)

@newContext BatteryIdle

exclusion(BatteryFull, BatteryDischarging)
exclusion(BatteryEmpty, BatteryCharging)
exclusion(BatteryEmpty, BatteryFull)
exclusion(BatteryDischarging, BatteryCharging)
exclusion(BatteryFull, BatteryLow)
exclusion(BatteryEmpty, BatteryLow)
exclusion(BatteryIdle, BatteryDischarging)
exclusion(BatteryIdle, BatteryCharging)

deactivateAllContexts()

println("___1____: ", getActiveContexts())
activateContext(BatteryCharging)
println("___2____: ", getActiveContexts())
activateContext(BatteryIdle)
println("___3____: ", getActiveContexts())
deactivateContext(BatteryCharging)
println("___4____: ", getActiveContexts())
activateContext(BatteryIdle)
println("___5____: ", getActiveContexts())
activateContext(BatteryDischarging)
println("___6____: ", getActiveContexts())
deactivateContext(BatteryIdle)
println("___7____: ", getActiveContexts())
activateContext(BatteryDischarging)
println("___8____: ", getActiveContexts())
activateContext(BatteryEmpty)
println("___9____: ", getActiveContexts())
activateContext(BatteryDischarging)
println("___10___: ", getActiveContexts())
deactivateContext(BatteryEmpty)
activateContext(BatteryLow)
println("___11___: ", getActiveContexts())
deactivateContext(EnergySaving)
println("___12___: ", getActiveContexts())
deactivateContext(BatteryLow)
println("___13___: ", getActiveContexts())
activateContext(EnergySaving)
println("___14___: ", getActiveContexts())