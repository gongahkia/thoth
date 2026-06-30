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

local function latitudeUnit(cell)
    return math.min(1, math.abs(cell.latitudeRadians or 0) / (math.pi / 2))
end

local function forestBiome(biome)
    return biome == "temperate_forest" or biome == "rainforest" or biome == "boreal_forest"
end

for t = 1, bins do
    grid[t] = {}
    local temperature = (t - 0.5) / bins
    for p = 1, bins do
        local precipitation = (p - 0.5) / bins
        grid[t][p] = terrestrialBiome(temperature, precipitation)
    end
end

function Biomes.lookup(temperature, precipitation, elevation, water, slope, hotspotContribution, isFloodBasalt, karstType, reefStage)
    temperature = clamp(temperature or 0.5, 0, 1)
    precipitation = clamp(precipitation or 0.5, 0, 1)
    elevation = elevation or 0
    slope = slope or 0
    if (reefStage or 0) == 4 then return "lagoon" end
    if (reefStage or 0) > 0 and (reefStage or 0) < 4 then return "reef" end
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

function Biomes.refineCell(cell)
    if not cell then return nil end
    cell.treeline = 0
    cell.riparian = 0
    cell.fireFrequency = 0
    cell.biomeSecondary = nil
    if cell.water then return cell.biome end
    local biome = cell.biome or Biomes.lookup(cell.temperature, cell.rainfall or cell.precipitation, cell.elevation, cell.water, cell.slope, cell.hotspotContribution, cell.isFloodBasalt, cell.karstType, cell.reefStage)
    local temperature = clamp(cell.temperature or 0.5, 0, 1)
    local precipitation = clamp(cell.rainfall or cell.precipitation or cell.moisture or 0.5, 0, 1)
    local elevation = cell.elevation or cell.elevationBase or 0
    local latUnit = latitudeUnit(cell)
    local gdd = temperature * (1 - latUnit) * 4000
    local wind = math.sqrt((cell.windX or 0) * (cell.windX or 0) + (cell.windY or 0) * (cell.windY or 0))
    if elevation > 0.38 and (gdd < 1100 or wind > 0.9) and forestBiome(biome) then
        cell.treeline = 1
        biome = temperature < 0.3 and "tundra" or "alpine"
    end
    if not cell.water and cell.riverBank then
        cell.riparian = 1
        if precipitation < 0.34 and (biome == "desert" or biome == "grassland" or biome == "savanna") then biome = "temperate_forest" end
    end
    local latDegrees = latUnit * 90
    local summerDry = latDegrees >= 25 and latDegrees <= 45 and (cell.monsoonIndex or 0) < 0.15 and temperature > 0.42
    if summerDry then
        cell.fireFrequency = clamp((0.58 - precipitation) * 1.6 + (temperature - 0.42) * 0.35, 0, 1)
        if cell.fireFrequency > 0.3 and forestBiome(biome) then biome = temperature > 0.6 and "savanna" or "grassland" end
    end
    if biome ~= "ocean" and biome ~= "coast" and biome ~= "river" and biome ~= "lake" then
        local warm = terrestrialBiome(clamp(temperature + 0.05, 0, 1), precipitation)
        local wet = terrestrialBiome(temperature, clamp(precipitation + 0.08, 0, 1))
        local secondary = warm ~= biome and warm or (wet ~= biome and wet or nil)
        cell.biomeSecondary = secondary
    end
    cell.biome = biome
    return biome
end

function Biomes.grid()
    return grid
end

return Biomes
