local Skills = {}

local entries = {
    {
        id = "jingzhe",
        name = "惊蛰·春雷",
        description = "攻击伤害提高 35%",
        icon = "image/icons/skills/01_jingzhe.png",
        apply = function(stats)
            stats.damage = stats.damage * 1.35
        end,
    },
    {
        id = "guyu",
        name = "谷雨·润生",
        description = "生命上限提高 20，并恢复 35",
        icon = "image/icons/skills/02_guyu.png",
        apply = function(stats)
            stats.maxHp = stats.maxHp + 20
            stats.hp = math.min(stats.maxHp, stats.hp + 35)
        end,
    },
    {
        id = "roots",
        name = "木德·盘根",
        description = "弹丸尺寸与射程提高",
        icon = "image/icons/skills/03_roots.png",
        apply = function(stats)
            stats.projectileRadius = stats.projectileRadius + 5
            stats.projectileLife = stats.projectileLife + 0.25
        end,
    },
    {
        id = "fire_seed",
        name = "火种·明烛",
        description = "攻击间隔缩短 18%",
        icon = "image/icons/skills/04_fire_seed.png",
        apply = function(stats)
            stats.attackInterval = math.max(0.16, stats.attackInterval * 0.82)
        end,
    },
    {
        id = "fire_burst",
        name = "离火·迸发",
        description = "每次攻击额外发射一枚弹丸",
        icon = "image/icons/skills/05_fire_burst.png",
        apply = function(stats)
            stats.projectileCount = math.min(5, stats.projectileCount + 1)
        end,
    },
    {
        id = "metal_blade",
        name = "金行·锐刃",
        description = "弹丸额外贯穿一个敌人",
        icon = "image/icons/skills/06_metal_blade.png",
        apply = function(stats)
            stats.pierce = stats.pierce + 1
        end,
    },
    {
        id = "water_mirror",
        name = "水镜·回澜",
        description = "生命上限提高 30，并恢复 30",
        icon = "image/icons/skills/07_water_mirror.png",
        apply = function(stats)
            stats.maxHp = stats.maxHp + 30
            stats.hp = math.min(stats.maxHp, stats.hp + 30)
        end,
    },
    {
        id = "frost_breath",
        name = "寒息·踏霜",
        description = "移动速度提高 18%",
        icon = "image/icons/skills/08_frost_breath.png",
        apply = function(stats)
            stats.moveSpeed = stats.moveSpeed * 1.18
        end,
    },
    {
        id = "earth_shock",
        name = "土行·震岳",
        description = "伤害提高 20%，弹丸变大",
        icon = "image/icons/skills/09_earth_shock.png",
        apply = function(stats)
            stats.damage = stats.damage * 1.2
            stats.projectileRadius = stats.projectileRadius + 3
        end,
    },
    {
        id = "stone_guard",
        name = "山甲·镇守",
        description = "受到的伤害降低 18%",
        icon = "image/icons/skills/10_stone_guard.png",
        apply = function(stats)
            stats.damageTaken = stats.damageTaken * 0.82
        end,
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

return Skills
