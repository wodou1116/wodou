local AnimationState = {}
AnimationState.__index = AnimationState

AnimationState.States = {
    Idle = "Idle",
    Move = "Move",
    Hit = "Hit",
    Death = "Death",
}

AnimationState.Priority = {
    [AnimationState.States.Idle] = 1,
    [AnimationState.States.Move] = 2,
    [AnimationState.States.Hit] = 3,
    [AnimationState.States.Death] = 4,
}

local VALID_STATES = {
    [AnimationState.States.Idle] = true,
    [AnimationState.States.Move] = true,
    [AnimationState.States.Hit] = true,
    [AnimationState.States.Death] = true,
}

function AnimationState.New(options)
    options = options or {}
    return setmetatable({
        state = AnimationState.States.Idle,
        time = 0,
        hitDuration = options.hitDuration or 0.16,
    }, AnimationState)
end

function AnimationState:Get()
    return self.state
end

function AnimationState:Set(state)
    assert(VALID_STATES[state], "unknown animation state: " .. tostring(state))
    if self.state == AnimationState.States.Death and state ~= AnimationState.States.Death then
        return self.state
    end
    if self.state ~= state then
        self.state = state
        self.time = 0
    end
    return self.state
end

function AnimationState:Hit(duration)
    if self.state ~= AnimationState.States.Death then
        self.hitDuration = duration or self.hitDuration
        self.state = AnimationState.States.Hit
        self.time = 0
    end
    return self.state
end

function AnimationState:Die()
    return self:Set(AnimationState.States.Death)
end

function AnimationState:Update(timeStep, isMoving)
    assert(timeStep >= 0, "timeStep must be non-negative")
    self.time = self.time + timeStep
    if self.state == AnimationState.States.Death then
        return self.state
    end
    if self.state == AnimationState.States.Hit and self.time < self.hitDuration then
        return self.state
    end
    return self:Set(isMoving and AnimationState.States.Move or AnimationState.States.Idle)
end

return AnimationState
