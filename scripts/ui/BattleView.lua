local UI = require("urhox-libs/UI")
local AssetCatalog = require("core.AssetCatalog")
local RuntimePresentation = require("vfx.RuntimePresentation")

local BattleView = {}
BattleView.__index = BattleView

local COLORS = {
    ink = { 12, 21, 19, 235 },
    surface = { 22, 37, 33, 232 },
    bronze = { 184, 143, 76, 255 },
    jade = { 91, 174, 131, 255 },
    pale = { 246, 239, 211, 255 },
    muted = { 181, 190, 171, 255 },
    danger = { 192, 65, 49, 255 },
    projectile = { 245, 211, 100, 255 },
}

local ENEMY_WIDGET_COUNT = 34
local PROJECTILE_WIDGET_COUNT = 56
local DEATH_WIDGET_COUNT = 12

local function TouchButton(text, left, top, direction, touchState)
    return UI.Button {
        position = "absolute",
        left = left,
        top = top,
        width = 82,
        height = 82,
        text = text,
        fontSize = 28,
        variant = "secondary",
        opacity = 0.72,
        onPointerDown = function()
            touchState[direction] = true
        end,
        onPointerUp = function()
            touchState[direction] = false
        end,
        onPointerCancel = function()
            touchState[direction] = false
        end,
    }
end

function BattleView.New(game, onReturnToMenu)
    local self = setmetatable({}, BattleView)
    self.game = game
    self.onReturnToMenu = onReturnToMenu
    self.root = nil
    self.arena = nil
    self.playerWidget = nil
    self.playerShadow = nil
    self.wheelWidgets = {}
    self.enemyWidgets = {}
    self.enemyShadows = {}
    self.eliteRings = {}
    self.projectileWidgets = {}
    self.deathWidgets = {}
    self.touchState = { left = false, right = false, up = false, down = false }
    self.choiceIcons = {}
    self.choiceNames = {}
    self.choiceDescriptions = {}
    self.choiceOverlay = nil
    self.resultOverlay = nil
    self.resultTitle = nil
    self.resultSummary = nil
    self.pauseOverlay = nil
    self.hpBar = nil
    self.xpBar = nil
    self.bossBar = nil
    self.bossPanel = nil
    self.timerLabel = nil
    self.levelLabel = nil
    self.warningWidget = nil
    self.choiceWasVisible = false
    self.visible = false
    return self
end

function BattleView:BuildArena()
    self.arena = UI.Panel {
        position = "absolute",
        left = 0,
        top = 0,
        width = 1920,
        height = 1080,
        backgroundImage = AssetCatalog.environments.spring,
        backgroundFit = "cover",
        overflow = "hidden",
    }

    self.arena:AddChild(UI.Panel {
        position = "absolute",
        left = 0,
        top = 0,
        width = 1920,
        height = 1080,
        backgroundColor = { 8, 18, 14, 52 },
        pointerEvents = "none",
    })

    self.warningWidget = UI.Panel {
        visible = false,
        position = "absolute",
        width = 250,
        height = 250,
        backgroundImage = AssetCatalog.warnings.circle,
        backgroundFit = "contain",
        pointerEvents = "none",
    }
    self.arena:AddChild(self.warningWidget)

    self.playerShadow = UI.Panel {
        position = "absolute",
        width = 90,
        height = 24,
        borderRadius = 12,
        backgroundColor = { 4, 9, 7, 110 },
        pointerEvents = "none",
    }
    self.arena:AddChild(self.playerShadow)

    for index = 1, ENEMY_WIDGET_COUNT do
        local shadow = UI.Panel {
            visible = false,
            position = "absolute",
            borderRadius = 30,
            backgroundColor = { 4, 9, 7, 100 },
            pointerEvents = "none",
        }
        self.enemyShadows[index] = shadow
        self.arena:AddChild(shadow)
    end

    for index = 1, ENEMY_WIDGET_COUNT do
        local ring = UI.Panel {
            visible = false,
            position = "absolute",
            borderColor = COLORS.bronze,
            borderWidth = 5,
            borderRadius = 80,
            backgroundColor = { 184, 143, 76, 28 },
            pointerEvents = "none",
        }
        self.eliteRings[index] = ring
        self.arena:AddChild(ring)
    end

    for index = 1, ENEMY_WIDGET_COUNT do
        local widget = UI.Panel {
            visible = false,
            position = "absolute",
            width = 100,
            height = 100,
            backgroundFit = "contain",
            pointerEvents = "none",
        }
        self.enemyWidgets[index] = widget
        self.arena:AddChild(widget)
    end

    for index = 1, DEATH_WIDGET_COUNT do
        local widget = UI.Panel {
            visible = false,
            position = "absolute",
            backgroundFit = "contain",
            transformOrigin = "center",
            pointerEvents = "none",
        }
        self.deathWidgets[index] = widget
        self.arena:AddChild(widget)
    end

    for index = 1, PROJECTILE_WIDGET_COUNT do
        local widget = UI.Panel {
            visible = false,
            position = "absolute",
            width = 24,
            height = 24,
            borderRadius = 12,
            backgroundColor = COLORS.projectile,
            borderColor = COLORS.pale,
            borderWidth = 2,
            pointerEvents = "none",
        }
        self.projectileWidgets[index] = widget
        self.arena:AddChild(widget)
    end

    local wheelImages = {
        outer = AssetCatalog.wheel.outer,
        marks = AssetCatalog.wheel.marks,
        middle = AssetCatalog.wheel.middle,
        inner = AssetCatalog.wheel.inner,
        core = AssetCatalog.wheel.core,
    }
    local wheelDefinitions = RuntimePresentation.WheelLayers
    for index = 1, #wheelDefinitions do
        local definition = wheelDefinitions[index]
        local widget = UI.Panel {
            position = "absolute",
            width = definition.width,
            height = definition.height,
            backgroundImage = wheelImages[definition.id],
            backgroundFit = "contain",
            transformOrigin = "center",
            opacity = definition.opacity,
            pointerEvents = "none",
        }
        widget.wheelDefinition = definition
        self.wheelWidgets[index] = widget
        self.arena:AddChild(widget)
    end

    self.playerWidget = UI.Panel {
        position = "absolute",
        width = 138,
        height = 190,
        backgroundFit = "contain",
        pointerEvents = "none",
    }
    self.arena:AddChild(self.playerWidget)
    return self.arena
