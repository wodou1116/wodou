local RuntimePresentation = {}

local TWO_PI = math.pi * 2
local ATTACK_PULSE_DURATION = 0.18

RuntimePresentation.WheelLayers = {
    { id = "outer", width = 103, height = 172, offsetX = 0, offsetY = 2, rotationPerSecond = 3, idleRpm = 0.5, opacity = 0.58 },
    { id = "marks", width = 103, height = 172, offsetX = 4, offsetY = 3, rotationPerSecond = -9, idleRpm = -1.5, opacity = 0.72 },
    { id = "middle", width = 97, height = 162, offsetX = 0, offsetY = 19, rotationPerSecond = 14, idleRpm = 14 / 6, opacity = 0.76 },
    { id = "inner", width = 95, height = 158, offsetX = -1, offsetY = 20, rotationPerSecond = -18, idleRpm = -3, opacity = 0.82 },
    { id = "core", width = 63, height = 105, offsetX = 4, offsetY = 13, rotationPerSecond = 9, idleRpm = 1.5, opacity = 0.90 },
}

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

function RuntimePresentation.Wheel(time, attackPulse)
    local result = {}
    local attackStrength = Clamp((attackPulse or 0) / ATTACK_PULSE_DURATION, 0, 1)
    for index, layer in ipairs(RuntimePresentation.WheelLayers) do
        local isCore = index == #RuntimePresentation.WheelLayers
        local speedMultiplier = 1 + attackStrength * (isCore and 1.4 or 0.65)
        local rotationSpeed = layer.rotationPerSecond * speedMultiplier
        result[index] = {
            id = layer.id,
            width = layer.width,
            height = layer.height,
            offsetX = layer.offsetX,
            offsetY = layer.offsetY,
            opacity = Clamp(layer.opacity + attackStrength * (isCore and 0.10 or 0.08), 0, 1),
            scale = 1 + attackStrength * (isCore and 0.16 or 0.05),
            rotation = math.fmod((time or 0) * rotationSpeed, 360),
            rotationSpeed = rotationSpeed,
            idleRpm = layer.idleRpm,
            coreGlow = isCore and attackStrength or 0,
            converge = 1 - attackStrength,
        }
    end
    return result
end

return RuntimePresentation
