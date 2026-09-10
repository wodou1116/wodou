local RuntimePresentation = {}

local TWO_PI = math.pi * 2

RuntimePresentation.WheelLayers = {
    -- A-08 各层共享竖向画布但主体中心不同，offset 用于运行时聚合校准。
    { id = "outer", width = 104, height = 174, offsetX = 0, offsetY = 2, rotationPerSecond = 0, opacity = 0.58 },
    { id = "marks", width = 105, height = 175, offsetX = 4, offsetY = 3, rotationPerSecond = -10, opacity = 0.72 },
    { id = "middle", width = 98, height = 164, offsetX = 0, offsetY = 19, rotationPerSecond = 14, opacity = 0.76 },
    { id = "inner", width = 96, height = 160, offsetX = -1, offsetY = 20, rotationPerSecond = -18, opacity = 0.82 },
    { id = "core", width = 64, height = 107, offsetX = 4, offsetY = 13, rotationPerSecond = 9, opacity = 0.90 },
}

local ENEMY_MOTION = {
    bifang = { bobAmplitude = 4, bobFrequency = 3.5, swayDegrees = 4.0, swayFrequency = 3.0 },
    jiuweihu = { bobAmplitude = 3, bobFrequency = 3.0, swayDegrees = 3.0, swayFrequency = 2.2 },
    kui = { bobAmplitude = 2, bobFrequency = 2.2, swayDegrees = 2.0, swayFrequency = 1.8 },
    spring_elite = { bobAmplitude = 3, bobFrequency = 2.0, swayDegrees = 2.5, swayFrequency = 1.6 },
    jumang = { bobAmplitude = 4, bobFrequency = 1.5, swayDegrees = 1.5, swayFrequency = 1.2 },
}

local DEFAULT_ENEMY_MOTION = { bobAmplitude = 2, bobFrequency = 2, swayDegrees = 2, swayFrequency = 2 }

local function Pulse(time, frequency, phase)
    return math.sin((time * frequency + (phase or 0)) * TWO_PI)
end

local function Clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

function RuntimePresentation.Player(time, isMoving)
    local breath = Pulse(time, isMoving and 2.6 or 1.7)
    return {
        offsetY = breath * (isMoving and 1.5 or 2.5),
        rotation = breath * (isMoving and 2.0 or 1.1),
        scaleX = 1 + breath * 0.008,
        scaleY = 1 - breath * 0.012,
    }
end

function RuntimePresentation.Enemy(kind, time, phase)
    local motion = ENEMY_MOTION[kind] or DEFAULT_ENEMY_MOTION
    return {
        offsetY = Pulse(time, motion.bobFrequency, phase) * motion.bobAmplitude,
        rotation = Pulse(time, motion.swayFrequency, phase) * motion.swayDegrees,
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

function RuntimePresentation.Hit(elapsed, duration)
    duration = duration or 0.16
    local progress = Clamp((elapsed or 0) / duration, 0, 1)
    local flash = 1 - progress
    return {
        flashWhite = flash,
        scale = 1 + math.sin(progress * math.pi) * 0.10,
    }
end

function RuntimePresentation.Death(elapsed, duration)
    duration = duration or 0.32
    local progress = Clamp((elapsed or 0) / duration, 0, 1)
    return {
        opacity = 1 - progress,
        scale = 1 - progress * 0.18,
        offsetY = -progress * 12,
        complete = progress >= 1,
    }
end

function RuntimePresentation.Wheel(time, attackPulse)
    local result = {}
    local pulse = Clamp((attackPulse or 0) / 0.18, 0, 1)
    for index, layer in ipairs(RuntimePresentation.WheelLayers) do
        result[index] = {
            id = layer.id,
            width = layer.width,
            height = layer.height,
            offsetX = layer.offsetX,
            offsetY = layer.offsetY,
            opacity = Clamp(layer.opacity + pulse * 0.16, 0, 1),
            scale = 1 + pulse * (index == #RuntimePresentation.WheelLayers and 0.16 or 0.07),
            rotation = math.fmod(time * layer.rotationPerSecond + pulse * (index % 2 == 0 and -8 or 8), 360),
        }
    end
    return result
end

return RuntimePresentation
