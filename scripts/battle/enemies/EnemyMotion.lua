local Enemies = require("data.Enemies")

local EnemyMotion = {}

local function Clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function Normalize(x, y)
    local length = math.sqrt(x * x + y * y)
    if length <= 0.0001 then
        return 0, 0, 0
    end
    return x / length, y / length, length
end

local function FacingFor(motion, vx, fallbackX, threshold)
    local facingX = motion.facingX
    if math.abs(vx) > (threshold or 0.0001) then
        facingX = vx >= 0 and 1 or -1
    elseif not facingX then
        facingX = fallbackX >= 0 and 1 or -1
    end
    motion.facingX = facingX
    return facingX == 1 and "right" or "left", facingX
end

function EnemyMotion.New(enemyId, seed)
    local config = Enemies.Get(enemyId)
    assert(config, "unknown enemy motion: " .. tostring(enemyId))

    return {
        enemyId = enemyId,
        phase = (seed or 0) % (math.pi * 2),
        orbitDirection = (seed or 0) % 2 == 0 and 1 or -1,
    }
end

-- Returns a frame command; this function does not mutate the enemy or target tables.
-- The caller owns motion state and writes the fields it needs back to its entity.
function EnemyMotion.Step(motion, enemy, target, timeStep)
    assert(motion and motion.enemyId, "motion state is required")
    assert(enemy and target, "enemy and target are required")

    local config = Enemies.Get(motion.enemyId)
    assert(config, "unknown enemy motion: " .. tostring(motion.enemyId))

    local rule = config.motion
    local targetX = target.x or 0
    local targetY = target.y or 0
    local enemyX = enemy.x or 0
    local enemyY = enemy.y or 0
    local dt = timeStep or 0
    local towardX, towardY, distance = Normalize(targetX - enemyX, targetY - enemyY)
    local tangentX = -towardY * motion.orbitDirection
    local tangentY = towardX * motion.orbitDirection
    local moveX, moveY, motionState

    motion.phase = motion.phase + dt * (rule.visualRate or rule.turnRate or 0)

    if rule.archetype == "orbit" then
        local radialWeight = distance > rule.preferredDistance and rule.approachWeight or 0
        local turnWeight = rule.orbitWeight * (1 + math.sin(motion.phase) * (rule.turnPulse or 0))
        moveX, moveY = Normalize(
            towardX * radialWeight + tangentX * turnWeight,
            towardY * radialWeight + tangentY * turnWeight
        )
        motionState = distance > rule.preferredDistance and "approach_orbit" or "orbit"
    elseif rule.archetype == "glide" then
        local radialWeight = 0
        if distance > rule.preferredDistance + rule.distanceBand then
            radialWeight = 1
            motionState = "close"
        elseif distance < rule.preferredDistance - rule.distanceBand then
            radialWeight = -1
            motionState = "retreat"
        else
            motionState = "glide"
        end

        local drift = math.sin(motion.phase) * rule.driftWeight
        moveX, moveY = Normalize(
            towardX * radialWeight + tangentX * drift,
            towardY * radialWeight + tangentY * drift
        )
    else
        moveX, moveY = towardX, towardY
        motionState = "press"
    end

    local speed = rule.speed or enemy.speed or 0
    local vx = moveX * speed
    local vy = moveY * speed
    local facing, facingX = FacingFor(motion, vx, targetX - enemyX, rule.facingThreshold)
    local step = 0.5 + math.sin(motion.phase * (rule.stepRate or 1)) * 0.5
    local elevation = (rule.elevation or 0) + math.sin(motion.phase) * (rule.hoverAmplitude or 0)
    local lean = Clamp(moveX * (rule.leanMax or 0), -(rule.leanMax or 0), rule.leanMax or 0)
    return {
        x = enemyX + vx * dt,
        y = enemyY + vy * dt,
        vx = vx,
        vy = vy,
        facing = facing,
        facingX = facingX,
        motionState = motionState,
        distance = distance,
        elevation = elevation,
        step = step,
        lean = lean,
    }
end

return EnemyMotion
