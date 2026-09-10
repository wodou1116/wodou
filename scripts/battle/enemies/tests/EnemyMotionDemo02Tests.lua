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

local function HasPresentation(command)
    return type(command.elevation) == "number"
        and type(command.step) == "number"
        and type(command.lean) == "number"
        and (command.facingX == -1 or command.facingX == 1)
end

local target = { x = 0, y = 0 }

local fox = EnemyMotion.New("jiuweihu", 0)
local foxFirst = EnemyMotion.Step(fox, { x = 420, y = 0 }, target, 0.1)
Assert(foxFirst.motionState == "approach_orbit", "九尾狐远距应保持绕行接近状态")
Assert(math.abs(foxFirst.vy) > 90, "九尾狐应有快速明显的环绕切线速度")
Assert(foxFirst.facing == "left" and foxFirst.facingX == -1, "九尾狐首次应稳定朝向目标")
Assert(HasPresentation(foxFirst), "九尾狐必须提供主线程可消费的表现字段")

local foxTurn = EnemyMotion.Step(fox, { x = 0, y = 420 }, target, 0.1)
Assert(foxTurn.facing == "right" and foxTurn.facingX == 1, "九尾狐应能随环绕方向灵活转向")
Assert(math.abs(foxTurn.lean) > 1, "九尾狐转向应输出可见倾斜")

local bird = EnemyMotion.New("bifang", 0)
local birdFar = EnemyMotion.Step(bird, { x = 520, y = 0 }, target, 0.1)
Assert(birdFar.motionState == "close" and birdFar.vx < 0, "毕方在远距带外应向目标收距")
Assert(birdFar.elevation > 0.6, "毕方应提供明显高于地面的悬浮高度")
Assert(math.abs(birdFar.lean) > 1, "毕方滑行应输出姿态倾斜")

local birdGlide = EnemyMotion.Step(bird, { x = 330, y = 0 }, target, 0.2)
Assert(birdGlide.motionState == "glide", "毕方应在远距带内滑翔")
Assert(math.abs(birdGlide.vy) > 20, "毕方滑翔应保留横向漂移")
Assert(birdGlide.step ~= birdFar.step, "毕方悬浮节奏应随时间变化")
Assert(HasPresentation(birdGlide), "毕方必须提供主线程可消费的表现字段")

local kui = EnemyMotion.New("kui", 1)
local kuiCommand = EnemyMotion.Step(kui, { x = 300, y = 0 }, target, 0.25)
Assert(kuiCommand.motionState == "press", "夔应持续压迫")
Assert(NearlyEqual(kuiCommand.vx, -54, 0.0001) and NearlyEqual(kuiCommand.vy, 0, 0.0001), "夔应保持低速、重型的直线推进")
Assert(NearlyEqual(kuiCommand.elevation, 0, 0.0001), "夔不应产生悬浮高度")
Assert(math.abs(kuiCommand.lean) < 1, "夔应保持沉重、低倾斜的推进姿态")
Assert(HasPresentation(kuiCommand), "夔必须提供主线程可消费的表现字段")

print("EnemyMotionDemo02Tests: motion identities and presentation contract passed")
