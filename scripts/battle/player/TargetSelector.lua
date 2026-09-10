local AttackRange = require("battle.player.AttackRange")

local TargetSelector = {}

-- Returns target, one-based index, and center distance. Ties retain list order.
-- options.maxRange is optional; options.isValid(candidate, index) can reject entries.
function TargetSelector.FindNearest(source, candidates, options)
    options = options or {}
    local bestTarget, bestIndex, bestDistanceSquared = nil, nil, math.huge
    local maxRange = options.maxRange

    for index = 1, #candidates do
        local candidate = candidates[index]
        local valid = candidate ~= nil and (not options.isValid or options.isValid(candidate, index))
        if valid then
            local distanceSquared = AttackRange.DistanceSquared(source, candidate)
            local inRange = not maxRange or distanceSquared <= maxRange * maxRange
            if inRange and distanceSquared < bestDistanceSquared then
                bestTarget, bestIndex, bestDistanceSquared = candidate, index, distanceSquared
            end
        end
    end

    if not bestTarget then
        return nil
    end
    return bestTarget, bestIndex, math.sqrt(bestDistanceSquared)
end

return TargetSelector
