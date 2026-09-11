local UI = require("urhox-libs/UI")
local Constants = require("core.Constants")
local Game = require("core.Game")
local BattleView = require("ui.BattleView")
local MainMenu = require("ui.MainMenu")

---@type Widget?
local uiRoot_ = nil
local game_ = Game.New()
local battleView_ = nil
local menuWidget_ = nil

function Start()
    graphics.windowTitle = Constants.GAME_TITLE

    UI.Init({
        theme = "default-dark",
        scale = UI.Scale.DESIGN_RESOLUTION(Constants.DESIGN_WIDTH, Constants.DESIGN_HEIGHT),
    })

    game_:Start()
    battleView_ = BattleView.New(game_, function()
        if menuWidget_ then
            menuWidget_:SetVisible(true)
        end
    end)
    menuWidget_ = MainMenu.Build(game_, function()
        menuWidget_:SetVisible(false)
        battleView_:Show()
    end)
    uiRoot_ = UI.Panel {
        id = "gameRoot",
        width = "100%",
        height = "100%",
        backgroundColor = { 10, 18, 16, 255 },
        children = {
            battleView_:Build(),
            menuWidget_,
        },
    }
    UI.SetRoot(uiRoot_)

    if Constants.QA_AUTORUN then
        local metadata = game_:StartQaCapture(Constants.QA_AUTORUN)
        menuWidget_:SetVisible(false)
        battleView_:Show()
        print("QA Capture: " .. metadata.mode .. " seed=" .. tostring(metadata.seed))
    end

    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("KeyDown", "HandleKeyDown")

    print("=== " .. Constants.GAME_TITLE .. " 春季纵切片启动 ===")
end

function Stop()
    game_:Stop()
    UI.Shutdown()
end

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local timeStep = eventData["TimeStep"]:GetFloat()
    if battleView_ then
        battleView_:Update(timeStep)
    end
end

---@param eventType string
---@param eventData KeyDownEventData
function HandleKeyDown(eventType, eventData)
    local key = eventData["Key"]:GetInt()
    if key == KEY_ESCAPE and battleView_ then
        game_:TogglePause()
    elseif key == KEY_R and battleView_ and (game_.state == Game.State.RESULT or game_.state == Game.State.BATTLE) then
        game_:RestartRun()
        battleView_:Show()
    elseif key == KEY_Z then
        game_:ToggleDebug()
    elseif game_:GetDebugEnabled() and battleView_ then
        if key == KEY_1 then
            battleView_:SetSolarTermOverride("lichun")
        elseif key == KEY_2 then
            battleView_:SetSolarTermOverride("yushui")
        elseif key == KEY_3 then
            battleView_:SetSolarTermOverride("jingzhe")
        elseif key == KEY_4 then
            battleView_:SetSolarTermOverride("chunfen")
        elseif key == KEY_5 then
            battleView_:SetSolarTermOverride("qingming")
        elseif key == KEY_6 then
            battleView_:SetSolarTermOverride("guyu")
        elseif key == KEY_C then
            battleView_:ToggleWheelCharged()
        elseif key == KEY_Q then
            local battle = game_.battleManager
            local scenario = battle.debugScenario or "peer_comparison"
            local mode = scenario:match("^combat_stress") and "combat_stress" or scenario
            game_:StartQaCapture({
                mode = mode,
                projectileCount = battle.debugProjectileTarget,
                freeze = true,
                seed = 20260911,
                presentationTime = 0.5,
                animationPhase = 0.5,
                state = {
                    solarTermId = battleView_:GetSolarTermId() or "lichun",
                    playerAnimationState = "idle",
                    enemyAnimationState = "move",
                    wheelState = battle.wheelState,
                },
            })
            battleView_:Show()
        elseif key == KEY_F4 then
            battleView_:ToggleShadows()
        elseif key == KEY_F5 then
            game_:ConfigureDebugScenario("single")
        elseif key == KEY_F6 then
            game_:ConfigureDebugScenario("peer_comparison")
        elseif key == KEY_F7 then
            game_:ConfigureDebugScenario("combat_stress", 20)
        elseif key == KEY_F8 then
            game_:ConfigureDebugScenario("combat_stress", 35)
        elseif key == KEY_F9 then
            game_:ConfigureDebugScenario("combat_stress", 50)
        elseif key == KEY_F10 then
            game_:ConfigureDebugScenario("boss")
        end
    end
end
