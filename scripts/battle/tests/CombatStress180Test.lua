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

local function RunTier(projectileCount)
    local battle = BattleManager.New()
    battle:Prepare({ characterId = "shi_yu_zhe" })
    battle:ConfigureDebugScenario("combat_stress", projectileCount)

    local directions = {
        { -1, -1 },
        { 1, -1 },
        { 1, 1 },
        { -1, 1 },
    }
    local maxEnemies = 0
    local maxProjectiles = 0
    local maxImpacts = 0
    local frames = 180 * 60
    for frame = 1, frames do
        local phase = math.floor((frame - 1) / (45 * 60)) % #directions + 1
        local direction = directions[phase]
        battle:Update(1 / 60, direction[1], direction[2])
        maxEnemies = math.max(maxEnemies, #battle.enemies)
        maxProjectiles = math.max(maxProjectiles, #battle.projectiles)
        maxImpacts = math.max(maxImpacts, #battle.impacts)
        assert(battle.active, "stress battle must remain active")
        assert(#battle.enemies == 20, "stress scenario must maintain exactly 20 enemies")
        assert(#battle.projectiles == projectileCount,
            "stress scenario must maintain its projectile tier")
        assert(#battle.impacts <= 24, "impact pool must remain bounded")
    end

    return {
        projectileCount = projectileCount,
        frames = frames,
        maxEnemies = maxEnemies,
        maxProjectiles = maxProjectiles,
        maxImpacts = maxImpacts,
        kills = battle.kills,
    }
end

for _, projectileCount in ipairs({ 20, 35, 50 }) do
    local result = RunTier(projectileCount)
    print(string.format(
        "CombatStress180Test tier=%d frames=%d enemies=%d projectiles=%d impacts=%d kills=%d",
        result.projectileCount,
        result.frames,
        result.maxEnemies,
        result.maxProjectiles,
        result.maxImpacts,
        result.kills
    ))
end
