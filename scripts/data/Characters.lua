local characters = {
    {
        id = "shi_yu_zhe",
        name = "时御者",
        description = "巡行四时异境，借四时轮镇定失序节气，净化被浊气侵蚀的四时神。",
    },
    {
        id = "si_chen_zhe",
        name = "司辰者",
        description = "观天时、察节候，以星辰与节律校准四时轮，寻找节气失序的源头。",
    },
}

local Characters = {}

function Characters.List()
    return characters
end

function Characters.Get(characterId)
    for index = 1, #characters do
        if characters[index].id == characterId then
            return characters[index]
        end
    end

    return nil
end

return Characters
