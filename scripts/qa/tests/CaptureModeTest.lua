package.path = "scripts/?.lua;scripts/?/init.lua;" .. package.path

local CaptureMode = require("qa.CaptureMode")

local function AssertEqual(actual, expected, message)
    assert(actual == expected, message or string.format("expected %s, got %s", tostring(expected), tostring(actual)))
end

local capture = CaptureMode.New()
local metadata = capture:Configure({
    mode = "peer_comparison",
    seed = 20260911,
    freeze = true,
    animationPhase = 0.25,
    camera = { x = 960, y = 540, zoom = 1.15 },
    state = { label = "peer_grid" },
})

AssertEqual(metadata.mode, "peer_comparison")
AssertEqual(metadata.seed, 20260911)
AssertEqual(metadata.freeze, true)
AssertEqual(metadata.camera.x, 960)
AssertEqual(metadata.animation.phase, 0.25)
AssertEqual(metadata.state.label, "peer_grid")
AssertEqual(capture:GetAnimationPhase(), 0.25)
AssertEqual(capture:GetPresentationTime(), 0.25)

capture:SetStateMetadata({ enemyCount = 12 })
AssertEqual(capture:GetStateMetadata().label, "peer_grid", "runtime metadata must preserve requested state")
AssertEqual(capture:GetStateMetadata().enemyCount, 12)

metadata.camera.x = 0
AssertEqual(capture:GetMetadata().camera.x, 960, "metadata must be a snapshot")

capture:Configure({ mode = "motion", freeze = true, keyframe = { index = 3, count = 5 } })
AssertEqual(capture:GetAnimationPhase(), 0.75)

capture:Clear()
assert(not capture:IsEnabled())

local ok = pcall(function()
    capture:Configure({ mode = "not_a_capture_mode" })
end)
assert(not ok, "unknown QA capture mode must fail fast")

print("CaptureModeTest: deterministic metadata, modes, and freeze state passed")
