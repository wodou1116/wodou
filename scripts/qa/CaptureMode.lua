local CaptureMode = {}
CaptureMode.__index = CaptureMode

CaptureMode.Modes = {
    single = true,
    peer_comparison = true,
    motion = true,
    combat_stress = true,
    boss = true,
}

CaptureMode.DEFAULT_SEED = 20260911

local function Clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function CopyTable(source)
    local copy = {}
    for key, value in pairs(source) do
        copy[key] = type(value) == "table" and CopyTable(value) or value
    end
    return copy
end

local function MergeTable(target, source)
    for key, value in pairs(source or {}) do
        target[key] = type(value) == "table" and CopyTable(value) or value
    end
    return target
end

local function ResolveAnimationPhase(options)
    if options.keyframe then
        local keyframe = options.keyframe
        assert(type(keyframe) == "table" and type(keyframe.index) == "number" and type(keyframe.count) == "number",
            "QA capture keyframe requires numeric index/count")
        assert(keyframe.count > 1, "QA capture keyframe count must exceed one")
        return Clamp(keyframe.index / (keyframe.count - 1), 0, 1), CopyTable(keyframe)
    end
    if options.animationPhase ~= nil then
        assert(type(options.animationPhase) == "number", "QA capture animationPhase must be a number")
        return Clamp(options.animationPhase, 0, 1), nil
    end
    return nil, nil
end

function CaptureMode.New()
    return setmetatable({ enabled = false, state = nil }, CaptureMode)
end

function CaptureMode:Configure(options)
    options = options or {}
    local mode = options.mode or "single"
    assert(CaptureMode.Modes[mode], "unknown QA capture mode: " .. tostring(mode))

    local seed = math.floor(options.seed or CaptureMode.DEFAULT_SEED)
    local phase, keyframe = ResolveAnimationPhase(options)
    local camera = options.camera or {}
    self.enabled = true
    self.state = {
        mode = mode,
        seed = seed,
        freeze = options.freeze ~= false,
        projectileCount = options.projectileCount,
        presentationTime = options.presentationTime,
        camera = {
            space = camera.space or "design_1920x1080",
            x = camera.x or 960,
            y = camera.y or 540,
            zoom = camera.zoom or 1,
        },
        animation = {
            phase = phase,
            keyframe = keyframe,
        },
        state = CopyTable(options.state or {}),
    }
    return self:GetMetadata()
end

function CaptureMode:Clear()
    self.enabled = false
    self.state = nil
end

function CaptureMode:IsEnabled()
    return self.enabled
end

function CaptureMode:IsFrozen()
    return self.enabled and self.state.freeze
end

function CaptureMode:GetMode()
    return self.state and self.state.mode or nil
end

function CaptureMode:GetProjectileCount()
    return self.state and self.state.projectileCount or nil
end

function CaptureMode:GetAnimationPhase()
    return self.state and self.state.animation.phase or nil
end

function CaptureMode:GetPresentationTime()
    if not self.state then
        return 0
    end
    return self.state.presentationTime or self.state.animation.phase or 0
end

function CaptureMode:ApplySeed()
    assert(self.enabled and self.state, "QA capture is not configured")
    math.randomseed(self.state.seed)
    return self.state.seed
end

function CaptureMode:SetStateMetadata(metadata)
    assert(self.enabled and self.state, "QA capture is not configured")
    MergeTable(self.state.state, metadata)
end

function CaptureMode:GetStateMetadata()
    if not self.state then
        return nil
    end
    return CopyTable(self.state.state)
end

function CaptureMode:GetMetadata()
    if not self.state then
        return nil
    end
    return CopyTable(self.state)
end

return CaptureMode
