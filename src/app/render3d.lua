local Defs = require("src.game.defs")

local Render3D = {}
local state = {
    loaded = false,
    headless = false,
    g3d = nil,
    assets = {},
}
local tilePalette = {}
local tilePaletteOrder = {}
local cameraPitch = math.rad(30)
local cameraDistance = 26
local cameraViewSize = 24
local baseYaw = math.rad(45)
local visibleRadius = 10
local atlasColumns = 8
local atlasRows = 5

local function clearList(list)
    for i = #list, 1, -1 do
        list[i] = nil
    end
end

function Render3D.prepareUi(app)
    app.ui = app.ui or {}
    app.ui.skillButtons = app.ui.skillButtons or {}
    app.ui.heroButtons = app.ui.heroButtons or {}
    app.ui.enemyButtons = app.ui.enemyButtons or {}
    app.ui.itemButtons = app.ui.itemButtons or {}
    app.ui.missionButtons = app.ui.missionButtons or {}
    app.ui.recruitButtons = app.ui.recruitButtons or {}
    app.ui.provisionButtons = app.ui.provisionButtons or {}
    app.ui.estateActionButtons = app.ui.estateActionButtons or {}
    app.ui.rosterButtons = app.ui.rosterButtons or {}
    clearList(app.ui.skillButtons)
    clearList(app.ui.heroButtons)
    clearList(app.ui.enemyButtons)
    clearList(app.ui.itemButtons)
    clearList(app.ui.missionButtons)
    clearList(app.ui.recruitButtons)
    clearList(app.ui.provisionButtons)
    clearList(app.ui.estateActionButtons)
    clearList(app.ui.rosterButtons)
end

function Render3D.cutsceneForEvent()
    return nil
end

function Render3D.cutsceneForStatus(message, sim)
    return Render3D.cutsceneForEvent({ message = message }, sim)
end

function Render3D.idleCombatScene()
    return nil
end

function Render3D.advanceCutscene(app, dt)
    if not (app and app.cutscene) then
        return
    end
    local cutscene = app.cutscene
    cutscene.elapsed = (cutscene.elapsed or 0) + (dt or 0)
    if cutscene.elapsed >= (cutscene.duration or 0.75) then
        app.cutscene = nil
    end
end

function Render3D.rotateDelta(dx, dy, rotation)
    rotation = (rotation or 0) % 4
    if rotation == 1 then
        return -dy, dx
    end
    if rotation == 2 then
        return -dx, -dy
    end
    if rotation == 3 then
        return dy, -dx
    end
    return dx, dy
end

function Render3D.unrotateDelta(rx, ry, rotation)
    rotation = (rotation or 0) % 4
    if rotation == 1 then
        return ry, -rx
    end
    if rotation == 2 then
        return -rx, -ry
    end
    if rotation == 3 then
        return -ry, rx
    end
    return rx, ry
end

function Render3D.projectIso(view, x, y)
    local rx, ry = Render3D.rotateDelta(x - view.originX, y - view.originY, view.rotation)
    return view.centerX + (rx - ry) * view.halfW, view.centerY + (rx + ry) * view.halfH
end

function Render3D.screenToWorld(view, x, y)
    local sx = x - view.centerX
    local sy = y - view.centerY
    local rx = (sx / view.halfW + sy / view.halfH) / 2
    local ry = (sy / view.halfH - sx / view.halfW) / 2
    local dx, dy = Render3D.unrotateDelta(rx, ry, view.rotation)
    return math.floor(view.originX + dx + 0.5), math.floor(view.originY + dy + 0.5)
end

local function newSolidImage(r, g, b, a)
    local data = love.image.newImageData(1, 1)
    data:setPixel(0, 0, r, g, b, a or 1)
    local image = love.graphics.newImage(data)
    image:setFilter("nearest", "nearest")
    return image
end

local function loadImage(path)
    if not love.filesystem.getInfo(path, "file") then
        return nil
    end
    local image = love.graphics.newImage(path)
    image:setFilter("nearest", "nearest")
    return image
end

