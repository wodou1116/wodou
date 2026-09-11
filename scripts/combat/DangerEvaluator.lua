local DangerEvaluator = {}

function DangerEvaluator.ScorePoint(x, y, hazards)
    local score = 0
    for index = 1, #(hazards or {}) do
        local hazard = hazards[index]
        local dx = x - (hazard.x or 0)
        local dy = y - (hazard.y or 0)
        local radius = math.max(0.0001, hazard.radius or 0)
        local distance = math.sqrt(dx * dx + dy * dy)
        if distance < radius then
            score = score + (hazard.weight or 1) * (1 + (radius - distance) / radius)
        end
    end
    return score
end

function DangerEvaluator.FindSafest(candidates, hazards)
    local best, bestIndex, bestScore = nil, nil, math.huge
    for index = 1, #(candidates or {}) do
        local candidate = candidates[index]
        local score = DangerEvaluator.ScorePoint(candidate.x or 0, candidate.y or 0, hazards)
        if score < bestScore then
            best, bestIndex, bestScore = candidate, index, score
        end
    end
    return best, bestIndex, bestScore
end

return DangerEvaluator
