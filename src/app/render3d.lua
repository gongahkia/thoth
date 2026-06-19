local Render3D = {}
local state = {
    loaded = false,
    headless = false,
    g3d = nil,
    assets = {},
}

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
    state.assets.spriteAtlas = loadImage("assets/sprites/thoth_atlas.png")
    state.g3d.camera.updateProjectionMatrix()
    state.g3d.camera.updateViewMatrix()
    Render3D.state = state
    return state
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
