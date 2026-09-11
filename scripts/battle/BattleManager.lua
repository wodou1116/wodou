local AssetCatalog = require("core.AssetCatalog")
local EventBus = require("core.EventBus")
local Logger = require("core.Logger")
local Skills = require("data.Skills")
local AnimationState = require("animation.AnimationState")
local BattleBounds = require("battle.BattleBounds")
local EnemyMotion = require("battle.enemies.EnemyMotion")
local PlayerFacing = require("battle.player.PlayerFacing")
local PlayerMover = require("battle.player.PlayerMover")
local TargetSelector = require("battle.player.TargetSelector")
local AttackLogic = require("combat.AttackLogic")
local CombatEvents = require("combat.CombatEvents")
local DamageContext = require("combat.DamageContext")
local DeathContext = require("combat.DeathContext")
local ProjectileSystem = require("combat.ProjectileSystem")
local StatSystem = require("combat.StatSystem")

local BattleManager = {}
BattleManager.__index = BattleManager

local ARENA = BattleBounds.DEFAULT
local MAX_ENEMIES = 34
local MAX_PROJECTILES = 56
local MAX_IMPACTS = 24
local DEBUG_RING_POSITIONS

local CAPTURE_ANIMATION_STATES = {
    idle = AnimationState.States.Idle,
    move = AnimationState.States.Move,
    hit = AnimationState.States.Hit,
    death = AnimationState.States.Death,
}

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

function BattleManager.New(eventBus)
    local self = setmetatable({}, BattleManager)
    self:Init(eventBus)
    return self
end

