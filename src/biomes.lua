local Biomes = {}

local bins = 16
local grid = {}

local function clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function terrestrialBiome(temperature, precipitation)
    if temperature < 0.2 then
        if precipitation > 0.52 then return "boreal_forest" end
        return "tundra"
    end
    if temperature < 0.38 then
        if precipitation < 0.28 then return "tundra" end
        if precipitation < 0.54 then return "grassland" end
        return "boreal_forest"
    end
    if temperature < 0.62 then
        if precipitation < 0.24 then return "desert" end
        if precipitation < 0.48 then return "grassland" end
        return "temperate_forest"
    end
    if precipitation < 0.2 then return "desert" end
    if precipitation < 0.42 then return "savanna" end
    if precipitation < 0.68 then return "temperate_forest" end
    return "rainforest"
end

for t = 1, bins do
    grid[t] = {}
    local temperature = (t - 0.5) / bins
    for p = 1, bins do
        local precipitation = (p - 0.5) / bins
        grid[t][p] = terrestrialBiome(temperature, precipitation)
    end
end

function Biomes.lookup(temperature, precipitation, elevation, water, slope, hotspotContribution, isFloodBasalt, karstType)
    temperature = clamp(temperature or 0.5, 0, 1)
    precipitation = clamp(precipitation or 0.5, 0, 1)
    elevation = elevation or 0
    slope = slope or 0
    if water then return elevation > -0.06 and "coast" or "ocean" end
    if isFloodBasalt then return "lava_flow" end
    if (karstType or 0) > 0 then return "karst" end
    if (hotspotContribution or 0) > 0.25 and slope < 0.2 then return "shield" end
    if elevation > 0.72 then return temperature < 0.35 and "snow" or "rock" end
    if slope > 0.18 and elevation > 0.45 then return "alpine" end
    if temperature < 0.14 then return "snow" end
    if precipitation > 0.82 and elevation < 0.12 then return "wetland" end
    local t = clamp(math.floor(temperature * bins) + 1, 1, bins)
    local p = clamp(math.floor(precipitation * bins) + 1, 1, bins)
    return grid[t][p]
end

function Biomes.grid()
    return grid
end

return Biomes
