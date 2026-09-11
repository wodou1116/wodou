local UI = require("urhox-libs/UI")
local AssetCatalog = require("core.AssetCatalog")
local ProjectilePresentation = require("vfx.ProjectilePresentation")
local RuntimePresentation = require("vfx.RuntimePresentation")
local SolarTermPresentation = require("vfx.SolarTermPresentation")

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
local IMPACT_WIDGET_COUNT = 24
local TRAIL_SEGMENT_COUNT = 3
local SOLAR_TERM_DURATION = 70
local SOLAR_TERM_SEQUENCE = { "lichun", "yushui", "jingzhe", "chunfen", "qingming", "guyu" }
local RAIN_WIDGET_COUNT = 12
local LEAF_WIDGET_COUNT = 8
local POLLEN_WIDGET_COUNT = 8

local ENEMY_SPRITES = {
    bifang = AssetCatalog.enemySprites.bifang,
    jiuweihu = AssetCatalog.enemySprites.jiuweihu,
    kui = AssetCatalog.enemySprites.kui,
    spring_elite = AssetCatalog.enemySprites.spring_elite,
    jumang = AssetCatalog.bossSprites.jumang,
}

local function TouchButton(text, left, top, direction, touchState)
    return UI.Button {
        visible = false,
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
            if touchState.enabled then
                touchState[direction] = true
            end
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
    self.projectileTrails = {}
    self.impactWidgets = {}
    self.deathWidgets = {}
    self.enemyHitWidgets = {}
    self.debugControls = {}
    self.debugLabel = nil
    self.playerHitWidget = nil
    self.targetMarker = nil
    self.touchState = { left = false, right = false, up = false, down = false, enabled = false }
    self.shadowsEnabled = true
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
    self.solarTermTint = nil
    self.solarTermFog = nil
    self.solarTermLightning = nil
    self.solarTermCorruption = nil
    self.rainWidgets = {}
    self.leafWidgets = {}
    self.pollenWidgets = {}
    self.solarTermOverride = nil
    self.currentSolarTermName = "立春"
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

    self.solarTermTint = UI.Panel {
        position = "absolute",
        left = 0,
        top = 0,
        width = 1920,
        height = 1080,
        backgroundColor = { 145, 190, 130, 20 },
        pointerEvents = "none",
    }
    self.arena:AddChild(self.solarTermTint)

    self.solarTermFog = UI.Panel {
        position = "absolute",
        left = 0,
        top = 180,
        width = 1920,
        height = 720,
        backgroundColor = { 205, 218, 208, 0 },
        pointerEvents = "none",
    }
    self.arena:AddChild(self.solarTermFog)

    self.solarTermCorruption = UI.Panel {
        position = "absolute",
        left = 0,
        top = 0,
        width = 1920,
        height = 1080,
        borderColor = { 52, 70, 48, 0 },
        borderWidth = 48,
        backgroundColor = { 18, 30, 22, 0 },
        pointerEvents = "none",
    }
    self.arena:AddChild(self.solarTermCorruption)

    for index = 1, RAIN_WIDGET_COUNT do
        local rain = UI.Panel {
            visible = false,
            position = "absolute",
            width = 3,
            height = 28,
            borderRadius = 2,
            backgroundColor = { 194, 218, 228, 86 },
            pointerEvents = "none",
        }
        self.rainWidgets[index] = rain
        self.arena:AddChild(rain)
    end

    for index = 1, LEAF_WIDGET_COUNT do
        local leaf = UI.Panel {
            visible = false,
            position = "absolute",
            width = 13,
            height = 5,
            borderRadius = 3,
            backgroundColor = { 207, 220, 168, 104 },
            pointerEvents = "none",
        }
        self.leafWidgets[index] = leaf
        self.arena:AddChild(leaf)
    end

    for index = 1, POLLEN_WIDGET_COUNT do
        local pollen = UI.Panel {
            visible = false,
            position = "absolute",
            width = 5,
            height = 5,
            borderRadius = 3,
            backgroundColor = { 239, 226, 166, 92 },
            pointerEvents = "none",
        }
        self.pollenWidgets[index] = pollen
        self.arena:AddChild(pollen)
    end

    self.solarTermLightning = UI.Panel {
        position = "absolute",
        left = 0,
        top = 0,
        width = 1920,
        height = 1080,
        backgroundColor = { 218, 230, 255, 0 },
        pointerEvents = "none",
    }
    self.arena:AddChild(self.solarTermLightning)

    for index = 1, RAIN_WIDGET_COUNT do
        local widget = UI.Panel {
            visible = false,
            position = "absolute",
            width = 3,
            height = 28,
            borderRadius = 2,
            backgroundColor = { 200, 222, 226, 150 },
            pointerEvents = "none",
        }
        self.rainWidgets[index] = widget
        self.arena:AddChild(widget)
    end

    for index = 1, LEAF_WIDGET_COUNT do
        local widget = UI.Panel {
            visible = false,
            position = "absolute",
            width = 13,
            height = 5,
            borderRadius = 3,
            backgroundColor = { 180, 205, 138, 104 },
            pointerEvents = "none",
        }
        self.leafWidgets[index] = widget
        self.arena:AddChild(widget)
    end

    for index = 1, POLLEN_WIDGET_COUNT do
        local widget = UI.Panel {
            visible = false,
            position = "absolute",
            width = 5,
            height = 5,
            borderRadius = 3,
            backgroundColor = { 231, 214, 137, 180 },
            pointerEvents = "none",
        }
        self.pollenWidgets[index] = widget
        self.arena:AddChild(widget)
    end

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

    self.targetMarker = UI.Panel {
        visible = false,
        position = "absolute",
        borderColor = COLORS.jade,
        borderWidth = 3,
        backgroundColor = { 91, 174, 131, 18 },
        pointerEvents = "none",
    }
    self.arena:AddChild(self.targetMarker)

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
        local hit = UI.Panel {
            visible = false,
            position = "absolute",
            borderColor = { 255, 255, 255, 245 },
            borderWidth = 5,
            backgroundColor = { 255, 255, 255, 34 },
            pointerEvents = "none",
        }
        self.enemyHitWidgets[index] = hit
        self.arena:AddChild(hit)
    end

    for index = 1, ENEMY_WIDGET_COUNT do
        local widget = UI.Sprite {
            visible = false,
            position = "absolute",
            width = 100,
            height = 100,
            animations = ENEMY_SPRITES,
            defaultAnimation = "bifang",
            objectFit = "contain",
            applyPivotInAbsolute = true,
            pointerEvents = "none",
        }
        self.enemyWidgets[index] = widget
        self.arena:AddChild(widget)
    end

    for index = 1, DEATH_WIDGET_COUNT do
        local widget = UI.Sprite {
            visible = false,
            position = "absolute",
            width = 100,
            height = 100,
            animations = ENEMY_SPRITES,
            defaultAnimation = "bifang",
            objectFit = "contain",
            applyPivotInAbsolute = true,
            pointerEvents = "none",
        }
        self.deathWidgets[index] = widget
        self.arena:AddChild(widget)
    end

    for index = 1, PROJECTILE_WIDGET_COUNT do
        self.projectileTrails[index] = {}
        for segment = TRAIL_SEGMENT_COUNT, 1, -1 do
            local trail = UI.Panel {
                visible = false,
                position = "absolute",
                backgroundImage = AssetCatalog.wheel.core,
                backgroundFit = "contain",
                pointerEvents = "none",
            }
            self.projectileTrails[index][segment] = trail
            self.arena:AddChild(trail)
        end

        local widget = UI.Panel {
            visible = false,
            position = "absolute",
            width = 24,
            height = 24,
            backgroundImage = AssetCatalog.wheel.core,
            backgroundFit = "contain",
            transformOrigin = "center",
            pointerEvents = "none",
        }
        self.projectileWidgets[index] = widget
        self.arena:AddChild(widget)
    end

    for index = 1, IMPACT_WIDGET_COUNT do
        local impact = UI.Panel {
            visible = false,
            position = "absolute",
            borderColor = COLORS.pale,
            borderWidth = 5,
            backgroundColor = { 246, 239, 211, 42 },
            pointerEvents = "none",
        }
        self.impactWidgets[index] = impact
        self.arena:AddChild(impact)
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

    self.playerWidget = UI.Sprite {
        position = "absolute",
        width = 138,
        height = 190,
        animations = AssetCatalog.characterSprites,
        defaultAnimation = "shi_yu_zhe",
        objectFit = "contain",
        applyPivotInAbsolute = true,
        pointerEvents = "none",
    }
    self.arena:AddChild(self.playerWidget)

    self.playerHitWidget = UI.Panel {
        visible = false,
        position = "absolute",
        borderColor = { 255, 255, 255, 250 },
        borderWidth = 6,
        backgroundColor = { 255, 255, 255, 38 },
        pointerEvents = "none",
    }
    self.arena:AddChild(self.playerHitWidget)
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
    self.debugControls = {
        TouchButton("←", 92, 876, "left", self.touchState),
        TouchButton("→", 266, 876, "right", self.touchState),
        TouchButton("↑", 179, 789, "up", self.touchState),
        TouchButton("↓", 179, 963, "down", self.touchState),
    }
    self.debugLabel = UI.Label {
        visible = false,
        position = "absolute",
        left = 28,
        bottom = 24,
        width = 720,
        fontSize = 17,
        fontColor = COLORS.pale,
        text = "DEBUG",
        pointerEvents = "none",
    }
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
            self.debugControls[1],
            self.debugControls[2],
            self.debugControls[3],
            self.debugControls[4],
            self.debugLabel,
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
    self.playerWidget:Play(characterId)
    self.playerWidget.currentKind = characterId
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

function BattleView:UpdateDebugControls()
    local enabled = self.game:GetDebugEnabled()
    self.touchState.enabled = enabled
    if not enabled then
        self.touchState.left = false
        self.touchState.right = false
        self.touchState.up = false
        self.touchState.down = false
    end
    for index = 1, #self.debugControls do
        self.debugControls[index]:SetVisible(enabled)
    end
    self.debugLabel:SetVisible(enabled)
    if enabled then
        local battle = self.game.battleManager
        self.debugLabel:SetText(string.format(
            "DEBUG｜%s｜怪 %d｜弹 %d｜Impact %d｜1-6 节气 C 蓄力｜F4 阴影 F5 单体 F6 对比 F7/F8/F9 压力 F10 Boss",
            battle.debugScenario or "normal",
            #battle.enemies,
            #battle.projectiles,
            #battle.impacts
        ))
    end
end

function BattleView:UpdatePools()
    local battle = self.game.battleManager
    local target = battle:FindNearestEnemy()
    if target then
        local markerSize = target.size * 0.82
        self.targetMarker:SetStyle({
            left = target.x - markerSize * 0.5,
            top = target.y - markerSize * 0.18,
            width = markerSize,
            height = markerSize * 0.28,
            borderRadius = markerSize * 0.14,
            opacity = 0.48 + math.abs(math.sin(battle.elapsed * 4)) * 0.28,
        })
        self.targetMarker:SetVisible(true)
    else
        self.targetMarker:SetVisible(false)
    end

    for index = 1, ENEMY_WIDGET_COUNT do
        local widget = self.enemyWidgets[index]
        local shadowWidget = self.enemyShadows[index]
        local ringWidget = self.eliteRings[index]
        local hitWidget = self.enemyHitWidgets[index]
        local enemy = battle.enemies[index]
        if enemy then
            local motion = RuntimePresentation.Enemy(enemy.kind, battle.elapsed, enemy.visualPhase)
            local hit = enemy.hitElapsed and RuntimePresentation.Hit(enemy.hitElapsed, 0.16) or nil
            local visualY = enemy.y + motion.offsetY
            if widget.currentKind ~= enemy.kind then
                widget:Play(enemy.kind)
                widget.currentKind = enemy.kind
            end
            widget:SetFlipX(enemy.facing == "left")
            widget:SetStyle({
                left = enemy.x,
                top = visualY,
                width = enemy.size,
                height = enemy.size,
                rotate = motion.rotation + (enemy.lean or 0),
                scale = hit and hit.scale or 1,
                opacity = 1,
            })
            widget:SetVisible(true)

            local shadow = RuntimePresentation.EnemyShadow(enemy.kind, enemy.size, battle.elapsed, enemy.visualPhase)
            shadowWidget:SetStyle({
                left = enemy.x - shadow.width * 0.5,
                top = enemy.y + shadow.offsetY - shadow.height * 0.5,
                width = shadow.width,
                height = shadow.height,
                borderRadius = shadow.height * 0.5,
                opacity = shadow.opacity,
            })
            shadowWidget:SetVisible(self.shadowsEnabled)

            if hit then
                local hitSize = enemy.size * (0.84 + hit.flashWhite * 0.12)
                hitWidget:SetStyle({
                    left = enemy.x - hitSize * 0.5,
                    top = visualY - hitSize * 0.54,
                    width = hitSize,
                    height = hitSize,
                    borderRadius = hitSize * 0.5,
                    opacity = hit.flashWhite,
                })
                hitWidget:SetVisible(true)
            else
                hitWidget:SetVisible(false)
            end

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
            hitWidget:SetVisible(false)
        end
    end

    for index = 1, PROJECTILE_WIDGET_COUNT do
        local widget = self.projectileWidgets[index]
        local trails = self.projectileTrails[index]
        local projectile = battle.projectiles[index]
        if projectile then
            local presentation = ProjectilePresentation.Compute(projectile, projectile.maxLife)
            local head = presentation.head
            widget:SetStyle({
                left = head.left,
                top = head.top,
                width = head.width,
                height = head.height,
                rotate = head.rotation,
                scale = head.scale,
                opacity = head.opacity,
            })
            widget:SetVisible(true)
            for segment = 1, TRAIL_SEGMENT_COUNT do
                local trail = presentation.tail[segment]
                trails[segment]:SetStyle({
                    left = trail.left,
                    top = trail.top,
                    width = trail.width,
                    height = trail.height,
                    rotate = trail.rotation,
                    scale = trail.scale,
                    opacity = trail.opacity,
                })
                trails[segment]:SetVisible(true)
            end
        else
            widget:SetVisible(false)
            for segment = 1, TRAIL_SEGMENT_COUNT do
                trails[segment]:SetVisible(false)
            end
        end
    end

    for index = 1, DEATH_WIDGET_COUNT do
        local widget = self.deathWidgets[index]
        local effect = battle.deathEffects[index]
        if effect then
            local visual = RuntimePresentation.Death(effect.elapsed, effect.duration)
            if widget.currentKind ~= effect.kind then
                widget:Play(effect.kind)
                widget.currentKind = effect.kind
            end
            widget:SetFlipX(effect.facing == "left")
            widget:SetStyle({
                left = effect.x,
                top = effect.y + visual.offsetY,
                width = effect.size,
                height = effect.size,
                opacity = visual.opacity,
                scale = visual.scale,
            })
            widget:SetVisible(true)
        else
            widget:SetVisible(false)
        end
    end

    for index = 1, IMPACT_WIDGET_COUNT do
        local widget = self.impactWidgets[index]
        local impact = battle.impacts[index]
        if impact then
            local visual = ProjectilePresentation.Impact(impact, impact.elapsed)
            local width = visual.ringWidth * visual.ringScale
            local height = visual.ringHeight * visual.ringScale
            widget:SetStyle({
                left = visual.x - width * 0.5,
                top = visual.y - height * 0.5,
                width = width,
                height = height,
                borderRadius = width * 0.5,
                opacity = visual.ringOpacity,
                scale = visual.coreScale,
            })
            widget:SetVisible(true)
        else
            widget:SetVisible(false)
        end
    end
end

local function ColorByte(value)
    return math.floor(math.max(0, math.min(1, value or 0)) * 255 + 0.5)
end

local function Wrap(value, modulus)
    return value - math.floor(value / modulus) * modulus
end

function BattleView:SetSolarTermOverride(termId)
    if termId == nil then
        self.solarTermOverride = nil
        return true
    end
    local ok = pcall(SolarTermPresentation.Get, termId)
    if not ok then
        return false
    end
    self.solarTermOverride = termId
    return true
end

function BattleView:ToggleWheelCharged()
    local battle = self.game.battleManager
    battle.wheelState = battle.wheelState == "charged" and nil or "charged"
    return battle.wheelState
end

function BattleView:UpdateSolarTerm()
    local battle = self.game.battleManager
    local elapsed = battle.elapsed or 0
    local captureMetadata = battle.captureMode and battle.captureMode:GetStateMetadata() or nil
    local captureTerm = captureMetadata and captureMetadata.solarTermId or nil
    local sequenceIndex = math.floor(elapsed / SOLAR_TERM_DURATION) % #SOLAR_TERM_SEQUENCE + 1
    local termId = self.solarTermOverride or captureTerm or SOLAR_TERM_SEQUENCE[sequenceIndex]
    local state = SolarTermPresentation.Step(termId, elapsed)
    self.currentSolarTermName = state.name

    local tint = state.overlay.tint
    self.solarTermTint:SetStyle({
        backgroundColor = { ColorByte(tint.r), ColorByte(tint.g), ColorByte(tint.b), ColorByte(tint.a) },
    })
    self.solarTermFog:SetStyle({
        left = -120 + state.fog.offset * 120,
        backgroundColor = { 205, 218, 208, math.floor(state.fog.opacity * 96) },
    })
    self.solarTermCorruption:SetStyle({
        borderColor = { 54, 69, 48, math.floor(state.corruption * 126) },
        backgroundColor = { 20, 29, 23, math.floor(state.corruption * 36) },
    })
    self.solarTermLightning:SetStyle({
        backgroundColor = { 218, 230, 255, math.floor(state.lightning.flash * 112) },
    })

    local rainCount = math.floor(state.rain.density * RAIN_WIDGET_COUNT + 0.5)
    for index = 1, RAIN_WIDGET_COUNT do
        local widget = self.rainWidgets[index]
        if index <= rainCount then
            widget:SetStyle({
                left = Wrap(index * 157 + elapsed * state.rain.speed * 520, 1980) - 30,
                top = Wrap(index * 89 + elapsed * state.rain.speed * 740, 1120) - 30,
                rotate = 12 + state.rain.angle * 35,
                opacity = 0.48 + (index % 3) * 0.12,
            })
            widget:SetVisible(true)
        else
            widget:SetVisible(false)
        end
    end

    local leafDensity = math.max(state.windLeaves.density, state.flowerLeaves.density)
    local leafCount = math.floor(leafDensity * LEAF_WIDGET_COUNT + 0.5)
    local leafSpeed = math.max(state.windLeaves.speed, state.flowerLeaves.speed)
    local leafDirection = state.flowerLeaves.density > state.windLeaves.density
        and state.flowerLeaves.direction or state.windLeaves.direction
    for index = 1, LEAF_WIDGET_COUNT do
        local widget = self.leafWidgets[index]
        if index <= leafCount then
            local travel = elapsed * leafSpeed * 380 * leafDirection
            widget:SetStyle({
                left = Wrap(index * 233 + travel, 1980) - 30,
                top = 180 + Wrap(index * 137 + elapsed * leafSpeed * 90, 720),
                rotate = Wrap(index * 37 + elapsed * 55, 360),
                backgroundColor = state.flowerLeaves.density > 0.4
                    and { 230, 229, 211, 112 } or { 180, 205, 138, 104 },
            })
            widget:SetVisible(true)
        else
            widget:SetVisible(false)
        end
    end

    local pollenCount = math.floor(state.pollen.density * POLLEN_WIDGET_COUNT + 0.5)
    for index = 1, POLLEN_WIDGET_COUNT do
        local widget = self.pollenWidgets[index]
        if index <= pollenCount then
            widget:SetStyle({
                left = Wrap(index * 271 + elapsed * state.pollen.speed * 210, 1940) - 10,
                top = 250 + Wrap(index * 101 - elapsed * state.pollen.speed * 120, 620),
                opacity = 0.52 + (index % 2) * 0.20,
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
    local state = player.animation:Get()
    local stateDuration = state == "Death" and 0.65 or 0.16
    local visual = RuntimePresentation.Player(
        battle.elapsed,
        player.isMoving,
        state,
        player.animation.time,
        stateDuration
    )
    self.playerWidget:SetFlipX(player.facing == "left")
    self.playerWidget:SetStyle({
        left = player.x,
        top = player.y + visual.offsetY,
        rotate = visual.rotation,
        scale = visual.scale,
        opacity = visual.opacity,
    })

    if visual.flashWhite > 0 then
        local hitSize = playerWidth * (0.92 + visual.flashWhite * 0.12)
        self.playerHitWidget:SetStyle({
            left = player.x - hitSize * 0.5,
            top = player.y - playerHeight * 0.72,
            width = hitSize,
            height = playerHeight * 0.82,
            borderRadius = hitSize * 0.5,
            opacity = visual.flashWhite,
        })
        self.playerHitWidget:SetVisible(true)
    else
        self.playerHitWidget:SetVisible(false)
    end

    local shadow = RuntimePresentation.Shadow(playerWidth, 0.06)
    self.playerShadow:SetStyle({
        left = player.x - shadow.width * 0.5,
        top = player.y + shadow.offsetY - shadow.height * 0.5,
        width = shadow.width,
        height = shadow.height,
        borderRadius = shadow.height * 0.5,
        opacity = shadow.opacity,
    })
    self.playerShadow:SetVisible(self.shadowsEnabled and visual.opacity > 0.05)

    local wheelAnchor = RuntimePresentation.WheelAnchor(
        player.x,
        player.y,
        playerWidth,
        playerHeight,
        player.facing
    )
    local wheelVisuals = RuntimePresentation.Wheel(
        battle.elapsed,
        battle.attackPulse,
        battle.wheelState,
        wheelAnchor.diameter
    )
    for index = 1, #self.wheelWidgets do
        local widget = self.wheelWidgets[index]
        local visual = wheelVisuals[index]
        widget:SetStyle({
            left = wheelAnchor.centerX - visual.width * 0.5 + visual.offsetX,
            top = wheelAnchor.centerY - visual.height * 0.5 + visual.offsetY,
            width = visual.width,
            height = visual.height,
            rotate = visual.rotation,
            opacity = visual.opacity * (0.45 + 0.55 * visual.opacity),
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
    local phase = battle.bossSpawned and ("春神现世 · " .. self.currentSolarTermName) or self.currentSolarTermName
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

function BattleView:ToggleShadows()
    self.shadowsEnabled = not self.shadowsEnabled
    return self.shadowsEnabled
end

function BattleView:Update(timeStep)
    if not self.root or not self.visible then
        return
    end

    self:UpdateDebugControls()
    local moveX, moveY = self:GetMovement()
    self.game:Update(timeStep, moveX, moveY)
    self:UpdateSolarTerm()
    self:UpdatePools()
    self:UpdatePlayer()
    self:UpdateBossAndWarning()
    self:UpdateOverlays()
end

return BattleView
