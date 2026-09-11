local AttackLogic = {}

function AttackLogic.New(interval, initialDelay)
    assert(type(interval) == "number" and interval > 0, "attack interval must be positive")
    return {
        interval = interval,
        cooldown = initialDelay == nil and interval or math.max(0, initialDelay),
    }
end

function AttackLogic.Step(state, timeStep, canAttack, perform)
    assert(state and state.interval, "attack state is required")
    state.cooldown = math.max(0, state.cooldown - (timeStep or 0))
    if state.cooldown > 0.000001 or not canAttack then
        return false
    end
    if perform and perform() == false then
        return false
    end
    state.cooldown = state.interval
    return true
end

function AttackLogic.SetInterval(state, interval)
    assert(type(interval) == "number" and interval > 0, "attack interval must be positive")
    state.interval = interval
    state.cooldown = math.min(state.cooldown, interval)
end

return AttackLogic
