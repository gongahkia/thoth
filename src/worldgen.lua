local Noise = require("src.noise")
local Rng = require("src.rng")

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

local function classifyBiome(elevation, water, river, temperature, moisture, slope)
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

function WorldGen.new(seed, options)
    options = options or {}
    return setmetatable({
        seed = tonumber(seed) or 1,
        chunkSize = options.chunkSize or 64,
        seaLevel = options.seaLevel or 0,
        plateCellSize = options.plateCellSize or 640,
        cache = {},
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

function WorldGen:isValidBiome(id)
    return biomeIds[id] == true
end

function WorldGen:metadata()
    return {
        version = "terrain_proto_v1",
        seed = self.seed,
        chunkSize = self.chunkSize,
        seaLevel = self.seaLevel,
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
    local dx = Noise.fbm(self.seed + 606, x + info.factor, y, { frequency = 0.01 / info.factor, octaves = 3 }) - Noise.fbm(self.seed + 606, x - info.factor, y, { frequency = 0.01 / info.factor, octaves = 3 })
    local dy = Noise.fbm(self.seed + 606, x, y + info.factor, { frequency = 0.01 / info.factor, octaves = 3 }) - Noise.fbm(self.seed + 606, x, y - info.factor, { frequency = 0.01 / info.factor, octaves = 3 })
    local slope = clamp(math.sqrt(dx * dx + dy * dy) + plate.boundary * 0.08, 0, 1)
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
        biome = classifyBiome(elevation, water, false, temperature, rainfall, slope),
    }
end

function WorldGen:chunk(chunkX, chunkY, scale)
    local info = scaleInfo(scale)
    local cacheKey = key(chunkX, chunkY, info.id)
    if self.cache[cacheKey] then return self.cache[cacheKey] end
    local size = self.chunkSize
    local pad = 2
    local all = {}
    local ordered = {}
    for ly = -pad, size + pad - 1 do
        for lx = -pad, size + pad - 1 do
            local sx = (chunkX * size + lx) * info.factor
            local sy = (chunkY * size + ly) * info.factor
            local cell = self:baseSample(sx, sy, info.id)
            cell.lx, cell.ly = lx, ly
            all[key(lx, ly)] = cell
            ordered[#ordered + 1] = cell
        end
    end
    table.sort(ordered, function(a, b) return a.elevationBase > b.elevationBase end)
    for _, cell in ipairs(ordered) do
        if not cell.water then
            local best = nil
            for oy = -1, 1 do
                for ox = -1, 1 do
                    if not (ox == 0 and oy == 0) then
                        local candidate = all[key(cell.lx + ox, cell.ly + oy)]
                        if candidate and candidate.elevationBase < cell.elevationBase and (not best or candidate.elevationBase < best.elevationBase) then
                            best = candidate
                        end
                    end
                end
            end
            if best then
                cell.downX, cell.downY = best.x, best.y
                local transfer = cell.flow * 0.92
                best.flow = best.flow + transfer
                local fall = math.max(0, cell.elevationBase - best.elevationBase)
                cell.slope = clamp(math.max(cell.slope, fall / math.max(1, info.factor * 2)), 0, 1)
            end
        end
    end
    for _, cell in ipairs(ordered) do
        local riverThreshold = info.id == "local" and 18 or (info.id == "region" and 10 or 6)
        cell.erosion = clamp(math.log(cell.flow + 1) * cell.slope * 0.04, 0, 0.22)
        local deposition = (cell.flow > riverThreshold and cell.slope < 0.035) and 0.025 or 0
        cell.elevation = cell.elevationBase - cell.erosion + deposition
        cell.water = cell.elevation <= self.seaLevel
        cell.river = not cell.water and cell.flow > riverThreshold and cell.downX ~= nil
        cell.moisture = clamp(cell.rainfall + math.log(cell.flow + 1) * 0.035, 0, 1)
    end
    table.sort(ordered, function(a, b) return a.elevationBase < b.elevationBase end)
    for _, cell in ipairs(ordered) do
        if cell.downX then
            local dx = (cell.downX / info.factor) - chunkX * size
            local dy = (cell.downY / info.factor) - chunkY * size
            local downstream = all[key(dx, dy)]
            if downstream and cell.elevation < downstream.elevation then
                cell.elevation = downstream.elevation + 0.0005
            end
        end
        cell.biome = classifyBiome(cell.elevation, cell.water, cell.river, cell.temperature, cell.moisture, cell.slope)
    end
    local rows = {}
    for y = 1, size do
        rows[y] = {}
        for x = 1, size do
            rows[y][x] = copyCell(all[key(x - 1, y - 1)])
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

return WorldGen
