local Coast = {}

local function clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function key(gx, gy)
    return tostring(gx) .. ":" .. tostring(gy)
end

local neighbors = {
    { x = -1, y = -1, distance = 1.41421356237 },
    { x = 0, y = -1, distance = 1 },
    { x = 1, y = -1, distance = 1.41421356237 },
    { x = -1, y = 0, distance = 1 },
    { x = 1, y = 0, distance = 1 },
    { x = -1, y = 1, distance = 1.41421356237 },
    { x = 0, y = 1, distance = 1 },
    { x = 1, y = 1, distance = 1.41421356237 },
}

local function coastNormal(region, cell)
    local nx, ny, waterNeighbors = 0, 0, 0
    for _, offset in ipairs(neighbors) do
        local neighbor = region.cells[key((cell.gx or 0) + offset.x, (cell.gy or 0) + offset.y)]
        if neighbor and neighbor.water then
            nx = nx - offset.x / offset.distance
            ny = ny - offset.y / offset.distance
            waterNeighbors = waterNeighbors + 1
        end
    end
    local length = math.sqrt(nx * nx + ny * ny)
    if length <= 0 then return nil end
    return nx / length, ny / length, waterNeighbors
end

function Coast.apply(region, options)
    options = options or {}
    local seaLevel = options.seaLevel or 0
    local cliffs, beaches = 0, 0
    for _, cell in pairs(region.cells or {}) do
        cell.coastCliff = false
        cell.coastBeach = false
        cell.coastExposure = 0
        cell.coastErosion = 0
        cell.coastDeposition = 0
    end
    for _, cell in pairs(region.cells or {}) do
        if not cell.water then
            local nx, ny, waterNeighbors = coastNormal(region, cell)
            if nx then
                local windX, windY = cell.windX or 0, cell.windY or 0
                local exposure = clamp(windX * nx + windY * ny, 0, 1)
                local relief = math.max(0, (cell.elevation or cell.elevationBase or 0) - seaLevel)
                local sheltered = 1 - exposure
                cell.coastExposure = exposure
                if exposure > 0.42 and relief > 0.045 then
                    local erosion = clamp(exposure * relief * 0.18, 0.004, 0.055)
                    cell.coastCliff = true
                    cell.coastErosion = erosion
                    cell.elevation = (cell.elevation or cell.elevationBase or 0) - erosion
                    cell.slope = clamp(math.max(cell.slope or 0, 0.2 + exposure * 0.18), 0, 1)
                    cliffs = cliffs + 1
                elseif sheltered > 0.45 and relief < 0.22 then
                    local sediment = cell.sediment or 0
                    local deposition = clamp(0.006 + sheltered * 0.018 + sediment * 1.2 + waterNeighbors * 0.0015, 0.004, 0.045)
                    cell.coastBeach = true
                    cell.coastDeposition = deposition
                    cell.elevation = math.max((cell.elevation or cell.elevationBase or 0) + deposition, seaLevel + 0.006)
                    cell.slope = math.min(cell.slope or 0, 0.075)
                    beaches = beaches + 1
                end
            end
        end
    end
    region.coast = { cliffs = cliffs, beaches = beaches }
    return region.coast
end

return Coast
