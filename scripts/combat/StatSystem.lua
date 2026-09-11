local StatSystem = {}
StatSystem.__index = StatSystem

local function Copy(source)
    local result = {}
    for key, value in pairs(source or {}) do
        result[key] = value
    end
    return result
end

function StatSystem.New(baseStats)
    local self = setmetatable({}, StatSystem)
    self.base = Copy(baseStats)
    self.modifiers = {}
    self.values = {}
    self:Recalculate()
    return self
end

function StatSystem:Recalculate()
    local values = Copy(self.base)
    local totals = {}

    for _, modifier in pairs(self.modifiers) do
        for statName, rule in pairs(modifier) do
            local total = totals[statName]
            if not total then
                total = { flat = 0, add = 0, multiply = 1, minimum = nil, maximum = nil }
                totals[statName] = total
            end
            total.flat = total.flat + (rule.flat or 0)
            total.add = total.add + (rule.add or 0)
            total.multiply = total.multiply * (rule.multiply or 1)
            if rule.minimum ~= nil then
                total.minimum = total.minimum and math.max(total.minimum, rule.minimum) or rule.minimum
            end
            if rule.maximum ~= nil then
                total.maximum = total.maximum and math.min(total.maximum, rule.maximum) or rule.maximum
            end
        end
    end

    for statName, total in pairs(totals) do
        local base = values[statName] or 0
        local value = (base + total.flat) * (1 + total.add) * total.multiply
        if total.minimum ~= nil then
            value = math.max(total.minimum, value)
        end
        if total.maximum ~= nil then
            value = math.min(total.maximum, value)
        end
        values[statName] = value
    end
    self.values = values
    return values
end

function StatSystem:Get(statName, fallback)
    local value = self.values[statName]
    if value == nil then
        return fallback
    end
    return value
end

function StatSystem:GetAll()
    return Copy(self.values)
end

function StatSystem:SetBase(statName, value)
    self.base[statName] = value
    self:Recalculate()
    return self:Get(statName)
end

function StatSystem:AddModifier(modifierId, modifier)
    assert(modifierId ~= nil, "modifier id is required")
    assert(type(modifier) == "table", "modifier must be a table")
    self.modifiers[modifierId] = modifier
    self:Recalculate()
    return modifier
end

function StatSystem:RemoveModifier(modifierId)
    local removed = self.modifiers[modifierId] ~= nil
    self.modifiers[modifierId] = nil
    self:Recalculate()
    return removed
end

return StatSystem
