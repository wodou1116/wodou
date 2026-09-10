local AssetCatalog = require("core.AssetCatalog")
local Logger = require("core.Logger")
local Skills = require("data.Skills")

local BattleManager = {}
BattleManager.__index = BattleManager

local ARENA = { left = 90, right = 1830, top = 150, bottom = 990 }
local MAX_ENEMIES = 34
local MAX_PROJECTILES = 56

local ENEMY_TYPES = {
    bifang = { hp = 54, speed = 92, damage = 7, radius = 38, size = 105, xp = 1, sprite = AssetCatalog.enemies.bifang },
    jiuweihu = { hp = 82, speed = 72, damage = 10, radius = 45, size = 118, xp = 1, sprite = AssetCatalog.enemies.jiuweihu },
    kui = { hp = 126, speed = 54, damage = 14, radius = 52, size = 132, xp = 2, sprite = AssetCatalog.enemies.kui },
    spring_elite = { hp = 420, speed = 48, damage = 18, radius = 66, size = 178, xp = 5, sprite = AssetCatalog.enemies.spring_elite },
    jumang = { hp = 1900, speed = 34, damage = 24, radius = 96, size = 260, xp = 20, sprite = AssetCatalog.bosses.jumang, boss = true },
}

local function Clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function Normalize(x, y)
    local length = math.sqrt(x * x + y * y)
    if length <= 0.0001 then
        return 0, 0
    end
    return x / length, y / length
end

-- Collision design (all gameplay positions are in 1920x1080 design space):
--
--       enemy circle (er)
--           ( E )       overlap when distance(P,E) < pr + er
--              \
--              ( P )    player/projectile circle (pr)
--
-- Rectangular arena bounds only clamp the player. Enemies enter from four edges.
local function CirclesOverlap(ax, ay, ar, bx, by, br)
    local dx = ax - bx
    local dy = ay - by
    local radius = ar + br
    return dx * dx + dy * dy <= radius * radius
end

function BattleManager.New()
    local self = setmetatable({}, BattleManager)
    self:Init()
    return self
end

function BattleManager:Init()
    self.run = nil
    self.active = false
    self.paused = false
    self.choosing = false
    self.result = nil
    self.elapsed = 0
    self.spawnTimer = 0
    self.attackTimer = 0
    self.eliteSpawned = false
    self.bossSpawned = false
    self.warningTimer = 2.5
    self.warning = nil
    self.enemies = {}
    self.projectiles = {}
    self.pendingChoices = {}
    self.acquiredSkills = {}
    self.kills = 0
    self.player = nil
end

function BattleManager:Prepare(runSnapshot)
    self.run = runSnapshot
    self:ResetBattle()
end

function BattleManager:ResetBattle()
    self.active = false
    self.paused = false
    self.choosing = false
    self.result = nil
    self.elapsed = 0
    self.spawnTimer = 0.35
    self.attackTimer = 0.2
    self.eliteSpawned = false
    self.bossSpawned = false
    self.warningTimer = 3.5
    self.warning = nil
    self.enemies = {}
    self.projectiles = {}
    self.pendingChoices = {}
    self.acquiredSkills = {}
    self.kills = 0

    local characterId = self.run and self.run.characterId or "shi_yu_zhe"
    self.player = {
        x = 960,
        y = 640,
        radius = 40,
        hp = 120,
        maxHp = 120,
        moveSpeed = characterId == "si_chen_zhe" and 350 or 330,
        damage = characterId == "shi_yu_zhe" and 52 or 46,
        damageTaken = 1,
        attackInterval = characterId == "si_chen_zhe" and 0.38 or 0.44,
        projectileSpeed = 820,
        projectileRadius = 12,
        projectileLife = 1.55,
        projectileCount = 1,
        pierce = 0,
        level = 1,
        xp = 0,
        xpNeeded = 4,
    }
end

function BattleManager:Start()
    self.active = true
    Logger.Info("Battle", "春季试炼开始")
end

function BattleManager:Restart()
    self:ResetBattle()
    self:Start()
end

function BattleManager:Stop()
    self.active = false
end

function BattleManager:TogglePause()
    if not self.active or self.choosing then
        return self.paused
    end
    self.paused = not self.paused
    return self.paused
