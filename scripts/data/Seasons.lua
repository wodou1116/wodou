local seasons = {
    spring = {
        id = "spring",
        name = "春之境",
        unlocked = true,
        solarTerms = { "立春", "雨水", "惊蛰", "春分", "清明", "谷雨" },
        boss = "句芒",
    },
    summer = {
        id = "summer",
        name = "夏之境",
        unlocked = false,
        solarTerms = { "立夏", "小满", "芒种", "夏至", "小暑", "大暑" },
        boss = "祝融",
    },
    autumn = {
        id = "autumn",
        name = "秋之境",
        unlocked = false,
        solarTerms = { "立秋", "处暑", "白露", "秋分", "寒露", "霜降" },
        boss = "蓐收",
    },
    winter = {
        id = "winter",
        name = "冬之境",
        unlocked = false,
        solarTerms = { "立冬", "小雪", "大雪", "冬至", "小寒", "大寒" },
        boss = "禺疆",
    },
}

local Seasons = {}

function Seasons.Get(seasonId)
    return seasons[seasonId]
end

function Seasons.List()
    return {
        seasons.spring,
        seasons.summer,
        seasons.autumn,
        seasons.winter,
    }
end

return Seasons
