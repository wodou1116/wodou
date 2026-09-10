local AttackRange = {}

function AttackRange.DistanceSquared(source, target)
    local dx = target.x - source.x
    local dy = target.y - source.y
    return dx * dx + dy * dy
end

function AttackRange.Distance(source, target)
    return math.sqrt(AttackRange.DistanceSquared(source, target))
end

-- Checks center-to-center distance, which is appropriate for projectile targeting.
function AttackRange.IsInRange(source, target, range)
    assert(range >= 0, "AttackRange range must be non-negative")
    return AttackRange.DistanceSquared(source, target) <= range * range
end

-- Checks the gap between collision circles for melee or contact range checks.
function AttackRange.IsWithinEdgeRange(source, target, range)
    assert(range >= 0, "AttackRange range must be non-negative")
    local combinedRadius = (source.radius or 0) + (target.radius or 0) + range
    return AttackRange.DistanceSquared(source, target) <= combinedRadius * combinedRadius
end

return AttackRange
