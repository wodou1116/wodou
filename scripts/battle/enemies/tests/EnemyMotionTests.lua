package.path = "scripts/?.lua;scripts/?/init.lua;" .. package.path

local EnemyMotion = require("battle.enemies.EnemyMotion")

local function Assert(condition, message)
    if not condition then
        error(message, 2)
    end
end

local function NearlyEqual(actual, expected, epsilon)
    return math.abs(actual - expected) <= epsilon
end

local target = { x = 0, y = 0 }

local fox = EnemyMotion.New("jiuweihu", 0)
local foxEnemy = { x = 400, y = 0 }
local foxCommand = EnemyMotion.Step(fox, foxEnemy, target, 1)
Assert(foxCommand.motionState == "approach_orbit", "九尾狐远距应绕行接近")
Assert(foxCommand.vy < 0, "九尾狐应产生切线绕行速度")
Assert(foxCommand.facing == "left", "九尾狐应面向目标方向")
Assert(foxEnemy.x == 400 and target.x == 0, "运动计算不应改写输入实体")

local bird = EnemyMotion.New("bifang", 0)
local birdFar = EnemyMotion.Step(bird, { x = 500, y = 0 }, target, 1)
Assert(birdFar.motionState == "close", "毕方过远应靠近目标")
Assert(birdFar.vx < 0, "毕方过远时应向目标飞行")
local birdNear = EnemyMotion.Step(bird, { x = 200, y = 0 }, target, 1)
Assert(birdNear.motionState == "retreat", "毕方过近应拉开距离")
Assert(birdNear.vx > 0, "毕方过近时应远离目标")
local birdGlide = EnemyMotion.Step(bird, { x = 300, y = 0 }, target, 1)
Assert(birdGlide.motionState == "glide", "毕方应在期望距离滑翔")
Assert(not NearlyEqual(birdGlide.vy, 0, 0.0001), "毕方滑翔应保留可控漂移")

local kui = EnemyMotion.New("kui", 1)
local kuiCommand = EnemyMotion.Step(kui, { x = 300, y = 0 }, target, 1)
Assert(kuiCommand.motionState == "press", "夔应持续压迫")
Assert(NearlyEqual(kuiCommand.vx, -54, 0.0001), "夔应以低速直线推进")
Assert(NearlyEqual(kuiCommand.vy, 0, 0.0001), "夔不应产生横向漂移")

print("EnemyMotionTests: 3 archetypes passed")
