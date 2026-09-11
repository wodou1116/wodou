local DeathContext = {}

function DeathContext.New(options)
    options = options or {}
    assert(options.victim, "death victim is required")
    return {
        victim = options.victim,
        killer = options.killer,
        damage = options.damage,
        reason = options.reason or "unknown",
        rewards = options.rewards or {},
        position = options.position,
        metadata = options.metadata,
    }
end

return DeathContext
