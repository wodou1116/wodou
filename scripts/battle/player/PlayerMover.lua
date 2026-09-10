local BattleBounds = require("battle.BattleBounds")

local PlayerMover = {}

local function Normalize(x, y)
    local length = math.sqrt(x * x + y * y)
    if length <= 0.0001 then
        return 0, 0
    end
    return x / length, y / length
end

-- Moves a player in design-space units. Returns normalized movement direction and
-- whether the player moved this frame.
function PlayerMover.Update(player, inputX, inputY, timeStep, bounds)
    assert(player and player.x and player.y, "PlayerMover requires a player with x/y")
    assert(timeStep >= 0, "PlayerMover timeStep must be non-negative")

    local directionX, directionY = Normalize(inputX or 0, inputY or 0)
    local speed = player.moveSpeed or 0
    local nextX = player.x + directionX * speed * timeStep
    local nextY = player.y + directionY * speed * timeStep
    local arena = bounds or BattleBounds.DEFAULT
    player.x, player.y = BattleBounds.ClampPosition(arena, nextX, nextY, player.radius)
    player.moveX, player.moveY = directionX, directionY
    player.isMoving = directionX ~= 0 or directionY ~= 0

    return directionX, directionY, player.isMoving
end

return PlayerMover
