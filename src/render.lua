local Render = {}
local ViewScale = require("src.viewscale")
local Clipmap = require("src.clipmap")
local Atmosphere = require("src.atmosphere")
local ffi = require("ffi")

local terrainScale = 18
local biomeBannerFontPath = "assets/fonts/BigBlue_Terminal_437TT.TTF"

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
    lava_flow = { 0.18, 0.13, 0.11 },
    shield = { 0.28, 0.32, 0.25 },
    karst = { 0.55, 0.58, 0.46 },
    reef = { 0.12, 0.62, 0.62 },
    lagoon = { 0.06, 0.42, 0.58 },
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
    stratoCone = { 0.24, 0.22, 0.21 },
    caldera = { 0.12, 0.1, 0.09 },
    lavaFlow = { 0.2, 0.12, 0.09 },
    shieldVolcano = { 0.25, 0.3, 0.23 },
    cinderCone = { 0.18, 0.14, 0.12 },
    pingo = { 0.62, 0.66, 0.62 },
    palsa = { 0.44, 0.38, 0.3 },
    polygonal = { 0.52, 0.56, 0.52 },
    solifluction = { 0.46, 0.44, 0.38 },
    submarineCanyon = { 0.02, 0.07, 0.16 },
}

local skyTop = { 0.43, 0.55, 0.66 }
local skyHorizon = { 0.68, 0.74, 0.75 }
local fogColor = { 0.6, 0.68, 0.69 }
local silhouetteColor = { 0.08, 0.09, 0.08 }
local tau = math.pi * 2
local seasonSkyTints = {
    spring = { top = { 0.96, 1.04, 0.98 }, horizon = { 1.02, 0.98, 0.92 }, fog = { 0.96, 1.04, 0.98 } },
    summer = { top = { 1.04, 1.0, 0.9 }, horizon = { 1.08, 0.96, 0.84 }, fog = { 1.02, 0.98, 0.9 } },
    autumn = { top = { 1.06, 0.92, 0.86 }, horizon = { 1.12, 0.86, 0.74 }, fog = { 1.08, 0.9, 0.8 } },
    winter = { top = { 0.82, 0.92, 1.12 }, horizon = { 0.86, 0.94, 1.08 }, fog = { 0.82, 0.94, 1.08 } },
}
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

function Render.biomeDisplayName(id)
    return string.upper((tostring(id or "unknown"):gsub("_", " ")))
end

function Render.bannerAlpha(age, duration, fade)
    age = age or 0
    duration = duration or 3
    fade = fade or 0.75
    if age < 0 or age >= duration then return 0 end
    return math.min(1, age / fade, (duration - age) / fade)
end

local function fontCache(app, path, size)
    app.fonts = app.fonts or {}
    local key = tostring(path) .. ":" .. tostring(size)
    if not app.fonts[key] then
        local font = love.filesystem.getInfo(path) and love.graphics.newFont(path, size) or love.graphics.newFont(size)
        if font.setFilter then font:setFilter("nearest", "nearest") end
        app.fonts[key] = font
    end
    return app.fonts[key]
end

local function tintColor(color, tint)
    return { clamp(color[1] * tint[1], 0, 1), clamp(color[2] * tint[2], 0, 1), clamp(color[3] * tint[3], 0, 1) }
end

