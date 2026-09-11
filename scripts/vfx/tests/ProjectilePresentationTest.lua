package.path = "scripts/?.lua;scripts/?/init.lua;" .. package.path

local ProjectilePresentation = require("vfx.ProjectilePresentation")

local function Near(actual, expected)
    return math.abs(actual - expected) < 0.0001
end

local visual = ProjectilePresentation.Compute({
    x = 100,
    y = 200,
    vx = 0,
    vy = 400,
    radius = 12,
    life = 1.55,
}, 1.55)

assert(visual.head.rotation == 90 and visual.head.width == 24)
assert(visual.lifeProgress == 1 and #visual.tail == 3)
assert(visual.tail[1].poolSlot == 1 and visual.tail[3].poolSlot == 3)
assert(visual.tail[1].y < visual.head.y and visual.tail[1].opacity > visual.tail[3].opacity)

local expiring = ProjectilePresentation.Compute({
    x = 0,
    y = 0,
    vx = -100,
    vy = 0,
    radius = 10,
    life = 0.1,
}, 1.0)
assert(expiring.head.rotation == 180 and expiring.lifeProgress == 0.1)
assert(expiring.head.opacity < visual.head.opacity)

local stationary = ProjectilePresentation.Compute({ x = 0, y = 0, vx = 0, vy = 0, radius = 8, life = 1 }, 1)
assert(stationary.head.rotation == 0 and stationary.tail[1].x < stationary.head.x)

local impactStart = ProjectilePresentation.Impact({ x = 20, y = 30, radius = 12 }, 0)
assert(impactStart.duration == 0.18 and not impactStart.complete and impactStart.ringOpacity == 1)

local impactEnd = ProjectilePresentation.Impact({ x = 20, y = 30, radius = 12 }, 0.18)
assert(impactEnd.complete and Near(impactEnd.opacity, 0) and impactEnd.ringScale > impactStart.ringScale)

local eliteImpact = ProjectilePresentation.Impact({ x = 20, y = 30, radius = 12, kind = "elite" }, 0)
local bossImpact = ProjectilePresentation.Impact({ x = 20, y = 30, radius = 12, kind = "boss" }, 0)
assert(eliteImpact.ringWidth > impactStart.ringWidth)
assert(bossImpact.ringWidth > eliteImpact.ringWidth and bossImpact.borderWidth > eliteImpact.borderWidth)

print("ProjectilePresentationTest: head, 3-tail pool, lifecycle and impact passed")

return true
