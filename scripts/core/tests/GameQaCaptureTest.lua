package.path = "scripts/?.lua;scripts/?/init.lua;" .. package.path

package.preload["core.AssetCatalog"] = function()
    return {
        enemies = { bifang = "bifang", jiuweihu = "jiuweihu", kui = "kui", spring_elite = "elite" },
        bosses = { jumang = "jumang" },
    }
end

package.preload["core.Logger"] = function()
    return { Info = function() end, SetEnabled = function() end }
end

package.preload["data.Skills"] = function()
    return { GetChoices = function() return {} end }
end

local Game = require("core.Game")

local game = Game.New()
game:Start()
local metadata = game:StartQaCapture({
    mode = "boss",
    seed = 808,
    freeze = true,
    camera = { x = 1000, y = 500 },
})

assert(game.state == Game.State.BATTLE)
assert(metadata.mode == "boss" and metadata.seed == 808)
assert(game:GetQaCaptureMetadata().camera.x == 1000)
assert(game.battleManager.captureMode:IsFrozen())
assert(game.battleManager:GetBoss() ~= nil)
assert(game:GetQaCaptureMetadata().state.enemyCount == 5)

assert(game:RestartRun())
assert(game.battleManager.captureMode:IsFrozen(), "restart must retain active QA capture state")

game:ReturnToMenu()
assert(game:GetQaCaptureMetadata() == nil, "returning to menu must restore normal gameplay state")

print("GameQaCaptureTest: QA capture startup, restart, and cleanup passed")
