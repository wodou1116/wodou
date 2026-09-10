-- AssetReadabilityTestScene.lua
-- 纯数据 QA 场景模块：可被 Lua require 加载，不修改正式运行时场景。
-- 截图由外部 Maker/运行时注入；本模块没有截图 API，不伪造截图。

local Scene = {}

local RATIOS = {
    {id = "4:3", width = 1280, height = 960},
    {id = "16:9", width = 1280, height = 720},
    {id = "20:9", width = 1280, height = 576},
    {id = "21:9", width = 1280, height = 549},
}

local function entity(id, asset, x, y, layer, scale)
    return {id = id, asset = asset, x = x, y = y, layer = layer, scale = scale or 1.0}
end

local function single()
    return {
        mode = "single",
        background = "image/environments/spring_arena.png",
        entities = {
            entity("player", "image/characters/shi_yu_zhe.png", 0, -40, "player", 1.0),
            entity("monster_01", "image/enemies/jiuweihu.png", 220, -40, "enemy", 0.8),
        },
        checks = {"normal", "zoom_50", "zoom_100", "shadow_on", "shadow_off"},
    }
end

local function peerComparison()
    local entities = {
        entity("player", "image/characters/shi_yu_zhe.png", 0, -220, "player", 0.9),
    }
    local groups = {
        {prefix = "jiuweihu", asset = "image/enemies/jiuweihu.png", x = -300, y = 160},
        {prefix = "bifang", asset = "image/enemies/bifang.png", x = 0, y = 160},
        {prefix = "kui", asset = "image/enemies/kui.png", x = 300, y = 160},
    }
    for _, group in ipairs(groups) do
        for index = 1, 4 do
            table.insert(entities, entity(group.prefix .. "_" .. index, group.asset,
                group.x + ((index - 1) % 2) * 90 - 45, group.y - math.floor((index - 1) / 2) * 100,
                "enemy", 0.65))
        end
    end
    for index = 1, 2 do
        table.insert(entities, entity("elite_" .. index, "image/enemies/spring_elite.png", -120 + (index - 1) * 240, -20, "elite", 0.9))
    end
    return {mode = "peer_comparison", background = "image/environments/spring_arena.png", entities = entities,
        checks = {"peer_confusion", "silhouette", "value", "color", "motion", "combat_role"}}
end

local function combatStress()
    local scene = peerComparison()
    scene.mode = "combat_stress"
    scene.projectile_count = 35
    scene.vfx = {"root", "fire", "freeze"}
    scene.damage_numbers = true
    scene.telegraph = "image/vfx/warnings/circle.png"
    for index = 1, 8 do
        local row = math.floor((index - 1) / 4)
        local column = (index - 1) % 4
        table.insert(scene.entities, entity("stress_enemy_" .. index, "image/enemies/jiuweihu.png",
            -360 + column * 240, -260 + row * 100, "enemy", 0.5))
    end
    return scene
end

local function boss()
    return {
        mode = "boss",
        background = "image/environments/spring_arena.png",
        entities = {
            entity("player", "image/characters/shi_yu_zhe.png", -260, -160, "player", 0.9),
            entity("boss", "image/bosses/jumang.png", 180, 20, "boss", 1.0),
        },
        telegraph = "image/vfx/warnings/circle.png",
        target_marker = true,
        player_vfx = {"root", "fire", "freeze"},
        checks = {"telegraph_visibility", "boss_occlusion", "target_marker", "damage_number"},
    }
end

local BUILDERS = {single = single, peer_comparison = peerComparison, combat_stress = combatStress, boss = boss}

function Scene.Build(mode)
    local builder = BUILDERS[mode]
    assert(builder ~= nil, "unknown AssetReadabilityTestScene mode: " .. tostring(mode))
    return builder()
end

function Scene.GetModes()
    return {"single", "peer_comparison", "combat_stress", "boss"}
end

function Scene.GetCapturePlan(modes)
    local selected = modes or Scene.GetModes()
    local captures = {}
    for _, mode in ipairs(selected) do
        local layout = Scene.Build(mode)
        for _, ratio in ipairs(RATIOS) do
            table.insert(captures, {
                mode = mode,
                ratio = ratio.id,
                width = ratio.width,
                height = ratio.height,
                layout_entity_count = #layout.entities,
                output = string.format("T1_%s_%s_001.png", ratio.id:gsub(":", "x"), mode),
                status = "PENDING_CAPTURE",
                requires_runtime_capture_api = true,
            })
        end
    end
    return {scene_id = "AssetReadabilityTestScene", deterministic = true, status = "PENDING_CAPTURE",
        reason = "Maker screenshot API is not available to this module", captures = captures}
end

return Scene