end

function BattleView:BuildHud()
    self.hpBar = UI.ProgressBar {
        value = 100,
        max = 100,
        width = 310,
        height = 22,
        variant = "error",
        showLabel = false,
    }
    self.xpBar = UI.ProgressBar {
        value = 0,
        max = 4,
        width = 310,
        height = 15,
        variant = "success",
        showLabel = false,
    }
    self.levelLabel = UI.Label {
        text = "境界 1",
        fontSize = 18,
        fontColor = COLORS.pale,
    }

    local hud = UI.Panel {
        position = "absolute",
        left = 26,
        top = 22,
        width = 390,
        height = 125,
        padding = 18,
        gap = 8,
        backgroundImage = AssetCatalog.ui.playerStatus,
        backgroundFit = "fill",
        backgroundColor = COLORS.surface,
        borderColor = COLORS.bronze,
        borderWidth = 2,
        borderRadius = 12,
        children = {
            UI.Label {
                text = "四时轮 · 春序",
                fontSize = 21,
                fontWeight = "bold",
                fontColor = COLORS.pale,
            },
            self.hpBar,
            self.xpBar,
            self.levelLabel,
        },
    }

    self.timerLabel = UI.Label {
        position = "absolute",
        left = 820,
        top = 26,
        width = 280,
        text = "立春 00:00",
        fontSize = 26,
        fontWeight = "bold",
        fontColor = COLORS.pale,
        textAlign = "center",
    }

    self.bossBar = UI.ProgressBar {
        value = 100,
        max = 100,
        width = 560,
        height = 22,
        variant = "error",
        showLabel = false,
    }
    self.bossPanel = UI.Panel {
        visible = false,
        position = "absolute",
        left = 650,
        top = 70,
        width = 620,
        height = 76,
        padding = 10,
        alignItems = "center",
        backgroundImage = AssetCatalog.ui.bossBar,
        backgroundFit = "fill",
        backgroundColor = COLORS.surface,
        children = {
            UI.Label {
                text = "春神 · 句芒（浊化）",
                fontSize = 20,
                fontWeight = "bold",
                fontColor = COLORS.pale,
                textAlign = "center",
            },
            self.bossBar,
        },
    }

    return { hud, self.timerLabel, self.bossPanel }
end

