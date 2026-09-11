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

math.randomseed(42)
local battle = BattleManager.New()
battle:Prepare({ characterId = "shi_yu_zhe" })
battle:Start()

battle.player.x = 100
battle.player.y = 160
battle:Update(1, -1, -1)
assert(battle.player.x == 130 and battle.player.y == 190, "player must respect radius-aware bounds")
assert(battle.player.facing == "left" and battle.player.isMoving, "player facing/move state must update")

battle.player.x = 960
battle.player.y = 640
battle.enemies = {}
battle.spawnTimer = 999
battle:SpawnEnemy("jiuweihu", 1220, 640)
battle:SpawnEnemy("bifang", 960, 940)
battle:SpawnEnemy("kui", 700, 640)
local before = {}
for index = 1, 3 do
    before[index] = { x = battle.enemies[index].x, y = battle.enemies[index].y }
end
battle:UpdateEnemies(0.1)
assert(battle.enemies[1].motionState:find("orbit"), "fox must use orbit movement")
assert(battle.enemies[2].motionState ~= "press", "bifang must use glide/range movement")
assert(battle.enemies[3].motionState == "press", "kui must use heavy press movement")
assert(battle.enemies[1].x ~= before[1].x or battle.enemies[1].y ~= before[1].y)

local target = battle:FindNearestEnemy()
assert(target ~= nil, "target selector must find an in-range enemy")
battle:Attack()
assert(#battle.projectiles > 0 and battle.attackPulse > 0, "attack must create projectile and wheel pulse")
local spawnedProjectile = battle.projectiles[1]
assert(spawnedProjectile.prevX == spawnedProjectile.x and spawnedProjectile.prevY == spawnedProjectile.y,
    "projectile must retain a previous position for trail presentation")
assert(spawnedProjectile.maxLife == spawnedProjectile.life, "projectile must expose its initial lifetime")

local firstEnemy = battle.enemies[1]
firstEnemy.hp = 1
battle:KillEnemy(1)
assert(#battle.deathEffects == 1, "death feedback must survive entity removal")
battle:UpdateDeathEffects(1)
assert(#battle.deathEffects == 0, "death feedback must expire")

battle:Restart()
for index = 1, 20 do
    local kinds = { "jiuweihu", "bifang", "kui" }
    local angle = index * math.pi * 2 / 20
    battle:SpawnEnemy(kinds[(index - 1) % 3 + 1], 960 + math.cos(angle) * 420, 640 + math.sin(angle) * 260)
end
local stressTarget = battle.enemies[1]
for _ = 1, 50 do
    battle:SpawnProjectile(stressTarget, 0)
end
assert(#battle.enemies == 20 and #battle.projectiles == 50, "stress fixture must reach 20 enemies/50 projectiles")
for _ = 1, 30 do
    battle:Update(1 / 60, 0, 0)
end
assert(#battle.enemies <= 34 and #battle.projectiles <= 56, "runtime pools must stay bounded")

battle:ConfigureDebugScenario("combat_stress", 50)
assert(#battle.enemies == 20 and #battle.projectiles == 50, "debug stress scenario must be deterministic")
assert(battle.debugScenario == "combat_stress_50", "debug scenario must expose its active fixture")

battle:ConfigureDebugScenario("single")
local victim = battle.enemies[1]
battle.projectileSystem:Clear()
battle.projectileSystem:Spawn({
    source = battle.player,
    x = victim.x,
    y = victim.y,
    vx = 100,
    vy = 0,
    radius = 12,
    life = 1,
    maxLife = 1,
    damage = victim.hp + 1,
    hitsLeft = 1,
    hitIds = {},
})
battle:UpdateProjectiles(0)
assert(#battle.impacts == 1, "projectile collision must create one impact presentation record")

battle:Restart()
battle:DamagePlayer(battle.player.maxHp)
assert(battle.result == nil and battle.finishing, "player death must delay the result overlay")
battle:Update(0.7, 0, 0)
assert(battle.result == "defeat" and not battle.finishing, "death presentation must finish before result")

print("BattleManagerIntegrationTest: Demo 0.2 logic and 20/50 stress passed")
