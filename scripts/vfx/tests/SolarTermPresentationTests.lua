package.path = "scripts/?.lua;scripts/?/init.lua;" .. package.path

local SolarTerms = require("data.SolarTerms")
local Presentation = require("vfx.SolarTermPresentation")

local function Near(actual, expected)
    return math.abs(actual - expected) < 0.0001
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

local yushuiA = Presentation.Step("yushui", 2.5)
local yushuiB = Presentation.Step("yushui", 2.5)
assert(yushuiA.rain.density > 0 and yushuiA.fog.opacity > 0, "雨水应带有雨雾")
assert(Near(yushuiA.rain.offset, yushuiB.rain.offset) and Near(yushuiA.fog.offset, yushuiB.fog.offset), "Step must be deterministic")

local jingzhe = Presentation.Step("jingzhe", 0)
assert(jingzhe.lightning.intensity > 0 and jingzhe.lightning.flash > 0, "惊蛰应在雷闪周期起点闪亮")

local chunfen = Presentation.Get("chunfen")
local qingming = Presentation.Get("qingming")
local guyu = Presentation.Get("guyu")
assert(chunfen.pollen.density > 0, "春分应有花粉")
assert(qingming.flowerLeaves.density > 0, "清明应有花叶")
assert(guyu.corruption > lichun.corruption, "谷雨应比立春具备更高的腐化层")

local transition = Presentation.Transition("lichun", "guyu", 0.5)
assert(transition.fromId == "lichun" and transition.toId == "guyu")
assert(Near(transition.progress, 0.5), "transition progress must preserve the requested midpoint")
assert(Near(transition.corruption, (lichun.corruption + guyu.corruption) * 0.5), "transition must blend scalar channels")
assert(Near(transition.overlay.tint.r, (lichun.overlay.tint.r + guyu.overlay.tint.r) * 0.5), "transition must blend overlay tint")
assert(transition.transition.duration > 0 and transition.transition.easing == "smoothstep")

print("SolarTermPresentationTests: six Spring solar terms passed")
