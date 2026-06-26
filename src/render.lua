local Render = {}
local ViewScale = require("src.viewscale")

local terrainScale = 18

local biomeColors = {
    ocean = { 0.035, 0.12, 0.28 },
    coast = { 0.065, 0.28, 0.46 },
    lake = { 0.08, 0.32, 0.5 },
    river = { 0.1, 0.43, 0.72 },
    wetland = { 0.16, 0.34, 0.2 },
    desert = { 0.72, 0.63, 0.36 },
    grassland = { 0.34, 0.54, 0.22 },
    savanna = { 0.58, 0.52, 0.22 },
    temperate_forest = { 0.12, 0.36, 0.16 },
    rainforest = { 0.025, 0.29, 0.12 },
    boreal_forest = { 0.11, 0.27, 0.28 },
    tundra = { 0.48, 0.52, 0.46 },
    alpine = { 0.49, 0.47, 0.41 },
    snow = { 0.86, 0.88, 0.84 },
    rock = { 0.35, 0.33, 0.3 },
}

local landformColors = {
    talus = { 0.46, 0.44, 0.4 },
    alluvial = { 0.58, 0.49, 0.31 },
    floodplain = { 0.2, 0.42, 0.22 },
    delta = { 0.42, 0.48, 0.28 },
    rift = { 0.38, 0.28, 0.22 },
    islandArc = { 0.45, 0.39, 0.34 },
    shield = { 0.24, 0.34, 0.27 },
    craton = { 0.3, 0.32, 0.25 },
}

local skyTop = { 0.43, 0.55, 0.66 }
local skyHorizon = { 0.68, 0.74, 0.75 }
local fogColor = { 0.6, 0.68, 0.69 }
local silhouetteColor = { 0.08, 0.09, 0.08 }

local function clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

local function mix(a, b, t)
    return a + (b - a) * t
end

local function mixColor(a, b, t)
    return { mix(a[1], b[1], t), mix(a[2], b[2], t), mix(a[3], b[3], t) }
end

local function shade(color, amount)
    return {
        clamp(color[1] * amount, 0, 1),
        clamp(color[2] * amount, 0, 1),
        clamp(color[3] * amount, 0, 1),
    }
end

local function baseColor(cell)
    if cell.river then
        local color = biomeColors.river
        if cell.delta then color = mixColor(color, landformColors.delta, 0.45) end
        if cell.floodplain then color = mixColor(color, landformColors.floodplain, 0.22) end
        return color
    end
    if cell.lake then return biomeColors.lake end
    local color = biomeColors[cell.biome] or biomeColors.grassland
    if cell.water then color = cell.biome == "coast" and biomeColors.coast or biomeColors.ocean end
    if (cell.craton or 0) > 0.12 then color = mixColor(color, landformColors.craton, 0.34) end
    if (cell.shield or 0) > 0.2 then color = mixColor(color, landformColors.shield, 0.26) end
    if (cell.riftValley or 0) > 0.08 then color = mixColor(color, landformColors.rift, 0.4) end
    if (cell.volcanicIslandArc or 0) > 0.04 then color = mixColor(color, landformColors.islandArc, 0.38) end
    if cell.delta then color = mixColor(color, landformColors.delta, 0.55) end
    if cell.floodplain then color = mixColor(color, landformColors.floodplain, 0.5) end
    if cell.alluvialFan then color = mixColor(color, landformColors.alluvial, 0.45) end
    if cell.talus then color = mixColor(color, landformColors.talus, 0.38) end
    if cell.riverBank then color = mixColor(color, biomeColors.river, 0.28) end
    return color
end

function Render.defaultCamera()
    return {
        x = 0,
        y = 0,
        yaw = 0,
        pitch = 0.02,
        eyeHeight = 3.2,
        fov = 620,
        renderRadius = 50,
        step = 2.25,
    }
end

function Render.biomePalette()
    local out = {}
    for id, color in pairs(biomeColors) do out[id] = { color[1], color[2], color[3] } end
    return out
end

local function cameraBasis(yaw)
    return {
        forwardX = math.sin(yaw),
        forwardY = -math.cos(yaw),
        rightX = math.cos(yaw),
        rightY = math.sin(yaw),
    }
end

local function viewParams(app)
    return ViewScale.params(app.viewScale, app.world)
end

local function terrainZ(cell)
    if cell.lake and cell.lakeSurface then return cell.lakeSurface * terrainScale end
    if cell.water then return -0.25 * terrainScale end
    return cell.elevation * terrainScale
