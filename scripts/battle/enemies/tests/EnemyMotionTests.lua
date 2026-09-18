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

local function AssertIntent(command, message)
    Assert(type(command.movementIntent) == "table", message .. "：缺少 movementIntent")
    Assert(type(command.movementIntent.x) == "number" and type(command.movementIntent.y) == "number", message .. "：移动坐标不可消费")
end

local target = { x = 0, y = 0 }

local fox = EnemyMotion.New("jiuweihu", 0)
Assert(fox.movement and fox.attack, "Enemy AI must use shared MovementAI and AttackLogic state")
local foxEnemy = { x = 420, y = 0 }
local foxOrbit = EnemyMotion.Step(fox, foxEnemy, target, 0.25)
local foxDash = EnemyMotion.Step(fox, foxEnemy, target, 0.20)
local foxRetreat = EnemyMotion.Step(fox, foxEnemy, target, 0.20)
Assert(foxOrbit.motionState == "approach_orbit" and foxOrbit.keyframe == "orbit", "九尾狐首帧应快速绕行接近")
Assert(foxOrbit.vy < -90, "九尾狐绕行应产生明显切线速度")
Assert(foxDash.motionState == "dash" and foxDash.keyframe == "dash", "九尾狐第二关键帧应短突进")
Assert(type(foxDash.attackIntent) == "table" and foxDash.attackIntent.type == "contact",
    "九尾狐短突进必须通过 AttackLogic 产出接触攻击 intent")
Assert(math.abs(foxDash.vx) > math.abs(foxOrbit.vx), "九尾狐短突进应快于绕行")
Assert(foxRetreat.motionState == "retreat" and foxRetreat.keyframe == "retreat", "九尾狐第三关键帧应短撤")
Assert(foxRetreat.vx > 0, "九尾狐短撤应远离目标")
AssertIntent(foxOrbit, "九尾狐")
Assert(foxEnemy.x == 420 and target.x == 0, "运动计算不应改写输入实体")

local statDrivenFox = EnemyMotion.New("jiuweihu", 0)
local statDrivenCommand = EnemyMotion.Step(statDrivenFox, {
    x = 420,
    y = 0,
    statSystem = { Get = function(_, name) return name == "speed" and 20 or nil end },
}, target, 0.1)
local statDrivenSpeed = math.sqrt(statDrivenCommand.vx ^ 2 + statDrivenCommand.vy ^ 2)
Assert(NearlyEqual(statDrivenSpeed, 20, 0.0001), "Enemy movement must read effective speed from StatSystem")

local bird = EnemyMotion.New("bifang", 0)
local birdFar = EnemyMotion.Step(bird, { x = 500, y = 0 }, target, 0.1)
Assert(birdFar.motionState == "close", "毕方过远应靠近目标")
Assert(birdFar.vx < 0, "毕方过远时应向目标飞行")
Assert(birdFar.elevation > 0.6, "毕方应保持明显飞行悬浮")
local birdHover = EnemyMotion.Step(bird, { x = 330, y = 0 }, target, 0.1)
local birdAttack = EnemyMotion.Step(bird, { x = 330, y = 0 }, target, 0.1)
Assert(birdHover.motionState == "glide" and birdHover.keyframe == "hover", "毕方应在远程带内悬浮")
Assert(birdAttack.motionState == "ranged_attack" and birdAttack.keyframe == "ranged_attack", "毕方第二关键帧应发起远程攻击")
Assert(type(birdAttack.attackIntent) == "table" and birdAttack.attackIntent.type == "ranged", "毕方必须产出清晰远程攻击 intent")
Assert(birdAttack.attackIntent.targetX == target.x and birdAttack.attackIntent.targetY == target.y, "毕方远程攻击 intent 应锁定目标位置")
AssertIntent(birdAttack, "毕方")
local birdNear = EnemyMotion.Step(bird, { x = 200, y = 0 }, target, 0.1)
Assert(birdNear.motionState == "retreat", "毕方过近应拉开距离")
Assert(birdNear.vx > 0, "毕方过近时应远离目标")

local kui = EnemyMotion.New("kui", 1)
local kuiStart = EnemyMotion.Step(kui, { x = 300, y = 0 }, target, 0.1)
local kuiPress = EnemyMotion.Step(kui, { x = 300, y = 0 }, target, 0.1)
local kuiStop = EnemyMotion.Step(kui, { x = 32, y = 0 }, target, 0.1)
Assert(kuiStart.motionState == "press" and kuiStart.keyframe == "press", "夔首帧应开始近战压迫")
Assert(math.abs(kuiStart.vx) < 54 and math.abs(kuiPress.vx) > math.abs(kuiStart.vx), "夔应有强启动惯性")
Assert(kuiStop.motionState == "melee_attack" and kuiStop.keyframe == "melee_attack", "夔第三关键帧应进入近战压迫")
Assert(kuiStop.vx < 0 and math.abs(kuiStop.vx) < math.abs(kuiPress.vx), "夔应有强停止惯性")
Assert(type(kuiStop.attackIntent) == "table" and kuiStop.attackIntent.type == "melee", "夔近战范围内必须产出攻击 intent")
AssertIntent(kuiStop, "夔")

local replayA = EnemyMotion.New("jiuweihu", 7)
local replayB = EnemyMotion.New("jiuweihu", 7)
for _, dt in ipairs({ 0.25, 0.20, 0.20 }) do
    local a = EnemyMotion.Step(replayA, foxEnemy, target, dt)
    local b = EnemyMotion.Step(replayB, foxEnemy, target, dt)
    Assert(a.motionState == b.motionState and NearlyEqual(a.vx, b.vx, 0.0001) and NearlyEqual(a.vy, b.vy, 0.0001), "固定 seed 的运动结果必须可复现")
end

print("EnemyMotionTests: Demo 0.3 intent, keyframes and deterministic motion passed")
