local PlayerFacing = {}

-- Horizontal facing is intentionally preserved for vertical or idle movement.
function PlayerFacing.Update(player, directionX)
    assert(player, "PlayerFacing requires a player")
    if directionX > 0 then
        player.facing = "right"
        player.facingX = 1
    elseif directionX < 0 then
        player.facing = "left"
        player.facingX = -1
    elseif not player.facing then
        player.facing = "right"
        player.facingX = 1
    end
    return player.facing, player.facingX
end

return PlayerFacing
