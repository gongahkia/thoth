local Render = {}
local ViewScale = require("src.viewscale")
local ffi = require("ffi")

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
    coastBeach = { 0.76, 0.68, 0.42 },
    coastCliff = { 0.34, 0.33, 0.32 },
    duneLight = { 0.82, 0.73, 0.43 },
    duneShade = { 0.5, 0.42, 0.22 },
    rift = { 0.38, 0.28, 0.22 },
    islandArc = { 0.45, 0.39, 0.34 },
    shield = { 0.24, 0.34, 0.27 },
    craton = { 0.3, 0.32, 0.25 },
}

local skyTop = { 0.43, 0.55, 0.66 }
local skyHorizon = { 0.68, 0.74, 0.75 }
local fogColor = { 0.6, 0.68, 0.69 }
local silhouetteColor = { 0.08, 0.09, 0.08 }
local tau = math.pi * 2
local skyShaderSource = [[
extern vec3 skyTop;
extern vec3 skyHorizon;
extern vec3 fogColor;
extern vec2 skySize;
extern number timeOfDay;

vec4 effect(vec4 color, Image texture, vec2 textureCoords, vec2 screenCoords)
{
    number y = clamp(screenCoords.y / max(1.0, skySize.y), 0.0, 1.0);
    number dome = smoothstep(0.0, 0.58, y);
    vec3 sky = mix(skyTop, skyHorizon, dome);
    number haze = smoothstep(0.38, 0.76, y);
    sky = mix(sky, fogColor, haze * 0.55);
    number daylight = clamp(sin(timeOfDay * 6.2831853), 0.0, 1.0);
    number band = smoothstep(0.2, 0.36, y) * (1.0 - smoothstep(0.48, 0.64, y));
    number wave = sin(screenCoords.x * 0.026 + timeOfDay * 6.2831853) * 0.5 + 0.5;
    number cloud = smoothstep(0.72, 0.96, wave) * band * daylight * 0.22;
    sky = mix(sky, vec3(0.88, 0.9, 0.84), cloud);
    return vec4(sky, 1.0);
}
]]

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

