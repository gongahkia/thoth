local Noise = require("src.noise")
local Rng = require("src.rng")
local Hydrology = require("src.hydrology")

local WorldGen = {}
WorldGen.__index = WorldGen

local scales = {
    { id = "local", factor = 1, label = "local" },
    { id = "region", factor = 4, label = "region" },
    { id = "continent", factor = 16, label = "continent" },
}

local scaleById = {}
for _, scale in ipairs(scales) do
    scaleById[scale.id] = scale
    scaleById[scale.factor] = scale
end

local biomeIds = {
    ocean = true,
    coast = true,
    lake = true,
    river = true,
    wetland = true,
    desert = true,
    grassland = true,
    savanna = true,
    temperate_forest = true,
    rainforest = true,
    boreal_forest = true,
    tundra = true,
    alpine = true,
    snow = true,
    rock = true,
}

local billboardKinds = {
    tree = true,
    reed = true,
    rock = true,
    shrub = true,
    snow = true,
}

local function clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function floorDiv(value, divisor)
    return math.floor(value / divisor)
end

local function key(...)
    local parts = {}
    for index = 1, select("#", ...) do
        parts[index] = tostring(select(index, ...))
    end
    return table.concat(parts, ":")
end

local function scaleInfo(scale)
    return scaleById[scale or "local"] or scales[1]
end

local function plateCenter(seed, gx, gy, cellSize)
    local jitterX = Rng.signed(seed, gx, gy, 11) * cellSize * 0.38
    local jitterY = Rng.signed(seed, gx, gy, 23) * cellSize * 0.38
    local id = Rng.hash(seed, gx, gy, 37)
    local angle = Rng.unitAt(seed, gx, gy, 41) * math.pi * 2
    local speed = 0.25 + Rng.unitAt(seed, gx, gy, 43) * 0.75
    local crust = Rng.unitAt(seed, gx, gy, 47) > 0.42 and "continental" or "oceanic"
    return {
        id = id,
        gx = gx,
        gy = gy,
        x = (gx + 0.5) * cellSize + jitterX,
        y = (gy + 0.5) * cellSize + jitterY,
        vx = math.cos(angle) * speed,
        vy = math.sin(angle) * speed,
        crust = crust,
    }
end

local function twoNearestPlates(seed, x, y, cellSize)
    local gx, gy = floorDiv(x, cellSize), floorDiv(y, cellSize)
    local first, second
    for yy = gy - 1, gy + 1 do
        for xx = gx - 1, gx + 1 do
            local plate = plateCenter(seed, xx, yy, cellSize)
            local dx, dy = x - plate.x, y - plate.y
            plate.distance = math.sqrt(dx * dx + dy * dy)
            if not first or plate.distance < first.distance then
                second = first
                first = plate
            elseif not second or plate.distance < second.distance then
                second = plate
            end
        end
    end
    return first, second
end

local function classifyBiome(elevation, water, river, temperature, moisture, slope, lake)
    if lake then return "lake" end
    if water then
        return elevation > -0.06 and "coast" or "ocean"
    end
    if river then return "river" end
    if elevation > 0.72 then return temperature < 0.35 and "snow" or "rock" end
    if slope > 0.18 and elevation > 0.45 then return "alpine" end
    if temperature < 0.18 then return "snow" end
    if temperature < 0.32 then return moisture > 0.48 and "boreal_forest" or "tundra" end
    if moisture < 0.18 then return "desert" end
    if moisture < 0.36 then return temperature > 0.62 and "savanna" or "grassland" end
    if moisture > 0.78 and elevation < 0.12 then return "wetland" end
    if moisture > 0.68 and temperature > 0.58 then return "rainforest" end
    return "temperate_forest"
end

local function copyCell(cell)
    local out = {}
    for k, v in pairs(cell) do out[k] = v end
    return out
end

local function option(value, fallback)
    if value == nil then return fallback end
    return value
end

