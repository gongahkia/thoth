local Render = {}

local terrainScale = 18

local biomeColors = {
    ocean = { 0.05, 0.15, 0.32 },
    coast = { 0.08, 0.3, 0.52 },
    lake = { 0.1, 0.34, 0.56 },
    river = { 0.12, 0.46, 0.78 },
    wetland = { 0.18, 0.36, 0.24 },
    desert = { 0.67, 0.58, 0.34 },
    grassland = { 0.31, 0.5, 0.24 },
    savanna = { 0.52, 0.5, 0.24 },
    temperate_forest = { 0.13, 0.34, 0.18 },
    rainforest = { 0.04, 0.28, 0.14 },
    boreal_forest = { 0.14, 0.3, 0.29 },
    tundra = { 0.5, 0.54, 0.49 },
    alpine = { 0.46, 0.44, 0.42 },
    snow = { 0.84, 0.86, 0.82 },
    rock = { 0.33, 0.32, 0.31 },
}

local skyTop = { 0.43, 0.55, 0.66 }
local skyHorizon = { 0.68, 0.74, 0.75 }
local fogColor = { 0.57, 0.66, 0.68 }

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
    if cell.river then return biomeColors.river end
    if cell.lake then return biomeColors.lake end
    local color = biomeColors[cell.biome] or biomeColors.grassland
    if cell.water then color = cell.biome == "coast" and biomeColors.coast or biomeColors.ocean end
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
        renderRadius = 86,
        step = 2,
    }
end

local function cameraBasis(yaw)
    return {
        forwardX = math.sin(yaw),
        forwardY = -math.cos(yaw),
        rightX = math.cos(yaw),
        rightY = math.sin(yaw),
    }
end

local function worldPoint(app, lateral, depth)
    local basis = cameraBasis(app.camera.yaw or 0)
    return app.player.x + basis.rightX * lateral + basis.forwardX * depth,
        app.player.y + basis.rightY * lateral + basis.forwardY * depth
end

local function cameraLocal(app, x, y)
    local basis = cameraBasis(app.camera.yaw or 0)
    local dx, dy = x - app.player.x, y - app.player.y
    return dx * basis.rightX + dy * basis.rightY, dx * basis.forwardX + dy * basis.forwardY
end

local function cameraHeight(app)
    return app.world:heightAt(app.player.x, app.player.y) * terrainScale + (app.camera.eyeHeight or 3.2)
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

local function terrainZ(cell)
    if cell.lake and cell.lakeSurface then return cell.lakeSurface * terrainScale end
    if cell.water then return -0.25 * terrainScale end
    return cell.elevation * terrainScale
end

local function litColor(app, cell, depth, x, y)
    local color = baseColor(cell)
    local normal = app.world:normalAt(x, y)
    local light = normal.x * -0.35 + normal.y * 0.55 + normal.z * 0.74
    local brightness = 0.58 + clamp(light, 0, 1) * 0.34 + clamp(cell.elevation + 0.2, 0, 1) * 0.1
    if cell.water then brightness = 0.82 end
    local shaded = shade(color, brightness)
    local fog = clamp((depth - 18) / math.max(1, (app.camera.renderRadius or 86) - 18), 0, 1)
    return mixColor(shaded, fogColor, fog * 0.86)
end

