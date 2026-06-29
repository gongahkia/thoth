local Noise = require("src.noise")

local Climate = {}

local function clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function key(...)
    local parts = {}
    for index = 1, select("#", ...) do
        parts[index] = tostring(select(index, ...))
    end
    return table.concat(parts, ":")
end

local function latitudeFor(seed, y)
    return 0.5 + 0.5 * math.sin(y * 0.00045 + seed * 0.0001)
end

local function latitudeRadiansFor(worldOrSeed, y)
    if type(worldOrSeed) == "table" and worldOrSeed.latitudeAt then return worldOrSeed:latitudeAt(y) end
    if type(worldOrSeed) == "table" then return (latitudeFor(worldOrSeed.seed or 1, y or 0) * 2 - 1) * (math.pi / 2) end
    return (latitudeFor(worldOrSeed or 1, y or 0) * 2 - 1) * (math.pi / 2)
end

local function normalize(x, y)
    local length = math.sqrt(x * x + y * y)
    if length <= 0 then return 1, 0 end
    return x / length, y / length
end

function Climate.windAt(seed, y)
    local signedLatitude = latitudeRadiansFor(seed or 1, y or 0) / (math.pi / 2)
    local absLatitude = math.abs(signedLatitude)
    local hemisphere = signedLatitude >= 0 and 1 or -1
    if absLatitude < 0.33 then return normalize(-1, 0.18 * hemisphere) end
    if absLatitude < 0.66 then return normalize(1, 0.12 * hemisphere) end
    return normalize(-1, -0.1 * hemisphere)
end

local function climateKey(scale, gx, gy)
    return key(scale, gx, gy)
end

local function sampleAt(store, scale, gx, gy)
    local sample = store[climateKey(scale, gx, gy)]
    if not sample then return nil end
    return sample.precipitation or 0, sample.rainShadow or 0, sample.windX or 0, sample.windY or 0
end

function Climate.sample(world, info, x, y)
    if (world.climateSampleDepth or 0) > 0 then return nil end
    local store = world.climateSamples
    if not store then return nil end
    local stride = math.max(1, world.hydrologyBasinStride or 1)
    if stride <= 1 then return nil end
    local scaleX = x / info.factor
    local scaleY = y / info.factor
    local bx = (scaleX - (stride - 1) * 0.5) / stride
    local by = (scaleY - (stride - 1) * 0.5) / stride
    local ix = math.floor(bx)
    local iy = math.floor(by)
    local tx = bx - ix
    local ty = by - iy
    local p00, r00, wx00, wy00 = sampleAt(store, info.id, ix, iy)
    local p10, r10, wx10, wy10 = sampleAt(store, info.id, ix + 1, iy)
    local p01, r01, wx01, wy01 = sampleAt(store, info.id, ix, iy + 1)
    local p11, r11, wx11, wy11 = sampleAt(store, info.id, ix + 1, iy + 1)
    if p00 and p10 and p01 and p11 then
        local px0 = p00 + (p10 - p00) * tx
        local px1 = p01 + (p11 - p01) * tx
        local rx0 = r00 + (r10 - r00) * tx
        local rx1 = r01 + (r11 - r01) * tx
        local wx0 = wx00 + (wx10 - wx00) * tx
        local wx1 = wx01 + (wx11 - wx01) * tx
        local wy0 = wy00 + (wy10 - wy00) * tx
        local wy1 = wy01 + (wy11 - wy01) * tx
        return {
            precipitation = px0 + (px1 - px0) * ty,
            rainShadow = rx0 + (rx1 - rx0) * ty,
            windX = wx0 + (wx1 - wx0) * ty,
            windY = wy0 + (wy1 - wy0) * ty,
        }
    end
    local precipitation, rainShadow, windX, windY = sampleAt(store, info.id, math.floor(bx + 0.5), math.floor(by + 0.5))
    if not precipitation then return nil end
    return { precipitation = precipitation, rainShadow = rainShadow, windX = windX, windY = windY }
end

local function cellAt(region, gx, gy)
    return region.cells[key(gx, gy)]
end

