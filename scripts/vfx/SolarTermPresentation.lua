local SolarTerms = require("data.SolarTerms")

local SolarTermPresentation = {}

local function Clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function Loop(time, speed)
    local value = math.fmod((time or 0) * (speed or 0), 1)
    return value < 0 and value + 1 or value
end

local function Copy(value)
    if type(value) ~= "table" then
        return value
    end

    local result = {}
    for key, item in pairs(value) do
        result[key] = Copy(item)
    end
    return result
end

local function Blend(from, to, progress)
    if type(from) == "number" and type(to) == "number" then
        return from + (to - from) * progress
    end
    if type(from) ~= "table" or type(to) ~= "table" then
        return progress < 1 and Copy(from) or Copy(to)
    end

    local result = {}
    for key, value in pairs(from) do
        result[key] = Blend(value, to[key], progress)
    end
    for key, value in pairs(to) do
        if result[key] == nil then
            result[key] = Blend(nil, value, progress)
        end
    end
    return result
end

local function RequireTerm(termId)
    local term = SolarTerms.Get(termId)
    assert(term, "unknown solar term: " .. tostring(termId))
    return term
end

function SolarTermPresentation.Get(termId)
    return RequireTerm(termId)
end

function SolarTermPresentation.Step(termId, time)
    local state = RequireTerm(termId)
    local currentTime = time or 0
    local lightning = state.lightning
    local cycle = Loop(currentTime, 1 / lightning.cadence)
    local flashWindow = lightning.duration / lightning.cadence
    local flash = 0
    if lightning.intensity > 0 and cycle < flashWindow then
        flash = lightning.intensity * (1 - cycle / flashWindow)
    end

    state.time = currentTime
    state.rain.offset = Loop(currentTime, state.rain.speed)
    state.fog.offset = Loop(currentTime, state.fog.speed)
    state.lightning.flash = flash
    state.windLeaves.offset = Loop(currentTime, state.windLeaves.speed)
    state.windLeaves.sway = math.sin(currentTime * state.windLeaves.speed * math.pi * 2) * state.windLeaves.density
    state.flowerLeaves.offset = Loop(currentTime, state.flowerLeaves.speed)
    state.flowerLeaves.sway = math.sin(currentTime * state.flowerLeaves.speed * math.pi * 2) * state.flowerLeaves.density
    state.pollen.offset = Loop(currentTime, state.pollen.speed)
    state.pollen.sway = math.sin(currentTime * state.pollen.speed * math.pi * 2) * state.pollen.density
    return state
end

function SolarTermPresentation.Transition(fromId, toId, progress)
    local from = RequireTerm(fromId)
    local to = RequireTerm(toId)
    local rawProgress = Clamp(progress or 0, 0, 1)
    local weight = rawProgress * rawProgress * (3 - rawProgress * 2)
    local state = Blend(from, to, weight)

    state.id = rawProgress >= 1 and to.id or from.id
    state.name = rawProgress >= 1 and to.name or from.name
    state.fromId = from.id
    state.toId = to.id
    state.progress = rawProgress
    state.transition = {
        duration = to.transition.duration,
        easing = "smoothstep",
        weight = weight,
    }
    return state
end

return SolarTermPresentation