local function pushVertex(vertices, x, y, color)
    vertices[#vertices + 1] = { x, y, color[1], color[2], color[3], 1 }
end

local function pushTri(vertices, a, b, c, color)
    pushVertex(vertices, a[1], a[2], color)
    pushVertex(vertices, b[1], b[2], color)
    pushVertex(vertices, c[1], c[2], color)
end

local function pushQuad(vertices, p00, p10, p11, p01, color)
    pushTri(vertices, p00, p10, p11, color)
    pushTri(vertices, p00, p11, p01, color)
end

function Render.buildTerrainMeshData(app, width, height)
    app.camera.eyeZ = cameraHeight(app)
    local vertices = {}
    local camera = app.camera
    local step = camera.step or 2
    local radius = camera.renderRadius or 86
    local lateralRange = radius * 0.82
    local visibleTiles = 0
    for depth = radius, step + 2, -step do
        local nextDepth = depth - step
        for lateral = -lateralRange, lateralRange - step, step do
            local wx0, wy0 = worldPoint(app, lateral, depth)
            local wx1, wy1 = worldPoint(app, lateral + step, depth)
            local wx2, wy2 = worldPoint(app, lateral + step, nextDepth)
            local wx3, wy3 = worldPoint(app, lateral, nextDepth)
            local centerX, centerY = worldPoint(app, lateral + step * 0.5, depth - step * 0.5)
            local cell = app.world:sample(math.floor(centerX), math.floor(centerY), "local")
            local z0 = terrainZ(app.world:sample(math.floor(wx0), math.floor(wy0), "local"))
            local z1 = terrainZ(app.world:sample(math.floor(wx1), math.floor(wy1), "local"))
            local z2 = terrainZ(app.world:sample(math.floor(wx2), math.floor(wy2), "local"))
            local z3 = terrainZ(app.world:sample(math.floor(wx3), math.floor(wy3), "local"))
            local p00x, p00y = project(app, width, height, lateral, depth, z0)
            local p10x, p10y = project(app, width, height, lateral + step, depth, z1)
            local p11x, p11y = project(app, width, height, lateral + step, nextDepth, z2)
            local p01x, p01y = project(app, width, height, lateral, nextDepth, z3)
            if p00x and p10x and p11x and p01x then
                local color = litColor(app, cell, depth, centerX, centerY)
                pushQuad(vertices, { p00x, p00y }, { p10x, p10y }, { p11x, p11y }, { p01x, p01y }, color)
                visibleTiles = visibleTiles + 1
            end
        end
    end
    return {
        vertices = vertices,
        visibleTiles = visibleTiles,
        triangles = #vertices / 3,
        cameraHeight = app.camera.eyeZ,
    }
end

local function chunkCoord(value, size)
    return math.floor(value / size)
end

function Render.billboardDrawList(app, width, height)
    app.camera.eyeZ = app.camera.eyeZ or cameraHeight(app)
    local size = app.world:metadata().chunkSize
    local cx, cy = chunkCoord(app.player.x, size), chunkCoord(app.player.y, size)
    local list = {}
    for y = cy - 1, cy + 1 do
        for x = cx - 1, cx + 1 do
            for _, spec in ipairs(app.world:billboards(x, y)) do
                local lateral, depth = cameraLocal(app, spec.x, spec.y)
                if depth > 2 and depth < (app.camera.renderRadius or 86) then
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
    return {
        visibleTiles = mesh.visibleTiles,
        triangles = mesh.triangles,
        billboards = #billboards,
        cameraHeight = mesh.cameraHeight,
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
        love.graphics.rectangle("fill", item.x - item.w * 0.5, item.topY, item.w, h)
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
    local cell = app.world:sample(math.floor(app.player.x), math.floor(app.player.y), "local")
    love.graphics.setColor(0.02, 0.025, 0.03, 0.78)
    love.graphics.rectangle("fill", 12, 12, 420, 142)
    love.graphics.setColor(0.88, 0.9, 0.82, 1)
    love.graphics.print("Thoth terrain proto / first-person heightfield", 24, 24)
    love.graphics.print("seed " .. tostring(app.world:metadata().seed) .. "  fps " .. tostring(love.timer.getFPS()), 24, 44)
    love.graphics.print("pos " .. math.floor(app.player.x) .. ", " .. math.floor(app.player.y) .. "  biome " .. tostring(cell.biome), 24, 66)
    love.graphics.print("elev " .. fmt(cell.elevation) .. " slope " .. fmt(cell.slope) .. " erosion " .. fmt(cell.erosion), 24, 88)
    love.graphics.print("rain " .. fmt(cell.rainfall) .. " flow " .. fmt(cell.flow) .. " river " .. tostring(cell.river), 24, 110)
    love.graphics.print("mesh " .. tostring(stats.visibleTiles) .. " tiles / " .. tostring(stats.triangles) .. " tris / " .. tostring(stats.billboards) .. " billboards", 24, 132)
    love.graphics.setColor(0.02, 0.025, 0.03, 0.7)
    love.graphics.rectangle("fill", width - 324, height - 52, 312, 34)
    love.graphics.setColor(0.88, 0.9, 0.82, 1)
    love.graphics.print("WASD walk  mouse/QE look  F mouse  R seed", width - 312, height - 42)
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
    local billboards = Render.billboardDrawList(app, width, height)
    drawBillboards(billboards)
    meshData.billboards = #billboards
    love.graphics.setColor(0.95, 0.92, 0.74, 1)
    love.graphics.circle("fill", width * 0.5, height * 0.52, 2)
    drawHud(app, width, height, meshData)
    return meshData
end

return Render