end

function BattleManager:SpawnEnemy(kind, x, y)
    if #self.enemies >= MAX_ENEMIES then
        return
    end

    local config = ENEMY_TYPES[kind]
    if not config then
        return
    end

    if not x or not y then
        local edge = math.random(4)
        if edge == 1 then
            x, y = ARENA.left, math.random(ARENA.top, ARENA.bottom)
        elseif edge == 2 then
            x, y = ARENA.right, math.random(ARENA.top, ARENA.bottom)
        elseif edge == 3 then
            x, y = math.random(ARENA.left, ARENA.right), ARENA.top
        else
            x, y = math.random(ARENA.left, ARENA.right), ARENA.bottom
        end
    end

    table.insert(self.enemies, {
        kind = kind,
        x = x,
        y = y,
        hp = config.hp,
        maxHp = config.hp,
        speed = config.speed,
        damage = config.damage,
        radius = config.radius,
        size = config.size,
        xp = config.xp,
        sprite = config.sprite,
        boss = config.boss == true,
        hitCooldown = 0,
    })
end

function BattleManager:SpawnProjectile(target, angleOffset)
    if #self.projectiles >= MAX_PROJECTILES then
        return
    end

    local player = self.player
    local dx, dy = Normalize(target.x - player.x, target.y - player.y)
    local baseAngle = math.atan(dy, dx) + angleOffset
    table.insert(self.projectiles, {
        x = player.x,
        y = player.y,
        vx = math.cos(baseAngle) * player.projectileSpeed,
        vy = math.sin(baseAngle) * player.projectileSpeed,
        radius = player.projectileRadius,
        life = player.projectileLife,
        damage = player.damage,
        hitsLeft = player.pierce + 1,
    })
end

function BattleManager:FindNearestEnemy()
    local best = nil
    local bestDistance = math.huge
    local player = self.player
    for index = 1, #self.enemies do
        local enemy = self.enemies[index]
        local dx = enemy.x - player.x
        local dy = enemy.y - player.y
        local distance = dx * dx + dy * dy
        if distance < bestDistance then
            best = enemy
            bestDistance = distance
        end
    end
    return best
end

function BattleManager:Attack()
    local target = self:FindNearestEnemy()
    if not target then
        return
    end

    local count = self.player.projectileCount
    for index = 1, count do
        local offset = (index - (count + 1) / 2) * 0.13
        self:SpawnProjectile(target, offset)
    end
end

function BattleManager:GainXp(amount)
    local player = self.player
    player.xp = player.xp + amount
    if player.xp < player.xpNeeded or self.choosing then
        return
    end

    player.xp = player.xp - player.xpNeeded
    player.level = player.level + 1
    player.xpNeeded = 3 + player.level * 2
    self.pendingChoices = Skills.GetChoices()
    self.choosing = true
end

function BattleManager:ChooseSkill(index)
    if not self.choosing then
        return false
    end
    local skill = self.pendingChoices[index]
    if not skill then
        return false
    end

    skill.apply(self.player)
    table.insert(self.acquiredSkills, skill)
    self.pendingChoices = {}
    self.choosing = false
    return true
end

function BattleManager:DamagePlayer(amount)
    local player = self.player
    player.hp = math.max(0, player.hp - amount * player.damageTaken)
    if player.hp <= 0 then
        self.active = false
        self.result = "defeat"
    end
end

function BattleManager:KillEnemy(index)
    local enemy = self.enemies[index]
    self.kills = self.kills + 1
    table.remove(self.enemies, index)
    if enemy.boss then
        self.active = false
        self.result = "victory"
    else
        self:GainXp(enemy.xp)
    end
end

