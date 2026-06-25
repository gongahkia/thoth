local WorldGen = require("src.worldgen")

local Render = {}

local biomeColors = {
    ocean = { 0.05, 0.16, 0.34 },
    coast = { 0.08, 0.32, 0.55 },
    river = { 0.12, 0.48, 0.8 },
    wetland = { 0.17, 0.38, 0.28 },
    desert = { 0.72, 0.62, 0.38 },
    grassland = { 0.36, 0.56, 0.28 },
    savanna = { 0.55, 0.54, 0.28 },
    temperate_forest = { 0.17, 0.43, 0.24 },
    rainforest = { 0.06, 0.34, 0.19 },
    boreal_forest = { 0.16, 0.34, 0.33 },
    tundra = { 0.55, 0.58, 0.52 },
    alpine = { 0.52, 0.5, 0.47 },
    snow = { 0.86, 0.88, 0.84 },
    rock = { 0.38, 0.36, 0.34 },
}

local function clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

local function mix(a, b, t)
    return a + (b - a) * t
end

local function shade(color, amount)
    return {
        clamp(color[1] * amount, 0, 1),
        clamp(color[2] * amount, 0, 1),
        clamp(color[3] * amount, 0, 1),
    }
end

local function ramp(value, a, b)
    local t = clamp(value, 0, 1)
    return { mix(a[1], b[1], t), mix(a[2], b[2], t), mix(a[3], b[3], t) }
end

local function cellColor(cell, overlay)
    if overlay == "plates" then
        local n = (cell.plateId % 1000) / 1000
        local boundary = cell.plateBoundary or 0
        return ramp(boundary, { 0.1 + n * 0.3, 0.12, 0.18 + n * 0.5 }, { 0.95, 0.9, 0.2 })
    elseif overlay == "uplift" then
        return ramp(cell.uplift * 2.4, { 0.08, 0.11, 0.16 }, { 0.9, 0.44, 0.18 })
    elseif overlay == "rainfall" then
        return ramp(cell.rainfall, { 0.3, 0.2, 0.12 }, { 0.1, 0.42, 0.86 })
    elseif overlay == "flow" then
        return ramp(clamp(math.log((cell.flow or 0) + 1) / 5, 0, 1), { 0.08, 0.1, 0.13 }, { 0.05, 0.78, 0.95 })
    elseif overlay == "erosion" then
        return ramp(clamp((cell.erosion or 0) * 5, 0, 1), { 0.12, 0.13, 0.12 }, { 0.96, 0.7, 0.28 })
    end
    local base = biomeColors[cell.biome] or { 0.4, 0.4, 0.4 }
    local amount = 0.82 + clamp(cell.elevation + 0.2, 0, 1) * 0.34
    return shade(base, amount)
end

local function scaleForApp(app)
    local metadata = app.world:metadata()
    return metadata.scales[app.scaleIndex or 1] or metadata.scales[1]
end

local function drawTerrain(app, width, height)
    local scale = scaleForApp(app)
    local overlay = app.overlays[app.overlayIndex] or "biome"
    local cellPx = 8
    local cols = math.ceil(width / cellPx) + 2
    local rows = math.ceil(height / cellPx) + 2
    local startX = math.floor(app.camera.x / scale.factor - cols * 0.5)
    local startY = math.floor(app.camera.y / scale.factor - rows * 0.5)
    app.hoverCell = nil
    local mx, my = love.mouse.getPosition()
    for row = 0, rows do
        for col = 0, cols do
            local sx = (startX + col) * scale.factor
            local sy = (startY + row) * scale.factor
            local cell = app.world:sample(sx, sy, scale.id)
            local color = cellColor(cell, overlay)
            love.graphics.setColor(color[1], color[2], color[3], 1)
            local px, py = col * cellPx - cellPx, row * cellPx - cellPx
            love.graphics.rectangle("fill", px, py, cellPx, cellPx)
            if cell.river then
                love.graphics.setColor(0.15, 0.64, 0.96, 1)
                love.graphics.rectangle("fill", px + 2, py + 2, cellPx - 4, cellPx - 4)
            elseif not cell.water and math.floor((cell.elevation + 1) * 18) % 3 == 0 then
                love.graphics.setColor(0, 0, 0, 0.12)
                love.graphics.line(px, py + cellPx - 1, px + cellPx, py + cellPx - 1)
            end
            if mx >= px and mx < px + cellPx and my >= py and my < py + cellPx then
                app.hoverCell = cell
            end
        end
    end
end

local function fmt(value)
    return string.format("%.3f", value or 0)
end

local function drawHud(app, width, height)
    local scale = scaleForApp(app)
    local cell = app.hoverCell or app.world:sample(math.floor(app.player.x), math.floor(app.player.y), scale.id)
    love.graphics.setColor(0.03, 0.035, 0.04, 0.82)
    love.graphics.rectangle("fill", 12, 12, 380, 202)
    love.graphics.setColor(0.86, 0.88, 0.82, 1)
    love.graphics.print("Thoth terrain proto", 24, 24)
    love.graphics.print("seed " .. tostring(app.world:metadata().seed) .. " / scale " .. scale.id .. " / overlay " .. tostring(app.overlays[app.overlayIndex]), 24, 46)
    love.graphics.print("pos " .. math.floor(app.player.x) .. ", " .. math.floor(app.player.y), 24, 68)
    love.graphics.print("biome " .. tostring(cell.biome) .. " / crust " .. tostring(cell.plateCrust), 24, 96)
    love.graphics.print("elev " .. fmt(cell.elevation) .. " slope " .. fmt(cell.slope) .. " erosion " .. fmt(cell.erosion), 24, 118)
    love.graphics.print("rain " .. fmt(cell.rainfall) .. " moisture " .. fmt(cell.moisture) .. " temp " .. fmt(cell.temperature), 24, 140)
    love.graphics.print("plate " .. tostring(cell.plateId) .. " boundary " .. fmt(cell.plateBoundary) .. " uplift " .. fmt(cell.uplift), 24, 162)
    love.graphics.print("flow " .. fmt(cell.flow) .. " river " .. tostring(cell.river), 24, 184)
    love.graphics.setColor(0.03, 0.035, 0.04, 0.72)
    love.graphics.rectangle("fill", width - 288, height - 64, 276, 42)
    love.graphics.setColor(0.86, 0.88, 0.82, 1)
    love.graphics.print("WASD walk  [/] scale  Tab overlay  R seed", width - 276, height - 52)
end

function Render.draw(app)
    local width, height = love.graphics.getDimensions()
    love.graphics.clear(0.02, 0.025, 0.03, 1)
    drawTerrain(app, width, height)
    love.graphics.setColor(0.02, 0.02, 0.018, 1)
    love.graphics.circle("fill", width * 0.5, height * 0.5, 6)
    love.graphics.setColor(0.95, 0.92, 0.72, 1)
    love.graphics.circle("fill", width * 0.5, height * 0.5, 4)
    drawHud(app, width, height)
end

return Render
