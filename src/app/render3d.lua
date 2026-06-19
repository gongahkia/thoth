local Defs = require("src.game.defs")

local Render3D = {}
local state = {
    loaded = false,
    headless = false,
    g3d = nil,
    assets = {},
}
local cameraPitch = math.rad(30)
local cameraDistance = 26
local cameraViewSize = 24
local baseYaw = math.rad(45)
local visibleRadius = 10
local atlasColumns = 8
local atlasRows = 5

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

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

local function newImageFromData(data)
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
    state.assets.enemy = newSolidImage(0.68, 0.16, 0.18, 1)
    state.assets.alpha = newSolidImage(0.58, 0.12, 0.46, 1)
    state.assets.boss = newSolidImage(0.82, 0.22, 0.12, 1)
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

local function torchLevel(sim)
    if sim and sim.expedition and sim.expedition.torch then
        return clamp(sim.expedition.torch, 0, 100)
    end
    return 100
end

local function lightProfile(sim)
    local torch = torchLevel(sim)
    local ratio = torch / 100
    return {
        torch = torch,
        ambient = 0.2 + ratio * 0.38,
        radius = 3.5 + ratio * 9.5,
    }
end

local function lightAt(sim, x, y, profile)
    if not (sim and sim.player) then
        return 1
    end
    profile = profile or lightProfile(sim)
    local dx = x - sim.player.x
    local dy = y - sim.player.y
    local distance = math.sqrt(dx * dx + dy * dy)
    local falloff = 1 - clamp(distance / profile.radius, 0, 1)
    falloff = falloff * falloff * (3 - 2 * falloff)
    return clamp(profile.ambient + falloff * (1 - profile.ambient), 0, 1)
end

local function litTileColor(rgb, light)
    local r = clamp((rgb[1] / 255) * light * 1.08, 0, 1)
    local g = clamp((rgb[2] / 255) * light * (0.9 + light * 0.1), 0, 1)
    local b = clamp((rgb[3] / 255) * light * (0.78 + light * 0.22), 0, 1)
    return r, g, b, 1
end

local function buildWorldTileModel(sim, profile)
    local vertices = {}
    local z = sim.player.z or 0
    local minX = sim.player.x - visibleRadius
    local maxX = sim.player.x + visibleRadius
    local minY = sim.player.y - visibleRadius
    local maxY = sim.player.y + visibleRadius
    local width = maxX - minX + 1
    local height = maxY - minY + 1
    local data = love.image.newImageData(width * height, 1)
    local index = 0
    for y = minY, maxY do
        for x = minX, maxX do
            index = index + 1
            local tile = sim.world:peekTile(x, y, z)
            local rgb = Defs.tile(tile.id).color or { 255, 255, 255 }
            local light = lightAt(sim, x, y, profile)
            data:setPixel(index - 1, 0, litTileColor(rgb, light))
            local u = (index - 0.5) / (width * height)
            pushTileQuad(vertices, x, y, z, u)
        end
    end
    local model = state.g3d.newModel(vertices, newImageFromData(data))
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

local function newBillboard(width, height, frame, x, y, z, yaw, texture)
    texture = texture or state.assets.spriteAtlas or state.assets.white
    local model = state.g3d.newModel(billboardVerts(width, height, frame), texture, {x, y, z or 0})
    model:makeNormals()
    model:setRotation(0, 0, math.pi / 2 - yaw)
    return model
end

local function drawLitModel(model, light)
    love.graphics.push("all")
    love.graphics.setColor(light, light, light, 1)
    model:draw()
    love.graphics.pop()
end

local function drawHeroBillboards(sim, yaw, profile)
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
            local x = sim.player.x + 0.5 + offset[1]
            local y = sim.player.y + 0.5 + offset[2]
            local model = newBillboard(0.85, 1.1, 24 + hero.rank, x, y, sim.player.z or 0, yaw)
            drawLitModel(model, lightAt(sim, x, y, profile))
        end
    end
