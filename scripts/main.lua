local UI = require("urhox-libs/UI")
local Constants = require("core.Constants")
local Game = require("core.Game")
local MainMenu = require("ui.MainMenu")

---@type Widget?
local uiRoot_ = nil
local game_ = Game.New()

function Start()
    graphics.windowTitle = Constants.GAME_TITLE

    UI.Init({
        theme = "default-dark",
        scale = UI.Scale.DESIGN_RESOLUTION(Constants.DESIGN_WIDTH, Constants.DESIGN_HEIGHT),
    })

    game_:Start()
    uiRoot_ = MainMenu.Build(game_)
    UI.SetRoot(uiRoot_)

    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("KeyDown", "HandleKeyDown")

    print("=== " .. Constants.GAME_TITLE .. " 基础架构启动 ===")
end

function Stop()
    game_:Stop()
    UI.Shutdown()
end

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local timeStep = eventData["TimeStep"]:GetFloat()
    game_:Update(timeStep)
end

---@param eventType string
---@param eventData KeyDownEventData
function HandleKeyDown(eventType, eventData)
    local key = eventData["Key"]:GetInt()
    if key ~= KEY_Z or not uiRoot_ then
        return
    end

    local debugPanel = uiRoot_:FindById("debugPanel")
    if debugPanel then
        debugPanel:SetVisible(game_:ToggleDebug())
    end
end
