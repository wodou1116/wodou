local MovementAI = {}

local function MoveToward(current, target, maximumDelta)
    if current < target then
        return math.min(current + maximumDelta, target)
    end
    return math.max(current - maximumDelta, target)
end

local function Normalize(x, y)
    local length = math.sqrt(x * x + y * y)
    if length <= 0.0001 then
        return 0, 0
    end
    return x / length, y / length
end

function MovementAI.New(strategy, options)
    assert(type(strategy) == "function", "movement strategy must be a function")
    options = options or {}
    return {
        strategy = strategy,
        velocityX = 0,
        velocityY = 0,
        acceleration = options.acceleration or math.huge,
        deceleration = options.deceleration or options.acceleration or math.huge,
        state = "idle",
    }
end

function MovementAI.Step(controller, entity, target, timeStep, context)
    assert(controller and controller.strategy, "movement controller is required")
    assert(entity, "movement entity is required")
    local dt = timeStep or 0
    local intent = controller.strategy(controller, entity, target, dt, context) or {}
    local directionX, directionY = Normalize(intent.directionX or 0, intent.directionY or 0)
    local desiredX = directionX * (intent.speed or 0)
    local desiredY = directionY * (intent.speed or 0)
    local stopping = desiredX == 0 and desiredY == 0
    local rate = stopping and controller.deceleration or controller.acceleration
    local maximumDelta = rate == math.huge and math.huge or rate * dt
    controller.velocityX = MoveToward(controller.velocityX, desiredX, maximumDelta)
    controller.velocityY = MoveToward(controller.velocityY, desiredY, maximumDelta)
    controller.state = intent.state or (stopping and "idle" or "move")

    entity.x = (entity.x or 0) + controller.velocityX * dt
    entity.y = (entity.y or 0) + controller.velocityY * dt
    return {
        x = entity.x,
        y = entity.y,
        vx = controller.velocityX,
        vy = controller.velocityY,
        state = controller.state,
        attack = intent.attack,
        metadata = intent.metadata,
    }
end

return MovementAI
