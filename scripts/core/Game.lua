local Constants = require("core.Constants")
local EventBus = require("core.EventBus")
local Logger = require("core.Logger")
local Characters = require("data.Characters")
local Seasons = require("data.Seasons")
local RunManager = require("run.RunManager")
local BattleManager = require("battle.BattleManager")

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
    self.battleManager = BattleManager.New()
end

function Game:Start()
    self.state = Game.State.MENU
    Logger.Info("Game", "基础工程启动完成")
end

function Game:Stop()
    self.battleManager:Stop()
    self.eventBus:Clear()
end

function Game:Update(timeStep)
    if self.state == Game.State.BATTLE then
        self.battleManager:Update(timeStep)
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

return Game
