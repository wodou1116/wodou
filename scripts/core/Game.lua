local Constants = require("core.Constants")
local EventBus = require("core.EventBus")
local Logger = require("core.Logger")
local Characters = require("data.Characters")
local Seasons = require("data.Seasons")
local RunManager = require("run.RunManager")
local BattleManager = require("battle.BattleManager")
local CaptureMode = require("qa.CaptureMode")

local Game = {}
Game.__index = Game

Game.State = {
    BOOT = "boot",
    MENU = "menu",
    BATTLE = "battle",
    RESULT = "result",
}

function Game.New()
    local self = setmetatable({}, Game)
    self:Init()
    return self
end

function Game:Init()
    self.state = Game.State.BOOT
    self.debugEnabled = Constants.DEBUG_ENABLED
    self.selectedCharacterId = Constants.DEFAULT_CHARACTER_ID
    self.eventBus = EventBus.New()
    self.runManager = RunManager.New()
    self.battleManager = BattleManager.New(self.eventBus)
    self.qaCapture = CaptureMode.New()
end

function Game:Start()
    self.state = Game.State.MENU
    Logger.Info("Game", "基础工程启动完成")
end

function Game:Stop()
    self.battleManager:Stop()
    self.qaCapture:Clear()
    self.eventBus:Clear()
end

function Game:Update(timeStep, moveX, moveY)
    if self.state == Game.State.BATTLE then
        self.battleManager:Update(timeStep, moveX, moveY)
        if self.battleManager.result then
            self.state = Game.State.RESULT
            self.runManager:Finish()
            self.eventBus:Emit("run_finished", self.battleManager.result)
        end
    end
end

function Game:SelectCharacter(characterId)
    local character = Characters.Get(characterId)
    if not character then
        return false, "角色不存在"
    end

    self.selectedCharacterId = characterId
    self.eventBus:Emit("character_selected", character)
    return true, character.name
end

function Game:StartRun(seasonId)
    local season = Seasons.Get(seasonId)
    if not season then
        return false, "季节不存在"
    end
    if not season.unlocked then
        return false, "该季节将在后续切片开放"
    end

    self.runManager:Begin(self.selectedCharacterId, seasonId)
    self.battleManager:Prepare(self.runManager:GetSnapshot())
    self.battleManager:Start()
    self.state = Game.State.BATTLE
    self.eventBus:Emit("run_started", self.runManager:GetSnapshot())
    return true, season.name .. " / " .. season.solarTerms[1]
end

function Game:ChooseSkill(index)
    return self.battleManager:ChooseSkill(index)
end

function Game:TogglePause()
    if self.state ~= Game.State.BATTLE then
        return false
    end
    return self.battleManager:TogglePause()
end

function Game:RestartRun()
    if not self.battleManager.run then
        return false
    end
    self.runManager:Begin(self.selectedCharacterId, Constants.DEFAULT_SEASON_ID)
    self.battleManager:Prepare(self.runManager:GetSnapshot())
    self.battleManager:Start()
    if self.qaCapture:IsEnabled() then
        self.qaCapture:ApplySeed()
        self.battleManager:ConfigureCapture(self.qaCapture)
    end
    self.state = Game.State.BATTLE
    return true
end

function Game:ReturnToMenu()
    self.battleManager:Stop()
    self.qaCapture:Clear()
    self.runManager:Finish()
    self.state = Game.State.MENU
end

function Game:GetSelectedCharacter()
    return Characters.Get(self.selectedCharacterId)
end

function Game:GetDebugEnabled()
    return self.debugEnabled
end

function Game:ToggleDebug()
    self.debugEnabled = not self.debugEnabled
    Logger.SetEnabled(self.debugEnabled)
    return self.debugEnabled
end

function Game:ConfigureDebugScenario(mode, projectileCount)
    if not self.debugEnabled or self.state ~= Game.State.BATTLE then
        return false
    end
    self.battleManager:ConfigureDebugScenario(mode, projectileCount)
    return true
end

function Game:StartQaCapture(options)
    local metadata = self.qaCapture:Configure(options)
    self.qaCapture:ApplySeed()
    local started = self:StartRun((options and options.seasonId) or Constants.DEFAULT_SEASON_ID)
    if not started then
        self.qaCapture:Clear()
        return nil
    end
    self.battleManager:ConfigureCapture(self.qaCapture)
    return metadata
end

function Game:GetQaCaptureMetadata()
    return self.qaCapture:GetMetadata()
end

return Game