end

local function enemyFrame(objectType)
    if objectType == "boss" then
        return 36
    end
    if objectType == "alpha" then
        return 35
    end
    if objectType == "encounter" then
        return 34
    end
    return 33
end

local function hasRole(def, role)
    for _, candidate in ipairs(def.roles or {}) do
        if candidate == role then
            return true
        end
    end
    return false
end

local function combatEnemyType(enemy)
    local def = Defs.enemy(enemy and enemy.kind) or {}
    if def.boss or hasRole(def, "boss") then
        return "boss"
    end
    if def.alpha or hasRole(def, "alpha") then
        return "alpha"
    end
    return "threat"
end

local function enemyTexture(objectType)
    if objectType == "boss" then
        return state.assets.boss or state.assets.enemy
    end
    if objectType == "alpha" then
        return state.assets.alpha or state.assets.enemy
    end
    return state.assets.enemy or state.assets.white
end

local function enemySize(objectType)
    if objectType == "boss" then
        return 1.2, 1.45
    end
    if objectType == "alpha" then
        return 1.08, 1.3
    end
    return 0.95, 1.15
end

local function drawCombatEnemyBillboards(sim, yaw, profile)
    if not (sim.combat and sim.combat.enemies) then
        return false
    end
    local offsets = {
        {-1.35, 1.7},
        {-0.45, 2.0},
        {0.45, 2.0},
        {1.35, 1.7},
    }
    for _, enemy in ipairs(sim.combat.enemies) do
        if enemy.hp > 0 and enemy.rank and offsets[enemy.rank] then
            local offset = offsets[enemy.rank]
            local objectType = combatEnemyType(enemy)
            local width, height = enemySize(objectType)
            local x = sim.player.x + 0.5 + offset[1]
            local y = sim.player.y + 0.5 + offset[2]
            local model = newBillboard(width, height, enemyFrame(objectType), x, y, sim.player.z or 0, yaw, enemyTexture(objectType))
            drawLitModel(model, lightAt(sim, x, y, profile))
        end
    end
    return true
end

local function isEnemyObject(object)
    return object.type == "threat" or object.type == "alpha" or object.type == "encounter" or object.type == "boss"
end

local function drawWorldEnemyBillboards(sim, yaw, profile)
    if not sim.objectsInRect then
        return
    end
    local minX = sim.player.x - visibleRadius
    local maxX = sim.player.x + visibleRadius
    local minY = sim.player.y - visibleRadius
    local maxY = sim.player.y + visibleRadius
    for _, object in ipairs(sim:objectsInRect(minX, maxX, minY, maxY, sim.player.z or 0)) do
        if isEnemyObject(object) then
            local width, height = enemySize(object.type)
            local model = newBillboard(width, height, enemyFrame(object.type), object.x + 0.5, object.y + 0.5, object.z or 0, yaw, enemyTexture(object.type))
            drawLitModel(model, lightAt(sim, object.x, object.y, profile))
        end
    end
end

local function drawEnemyBillboards(sim, yaw, profile)
    if not (state.g3d and (state.assets.spriteAtlas or state.assets.white)) then
        return
    end
    if not drawCombatEnemyBillboards(sim, yaw, profile) then
        drawWorldEnemyBillboards(sim, yaw, profile)
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
    if not (love and love.graphics and sim and sim.world and state.g3d) then
        return
    end
    app.worldView.mode = "render3d"
    local profile = lightProfile(sim)
    app.worldView.light = { torch = profile.torch, ambient = profile.ambient, radius = profile.radius }
    local yaw = applyCamera(sim, app)
    local model = buildWorldTileModel(sim, profile)
    love.graphics.setColor(1, 1, 1, 1)
    model:draw()
    drawHeroBillboards(sim, yaw, profile)
    drawEnemyBillboards(sim, yaw, profile)
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
