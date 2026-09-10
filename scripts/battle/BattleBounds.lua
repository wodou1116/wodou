local BattleBounds = {}

-- All combat coordinates use the 1920x1080 design space.
BattleBounds.DESIGN_WIDTH = 1920
BattleBounds.DESIGN_HEIGHT = 1080
BattleBounds.DEFAULT = {
    left = 90,
    right = 1830,
    top = 150,
    bottom = 990,
}

local function CopyBounds(bounds)
    return {
        left = bounds.left,
        right = bounds.right,
        top = bounds.top,
        bottom = bounds.bottom,
    }
end

function BattleBounds.New(overrides)
    local bounds = CopyBounds(BattleBounds.DEFAULT)
    if overrides then
        for key, value in pairs(overrides) do
            bounds[key] = value
        end
    end

    assert(bounds.left <= bounds.right, "BattleBounds left must not exceed right")
    assert(bounds.top <= bounds.bottom, "BattleBounds top must not exceed bottom")
    return bounds
end

function BattleBounds.ClampPosition(bounds, x, y, radius)
    radius = radius or 0
    local left = bounds.left + radius
    local right = bounds.right - radius
    local top = bounds.top + radius
    local bottom = bounds.bottom - radius

    -- A radius larger than the arena collapses to the arena center.
    if left > right then
        left = (bounds.left + bounds.right) * 0.5
        right = left
    end
    if top > bottom then
        top = (bounds.top + bounds.bottom) * 0.5
        bottom = top
    end

    return math.max(left, math.min(right, x)), math.max(top, math.min(bottom, y))
end

function BattleBounds.Contains(bounds, x, y, radius)
    local clampedX, clampedY = BattleBounds.ClampPosition(bounds, x, y, radius)
    return clampedX == x and clampedY == y
end

return BattleBounds
