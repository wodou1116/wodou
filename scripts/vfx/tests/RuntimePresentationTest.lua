package.path = "scripts/?.lua;scripts/?/init.lua;" .. package.path

local Presentation = require("vfx.RuntimePresentation")

local function near(a, b)
    return math.abs(a - b) < 0.0001
end

local player = Presentation.Player(0, false)
assert(player.state == "idle" and player.scaleX == 1 and player.scaleY == 1)

local movingPlayer = Presentation.Player(0.1, true)
assert(movingPlayer.state == "move" and math.abs(movingPlayer.offsetY) <= 1.5)

local hitPlayer = Presentation.Player(0, false, "hit", 0.08, 0.16)
assert(hitPlayer.state == "hit" and near(hitPlayer.flashWhite, 0.5) and hitPlayer.scale > 1)

local deadPlayer = Presentation.Player(0, false, "death", 0.32, 0.32)
assert(deadPlayer.state == "death" and deadPlayer.complete and near(deadPlayer.opacity, 0))

local enemy = Presentation.Enemy("bifang", 0.1, 0.25)
assert(enemy.elevation == 0.72 and math.abs(enemy.bob) <= 4 and math.abs(enemy.lean) <= 4)
assert(near(enemy.offsetY, enemy.elevationOffset + enemy.bob) and enemy.rotation == enemy.lean)

local fox = Presentation.Enemy("jiuweihu", 0.1, 0.25)
local kui = Presentation.Enemy("kui", 0.1, 0.25)
assert(fox.elevation == 0.08 and kui.elevation == 0)

local shadow = Presentation.Shadow(100, 0.5)
assert(near(shadow.width, 60) and near(shadow.height, 18) and near(shadow.opacity, 0.26))

local birdShadow = Presentation.EnemyShadow("bifang", 100, 0.1, 0.25)
assert(near(birdShadow.elevation, 0.72) and birdShadow.width < shadow.width)

local hit = Presentation.Hit(0.08, 0.16)
assert(near(hit.flashWhite, 0.5) and hit.scale > 1)

local death = Presentation.Death(0.32, 0.32)
assert(death.complete and near(death.opacity, 0) and near(death.scale, 0.82))

local wheel = Presentation.Wheel(1, 0)
assert(#wheel == 5 and wheel[1].rotation == 3 and wheel[2].rotation == -9)
assert(wheel[1].width <= 138 * 0.75 and wheel[5].width < wheel[1].width)
assert(wheel[1].offsetY == 2 and wheel[3].offsetY == 19 and wheel[4].offsetY == 20 and wheel[5].offsetY == 13)
assert(wheel[1].rotationSpeed ~= wheel[2].rotationSpeed)

local attackWheel = Presentation.Wheel(1, 0.18)
assert(attackWheel[5].scale > wheel[5].scale and attackWheel[5].opacity >= wheel[5].opacity)
assert(attackWheel[5].coreGlow > 0 and attackWheel[5].rotationSpeed > wheel[5].rotationSpeed)

return true