function BattleView:BuildChoices()
    local cards = {}
    for index = 1, 3 do
        local icon = UI.Panel {
            width = 128,
            height = 128,
            backgroundFit = "contain",
            pointerEvents = "none",
        }
        local name = UI.Label {
            text = "节气之力",
            width = "100%",
            fontSize = 25,
            fontWeight = "bold",
            fontColor = COLORS.pale,
            textAlign = "center",
            pointerEvents = "none",
        }
        local description = UI.Label {
            text = "选择后继续行歌",
            width = "100%",
            minHeight = 62,
            fontSize = 17,
            fontColor = COLORS.muted,
            textAlign = "center",
            whiteSpace = "normal",
            pointerEvents = "none",
        }
        self.choiceIcons[index] = icon
        self.choiceNames[index] = name
        self.choiceDescriptions[index] = description

        cards[index] = UI.Button {
            width = 310,
            height = 430,
            padding = 30,
            gap = 18,
            flexDirection = "column",
            justifyContent = "center",
            alignItems = "center",
            backgroundImage = AssetCatalog.ui.choiceCard,
            backgroundFit = "fill",
            backgroundColor = COLORS.surface,
            borderColor = COLORS.bronze,
            borderWidth = 2,
            borderRadius = 18,
            onClick = function()
                self.game:ChooseSkill(index)
            end,
            children = { icon, name, description },
        }
    end

    self.choiceOverlay = UI.Panel {
        visible = false,
        position = "absolute",
        left = 0,
        top = 0,
        width = 1920,
        height = 1080,
        paddingTop = 160,
        alignItems = "center",
        backgroundColor = { 7, 13, 12, 218 },
        children = {
            UI.Label {
                text = "节候共鸣",
                fontSize = 42,
                fontWeight = "bold",
                fontColor = COLORS.pale,
                textAlign = "center",
            },
            UI.Label {
                text = "择一节气之力，校准四时轮",
                marginTop = 8,
                marginBottom = 34,
                fontSize = 19,
                fontColor = COLORS.jade,
                textAlign = "center",
            },
            UI.Panel {
                width = 1010,
                height = 450,
                flexDirection = "row",
                justifyContent = "space-between",
                children = cards,
            },
        },
    }
    return self.choiceOverlay
end

function BattleView:BuildResult()
    self.resultTitle = UI.Label {
        text = "春序已定",
        fontSize = 48,
        fontWeight = "bold",
        fontColor = COLORS.pale,
        textAlign = "center",
    }
    self.resultSummary = UI.Label {
        text = "",
        marginTop = 16,
        marginBottom = 28,
        fontSize = 20,
        fontColor = COLORS.muted,
        textAlign = "center",
        whiteSpace = "normal",
    }
    self.resultOverlay = UI.Panel {
        visible = false,
        position = "absolute",
        left = 0,
        top = 0,
        width = 1920,
        height = 1080,
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = { 6, 13, 11, 220 },
        children = {
            UI.Panel {
                width = 620,
                padding = 48,
                alignItems = "center",
                backgroundColor = COLORS.surface,
                borderColor = COLORS.bronze,
                borderWidth = 3,
                borderRadius = 22,
                children = {
                    self.resultTitle,
                    self.resultSummary,
                    UI.Button {
                        width = 300,
                        height = 64,
                        text = "再入春境",
                        variant = "primary",
                        fontSize = 22,
                        onClick = function()
                            self.game:RestartRun()
                            self.resultOverlay:SetVisible(false)
                        end,
                    },
                    UI.Button {
                        width = 300,
                        height = 56,
                        marginTop = 14,
                        text = "返回行歌台",
                        variant = "secondary",
                        fontSize = 20,
                        onClick = function()
                            self.game:ReturnToMenu()
                            self:Hide()
                            if self.onReturnToMenu then
                                self.onReturnToMenu()
                            end
                        end,
                    },
                },
            },
        },
    }
    return self.resultOverlay
end

function BattleView:Build()
    local hudChildren = self:BuildHud()
    self.pauseOverlay = UI.Panel {
        visible = false,
        position = "absolute",
        left = 0,
        top = 0,
        width = 1920,
        height = 1080,
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = { 4, 9, 8, 150 },
        pointerEvents = "none",
        children = {
            UI.Label {
                text = "行歌暂歇\n按 ESC 继续",
                fontSize = 36,
                fontColor = COLORS.pale,
                textAlign = "center",
                whiteSpace = "normal",
            },
        },
    }

    self.root = UI.Panel {
        id = "battleView",
        visible = false,
        position = "absolute",
        left = 0,
        top = 0,
        width = 1920,
        height = 1080,
        backgroundColor = COLORS.ink,
        children = {
            self:BuildArena(),
            hudChildren[1],
            hudChildren[2],
            hudChildren[3],
            UI.Button {
                position = "absolute",
                right = 28,
                top = 28,
                width = 120,
                height = 52,
                text = "暂停",
                variant = "secondary",
                onClick = function()
                    self.game:TogglePause()
                end,
            },
            TouchButton("←", 92, 876, "left", self.touchState),
            TouchButton("→", 266, 876, "right", self.touchState),
            TouchButton("↑", 179, 789, "up", self.touchState),
            TouchButton("↓", 179, 963, "down", self.touchState),
            self.pauseOverlay,
            self:BuildChoices(),
            self:BuildResult(),
        },
    }
    return self.root
