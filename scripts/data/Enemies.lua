local enemies = {
    jiuweihu = {
        id = "jiuweihu",
        name = "九尾狐",
        motion = {
            archetype = "orbit",
            speed = 126,
            preferredDistance = 210,
            approachWeight = 0.58,
            orbitWeight = 0.82,
            turnRate = 2.6,
        },
    },
    bifang = {
        id = "bifang",
        name = "毕方",
        motion = {
            archetype = "glide",
            speed = 92,
            preferredDistance = 300,
            distanceBand = 52,
            driftWeight = 0.38,
            turnRate = 2.1,
        },
    },
    kui = {
        id = "kui",
        name = "夔",
        motion = {
            archetype = "press",
            speed = 54,
            turnRate = 0,
        },
    },
}

local Enemies = {}

function Enemies.Get(enemyId)
    return enemies[enemyId]
end

return Enemies