function BattleManager:Init(eventBus)
    self.eventBus = eventBus or EventBus.New()
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
    self.projectileSystem = ProjectileSystem.New({ capacity = MAX_PROJECTILES })
    self.projectiles = self.projectileSystem.active
    self.deathEffects = {}
    self.impacts = {}
    self.pendingChoices = {}
    self.acquiredSkills = {}
    self.kills = 0
    self.spawnSerial = 0
    self.attackPulse = 0
    self.wheelState = nil
    self.player = nil
    self.finishing = false
    self.pendingResult = nil
    self.resultDelay = 0
    self.debugScenario = nil
    self.debugFreezeSpawning = false
    self.debugFreezeEnemyPositions = false
    self.debugProjectileTarget = nil
    self.debugEnemyTarget = nil
    self.debugInvulnerable = false
    self.captureMode = nil
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
    self.projectileSystem:Clear()
    self.projectiles = self.projectileSystem.active
    self.deathEffects = {}
    self.impacts = {}
    self.pendingChoices = {}
    self.acquiredSkills = {}
    self.kills = 0
    self.spawnSerial = 0
    self.attackPulse = 0
    self.wheelState = nil
    self.finishing = false
    self.pendingResult = nil
    self.resultDelay = 0
    self.debugScenario = nil
    self.debugFreezeSpawning = false
    self.debugFreezeEnemyPositions = false
    self.debugProjectileTarget = nil
    self.debugEnemyTarget = nil
    self.debugInvulnerable = false
    self.captureMode = nil

    local characterId = self.run and self.run.characterId or "shi_yu_zhe"
    local statSystem = StatSystem.New({
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
        attackRange = 760,
    })
    self.player = {
        id = "player",
        team = "player",
        x = 960,
        y = 640,
        radius = 40,
        hp = 120,
        statSystem = statSystem,
        level = 1,
        xp = 0,
        xpNeeded = 4,
        facing = "right",
        facingX = 1,
        moveX = 0,
        moveY = 0,
        isMoving = false,
        animation = AnimationState.New(),
        hitElapsed = nil,
        deathElapsed = nil,
    }
    local stats = statSystem:GetAll()
    for statName, value in pairs(stats) do
        self.player[statName] = value
    end
    self.attackLogic = AttackLogic.New(self.player.attackInterval, self.attackTimer)
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
        local edgeNames = { "left", "right", "top", "bottom" }
        local edge = edgeNames[math.random(#edgeNames)]
        local lane = (edge == "left" or edge == "right")
            and math.random(ARENA.top, ARENA.bottom)
            or math.random(ARENA.left, ARENA.right)
        local entry = BattleBounds.GetEnemyEntry(ARENA, edge, lane, config.radius, 30)
        x, y = entry.spawnX, entry.spawnY
    end

    self.spawnSerial = self.spawnSerial + 1
    local enemyStats = StatSystem.New({
        maxHp = config.hp,
        speed = config.speed,
        damage = config.damage,
        armor = config.armor or 0,
        damageTaken = config.damageTaken or 1,
    })
    local motion = nil
    if kind == "bifang" or kind == "jiuweihu" or kind == "kui" then
        motion = EnemyMotion.New(kind, self.spawnSerial)
    end

    table.insert(self.enemies, {
        id = kind .. "#" .. tostring(self.spawnSerial),
        team = "enemy",
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
        statSystem = enemyStats,
        armor = enemyStats:Get("armor"),
        damageTaken = enemyStats:Get("damageTaken"),
        hitCooldown = 0,
        facing = x < self.player.x and "right" or "left",
        motion = motion,
        motionState = "idle",
        animation = AnimationState.New(),
        hitElapsed = nil,
        visualPhase = self.spawnSerial * 0.173,
    })
end

function BattleManager:SpawnProjectile(target, angleOffset)
    local player = self.player
    local dx, dy = Normalize(target.x - player.x, target.y - player.y)
    local baseAngle = math.atan(dy, dx) + angleOffset
    local projectile = self.projectileSystem:Spawn({
        source = player,
        team = player.team,
        x = player.x,
        y = player.y,
        vx = math.cos(baseAngle) * player.projectileSpeed,
        vy = math.sin(baseAngle) * player.projectileSpeed,
        radius = player.projectileRadius,
        life = player.projectileLife,
        maxLife = player.projectileLife,
        damage = player.damage,
        hitsLeft = player.pierce + 1,
        hitIds = {},
    })
    if not projectile then
        return nil
    end
    self.attackPulse = 0.18
    self.eventBus:Emit(CombatEvents.PROJECTILE_SPAWNED, projectile)
    return projectile
end

function BattleManager:FindNearestEnemy()
    return TargetSelector.FindNearest(self.player, self.enemies, {
        maxRange = self.player.attackRange,
        isValid = function(enemy)
            return enemy.hp > 0
        end,
    })
end

function BattleManager:Attack()
    local target = self:FindNearestEnemy()
    if not target then
        return false
    end

    PlayerFacing.FaceAttack(self.player, target.x - self.player.x, target.y - self.player.y)

    local count = self.player.projectileCount
    for index = 1, count do
        local offset = (index - (count + 1) / 2) * 0.13
        self:SpawnProjectile(target, offset)
    end
    return true
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

    Skills.Apply(skill, self.player, skill.id .. "#" .. tostring(#self.acquiredSkills + 1))
    AttackLogic.SetInterval(self.attackLogic, self.player.attackInterval)
    table.insert(self.acquiredSkills, skill)
    self.pendingChoices = {}
    self.choosing = false
    return true
end

function BattleManager:DamagePlayer(amount, source)
    local player = self.player
    if player.hp <= 0 then
        return nil
    end
    if self.debugInvulnerable then
        player.hitElapsed = 0
        player.animation:Hit()
        return nil
    end
    local context = DamageContext.New({
        source = source,
        target = player,
        amount = amount,
        kind = "contact",
    })
    local resolved = DamageContext.Resolve(context, player.statSystem)
    DamageContext.Apply(resolved)
    self.eventBus:Emit(CombatEvents.DAMAGE_RESOLVED, resolved)
    player.hitElapsed = 0
    player.animation:Hit()
    if player.hp <= 0 then
        player.animation:Die()
        player.deathElapsed = 0
        self.eventBus:Emit(CombatEvents.ENTITY_DIED, DeathContext.New({
            victim = player,
            killer = source,
            damage = resolved,
            reason = "damage",
            position = { x = player.x, y = player.y },
        }))
        self:BeginFinish("defeat", 0.65)
    end
    return resolved
end

function BattleManager:BeginFinish(result, delay)
    self.active = false
    self.finishing = true
    self.pendingResult = result
    self.resultDelay = delay or 0
end

function BattleManager:AddImpact(x, y, radius, kind)
    if #self.impacts >= MAX_IMPACTS then
        table.remove(self.impacts, 1)
    end
    table.insert(self.impacts, {
        x = x,
        y = y,
        radius = radius or 18,
        kind = kind or "hit",
        elapsed = 0,
        duration = 0.18,
    })
end

function BattleManager:KillEnemy(index, damage)
    local enemy = self.enemies[index]
    enemy.animation:Die()
    table.insert(self.deathEffects, {
        x = enemy.x,
        y = enemy.y,
        size = enemy.size,
        sprite = enemy.sprite,
        elapsed = 0,
        duration = enemy.boss and 0.55 or 0.34,
        kind = enemy.kind,
        facing = enemy.facing,
    })
    self.kills = self.kills + 1
    self.eventBus:Emit(CombatEvents.ENTITY_DIED, DeathContext.New({
        victim = enemy,
        killer = damage and damage.source or self.player,
        damage = damage,
        reason = damage and "damage" or "scripted",
        rewards = { xp = enemy.xp },
        position = { x = enemy.x, y = enemy.y },
    }))
    table.remove(self.enemies, index)
    if enemy.boss then
        self:BeginFinish("victory", 0.62)
    elseif not self.debugFreezeSpawning then
        self:GainXp(enemy.xp)
    end
end

function BattleManager:UpdateSpawning(timeStep)
    if self.debugFreezeSpawning then
        return
    end
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
                self:DamagePlayer(34, { id = "boss_warning", team = "enemy" })
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
        if enemy.hitElapsed then
            enemy.hitElapsed = enemy.hitElapsed + timeStep
            if enemy.hitElapsed >= 0.16 then
                enemy.hitElapsed = nil
            end
        end

        if enemy.motion then
            local command = EnemyMotion.Step(enemy.motion, enemy, player, timeStep)
            if not self.debugFreezeEnemyPositions then
                enemy.x = command.x
                enemy.y = command.y
            end
            enemy.facing = command.facing
            enemy.facingX = command.facingX
            enemy.motionState = command.motionState
            enemy.elevation = command.elevation
            enemy.step = command.step
            enemy.lean = command.lean
        else
            local dx, dy = Normalize(player.x - enemy.x, player.y - enemy.y)
            enemy.x = enemy.x + dx * enemy.speed * timeStep
            enemy.y = enemy.y + dy * enemy.speed * timeStep
            enemy.facing = dx >= 0 and "right" or "left"
            enemy.motionState = "press"
        end
        enemy.animation:Update(timeStep, true)

        if enemy.hitCooldown <= 0 and CirclesOverlap(player.x, player.y, player.radius, enemy.x, enemy.y, enemy.radius) then
            self:DamagePlayer(enemy.damage, enemy)
            enemy.hitCooldown = 0.75
            if not self.active then
                return
            end
        end
    end
end

function BattleManager:UpdateProjectiles(timeStep)
    self.projectileSystem:Update(timeStep, {
        isOutOfBounds = function(projectile)
            return BattleBounds.ShouldRecycleProjectile(ARENA, projectile.x, projectile.y, projectile.radius, 180)
        end,
        queryHit = function(projectile)
            for enemyIndex = #self.enemies, 1, -1 do
                local enemy = self.enemies[enemyIndex]
                local alreadyHit = projectile.hitIds and projectile.hitIds[enemy.id]
                if not alreadyHit and CirclesOverlap(
                    projectile.x, projectile.y, projectile.radius,
                    enemy.x, enemy.y, enemy.radius
                ) then
                    return enemy, enemyIndex
                end
            end
            return nil
        end,
        onHit = function(projectile, enemy, enemyIndex)
            local impactKind = enemy.boss and "boss"
                or (enemy.kind == "spring_elite" and "elite" or "projectile")
            self:AddImpact(projectile.x, projectile.y, projectile.radius * 1.8, impactKind)
            local context = DamageContext.New({
                source = projectile.source or self.player,
                target = enemy,
                amount = projectile.damage,
                kind = "projectile",
                tags = { "basic_attack" },
                metadata = { projectile = projectile },
            })
            local resolved = DamageContext.Resolve(context, enemy.statSystem or enemy)
            DamageContext.Apply(resolved)
            self.eventBus:Emit(CombatEvents.DAMAGE_RESOLVED, resolved)
            enemy.hitElapsed = 0
            enemy.animation:Hit()
            projectile.hitIds = projectile.hitIds or {}
            projectile.hitIds[enemy.id] = true
            projectile.hitsLeft = projectile.hitsLeft - 1
            if enemy.hp <= 0 then
                self:KillEnemy(enemyIndex, resolved)
            end
            return projectile.hitsLeft > 0
        end,
    })
end

function BattleManager:MaintainDebugStress()
    if not self.debugEnemyTarget or not self.debugProjectileTarget then
        return
    end

    local kinds = { "bifang", "jiuweihu", "kui" }
    while #self.enemies < self.debugEnemyTarget do
        local index = #self.enemies + 1
        local position = DEBUG_RING_POSITIONS[index]
        self:SpawnEnemy(kinds[(index - 1) % #kinds + 1], position[1], position[2])
    end

    local target = self.enemies[(self.spawnSerial % #self.enemies) + 1]
    while #self.projectiles > self.debugProjectileTarget do
        self.projectileSystem:ReleaseAt(#self.projectiles)
    end
    while #self.projectiles < self.debugProjectileTarget do
        local index = #self.projectiles + 1
        self:SpawnProjectile(target, (index - (self.debugProjectileTarget + 1) * 0.5) * 0.055)
    end
end

function BattleManager:UpdateImpacts(timeStep)
    for index = #self.impacts, 1, -1 do
        local impact = self.impacts[index]
        impact.elapsed = impact.elapsed + timeStep
        if impact.elapsed >= impact.duration then
            table.remove(self.impacts, index)
        end
    end
end

function BattleManager:UpdateDeathEffects(timeStep)
    for index = #self.deathEffects, 1, -1 do
        local effect = self.deathEffects[index]
        effect.elapsed = effect.elapsed + timeStep
        if effect.elapsed >= effect.duration then
            table.remove(self.deathEffects, index)
        end
    end
end

function BattleManager:Update(timeStep, moveX, moveY)
    if self.captureMode and self.captureMode:IsFrozen() then
        self:ApplyCapturePose()
        return
    end
    if self.finishing then
        self.resultDelay = math.max(0, self.resultDelay - timeStep)
        self.attackPulse = math.max(0, self.attackPulse - timeStep)
        if self.player and self.player.deathElapsed then
            self.player.deathElapsed = self.player.deathElapsed + timeStep
            self.player.animation:Update(timeStep, false)
        end
        self:UpdateDeathEffects(timeStep)
        self:UpdateImpacts(timeStep)
        if self.resultDelay <= 0 then
            self.result = self.pendingResult
            self.pendingResult = nil
            self.finishing = false
        end
        return
    end
    if not self.active or self.paused or self.choosing then
        return
    end

    local player = self.player
    local directionX, directionY = PlayerMover.Update(player, moveX, moveY, timeStep, ARENA)
    PlayerFacing.Update(player, directionX, directionY)
    if player.hitElapsed then
        player.hitElapsed = player.hitElapsed + timeStep
        if player.hitElapsed >= 0.16 then
            player.hitElapsed = nil
        end
    end
    player.animation:Update(timeStep, player.isMoving)

    self.elapsed = self.elapsed + timeStep
    self.attackPulse = math.max(0, self.attackPulse - timeStep)
    self:UpdateDeathEffects(timeStep)
    self:UpdateImpacts(timeStep)
    AttackLogic.SetInterval(self.attackLogic, player.attackInterval)
    AttackLogic.Step(self.attackLogic, timeStep, true, function()
        return self:Attack()
    end)
    self.attackTimer = self.attackLogic.cooldown

    self:UpdateSpawning(timeStep)
    self:UpdateWarning(timeStep)
    if not self.active then
        return
    end
    self:UpdateEnemies(timeStep)
    if self.active then
        self:UpdateProjectiles(timeStep)
        self:MaintainDebugStress()
    end
end


DEBUG_RING_POSITIONS = {
    { 520, 330 }, { 760, 300 }, { 1000, 300 }, { 1240, 330 }, { 1440, 410 },
    { 1510, 590 }, { 1450, 760 }, { 1230, 850 }, { 990, 875 }, { 750, 850 },
    { 520, 770 }, { 420, 600 }, { 470, 470 }, { 680, 450 }, { 900, 430 },
    { 1120, 450 }, { 1320, 500 }, { 1300, 690 }, { 1050, 720 }, { 760, 700 },
}

function BattleManager:ConfigureDebugScenario(mode, projectileCount, captureMode)
    assert(self.player, "debug scenario requires a prepared battle")
    local scenarioName = mode
    self.active = true
    self.paused = false
    self.choosing = false
    self.result = nil
    self.finishing = false
    self.pendingResult = nil
    self.enemies = {}
    self.projectileSystem:Clear()
    self.projectiles = self.projectileSystem.active
    self.deathEffects = {}
    self.impacts = {}
    self.captureMode = captureMode
    self.debugFreezeSpawning = true
    self.debugFreezeEnemyPositions = (captureMode and captureMode:IsFrozen())
        or (mode ~= "combat_stress" and mode ~= "motion")
    self.debugProjectileTarget = nil
    self.debugEnemyTarget = nil
    self.debugInvulnerable = false
    self.elapsed = 0
    self.attackTimer = 999999
    self.attackLogic = AttackLogic.New(self.player.attackInterval, self.attackTimer)
    self.attackPulse = 0
    self.eliteSpawned = false
    self.bossSpawned = false
    self.warning = nil
    self.warningTimer = 3.5
    self.player.x = 960
    self.player.y = 640
    self.player.hp = self.player.maxHp
    self.player.hitElapsed = nil
    self.player.deathElapsed = nil
    self.player.animation = AnimationState.New()

    if mode == "single" then
        self.debugInvulnerable = true
        self:SpawnEnemy("jiuweihu", 1180, 620)
    elseif mode == "peer_comparison" then
        self.debugInvulnerable = true
        local kinds = { "bifang", "jiuweihu", "kui" }
        for group = 1, 3 do
            for index = 1, 4 do
                self:SpawnEnemy(kinds[group], 570 + (group - 1) * 390 + ((index - 1) % 2) * 105,
                    360 + math.floor((index - 1) / 2) * 150)
            end
        end
        self:SpawnEnemy("spring_elite", 785, 805)
        self:SpawnEnemy("spring_elite", 1135, 805)
        self.eliteSpawned = true
    elseif mode == "boss" then
        self.debugInvulnerable = true
        self:SpawnEnemy("bifang", 520, 500)
        self:SpawnEnemy("jiuweihu", 650, 760)
        self:SpawnEnemy("kui", 1250, 760)
        self:SpawnEnemy("spring_elite", 1510, 650)
        self:SpawnEnemy("jumang", 1240, 350)
        self.bossSpawned = true
    elseif mode == "motion" then
        self.debugInvulnerable = true
        self:SpawnEnemy("jiuweihu", 1270, 460)
        self:SpawnEnemy("bifang", 1090, 780)
        self:SpawnEnemy("kui", 650, 710)
    elseif mode == "combat_stress" then
        self.debugInvulnerable = true
        local kinds = { "bifang", "jiuweihu", "kui" }
        for index = 1, #DEBUG_RING_POSITIONS do
            local position = DEBUG_RING_POSITIONS[index]
            self:SpawnEnemy(kinds[(index - 1) % #kinds + 1], position[1], position[2])
        end
        local count = math.max(0, math.min(MAX_PROJECTILES, projectileCount or 35))
        self.debugEnemyTarget = #DEBUG_RING_POSITIONS
        self.debugProjectileTarget = count
        local target = self.enemies[1]
        for index = 1, count do
            self:SpawnProjectile(target, (index - (count + 1) * 0.5) * 0.035)
        end
        scenarioName = "combat_stress_" .. tostring(count)
        self:MaintainDebugStress()
    else
        error("unknown debug scenario: " .. tostring(mode))
    end

    self.debugScenario = scenarioName
    if self.captureMode then
        self:ApplyCapturePose()
        self:UpdateCaptureMetadata()
    end
    return self.debugScenario
end

function BattleManager:ConfigureCapture(captureMode)
    assert(captureMode and captureMode:IsEnabled(), "configured QA capture mode is required")
    return self:ConfigureDebugScenario(captureMode:GetMode(), captureMode:GetProjectileCount(), captureMode)
end

function BattleManager:ApplyCapturePose()
    if not self.captureMode then
        return
    end

    self.elapsed = self.captureMode:GetPresentationTime()
    local state = self.captureMode:GetStateMetadata() or {}
    self.wheelState = state.wheelState

    local function ApplyFacing(entity, facing)
        if entity and (facing == "left" or facing == "right") then
            entity.facing = facing
            entity.facingX = facing == "left" and -1 or 1
        end
    end

    local function ApplyAnimationState(entity, requestedState)
        if not entity or not requestedState then
            return
        end
        local normalized = string.lower(tostring(requestedState))
        local animationState = CAPTURE_ANIMATION_STATES[normalized]
        assert(animationState, "unknown QA animation state: " .. tostring(requestedState))
        entity.animation:Set(animationState)
        entity.isMoving = animationState == AnimationState.States.Move
        entity.hitElapsed = animationState == AnimationState.States.Hit and 0 or nil
        entity.deathElapsed = animationState == AnimationState.States.Death and 0 or nil
    end

    ApplyFacing(self.player, state.playerFacing)
    ApplyAnimationState(self.player, state.playerAnimationState or state.animationState)
    for index = 1, #self.enemies do
        ApplyFacing(self.enemies[index], state.enemyFacing)
        ApplyAnimationState(self.enemies[index], state.enemyAnimationState)
    end

    local phase = self.captureMode:GetAnimationPhase()
    if phase == nil then
        self:UpdateCaptureMetadata()
        return
    end

    local function ApplyAnimationPose(animation)
        if animation then
            local duration = animation:Get() == AnimationState.States.Death and 0.65 or animation.hitDuration
            animation.time = duration * phase
        end
    end

    if self.player then
        ApplyAnimationPose(self.player.animation)
    end
    for index = 1, #self.enemies do
        ApplyAnimationPose(self.enemies[index].animation)
    end
    self:UpdateCaptureMetadata()
end

function BattleManager:UpdateCaptureMetadata()
    if not self.captureMode then
        return
    end
    self.captureMode:SetStateMetadata({
        scenario = self.debugScenario,
        elapsed = self.elapsed,
        enemyCount = #self.enemies,
        projectileCount = #self.projectiles,
        player = self.player and { x = self.player.x, y = self.player.y, hp = self.player.hp } or nil,
    })
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
