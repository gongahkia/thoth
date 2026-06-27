local Erosion = {}

local function option(value, fallback)
    if value == nil then return fallback end
    return value
end

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

local function sedimentCapacity(cell, options)
    local flow = math.max(1, cell.flow or 1)
    local slope = math.max(0.0001, cell.streamPowerSlope or 0)
    return (options.sedimentCapacity or 0.18) * flow * slope
end

local function cellKey(gx, gy)
    return tostring(gx) .. ":" .. tostring(gy)
end

local function gaussianKernel(radius)
    radius = math.max(0, math.floor(radius or 0))
    if radius == 0 then return { [0] = 1 }, 0 end
    local sigma = math.max(0.5, radius * 0.5)
    local kernel, sum = {}, 0
    for offset = -radius, radius do
        local weight = math.exp(-(offset * offset) / (2 * sigma * sigma))
        kernel[offset] = weight
        sum = sum + weight
    end
    for offset = -radius, radius do kernel[offset] = kernel[offset] / sum end
    return kernel, radius
end

local function coordinateIndex(order, region)
    local byY = {}
    local minX, minY, maxX, maxY = region.minX, region.minY, region.maxX, region.maxY
    for _, cell in ipairs(order) do
        local gx, gy = cell.gx, cell.gy
        if gx and gy then
            if not minX or gx < minX then minX = gx end
            if not maxX or gx > maxX then maxX = gx end
            if not minY or gy < minY then minY = gy end
            if not maxY or gy > maxY then maxY = gy end
            local row = byY[gy]
            if not row then
                row = {}
                byY[gy] = row
            end
            row[gx] = cell
        end
    end
    return { byY = byY, minX = minX, minY = minY, maxX = maxX, maxY = maxY }
end