end

function BattleView:Show()
    local battle = self.game.battleManager
    local characterId = battle.run and battle.run.characterId or "shi_yu_zhe"
    self.playerWidget:SetStyle({ backgroundImage = AssetCatalog.characters[characterId] })
    self.choiceWasVisible = false
    self.resultOverlay:SetVisible(false)
    self.root:SetVisible(true)
    self.visible = true
end

function BattleView:Hide()
    self.root:SetVisible(false)
    self.visible = false
end

function BattleView:GetMovement()
    local left = input:GetKeyDown(KEY_A) or input:GetKeyDown(KEY_LEFT) or self.touchState.left
    local right = input:GetKeyDown(KEY_D) or input:GetKeyDown(KEY_RIGHT) or self.touchState.right
    local up = input:GetKeyDown(KEY_W) or input:GetKeyDown(KEY_UP) or self.touchState.up
    local down = input:GetKeyDown(KEY_S) or input:GetKeyDown(KEY_DOWN) or self.touchState.down
    return (right and 1 or 0) - (left and 1 or 0), (down and 1 or 0) - (up and 1 or 0)
end

function BattleView:UpdatePools()
    local battle = self.game.battleManager
    for index = 1, ENEMY_WIDGET_COUNT do
        local widget = self.enemyWidgets[index]
        local shadowWidget = self.enemyShadows[index]
        local ringWidget = self.eliteRings[index]
        local enemy = battle.enemies[index]
        if enemy then
            local motion = RuntimePresentation.Enemy(enemy.kind, battle.elapsed, enemy.visualPhase)
            local hit = enemy.hitElapsed and RuntimePresentation.Hit(enemy.hitElapsed, 0.16) or nil
            local visualY = enemy.y + motion.offsetY
            widget:SetStyle({
                left = enemy.x - enemy.size * 0.5,
                top = visualY - enemy.size * 0.5,
                width = enemy.size,
                height = enemy.size,
                backgroundImage = enemy.sprite,
                rotate = motion.rotation + (enemy.facing == "left" and -1.5 or 1.5),
                scale = hit and hit.scale or 1,
            })
            widget:SetVisible(true)

            local elevation = enemy.kind == "bifang" and 0.72 or 0.08
            local shadow = RuntimePresentation.Shadow(enemy.size, elevation)
            shadowWidget:SetStyle({
                left = enemy.x - shadow.width * 0.5,
                top = enemy.y + shadow.offsetY - shadow.height * 0.5,
                width = shadow.width,
                height = shadow.height,
                borderRadius = shadow.height * 0.5,
                opacity = shadow.opacity,
            })
            shadowWidget:SetVisible(true)

            local elite = enemy.kind == "spring_elite"
            if elite then
                local ringSize = enemy.size * (1.08 + math.abs(math.sin(battle.elapsed * 3.2)) * 0.08)
                ringWidget:SetStyle({
                    left = enemy.x - ringSize * 0.5,
                    top = enemy.y - ringSize * 0.5,
                    width = ringSize,
                    height = ringSize,
                    borderRadius = ringSize * 0.5,
                    opacity = 0.72,
                })
            end
            ringWidget:SetVisible(elite)
        else
            widget:SetVisible(false)
            shadowWidget:SetVisible(false)
            ringWidget:SetVisible(false)
        end
    end

    for index = 1, PROJECTILE_WIDGET_COUNT do
        local widget = self.projectileWidgets[index]
        local projectile = battle.projectiles[index]
        if projectile then
            local size = projectile.radius * 2
            widget:SetStyle({
                left = projectile.x - projectile.radius,
                top = projectile.y - projectile.radius,
                width = size,
                height = size,
                borderRadius = projectile.radius,
            })
            widget:SetVisible(true)
        else
            widget:SetVisible(false)
        end
    end

    for index = 1, DEATH_WIDGET_COUNT do
        local widget = self.deathWidgets[index]
        local effect = battle.deathEffects[index]
        if effect then
            local visual = RuntimePresentation.Death(effect.elapsed, effect.duration)
            widget:SetStyle({
                left = effect.x - effect.size * 0.5,
                top = effect.y - effect.size * 0.5 + visual.offsetY,
                width = effect.size,
                height = effect.size,
                backgroundImage = effect.sprite,
                opacity = visual.opacity,
                scale = visual.scale,
            })
            widget:SetVisible(true)
        else
            widget:SetVisible(false)
        end
    end
