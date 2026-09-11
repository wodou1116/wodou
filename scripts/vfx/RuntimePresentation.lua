local RuntimePresentation = {}

local TWO_PI = math.pi * 2
local ATTACK_PULSE_DURATION = 0.18
local WHEEL_REFERENCE_DIAMETER = 118
local WHEEL_ASPECT_RATIO = 724 / 434

RuntimePresentation.WheelLayers = {
    { id = "outer", diameterRatio = 1.00, offsetX = 0, offsetY = 2, rotationPerSecond = 3, idleRpm = 0.5, opacity = 0.58 },
    { id = "marks", diameterRatio = 1.00, offsetX = 4, offsetY = 3, rotationPerSecond = -9, idleRpm = -1.5, opacity = 0.72 },
    { id = "middle", diameterRatio = 0.94, offsetX = 0, offsetY = 19, rotationPerSecond = 14, idleRpm = 14 / 6, opacity = 0.76 },
    { id = "inner", diameterRatio = 0.92, offsetX = -1, offsetY = 20, rotationPerSecond = -18, idleRpm = -3, opacity = 0.82 },
    { id = "core", diameterRatio = 0.61, offsetX = 4, offsetY = 13, rotationPerSecond = 9, idleRpm = 1.5, opacity = 0.90 },
}

for _, layer in ipairs(RuntimePresentation.WheelLayers) do
    layer.width = WHEEL_REFERENCE_DIAMETER * layer.diameterRatio
    layer.height = layer.width * WHEEL_ASPECT_RATIO
end

local ENEMY_MOTION = {
    bifang = { bobAmplitude = 4, bobFrequency = 3.5, swayDegrees = 4.0, swayFrequency = 3.0, elevation = 0.72, elevationOffset = -18 },
    jiuweihu = { bobAmplitude = 3, bobFrequency = 3.0, swayDegrees = 3.0, swayFrequency = 2.2, elevation = 0.08, elevationOffset = -3 },
    kui = { bobAmplitude = 2, bobFrequency = 2.2, swayDegrees = 2.0, swayFrequency = 1.8, elevation = 0, elevationOffset = 0 },
    spring_elite = { bobAmplitude = 3, bobFrequency = 2.0, swayDegrees = 2.5, swayFrequency = 1.6, elevation = 0.08, elevationOffset = -3 },
    jumang = { bobAmplitude = 4, bobFrequency = 1.5, swayDegrees = 1.5, swayFrequency = 1.2, elevation = 0.16, elevationOffset = -5 },
}

local DEFAULT_ENEMY_MOTION = {
    bobAmplitude = 2,
    bobFrequency = 2,
    swayDegrees = 2,
    swayFrequency = 2,
    elevation = 0,
    elevationOffset = 0,
}

local function Pulse(time, frequency, phase)
    return math.sin((time * frequency + (phase or 0)) * TWO_PI)
end

local function Clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

function RuntimePresentation.Player(time, isMoving, state, stateElapsed, duration)
    local resolvedState = state and string.lower(state) or (isMoving and "move" or "idle")
    local moving = resolvedState == "move"
    local breath = Pulse(time or 0, moving and 2.6 or 1.7)
    local visual = {
        state = resolvedState,
        offsetY = breath * (moving and 1.5 or 2.5),
        rotation = breath * (moving and 2.0 or 1.1),
        scaleX = 1 + breath * 0.008,
        scaleY = 1 - breath * 0.012,
        scale = 1,
        opacity = 1,
        flashWhite = 0,
        complete = false,
    }

    if resolvedState == "hit" then
        local hit = RuntimePresentation.Hit(stateElapsed, duration)
        visual.scale = hit.scale
        visual.flashWhite = hit.flashWhite
    elseif resolvedState == "death" then
        local death = RuntimePresentation.Death(stateElapsed, duration)
        visual.offsetY = visual.offsetY + death.offsetY
        visual.scale = death.scale
        visual.opacity = death.opacity
        visual.complete = death.complete
    end

    return visual
end

function RuntimePresentation.Enemy(kind, time, phase)
    local motion = ENEMY_MOTION[kind] or DEFAULT_ENEMY_MOTION
    local bob = Pulse(time or 0, motion.bobFrequency, phase) * motion.bobAmplitude
    local lean = Pulse(time or 0, motion.swayFrequency, phase) * motion.swayDegrees
    return {
        bob = bob,
        lean = lean,
        elevation = motion.elevation,
        elevationOffset = motion.elevationOffset,
        offsetY = motion.elevationOffset + bob,
        rotation = lean,
    }
end

