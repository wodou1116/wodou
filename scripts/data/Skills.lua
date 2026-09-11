local Skills = {}

local entries = {
    {
        id = "jingzhe",
        name = "惊蛰·春雷",
        description = "攻击伤害提高 35%",
        icon = "image/icons/skills/01_jingzhe.png",
        modifier = { damage = { multiply = 1.35 } },
    },
    {
        id = "guyu",
        name = "谷雨·润生",
        description = "生命上限提高 20，并恢复 35",
        icon = "image/icons/skills/02_guyu.png",
        modifier = { maxHp = { flat = 20 } },
        heal = 35,
    },
    {
        id = "roots",
        name = "木德·盘根",
        description = "弹丸尺寸与射程提高",
        icon = "image/icons/skills/03_roots.png",
        modifier = {
            projectileRadius = { flat = 5 },
            projectileLife = { flat = 0.25 },
        },
    },
    {
        id = "fire_seed",
        name = "火种·明烛",
        description = "攻击间隔缩短 18%",
        icon = "image/icons/skills/04_fire_seed.png",
        modifier = { attackInterval = { multiply = 0.82, minimum = 0.16 } },
    },
    {
        id = "fire_burst",
        name = "离火·迸发",
        description = "每次攻击额外发射一枚弹丸",
        icon = "image/icons/skills/05_fire_burst.png",
        modifier = { projectileCount = { flat = 1, maximum = 5 } },
    },
    {
        id = "metal_blade",
        name = "金行·锐刃",
        description = "弹丸额外贯穿一个敌人",
        icon = "image/icons/skills/06_metal_blade.png",
        modifier = { pierce = { flat = 1 } },
    },
    {
        id = "water_mirror",
        name = "水镜·回澜",
        description = "生命上限提高 30，并恢复 30",
        icon = "image/icons/skills/07_water_mirror.png",
        modifier = { maxHp = { flat = 30 } },
        heal = 30,
    },
    {
        id = "frost_breath",
        name = "寒息·踏霜",
        description = "移动速度提高 18%",
        icon = "image/icons/skills/08_frost_breath.png",
        modifier = { moveSpeed = { multiply = 1.18 } },
    },
    {
        id = "earth_shock",
        name = "土行·震岳",
        description = "伤害提高 20%，弹丸变大",
        icon = "image/icons/skills/09_earth_shock.png",
        modifier = {
            damage = { multiply = 1.2 },
            projectileRadius = { flat = 3 },
        },
    },
    {
        id = "stone_guard",
        name = "山甲·镇守",
        description = "受到的伤害降低 18%",
        icon = "image/icons/skills/10_stone_guard.png",
        modifier = { damageTaken = { multiply = 0.82 } },
    },
}

function Skills.List()
    return entries
end

function Skills.GetChoices()
    local indices = {}
    for index = 1, #entries do
        indices[index] = index
    end

    for index = #indices, 2, -1 do
        local swapIndex = math.random(index)
        indices[index], indices[swapIndex] = indices[swapIndex], indices[index]
    end

    return { entries[indices[1]], entries[indices[2]], entries[indices[3]] }
end

function Skills.Apply(skill, actor, modifierId)
    assert(skill and actor and actor.statSystem, "skill requires an actor StatSystem")
    actor.statSystem:AddModifier(modifierId or skill.id, skill.modifier or {})
    local values = actor.statSystem:GetAll()
    for statName, value in pairs(values) do
        actor[statName] = value
    end
    if skill.heal then
        actor.hp = math.min(actor.maxHp, actor.hp + skill.heal)
    end
    return values
end

return Skills
