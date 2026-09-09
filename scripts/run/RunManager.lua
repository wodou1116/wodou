local RunManager = {}
RunManager.__index = RunManager

function RunManager.New()
    local self = setmetatable({}, RunManager)
    self:Init()
    return self
end

function RunManager:Init()
    self.active = false
    self.characterId = nil
    self.seasonId = nil
    self.stageIndex = 0
end

function RunManager:Begin(characterId, seasonId)
    self.active = true
    self.characterId = characterId
    self.seasonId = seasonId
    self.stageIndex = 1
end

function RunManager:Finish()
    self.active = false
end

function RunManager:GetSnapshot()
    return {
        active = self.active,
        characterId = self.characterId,
        seasonId = self.seasonId,
        stageIndex = self.stageIndex,
    }
end

return RunManager
