-- Pure simulation: the server owns this state, the HUD only observes it.
local Stamina = {}
function Stamina.new(config)
    return {value=config.MaxStamina, running=false, exhausted=false, rest=0}
end
function Stamina.step(state, wantsSprint, moving, allowed, dt, config)
    dt = math.max(0, dt)
    local running = allowed and wantsSprint and moving and not state.exhausted and state.value > 0
    if running then
        state.rest = 0
        state.value = math.max(0, state.value - config.DrainRate * dt)
        if state.value <= 0 then state.exhausted = true; running = false end
    else
        state.rest += dt
        if state.rest >= config.RegenDelay then
            state.value = math.min(config.MaxStamina, state.value + config.RegenRate * dt)
        end
        if state.exhausted and state.value >= config.RestartThreshold then state.exhausted = false end
    end
    state.running = running
    return state
end
return Stamina
