local UI = require("urhox-libs/UI")
local AssetCatalog = require("core.AssetCatalog")
local Constants = require("core.Constants")
local Characters = require("data.Characters")

local MainMenu = {}

local COLORS = {
    ink = { 15, 24, 22, 255 },
    surface = { 20, 34, 31, 235 },
    surfaceStrong = { 28, 45, 40, 248 },
    bronze = { 180, 142, 78, 255 },
    bronzeMuted = { 104, 82, 50, 255 },
    jade = { 112, 169, 141, 255 },
    text = { 244, 238, 215, 255 },
    textMuted = { 184, 193, 175, 255 },
}

local function RoleCard(character, image, cardImage, game, onSelected)
    local selected = character.id == game.selectedCharacterId
    local button
    button = UI.Button {
        width = 420,
        height = 610,
        padding = 22,
        backgroundImage = cardImage,
        backgroundFit = "fill",
        backgroundColor = selected and COLORS.surfaceStrong or COLORS.surface,
        borderColor = selected and COLORS.jade or COLORS.bronzeMuted,
        borderWidth = selected and 4 or 2,
        borderRadius = 18,
        flexDirection = "column",
        justifyContent = "flex-end",
        alignItems = "center",
        onClick = function()
            game:SelectCharacter(character.id)
            onSelected(character)
        end,
        children = {
            UI.Panel {
                position = "absolute",
                left = 40,
                top = 30,
                width = 340,
                height = 410,
                backgroundImage = image,
                backgroundFit = "contain",
                pointerEvents = "none",
            },
            UI.Label {
                text = character.name,
                width = "100%",
                fontSize = 34,
                fontWeight = "bold",
                fontColor = COLORS.text,
                textAlign = "center",
                pointerEvents = "none",
            },
            UI.Label {
                text = character.description,
                width = "100%",
                minHeight = 82,
                marginTop = 10,
                fontSize = 18,
                fontColor = COLORS.textMuted,
                textAlign = "center",
                whiteSpace = "normal",
                pointerEvents = "none",
            },
        },
    }
    return button
end

function MainMenu.Build(game, onStart)
    local characters = Characters.List()
    local statusLabel = UI.Label {
        text = "选择行歌者，进入春季异境",
        fontSize = 18,
        fontColor = COLORS.textMuted,
        textAlign = "center",
    }

    local cardsPanel = UI.Panel {
        width = 900,
        height = 620,
        flexDirection = "row",
        justifyContent = "space-between",
        alignItems = "center",
    }

    local function RebuildCards(selectedCharacter)
        cardsPanel:RemoveAllChildren()
        cardsPanel:AddChild(RoleCard(characters[1], AssetCatalog.characters.shi_yu_zhe, AssetCatalog.ui.roleCardLeft, game, RebuildCards))
        cardsPanel:AddChild(RoleCard(characters[2], AssetCatalog.characters.si_chen_zhe, AssetCatalog.ui.roleCardRight, game, RebuildCards))
        if selectedCharacter then
            statusLabel:SetText("已选择：" .. selectedCharacter.name)
        end
    end

    RebuildCards(nil)

    local root = UI.Panel {
        id = "mainMenu",
        width = "100%",
        height = "100%",
        position = "absolute",
        left = 0,
        top = 0,
        backgroundImage = AssetCatalog.environments.spring,
        backgroundFit = "cover",
        backgroundColor = COLORS.ink,
        children = {
            UI.Panel {
                position = "absolute",
                left = 0,
                top = 0,
                width = "100%",
                height = "100%",
                backgroundColor = { 7, 15, 13, 150 },
                pointerEvents = "none",
            },
            UI.SafeAreaView {
                width = "100%",
                height = "100%",
                nativeMenuInset = true,
                alignItems = "center",
                paddingTop = 34,
                children = {
                    UI.Label {
                        text = Constants.GAME_TITLE,
                        fontSize = 50,
                        fontWeight = "bold",
                        fontColor = COLORS.text,
                        textAlign = "center",
                    },
                    UI.Label {
                        text = "春序初试｜一局一季，六节气构筑",
                        marginTop = 6,
                        marginBottom = 18,
                        fontSize = 20,
                        fontColor = COLORS.jade,
                        textAlign = "center",
                    },
                    cardsPanel,
                    UI.Button {
                        width = 360,
                        height = 70,
                        marginTop = 16,
                        text = "启程 · 春季异境",
                        variant = "primary",
                        fontSize = 25,
                        onClick = function()
                            local ok, message = game:StartRun(Constants.DEFAULT_SEASON_ID)
                            statusLabel:SetText(message)
                            if ok and onStart then
                                onStart()
                            end
                        end,
                    },
                    statusLabel,
                },
            },
        },
    }

    return root
end

return MainMenu