local function applyRebound(index, losses, targetMass, kernel, radius)
    if targetMass <= 0 or not index.minX then return 0, 0 end
    local lossRows = {}
    for cell, loss in pairs(losses) do
        if loss > 0 and cell.gx and cell.gy then
            local row = lossRows[cell.gy]
            if not row then
                row = {}
                lossRows[cell.gy] = row
            end
            row[cell.gx] = loss
        end
    end

    local horizontal = {}
    for gy = index.minY, index.maxY do
        local source = lossRows[gy]
        if source then
            local row, any = {}, false
            for gx = index.minX, index.maxX do
                local value = 0
                for ox = -radius, radius do value = value + (source[gx + ox] or 0) * kernel[ox] end
                if value > 0 then
                    row[gx] = value
                    any = true
                end
            end
            if any then horizontal[gy] = row end
        end
    end

    local rebound, smoothed = {}, 0
    for gy = index.minY, index.maxY do
        local cells = index.byY[gy]
        if cells then
            for gx = index.minX, index.maxX do
                local cell = cells[gx]
                if cell then
                    local value = 0
                    for oy = -radius, radius do
                        local row = horizontal[gy + oy]
                        if row then value = value + (row[gx] or 0) * kernel[oy] end
                    end
                    if value > 0 then
                        rebound[cell] = value
                        smoothed = smoothed + value
                    end
                end
            end
        end
    end
    if smoothed <= 0 then return 0, 0 end

    local scale = targetMass / smoothed
    local added, maxRebound = 0, 0
    for cell, value in pairs(rebound) do
        local delta = value * scale
        cell.elevation = (cell.elevation or cell.elevationBase or 0) + delta
        cell.isostaticRebound = (cell.isostaticRebound or 0) + delta
        added = added + delta
        if delta > maxRebound then maxRebound = delta end
    end
    return added, maxRebound
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
    local isostasy = option(options.isostasy, true)
    local isostasyRatio = isostasy and option(options.isostasyRatio, 0.8) or 0
    local kernel, isostasyRadius = gaussianKernel(option(options.isostasyRadius, 4))
    local index = isostasyRatio > 0 and coordinateIndex(order, region) or nil
    local maxDelta = 0
    local isostaticErosion, isostaticRebound = 0, 0

    for _, cell in ipairs(order) do
        cell.elevationBase = cell.elevationBase or cell.elevation or 0
        cell.elevation = cell.elevation or cell.elevationBase
        cell.isostaticErosion = 0
        cell.isostaticRebound = 0
    end

    for _ = 1, iterations do
        maxDelta = 0
        local losses, eroded = {}, 0
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
                local incision = math.max(0, old + uplift - nextElevation)
                if isostasyRatio > 0 and incision > 0 then
                    losses[cell] = incision
                    cell.isostaticErosion = (cell.isostaticErosion or 0) + incision
                    eroded = eroded + incision
                end
                local delta = math.abs(nextElevation - old)
                if delta > maxDelta then maxDelta = delta end
                cell.elevation = nextElevation
            end
        end
        if isostasyRatio > 0 and eroded > 0 then
            local rebound, maxRebound = applyRebound(index, losses, eroded * isostasyRatio, kernel, isostasyRadius)
            isostaticErosion = isostaticErosion + eroded
            isostaticRebound = isostaticRebound + rebound
            if maxRebound > maxDelta then maxDelta = maxRebound end
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

    local sedimentSum, maxSediment = 0, 0
    local sedimentYield = options.sedimentYield or 1.0
    local depositionG = options.G or 1.2
    local transfer = options.sedimentTransfer or 0.985
    local maxDeposit = options.maxDeposit or 0.06
    for _, cell in ipairs(order) do
        cell.sediment = 0
        cell.sedimentFlux = 0
        cell.sedimentCapacity = 0
    end
    for index = #order, 1, -1 do
        local cell = order[index]
        if not cell.water then
            local flow = math.max(1, cell.flow or 1)
            local source = (cell.streamPowerErosion or 0) * flow * sedimentYield
            local flux = (cell.sedimentFlux or 0) + source
            local capacity = sedimentCapacity(cell, options)
            local deposit = 0
            if flux > capacity then
                local excess = flux - capacity
                deposit = math.min(excess, depositionG * flux / flow)
                deposit = math.min(deposit, maxDeposit)
                flux = flux - deposit
            end
            cell.sediment = deposit
            cell.sedimentFlux = flux
            cell.sedimentCapacity = capacity
            sedimentSum = sedimentSum + deposit
            if deposit > maxSediment then maxSediment = deposit end
            if cell.downCell then
                cell.downCell.sedimentFlux = (cell.downCell.sedimentFlux or 0) + flux * transfer
            end
        end
    end

    return {
        iterations = iterations,
        maxDelta = maxDelta,
        meanErosion = erosionSum / math.max(1, #order),
        meanUplift = upliftSum / math.max(1, #order),
        maxErosion = maxErosion,
        isostaticErosion = isostaticErosion,
        isostaticRebound = isostaticRebound,
        meanSediment = sedimentSum / math.max(1, #order),
        maxSediment = maxSediment,
    }
end

function Erosion.glaciate(region, options)
    options = options or {}
    local order = orderedCells(region)
    local freeze = options.freezeTemperature or 0.38
    local snowline = options.snowline or 0.52
    local minFlow = options.minFlow or math.max(1, (region.threshold or 1) * 0.04)
    local maxCut = options.maxCut or 0.075
    local cells = region.cells or {}
    local deltas, primary = {}, {}

    for _, cell in ipairs(order) do
        cell.glaciated = false
        cell.glacialDelta = 0
        cell.glacialErosion = 0
        if not cell.water and (cell.temperature or 1) < freeze and (cell.elevation or cell.elevationBase or 0) > snowline and (cell.flow or 0) > minFlow then
            local cold = (freeze - (cell.temperature or freeze)) / freeze
            local height = ((cell.elevation or cell.elevationBase or 0) - snowline) / math.max(0.1, 1 - snowline)
            local flowFactor = math.min(1, math.sqrt((cell.flow or 0) / math.max(1, minFlow * 12)))
            local cut = math.min(maxCut, (0.018 + cold * 0.035 + height * 0.03) * flowFactor)
            deltas[cell] = math.min(deltas[cell] or 0, -cut)
            primary[cell] = true
            local radius = cut > maxCut * 0.55 and 2 or 1
            for oy = -radius, radius do
                for ox = -radius, radius do
                    local distance = math.sqrt(ox * ox + oy * oy)
                    if distance > 0 and distance <= radius then
                        local neighbor = cells[cellKey((cell.gx or 0) + ox, (cell.gy or 0) + oy)]
                        if neighbor and not neighbor.water then
                            local sideCut = cut * 0.48 * (1 - distance / (radius + 0.75))
                            deltas[neighbor] = math.min(deltas[neighbor] or 0, -sideCut)
                        end
                    end
                end
            end
        end
    end

    local count, erosionSum = 0, 0
    for cell, delta in pairs(deltas) do
        local old = cell.elevation or cell.elevationBase or 0
        cell.elevation = old + delta
        cell.glacialDelta = delta
        cell.glacialErosion = -delta
        cell.glaciated = primary[cell] == true
        if cell.glaciated then count = count + 1 end
        erosionSum = erosionSum - delta
    end
    region.glaciers = {
        glaciatedCells = count,
        meanGlacialErosion = erosionSum / math.max(1, #order),
    }
    return region.glaciers
end

return Erosion