end

local function cameraLocal(app, x, y, params)
    params = params or viewParams(app)
    local basis = cameraBasis(app.camera.yaw or 0)
    local factor = params.factor or 1
    local dx, dy = (x - app.player.x) / factor, (y - app.player.y) / factor
    return dx * basis.rightX + dy * basis.rightY, dx * basis.forwardX + dy * basis.forwardY
end

local function viewCell(app, x, y, params)
    params = params or viewParams(app)
    local target = app.world:sample(math.floor(x), math.floor(y), params.target)
    if not params.transitioning or params.from == params.target then return target, terrainZ(target) end
    local from = app.world:sample(math.floor(x), math.floor(y), params.from)
    return target, mix(terrainZ(from), terrainZ(target), params.ease)
end

local function cameraHeight(app)
    local params = viewParams(app)
    local _, z = viewCell(app, app.player.x, app.player.y, params)
    return z + (app.camera.eyeHeight or 3.2) * (1 + math.log(params.factor or 1) * 0.34)
end

local function project(app, width, height, lateral, depth, z)
    local near = 1.2
    if depth <= near then return nil end
    local camera = app.camera
    local fov = camera.fov or 620
    local horizon = height * 0.46 + (camera.pitch or 0) * fov
    local sx = width * 0.5 + lateral / depth * fov
    local sy = horizon - (z - camera.eyeZ) / depth * fov
    return sx, sy
end

local function projectWorld(app, width, height, x, y, z)
    local lateral, depth = cameraLocal(app, x, y)
    local sx, sy = project(app, width, height, lateral, depth, z)
    return sx, sy, depth
end

local function litColor(cell, depth, slopeLight, radius)
    local color = baseColor(cell)
    local light = 0.72 + clamp(slopeLight, -0.22, 0.28) - clamp(cell.slope or 0, 0, 1) * 0.08
    local brightness = 0.58 + clamp(light, 0, 1) * 0.34 + clamp(cell.elevation + 0.2, 0, 1) * 0.1
    if cell.water then brightness = 0.82 end
    local shaded = shade(color, brightness)
    local fog = clamp((depth - 24) / math.max(1, radius - 24), 0, 1)
    return mixColor(shaded, fogColor, fog * 0.76)
end

local function foggedColor(color, depth, radius, amount)
    local fog = clamp((depth - 24) / math.max(1, radius - 24), 0, 1)
    return mixColor(color, fogColor, fog * (amount or 0.7))
end