function Render.skyColors(timeOfDay)
    local t = (tonumber(timeOfDay) or 0.25) % 1
    local daylight = clamp(math.sin(t * tau), 0, 1)
    local dusk = 1 - daylight
    local nightTop = { 0.035, 0.045, 0.12 }
    local nightHorizon = { 0.16, 0.12, 0.2 }
    local nightFog = { 0.18, 0.2, 0.26 }
    return {
        top = mixColor(nightTop, skyTop, daylight),
        horizon = mixColor(nightHorizon, skyHorizon, daylight),
        fog = mixColor(nightFog, fogColor, daylight * 0.85 + dusk * 0.18),
        daylight = daylight,
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
    if cell.coastBeach then color = mixColor(color, landformColors.coastBeach, 0.68) end
    if cell.coastCliff then color = mixColor(color, landformColors.coastCliff, 0.6) end
    if (cell.duneAmplitude or 0) > 0 then color = mixColor(color, (cell.duneDelta or 0) >= 0 and landformColors.duneLight or landformColors.duneShade, clamp((cell.duneAmplitude or 0) * 12, 0.18, 0.42)) end
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

local function frustumState(camera, width, radius, lateralRange, step)
    return {
        xPerDepth = width * 0.5 / (camera.fov or 620),
        radius = radius,
        lateralRange = lateralRange,
        sampleMargin = step * 1.5,
        tileMargin = step * 0.5,
    }
end

local function inFrustum(state, lateral, depth, margin)
    margin = margin or 0
    if depth <= 1.2 or depth > state.radius + margin then return false end
    if math.abs(lateral) > depth * state.xPerDepth + margin then return false end
    local radial = state.radius + margin
    return lateral * lateral + depth * depth <= radial * radial
end

local function terrainLight(cell, slopeLight)
    local light = 0.72 + clamp(slopeLight, -0.22, 0.28) - clamp(cell.slope or 0, 0, 1) * 0.08
    local brightness = 0.58 + clamp(light, 0, 1) * 0.34 + clamp(cell.elevation + 0.2, 0, 1) * 0.1
    if cell.water then brightness = 0.82 end
    return brightness
end

local vertexFloatCount = 8
local vertexByteCount = vertexFloatCount * 4
local floatPointer = ffi.typeof("float *")

local meshMinimums = {
    terrain = 4608,
    silhouette = 3072,
    river = 1024,
}

local function meshCapacity(required, minimum)
    local capacity = minimum or 256
    while capacity < required do capacity = capacity * 2 end
    return capacity
end

local function vertexCount(vertices)
    return vertices.count or #vertices
end

local function resetByteStream(stream, capacity)
    local oldBytes = stream.bytes
    local oldCount = stream.count or 0
    stream.bytes = love.data.newByteData(capacity * vertexByteCount)
    stream.floats = ffi.cast(floatPointer, stream.bytes:getFFIPointer())
    if oldBytes and oldCount > 0 then
        ffi.copy(stream.bytes:getFFIPointer(), oldBytes:getFFIPointer(), oldCount * vertexByteCount)
    end
    stream.capacity = capacity
end

local function vertexStream(app, id)
    app.vertexBuffers = app.vertexBuffers or {}
    local vertices = app.vertexBuffers[id]
    if not vertices then
        vertices = { count = 0 }
        app.vertexBuffers[id] = vertices
    end
    if love and love.data and not vertices.bytes then
        resetByteStream(vertices, meshMinimums[id] or 256)
    end
    vertices.count = 0
    return vertices
end

local function growVertexStream(vertices, required)
    if required <= (vertices.capacity or 0) then return end
    resetByteStream(vertices, meshCapacity(required, vertices.capacity or 256))
end

local function pushVertex(vertices, x, y, color, light, depth)
    local index = (vertices.count or #vertices) + 1
    light = light or 1
    depth = depth or 0
    if vertices.floats then
        growVertexStream(vertices, index)
        local offset = (index - 1) * vertexFloatCount
        vertices.floats[offset] = x
        vertices.floats[offset + 1] = y
        vertices.floats[offset + 2] = light
        vertices.floats[offset + 3] = depth
        vertices.floats[offset + 4] = color[1]
        vertices.floats[offset + 5] = color[2]
        vertices.floats[offset + 6] = color[3]
        vertices.floats[offset + 7] = 1
        vertices.count = index
        return
    end
    local vertex = vertices[index]
    if vertex then
        vertex[1] = x
        vertex[2] = y
        vertex[3] = light
        vertex[4] = depth
        vertex[5] = color[1]
        vertex[6] = color[2]
        vertex[7] = color[3]
        vertex[8] = 1
    else
        vertices[index] = { x, y, light, depth, color[1], color[2], color[3], 1 }
    end
    vertices.count = index
end

local function pushTriCoords(vertices, ax, ay, bx, by, cx, cy, color, light, depth)
    pushVertex(vertices, ax, ay, color, light, depth)
    pushVertex(vertices, bx, by, color, light, depth)
    pushVertex(vertices, cx, cy, color, light, depth)
end

local function pushQuadCoords(vertices, x00, y00, x10, y10, x11, y11, x01, y01, color, light, depth)
    pushTriCoords(vertices, x00, y00, x10, y10, x11, y11, color, light, depth)
    pushTriCoords(vertices, x00, y00, x11, y11, x01, y01, color, light, depth)
end

local function pushLineQuad(vertices, ax, ay, bx, by, width, color, light, depth)
    local dx, dy = bx - ax, by - ay
    local length = math.sqrt(dx * dx + dy * dy)
    if length <= 0.001 then return false end
    local nx, ny = -dy / length * width * 0.5, dx / length * width * 0.5
    pushQuadCoords(vertices, ax - nx, ay - ny, bx - nx, by - ny, bx + nx, by + ny, ax + nx, ay + ny, color, light, depth)
    return true
end

function Render.buildTerrainMeshData(app, width, height)
    local params = viewParams(app)
    app.camera.eyeZ = cameraHeight(app)
    local vertices = vertexStream(app, "terrain")
    local riverVertices = vertexStream(app, "river")
    local silhouetteVertices = vertexStream(app, "silhouette")
    local camera = app.camera
    local step = camera.step or 2
    local radius = camera.renderRadius or 86
    local lateralRange = radius * 0.82
    local basis = cameraBasis(camera.yaw or 0)
    local frustum = frustumState(camera, width, radius, lateralRange, step)
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
            if inFrustum(frustum, lat, dep, frustum.sampleMargin) then
                local wx = app.player.x + (basis.rightX * lat + basis.forwardX * dep) * params.factor
                local wy = app.player.y + (basis.rightY * lat + basis.forwardY * dep) * params.factor
                local _, z = viewCell(app, wx, wy, params)
                grid[row][col] = z
            end
        end
    end
    local fullTiles = (#depths - 1) * (#laterals - 1)
    local expectedMaxForFOV = 0
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
            if inFrustum(frustum, centerLat, centerDepth, frustum.tileMargin) then
                expectedMaxForFOV = expectedMaxForFOV + 1
                local centerX = app.player.x + (basis.rightX * centerLat + basis.forwardX * centerDepth) * params.factor
                local centerY = app.player.y + (basis.rightY * centerLat + basis.forwardY * centerDepth) * params.factor
                local cell = viewCell(app, centerX, centerY, params)
                local z0 = grid[row][col]
                local z1 = grid[row][col + 1]
                local z2 = grid[row + 1][col + 1]
                local z3 = grid[row + 1][col]
                local p00x, p00y, p10x, p10y, p11x, p11y, p01x, p01y
                if z0 then p00x, p00y = project(app, width, height, lat, dep, z0) end
                if z1 then p10x, p10y = project(app, width, height, nextLat, dep, z1) end
                if z2 then p11x, p11y = project(app, width, height, nextLat, nextDepth, z2) end
                if z3 then p01x, p01y = project(app, width, height, lat, nextDepth, z3) end
                if p00x and p10x and p11x and p01x then
                    local slopeLight = ((z0 + z1) - (z2 + z3)) / (terrainScale * 2)
                    local color = baseColor(cell)
                    pushQuadCoords(vertices, p00x, p00y, p10x, p10y, p11x, p11y, p01x, p01y, color, terrainLight(cell, slopeLight), centerDepth)
                    visibleTiles = visibleTiles + 1
                    local edgeSlope = math.abs(slopeLight)
                    if (cell.slope or 0) > 0.28 or edgeSlope > 0.045 then
                        local width = clamp(0.65 + (cell.slope or 0) * 3.2, 0.8, 2.4)
                        if pushLineQuad(silhouetteVertices, p01x, p01y, p11x, p11y, width, silhouetteColor, 1, centerDepth) then
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
                            if pushLineQuad(riverVertices, ax, ay, bx, by, stripWidth, biomeColors.river, 1, stripDepth) then
                                riverStrips = riverStrips + 1
                            end
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
        fullTiles = fullTiles,
        expectedMaxForFOV = expectedMaxForFOV,
        culledTiles = fullTiles - expectedMaxForFOV,
        triangles = vertexCount(vertices) / 3,
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
        fullTiles = mesh.fullTiles,
        expectedMaxForFOV = mesh.expectedMaxForFOV,
        culledTiles = mesh.culledTiles,
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

local function skyShader(app)
    app.shaders = app.shaders or {}
    if not app.shaders.skyDome then app.shaders.skyDome = love.graphics.newShader(skyShaderSource) end
    return app.shaders.skyDome
end

local function drawSky(app, width, height)
    local timeOfDay = app.atmosphereTime or 0.25
    local colors = Render.skyColors(timeOfDay)
    local shader = skyShader(app)
    shader:send("skyTop", colors.top)
    shader:send("skyHorizon", colors.horizon)
    shader:send("fogColor", colors.fog)
    shader:send("skySize", { width, height })
    shader:send("timeOfDay", timeOfDay % 1)
    love.graphics.setShader(shader)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, width, height)
    love.graphics.setShader()
    return colors
end

local meshFormat = {
    { "VertexPosition", "float", 2 },
    { "VertexTexCoord", "float", 2 },
    { "VertexColor", "float", 4 },
}

local billboardAtlasSize = 32
local billboardAtlasKinds = {
    "tree_deciduous",
    "tree_conifer",
    "tree_dead",
    "shrub",
    "reed",
    "rock",
    "outcrop",
    "peak",
    "ridge",
    "snow_tuft",
}
local billboardAtlasAliases = {
    snow = "snow_tuft",
    tree = "tree_deciduous",
}

local function terrainShader(app)
    app.shaders = app.shaders or {}
    if not app.shaders.terrain then
        local source = assert(love.filesystem.read("src/shaders/terrain.frag"))
        app.shaders.terrain = love.graphics.newShader(source)
    end
    return app.shaders.terrain
end

function Render.billboardAtlasKinds()
    local out = {}
    for index, kind in ipairs(billboardAtlasKinds) do out[index] = kind end
    return out
end

function Render.billboardAtlasKindFor(kind)
    return billboardAtlasAliases[kind] or kind
end

local function createBillboardAtlas()
    local image = love.graphics.newImage("assets/billboards.png")
    image:setFilter("nearest", "nearest")
    local width, height = image:getDimensions()
    local quads = {}
    for index, kind in ipairs(billboardAtlasKinds) do
        quads[kind] = love.graphics.newQuad((index - 1) * billboardAtlasSize, 0, billboardAtlasSize, billboardAtlasSize, width, height)
    end
    return image, quads
end

local function billboardResources(app, requiredSprites)
    app.billboardSprites = app.billboardSprites or {}
    local resources = app.billboardSprites
    if not resources.atlas then
        resources.atlas, resources.quads = createBillboardAtlas()
    end
    if not resources.batch or requiredSprites > resources.capacity then
        local capacity = meshCapacity(requiredSprites, resources.capacity or 256)
        resources.batch = love.graphics.newSpriteBatch(resources.atlas, capacity, "stream")
        resources.capacity = capacity
    end
    return resources
end

local function streamMesh(app, id, vertices)
    local count = vertexCount(vertices)
    app.meshes = app.meshes or {}
    local entry = app.meshes[id]
    if not entry or count > entry.capacity then
        local capacity = meshCapacity(count, meshMinimums[id])
        entry = {
            mesh = love.graphics.newMesh(meshFormat, capacity, "triangles", "stream"),
            capacity = capacity,
        }
        app.meshes[id] = entry
    end
    entry.mesh:setVertices(vertices.bytes or vertices, 1, count)
    entry.mesh:setDrawRange(1, count)
    return entry.mesh
end

local function drawStream(app, id, vertices, fogAmount, lightAmount)
    if vertexCount(vertices) <= 0 then return end
    local radius = app.camera.renderRadius or 50
    local shader = terrainShader(app)
    shader:send("fogColor", fogColor)
    shader:send("fogNear", 24)
    shader:send("fogFar", math.max(25, radius))
    shader:send("fogAmount", fogAmount)
    shader:send("lightAmount", lightAmount)
    love.graphics.setShader(shader)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(streamMesh(app, id, vertices))
    love.graphics.setShader()
end

local function drawBillboards(app, list)
    if #list == 0 then return end
    local resources = billboardResources(app, #list * 2)
    local batch = resources.batch
    local quads = resources.quads
    batch:clear()
    for _, item in ipairs(list) do
        local color = item.color
        local fog = clamp((item.depth - 18) / 68, 0, 1)
        local c = mixColor(color, fogColor, fog * 0.75)
        local h = item.baseY - item.topY
        if h > 0 then
            batch:setColor(c[1], c[2], c[3], 1)
            local atlasKind = Render.billboardAtlasKindFor(item.kind)
            batch:add(quads[atlasKind] or quads.shrub, item.x - item.w * 0.5, item.topY, 0, item.w / billboardAtlasSize, h / billboardAtlasSize)
        end
    end
    batch:setColor(1, 1, 1, 1)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(batch)
end

local function fmt(value)
    return string.format("%.3f", value or 0)
end

local function topoColor(entry)
    local cell = entry.cell
    if cell.river then return biomeColors.river end
    if cell.water then return cell.lake and biomeColors.lake or biomeColors.ocean end
    local low = { 0.18, 0.34, 0.18 }
    local high = { 0.78, 0.74, 0.52 }
    local t = clamp(((cell.elevation or 0) + 0.1) / 0.8, 0, 1)
    local color = mixColor(low, high, t)
    if entry.contour then color = shade(color, 0.58) end
    return color
end

function Render.topographicMapData(app, sampleCount)
    local params = viewParams(app)
    local count = sampleCount or 64
    local span = (app.topographicSpan or 256) * (params.factor or 1)
    local step = span / math.max(1, count - 1)
    local originX = app.player.x - span * 0.5
    local originY = app.player.y - span * 0.5
    local rows = {}
    local stats = { samples = 0, water = 0, rivers = 0, contours = 0, scale = params.target, span = span }
    for row = 1, count do
        rows[row] = {}
        for col = 1, count do
            local wx = originX + (col - 1) * step
            local wy = originY + (row - 1) * step
            local cell = app.world:sample(math.floor(wx), math.floor(wy), params.target)
            rows[row][col] = { cell = cell, contour = false }
            stats.samples = stats.samples + 1
            if cell.water then stats.water = stats.water + 1 end
            if cell.river then stats.rivers = stats.rivers + 1 end
        end
    end
    for row = 1, count do
        for col = 1, count do
            local cell = rows[row][col].cell
            if not cell.water then
                local band = math.floor((cell.elevation or 0) / 0.08)
                local east = rows[row][col + 1] and rows[row][col + 1].cell
                local south = rows[row + 1] and rows[row + 1][col] and rows[row + 1][col].cell
                local edge = (east and not east.water and math.floor((east.elevation or 0) / 0.08) ~= band) or (south and not south.water and math.floor((south.elevation or 0) / 0.08) ~= band)
                if edge then
                    rows[row][col].contour = true
                    stats.contours = stats.contours + 1
                end
            end
        end
    end
    stats.rows = rows
    stats.sampleCount = count
    return stats
end

function Render.debugPanelData(app)
    local params = viewParams(app)
    local cell = app.world:sample(math.floor(app.player.x), math.floor(app.player.y), params.target)
    local plate = app.world:plateAt(app.player.x, app.player.y)
    local scaleFactor = cell.scaleFactor or 1
    local downX = cell.downX and cell.downX * scaleFactor or cell.x * scaleFactor
    local downY = cell.downY and cell.downY * scaleFactor or cell.y * scaleFactor
    return {
        scale = params.target,
        plate = {
            id = plate.id,
            secondaryId = plate.secondaryId,
            vx = plate.vx or 0,
            vy = plate.vy or 0,
            boundary = plate.boundary or 0,
            convergent = plate.convergent or 0,
            divergent = plate.divergent or 0,
            subduction = plate.oceanicSubduction or 0,
        },
        drainage = {
            dx = downX - app.player.x,
            dy = downY - app.player.y,
            flow = cell.flow or 0,
            basinId = cell.basinId,
            watershedId = cell.watershedId,
            river = cell.river == true,
        },
        erosion = {
            erosion = cell.erosion or 0,
            deposition = cell.deposition or 0,
            thermal = cell.thermalErosion or 0,
            talus = cell.talus == true,
            alluvialFan = cell.alluvialFan == true,
            floodplain = cell.floodplain == true,
            delta = cell.delta == true,
        },
        biome = {
            id = cell.biome,
            elevation = cell.elevation or 0,
            rainfall = cell.rainfall or 0,
            moisture = cell.moisture or 0,
            temperature = cell.temperature or 0,
            slope = cell.slope or 0,
            water = cell.water == true,
            lake = cell.lake == true,
        },
    }
end

local function drawTopographicMap(app, width)
    local data = Render.topographicMapData(app, app.topographicSamples or 64)
    local pixel = 3
    local size = data.sampleCount * pixel
    local x0 = width - size - 16
    local y0 = 16
    love.graphics.setColor(0.02, 0.025, 0.03, 0.82)
    love.graphics.rectangle("fill", x0 - 8, y0 - 8, size + 16, size + 34)
    for row = 1, data.sampleCount do
        for col = 1, data.sampleCount do
            local color = topoColor(data.rows[row][col])
            love.graphics.setColor(color[1], color[2], color[3], 1)
            love.graphics.rectangle("fill", x0 + (col - 1) * pixel, y0 + (row - 1) * pixel, pixel, pixel)
        end
    end
    love.graphics.setColor(0.88, 0.9, 0.82, 1)
    love.graphics.print("topo " .. tostring(data.scale) .. " / " .. tostring(data.contours) .. " contours", x0, y0 + size + 8)
    return data
end

local function drawDebugPanels(app, width, y)
    local data = Render.debugPanelData(app)
    local x = width - 364
    love.graphics.setColor(0.02, 0.025, 0.03, 0.82)
    love.graphics.rectangle("fill", x - 8, y - 8, 356, 164)
    love.graphics.setColor(0.88, 0.9, 0.82, 1)
    love.graphics.print("plates v " .. fmt(data.plate.vx) .. "," .. fmt(data.plate.vy) .. " b " .. fmt(data.plate.boundary) .. " conv " .. fmt(data.plate.convergent), x, y)
    love.graphics.print("drain -> " .. fmt(data.drainage.dx) .. "," .. fmt(data.drainage.dy) .. " flow " .. fmt(data.drainage.flow) .. " river " .. tostring(data.drainage.river), x, y + 28)
    love.graphics.print("erosion e " .. fmt(data.erosion.erosion) .. " d " .. fmt(data.erosion.deposition) .. " t " .. fmt(data.erosion.thermal), x, y + 56)
    love.graphics.print("forms talus " .. tostring(data.erosion.talus) .. " fan " .. tostring(data.erosion.alluvialFan) .. " plain " .. tostring(data.erosion.floodplain), x, y + 84)
    love.graphics.print("biome " .. tostring(data.biome.id) .. " elev " .. fmt(data.biome.elevation) .. " rain " .. fmt(data.biome.rainfall), x, y + 112)
    love.graphics.print("inputs temp " .. fmt(data.biome.temperature) .. " moist " .. fmt(data.biome.moisture) .. " slope " .. fmt(data.biome.slope), x, y + 140)
    return data
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

function Render.drawScene(app, width, height)
    love.graphics.clear(skyTop[1], skyTop[2], skyTop[3], 1)
    local sky = drawSky(app, width, height)
    local meshData = Render.buildTerrainMeshData(app, width, height)
    meshData.skyDome = 1
    meshData.skyTime = app.atmosphereTime or 0.25
    meshData.skyDaylight = sky.daylight
    drawStream(app, "terrain", meshData.vertices, 0.76, 1)
    drawStream(app, "silhouette", meshData.silhouetteVertices, 0.78, 0)
    drawStream(app, "river", meshData.riverVertices, 0.55, 0)
    local billboards = Render.billboardDrawList(app, width, height)
    drawBillboards(app, billboards)
    meshData.billboards = #billboards
    meshData.landmarks = 0
    for _, item in ipairs(billboards) do
        if item.kind == "peak" or item.kind == "ridge" or item.kind == "outcrop" then meshData.landmarks = meshData.landmarks + 1 end
    end
    return meshData
end

function Render.drawHud(app, width, height, meshData)
    meshData = meshData or {}
    love.graphics.setColor(0.95, 0.92, 0.74, 1)
    love.graphics.circle("fill", width * 0.5, height * 0.52, 2)
    if app.debugTopo then
        local topo = drawTopographicMap(app, width)
        meshData.topographicMap = topo.samples
        meshData.topographicContours = topo.contours
    end
    if app.debugPanels then
        local debugY = app.debugTopo and 246 or 16
        local panels = drawDebugPanels(app, width, debugY)
        meshData.debugPanels = 1
        meshData.debugPanelScale = panels.scale
    end
    drawHud(app, width, height, meshData)
    return meshData
end

function Render.draw(app)
    local width, height = love.graphics.getDimensions()
    local meshData = Render.drawScene(app, width, height)
    return Render.drawHud(app, width, height, meshData)
end

return Render
