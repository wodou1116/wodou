local SPRING_BASE = {
    id = "spring_base",
    season = "spring",
    overlay = {
        tint = { r = 0.74, g = 0.91, b = 0.68, a = 0.16 },
        grade = { brightness = 1.0, contrast = 1.0, saturation = 1.0 },
    },
    rain = { density = 0, speed = 0, angle = 0.18 },
    fog = { opacity = 0, speed = 0 },
    lightning = { intensity = 0, cadence = 3.0, duration = 0.12 },
    windLeaves = { density = 0, speed = 0, direction = 1 },
    flowerLeaves = { density = 0, speed = 0, direction = 1 },
    pollen = { density = 0, speed = 0, direction = 1 },
    corruption = 0.04,
    transition = { duration = 0.7, easing = "smoothstep" },
}

local terms = {
    lichun = {
        id = "lichun",
        name = "立春",
        springBase = "spring_base",
        overlay = {
            tint = { r = 0.78, g = 0.96, b = 0.65, a = 0.18 },
            grade = { brightness = 1.04, saturation = 1.08 },
        },
        windLeaves = { density = 0.32, speed = 0.18, direction = 1 },
        flowerLeaves = { density = 0.10, speed = 0.10, direction = 1 },
        pollen = { density = 0.05, speed = 0.08, direction = 1 },
        transition = { duration = 0.65 },
    },
    yushui = {
        id = "yushui",
        name = "雨水",
        springBase = "spring_base",
        overlay = {
            tint = { r = 0.58, g = 0.75, b = 0.82, a = 0.24 },
            grade = { brightness = 0.94, saturation = 0.90 },
        },
        rain = { density = 0.62, speed = 0.83, angle = 0.24 },
        fog = { opacity = 0.33, speed = 0.07 },
        windLeaves = { density = 0.12, speed = 0.12, direction = 1 },
        flowerLeaves = { density = 0.08, speed = 0.08, direction = 1 },
        pollen = { density = 0.06, speed = 0.05, direction = 1 },
        corruption = 0.08,
        transition = { duration = 0.8 },
    },
    jingzhe = {
        id = "jingzhe",
        name = "惊蛰",
        springBase = "spring_base",
        overlay = {
            tint = { r = 0.63, g = 0.72, b = 0.89, a = 0.22 },
            grade = { contrast = 1.10, saturation = 1.04 },
        },
        rain = { density = 0.45, speed = 0.92, angle = 0.30 },
        fog = { opacity = 0.18, speed = 0.10 },
        lightning = { intensity = 0.84, cadence = 2.4, duration = 0.12 },
        windLeaves = { density = 0.25, speed = 0.30, direction = -1 },
        flowerLeaves = { density = 0.12, speed = 0.16, direction = -1 },
        pollen = { density = 0.08, speed = 0.10, direction = -1 },
        corruption = 0.14,
        transition = { duration = 0.55 },
    },
    chunfen = {
        id = "chunfen",
        name = "春分",
        springBase = "spring_base",
        overlay = {
            tint = { r = 0.91, g = 0.88, b = 0.68, a = 0.16 },
            grade = { brightness = 1.06, saturation = 1.12 },
        },
        rain = { density = 0.16, speed = 0.45, angle = 0.16 },
        fog = { opacity = 0.08, speed = 0.05 },
        windLeaves = { density = 0.36, speed = 0.20, direction = 1 },
        flowerLeaves = { density = 0.36, speed = 0.15, direction = 1 },
        pollen = { density = 0.46, speed = 0.12, direction = 1 },
        corruption = 0.10,
        transition = { duration = 0.7 },
    },
    qingming = {
        id = "qingming",
        name = "清明",
        springBase = "spring_base",
        overlay = {
            tint = { r = 0.67, g = 0.78, b = 0.68, a = 0.24 },
            grade = { brightness = 0.92, saturation = 0.84 },
        },
        rain = { density = 0.42, speed = 0.67, angle = 0.20 },
        fog = { opacity = 0.38, speed = 0.06 },
        windLeaves = { density = 0.18, speed = 0.14, direction = -1 },
        flowerLeaves = { density = 0.58, speed = 0.18, direction = -1 },
        pollen = { density = 0.15, speed = 0.08, direction = -1 },
        corruption = 0.20,
        transition = { duration = 0.9 },
    },
    guyu = {
        id = "guyu",
        name = "谷雨",
        springBase = "spring_base",
        overlay = {
            tint = { r = 0.54, g = 0.76, b = 0.61, a = 0.28 },
            grade = { brightness = 0.96, contrast = 1.06, saturation = 0.96 },
        },
        rain = { density = 0.78, speed = 0.76, angle = 0.22 },
        fog = { opacity = 0.30, speed = 0.09 },
        windLeaves = { density = 0.20, speed = 0.16, direction = 1 },
        flowerLeaves = { density = 0.25, speed = 0.13, direction = 1 },
        pollen = { density = 0.24, speed = 0.10, direction = 1 },
        corruption = 0.28,
        transition = { duration = 0.85 },
    },
}

local function Copy(value)
    if type(value) ~= "table" then
        return value
    end

    local result = {}
    for key, item in pairs(value) do
        result[key] = Copy(item)
    end
    return result
end

local function Merge(base, override)
    local result = Copy(base)
    for key, value in pairs(override) do
        if type(value) == "table" and type(result[key]) == "table" then
            result[key] = Merge(result[key], value)
        else
            result[key] = Copy(value)
        end
    end
    return result
end

local SolarTerms = {}

function SolarTerms.Get(termId)
    local term = terms[termId]
    if not term then
        return nil
    end
    return Merge(SPRING_BASE, term)
end

function SolarTerms.GetSpringBase()
    return Copy(SPRING_BASE)
end

return SolarTerms