local function pushVertex(vertices, x, y, color)
    vertices[#vertices + 1] = { x, y, color[1], color[2], color[3], 1 }
end

local function pushTriCoords(vertices, ax, ay, bx, by, cx, cy, color)
    pushVertex(vertices, ax, ay, color)
    pushVertex(vertices, bx, by, color)
    pushVertex(vertices, cx, cy, color)
end

local function pushQuadCoords(vertices, x00, y00, x10, y10, x11, y11, x01, y01, color)
    pushTriCoords(vertices, x00, y00, x10, y10, x11, y11, color)
    pushTriCoords(vertices, x00, y00, x11, y11, x01, y01, color)
end

local function pushLineQuad(vertices, ax, ay, bx, by, width, color)
    local dx, dy = bx - ax, by - ay
    local length = math.sqrt(dx * dx + dy * dy)
    if length <= 0.001 then return false end
    local nx, ny = -dy / length * width * 0.5, dx / length * width * 0.5
    pushQuadCoords(vertices, ax - nx, ay - ny, bx - nx, by - ny, bx + nx, by + ny, ax + nx, ay + ny, color)
    return true
end

function Render.buildTerrainMeshData(app, width, height)
    local params = viewParams(app)
    app.camera.eyeZ = cameraHeight(app)
    local vertices = {}
    local riverVertices = {}
    local silhouetteVertices = {}
    local camera = app.camera
    local step = camera.step or 2
    local radius = camera.renderRadius or 86
    local lateralRange = radius * 0.82
    local basis = cameraBasis(camera.yaw or 0)
    local laterals = {}
    local depths = {}
    local lateral = -lateralRange
    while lateral <= lateralRange + 0.0001 do
        laterals[#laterals + 1] = lateral
        lateral = lateral + step
    end
    local depth = radius
    while depth >= step + 2 do
        depths[#depths + 1] = depth
        depth = depth - step
    end
    depths[#depths + 1] = depth
    local grid = {}
    for row = 1, #depths do
        grid[row] = {}
        for col = 1, #laterals do
            local lat = laterals[col]
            local dep = depths[row]
            local wx = app.player.x + (basis.rightX * lat + basis.forwardX * dep) * params.factor
            local wy = app.player.y + (basis.rightY * lat + basis.forwardY * dep) * params.factor
            local _, z = viewCell(app, wx, wy, params)
            grid[row][col] = z
        end
    end
    local visibleTiles = 0
    local riverStrips = 0
    local silhouetteStrips = 0
    for row = 1, #depths - 1 do
        local dep = depths[row]
        local nextDepth = depths[row + 1]
        for col = 1, #laterals - 1 do
            local lat = laterals[col]
            local nextLat = laterals[col + 1]
            local centerLat = (lat + nextLat) * 0.5
            local centerDepth = (dep + nextDepth) * 0.5
            local centerX = app.player.x + (basis.rightX * centerLat + basis.forwardX * centerDepth) * params.factor
            local centerY = app.player.y + (basis.rightY * centerLat + basis.forwardY * centerDepth) * params.factor
            local cell = viewCell(app, centerX, centerY, params)
            local z0 = grid[row][col]
            local z1 = grid[row][col + 1]
            local z2 = grid[row + 1][col + 1]
            local z3 = grid[row + 1][col]
            local p00x, p00y = project(app, width, height, lat, dep, z0)
            local p10x, p10y = project(app, width, height, nextLat, dep, z1)
            local p11x, p11y = project(app, width, height, nextLat, nextDepth, z2)
            local p01x, p01y = project(app, width, height, lat, nextDepth, z3)
            if p00x and p10x and p11x and p01x then
                local slopeLight = ((z0 + z1) - (z2 + z3)) / (terrainScale * 2)
                local color = litColor(cell, centerDepth, slopeLight, radius)
                pushQuadCoords(vertices, p00x, p00y, p10x, p10y, p11x, p11y, p01x, p01y, color)
                visibleTiles = visibleTiles + 1
                local edgeSlope = math.abs(slopeLight)
                if (cell.slope or 0) > 0.28 or edgeSlope > 0.045 then
                    local lineColor = foggedColor(silhouetteColor, centerDepth, radius, 0.78)
                    local width = clamp(0.65 + (cell.slope or 0) * 3.2, 0.8, 2.4)
                    if pushLineQuad(silhouetteVertices, p01x, p01y, p11x, p11y, width, lineColor) then
                        silhouetteStrips = silhouetteStrips + 1
                    end
                end
                if cell.river and cell.downX and cell.downY then
                    local scaleFactor = cell.scaleFactor or 1
                    local axWorld = cell.x * scaleFactor
                    local ayWorld = cell.y * scaleFactor
                    local bxWorld = cell.downX * scaleFactor
                    local byWorld = cell.downY * scaleFactor
                    local _, downZ = viewCell(app, bxWorld, byWorld, params)
                    local ax, ay, ad = projectWorld(app, width, height, axWorld, ayWorld, terrainZ(cell) + 0.08)
                    local bx, by, bd = projectWorld(app, width, height, bxWorld, byWorld, downZ + 0.08)
                    if ax and bx then
                        local stripDepth = math.max(1, (ad + bd) * 0.5)
                        local stripWidth = clamp((1.15 + math.log((cell.flow or 0) + 1) * 0.12) / stripDepth * (camera.fov or 620), 1.2, 5.2)
                        local riverColor = foggedColor(biomeColors.river, stripDepth, radius, 0.55)
                        if pushLineQuad(riverVertices, ax, ay, bx, by, stripWidth, riverColor) then
                            riverStrips = riverStrips + 1
                        end
                    end
                end
            end
        end
    end
    return {
        vertices = vertices,
        riverVertices = riverVertices,
        silhouetteVertices = silhouetteVertices,
        visibleTiles = visibleTiles,
        triangles = #vertices / 3,
        riverStrips = riverStrips,
        silhouetteStrips = silhouetteStrips,
        cameraHeight = app.camera.eyeZ,
        viewScale = params.target,
        viewFactor = params.factor,
        viewProgress = params.progress,
    }
end

local function chunkCoord(value, size)
    return math.floor(value / size)
end

function Render.billboardDrawList(app, width, height)
    local params = viewParams(app)
    if params.factor > 2.1 then return {} end
    app.camera.eyeZ = app.camera.eyeZ or cameraHeight(app)
    local size = app.world:metadata().chunkSize
    local radius = app.camera.renderRadius or 62
    local minChunkX = chunkCoord(app.player.x - radius, size)
    local maxChunkX = chunkCoord(app.player.x + radius, size)
    local minChunkY = chunkCoord(app.player.y - radius, size)
    local maxChunkY = chunkCoord(app.player.y + radius, size)
    local list = {}
    for y = minChunkY, maxChunkY do
        for x = minChunkX, maxChunkX do
            for _, spec in ipairs(app.world:billboards(x, y)) do
                local lateral, depth = cameraLocal(app, spec.x, spec.y, params)
                if depth > 2 and depth < radius then
                    local baseZ = spec.z * terrainScale
                    local bx, by = project(app, width, height, lateral, depth, baseZ)
                    local tx, ty = project(app, width, height, lateral, depth, baseZ + spec.height * terrainScale * 0.45)
                    if bx and tx then
                        local screenW = math.max(2, spec.width / depth * (app.camera.fov or 620))
                        list[#list + 1] = {
                            x = bx,
                            baseY = by,
                            topY = ty,
                            w = screenW,
                            depth = depth,
                            color = spec.color,
                            kind = spec.kind,
                        }
                    end
                end
            end
        end
    end
    table.sort(list, function(a, b) return a.depth > b.depth end)
    return list
end

function Render.visibleStats(app, width, height)
    local mesh = Render.buildTerrainMeshData(app, width or 1280, height or 720)
    local billboards = Render.billboardDrawList(app, width or 1280, height or 720)
    local landmarks = 0
    for _, item in ipairs(billboards) do
        if item.kind == "peak" or item.kind == "ridge" or item.kind == "outcrop" then landmarks = landmarks + 1 end
    end
    return {
        visibleTiles = mesh.visibleTiles,
        triangles = mesh.triangles,
        riverStrips = mesh.riverStrips,
        silhouetteStrips = mesh.silhouetteStrips,
        billboards = #billboards,
        landmarks = landmarks,
        cameraHeight = mesh.cameraHeight,
        viewScale = mesh.viewScale,
        viewFactor = mesh.viewFactor,
        viewProgress = mesh.viewProgress,
        labels = #(ViewScale.visibleLabels(app.viewScale, 8)),
    }
end

local function drawSky(width, height)
    love.graphics.setColor(skyTop[1], skyTop[2], skyTop[3], 1)
    love.graphics.rectangle("fill", 0, 0, width, height)
    love.graphics.setColor(skyHorizon[1], skyHorizon[2], skyHorizon[3], 1)
    love.graphics.rectangle("fill", 0, height * 0.38, width, height * 0.28)
    love.graphics.setColor(fogColor[1], fogColor[2], fogColor[3], 0.35)
    love.graphics.rectangle("fill", 0, height * 0.54, width, height * 0.46)
end

local meshFormat = {
    { "VertexPosition", "float", 2 },
    { "VertexColor", "float", 4 },
}

local function drawBillboards(list)
    for _, item in ipairs(list) do
        local color = item.color
        local fog = clamp((item.depth - 18) / 68, 0, 1)
        local c = mixColor(color, fogColor, fog * 0.75)
        love.graphics.setColor(c[1], c[2], c[3], 1)
        local h = item.baseY - item.topY
        if item.kind == "peak" then
            love.graphics.polygon("fill", item.x, item.topY, item.x - item.w * 0.58, item.baseY, item.x + item.w * 0.58, item.baseY)
            love.graphics.setColor(c[1] * 1.12, c[2] * 1.12, c[3] * 1.12, 1)
            love.graphics.polygon("fill", item.x, item.topY, item.x + item.w * 0.22, item.baseY - h * 0.38, item.x + item.w * 0.58, item.baseY)
        elseif item.kind == "ridge" then
            love.graphics.polygon("fill", item.x - item.w * 0.55, item.baseY, item.x - item.w * 0.12, item.topY, item.x + item.w * 0.55, item.baseY - h * 0.18, item.x + item.w * 0.22, item.baseY)
        elseif item.kind == "outcrop" then
            love.graphics.polygon("fill", item.x - item.w * 0.48, item.baseY, item.x - item.w * 0.22, item.topY, item.x + item.w * 0.44, item.baseY - h * 0.22, item.x + item.w * 0.52, item.baseY)
        else
            love.graphics.rectangle("fill", item.x - item.w * 0.5, item.topY, item.w, h)
        end
        if item.kind == "tree" then
            love.graphics.setColor(c[1] * 0.6, c[2] * 0.6, c[3] * 0.6, 1)
            love.graphics.rectangle("fill", item.x - item.w * 0.12, item.baseY - h * 0.38, item.w * 0.24, h * 0.38)
        end
    end
end

local function fmt(value)
    return string.format("%.3f", value or 0)
end

local function drawHud(app, width, height, stats)
    local params = viewParams(app)
    local cell = app.world:sample(math.floor(app.player.x), math.floor(app.player.y), params.target)
    local labels = ViewScale.visibleLabels(app.viewScale, 4)
    love.graphics.setColor(0.02, 0.025, 0.03, 0.78)
    love.graphics.rectangle("fill", 12, 12, 456, 214)
    love.graphics.setColor(0.88, 0.9, 0.82, 1)
    love.graphics.print("Thoth terrain proto / first-person heightfield", 24, 24)
    love.graphics.print("seed " .. tostring(app.world:metadata().seed) .. "  fps " .. tostring(love.timer.getFPS()) .. "  scope " .. tostring(params.target) .. " x" .. string.format("%.1f", params.factor), 24, 44)
    love.graphics.print("pos " .. math.floor(app.player.x) .. ", " .. math.floor(app.player.y) .. "  biome " .. tostring(cell.biome), 24, 66)
    love.graphics.print("elev " .. fmt(cell.elevation) .. " slope " .. fmt(cell.slope) .. " erosion " .. fmt(cell.erosion), 24, 88)
    love.graphics.print("rain " .. fmt(cell.rainfall) .. " flow " .. fmt(cell.flow) .. " river " .. tostring(cell.river), 24, 110)
    local survey = app.survey or {}
    love.graphics.print("mesh " .. tostring(stats.visibleTiles) .. " tiles / " .. tostring(stats.triangles) .. " tris / rivers " .. tostring(stats.riverStrips or 0) .. " / survey " .. tostring(survey.cellCount or 0) .. ":" .. tostring(survey.discoveryCount or 0), 24, 132)
    local anchor = app.viewScale and app.viewScale.anchor
    love.graphics.print("anchor " .. tostring(anchor and anchor.name or "terrain labels") .. " / labels " .. tostring(#labels), 24, 154)
    for index, label in ipairs(labels) do
        love.graphics.print(tostring(label.scaleLabel) .. " " .. tostring(label.name), 24, 154 + index * 16)
    end
    love.graphics.setColor(0.02, 0.025, 0.03, 0.7)
    love.graphics.rectangle("fill", width - 428, height - 52, 416, 34)
    love.graphics.setColor(0.88, 0.9, 0.82, 1)
    love.graphics.print("WASD walk  mouse/QE look  F mouse  Tab scope  M mark  R seed", width - 416, height - 42)
end

function Render.draw(app)
    local width, height = love.graphics.getDimensions()
    love.graphics.clear(skyTop[1], skyTop[2], skyTop[3], 1)
    drawSky(width, height)
    local meshData = Render.buildTerrainMeshData(app, width, height)
    if #meshData.vertices > 0 then
        local mesh = love.graphics.newMesh(meshFormat, meshData.vertices, "triangles", "stream")
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(mesh)
    end
    if #meshData.silhouetteVertices > 0 then
        local mesh = love.graphics.newMesh(meshFormat, meshData.silhouetteVertices, "triangles", "stream")
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(mesh)
    end
    if #meshData.riverVertices > 0 then
        local mesh = love.graphics.newMesh(meshFormat, meshData.riverVertices, "triangles", "stream")
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(mesh)
    end
    local billboards = Render.billboardDrawList(app, width, height)
    drawBillboards(billboards)
    meshData.billboards = #billboards
    meshData.landmarks = 0
    for _, item in ipairs(billboards) do
        if item.kind == "peak" or item.kind == "ridge" or item.kind == "outcrop" then meshData.landmarks = meshData.landmarks + 1 end
    end
    love.graphics.setColor(0.95, 0.92, 0.74, 1)
    love.graphics.circle("fill", width * 0.5, height * 0.52, 2)
    drawHud(app, width, height, meshData)
    return meshData
end

return Render
