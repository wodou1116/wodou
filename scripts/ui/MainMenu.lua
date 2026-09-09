local UI = require("urhox-libs/UI")
local Constants = require("core.Constants")
local Characters = require("data.Characters")
local Seasons = require("data.Seasons")

local MainMenu = {}

local COLORS = {
    background = { 18, 23, 24, 255 },
    surface = { 31, 38, 37, 244 },
    surfaceMuted = { 40, 48, 46, 230 },
    bronze = { 150, 124, 81, 255 },
    jade = { 93, 131, 117, 255 },
    text = { 232, 229, 215, 255 },
    textMuted = { 164, 169, 158, 255 },
}

local function CreateRoleButton(character, game, selectedLabel, statusLabel)
    return UI.Button {
        width = 260,
        height = 64,
        text = character.name,
        variant = "secondary",
        fontSize = 22,
        onClick = function()
            local ok, message = game:SelectCharacter(character.id)
            if ok then
                selectedLabel:SetText(character.name .. "｜" .. character.description)
                statusLabel:SetText("已选择：" .. message)
            else
                statusLabel:SetText(message)
            end
        end,
    }
end

local function CreateSeasonButtons(statusLabel)
    local children = {}
    local seasons = Seasons.List()

    for index = 1, #seasons do
        local season = seasons[index]
        table.insert(children, UI.Button {
            width = 180,
            height = 56,
            text = season.name,
            variant = season.unlocked and "primary" or "secondary",
            disabled = not season.unlocked,
            fontSize = 18,
            onClick = function()
                statusLabel:SetText("当前行歌：" .. season.name)
            end,
        })
    end

    return UI.Panel {
        flexDirection = "row",
        flexWrap = "wrap",
        justifyContent = "center",
        gap = 16,
        children = children,
    }
end

function MainMenu.Build(game)
    local selectedCharacter = game:GetSelectedCharacter()
    local selectedLabel = UI.Label {
        text = selectedCharacter.name .. "｜" .. selectedCharacter.description,
        width = "100%",
        fontSize = 18,
        fontColor = COLORS.textMuted,
        textAlign = "center",
        whiteSpace = "normal",
    }
    local statusLabel = UI.Label {
        text = "基础架构已就绪，当前使用程序占位界面。",
        fontSize = 16,
        fontColor = COLORS.textMuted,
        textAlign = "center",
    }

    local roleButtons = {}
    local characters = Characters.List()
    for index = 1, #characters do
        table.insert(roleButtons, CreateRoleButton(characters[index], game, selectedLabel, statusLabel))
    end

    local startButton = UI.Button {
        width = 360,
        height = 72,
        text = "开始行歌",
        variant = "primary",
        fontSize = 24,
        onClick = function()
            local ok, message = game:StartRun(Constants.DEFAULT_SEASON_ID)
            if ok then
                statusLabel:SetText("已进入基础流程：" .. message .. "（战斗资产待接入）")
            else
                statusLabel:SetText(message)
            end
        end,
    }

    return UI.Panel {
        id = "gameRoot",
        width = "100%",
        height = "100%",
        backgroundColor = COLORS.background,
        pointerEvents = "box-none",
        children = {
            UI.SafeAreaView {
                width = "100%",
                height = "100%",
                nativeMenuInset = true,
                padding = 40,
                justifyContent = "center",
                alignItems = "center",
                children = {
                    UI.Panel {
                        width = "82%",
                        maxWidth = 1220,
                        padding = 44,
                        gap = 24,
                        alignItems = "center",
                        backgroundColor = COLORS.surface,
                        borderColor = COLORS.bronze,
                        borderWidth = 2,
                        borderRadius = 24,
                        children = {
                            UI.Label {
                                text = Constants.GAME_TITLE,
                                fontSize = 44,
                                fontWeight = "bold",
                                fontColor = COLORS.text,
                                textAlign = "center",
                            },
                            UI.Label {
                                text = "一局一季，六节气构筑",
                                fontSize = 20,
                                fontColor = COLORS.jade,
                                textAlign = "center",
                            },
                            UI.Panel {
                                width = 190,
                                height = 190,
                                borderRadius = 95,
                                borderWidth = 5,
                                borderColor = COLORS.bronze,
                                backgroundColor = COLORS.surfaceMuted,
                                justifyContent = "center",
                                alignItems = "center",
                                children = {
                                    UI.Label {
                                        text = "四时轮\n资产占位",
                                        fontSize = 22,
                                        fontColor = COLORS.textMuted,
                                        textAlign = "center",
                                        whiteSpace = "normal",
                                    },
                                },
                            },
                            UI.Panel {
                                flexDirection = "row",
                                flexWrap = "wrap",
                                justifyContent = "center",
                                gap = 20,
                                children = roleButtons,
                            },
                            selectedLabel,
                            CreateSeasonButtons(statusLabel),
                            startButton,
                            statusLabel,
                        },
                    },
                },
            },
            UI.Panel {
                id = "debugPanel",
                visible = Constants.DEBUG_ENABLED,
                position = "absolute",
                top = 24,
                left = 24,
                padding = 12,
                backgroundColor = { 0, 0, 0, 170 },
                borderRadius = 8,
                pointerEvents = "none",
                children = {
                    UI.Label {
                        text = "DEBUG｜1920×1080｜Z 隐藏",
                        fontSize = 14,
                        fontColor = COLORS.text,
                    },
                },
            },
        },
    }
end

return MainMenu
