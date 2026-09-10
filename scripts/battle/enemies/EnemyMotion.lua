local Enemies = require("data.Enemies")

local EnemyMotion = {}

local function Normalize(x, y)
    local length = math.sqrt(x * x + y * y)
    if length <= 0.0001 then
        return 0, 0, 0
    end
    return x / length, y / length, length
end

local function FacingFor(vx, fallbackX)
    if math.abs(vx) > 0.0001 then
        return vx >= 0 and "right" or "left"
    end
    return fallbackX >= 0 and "right" or "left"
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
-- The caller owns motion state and writes x/y/facing/motionState back to its entity.
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
    local towardX, towardY, distance = Normalize(targetX - enemyX, targetY - enemyY)
    local tangentX = -towardY * motion.orbitDirection
    local tangentY = towardX * motion.orbitDirection
    local moveX, moveY, motionState

    motion.phase = motion.phase + (timeStep or 0) * rule.turnRate

    if rule.archetype == "orbit" then
        local radialWeight = distance > rule.preferredDistance and rule.approachWeight or 0
        moveX, moveY = Normalize(
            towardX * radialWeight + tangentX * rule.orbitWeight,
            towardY * radialWeight + tangentY * rule.orbitWeight
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
    return {
        x = enemyX + vx * timeStep,
        y = enemyY + vy * timeStep,
        vx = vx,
        vy = vy,
        facing = FacingFor(vx, targetX - enemyX),
        motionState = motionState,
        distance = distance,
    }
end

return EnemyMotion