function Render.skyColors(timeOfDay, season)
    if type(timeOfDay) == "table" then
        season = timeOfDay.season
        timeOfDay = timeOfDay.time
    end
    local t = (tonumber(timeOfDay) or 0.25) % 1
    local daylight = clamp(math.sin(t * tau), 0, 1)
    local dusk = 1 - daylight
    local nightTop = { 0.035, 0.045, 0.12 }
    local nightHorizon = { 0.16, 0.12, 0.2 }
    local nightFog = { 0.18, 0.2, 0.26 }
    local tint = seasonSkyTints[season or "summer"] or seasonSkyTints.summer
    return {
        top = tintColor(mixColor(nightTop, skyTop, daylight), tint.top),
        horizon = tintColor(mixColor(nightHorizon, skyHorizon, daylight), tint.horizon),
        fog = tintColor(mixColor(nightFog, fogColor, daylight * 0.85 + dusk * 0.18), tint.fog),
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
    if cell.water then color = (cell.biome == "coast" or cell.biome == "reef" or cell.biome == "lagoon") and biomeColors[cell.biome] or biomeColors.ocean end
    if (cell.craton or 0) > 0.12 then color = mixColor(color, landformColors.craton, 0.34) end
    if (cell.shield or 0) > 0.2 then color = mixColor(color, landformColors.shield, 0.26) end
    if (cell.riftValley or 0) > 0.08 then color = mixColor(color, landformColors.rift, 0.4) end
    if (cell.volcanicIslandArc or 0) > 0.04 then color = mixColor(color, landformColors.islandArc, 0.38) end
    if (cell.volcanicForm or 0) == 1 then color = mixColor(color, landformColors.stratoCone, 0.55) end
    if (cell.volcanicForm or 0) == 2 then color = mixColor(color, landformColors.caldera, 0.65) end
    if (cell.volcanicForm or 0) == 3 then color = mixColor(color, landformColors.lavaFlow, 0.62) end
    if (cell.volcanicForm or 0) == 4 then color = mixColor(color, landformColors.shieldVolcano, 0.5) end
    if (cell.volcanicForm or 0) == 5 then color = mixColor(color, landformColors.cinderCone, 0.55) end
    if (cell.periglacialFeature or 0) == 1 then color = mixColor(color, landformColors.pingo, 0.42) end
    if (cell.periglacialFeature or 0) == 2 then color = mixColor(color, landformColors.palsa, 0.42) end
    if (cell.periglacialFeature or 0) == 3 then color = mixColor(color, landformColors.polygonal, 0.32) end
    if (cell.periglacialFeature or 0) == 4 then color = mixColor(color, landformColors.solifluction, 0.38) end
    if cell.submarineCanyon then color = mixColor(color, landformColors.submarineCanyon, 0.52) end
    if cell.delta then color = mixColor(color, landformColors.delta, 0.55) end
    if cell.coastBeach then color = mixColor(color, landformColors.coastBeach, 0.68) end
    if cell.coastCliff then color = mixColor(color, landformColors.coastCliff, 0.6) end
    if cell.oxbowLake then color = mixColor(color, biomeColors.lake, 0.5) end
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

local function terrainLight(cell, diffuse)
    local light = 0.72 + clamp(diffuse, -0.32, 0.42) - clamp(cell.slope or 0, 0, 1) * 0.08
    local brightness = 0.58 + clamp(light, 0, 1) * 0.34 + clamp(cell.elevation + 0.2, 0, 1) * 0.1
    if cell.water then brightness = 0.82 end
    return brightness
end

local function quadDiffuse(z00, z10, z11, z01, sx, sy, sz)
    local slopeRight = ((z10 + z11) - (z00 + z01)) * 0.5 / terrainScale
    local slopeForward = ((z01 + z11) - (z00 + z10)) * 0.5 / terrainScale
    local nx, ny, nz = -slopeRight, -slopeForward, 1
    local invLen = 1 / math.sqrt(nx * nx + ny * ny + nz * nz)
    return (nx * sx + ny * sy + nz * sz) * invLen
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

local function buildGridTerrainMeshData(app, width, height, params)
    params = params or viewParams(app)
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
    local sun = Atmosphere.sunDirection(app.atmosphere)
    local sunLat = sun.x * basis.rightX + sun.y * basis.rightY
    local sunDep = sun.x * basis.forwardX + sun.y * basis.forwardY
    local sunZ = sun.z
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
                    local diffuse = quadDiffuse(z0, z1, z2, z3, sunLat, sunDep, sunZ)
                    local edgeSlope = math.abs((z0 + z1 - z2 - z3) / (terrainScale * 2))
                    local color = baseColor(cell)
                    pushQuadCoords(vertices, p00x, p00y, p10x, p10y, p11x, p11y, p01x, p01y, color, terrainLight(cell, diffuse), centerDepth)
                    visibleTiles = visibleTiles + 1
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

local function terrainClipmap(app)
    app.terrainClipmap = app.terrainClipmap or Clipmap.new()
    return app.terrainClipmap
end

local function clipmapSampleFn(app, params)
    return function(x, y, level)
        local gx, gy = math.floor(x), math.floor(y)
        local cell = level.index <= 2 and app.world:sample(gx, gy, params.target) or app.world:baseSample(gx, gy, params.target)
        return cell, terrainZ(cell)
    end
end

local function clipmapZ(level, nextLevel, sample, ix, iy)
    local z = sample.z
    local morph = Clipmap.outerMorph(level, ix, iy)
    if morph > 0 and nextLevel then
        local coarseZ = Clipmap.heightAt(nextLevel, sample.x, sample.y)
        if coarseZ then z = mix(z, coarseZ, morph) end
    end
    return z, morph
end

local function projectClipmapSample(app, width, height, params, sample, z)
    local lateral, depth = cameraLocal(app, sample.x, sample.y, params)
    local sx, sy = project(app, width, height, lateral, depth, z)
    return sx, sy, depth
end

local function buildClipmapTerrainMeshData(app, width, height, params)
    params = params or viewParams(app)
    app.camera.eyeZ = cameraHeight(app)
    local vertices = vertexStream(app, "terrain")
    local riverVertices = vertexStream(app, "river")
    local silhouetteVertices = vertexStream(app, "silhouette")
    local camera = app.camera
    local clipmap = terrainClipmap(app)
    local _, clipStats = Clipmap.update(clipmap, app.player.x, app.player.y, clipmapSampleFn(app, params), { scaleId = params.target })
    local radius = math.max(camera.renderRadius or 86, clipStats.radius)
    local frustum = frustumState(camera, width, radius, radius * 0.82, 1)
    local basis = cameraBasis(camera.yaw or 0)
    local sun = Atmosphere.sunDirection(app.atmosphere)
    local sunLat = sun.x * basis.rightX + sun.y * basis.rightY
    local sunDep = sun.x * basis.forwardX + sun.y * basis.forwardY
    local sunZ = sun.z
    local visibleTiles = 0
    local expectedMaxForFOV = 0
    local riverStrips = 0
    local silhouetteStrips = 0
    local morphTiles = 0
    for levelIndex, level in ipairs(clipmap.levels) do
        local nextLevel = clipmap.levels[levelIndex + 1]
        for _, tile in ipairs(level.tiles) do
            local s00 = level.samples[tile.i00]
            local s10 = level.samples[tile.i10]
            local s11 = level.samples[tile.i11]
            local s01 = level.samples[tile.i01]
            local centerX = (s00.x + s11.x) * 0.5
            local centerY = (s00.y + s11.y) * 0.5
            local centerLat, centerDepth = cameraLocal(app, centerX, centerY, params)
            if inFrustum(frustum, centerLat, centerDepth, level.step * 1.5) then
                expectedMaxForFOV = expectedMaxForFOV + 1
                local z00, m00 = clipmapZ(level, nextLevel, s00, tile.ix, tile.iy)
                local z10, m10 = clipmapZ(level, nextLevel, s10, tile.ix + 1, tile.iy)
                local z11, m11 = clipmapZ(level, nextLevel, s11, tile.ix + 1, tile.iy + 1)
                local z01, m01 = clipmapZ(level, nextLevel, s01, tile.ix, tile.iy + 1)
                local p00x, p00y = projectClipmapSample(app, width, height, params, s00, z00)
                local p10x, p10y = projectClipmapSample(app, width, height, params, s10, z10)
                local p11x, p11y = projectClipmapSample(app, width, height, params, s11, z11)
                local p01x, p01y = projectClipmapSample(app, width, height, params, s01, z01)
                if p00x and p10x and p11x and p01x then
                    if math.max(m00, m10, m11, m01) > 0 then morphTiles = morphTiles + 1 end
                    local cell = s00.cell
                    local diffuse = quadDiffuse(z00, z10, z11, z01, sunLat, sunDep, sunZ)
                    local edgeSlope = math.abs((z00 + z10 - z11 - z01) / (terrainScale * 2))
                    local color = baseColor(cell)
                    pushQuadCoords(vertices, p00x, p00y, p10x, p10y, p11x, p11y, p01x, p01y, color, terrainLight(cell, diffuse), centerDepth)
                    visibleTiles = visibleTiles + 1
                    if (cell.slope or 0) > 0.28 or edgeSlope > 0.045 then
                        local stripWidth = clamp(0.65 + (cell.slope or 0) * 3.2, 0.8, 2.4)
                        if pushLineQuad(silhouetteVertices, p01x, p01y, p11x, p11y, stripWidth, silhouetteColor, 1, centerDepth) then
                            silhouetteStrips = silhouetteStrips + 1
                        end
                    end
                    if level.index <= 2 and cell.river and cell.downX and cell.downY then
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
        fullTiles = clipStats.tileCapacity,
        expectedMaxForFOV = expectedMaxForFOV,
        culledTiles = clipStats.tileCapacity - expectedMaxForFOV,
        triangles = vertexCount(vertices) / 3,
        riverStrips = riverStrips,
        silhouetteStrips = silhouetteStrips,
        cameraHeight = app.camera.eyeZ,
        viewScale = params.target,
        viewFactor = params.factor,
        viewProgress = params.progress,
        terrainRadius = radius,
        clipmap = true,
        clipmapRings = clipStats.rings,
        clipmapRadius = clipStats.radius,
        clipmapSteps = table.concat(clipStats.steps, ","),
        clipmapTileCapacity = clipStats.tileCapacity,
        clipmapVertexCapacity = clipStats.vertexCapacity,
        clipmapRefilledRings = clipStats.refilledRings,
        clipmapReusedRings = clipStats.reusedRings,
        clipmapPartialRefills = clipStats.partialRefills,
        clipmapFullRefills = clipStats.fullRefills,
        clipmapSamplesRefilled = clipStats.samplesRefilled,
        clipmapMorphBands = clipStats.morphBands,
        clipmapMorphTiles = morphTiles,
    }
