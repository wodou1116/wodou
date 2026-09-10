local ProjectilePresentation = {}

local DEFAULT_LIFETIME = 1.55
local IMPACT_DURATION = 0.18

local function Clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function Direction(vx, vy)
    local speed = math.sqrt(vx * vx + vy * vy)
    if speed <= 0.0001 then
        return 1, 0, 0
    end
    return vx / speed, vy / speed, speed
end

function ProjectilePresentation.Compute(projectile, totalLifetime)
    assert(projectile, "projectile is required")

    local x = projectile.x or 0
    local y = projectile.y or 0
    local vx = projectile.vx or 0
    local vy = projectile.vy or 0
    local radius = projectile.radius or 12
    local lifetime = projectile.maxLife or totalLifetime or DEFAULT_LIFETIME
    local lifeProgress = Clamp((projectile.life or lifetime) / lifetime, 0, 1)
    local ux, uy, speed = Direction(vx, vy)
    local size = radius * 2
    local fade = Clamp(lifeProgress / 0.2, 0, 1)
    local rotation = speed > 0 and math.deg(math.atan(vy, vx)) or 0
    local headScale = 1 + Clamp(speed / 1200, 0, 0.12)
    local result = {
        lifeProgress = lifeProgress,
        ageProgress = 1 - lifeProgress,
        head = {
            x = x,
            y = y,
            left = x - radius,
            top = y - radius,
            width = size,
            height = size,
            borderRadius = radius,
            rotation = rotation,
            scale = headScale,
            opacity = fade,
        },
        tail = {},
    }

    for index = 1, 3 do
        local distance = radius * (1.25 + index * 0.85)
        local tailRadius = radius * (1 - index * 0.16)
        local tailX = x - ux * distance
        local tailY = y - uy * distance
        result.tail[index] = {
            poolSlot = index,
            x = tailX,
            y = tailY,
            left = tailX - tailRadius,
            top = tailY - tailRadius,
            width = tailRadius * 2,
            height = tailRadius * 2,
            borderRadius = tailRadius,
            rotation = rotation,
            opacity = fade * (0.62 - index * 0.12),
            scale = 1 - index * 0.08,
        }
    end

    return result
end

function ProjectilePresentation.Impact(impact, elapsed)
    assert(impact, "impact is required")

    local progress = Clamp((elapsed or 0) / IMPACT_DURATION, 0, 1)
    local radius = impact.radius or 12
    local easeOut = 1 - (1 - progress) * (1 - progress)
    return {
        x = impact.x or 0,
        y = impact.y or 0,
        duration = IMPACT_DURATION,
        progress = progress,
        opacity = 1 - progress,
        flashWhite = 1 - progress,
        ringScale = 0.6 + easeOut * 0.9,
        coreScale = 1 + (1 - progress) * 0.25,
        ringWidth = radius * 4,
        ringHeight = radius * 4,
        ringOpacity = 1 - progress,
        complete = progress >= 1,
    }
end

return ProjectilePresentation
