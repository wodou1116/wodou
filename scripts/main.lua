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
    end
end