end

function Render.buildTerrainMeshData(app, width, height)
    local params = viewParams(app)
    if params.target == "local" and not params.transitioning then
        return buildClipmapTerrainMeshData(app, width, height, params)
    end
    return buildGridTerrainMeshData(app, width, height, params)
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
                            swayPhase = spec.swayPhase or 0,
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
    local landmarks, swayBillboards = 0, 0
    for _, item in ipairs(billboards) do
        if item.kind == "peak" or item.kind == "ridge" or item.kind == "outcrop" then landmarks = landmarks + 1 end
        if Render.billboardSwayMagnitude(item.kind) > 0 then swayBillboards = swayBillboards + 1 end
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
        swayBillboards = swayBillboards,
        landmarks = landmarks,
        cameraHeight = mesh.cameraHeight,
        viewScale = mesh.viewScale,
        viewFactor = mesh.viewFactor,
        viewProgress = mesh.viewProgress,
        terrainRadius = mesh.terrainRadius,
        clipmap = mesh.clipmap,
        clipmapRings = mesh.clipmapRings,
        clipmapRadius = mesh.clipmapRadius,
        clipmapSteps = mesh.clipmapSteps,
        clipmapTileCapacity = mesh.clipmapTileCapacity,
        clipmapVertexCapacity = mesh.clipmapVertexCapacity,
        clipmapRefilledRings = mesh.clipmapRefilledRings,
        clipmapReusedRings = mesh.clipmapReusedRings,
        clipmapPartialRefills = mesh.clipmapPartialRefills,
        clipmapFullRefills = mesh.clipmapFullRefills,
        clipmapSamplesRefilled = mesh.clipmapSamplesRefilled,
        clipmapMorphBands = mesh.clipmapMorphBands,
        clipmapMorphTiles = mesh.clipmapMorphTiles,
        labels = #(ViewScale.visibleLabels(app.viewScale, 8)),
    }
