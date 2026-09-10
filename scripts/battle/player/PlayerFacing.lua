local PlayerFacing = {}

local function Sign(value)
    if value > 0.0001 then
        return 1
    elseif value < -0.0001 then
        return -1
    end
    return 0
end

local function ApplyDirection(player, directionX, directionY)
    local horizontal = Sign(directionX or 0)
    local vertical = Sign(directionY or 0)
    if horizontal == 0 and vertical == 0 then
        return player.facing, player.facingX, player.facingY
    end

    if horizontal ~= 0 then
        player.facing = horizontal > 0 and "right" or "left"
        player.facingX = horizontal
    elseif not player.facing then
        player.facing = "right"
        player.facingX = 1
    end
    player.facingY = vertical
    return player.facing, player.facingX, player.facingY
end

-- Horizontal sprite facing is preserved for vertical movement, while facingY
-- records the complete last non-zero movement or attack direction.
function PlayerFacing.Update(player, directionX, directionY)
    assert(player, "PlayerFacing requires a player")
    if player.didMove then
        return ApplyDirection(player, player.lastMoveX, player.lastMoveY)
    end
    if player.didMove ~= nil then
        return player.facing or "right", player.facingX or 1, player.facingY or 0
    end
    return ApplyDirection(player, directionX, directionY)
end

function PlayerFacing.FaceAttack(player, directionX, directionY)
    assert(player, "PlayerFacing requires a player")
    return ApplyDirection(player, directionX, directionY)
end

return PlayerFacing
