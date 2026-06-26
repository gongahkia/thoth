local WorldGen = require("src.worldgen")

local Diagnostics = {}

local defaultSeeds = { 3, 19, 45, 46 }
local badSeeds = {
    { seed = 1, flags = { "water_high", "river_low", "single_biome_high" } },
    { seed = 9, flags = { "water_low", "single_biome_high" } },
    { seed = 42, flags = { "water_high" } },
    { seed = 99, flags = { "water_low", "steep_slope_high" } },
}

local defaultThresholds = {
    waterRatioMin = 0.12,
    waterRatioMax = 0.88,
    riverRatioMin = 0.001,
    riverRatioMax = 0.18,
    lakeRatioMax = 0.18,
    meanSlopeMax = 0.36,
    steepSlopeRatioMax = 0.58,
    singleBiomeMax = 0.92,
    minBiomeCount = 3,
}

local function copyMap(input)
    local out = {}
    for k, v in pairs(input or {}) do out[k] = v end
    return out
end

local function copyList(input)
    local out = {}
    for index, value in ipairs(input or {}) do out[index] = value end
    return out
end

local function mergeThresholds(input)
    local out = copyMap(defaultThresholds)
    for k, v in pairs(input or {}) do out[k] = v end
    return out
end

local function addFlag(stats, message)
    stats.flags[#stats.flags + 1] = message
end

local function sortedBiomeRatios(stats)
    local out = {}
    for id, count in pairs(stats.biomes) do
        out[#out + 1] = { id = id, count = count, ratio = count / math.max(1, stats.cells) }
    end
    table.sort(out, function(a, b)
        if a.count == b.count then return a.id < b.id end
        return a.count > b.count
    end)
    return out
end

local function finalize(stats, thresholds)
    stats.landRatio = stats.land / math.max(1, stats.cells)
    stats.waterRatio = stats.water / math.max(1, stats.cells)
    stats.riverRatio = stats.rivers / math.max(1, stats.cells)
    stats.lakeRatio = stats.lakes / math.max(1, stats.cells)
    stats.meanSlope = stats.slopeSum / math.max(1, stats.cells)
    stats.steepSlopeRatio = stats.steepSlopes / math.max(1, stats.cells)
    stats.biomeRatios = sortedBiomeRatios(stats)
    stats.biomeCount = #stats.biomeRatios
    stats.topBiome = stats.biomeRatios[1]

    if stats.waterRatio < thresholds.waterRatioMin then addFlag(stats, "water_low") end
    if stats.waterRatio > thresholds.waterRatioMax then addFlag(stats, "water_high") end
    if stats.riverRatio < thresholds.riverRatioMin then addFlag(stats, "river_low") end
    if stats.riverRatio > thresholds.riverRatioMax then addFlag(stats, "river_high") end
    if stats.lakeRatio > thresholds.lakeRatioMax then addFlag(stats, "lake_high") end
    if stats.meanSlope > thresholds.meanSlopeMax then addFlag(stats, "mean_slope_high") end
    if stats.steepSlopeRatio > thresholds.steepSlopeRatioMax then addFlag(stats, "steep_slope_high") end
    if stats.biomeCount < thresholds.minBiomeCount then addFlag(stats, "biome_count_low") end
    if stats.topBiome and stats.topBiome.ratio > thresholds.singleBiomeMax then addFlag(stats, "single_biome_high") end
    return stats
end

function Diagnostics.defaultSeeds()
    return copyList(defaultSeeds)
end

function Diagnostics.badSeeds()
    local out = {}
    for index, fixture in ipairs(badSeeds) do
        out[index] = { seed = fixture.seed, flags = copyList(fixture.flags) }
    end
    return out
end

function Diagnostics.defaultThresholds()
    return copyMap(defaultThresholds)
end

function Diagnostics.analyzeSeed(seed, options)
    options = options or {}
    local thresholds = mergeThresholds(options.thresholds)
    local world = WorldGen.new(seed, options.worldOptions)
    local scale = options.scale or "local"
    local chunkRadius = options.chunkRadius or 1
    local sampleStep = options.sampleStep or 4
    local stats = {
        seed = seed,
        scale = scale,
        chunkRadius = chunkRadius,
        sampleStep = sampleStep,
        cells = 0,
        land = 0,
        water = 0,
        rivers = 0,
        lakes = 0,
        slopeSum = 0,
        maxSlope = 0,
        steepSlopes = 0,
        minElevation = math.huge,
        maxElevation = -math.huge,
        maxFlow = 0,
        biomes = {},
        flags = {},
    }

    for cy = -chunkRadius, chunkRadius do
        for cx = -chunkRadius, chunkRadius do
            local chunk = world:chunk(cx, cy, scale)
            for y = 1, chunk.size, sampleStep do
                for x = 1, chunk.size, sampleStep do
                    local cell = chunk.cells[y][x]
                    stats.cells = stats.cells + 1
                    if cell.water then stats.water = stats.water + 1 else stats.land = stats.land + 1 end
                    if cell.river then stats.rivers = stats.rivers + 1 end
                    if cell.lake then stats.lakes = stats.lakes + 1 end
                    local slope = cell.slope or 0
                    stats.slopeSum = stats.slopeSum + slope
                    if slope > stats.maxSlope then stats.maxSlope = slope end
                    if slope > 0.18 then stats.steepSlopes = stats.steepSlopes + 1 end
                    if cell.elevation < stats.minElevation then stats.minElevation = cell.elevation end
                    if cell.elevation > stats.maxElevation then stats.maxElevation = cell.elevation end
                    if (cell.flow or 0) > stats.maxFlow then stats.maxFlow = cell.flow or 0 end
                    stats.biomes[cell.biome] = (stats.biomes[cell.biome] or 0) + 1
                end
            end
        end
    end
    stats.cache = world:cacheStats()
    stats.metrics = world:metricsSnapshot()
    return finalize(stats, thresholds)
end

function Diagnostics.sweep(options)
    options = options or {}
    local seeds = options.seeds or defaultSeeds
    local results = {}
    local failed = {}
    for _, seed in ipairs(seeds) do
        local stats = Diagnostics.analyzeSeed(seed, options)
        results[#results + 1] = stats
        if #stats.flags > 0 then failed[#failed + 1] = stats end
    end
    return {
        results = results,
        failed = failed,
        thresholds = mergeThresholds(options.thresholds),
    }
end

function Diagnostics.formatResult(stats)
    local top = stats.topBiome and (stats.topBiome.id .. ":" .. string.format("%.3f", stats.topBiome.ratio)) or "none"
    local flags = #stats.flags > 0 and table.concat(stats.flags, ",") or "ok"
    return string.format(
        "seed=%s cells=%d land=%.3f water=%.3f river=%.3f lake=%.3f mean_slope=%.3f steep=%.3f biomes=%d top=%s max_flow=%.2f flags=%s",
        tostring(stats.seed),
        stats.cells,
        stats.landRatio,
        stats.waterRatio,
        stats.riverRatio,
        stats.lakeRatio,
        stats.meanSlope,
        stats.steepSlopeRatio,
        stats.biomeCount,
        top,
        stats.maxFlow,
        flags
    )
end

function Diagnostics.formatFailures(failed)
    local parts = {}
    for _, stats in ipairs(failed or {}) do
        parts[#parts + 1] = Diagnostics.formatResult(stats)
    end
    return table.concat(parts, "\n")
end

return Diagnostics