end

local function skyShader(app)
    app.shaders = app.shaders or {}
    if not app.shaders.skyDome then app.shaders.skyDome = love.graphics.newShader(skyShaderSource) end
    return app.shaders.skyDome
end

local function drawSky(app, width, height)
    local atmosphere = app.atmosphere
    local timeOfDay = (atmosphere and atmosphere.time) or app.atmosphereTime or 0.25
    local colors = Render.skyColors(atmosphere or timeOfDay)
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
local billboardSwayMagnitudes = {
    tree_deciduous = 1.15,
    tree_conifer = 1.05,
    tree_dead = 0.42,
    shrub = 0.24,
    reed = 0.68,
    rock = 0,
    outcrop = 0,
    peak = 0,
    ridge = 0,
    snow_tuft = 0,
}
local billboardShaderSource = [[
extern number time;
extern number atlasColumns;

#ifdef VERTEX
vec4 position(mat4 transform_projection, vec4 vertex_position)
{
    number cell = floor(VertexTexCoord.x * atlasColumns);
    number top = 1.0 - VertexTexCoord.y;
    number magnitude = 0.0;
    if (cell < 2.0) {
        magnitude = 1.15;
    } else if (cell < 3.0) {
        magnitude = 0.42;
    } else if (cell < 4.0) {
        magnitude = 0.24;
    } else if (cell < 5.0) {
        magnitude = 0.68;
    }
    vertex_position.x += sin(time * 6.2831853 + VertexColor.a * 6.2831853) * magnitude * top * top;
    return transform_projection * vertex_position;
}
#endif

#ifdef PIXEL
vec4 effect(vec4 color, Image texture, vec2 textureCoords, vec2 screenCoords)
{
    vec4 texel = Texel(texture, textureCoords);
    return vec4(texel.rgb * color.rgb, texel.a);
}
#endif
]]

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

