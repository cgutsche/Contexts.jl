using Pkg
using Plots, Parameters
using OrdinaryDiffEq, ModelingToolkit
using ModelingToolkitStandardLibrary.Electrical
using ModelingToolkitStandardLibrary.Blocks

include("../src/Contexts.jl")
using .Contexts


@newContext Day
@newContext Night

@newContext BatteryLow

weakExclusion(Day, Night)

activateContext(Day)
activateContext(BatteryLow)

println("Active Contexts: ", getActiveContexts())


function dayNightSwitch!(integ, u, p, ctx)
    if isActive(Day)
        activateContext(Night)
    else
        activateContext(Day)
    end
    terminate!(integ)
end


function BatteryLowSwitch!(integ, u, p, ctx)
    if isActive(BatteryLow)
        deactivateContext(BatteryLow)
    else
        activateContext(BatteryLow)
        terminate!(integ)
    end
end

@variables t
D = Differential(t)

@mtkmodel DayModel begin
    @components begin
        capacitor = Capacitor(C = 1)
        ground = Ground()
        resistor = Resistor(R = 5)
        intResistor = Resistor(R = 1)
        source = Voltage()
        voltage = Constant(k = 10)
    end
    @variables begin
        v_pos(t) = 1, [irreducible=true]
        dummyTime(t) = 0
    end
    @equations begin
        D(dummyTime) ~ 1
        v_pos ~ abs(capacitor.v)
        connect(voltage.output, source.V)
        connect(ground.g, source.p)
        connect(capacitor.p, source.p)
        connect(capacitor.n, intResistor.p)
        connect(resistor.p, source.p)
        connect(resistor.n, source.n)
        connect(intResistor.n, source.n)
    end
    @continuous_events begin
        [t ~ 12, t ~ 36] => (dayNightSwitch!, [], [], [])
        [v_pos ~  3] => (BatteryLowSwitch!, [], [], [])
    end
end
@mtkbuild dayModel = DayModel()

@mtkmodel NightModel begin
    @components begin
        capacitor = Capacitor(C = 1)
        ground = Ground()
        resistor = Resistor(R = 5)
        intResistor = Resistor(R = 1)
    end
    @variables begin
        v_pos(t) = 1, [irreducible=true]
    end
    @equations begin
        v_pos ~ abs(capacitor.v)
        connect(ground.g, resistor.p)
        connect(capacitor.n, intResistor.p)
        connect(intResistor.n, resistor.p)
        connect(capacitor.p, resistor.n)
    end
    @continuous_events begin
        [t ~ 24] => (dayNightSwitch!, [], [], [])
        [v_pos ~  3] => (BatteryLowSwitch!, [], [], [])
    end
end
@mtkbuild nightModel = NightModel()


@mtkmodel NightModelLowPower begin
    @components begin
        capacitor = Capacitor(C = 1)
        ground = Ground()
        resistor = Resistor(R = 50)
        intResistor = Resistor(R = 1)
    end
    @variables begin
        v_pos(t) = 1, [irreducible=true]
    end
    @equations begin
        v_pos ~ abs(capacitor.v)
        connect(ground.g, resistor.p)
        connect(capacitor.n, intResistor.p)
        connect(intResistor.n, resistor.p)
        connect(capacitor.p, resistor.n)
    end
    @continuous_events begin
        [t ~ 24] => (dayNightSwitch!, [], [], [])
    end
end
@mtkbuild nightModelLowPower = NightModelLowPower()

println("Starting Simulation")

t_max = 45.0

prob = ODEProblem(dayModel, [], (0, t_max))
sol_temp = solve(prob, FBDF())

t_end = sol_temp[t, end]
solutions::Vector{ODESolution} = [sol_temp]
while true
    println("Active Contexts: ", getActiveContexts())
    if isActive(Day)
        local prob = ODEProblem(dayModel, [dayModel.capacitor.v => sol_temp[sol_temp.prob.f.sys.capacitor.v][end]], (t_end, t_max))
        global sol_temp = solve(prob, FBDF())
    elseif isActive(Night & !BatteryLow)
        local prob = ODEProblem(nightModel, [nightModel.capacitor.v => sol_temp[sol_temp.prob.f.sys.capacitor.v][end]], (t_end, t_max))
        global sol_temp = solve(prob, FBDF())
    elseif isActive(Night & BatteryLow)
        local prob = ODEProblem(nightModelLowPower, [nightModelLowPower.capacitor.v => sol_temp[sol_temp.prob.f.sys.capacitor.v][end]], (t_end, t_max))
        global sol_temp = solve(prob, FBDF())
    end

    global t_end = sol_temp[t, end]
    push!(solutions, sol_temp)
    if t_end == t_max
        break
    end
end

labels=["Day", "Night", "Night & BatteryLow"]
colors=["orange", "darkblue", "green", "orange", "darkblue", "green"]
p = plot(solutions[1], idxs = [solutions[1].prob.f.sys.capacitor.v], label=labels[1], lc=colors[1], legendtitle = "Active Contexts")
for i in 2:length(solutions)
    if i < 4
        p = plot!(solutions[i], idxs = [solutions[i].prob.f.sys.capacitor.v], label=labels[i], lc=colors[i])
    else
        p = plot!(solutions[i], idxs = [solutions[i].prob.f.sys.capacitor.v], primary=false, lc=colors[i])
    end
end

xlims!(0, t_max)
xlabel!("Time [h]")
ylabel!("Capacitor Voltage [V]")
display(p)
savefig(p, "VoltageContexts.pdf")
readline()

