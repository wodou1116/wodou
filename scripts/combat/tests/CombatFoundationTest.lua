package.path = "scripts/?.lua;scripts/?/init.lua;" .. package.path

local AreaEffect = require("combat.AreaEffect")
local AttackLogic = require("combat.AttackLogic")
local DamageContext = require("combat.DamageContext")
local DangerEvaluator = require("combat.DangerEvaluator")
local DeathContext = require("combat.DeathContext")
local ObjectPool = require("combat.ObjectPool")
local ProjectileSystem = require("combat.ProjectileSystem")
local StatSystem = require("combat.StatSystem")
local TargetSelector = require("combat.TargetSelector")

local stats = StatSystem.New({ damage = 100, moveSpeed = 200, damageTaken = 1 })
stats:AddModifier("wood_build", {
    damage = { flat = 10, add = 0.2, multiply = 0.5 },
    moveSpeed = { add = 0.1 },
})
assert(stats:Get("damage") == 66, "stat order must be (base + flat) * (1 + add) * multiply")
assert(math.abs(stats:Get("moveSpeed") - 220) < 0.0001)
stats:RemoveModifier("wood_build")
assert(stats:Get("damage") == 100)

local target = { id = "enemy-1", hp = 80, maxHp = 80, armor = 5, damageTaken = 0.5 }
local damage = DamageContext.New({
    source = { id = "player" },
    target = target,
    amount = 30,
    kind = "projectile",
    tags = { "basic_attack" },
})
local resolved = DamageContext.Resolve(damage, target)
assert(resolved.amount == 12.5, "armor applies before damageTaken")
assert(resolved.lethal == false)
DamageContext.Apply(resolved)
assert(target.hp == 67.5)

local death = DeathContext.New({ victim = target, killer = damage.source, damage = resolved, reason = "damage" })
assert(death.victim == target and death.killer.id == "player" and death.reason == "damage")

local created = 0
local pool = ObjectPool.New(function()
    created = created + 1
    return {}
end, function(item)
    item.value = nil
end, 2)
local first = pool:Acquire()
first.value = 3
pool:Release(first)
assert(pool:Acquire() == first and first.value == nil and created == 1)

local projectiles = ProjectileSystem.New({ capacity = 2 })
local p1 = assert(projectiles:Spawn({ x = 0, y = 0, vx = 10, vy = 0, life = 1, radius = 2, damage = 4 }))
assert(projectiles:Spawn({ x = 0, y = 0, vx = 0, vy = 10, life = 1 }))
assert(projectiles:Spawn({}) == nil, "projectile capacity must be hard bounded")
projectiles:Update(0.5, {
    queryHit = function(projectile)
        return projectile == p1 and target or nil
    end,
    onHit = function()
        return false
    end,
})
assert(projectiles:Count() == 1, "consumed projectile must return to pool")
projectiles:Update(0.6)
assert(projectiles:Count() == 0, "expired projectile must return to pool")

local units = {
    { id = "a", x = 3, y = 4, radius = 0, alive = true },
    { id = "b", x = 20, y = 0, radius = 1, alive = true },
    { id = "c", x = 1, y = 1, radius = 0, alive = false },
}
local affected = AreaEffect.Query({ x = 0, y = 0, radius = 5 }, units, function(unit)
    return unit.alive
end)
assert(#affected == 1 and affected[1].id == "a")

local nearest = TargetSelector.FindNearest({ x = 0, y = 0 }, units, {
    isValid = function(unit) return unit.alive end,
})
assert(nearest.id == "a")
local preferred = TargetSelector.FindBest({ x = 0, y = 0 }, units, {
    isValid = function(unit) return unit.alive end,
    score = function(unit) return unit.id == "b" and 10 or 1 end,
})
assert(preferred.id == "b")

local attack = AttackLogic.New(0.5)
local fired = 0
assert(AttackLogic.Step(attack, 0.49, true, function() fired = fired + 1 end) == false)
assert(AttackLogic.Step(attack, 0.01, true, function() fired = fired + 1 end) == true)
assert(fired == 1)

local hazards = {
    { x = 0, y = 0, radius = 10, weight = 2 },
    { x = 100, y = 0, radius = 20, weight = 1 },
}
assert(DangerEvaluator.ScorePoint(0, 0, hazards) > DangerEvaluator.ScorePoint(50, 50, hazards))
local safest = DangerEvaluator.FindSafest({
    { x = 0, y = 0 },
    { x = 50, y = 50 },
}, hazards)
assert(safest.x == 50 and safest.y == 50)

print("CombatFoundationTest: stats, contexts, pool, projectile, area, targeting, attack and danger passed")
