package.path = "scripts/?.lua;scripts/?/init.lua;" .. package.path

local SolarTerms = require("data.SolarTerms")
local Presentation = require("vfx.SolarTermPresentation")

local function Near(actual, expected)
    return math.abs(actual - expected) < 0.0001
end

local function HasValue(values, expected)
    for _, value in ipairs(values) do
        if value == expected then
            return true
        end
    end
    return false
end

local expectedTerms = { "lichun", "yushui", "jingzhe", "chunfen", "qingming", "guyu" }
for _, termId in ipairs(expectedTerms) do
    local term = SolarTerms.Get(termId)
    assert(term and term.springBase == "spring_base", termId .. " must inherit Spring Base")
end

local base = SolarTerms.GetSpringBase()
assert(base.id == "spring_base" and base.overlay and base.overlay.tint and base.overlay.grade)

local lichun = Presentation.Get("lichun")
assert(lichun.season == "spring" and lichun.windLeaves.density > 0)
assert(lichun.rain.density == 0 and lichun.lightning.intensity == 0)
assert(lichun.visual.overlay.tint == lichun.overlay.tint, "visual overlay must preserve the overlay tint contract")
assert(lichun.visual.weather.rain == lichun.rain and lichun.visual.weather.fog == lichun.fog,
    "visual weather must expose the existing weather channels")
assert(lichun.visual.foregroundDressing.windLeaves == lichun.windLeaves
    and lichun.visual.foregroundDressing.flowerLeaves == lichun.flowerLeaves
    and lichun.visual.foregroundDressing.pollen == lichun.pollen,
    "visual foreground dressing must expose wind leaves, flower leaves, and pollen")
assert(lichun.visual.colorGrade == lichun.overlay.grade, "visual color grade must preserve the existing grade")
assert(Near(lichun.visual.corruptionAmount, lichun.corruption), "visual corruption amount must preserve corruption")

local yushuiA = Presentation.Step("yushui", 2.5)
local yushuiB = Presentation.Step("yushui", 2.5)
assert(yushuiA.rain.density > 0 and yushuiA.fog.opacity > 0, "雨水应带有雨雾")
assert(Near(yushuiA.rain.offset, yushuiB.rain.offset) and Near(yushuiA.fog.offset, yushuiB.fog.offset), "Step must be deterministic")

local jingzhe = Presentation.Step("jingzhe", 0)
assert(jingzhe.lightning.intensity > 0 and jingzhe.lightning.flash > 0, "惊蛰应在雷闪周期起点闪亮")
assert(jingzhe.visual.weather.lightning.flash == jingzhe.lightning.flash, "weather contract must include stepped lightning")

local chunfen = Presentation.Get("chunfen")
local qingming = Presentation.Get("qingming")
local guyu = Presentation.Get("guyu")
assert(chunfen.pollen.density > 0, "春分应有花粉")
assert(qingming.flowerLeaves.density > 0, "清明应有花叶")
assert(guyu.corruption > lichun.corruption, "谷雨应比立春具备更高的腐化层")

assert(lichun.visual.overlay.tint.r > jingzhe.visual.overlay.tint.r, "立春应比惊蛰更暖")
assert(lichun.visual.weather.rain.density < jingzhe.visual.weather.rain.density
    and lichun.visual.weather.lightning.intensity < jingzhe.visual.weather.lightning.intensity,
    "惊蛰应有区别于立春的雷雨天气")
assert(lichun.visual.foregroundDressing.windLeaves.direction ~= jingzhe.visual.foregroundDressing.windLeaves.direction,
    "惊蛰前景风向应区别于立春")
assert(qingming.visual.weather.fog.opacity > jingzhe.visual.weather.fog.opacity,
    "清明应比惊蛰更显雾气")
assert(qingming.visual.foregroundDressing.flowerLeaves.density > guyu.visual.foregroundDressing.flowerLeaves.density,
    "清明应比谷雨有更强的花叶前景")
assert(qingming.visual.colorGrade.saturation < guyu.visual.colorGrade.saturation,
    "清明应比谷雨更低饱和")
assert(qingming.visual.corruptionAmount < guyu.visual.corruptionAmount,
    "谷雨腐化量应高于清明")

local transition = Presentation.Transition("lichun", "guyu", 0.5)
assert(transition.fromId == "lichun" and transition.toId == "guyu")
assert(Near(transition.progress, 0.5), "transition progress must preserve the requested midpoint")
assert(Near(transition.corruption, (lichun.corruption + guyu.corruption) * 0.5), "transition must blend scalar channels")
assert(Near(transition.overlay.tint.r, (lichun.overlay.tint.r + guyu.overlay.tint.r) * 0.5), "transition must blend overlay tint")
assert(transition.transition.duration > 0 and transition.transition.easing == "smoothstep")
assert(Near(transition.visual.corruptionAmount, transition.corruption), "transition must keep visual corruption synchronized")
assert(Near(transition.visual.weather.rain.density, transition.rain.density), "transition must keep visual weather synchronized")

local sevenMinuteRun = Presentation.DiagnoseRun(7 * 60)
assert(sevenMinuteRun.duration == 420 and sevenMinuteRun.termDuration == 70)
assert(sevenMinuteRun.completedCycles == 1 and #sevenMinuteRun.rotation == 6,
    "七分钟 Run 应完整轮转六节气一次")
assert(sevenMinuteRun.rotation[1].termId == "lichun" and sevenMinuteRun.rotation[3].termId == "jingzhe"
    and sevenMinuteRun.rotation[5].termId == "qingming" and sevenMinuteRun.rotation[6].termId == "guyu",
    "轮转顺序必须与 Spring Base 一致")
assert(sevenMinuteRun.visualFatigue.uniqueTerms == 6 and sevenMinuteRun.visualFatigue.repeatedAdjacentPairs == 0,
    "完整轮转不应有相邻节气重复")
assert(HasValue(sevenMinuteRun.visualFatigue.lowContrastTransitions, "lichun->yushui") == false,
    "立春到雨水应提供足够的视觉差异")

local tenMinuteRun = Presentation.DiagnoseRun(10 * 60)
assert(tenMinuteRun.completedCycles == 1 and #tenMinuteRun.rotation == 9,
    "十分钟 Run 应记录一个完整轮转及后三个节气")
assert(tenMinuteRun.rotation[7].termId == "lichun" and tenMinuteRun.rotation[9].termId == "jingzhe",
    "十分钟 Run 的第二轮应从立春继续")
assert(tenMinuteRun.visualFatigue.lowContrastTransitions ~= nil
    and tenMinuteRun.visualFatigue.transitionDeltas[1].total > 0,
    "疲劳诊断应输出每次轮转的视觉差异")

print("SolarTermPresentationTests: Spring visual state and run diagnostics passed")