function Render.billboardSwayMagnitude(kind)
    return billboardSwayMagnitudes[Render.billboardAtlasKindFor(kind)] or 0
end

local function billboardShader(app)
    app.shaders = app.shaders or {}
    if not app.shaders.billboardSway then app.shaders.billboardSway = love.graphics.newShader(billboardShaderSource) end
    return app.shaders.billboardSway
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

local function drawStream(app, id, vertices, fogAmount, lightAmount, radiusOverride)
    if vertexCount(vertices) <= 0 then return end
    local radius = radiusOverride or app.camera.renderRadius or 50
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
            local phase = clamp((item.swayPhase or 0) * 0.5 + 0.5, 0, 1)
            batch:setColor(c[1], c[2], c[3], phase)
            local atlasKind = Render.billboardAtlasKindFor(item.kind)
            batch:add(quads[atlasKind] or quads.shrub, item.x - item.w * 0.5, item.topY, 0, item.w / billboardAtlasSize, h / billboardAtlasSize)
        end
    end
    batch:setColor(1, 1, 1, 1)
    love.graphics.setColor(1, 1, 1, 1)
    local shader = billboardShader(app)
    shader:send("time", app.atmosphere and app.atmosphere.time or app.atmosphereTime or 0)
    shader:send("atlasColumns", #billboardAtlasKinds)
    love.graphics.setShader(shader)
    love.graphics.draw(batch)
    love.graphics.setShader()
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

local function minimapData(app)
    local params = viewParams(app)
    local sampleCount = app.minimapSamples or 48
    local bucket = app.minimapBucket or 8
    local cache = app.minimapCache
    local key = table.concat({
        params.target,
        sampleCount,
        math.floor((app.player.x or 0) / bucket),
        math.floor((app.player.y or 0) / bucket),
    }, ":")
    local time = love.timer and love.timer.getTime and love.timer.getTime() or os.clock()
    if cache and cache.key == key and time - (cache.time or 0) < (app.minimapInterval or 0.2) then return cache.data end
    local span = app.topographicSpan
    app.topographicSpan = app.minimapSpan or 192
    local data = Render.topographicMapData(app, sampleCount)
    app.topographicSpan = span
    app.minimapCache = { key = key, time = time, data = data }
    return data
end

local function drawMinimap(app, width, height)
    local data = minimapData(app)
    local pixel = math.max(2, math.floor(math.min(width, height) * 0.22 / data.sampleCount))
    local size = data.sampleCount * pixel
    local x0 = width - size - 18
    local y0 = height - size - 70
    love.graphics.setColor(0.02, 0.025, 0.03, 0.76)
    love.graphics.rectangle("fill", x0 - 6, y0 - 6, size + 12, size + 12)
    for row = 1, data.sampleCount do
        for col = 1, data.sampleCount do
            local color = topoColor(data.rows[row][col])
            love.graphics.setColor(color[1], color[2], color[3], 0.96)
            love.graphics.rectangle("fill", x0 + (col - 1) * pixel, y0 + (row - 1) * pixel, pixel, pixel)
        end
    end
    love.graphics.setColor(0.95, 0.92, 0.74, 1)
    local cx = x0 + size * 0.5
    local cy = y0 + size * 0.5
    local ux = app.player.travelX
    local uy = app.player.travelY
    if not ux or not uy or ux * ux + uy * uy < 0.0001 then
        ux, uy = math.sin(app.camera.yaw or 0), -math.cos(app.camera.yaw or 0)
    end
    local px, py = -uy, ux
    love.graphics.polygon("fill", cx + ux * 6, cy + uy * 6, cx - ux * 5 + px * 4, cy - uy * 5 + py * 4, cx - ux * 5 - px * 4, cy - uy * 5 - py * 4)
    love.graphics.setColor(0.95, 0.92, 0.74, 0.72)
    love.graphics.rectangle("line", x0 - 0.5, y0 - 0.5, size + 1, size + 1)
    return data
end

local function drawBiomeBanner(app, width, height)
    local banner = app.biomeBanner
    if not banner then return nil end
    local alpha = Render.bannerAlpha(banner.age, banner.duration, banner.fade)
    if alpha <= 0 then return nil end
    local font = fontCache(app, biomeBannerFontPath, app.biomeBannerFontSize or 32)
    local previous = love.graphics.getFont()
    love.graphics.setFont(font)
    local text = banner.label or Render.biomeDisplayName(banner.biome)
    local x = math.floor((width - font:getWidth(text)) * 0.5)
    local y = math.floor(height * 0.42)
    love.graphics.setColor(0.02, 0.025, 0.03, 0.72 * alpha)
    love.graphics.rectangle("fill", x - 18, y - 10, font:getWidth(text) + 36, font:getHeight() + 20)
    love.graphics.setColor(0, 0, 0, 0.55 * alpha)
    love.graphics.print(text, x + 3, y + 3)
    love.graphics.setColor(0.95, 0.92, 0.74, alpha)
    love.graphics.print(text, x, y)
    love.graphics.setFont(previous)
    return alpha
end

local debugPanelLines = {
    { id = "plate", label = function(d) return "plates v " .. fmt(d.plate.vx) .. "," .. fmt(d.plate.vy) .. " b " .. fmt(d.plate.boundary) .. " conv " .. fmt(d.plate.convergent) end },
    { id = "drainage", label = function(d) return "drain -> " .. fmt(d.drainage.dx) .. "," .. fmt(d.drainage.dy) .. " flow " .. fmt(d.drainage.flow) .. " river " .. tostring(d.drainage.river) end },
    { id = "erosion", label = function(d) return "erosion e " .. fmt(d.erosion.erosion) .. " d " .. fmt(d.erosion.deposition) .. " t " .. fmt(d.erosion.thermal) .. " talus " .. tostring(d.erosion.talus) end },
    { id = "biome", label = function(d) return "biome " .. tostring(d.biome.id) .. " temp " .. fmt(d.biome.temperature) .. " moist " .. fmt(d.biome.moisture) .. " slope " .. fmt(d.biome.slope) end },
}

function Render.debugPanelIds()
    local out = {}
    for index, panel in ipairs(debugPanelLines) do out[index] = panel.id end
    return out
end

local function debugPanelToggles(app)
    if type(app.debugPanels) == "table" then return app.debugPanels end
    local master = app.debugPanels == true
    return { plate = master, drainage = master, erosion = master, biome = master }
end

local function drawDebugPanels(app, width, y)
    local toggles = debugPanelToggles(app)
    local active = {}
    for _, panel in ipairs(debugPanelLines) do
        if toggles[panel.id] then active[#active + 1] = panel end
    end
    if #active == 0 then return Render.debugPanelData(app) end
    local data = Render.debugPanelData(app)
    local x = width - 364
    local lineHeight = 28
    local panelHeight = #active * lineHeight + 12
    love.graphics.setColor(0.02, 0.025, 0.03, 0.82)
    love.graphics.rectangle("fill", x - 8, y - 8, 356, panelHeight)
    love.graphics.setColor(0.88, 0.9, 0.82, 1)
    for index, panel in ipairs(active) do
        love.graphics.print(panel.label(data), x, y + (index - 1) * lineHeight)
    end
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
    love.graphics.print("WASD move  mouse/E/left look  Tab scope  M map  N mark  Q quit", width - 416, height - 42)
end

function Render.drawScene(app, width, height)
    love.graphics.clear(skyTop[1], skyTop[2], skyTop[3], 1)
    local sky = drawSky(app, width, height)
    local meshData = Render.buildTerrainMeshData(app, width, height)
    meshData.skyDome = 1
    meshData.skyTime = app.atmosphere and app.atmosphere.time or app.atmosphereTime or 0.25
    meshData.skySeason = app.atmosphere and app.atmosphere.season or "summer"
    meshData.skyDaylight = sky.daylight
    drawStream(app, "terrain", meshData.vertices, 0.76, 1, meshData.terrainRadius)
    drawStream(app, "silhouette", meshData.silhouetteVertices, 0.78, 0, meshData.terrainRadius)
    drawStream(app, "river", meshData.riverVertices, 0.55, 0, meshData.terrainRadius)
    local billboards = Render.billboardDrawList(app, width, height)
    drawBillboards(app, billboards)
    meshData.billboards = #billboards
    meshData.swayBillboards = 0
    meshData.landmarks = 0
    for _, item in ipairs(billboards) do
        if item.kind == "peak" or item.kind == "ridge" or item.kind == "outcrop" then meshData.landmarks = meshData.landmarks + 1 end
        if Render.billboardSwayMagnitude(item.kind) > 0 then meshData.swayBillboards = meshData.swayBillboards + 1 end
    end
    meshData.swayTime = app.atmosphere and app.atmosphere.time or app.atmosphereTime or 0
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
    if app.minimap then
        local map = drawMinimap(app, width, height)
        meshData.minimap = map.samples
        meshData.minimapContours = map.contours
    end
    local biomeBannerAlpha = drawBiomeBanner(app, width, height)
    if biomeBannerAlpha then meshData.biomeBannerAlpha = biomeBannerAlpha end
    do
        local toggles = debugPanelToggles(app)
        local any = false
        for _, panel in ipairs(debugPanelLines) do if toggles[panel.id] then any = true break end end
        if any then
            local debugY = app.debugTopo and 246 or 16
            local panels = drawDebugPanels(app, width, debugY)
            meshData.debugPanels = 1
            meshData.debugPanelScale = panels.scale
        end
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
