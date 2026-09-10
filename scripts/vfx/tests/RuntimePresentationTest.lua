local Presentation = require("vfx.RuntimePresentation")

local player = Presentation.Player(0, false)
assert(player.scaleX == 1 and player.scaleY == 1)

local enemy = Presentation.Enemy("bifang", 0.1, 0.25)
assert(math.abs(enemy.offsetY) <= 4)
assert(math.abs(enemy.rotation) <= 4)

local function near(a, b)
    return math.abs(a - b) < 0.0001
end

local shadow = Presentation.Shadow(100, 0.5)
assert(near(shadow.width, 60) and near(shadow.height, 18) and near(shadow.opacity, 0.26))

local hit = Presentation.Hit(0.08, 0.16)
assert(near(hit.flashWhite, 0.5) and hit.scale > 1)

local death = Presentation.Death(0.32, 0.32)
assert(death.complete and near(death.opacity, 0) and near(death.scale, 0.82))

local wheel = Presentation.Wheel(1, 0)
assert(#wheel == 5 and wheel[1].rotation == 0 and wheel[2].rotation == -10)
assert(wheel[1].width < 138 and wheel[5].width < wheel[1].width)
assert(wheel[1].offsetY == 2 and wheel[3].offsetY == 19 and wheel[4].offsetY == 20 and wheel[5].offsetY == 13)

local attackWheel = Presentation.Wheel(1, 0.18)
assert(attackWheel[5].scale > wheel[5].scale and attackWheel[5].opacity >= wheel[5].opacity)

return true
