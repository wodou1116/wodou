local TargetSelector = {}

local function DistanceSquared(source, target)
    local dx = (target.x or 0) - (source.x or 0)
    local dy = (target.y or 0) - (source.y or 0)
    return dx * dx + dy * dy
end

function TargetSelector.FindNearest(source, candidates, options)
    options = options or {}
    local bestTarget, bestIndex, bestDistanceSquared = nil, nil, math.huge
    local maxRangeSquared = options.maxRange and options.maxRange * options.maxRange or nil

    for index = 1, #(candidates or {}) do
        local candidate = candidates[index]
        local valid = candidate and (not options.isValid or options.isValid(candidate, index))
        if valid then
            local distanceSquared = DistanceSquared(source, candidate)
            if (not maxRangeSquared or distanceSquared <= maxRangeSquared) and distanceSquared < bestDistanceSquared then
                bestTarget, bestIndex, bestDistanceSquared = candidate, index, distanceSquared
            end
        end
    end

    if not bestTarget then
        return nil
    end
    return bestTarget, bestIndex, math.sqrt(bestDistanceSquared)
end

function TargetSelector.FindBest(source, candidates, options)
    options = options or {}
    assert(type(options.score) == "function", "target score callback is required")
    local bestTarget, bestIndex, bestScore = nil, nil, -math.huge
    for index = 1, #(candidates or {}) do
        local candidate = candidates[index]
        if candidate and (not options.isValid or options.isValid(candidate, index)) then
            local score = options.score(candidate, index, source)
            if score > bestScore then
                bestTarget, bestIndex, bestScore = candidate, index, score
            end
        end
    end
    return bestTarget, bestIndex, bestScore
end

return TargetSelector
