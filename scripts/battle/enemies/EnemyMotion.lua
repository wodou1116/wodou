local Enemies = require("data.Enemies")
local AttackLogic = require("combat.AttackLogic")
local MovementAI = require("combat.MovementAI")

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

local function EffectiveSpeed(enemy, config)
    if enemy.statSystem and type(enemy.statSystem.Get) == "function" then
        return enemy.statSystem:Get("speed", enemy.speed or 0)
    end
    return enemy.speed or (config.stats and config.stats.speed) or 0
end

local function MovementStrategy(_, _, _, _, context)
    return context.intent
end

function EnemyMotion.New(enemyId, seed)
    local config = Enemies.Get(enemyId)
    assert(config, "unknown enemy motion: " .. tostring(enemyId))
    local rule = config.motion
    local motion = {
        enemyId = enemyId,
        phase = (seed or 0) % (math.pi * 2),
        orbitDirection = (seed or 0) % 2 == 0 and 1 or -1,
        actionTime = 0,
    }
    motion.movement = MovementAI.New(MovementStrategy, {
        acceleration = rule.acceleration or math.huge,
        deceleration = rule.stopAcceleration or rule.acceleration or math.huge,
    })
    motion.attack = AttackLogic.New(rule.attackCooldown or 1, rule.attackInitialCooldown or 0)
    return motion
end

local function BuildMovementIntent(motion, rule, distance, towardX, towardY, tangentX, tangentY, speed, dt)
    local moveX, moveY, motionState, keyframe

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
            speed = speed * rule.dashSpeedMultiplier
            motionState = "dash"
            keyframe = "dash"
        else
            moveX, moveY = Normalize(
                -towardX + tangentX * rule.retreatOrbitWeight,
                -towardY + tangentY * rule.retreatOrbitWeight
            )
            speed = speed * rule.retreatSpeedMultiplier
            motionState = "retreat"
            keyframe = "retreat"
        end
    elseif rule.archetype == "glide" then
        local radialWeight = 0
        if distance > rule.preferredDistance + rule.distanceBand then
            radialWeight = 1
            motionState = "close"
            keyframe = "close"
        elseif distance < rule.preferredDistance - rule.distanceBand then
            radialWeight = -1
            motionState = "retreat"
            keyframe = "retreat"
        else
            motionState = "glide"
            keyframe = "hover"
        end
        local drift = math.sin(motion.phase) * rule.driftWeight
        moveX, moveY = Normalize(
            towardX * radialWeight + tangentX * drift,
            towardY * radialWeight + tangentY * drift
        )
    else
        if distance <= rule.meleeRange then
            moveX, moveY = 0, 0
            motionState = "melee_attack"
            keyframe = "melee_attack"
        else
            moveX, moveY = towardX, towardY
            motionState = "press"
            keyframe = "press"
        end
    end

    return {
        directionX = moveX,
        directionY = moveY,
        speed = speed,
        state = motionState,
        metadata = { keyframe = keyframe },
    }, keyframe
end

local function BuildAttackIntent(motion, rule, motionState, targetX, targetY, dt)
    local attackType = nil
    if rule.archetype == "orbit" and motionState == "dash" then
        attackType = "contact"
    elseif rule.archetype == "glide" and motionState == "glide" then
        attackType = "ranged"
    elseif rule.archetype == "press" and motionState == "melee_attack" then
        attackType = "melee"
    end

    if not attackType then
        return nil
    end
    AttackLogic.SetInterval(motion.attack, rule.attackCooldown or 1)
    local fired = false
    AttackLogic.Step(motion.attack, dt, true, function()
        fired = true
    end)
    if not fired then
        return nil
    end

    local intent = {
        type = attackType,
        targetX = targetX,
        targetY = targetY,
    }
    if attackType == "ranged" then
        intent.range = rule.attackRange
        intent.projectileSpeed = rule.projectileSpeed
    elseif attackType == "melee" then
        intent.range = rule.meleeRange
    end
    return intent
end

-- Pure with respect to enemy and target. Stateful AI lives only in motion.
function EnemyMotion.Step(motion, enemy, target, timeStep)
    assert(motion and motion.enemyId, "motion state is required")
    assert(enemy and target, "enemy and target are required")

    local config = Enemies.Get(motion.enemyId)
    assert(config, "unknown enemy motion: " .. tostring(motion.enemyId))
    local rule = config.motion
    local dt = timeStep or 0
    local targetX = target.x or 0
    local targetY = target.y or 0
    local enemyX = enemy.x or 0
    local enemyY = enemy.y or 0
    local towardX, towardY, distance = Normalize(targetX - enemyX, targetY - enemyY)
    local tangentX = -towardY * motion.orbitDirection
    local tangentY = towardX * motion.orbitDirection
    local speed = EffectiveSpeed(enemy, config)

    motion.phase = motion.phase + dt * (rule.visualRate or rule.turnRate or 0)
    local intent, keyframe = BuildMovementIntent(
        motion, rule, distance, towardX, towardY, tangentX, tangentY, speed, dt
    )
    local pose = { x = enemyX, y = enemyY }
    local movement = MovementAI.Step(motion.movement, pose, target, dt, { intent = intent })
    local motionState = movement.state
    local attackIntent = BuildAttackIntent(motion, rule, motionState, targetX, targetY, dt)
    if attackIntent then
        if attackIntent.type == "ranged" then
            motionState = "ranged_attack"
            keyframe = motionState
        elseif attackIntent.type == "melee" then
            motionState = "melee_attack"
            keyframe = motionState
        end
    end

    local facing, facingX = FacingFor(motion, movement.vx, targetX - enemyX, rule.facingThreshold)
    local directionX = Normalize(movement.vx, movement.vy)
    local step = 0.5 + math.sin(motion.phase * (rule.stepRate or 1)) * 0.5
    local elevation = (rule.elevation or 0) + math.sin(motion.phase) * (rule.hoverAmplitude or 0)
    local lean = Clamp(directionX * (rule.leanMax or 0), -(rule.leanMax or 0), rule.leanMax or 0)
    movement.state = motionState
    movement.metadata.keyframe = keyframe

    return {
        x = movement.x,
        y = movement.y,
        vx = movement.vx,
        vy = movement.vy,
        facing = facing,
        facingX = facingX,
        motionState = motionState,
        keyframe = keyframe,
        distance = distance,
        elevation = elevation,
        step = step,
        lean = lean,
        movementIntent = movement,
        attackIntent = attackIntent,
    }
end

return EnemyMotion