function WorldGen.new(seed, options)
    options = options or {}
    return setmetatable({
        seed = tonumber(seed) or 1,
        chunkSize = option(options.chunkSize, 64),
        seaLevel = option(options.seaLevel, 0),
        plateCellSize = option(options.plateCellSize, 640),
        hydrologyRegionChunks = option(options.hydrologyRegionChunks, 2),
        hydrologyHaloCells = option(options.hydrologyHaloCells, 8),
        hydrologyBasinChunks = option(options.hydrologyBasinChunks, 8),
        hydrologyBasinStride = option(options.hydrologyBasinStride, 4),
        hydrologyBasinHaloCells = option(options.hydrologyBasinHaloCells, 0),
        hydrologyBasinFlowScale = option(options.hydrologyBasinFlowScale, 0.6),
        cache = {},
        metrics = {
            chunkMisses = 0,
            hydrologyMisses = 0,
            billboardMisses = 0,
            basinMisses = 0,
            hydrologyCells = 0,
            basinCells = 0,
        },
    }, WorldGen)
end

function WorldGen.scaleInfo(scale)
    return scaleInfo(scale)
end

function WorldGen.biomeIds()
    local result = {}
    for id in pairs(biomeIds) do result[#result + 1] = id end
    table.sort(result)
    return result
end

function WorldGen.billboardKinds()
    local result = {}
    for id in pairs(billboardKinds) do result[#result + 1] = id end
    table.sort(result)
    return result
end

function WorldGen:isValidBiome(id)
    return biomeIds[id] == true
end

function WorldGen:metadata()
    return {
        version = "terrain_proto_v1",
        seed = self.seed,
        chunkSize = self.chunkSize,
        seaLevel = self.seaLevel,
        hydrologyRegionChunks = self.hydrologyRegionChunks,
        hydrologyHaloCells = self.hydrologyHaloCells,
        hydrologyBasinChunks = self.hydrologyBasinChunks,
        hydrologyBasinStride = self.hydrologyBasinStride,
        hydrologyBasinHaloCells = self.hydrologyBasinHaloCells,
        hydrologyBasinFlowScale = self.hydrologyBasinFlowScale,
        scales = scales,
    }
end

function WorldGen:plateAt(x, y)
    local first, second = twoNearestPlates(self.seed, x, y, self.plateCellSize)
    local gap = math.max(0, (second.distance or first.distance) - first.distance)
    local boundary = clamp(1 - gap / (self.plateCellSize * 0.34), 0, 1)
    local nx, ny = second.x - first.x, second.y - first.y
    local nlen = math.sqrt(nx * nx + ny * ny)
    if nlen > 0 then nx, ny = nx / nlen, ny / nlen end
    local rel = ((first.vx or 0) - (second.vx or 0)) * nx + ((first.vy or 0) - (second.vy or 0)) * ny
    local convergent = clamp(rel, 0, 1)
    local divergent = clamp(-rel, 0, 1)
    return {
        id = first.id,
        secondaryId = second.id,
        crust = first.crust,
        boundary = boundary,
        convergent = convergent,
        divergent = divergent,
        vx = first.vx,
        vy = first.vy,
    }
end

function WorldGen:baseSample(x, y, scale)
    local info = scaleInfo(scale)
    local wx, wy = Noise.warp(self.seed, x, y, { amount = 48 * info.factor, frequency = 0.0015 / info.factor })
    local plate = self:plateAt(wx, wy)
    local continent = Noise.fbm(self.seed + 101, wx, wy, { frequency = 0.0009, octaves = 5, salt = 1 })
    local rough = Noise.fbm(self.seed + 202, wx, wy, { frequency = 0.008 / math.sqrt(info.factor), octaves = 5, salt = 2 })
    local ridge = Noise.ridge(self.seed + 303, wx, wy, { frequency = 0.0035 / math.sqrt(info.factor), octaves = 4, salt = 3 })
    local continentalBias = plate.crust == "continental" and 0.24 or -0.2
    local uplift = plate.boundary * (plate.convergent * 0.55 + ridge * 0.28)
    local rift = plate.boundary * plate.divergent * 0.24
    local elevation = continentalBias + (continent - 0.5) * 0.72 + (rough - 0.5) * 0.24 + uplift - rift
    local latitude = 0.5 + 0.5 * math.sin(y * 0.00045 + self.seed * 0.0001)
    local temperature = clamp(1 - math.abs(latitude * 2 - 1) * 1.1 - math.max(0, elevation) * 0.42 + (Noise.fbm(self.seed + 404, x, y, { frequency = 0.002, octaves = 3 }) - 0.5) * 0.18, 0, 1)
    local moistureNoise = Noise.fbm(self.seed + 505, x, y, { frequency = 0.0022, octaves = 4 })
    local rainfall = clamp(0.2 + moistureNoise * 0.62 + (1 - math.abs(latitude - 0.5) * 2) * 0.18 - math.max(0, elevation) * 0.18 - uplift * 0.16, 0, 1)
    local slope = clamp(ridge * 0.1 + math.abs(rough - 0.5) * 0.16 + plate.boundary * 0.08 + uplift * 0.06, 0, 1)
    local water = elevation <= self.seaLevel
    return {
        x = x,
        y = y,
        scale = info.id,
        scaleFactor = info.factor,
        elevationBase = elevation,
        elevation = elevation,
        water = water,
        plateId = plate.id,
        plateBoundary = plate.boundary,
        plateCrust = plate.crust,
        uplift = uplift,
        rainfall = rainfall,
        temperature = temperature,
        moisture = rainfall,
        slope = slope,
        flow = rainfall,
        erosion = 0,
        river = false,
        lake = false,
        lakeDepth = 0,
        biome = classifyBiome(elevation, water, false, temperature, rainfall, slope, false),
    }
end

function WorldGen:chunk(chunkX, chunkY, scale)
    local info = scaleInfo(scale)
    local cacheKey = key(chunkX, chunkY, info.id)
    if self.cache[cacheKey] then return self.cache[cacheKey] end
    self.metrics.chunkMisses = self.metrics.chunkMisses + 1
    local size = self.chunkSize
    local region = Hydrology.region(self, chunkX, chunkY, info)
    local rows = {}
    for y = 1, size do
        rows[y] = {}
        for x = 1, size do
            local gx = chunkX * size + x - 1
            local gy = chunkY * size + y - 1
            local cell = copyCell(Hydrology.cell(region, gx, gy))
            cell.biome = classifyBiome(cell.elevation, cell.water, cell.river, cell.temperature, cell.moisture, cell.slope, cell.lake)
            rows[y][x] = cell
        end
    end
    local chunk = {
        x = chunkX,
        y = chunkY,
        scale = info.id,
        scaleFactor = info.factor,
        size = size,
        cells = rows,
    }
    self.cache[cacheKey] = chunk
    return chunk
end

function WorldGen:hydrologyStats(chunkX, chunkY, scale)
    return Hydrology.stats(self, chunkX, chunkY, scaleInfo(scale))
end

function WorldGen:preloadAround(x, y, radius, scale)
    local info = scaleInfo(scale)
    local minGX = floorDiv(math.floor(x - radius), info.factor)
    local maxGX = floorDiv(math.floor(x + radius), info.factor)
    local minGY = floorDiv(math.floor(y - radius), info.factor)
    local maxGY = floorDiv(math.floor(y + radius), info.factor)
    local minChunkX = floorDiv(minGX, self.chunkSize)
    local maxChunkX = floorDiv(maxGX, self.chunkSize)
    local minChunkY = floorDiv(minGY, self.chunkSize)
    local maxChunkY = floorDiv(maxGY, self.chunkSize)
    local chunks = 0
    for cy = minChunkY, maxChunkY do
        for cx = minChunkX, maxChunkX do
            self:chunk(cx, cy, info.id)
            chunks = chunks + 1
        end
    end
    return chunks
end

function WorldGen:preloadBillboardsAround(x, y, radius)
    local minChunkX = floorDiv(math.floor(x - radius), self.chunkSize)
    local maxChunkX = floorDiv(math.floor(x + radius), self.chunkSize)
    local minChunkY = floorDiv(math.floor(y - radius), self.chunkSize)
    local maxChunkY = floorDiv(math.floor(y + radius), self.chunkSize)
    local chunks = 0
    for cy = minChunkY, maxChunkY do
        for cx = minChunkX, maxChunkX do
            self:billboards(cx, cy)
            chunks = chunks + 1
        end
    end
    return chunks
end

function WorldGen:cacheStats()
    local stats = { total = 0, chunks = 0, hydrology = 0, basins = 0, billboards = 0 }
    for cacheKey in pairs(self.cache) do
        stats.total = stats.total + 1
        if string.sub(cacheKey, 1, 9) == "hydrology" then
            stats.hydrology = stats.hydrology + 1
        elseif string.sub(cacheKey, 1, 5) == "basin" then
            stats.basins = stats.basins + 1
        elseif string.sub(cacheKey, 1, 10) == "billboards" then
            stats.billboards = stats.billboards + 1
        else
            stats.chunks = stats.chunks + 1
        end
    end
    return stats
end

function WorldGen:metricsSnapshot()
    return {
        chunkMisses = self.metrics.chunkMisses,
        hydrologyMisses = self.metrics.hydrologyMisses,
        billboardMisses = self.metrics.billboardMisses,
        basinMisses = self.metrics.basinMisses,
        hydrologyCells = self.metrics.hydrologyCells,
        basinCells = self.metrics.basinCells,
    }
end

function WorldGen:sample(x, y, scale)
    local info = scaleInfo(scale)
    local gx = floorDiv(x, info.factor)
    local gy = floorDiv(y, info.factor)
    local chunkX = floorDiv(gx, self.chunkSize)
    local chunkY = floorDiv(gy, self.chunkSize)
    local lx = gx - chunkX * self.chunkSize
    local ly = gy - chunkY * self.chunkSize
    return self:chunk(chunkX, chunkY, info.id).cells[ly + 1][lx + 1]
end

function WorldGen:heightAt(x, y)
    local ix = math.floor(x)
    local iy = math.floor(y)
    local fx = x - ix
    local fy = y - iy
    local h00 = self:sample(ix, iy, "local").elevation
    local h10 = self:sample(ix + 1, iy, "local").elevation
    local h01 = self:sample(ix, iy + 1, "local").elevation
    local h11 = self:sample(ix + 1, iy + 1, "local").elevation
    local hx0 = h00 + (h10 - h00) * fx
    local hx1 = h01 + (h11 - h01) * fx
    return hx0 + (hx1 - hx0) * fy
end

function WorldGen:normalAt(x, y)
    local scale = 18
    local dx = (self:heightAt(x + 1, y) - self:heightAt(x - 1, y)) * scale * 0.5
    local dy = (self:heightAt(x, y + 1) - self:heightAt(x, y - 1)) * scale * 0.5
    local nx, ny, nz = -dx, -dy, 1
    local length = math.sqrt(nx * nx + ny * ny + nz * nz)
    if length <= 0 then return { x = 0, y = 0, z = 1 } end
    return { x = nx / length, y = ny / length, z = nz / length }
end

local function billboardSpecFor(seed, cell)
    if cell.water or cell.river then return nil end
    local chance = Rng.unitAt(seed, cell.x, cell.y, 701)
    local kind, width, height, color
    if (cell.biome == "temperate_forest" or cell.biome == "rainforest" or cell.biome == "boreal_forest") and cell.slope < 0.18 and chance < 0.18 then
        kind, width, height, color = "tree", 1.3, 3.4, { 0.08, 0.26, 0.12 }
    elseif cell.biome == "wetland" and chance < 0.16 then
        kind, width, height, color = "reed", 0.7, 1.8, { 0.28, 0.34, 0.16 }
    elseif (cell.biome == "rock" or cell.biome == "alpine") and chance < 0.12 then
        kind, width, height, color = "rock", 1.4, 1.3, { 0.36, 0.34, 0.32 }
    elseif cell.biome == "desert" and chance < 0.1 then
        kind, width, height, color = "shrub", 0.9, 1.2, { 0.34, 0.28, 0.12 }
    elseif cell.biome == "snow" and chance < 0.08 then
        kind, width, height, color = "snow", 0.9, 1.1, { 0.86, 0.88, 0.82 }
    else
        return nil
    end
    local jx = Rng.signed(seed, cell.x, cell.y, 709) * 1.5
    local jy = Rng.signed(seed, cell.x, cell.y, 719) * 1.5
    return {
        kind = kind,
        x = cell.x + jx,
        y = cell.y + jy,
        z = cell.elevation,
        width = width,
        height = height,
        color = color,
        biome = cell.biome,
    }
end

function WorldGen:billboards(chunkX, chunkY)
    local cacheKey = key("billboards", chunkX, chunkY)
    if self.cache[cacheKey] then return self.cache[cacheKey] end
    self.metrics.billboardMisses = self.metrics.billboardMisses + 1
    local chunk = self:chunk(chunkX, chunkY, "local")
    local result = {}
    for y = 3, chunk.size - 2, 4 do
        for x = 3, chunk.size - 2, 4 do
            local spec = billboardSpecFor(self.seed, chunk.cells[y][x])
            if spec then
                spec.z = self:heightAt(spec.x, spec.y)
                result[#result + 1] = spec
            end
        end
    end
    self.cache[cacheKey] = result
    return result
end

return WorldGen
