-- capture_asset_test_scene.lua
-- 生成确定性 capture plan；没有截图 API 时只返回 PENDING_CAPTURE。

local Scene = require("scenes.qa.AssetReadabilityTestScene")
local Capture = {}

-- V1.3 metadata only: the runtime capture behavior remains unchanged.
local PLANNER_VERSION = "1.3"
local SCREENSHOT_BUDGET = {
    T0 = 0,
    T1_PER_ASSET = {min = 1, max = 2},
    T2_PER_MOTION_MAX = 3,
    T3_PER_SCENE = {min = 4, max = 6},
    T4 = "key_state_x_ratio_sample",
}
local ROI_POLICY = {min_scale = 1.5, max_scale = 2.0, unit = "subject_bbox"}
local SKIP_STATUSES = {capture = "SKIP_CAPTURE", vision_review = "SKIP_VISION_REVIEW"}

local function collectAssetRefs(value, refs, seen)
    if type(value) == "string" then
        if value:match("^image/") and not seen[value] then
            seen[value] = true
            table.insert(refs, value)
        end
    elseif type(value) == "table" then
        for _, item in pairs(value) do
            collectAssetRefs(item, refs, seen)
        end
    end
end

local function annotatePlan(plan)
    plan.planner_version = PLANNER_VERSION
    plan.screenshot_budget = SCREENSHOT_BUDGET
    plan.roi_policy = ROI_POLICY
    plan.skip_statuses = SKIP_STATUSES
    plan.hash_fields = {"asset_hash", "scene_config_hash", "qa_case_hash"}
    plan.contact_sheet = {tool = "qa_tooling.py", purpose = "coverage_only"}
    plan.keyframe_sampling = {tool = "qa_tooling.py", strategy = "evenly_spaced", max_per_motion = 3}
    for _, capture in ipairs(plan.captures) do
        local assetRefs = {}
        collectAssetRefs(Scene.Build(capture.mode), assetRefs, {})
        table.sort(assetRefs)
        capture.qa_case = {
            case_id = string.format("demo02.t1.%s.%s", capture.mode, capture.ratio:gsub(":", "x")),
            stage = "T1",
            mode = capture.mode,
            ratio = capture.ratio,
            state = "default",
            asset_refs = assetRefs,
            scene_config_ref = "scenes/qa/AssetReadabilityTestScene.lua",
            deterministic = true,
        }
        capture.skip_status = nil
        capture.roi_policy = ROI_POLICY
        capture.hash_fields = plan.hash_fields
    end
    return plan
end

function Capture.BuildPlan(modes)
    return annotatePlan(Scene.GetCapturePlan(modes))
end

function Capture.Run(captureApi, modes)
    local plan = Capture.BuildPlan(modes)
    if type(captureApi) ~= "function" then
        return plan
    end

    local completed = {}
    for _, capture in ipairs(plan.captures) do
        local result = captureApi(capture)
        if result == nil or result.status ~= "CAPTURED" then
            capture.status = "PENDING_CAPTURE"
        else
            capture.status = "CAPTURED"
            capture.path = result.path
        end
        table.insert(completed, capture)
    end
    plan.captures = completed
    plan.status = "CAPTURED"
    for _, capture in ipairs(completed) do
        if capture.status ~= "CAPTURED" then
            plan.status = "PENDING_CAPTURE"
            break
        end
    end
    return plan
end

return Capture