function RuntimePresentation.Shadow(entitySize, elevation)
    local size = entitySize or 100
    local height = Clamp(elevation or 0, 0, 1)
    return {
        width = size * (0.68 - height * 0.16),
        height = size * (0.20 - height * 0.04),
        offsetY = size * 0.34 + height * size * 0.05,
        opacity = 0.32 - height * 0.12,
        anchorX = 0.5,
        anchorY = 0.5,
    }
end

function RuntimePresentation.EnemyShadow(kind, entitySize, time, phase)
    local enemy = RuntimePresentation.Enemy(kind, time, phase)
    local shadow = RuntimePresentation.Shadow(entitySize, enemy.elevation)
    shadow.elevation = enemy.elevation
    shadow.offsetY = shadow.offsetY - enemy.elevationOffset
    return shadow
end

function RuntimePresentation.Hit(elapsed, duration)
    local resolvedDuration = duration or 0.16
    local progress = Clamp((elapsed or 0) / resolvedDuration, 0, 1)
    local flash = 1 - progress
    return {
        flashWhite = flash,
        scale = 1 + math.sin(progress * math.pi) * 0.10,
    }
end

function RuntimePresentation.Death(elapsed, duration)
    local resolvedDuration = duration or 0.32
    local progress = Clamp((elapsed or 0) / resolvedDuration, 0, 1)
    return {
        opacity = 1 - progress,
        scale = 1 - progress * 0.18,
        offsetY = -progress * 12,
        complete = progress >= 1,
    }
end

function RuntimePresentation.WheelAnchor(playerX, playerY, playerWidth, playerHeight, facing)
    local width = playerWidth or 138
    local height = playerHeight or 190
    local backward = facing == "left" and 1 or -1
    local diameter = Clamp(height * 0.62, height * 0.55, height * 0.70)
    return {
        centerX = (playerX or 0) + backward * width * 0.18,
        centerY = (playerY or 0) - height * 0.64,
        diameter = diameter,
    }
end

function RuntimePresentation.Wheel(time, attackPulse, state, diameter)
    local result = {}
    local resolvedState = state and string.lower(state) or ((attackPulse or 0) > 0 and "attack" or "idle")
    local attackStrength = resolvedState == "attack" and Clamp((attackPulse or 0) / ATTACK_PULSE_DURATION, 0, 1) or 0
    local attackProgress = 1 - attackStrength
    local lockStrength = resolvedState == "attack" and Clamp(1 - attackProgress / 0.22, 0, 1) or 0
    local alignmentBoost = resolvedState == "attack" and math.sin(attackProgress * math.pi) or 0
    local rebound = resolvedState == "attack" and math.sin(attackProgress * math.pi) * 0.08 or 0
    local chargedStrength = resolvedState == "charged" and 1 or 0
    local layoutScale = (diameter or WHEEL_REFERENCE_DIAMETER) / WHEEL_REFERENCE_DIAMETER
    for index, layer in ipairs(RuntimePresentation.WheelLayers) do
        local isCore = index == #RuntimePresentation.WheelLayers
        local speedMultiplier = 1 + alignmentBoost * (isCore and 1.35 or 0.72) + chargedStrength * (isCore and 0.42 or 0.18)
        speedMultiplier = speedMultiplier * (1 - lockStrength * 0.86)
        local rotationSpeed = layer.rotationPerSecond * speedMultiplier
        local baseRotation = (time or 0) * rotationSpeed
        local lockedRotation = math.floor((baseRotation + 22.5) / 45) * 45
        local rotation = baseRotation * (1 - lockStrength) + lockedRotation * lockStrength
        local marksStrength = layer.id == "marks" and chargedStrength * (0.18 + math.abs(Pulse(time or 0, 1.2)) * 0.12) or 0
        local layerStrength = attackStrength + chargedStrength
        result[index] = {
            id = layer.id,
            state = resolvedState,
            width = layer.width * layoutScale,
            height = layer.height * layoutScale,
            offsetX = layer.offsetX * layoutScale,
            offsetY = layer.offsetY * layoutScale,
            opacity = Clamp(layer.opacity + attackStrength * (isCore and 0.10 or 0.06) + chargedStrength * (isCore and 0.10 or 0.08) + marksStrength, 0, 1),
            scale = 1 + rebound + layerStrength * (isCore and 0.16 or 0.05) + chargedStrength * (isCore and 0.05 or 0.03),
            rotation = math.fmod(rotation, 360),
            rotationSpeed = rotationSpeed,
            idleRpm = layer.idleRpm,
            coreGlow = isCore and Clamp(attackStrength + chargedStrength, 0, 1) or 0,
            converge = 1 - attackStrength,
            locked = lockStrength > 0,
            rebound = rebound,
        }
    end
    return result
end

return RuntimePresentation
