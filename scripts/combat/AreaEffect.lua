local AreaEffect = {}

local function Overlaps(effect, target)
    local dx = (target.x or 0) - (effect.x or 0)
    local dy = (target.y or 0) - (effect.y or 0)
    local radius = (effect.radius or 0) + (target.radius or 0)
    return dx * dx + dy * dy <= radius * radius
end

function AreaEffect.Query(effect, candidates, isValid)
    assert(effect and effect.radius, "area effect radius is required")
    local result = {}
    for index = 1, #(candidates or {}) do
        local candidate = candidates[index]
        if candidate and (not isValid or isValid(candidate, index)) and Overlaps(effect, candidate) then
            result[#result + 1] = candidate
        end
    end
    return result
end

function AreaEffect.Apply(effect, candidates, apply, isValid)
    assert(type(apply) == "function", "area effect apply callback is required")
    local affected = AreaEffect.Query(effect, candidates, isValid)
    for index = 1, #affected do
        apply(affected[index], effect)
    end
    return affected
end

return AreaEffect
