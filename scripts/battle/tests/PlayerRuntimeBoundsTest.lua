package.path = "scripts/?.lua;scripts/?/init.lua;" .. package.path

local BattleBounds = require("battle.BattleBounds")
local PlayerFacing = require("battle.player.PlayerFacing")
local PlayerMover = require("battle.player.PlayerMover")

local passed = 0

local function Test(name, callback)
    callback()
    passed = passed + 1
    print("PASS " .. name)
end

local function AssertEqual(actual, expected, message)
    assert(actual == expected, message or string.format("expected %s, got %s", tostring(expected), tostring(actual)))
end

Test("BattleBounds clamps every player edge and corner by radius", function()
    local bounds = BattleBounds.New()
    local radius = 40
    local northwestX, northwestY = BattleBounds.ClampPosition(bounds, 0, 0, radius)
    local northeastX, northeastY = BattleBounds.ClampPosition(bounds, 9999, 0, radius)
    local southwestX, southwestY = BattleBounds.ClampPosition(bounds, 0, 9999, radius)
    local southeastX, southeastY = BattleBounds.ClampPosition(bounds, 9999, 9999, radius)
    AssertEqual(northwestX, 130)
    AssertEqual(northwestY, 190)
    AssertEqual(northeastX, 1790)
    AssertEqual(northeastY, 190)
    AssertEqual(southwestX, 130)
    AssertEqual(southwestY, 950)
    AssertEqual(southeastX, 1790)
    AssertEqual(southeastY, 950)
    assert(BattleBounds.Contains(bounds, northwestX, northwestY, radius))
    assert(BattleBounds.Contains(bounds, southeastX, southeastY, radius))
end)

Test("BattleBounds recycles projectiles only beyond their buffered circle", function()
    local bounds = BattleBounds.New()
    assert(not BattleBounds.ShouldRecycleProjectile(bounds, 60, 540, 10, 20))
    assert(BattleBounds.ShouldRecycleProjectile(bounds, 59, 540, 10, 20))
    assert(not BattleBounds.ShouldRecycleProjectile(bounds, 1860, 540, 10, 20))
    assert(BattleBounds.ShouldRecycleProjectile(bounds, 1861, 540, 10, 20))
    assert(not BattleBounds.ShouldRecycleProjectile(bounds, 960, 120, 10, 20))
    assert(BattleBounds.ShouldRecycleProjectile(bounds, 960, 119, 10, 20))
end)

Test("BattleBounds supplies offscreen enemy spawn and in-arena entry", function()
    local entry = BattleBounds.GetEnemyEntry(BattleBounds.New(), "left", 0, 30, 20)
    AssertEqual(entry.spawnX, 40)
    AssertEqual(entry.spawnY, 180)
    AssertEqual(entry.entryX, 120)
    AssertEqual(entry.entryY, 180)

    local topEntry = BattleBounds.GetEnemyEntry(BattleBounds.New(), "top", 2000, 30, 20)
    AssertEqual(topEntry.spawnX, 1800)
    AssertEqual(topEntry.spawnY, 100)
    AssertEqual(topEntry.entryX, 1800)
    AssertEqual(topEntry.entryY, 180)
end)

Test("PlayerMover keeps a non-zero movement direction at the arena edge", function()
    local player = { x = 100, y = 500, radius = 10, moveSpeed = 100, facing = "right", facingX = 1 }
    local dx = PlayerMover.Update(player, -1, 0, 1, BattleBounds.New())
    AssertEqual(dx, -1)
    AssertEqual(player.x, 100)
    AssertEqual(player.isMoving, true)
    AssertEqual(PlayerFacing.Update(player, dx), "left")

    PlayerMover.Update(player, 0, 1, 1, BattleBounds.New())
    AssertEqual(player.isMoving, true)
    AssertEqual(player.lastMoveX, 0)
    AssertEqual(player.lastMoveY, 1)
    PlayerFacing.Update(player, 0)
    AssertEqual(player.facing, "left")
    AssertEqual(player.facingY, 1)
end)

Test("PlayerFacing accepts an attack direction and preserves it through idle", function()
    local player = { facing = "right", facingX = 1 }
    AssertEqual(PlayerFacing.FaceAttack(player, -1, -1), "left")
    AssertEqual(player.facingX, -1)
    AssertEqual(player.facingY, -1)
    AssertEqual(PlayerFacing.Update(player, 0, 0), "left")
end)

print(string.format("%d tests passed", passed))
