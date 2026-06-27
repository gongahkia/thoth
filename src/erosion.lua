local Erosion = {}

local function orderedCells(region)
    if region.visitOrder then return region.visitOrder end
    local cells = {}
    for _, cell in pairs(region.cells or {}) do cells[#cells + 1] = cell end
    table.sort(cells, function(a, b)
        local ae = a.filledElevation or a.elevation or a.elevationBase or 0
        local be = b.filledElevation or b.elevation or b.elevationBase or 0
        if ae == be then
            if (a.gy or 0) == (b.gy or 0) then return (a.gx or 0) < (b.gx or 0) end
            return (a.gy or 0) < (b.gy or 0)
        end
        return ae < be
    end)
    return cells
end

local function upliftFor(cell, mode)
    if type(mode) == "function" then return mode(cell) or 0 end
    if type(mode) == "number" then return mode end
    if mode == false then return 0 end
    local uplift = math.max(0, cell.uplift or 0)
    local boundary = math.max(0, cell.plateBoundary or 0)
    return uplift * 0.00018 + uplift * boundary * 0.00022
end

function Erosion.relax(region, options)
    options = options or {}
    local iterations = options.iterations
    if iterations == nil then iterations = 80 end
    iterations = math.max(0, math.floor(iterations))
    local order = orderedCells(region)
    local k = options.K or 0.0006
    local m = options.m or 0.5
    local n = options.n or 1.0
    local dt = options.dt or 1.0
    local upliftMode = options.uplift
    if upliftMode == nil then upliftMode = "plateBased" end
    local seaLevel = region.seaLevel or -math.huge
    local minSlope = options.minSlope or 0.00002
    local maxDelta = 0

    for _, cell in ipairs(order) do
        cell.elevationBase = cell.elevationBase or cell.elevation or 0
        cell.elevation = cell.elevation or cell.elevationBase
    end

    for _ = 1, iterations do
        maxDelta = 0
        for index = #order, 1, -1 do
            local cell = order[index]
            local down = cell.downCell
            if down and not cell.water then
                local old = cell.elevation or cell.elevationBase or 0
                local downElevation = down.elevation or down.elevationBase or old
                local distance = math.max(1, cell.downDistance or region.stride or 1)
                local area = math.max(0.01, cell.flow or 0.01)
                local coeff = k * dt * (area ^ m) / (distance ^ n)
                local uplift = upliftFor(cell, upliftMode) * dt
                local nextElevation = (old + uplift + coeff * downElevation) / (1 + coeff)
                local gradeFloor = downElevation + minSlope * distance
                if old >= gradeFloor then nextElevation = math.max(nextElevation, gradeFloor) end
                nextElevation = math.min(nextElevation, old + uplift)
                nextElevation = math.max(nextElevation, seaLevel - 0.08)
                local delta = math.abs(nextElevation - old)
                if delta > maxDelta then maxDelta = delta end
                cell.elevation = nextElevation
            end
        end
    end

    local erosionSum, upliftSum, maxErosion = 0, 0, 0
    for _, cell in ipairs(order) do
        local base = cell.elevationBase or 0
        local elevation = cell.elevation or base
        local delta = elevation - base
        local erosion = math.max(0, -delta)
        local uplift = math.max(0, delta)
        cell.streamPowerDelta = delta
        cell.streamPowerErosion = erosion
        cell.streamPowerUplift = uplift
        if cell.downCell then
            local distance = math.max(1, cell.downDistance or region.stride or 1)
            cell.streamPowerSlope = math.max(0, (elevation - (cell.downCell.elevation or cell.downCell.elevationBase or elevation)) / distance)
        else
            cell.streamPowerSlope = 0
        end
        erosionSum = erosionSum + erosion
        upliftSum = upliftSum + uplift
        if erosion > maxErosion then maxErosion = erosion end
    end

    return {
        iterations = iterations,
        maxDelta = maxDelta,
        meanErosion = erosionSum / math.max(1, #order),
        meanUplift = upliftSum / math.max(1, #order),
        maxErosion = maxErosion,
    }
end

return Erosion
