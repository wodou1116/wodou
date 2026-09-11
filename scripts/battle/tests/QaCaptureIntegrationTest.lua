package.path = "scripts/?.lua;scripts/?/init.lua;" .. package.path

package.preload["core.AssetCatalog"] = function()
    return {
        enemies = { bifang = "bifang", jiuweihu = "jiuweihu", kui = "kui", spring_elite = "elite" },
        bosses = { jumang = "jumang" },
    }
end

package.preload["core.Logger"] = function()
    return { Info = function() end }
end

package.preload["data.Skills"] = function()
    return { GetChoices = function() return {} end }
end

local BattleManager = require("battle.BattleManager")
local CaptureMode = require("qa.CaptureMode")

local frozenCapture = CaptureMode.New()
frozenCapture:Configure({
    mode = "motion",
    seed = 101,
    freeze = true,
    animationPhase = 0.5,
    state = {
        solarTermId = "jingzhe",
        playerAnimationState = "hit",
        enemyAnimationState = "move",
        playerFacing = "left",
        wheelState = "charged",
    },
})

local frozenBattle = BattleManager.New()
frozenBattle:Prepare({ characterId = "shi_yu_zhe" })
frozenBattle:ConfigureCapture(frozenCapture)
local frozenEnemy = frozenBattle.enemies[1]
local frozenX, frozenY = frozenEnemy.x, frozenEnemy.y
local frozenAttackTimer = frozenBattle.attackTimer
frozenBattle:Update(1, 1, 0)
assert(frozenEnemy.x == frozenX and frozenEnemy.y == frozenY, "capture freeze must stop entity translation")
assert(frozenBattle.attackTimer == frozenAttackTimer, "capture freeze must stop attack scheduling")
assert(frozenBattle.elapsed == 0.5, "capture freeze must expose the requested presentation phase")
assert(frozenEnemy.animation.time == frozenEnemy.animation.hitDuration * 0.5,
    "capture freeze must apply the requested animation phase")
assert(frozenBattle.player.animation:Get() == "Hit" and frozenBattle.player.facing == "left")
assert(frozenEnemy.animation:Get() == "Move")
assert(frozenBattle.wheelState == "charged")
assert(frozenCapture:GetStateMetadata().solarTermId == "jingzhe", "requested state must survive runtime metadata")

local liveCapture = CaptureMode.New()
liveCapture:Configure({ mode = "motion", seed = 101, freeze = false })

local liveBattle = BattleManager.New()
liveBattle:Prepare({ characterId = "shi_yu_zhe" })
liveBattle:ConfigureCapture(liveCapture)
local liveEnemy = liveBattle.enemies[1]
local liveX, liveY = liveEnemy.x, liveEnemy.y
liveBattle:Update(0.25, 0, 0)
assert(liveEnemy.x ~= liveX or liveEnemy.y ~= liveY, "unfrozen motion capture must advance entity motion")
assert(liveBattle.debugFreezeSpawning, "capture scenarios must freeze procedural spawning")

print("QaCaptureIntegrationTest: BattleManager capture freeze and motion passed")
