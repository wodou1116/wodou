-- capture_asset_test_scene.lua
-- 生成确定性 capture plan；没有截图 API 时只返回 PENDING_CAPTURE。

local Scene = require("scenes.qa.AssetReadabilityTestScene")
local Capture = {}

function Capture.BuildPlan(modes)
    return Scene.GetCapturePlan(modes)
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

