local enemies = {
    jiuweihu = {
        id = "jiuweihu",
        name = "九尾狐",
        motion = {
            archetype = "orbit",
            speed = 174,
            preferredDistance = 220,
            approachWeight = 0.48,
            orbitWeight = 1.0,
            turnRate = 5.8,
            turnPulse = 0.16,
            visualRate = 7.2,
            elevation = 0.08,
            hoverAmplitude = 0.025,
            stepRate = 2.4,
            leanMax = 12,
            facingThreshold = 8,
        },
    },
    bifang = {
        id = "bifang",
        name = "毕方",
        motion = {
            archetype = "glide",
            speed = 96,
            preferredDistance = 330,
            distanceBand = 86,
            driftWeight = 0.72,
            turnRate = 3.4,
            visualRate = 5.4,
            elevation = 0.78,
            hoverAmplitude = 0.16,
            stepRate = 1.35,
            leanMax = 10,
            facingThreshold = 6,
        },
    },
    kui = {
        id = "kui",
        name = "夔",
        motion = {
            archetype = "press",
            speed = 54,
            turnRate = 0,
            visualRate = 2.2,
            elevation = 0,
            hoverAmplitude = 0,
            stepRate = 0.9,
            leanMax = 0.5,
            facingThreshold = 4,
        },
    },
}

local Enemies = {}

function Enemies.Get(enemyId)
    return enemies[enemyId]
end

return Enemies
