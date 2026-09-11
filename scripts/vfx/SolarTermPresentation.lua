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

local function BuildVisualContract(state)
    state.visual = {
        overlay = {
            tint = state.overlay.tint,
        },
        weather = {
            rain = state.rain,
            fog = state.fog,
            lightning = state.lightning,
        },
        foregroundDressing = {
            windLeaves = state.windLeaves,
            flowerLeaves = state.flowerLeaves,
            pollen = state.pollen,
        },
        colorGrade = state.overlay.grade,
        corruptionAmount = state.corruption,
    }
    return state
end

local function NumericDelta(from, to)
    if type(from) == "number" and type(to) == "number" then
        return math.abs(to - from)
    end
    if type(from) ~= "table" or type(to) ~= "table" then
        return 0
    end

    local total = 0
    for key, value in pairs(from) do
        total = total + NumericDelta(value, to[key])
    end
    for key, value in pairs(to) do
        if from[key] == nil then
            total = total + NumericDelta(nil, value)
        end
    end
    return total
end

local function VisualDelta(from, to)
    local fromVisual = from.visual
    local toVisual = to.visual
    local overlay = NumericDelta(fromVisual.overlay, toVisual.overlay)
    local weather = NumericDelta(fromVisual.weather, toVisual.weather)
    local foregroundDressing = NumericDelta(fromVisual.foregroundDressing, toVisual.foregroundDressing)
    local colorGrade = NumericDelta(fromVisual.colorGrade, toVisual.colorGrade)
    local corruptionAmount = math.abs(toVisual.corruptionAmount - fromVisual.corruptionAmount)

    return {
        overlay = overlay,
        weather = weather,
        foregroundDressing = foregroundDressing,
        colorGrade = colorGrade,
        corruptionAmount = corruptionAmount,
        total = overlay + weather + foregroundDressing + colorGrade + corruptionAmount,
    }
end

function SolarTermPresentation.Get(termId)
    return BuildVisualContract(RequireTerm(termId))
end

function SolarTermPresentation.Step(termId, time)
    local state = SolarTermPresentation.Get(termId)
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
    return BuildVisualContract(state)
end

function SolarTermPresentation.DiagnoseRun(duration)
    assert(type(duration) == "number" and duration > 0, "duration must be a positive number")

    local sequence = SolarTerms.GetSpringSequence()
    local termDuration = SolarTerms.GetSpringTermDuration()
    local cycleDuration = #sequence * termDuration
    local rotation = {}
    local uniqueTerms = {}
    local repeatedAdjacentPairs = 0
    local transitionDeltas = {}
    local lowContrastTransitions = {}
    local previous = nil

    for startTime = 0, duration - 0.0001, termDuration do
        local sequenceIndex = math.floor(startTime / termDuration) % #sequence + 1
        local termId = sequence[sequenceIndex]
        local state = SolarTermPresentation.Step(termId, startTime)
        local entry = {
            termId = termId,
            startTime = startTime,
            endTime = math.min(startTime + termDuration, duration),
            visual = Copy(state.visual),
        }

        rotation[#rotation + 1] = entry
        uniqueTerms[termId] = true
        if previous then
            local delta = VisualDelta(previous, state)
            local label = previous.id .. "->" .. termId
            delta.fromId = previous.id
            delta.toId = termId
            transitionDeltas[#transitionDeltas + 1] = delta
            if previous.id == termId then
                repeatedAdjacentPairs = repeatedAdjacentPairs + 1
            end
            if delta.total < 1 then
                lowContrastTransitions[#lowContrastTransitions + 1] = label
            end
        end
        previous = state
    end

    local uniqueTermCount = 0
    for _ in pairs(uniqueTerms) do
        uniqueTermCount = uniqueTermCount + 1
    end

    return {
        duration = duration,
        termDuration = termDuration,
        cycleDuration = cycleDuration,
        completedCycles = math.floor(duration / cycleDuration),
        rotation = rotation,
        visualFatigue = {
            uniqueTerms = uniqueTermCount,
            repeatedAdjacentPairs = repeatedAdjacentPairs,
            transitionDeltas = transitionDeltas,
            lowContrastTransitions = lowContrastTransitions,
        },
    }
end

return SolarTermPresentation
