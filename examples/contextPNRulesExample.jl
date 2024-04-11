include("../src/Contexts.jl")
using .Contexts

@newContext BatteryFull
@newContext BatteryCharging
@newContext BatteryHigh
@newContext BatteryLow
@newContext EnergySaving
@newContext PowerMode
@newContext BatteryEmpty
@newContext BatteryDischarging

for c in getContexts()
	activateContext(c)
end

# Activating BatteryFull will deactivate BatteryCharging
directedExclusion(BatteryFull => BatteryCharging)
directedExclusion(BatteryEmpty => BatteryDischarging)
directedExclusion(BatteryEmpty => BatteryLow)
directedExclusion(BatteryDischarging => BatteryFull)
directedExclusion(BatteryCharging => BatteryEmpty)

@newContext BatteryIdle

weakExclusion(BatteryIdle, BatteryDischarging)
weakExclusion(BatteryCharging, BatteryIdle)
weakExclusion(BatteryDischarging, BatteryCharging)


# BatteryIdle can not be activated when BatteryDischarging is active
# and BatteryDischarging can not be activated when BatteryIdle is active
exclusion(BatteryEmpty, BatteryFull)
exclusion(BatteryFull, BatteryLow)
exclusion(BatteryEmpty, BatteryLow)
exclusion(BatteryFull, BatteryHigh)
exclusion(BatteryEmpty, BatteryHigh)
exclusion(BatteryHigh, BatteryLow)


# If BatteryLow get activated, EnergySaving Mode will be activated too
# Deactivation of EnergySaving will cont deactivate energy low
# Energy saving can be activated independently from BatteryLow
weakInclusion(BatteryLow => EnergySaving)


# PowerMode can only be active if battery is high or full
requirement(PowerMode => (BatteryHigh | BatteryFull))


deactivateAllContexts()

# Demonstration of requirement
activateContext(PowerMode)
println("___1____: ", getActiveContexts())
activateContext(BatteryHigh)
activateContext(PowerMode)
println("___2____: ", getActiveContexts())
deactivateContext(BatteryHigh)
activateContext(BatteryFull)
activateContext(PowerMode)
println("___3____: ", getActiveContexts())
deactivateContext(BatteryFull)
println("___4____: ", getActiveContexts())

deactivateAllContexts()
println()

# Demonstration of weak exclusion and directed exclusion
println("___1____: ", getActiveContexts())
activateContext(BatteryCharging)
println("___2____: ", getActiveContexts())
activateContext(BatteryIdle)
println("___3____: ", getActiveContexts())
activateContext(BatteryDischarging)
println("___4____: ", getActiveContexts())
deactivateContext(BatteryIdle)
println("___5____: ", getActiveContexts())
activateContext(BatteryDischarging)
println("___6____: ", getActiveContexts())
activateContext(BatteryEmpty)
println("___7____: ", getActiveContexts())
activateContext(BatteryDischarging)
println("___8____: ", getActiveContexts())
activateContext(BatteryLow)
println("___9____: ", getActiveContexts())
deactivateContext(BatteryEmpty)
# demonstration of weak inclusion
activateContext(BatteryLow)
println("___10___: ", getActiveContexts())
deactivateContext(EnergySaving)
println("___11___: ", getActiveContexts())
deactivateContext(BatteryLow)
println("___12___: ", getActiveContexts())
activateContext(EnergySaving)
println("___13___: ", getActiveContexts())


println()

# Example for behavior when conflicting rules are defined
@newContext C1
@newContext C2
@newContext C3

directedExclusion(C1 => C2)
exclusion(C1, C2)
exclusion(C1, C3)
weakInclusion(C1 => C3)

deactivateAllContexts()

activateContext(C2)
println("___1____: ", getActiveContexts())
activateContext(C1)
println("___2____: ", getActiveContexts())
activateContext(C1)
println("___3____: ", getActiveContexts())