local function sortedTileIds()
    local ids = {}
    for id in pairs(Defs.tiles) do
        ids[#ids + 1] = id
    end
    table.sort(ids)
    return ids
end

local function buildTilePalette()
    tilePalette = {}
    tilePaletteOrder = sortedTileIds()
    local width = math.max(1, #tilePaletteOrder)
    local data = love.image.newImageData(width, 1)
    for index, id in ipairs(tilePaletteOrder) do
        local color = Defs.tile(id).color or { 255, 255, 255 }
        data:setPixel(index - 1, 0, color[1] / 255, color[2] / 255, color[3] / 255, 1)
        tilePalette[id] = (index - 0.5) / width
    end
    local image = love.graphics.newImage(data)
    image:setFilter("nearest", "nearest")
    return image
end

function Render3D.load()
    state.loaded = true
    state.headless = not (love and love.graphics)
    state.assets = {}
    state.g3d = nil
    state.loadError = nil
    if state.headless then
        Render3D.state = state
        return state
    end
    local ok, g3dOrErr = pcall(require, "vendor.g3d.g3d")
    if not ok then
        state.loadError = g3dOrErr
        Render3D.state = state
        return state
    end
    state.g3d = g3dOrErr
    state.assets.white = newSolidImage(1, 1, 1, 1)
    state.assets.tilePalette = buildTilePalette()
    state.assets.spriteAtlas = loadImage("assets/sprites/thoth_atlas.png")
    state.g3d.camera.updateProjectionMatrix()
    state.g3d.camera.updateViewMatrix()
    Render3D.state = state
    return state
end

local function tileVertex(x, y, z, u)
    return {x, y, z, u, 0.5, 0, 0, 1, 1, 1, 1, 1}
end

local function billboardVertex(x, y, z, u, v)
    return {x, y, z, u, v, 0, 0, 1, 1, 1, 1, 1}
end

local function pushTileQuad(vertices, x, y, z, u)
    local gap = 0.03
    local left = x + gap
    local right = x + 1 - gap
    local top = y + gap
    local bottom = y + 1 - gap
    local a = tileVertex(left, top, z, u)
    local b = tileVertex(right, top, z, u)
    local c = tileVertex(right, bottom, z, u)
    local d = tileVertex(left, bottom, z, u)
    vertices[#vertices + 1] = a
    vertices[#vertices + 1] = b
    vertices[#vertices + 1] = c
    vertices[#vertices + 1] = a
    vertices[#vertices + 1] = c
    vertices[#vertices + 1] = d
end

local function buildWorldTileModel(sim)
    local vertices = {}
    local z = sim.player.z or 0
    for y = sim.player.y - visibleRadius, sim.player.y + visibleRadius do
        for x = sim.player.x - visibleRadius, sim.player.x + visibleRadius do
            local tile = sim.world:peekTile(x, y, z)
            local u = tilePalette[tile.id] or tilePalette.archive_floor or 0.5
            pushTileQuad(vertices, x, y, z, u)
        end
    end
    local model = state.g3d.newModel(vertices, state.assets.tilePalette)
    model:makeNormals()
    return model
end

local function applyCamera(sim, app)
    local yaw = baseYaw + ((app.viewRotation or 0) % 4) * math.pi / 2
    local horizontal = math.cos(cameraPitch) * cameraDistance
    local targetX = sim.player.x + 0.5
    local targetY = sim.player.y + 0.5
    local targetZ = sim.player.z or 0
    local x = targetX + math.cos(yaw) * horizontal
    local y = targetY - math.sin(yaw) * horizontal
    local z = targetZ + math.sin(cameraPitch) * cameraDistance
    state.g3d.camera.lookAt(x, y, z, targetX, targetY, targetZ)
    state.g3d.camera.updateOrthographicMatrix(cameraViewSize)
    return yaw
end

local function atlasFrameUv(frame)
    local index = (frame or 0) % (atlasColumns * atlasRows)
    local col = index % atlasColumns
    local row = math.floor(index / atlasColumns)
    local u0 = col / atlasColumns
    local u1 = (col + 1) / atlasColumns
    local v0 = row / atlasRows
    local v1 = (row + 1) / atlasRows
    return u0, v0, u1, v1
end

local function billboardVerts(width, height, frame)
    local u0, v0, u1, v1 = atlasFrameUv(frame)
    local halfWidth = width / 2
    return {
        billboardVertex(-halfWidth, 0, 0, u0, v1),
        billboardVertex(halfWidth, 0, 0, u1, v1),
        billboardVertex(halfWidth, 0, height, u1, v0),
        billboardVertex(-halfWidth, 0, 0, u0, v1),
        billboardVertex(halfWidth, 0, height, u1, v0),
        billboardVertex(-halfWidth, 0, height, u0, v0),
    }
end

local function newBillboard(width, height, frame, x, y, z, yaw)
    local texture = state.assets.spriteAtlas or state.assets.white
    local model = state.g3d.newModel(billboardVerts(width, height, frame), texture, {x, y, z or 0})
    model:makeNormals()
    model:setRotation(0, 0, math.pi / 2 - yaw)
    return model
end

local function drawHeroBillboards(sim, yaw)
    if not (state.g3d and (state.assets.spriteAtlas or state.assets.white) and sim.partyState) then
        return
    end
    local offsets = {
        {-1.1, -0.65},
        {-0.35, -0.95},
        {0.35, -0.95},
        {1.1, -0.65},
    }
    for _, hero in ipairs(sim:partyState()) do
        if hero.alive ~= false and hero.rank and offsets[hero.rank] then
            local offset = offsets[hero.rank]
            local model = newBillboard(0.85, 1.1, 24 + hero.rank, sim.player.x + 0.5 + offset[1], sim.player.y + 0.5 + offset[2], sim.player.z or 0, yaw)
            model:draw()
        end
    end
end

function Render3D.drawWorld(sim, app)
    app.worldView = app.worldView or {}
    app.worldView.mode = "render3d-placeholder"
    app.worldView.centerX = 0
    app.worldView.centerY = 0
    app.worldView.halfW = 32
    app.worldView.halfH = 16
    app.worldView.originX = sim and sim.player and sim.player.x or 0
    app.worldView.originY = sim and sim.player and sim.player.y or 0
    app.worldView.rotation = app.viewRotation or 0
    if not (love and love.graphics and sim and sim.world and state.g3d and state.assets.tilePalette) then
        return
    end
    app.worldView.mode = "render3d"
    local yaw = applyCamera(sim, app)
    local model = buildWorldTileModel(sim)
    model:draw()
    drawHeroBillboards(sim, yaw)
end

function Render3D.drawHud()
end

function Render3D.drawSidePanel()
end

function Render3D.drawCutscene()
end

function Render3D.drawCombatStage()
end

function Render3D.drawCombatOverlay()
end

function Render3D.drawCampOverlay()
end

function Render3D.drawEstatePanel()
end

function Render3D.draw(sim, app)
    if love and love.graphics then
        love.graphics.clear(0.055, 0.058, 0.065, 1)
    end
    Render3D.prepareUi(app)
    Render3D.drawWorld(sim, app)
end

return Render3D
