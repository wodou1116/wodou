-- Demo 0.3 T2 deterministic capture contract.
-- This module is metadata-only: it never creates screenshots or visual scores.

local CaptureCases = {}

CaptureCases.STATUS = "PENDING_CAPTURE"
CaptureCases.SEED = 20260911
CaptureCases.MODE = "motion"
CaptureCases.RATIO = "16:9"
CaptureCases.FREEZE = true
CaptureCases.CAMERA = {
    space = "design_1920x1080",
    x = 960,
    y = 540,
    zoom = 1.0,
}
CaptureCases.ROI_POLICY = {
    requested_scale = 1.75,
    min_scale = 1.5,
    max_scale = 2.0,
    basis = "subject_bbox",
}
CaptureCases.SCREENSHOT_BUDGET = {
    min_per_motion = 0,
    max_per_motion = 3,
}
CaptureCases.KEYFRAME_SAMPLING = {
    strategy = "evenly_spaced",
    planned_frame_count = 3,
    max_per_motion = 3,
    indices = {0, 1, 2},
}

local PLAYER_POSITION = {x = 960, y = 640}
local TARGETS = {
    {asset_id = "A-12", enemy_id = "jiuweihu", name = "九尾狐", x = 1270, y = 460},
    {asset_id = "A-11", enemy_id = "bifang", name = "毕方", x = 1090, y = 780},
    {asset_id = "A-13", enemy_id = "kui", name = "夔", x = 650, y = 710},
}

local MOTION_STATES = {
    idle = {
        player_animation_state = "idle",
        enemy_animation_state = "idle",
        wheel_state = "idle",
        attack_state = "idle",
        animation_phase = 0.0,
    },
    move = {
        player_animation_state = "move",
        enemy_animation_state = "move",
        wheel_state = "idle",
        attack_state = "none",
        animation_phase = 0.5,
    },
    attack = {
        player_animation_state = "idle",
        enemy_animation_state = "hit",
        wheel_state = "attack",
        attack_state = "attack",
        animation_phase = 0.5,
    },
}

local DIMENSIONS = {
    {
        key = "wheel_separation",
        name = "Wheel Separation",
        motion = "idle",
        asset_refs = {"A-03", "A-10", "A-08-01", "A-08-02", "A-07-03", "A-08-04", "A-07-05"},
    },
    {
        key = "player_readability",
        name = "Player Readability",
        motion = "move",
        asset_refs = {"A-03", "A-10"},
    },
    {
        key = "combat_presence",
        name = "Combat Presence",
        motion = "attack",
        asset_refs = {"A-03", "A-10", "A-08-01", "A-17-01"},
    },
    {
        key = "ground_vfx_conflict",
        name = "Ground VFX Conflict",
        motion = "move",
        asset_refs = {"A-03", "A-10", "A-17-01", "A-17-06"},
    },
    {
        key = "attack_state_recognition",
        name = "Attack State Recognition",
        motion = "attack",
        asset_refs = {"A-03", "A-10", "A-08-01", "A-08-02", "A-07-03", "A-08-04", "A-07-05", "A-17-01"},
    },
}

local function CopyValue(value)
    if type(value) ~= "table" then
        return value
    end
    local copy = {}
    for key, item in pairs(value) do
        copy[key] = CopyValue(item)
    end
    return copy
end

local function BuildState(animation)
    return {
        playerAnimationState = animation.player_animation_state,
        enemyAnimationState = animation.enemy_animation_state,
        wheelState = animation.wheel_state,
        attackState = animation.attack_state,
        playerFacing = "right",
        enemyFacing = "left",
    }
end

function CaptureCases.GetContract()
    return {
        status = CaptureCases.STATUS,
        mode = CaptureCases.MODE,
        seed = CaptureCases.SEED,
        freeze = CaptureCases.FREEZE,
        camera = CopyValue(CaptureCases.CAMERA),
        screenshot_budget = CopyValue(CaptureCases.SCREENSHOT_BUDGET),
        roi_policy = CopyValue(CaptureCases.ROI_POLICY),
        keyframe_sampling = CopyValue(CaptureCases.KEYFRAME_SAMPLING),
        entity_positions = {
            player = CopyValue(PLAYER_POSITION),
            jiuweihu = {x = 1270, y = 460},
            bifang = {x = 1090, y = 780},
            kui = {x = 650, y = 710},
        },
    }
end

function CaptureCases.GetCases()
    local cases = {}
    for _, dimension in ipairs(DIMENSIONS) do
        for _, target in ipairs(TARGETS) do
            local animation = MOTION_STATES[dimension.motion]
            local assetRefs = CopyValue(dimension.asset_refs)
            table.insert(assetRefs, target.asset_id)
            table.sort(assetRefs)
            table.insert(cases, {
                case_id = string.format("demo03.t2.%s.%s", dimension.key, target.enemy_id),
                stage = "T2",
                status = CaptureCases.STATUS,
                mode = CaptureCases.MODE,
                ratio = CaptureCases.RATIO,
                dimension_key = dimension.key,
                dimension = dimension.name,
                asset_id = target.asset_id,
                enemy_id = target.enemy_id,
                target_name = target.name,
                motion = dimension.motion,
                seed = CaptureCases.SEED,
                freeze = CaptureCases.FREEZE,
                camera = CopyValue(CaptureCases.CAMERA),
                entity_positions = {
                    player = CopyValue(PLAYER_POSITION),
                    enemy = {id = target.enemy_id, x = target.x, y = target.y},
                },
                animation_state = CopyValue(animation),
                state = BuildState(animation),
                asset_refs = assetRefs,
                screenshot_budget = CopyValue(CaptureCases.SCREENSHOT_BUDGET),
                roi_policy = CopyValue(CaptureCases.ROI_POLICY),
                keyframe_sampling = CopyValue(CaptureCases.KEYFRAME_SAMPLING),
                contact_sheet = {
                    tool = "qa_tooling.py",
                    purpose = "coverage_only",
                    status = CaptureCases.STATUS,
                    source_frames = {},
                },
                captured_frames = {},
            })
        end
    end
    return cases
end

function CaptureCases.BuildCaptureOptions(case)
    assert(case and case.animation_state, "T2 capture case animation state is required")
    return {
        mode = case.mode,
        seed = case.seed,
        freeze = case.freeze,
        animationPhase = case.animation_state.animation_phase,
        camera = CopyValue(case.camera),
        state = CopyValue(case.state),
    }
end

return CaptureCases
