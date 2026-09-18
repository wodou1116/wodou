local function LoadModule(engineName, standaloneName)
    local ok, module = pcall(require, engineName)
    if ok then
        return module
    end
    return require(standaloneName)
end

local CaptureMode = LoadModule("qa.CaptureMode", "scripts.qa.CaptureMode")
local T2CaptureCases = LoadModule("qa.T2CaptureCases", "scripts.qa.T2CaptureCases")

local function AssertEqual(actual, expected, message)
    assert(actual == expected, message or string.format("expected %s, got %s", tostring(expected), tostring(actual)))
end

local contract = T2CaptureCases.GetContract()
AssertEqual(contract.status, "PENDING_CAPTURE")
AssertEqual(contract.seed, 20260911)
AssertEqual(contract.freeze, true)
AssertEqual(contract.camera.space, "design_1920x1080")
AssertEqual(contract.camera.x, 960)
AssertEqual(contract.camera.y, 540)
AssertEqual(contract.screenshot_budget.max_per_motion, 3)
AssertEqual(contract.roi_policy.min_scale, 1.5)
AssertEqual(contract.roi_policy.max_scale, 2.0)
AssertEqual(contract.keyframe_sampling.strategy, "evenly_spaced")
AssertEqual(#contract.keyframe_sampling.indices, 3)

local cases = T2CaptureCases.GetCases()
AssertEqual(#cases, 15)
local targets = {}
local dimensions = {}
for _, case in ipairs(cases) do
    AssertEqual(case.stage, "T2")
    AssertEqual(case.status, "PENDING_CAPTURE")
    AssertEqual(case.mode, "motion")
    AssertEqual(case.ratio, "16:9")
    AssertEqual(case.seed, 20260911)
    AssertEqual(case.freeze, true)
    AssertEqual(case.camera.x, 960)
    AssertEqual(case.camera.y, 540)
    AssertEqual(case.entity_positions.player.x, 960)
    AssertEqual(case.entity_positions.player.y, 640)
    assert(case.entity_positions.enemy.x ~= nil and case.entity_positions.enemy.y ~= nil,
        "T2 case must pin the target entity position")
    assert(case.animation_state.player_animation_state ~= nil and case.animation_state.enemy_animation_state ~= nil,
        "T2 case must pin player and enemy animation states")
    AssertEqual(case.screenshot_budget.max_per_motion, 3)
    AssertEqual(#case.keyframe_sampling.indices, 3)
    AssertEqual(case.keyframe_sampling.indices[1], 0)
    AssertEqual(case.keyframe_sampling.indices[2], 1)
    AssertEqual(case.keyframe_sampling.indices[3], 2)
    AssertEqual(#case.captured_frames, 0)
    AssertEqual(case.contact_sheet.status, "PENDING_CAPTURE")
    assert(case.roi_policy.requested_scale >= 1.5 and case.roi_policy.requested_scale <= 2.0,
        "T2 ROI must stay in the 1.5x-2.0x policy")

    targets[case.asset_id] = true
    dimensions[case.dimension_key] = true
    local capture = CaptureMode.New()
    local metadata = capture:Configure(T2CaptureCases.BuildCaptureOptions(case))
    AssertEqual(metadata.seed, 20260911)
    AssertEqual(metadata.freeze, true)
    AssertEqual(metadata.camera.x, 960)
    AssertEqual(metadata.camera.y, 540)
    AssertEqual(metadata.state.attackState, case.state.attackState)
    if case.motion == "attack" then
        AssertEqual(case.animation_state.enemy_animation_state, "move")
        assert(case.state.enemyMotionKeyframe == "dash"
            or case.state.enemyMotionKeyframe == "ranged_attack"
            or case.state.enemyMotionKeyframe == "melee_attack")
        AssertEqual(case.state.wheelAttackPulse, 0.09)
    end
    AssertEqual(capture:IsFrozen(), true)
    capture:ApplySeed()
    capture:Clear()
end

AssertEqual(targets["A-11"], true)
AssertEqual(targets["A-12"], true)
AssertEqual(targets["A-13"], true)
AssertEqual(dimensions["wheel_separation"], true)
AssertEqual(dimensions["player_readability"], true)
AssertEqual(dimensions["combat_presence"], true)
AssertEqual(dimensions["ground_vfx_conflict"], true)
AssertEqual(dimensions["attack_state_recognition"], true)

print("T2CaptureCaseTest: fixed capture contract and PENDING_CAPTURE matrix passed")
