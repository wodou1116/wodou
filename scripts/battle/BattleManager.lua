local Logger = require("core.Logger")

local BattleManager = {}
BattleManager.__index = BattleManager

function BattleManager.New()
    local self = setmetatable({}, BattleManager)
    self:Init()
    return self
end

function BattleManager:Init()
    self.active = false
    self.elapsed = 0
    self.run = nil
end

function BattleManager:Prepare(runSnapshot)
    self.run = runSnapshot
    self.elapsed = 0
    Logger.Info("Battle", "战斗上下文已准备，等待运行时资产接入")
end

function BattleManager:Start()
    self.active = true
end

function BattleManager:Update(timeStep)
    if self.active then
        self.elapsed = self.elapsed + timeStep
    end
end

function BattleManager:Stop()
    self.active = false
end

return BattleManager
