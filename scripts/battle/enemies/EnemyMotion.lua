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

local function Approach(current, target, maximumDelta)
    if current < target then
        return math.min(current + maximumDelta, target)
    end
    return math.max(current - maximumDelta, target)
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
        actionTime = 0,
        attackCooldown = config.motion.attackInitialCooldown or 0,
        velocityX = 0,
        velocityY = 0,
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
    local moveX, moveY, motionState, keyframe, attackIntent

    motion.phase = motion.phase + dt * (rule.visualRate or rule.turnRate or 0)

    if rule.archetype == "orbit" then
        local cycleLength = rule.dashDelay + rule.dashDuration + rule.retreatDuration
        motion.actionTime = (motion.actionTime + dt) % cycleLength
        if motion.actionTime < rule.dashDelay then
            local radialWeight = distance > rule.preferredDistance and rule.approachWeight or 0
            local turnWeight = rule.orbitWeight * (1 + math.sin(motion.phase) * (rule.turnPulse or 0))
            moveX, moveY = Normalize(
                towardX * radialWeight + tangentX * turnWeight,
                towardY * radialWeight + tangentY * turnWeight
            )
            motionState = distance > rule.preferredDistance and "approach_orbit" or "orbit"
            keyframe = "orbit"
        elseif motion.actionTime < rule.dashDelay + rule.dashDuration then
            moveX, moveY = Normalize(
                towardX + tangentX * rule.dashOrbitWeight,
                towardY + tangentY * rule.dashOrbitWeight
            )
            motionState = "dash"
            keyframe = "dash"
        else
            moveX, moveY = Normalize(
                -towardX + tangentX * rule.retreatOrbitWeight,
                -towardY + tangentY * rule.retreatOrbitWeight
            )
            motionState = "retreat"
            keyframe = "retreat"
        end
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

        if motionState == "glide" then
            motion.attackCooldown = math.max(0, motion.attackCooldown - dt)
            if motion.attackCooldown == 0 then
                motionState = "ranged_attack"
                keyframe = "ranged_attack"
                attackIntent = {
                    type = "ranged",
                    targetX = targetX,
                    targetY = targetY,
                    range = rule.attackRange,
                    projectileSpeed = rule.projectileSpeed,
                }
                motion.attackCooldown = rule.attackCooldown
            else
                keyframe = "hover"
            end
        else
            keyframe = motionState
        end
    else
        motion.attackCooldown = math.max(0, motion.attackCooldown - dt)
        if distance <= rule.meleeRange then
            moveX, moveY = 0, 0
            motion.velocityX = Approach(motion.velocityX, 0, rule.stopAcceleration * dt)
            motion.velocityY = Approach(motion.velocityY, 0, rule.stopAcceleration * dt)
            motionState = "melee_attack"
            keyframe = "melee_attack"
            if motion.attackCooldown == 0 then
                attackIntent = {
                    type = "melee",
                    targetX = targetX,
                    targetY = targetY,
                    range = rule.meleeRange,
                }
                motion.attackCooldown = rule.attackCooldown
            end
        else
            moveX, moveY = towardX, towardY
            motion.velocityX = Approach(motion.velocityX, towardX * rule.speed, rule.acceleration * dt)
            motion.velocityY = Approach(motion.velocityY, towardY * rule.speed, rule.acceleration * dt)
            motionState = "press"
            keyframe = "press"
        end
    end

    local speed = rule.speed or enemy.speed or 0
    local vx = moveX * speed
    local vy = moveY * speed
    if rule.archetype == "orbit" then
        if keyframe == "dash" then
            vx = moveX * rule.dashSpeed
            vy = moveY * rule.dashSpeed
        elseif keyframe == "retreat" then
            vx = moveX * rule.retreatSpeed
            vy = moveY * rule.retreatSpeed
        end
    elseif rule.archetype == "press" then
        vx = motion.velocityX
        vy = motion.velocityY
        moveX, moveY = Normalize(vx, vy)
    end
    local facing, facingX = FacingFor(motion, vx, targetX - enemyX, rule.facingThreshold)
    local step = 0.5 + math.sin(motion.phase * (rule.stepRate or 1)) * 0.5
    local elevation = (rule.elevation or 0) + math.sin(motion.phase) * (rule.hoverAmplitude or 0)
    local lean = Clamp(moveX * (rule.leanMax or 0), -(rule.leanMax or 0), rule.leanMax or 0)
    local nextX = enemyX + vx * dt
    local nextY = enemyY + vy * dt
    return {
        x = nextX,
        y = nextY,
        vx = vx,
        vy = vy,
        facing = facing,
        facingX = facingX,
        motionState = motionState,
        keyframe = keyframe,
        distance = distance,
        elevation = elevation,
        step = step,
        lean = lean,
        movementIntent = {
            x = nextX,
            y = nextY,
            vx = vx,
            vy = vy,
            state = motionState,
            keyframe = keyframe,
        },
        attackIntent = attackIntent,
    }
end

return EnemyMotion
