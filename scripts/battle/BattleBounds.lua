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

-- Collision and boundary design (all positions are circle centres):
--
--                   top
--        +---------------------------+
--        |  player centre range      |
-- left   |  [left + r, right - r]    | right
--        |  [top + r, bottom - r]    |
--        +---------------------------+
--                  bottom
--
-- Player centres are clamped to the inner rectangle, so their radius never
-- crosses a side or corner. Projectiles are not clamped: they are recycled
-- only after the whole circle has crossed an outer rectangle expanded by
-- `buffer`. Enemies spawn outside that outer rectangle and receive a matching
-- inner entry point, which keeps their arrival direction unambiguous.

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

local function InnerRange(minimum, maximum, radius)
    local innerMinimum = minimum + radius
    local innerMaximum = maximum - radius
    if innerMinimum > innerMaximum then
        local center = (minimum + maximum) * 0.5
        return center, center
    end
    return innerMinimum, innerMaximum
end

local function Clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

function BattleBounds.ClampPosition(bounds, x, y, radius)
    radius = math.max(0, radius or 0)
    local left, right = InnerRange(bounds.left, bounds.right, radius)
    local top, bottom = InnerRange(bounds.top, bounds.bottom, radius)
    return Clamp(x, left, right), Clamp(y, top, bottom)
end

function BattleBounds.Contains(bounds, x, y, radius)
    local clampedX, clampedY = BattleBounds.ClampPosition(bounds, x, y, radius)
    return clampedX == x and clampedY == y
end

-- Returns true once a projectile circle has completely left the arena plus
-- its allowed travel buffer. This intentionally does not clamp projectiles.
function BattleBounds.ShouldRecycleProjectile(bounds, x, y, radius, buffer)
    radius = math.max(0, radius or 0)
    buffer = math.max(0, buffer or 0)
    return x < bounds.left - radius - buffer
        or x > bounds.right + radius + buffer
        or y < bounds.top - radius - buffer
        or y > bounds.bottom + radius + buffer
end

-- Returns a deterministic offscreen spawn and its corresponding in-arena
-- entry point. `lane` is the free axis and is clamped by the enemy radius.
function BattleBounds.GetEnemyEntry(bounds, edge, lane, radius, padding)
    radius = math.max(0, radius or 0)
    padding = math.max(0, padding or 0)
    local left, right = InnerRange(bounds.left, bounds.right, radius)
    local top, bottom = InnerRange(bounds.top, bounds.bottom, radius)
    lane = lane or (edge == "left" or edge == "right") and (bounds.top + bounds.bottom) * 0.5
        or (bounds.left + bounds.right) * 0.5

    if edge == "left" then
        local y = Clamp(lane, top, bottom)
        return { spawnX = bounds.left - radius - padding, spawnY = y, entryX = left, entryY = y }
    elseif edge == "right" then
        local y = Clamp(lane, top, bottom)
        return { spawnX = bounds.right + radius + padding, spawnY = y, entryX = right, entryY = y }
    elseif edge == "top" then
        local x = Clamp(lane, left, right)
        return { spawnX = x, spawnY = bounds.top - radius - padding, entryX = x, entryY = top }
    elseif edge == "bottom" then
        local x = Clamp(lane, left, right)
        return { spawnX = x, spawnY = bounds.bottom + radius + padding, entryX = x, entryY = bottom }
    end

    error("unknown battle edge: " .. tostring(edge))
end

return BattleBounds
