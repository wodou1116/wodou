local Constants = {
    GAME_TITLE = "四时风物：节气行歌",
    DESIGN_WIDTH = 1920,
    DESIGN_HEIGHT = 1080,
    DEFAULT_CHARACTER_ID = "shi_yu_zhe",
    DEFAULT_SEASON_ID = "spring",
    DEBUG_ENABLED = true,
    QA_AUTORUN = {
        mode = "peer_comparison",
        freeze = true,
        seed = 20260911,
        presentationTime = 0.5,
        animationPhase = 0.5,
        state = {
            solarTermId = "lichun",
            playerAnimationState = "idle",
            enemyAnimationState = "move",
        },
    },
}

return Constants