local function gradient(region, cell)
    local west = cellAt(region, cell.gx - 1, cell.gy)
    local east = cellAt(region, cell.gx + 1, cell.gy)
    local north = cellAt(region, cell.gx, cell.gy - 1)
    local south = cellAt(region, cell.gx, cell.gy + 1)
    local dx = ((east and east.elevationBase or cell.elevationBase) - (west and west.elevationBase or cell.elevationBase)) * 0.5
    local dy = ((south and south.elevationBase or cell.elevationBase) - (north and north.elevationBase or cell.elevationBase)) * 0.5
    local distance = math.max(1, (region.stride or 1) * (region.scaleFactor or 1))
    return dx / distance, dy / distance
end

function Climate.solveRegion(world, region)
    local cells = {}
    for _, cell in pairs(region.cells or {}) do
        cells[#cells + 1] = cell
        cell.incomingMoisture = 0
        cell.incomingMoistureCount = 0
    end
    table.sort(cells, function(a, b)
        local awx, awy = Climate.windAt(world, a.y or a.gy or 0)
        local bwx, bwy = Climate.windAt(world, b.y or b.gy or 0)
        local ap = (a.gx or 0) * awx + (a.gy or 0) * awy
        local bp = (b.gx or 0) * bwx + (b.gy or 0) * bwy
        if ap == bp then
            if (a.gy or 0) == (b.gy or 0) then return (a.gx or 0) < (b.gx or 0) end
            return (a.gy or 0) < (b.gy or 0)
        end
        return ap < bp
    end)

    local maxPrecipitation, shadowCells = 0, 0
    local store = world.climateSamples
    for _, cell in ipairs(cells) do
        local windX, windY = Climate.windAt(world, cell.y or 0)
        local gradX, gradY = gradient(region, cell)
        local lift = math.max(0, windX * gradX + windY * gradY)
        local lee = math.max(0, -(windX * gradX + windY * gradY))
        local latitudeRadians = latitudeRadiansFor(world, cell.y or 0)
        local equatorMoisture = 1 - math.abs(latitudeRadians / (math.pi / 2))
        local incoming = cell.incomingMoistureCount > 0 and (cell.incomingMoisture / cell.incomingMoistureCount) or nil
        local sourceNoise = Noise.value(world.seed + 808, (cell.x or 0) * 0.0015, (cell.y or 0) * 0.0015, 11)
        local localSource = (cell.water and 0.46 or 0.16) + equatorMoisture * 0.32 + sourceNoise * 0.14
        local moisture = clamp((incoming or (0.38 + equatorMoisture * 0.34)) + localSource * 0.38, 0.04, 1)
        local condensation = clamp(moisture * lift * (world.orographicLiftScale or 8.5), 0, moisture * 0.72)
        local leeDrying = lee * (world.orographicLeeScale or 1.8)
        local background = 0.11 + equatorMoisture * 0.28 + (cell.water and 0.05 or 0)
        local precipitation = clamp(background + condensation - leeDrying, 0.015, 1)
        local outgoing = clamp(moisture - condensation * 0.85 - leeDrying * 0.05 + (cell.water and 0.16 or 0.012), 0.03, 1)
        local shadow = (lee > 0.001 and precipitation < 0.34) and clamp((0.34 - precipitation) * 2.4 + lee * 18, 0, 1) or 0
        cell.precipitation = precipitation
        cell.rainfall = precipitation
        cell.moisture = precipitation
        cell.airMoisture = moisture
        cell.windX = windX
        cell.windY = windY
        cell.rainShadowScore = shadow
        cell.rainShadow = shadow > 0.35
        if precipitation > maxPrecipitation then maxPrecipitation = precipitation end
        if cell.rainShadow then shadowCells = shadowCells + 1 end
        if store then
            store[climateKey(region.scale, cell.gx, cell.gy)] = {
                precipitation = precipitation,
                rainShadow = shadow,
                windX = windX,
                windY = windY,
            }
        end
        local stepX = windX > 0.35 and 1 or (windX < -0.35 and -1 or 0)
        local stepY = windY > 0.35 and 1 or (windY < -0.35 and -1 or 0)
        if stepX == 0 and stepY == 0 then stepX = windX >= 0 and 1 or -1 end
        local downwind = cellAt(region, cell.gx + stepX, cell.gy + stepY)
        if downwind then
            downwind.incomingMoisture = downwind.incomingMoisture + outgoing
            downwind.incomingMoistureCount = downwind.incomingMoistureCount + 1
        end
    end
    region.climate = {
        maxPrecipitation = maxPrecipitation,
        rainShadowCells = shadowCells,
    }
    return region.climate
end

return Climate
