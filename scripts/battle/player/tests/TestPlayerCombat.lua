package.path = "scripts/?.lua;scripts/?/init.lua;" .. package.path

local BattleBounds = require("battle.BattleBounds")
local PlayerMover = require("battle.player.PlayerMover")
local PlayerFacing = require("battle.player.PlayerFacing")
local AttackRange = require("battle.player.AttackRange")
local TargetSelector = require("battle.player.TargetSelector")

local passed = 0

local function Test(name, callback)
    callback()
    passed = passed + 1
    print("PASS " .. name)
end

local function AssertEqual(actual, expected, message)
    assert(actual == expected, message or string.format("expected %s, got %s", tostring(expected), tostring(actual)))
end

Test("BattleBounds clamps with player radius", function()
    local bounds = BattleBounds.New()
    local x, y = BattleBounds.ClampPosition(bounds, 0, 1200, 40)
    AssertEqual(x, 130)
    AssertEqual(y, 950)
    assert(BattleBounds.Contains(bounds, 130, 950, 40))
    assert(not BattleBounds.Contains(bounds, 90, 150, 40))
end)

Test("PlayerMover normalizes diagonal input and clamps", function()
    local player = { x = 80, y = 200, radius = 10, moveSpeed = 100 }
    local dx, dy, moving = PlayerMover.Update(player, -1, 1, 1, BattleBounds.New())
    assert(math.abs(dx + math.sqrt(0.5)) < 0.0001)
    assert(math.abs(dy - math.sqrt(0.5)) < 0.0001)
    AssertEqual(moving, true)
    AssertEqual(player.x, 100)
    assert(math.abs(player.y - (200 + math.sqrt(0.5) * 100)) < 0.0001)
end)

Test("PlayerFacing keeps facing when movement is vertical", function()
    local player = {}
    AssertEqual(PlayerFacing.Update(player, -1), "left")
    AssertEqual(PlayerFacing.Update(player, 0), "left")
    AssertEqual(player.facingX, -1)
end)

Test("AttackRange supports center and edge ranges", function()
    local source = { x = 0, y = 0, radius = 10 }
    local target = { x = 25, y = 0, radius = 10 }
    assert(not AttackRange.IsInRange(source, target, 20))
    assert(AttackRange.IsWithinEdgeRange(source, target, 5))
    assert(not AttackRange.IsWithinEdgeRange(source, target, 4))
end)

Test("TargetSelector applies range filter and preserves tie order", function()
    local source = { x = 0, y = 0 }
    local targets = {
        { x = 30, y = 40, alive = true },
        { x = 30, y = 40, alive = true },
        { x = 100, y = 0, alive = false },
    }
    local target, index, distance = TargetSelector.FindNearest(source, targets, {
        maxRange = 60,
        isValid = function(candidate)
            return candidate.alive
        end,
    })
    AssertEqual(target, targets[1])
    AssertEqual(index, 1)
    AssertEqual(distance, 50)
end)

print(string.format("%d tests passed", passed))
