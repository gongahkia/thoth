local Hydrology = {}

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

local Heap = {}
Heap.__index = Heap

function Heap.new()
    return setmetatable({ items = {} }, Heap)
end

function Heap:push(cell, priority)
    local items = self.items
    local item = { cell = cell, priority = priority }
    items[#items + 1] = item
    local index = #items
    while index > 1 do
        local parent = math.floor(index / 2)
        if items[parent].priority <= item.priority then break end
        items[index] = items[parent]
        index = parent
    end
    items[index] = item
end

function Heap:pop()
    local items = self.items
    local root = items[1]
    if not root then return nil end
    local last = items[#items]
    items[#items] = nil
    if #items > 0 then
        local index = 1
        while true do
            local left = index * 2
            local right = left + 1
            if left > #items then break end
            local child = left
            if right <= #items and items[right].priority < items[left].priority then child = right end
            if items[child].priority >= last.priority then break end
            items[index] = items[child]
            index = child
        end
        items[index] = last
    end
    return root.cell
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

local function riverThreshold(scaleId)
    if scaleId == "local" then return 82 end
    if scaleId == "region" then return 46 end
    return 24
end

local function regionIndex(chunkCoord, regionChunks)
    local offset = math.floor(regionChunks / 2)
    return floorDiv(chunkCoord + offset, regionChunks)
end

local function regionStart(regionCoord, regionChunks)
    local offset = math.floor(regionChunks / 2)
    return regionCoord * regionChunks - offset
end

local function regionCacheKey(info, regionX, regionY)
    return key("hydrology", info.id, regionX, regionY)
end

local function boundaryCell(region, gx, gy)
    return region.cells[key(gx, gy)]
end

local function terminal(cell)
    if cell.terminalCell then return cell.terminalCell end
    local cursor = cell
    local path = {}
    local guard = 0
    while cursor.downCell and guard < 200000 do
        if cursor.terminalCell then
            cursor = cursor.terminalCell
            break
        end
        path[#path + 1] = cursor
        cursor = cursor.downCell
        guard = guard + 1
    end
    for _, item in ipairs(path) do
        item.terminalCell = cursor
    end
    cell.terminalCell = cursor
    return cursor
end

local function lakeOutlet(cell)
    if cell.lakeOutletCell ~= nil then return cell.lakeOutletCell end
    local cursor = cell.downCell
    local path = { cell }
    local guard = 0
    while cursor and cursor.lake and guard < 200000 do
        if cursor.lakeOutletCell ~= nil then
            cursor = cursor.lakeOutletCell
            break
        end
        path[#path + 1] = cursor
        cursor = cursor.downCell
        guard = guard + 1
    end
    for _, item in ipairs(path) do
        item.lakeOutletCell = cursor
    end
    return cursor
end

local function addBoundary(region, heap, visitOrder, cell)
    if cell.hydroVisited then return end
    cell.hydroVisited = true
    cell.filledElevation = cell.elevationBase
    visitOrder[#visitOrder + 1] = cell
    heap:push(cell, cell.filledElevation)
end

local function solveRegion(world, chunkX, chunkY, info)
    local regionChunks = world.hydrologyRegionChunks or 4
    local regionX = regionIndex(chunkX, regionChunks)
    local regionY = regionIndex(chunkY, regionChunks)
    local cacheKey = regionCacheKey(info, regionX, regionY)
    if world.cache[cacheKey] then return world.cache[cacheKey] end
    if world.metrics then world.metrics.hydrologyMisses = world.metrics.hydrologyMisses + 1 end

    local chunkSize = world.chunkSize
    local startChunkX = regionStart(regionX, regionChunks)
    local startChunkY = regionStart(regionY, regionChunks)
    local interiorMinX = startChunkX * chunkSize
    local interiorMinY = startChunkY * chunkSize
    local interiorMaxX = interiorMinX + regionChunks * chunkSize - 1
    local interiorMaxY = interiorMinY + regionChunks * chunkSize - 1
    local halo = world.hydrologyHaloCells or math.floor(chunkSize / 2)
    local minX = interiorMinX - halo
    local minY = interiorMinY - halo
    local maxX = interiorMaxX + halo
    local maxY = interiorMaxY + halo
    local region = {
        id = key(info.id, regionX, regionY),
        scale = info.id,
        scaleFactor = info.factor,
        regionX = regionX,
        regionY = regionY,
        startChunkX = startChunkX,
        startChunkY = startChunkY,
        interiorMinX = interiorMinX,
        interiorMinY = interiorMinY,
        interiorMaxX = interiorMaxX,
        interiorMaxY = interiorMaxY,
        minX = minX,
        minY = minY,
        maxX = maxX,
        maxY = maxY,
        cells = {},
    }

    for gy = minY, maxY do
        for gx = minX, maxX do
            local cell = world:baseSample(gx * info.factor, gy * info.factor, info.id)
            cell.gx = gx
            cell.gy = gy
            cell.hydrologyRegion = region.id
            cell.filledElevation = cell.elevationBase
            cell.flow = math.max(0.01, cell.rainfall or 0)
            cell.erosion = 0
            cell.deposition = 0
            cell.river = false
            cell.riverBank = false
            cell.lake = false
            cell.lakeDepth = 0
            cell.lakeSurface = nil
            region.cells[key(gx, gy)] = cell
        end
    end

    local heap = Heap.new()
    local visitOrder = {}
    for gx = minX, maxX do
        addBoundary(region, heap, visitOrder, boundaryCell(region, gx, minY))
        addBoundary(region, heap, visitOrder, boundaryCell(region, gx, maxY))
    end
    for gy = minY + 1, maxY - 1 do
        addBoundary(region, heap, visitOrder, boundaryCell(region, minX, gy))
        addBoundary(region, heap, visitOrder, boundaryCell(region, maxX, gy))
    end

    while true do
        local cell = heap:pop()
        if not cell then break end
        for _, offset in ipairs(neighbors) do
            local nextCell = region.cells[key(cell.gx + offset.x, cell.gy + offset.y)]
            if nextCell and not nextCell.hydroVisited then
                nextCell.hydroVisited = true
                nextCell.downCell = cell
                nextCell.downX = cell.x
                nextCell.downY = cell.y
                nextCell.downDistance = offset.distance * info.factor
                nextCell.filledElevation = math.max(nextCell.elevationBase, cell.filledElevation)
                visitOrder[#visitOrder + 1] = nextCell
                heap:push(nextCell, nextCell.filledElevation)
            end
        end
    end

    for index = #visitOrder, 1, -1 do
        local cell = visitOrder[index]
        if cell.downCell then
            cell.downCell.flow = cell.downCell.flow + cell.flow * 0.965
        end
    end

    local threshold = riverThreshold(info.id)
    local lakeMinDepth = 0.018
    for _, cell in ipairs(visitOrder) do
        local down = cell.downCell
        local hydroSlope = 0
        if down then
            local distance = math.max(1, cell.downDistance or info.factor)
            local filledFall = math.max(0, cell.filledElevation - down.filledElevation)
            local baseFall = math.max(0, cell.elevationBase - down.elevationBase)
            hydroSlope = math.max(filledFall, baseFall * 0.25) / distance
        end
        cell.slope = clamp(math.max(cell.slope or 0, hydroSlope), 0, 1)
        local ocean = cell.elevationBase <= world.seaLevel
        cell.lakeDepth = math.max(0, cell.filledElevation - cell.elevationBase)
        cell.lake = (not ocean) and cell.lakeDepth > lakeMinDepth and cell.filledElevation > world.seaLevel + 0.006
        if cell.lake then
            cell.lakeSurface = cell.filledElevation
        end
        local flowPower = math.log(cell.flow + 1)
        cell.erosion = clamp(flowPower * cell.slope * 0.035, 0, 0.22)
        local lowSlope = cell.slope < 0.024
        cell.deposition = (cell.flow > threshold and lowSlope) and 0.018 or 0
        cell.water = ocean or cell.lake
        cell.river = not cell.water and cell.flow > threshold and cell.downCell ~= nil
        if cell.lake then
            cell.elevation = cell.lakeSurface
        elseif cell.water then
            cell.elevation = cell.elevationBase
        else
            cell.elevation = cell.elevationBase - cell.erosion + cell.deposition
        end
    end

    for _, cell in ipairs(visitOrder) do
        if cell.river then
            for _, offset in ipairs(neighbors) do
                local neighbor = region.cells[key(cell.gx + offset.x, cell.gy + offset.y)]
                if neighbor and not neighbor.water and not neighbor.river then
                    neighbor.riverBank = true
                end
            end
        end
    end

    for _, cell in ipairs(visitOrder) do
        if cell.downCell and not cell.water and cell.elevation < cell.downCell.elevation then
            cell.elevation = cell.downCell.elevation + 0.0005
        end
    end

    local stats = {
        rivers = 0,
        lakes = 0,
        lakeCells = 0,
        endorheic = 0,
        seamMismatches = 0,
        uphillRejects = 0,
        basins = 0,
        maxFlow = 0,
    }
    local basins = {}
    for gy = interiorMinY, interiorMaxY do
        for gx = interiorMinX, interiorMaxX do
            local cell = region.cells[key(gx, gy)]
            local root = terminal(cell)
            cell.basinId = key("b", info.id, root.gx, root.gy)
            cell.watershedId = key("w", info.id, regionX, regionY, root.gx, root.gy)
            basins[cell.basinId] = true
            if cell.lake then
                local outlet = lakeOutlet(cell)
                if outlet then
                    cell.outletX = outlet.x
                    cell.outletY = outlet.y
                    cell.lakeId = key("l", info.id, math.floor(cell.lakeSurface * 10000 + 0.5), outlet.gx, outlet.gy)
                end
                stats.lakeCells = stats.lakeCells + 1
            end
            if cell.river then stats.rivers = stats.rivers + 1 end
            if cell.lake then stats.lakes = stats.lakes + 1 end
            if not cell.downCell and not cell.water then stats.endorheic = stats.endorheic + 1 end
            if cell.downCell and cell.filledElevation + 0.000001 < cell.downCell.filledElevation then stats.uphillRejects = stats.uphillRejects + 1 end
            if cell.downCell and not region.cells[key(cell.downCell.gx, cell.downCell.gy)] then stats.seamMismatches = stats.seamMismatches + 1 end
            if cell.flow > stats.maxFlow then stats.maxFlow = cell.flow end
        end
    end
    for _ in pairs(basins) do stats.basins = stats.basins + 1 end
    region.stats = stats
    world.cache[cacheKey] = region
    return region
end

function Hydrology.region(world, chunkX, chunkY, info)
    return solveRegion(world, chunkX, chunkY, info)
end

function Hydrology.cell(region, gx, gy)
    return region.cells[key(gx, gy)]
end

function Hydrology.stats(world, chunkX, chunkY, info)
    local region = solveRegion(world, chunkX, chunkY, info)
    local out = {}
    for k, v in pairs(region.stats) do out[k] = v end
    return out
end

return Hydrology