function BattleManager:UpdateSpawning(timeStep)
    if not self.bossSpawned then
        self.spawnTimer = self.spawnTimer - timeStep
        if self.spawnTimer <= 0 then
            local roll = math.random()
            local kind = roll < 0.48 and "bifang" or (roll < 0.82 and "jiuweihu" or "kui")
            self:SpawnEnemy(kind)
            self.spawnTimer = math.max(0.48, 1.2 - self.elapsed * 0.012)
        end
    end

    if not self.eliteSpawned and self.elapsed >= 24 then
        self.eliteSpawned = true
        self:SpawnEnemy("spring_elite", 960, ARENA.top)
    end

    if not self.bossSpawned and self.elapsed >= 45 then
        self.bossSpawned = true
        if #self.enemies >= MAX_ENEMIES then
            table.remove(self.enemies, #self.enemies)
        end
        self:SpawnEnemy("jumang", 960, 270)
    end
end

function BattleManager:UpdateWarning(timeStep)
    if not self.bossSpawned then
        return
    end

    if self.warning then
        self.warning.timeLeft = self.warning.timeLeft - timeStep
        if self.warning.timeLeft <= 0 then
            if CirclesOverlap(self.player.x, self.player.y, self.player.radius, self.warning.x, self.warning.y, self.warning.radius * 0.72) then
                self:DamagePlayer(34)
            end
            self.warning = nil
            self.warningTimer = 3.2
        end
        return
    end

    self.warningTimer = self.warningTimer - timeStep
    if self.warningTimer <= 0 then
        self.warning = {
            x = Clamp(self.player.x, ARENA.left + 80, ARENA.right - 80),
            y = Clamp(self.player.y, ARENA.top + 80, ARENA.bottom - 80),
            radius = 115,
            timeLeft = 0.9,
        }
    end
end

function BattleManager:UpdateEnemies(timeStep)
    local player = self.player
    for index = #self.enemies, 1, -1 do
        local enemy = self.enemies[index]
        enemy.hitCooldown = math.max(0, enemy.hitCooldown - timeStep)
        local dx, dy = Normalize(player.x - enemy.x, player.y - enemy.y)
        enemy.x = enemy.x + dx * enemy.speed * timeStep
        enemy.y = enemy.y + dy * enemy.speed * timeStep

        if enemy.hitCooldown <= 0 and CirclesOverlap(player.x, player.y, player.radius, enemy.x, enemy.y, enemy.radius) then
            self:DamagePlayer(enemy.damage)
            enemy.hitCooldown = 0.75
            if not self.active then
                return
            end
        end
    end
end

function BattleManager:UpdateProjectiles(timeStep)
    for projectileIndex = #self.projectiles, 1, -1 do
        local projectile = self.projectiles[projectileIndex]
        projectile.x = projectile.x + projectile.vx * timeStep
        projectile.y = projectile.y + projectile.vy * timeStep
        projectile.life = projectile.life - timeStep

        local removeProjectile = projectile.life <= 0
        if not removeProjectile then
            for enemyIndex = #self.enemies, 1, -1 do
                local enemy = self.enemies[enemyIndex]
                if CirclesOverlap(projectile.x, projectile.y, projectile.radius, enemy.x, enemy.y, enemy.radius) then
                    enemy.hp = enemy.hp - projectile.damage
                    projectile.hitsLeft = projectile.hitsLeft - 1
                    if enemy.hp <= 0 then
                        self:KillEnemy(enemyIndex)
                    end
                    if projectile.hitsLeft <= 0 then
                        removeProjectile = true
                        break
                    end
                end
            end
        end

        if removeProjectile then
            table.remove(self.projectiles, projectileIndex)
        end
    end
end

function BattleManager:Update(timeStep, moveX, moveY)
    if not self.active or self.paused or self.choosing then
        return
    end

    local player = self.player
    local dx, dy = Normalize(moveX or 0, moveY or 0)
    player.x = Clamp(player.x + dx * player.moveSpeed * timeStep, ARENA.left, ARENA.right)
    player.y = Clamp(player.y + dy * player.moveSpeed * timeStep, ARENA.top, ARENA.bottom)

    self.elapsed = self.elapsed + timeStep
    self.attackTimer = self.attackTimer - timeStep
    if self.attackTimer <= 0 then
        self:Attack()
        self.attackTimer = player.attackInterval
    end

    self:UpdateSpawning(timeStep)
    self:UpdateWarning(timeStep)
    if not self.active then
        return
    end
    self:UpdateEnemies(timeStep)
    if self.active then
        self:UpdateProjectiles(timeStep)
    end
end

function BattleManager:GetBoss()
    for index = 1, #self.enemies do
        if self.enemies[index].boss then
            return self.enemies[index]
        end
    end
    return nil
end

return BattleManager