end

function BattleView:UpdatePlayer()
    local battle = self.game.battleManager
    local player = battle.player
    if not player then
        return
    end

    local playerWidth = 138
    local playerHeight = 190
    local idle = RuntimePresentation.Player(battle.elapsed, player.isMoving)
    local hit = player.hitElapsed and RuntimePresentation.Hit(player.hitElapsed, 0.16) or nil
    self.playerWidget:SetStyle({
        left = player.x - playerWidth * 0.5,
        top = player.y - playerHeight * 0.62 + idle.offsetY,
        rotate = idle.rotation + (player.facing == "left" and -1.2 or 1.2),
        scale = hit and hit.scale or 1,
    })

    local shadow = RuntimePresentation.Shadow(playerWidth, 0.06)
    self.playerShadow:SetStyle({
        left = player.x - shadow.width * 0.5,
        top = player.y + shadow.offsetY - shadow.height * 0.5,
        width = shadow.width,
        height = shadow.height,
        borderRadius = shadow.height * 0.5,
        opacity = shadow.opacity,
    })

    local wheelVisuals = RuntimePresentation.Wheel(battle.elapsed, battle.attackPulse)
    for index = 1, #self.wheelWidgets do
        local widget = self.wheelWidgets[index]
        local definition = widget.wheelDefinition
        local visual = wheelVisuals[index]
        widget:SetStyle({
            left = player.x - definition.width * 0.5 + visual.offsetX,
            top = player.y - definition.height * 0.5 + visual.offsetY,
            rotate = visual.rotation,
            opacity = visual.opacity,
            scale = visual.scale,
        })
    end

    self.hpBar:SetMax(player.maxHp)
    self.hpBar:SetValue(player.hp)
    self.xpBar:SetMax(player.xpNeeded)
    self.xpBar:SetValue(player.xp)
    self.levelLabel:SetText(string.format("境界 %d｜净化 %d", player.level, battle.kills))

    local minutes = math.floor(battle.elapsed / 60)
    local seconds = math.floor(battle.elapsed % 60)
    local phase = battle.bossSpawned and "春神现世" or (battle.eliteSpawned and "惊蛰" or "立春")
    self.timerLabel:SetText(string.format("%s %02d:%02d", phase, minutes, seconds))
end

function BattleView:UpdateBossAndWarning()
    local battle = self.game.battleManager
    local boss = battle:GetBoss()

    if boss and boss.boss then
        self.bossBar:SetMax(boss.maxHp)
        self.bossBar:SetValue(boss.hp)
        self.bossPanel:SetVisible(true)
    else
        self.bossPanel:SetVisible(false)
    end

    local warning = battle.warning
    if warning then
        local size = warning.radius * 2
        self.warningWidget:SetStyle({
            left = warning.x - warning.radius,
            top = warning.y - warning.radius,
            width = size,
            height = size,
            opacity = 0.5 + math.abs(math.sin(warning.timeLeft * 18)) * 0.5,
        })
        self.warningWidget:SetVisible(true)
    else
        self.warningWidget:SetVisible(false)
    end
end

function BattleView:UpdateOverlays()
    local battle = self.game.battleManager
    if battle.choosing and not self.choiceWasVisible then
        for index = 1, 3 do
            local skill = battle.pendingChoices[index]
            self.choiceIcons[index]:SetStyle({ backgroundImage = skill.icon })
            self.choiceNames[index]:SetText(skill.name)
            self.choiceDescriptions[index]:SetText(skill.description)
        end
    end
    self.choiceOverlay:SetVisible(battle.choosing)
    self.choiceWasVisible = battle.choosing
    self.pauseOverlay:SetVisible(battle.paused)

    if battle.result then
        local victory = battle.result == "victory"
        self.resultTitle:SetText(victory and "春序已定" or "四时轮失衡")
        self.resultSummary:SetText(string.format(
            "%s\n坚持 %d 秒｜净化 %d 个浊灵｜境界 %d",
            victory and "句芒浊气已净化，春令归位。" or "暂避浊潮，重新校准四时轮。",
            math.floor(battle.elapsed),
            battle.kills,
            battle.player.level
        ))
        self.resultOverlay:SetVisible(true)
    end
end

function BattleView:Update(timeStep)
    if not self.root or not self.visible then
        return
    end

    local moveX, moveY = self:GetMovement()
    self.game:Update(timeStep, moveX, moveY)
    self:UpdatePools()
    self:UpdatePlayer()
    self:UpdateBossAndWarning()
    self:UpdateOverlays()
end

return BattleView
