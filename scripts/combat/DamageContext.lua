local DamageContext = {}

local function ReadStat(stats, name, fallback)
    if stats and type(stats.Get) == "function" then
        return stats:Get(name, fallback)
    end
    if stats and stats[name] ~= nil then
        return stats[name]
    end
    return fallback
end

function DamageContext.New(options)
    options = options or {}
    assert(options.target, "damage target is required")
    assert(type(options.amount) == "number" and options.amount >= 0, "damage amount must be non-negative")
    return {
        source = options.source,
        target = options.target,
        amount = options.amount,
        kind = options.kind or "direct",
        element = options.element,
        tags = options.tags or {},
        critical = options.critical == true,
        criticalMultiplier = options.criticalMultiplier or 1.5,
        metadata = options.metadata,
    }
end

function DamageContext.Resolve(context, targetStats)
    assert(context and context.target, "damage context is required")
    local stats = targetStats or context.target
    local armor = math.max(0, ReadStat(stats, "armor", 0))
    local damageTaken = math.max(0, ReadStat(stats, "damageTaken", 1))
    local criticalMultiplier = context.critical and context.criticalMultiplier or 1
    local amount = math.max(0, context.amount * criticalMultiplier - armor) * damageTaken
    local hp = context.target.hp or 0
    return {
        source = context.source,
        target = context.target,
        rawAmount = context.amount,
        amount = amount,
        kind = context.kind,
        element = context.element,
        tags = context.tags,
        critical = context.critical,
        lethal = amount >= hp,
        metadata = context.metadata,
    }
end

function DamageContext.Apply(resolved)
    assert(resolved and resolved.target, "resolved damage is required")
    local target = resolved.target
    local before = target.hp or 0
    target.hp = math.max(0, before - resolved.amount)
    resolved.appliedAmount = before - target.hp
    resolved.lethal = before > 0 and target.hp <= 0
    return resolved.appliedAmount
end

return DamageContext
