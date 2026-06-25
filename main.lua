package.path = "./?.lua;./?/init.lua;./src/?.lua;./src/?/init.lua;" .. package.path

local Player = require("src.player")
local Render = require("src.render")
local WorldGen = require("src.worldgen")

local app
local terrainPreloadPadding = 0
local billboardPreloadPadding = 0

local function hasArg(args, value)
    for _, arg in ipairs(args or {}) do
        if arg == value then return true end
    end
    return false
end

local function argValue(args, flag, fallback)
    for index, arg in ipairs(args or {}) do
        if arg == flag then return args[index + 1] or fallback end
    end
    return fallback
end

local function smoke(args)
    local world = WorldGen.new(tonumber(argValue(args, "--seed", 20260625)))
    local player = Player.new(0, 0)
    local renderStats = Render.visibleStats({ world = world, player = player, camera = Render.defaultCamera() }, 1280, 720)
    local totals = { land = 0, water = 0, river = 0, chunks = 0 }
    for _, scale in ipairs(world:metadata().scales) do
        for cy = -1, 1 do
            for cx = -1, 1 do
                local chunk = world:chunk(cx, cy, scale.id)
                totals.chunks = totals.chunks + 1
                for _, row in ipairs(chunk.cells) do
                    for _, cell in ipairs(row) do
                        if cell.water then totals.water = totals.water + 1 else totals.land = totals.land + 1 end
                        if cell.river then totals.river = totals.river + 1 end
                    end
                end
            end
        end
    end
    print("smoke=terrain")
    print("chunks=" .. totals.chunks)
    print("land=" .. totals.land)
    print("water=" .. totals.water)
    print("rivers=" .. totals.river)
    print("mesh_tiles=" .. renderStats.visibleTiles)
    print("triangles=" .. renderStats.triangles)
    print("billboards=" .. renderStats.billboards)
    print("camera_height=" .. string.format("%.3f", renderStats.cameraHeight))
    love.event.quit(0)
end

local function preloadApp(app)
    local renderRadius = app.camera.renderRadius or 62
    local frustumRadius = math.ceil(math.sqrt(renderRadius * renderRadius + (renderRadius * 0.82) * (renderRadius * 0.82)))
    app.world:preloadAround(app.player.x, app.player.y, frustumRadius + terrainPreloadPadding, "local")
    app.world:preloadBillboardsAround(app.player.x, app.player.y, frustumRadius + billboardPreloadPadding)
    local size = app.world:metadata().chunkSize
    app.preloadedChunkX = math.floor(app.player.x / size)
    app.preloadedChunkY = math.floor(app.player.y / size)
end

local function refreshPreloadIfNeeded(app)
    local size = app.world:metadata().chunkSize
    local chunkX = math.floor(app.player.x / size)
    local chunkY = math.floor(app.player.y / size)
    if chunkX == app.preloadedChunkX and chunkY == app.preloadedChunkY then return end
    preloadApp(app)
end

function love.load(args)
    if hasArg(args, "--smoke") then
        smoke(args)
        return
    end
    love.graphics.setDefaultFilter("nearest", "nearest")
    app = {
        world = WorldGen.new(tonumber(argValue(args, "--seed", 20260625))),
        player = Player.new(0, 0),
        camera = Render.defaultCamera(),
        paused = false,
        mouseLook = true,
        renderSmoke = hasArg(args, "--render-smoke"),
    }
    preloadApp(app)
    if love.mouse and love.mouse.setRelativeMode then love.mouse.setRelativeMode(true) end
end

function love.update(dt)
    if not app then return end
    local turn = (love.keyboard.isDown("e", "right") and 1 or 0) - (love.keyboard.isDown("q", "left") and 1 or 0)
    local pitch = (love.keyboard.isDown("down") and 1 or 0) - (love.keyboard.isDown("up") and 1 or 0)
    app.camera.yaw = app.camera.yaw + turn * dt * 1.9
    app.camera.pitch = math.max(-0.42, math.min(0.38, app.camera.pitch + pitch * dt * 0.85))
    Player.update(app.player, dt, {
        forward = love.keyboard.isDown("w"),
        back = love.keyboard.isDown("s"),
        left = love.keyboard.isDown("a", "left"),
        right = love.keyboard.isDown("d", "right"),
        sprint = love.keyboard.isDown("lshift", "rshift"),
        yaw = app.camera.yaw,
    }, app.world)
    refreshPreloadIfNeeded(app)
    app.camera.x = app.camera.x + (app.player.x - app.camera.x) * math.min(1, dt * 10)
    app.camera.y = app.camera.y + (app.player.y - app.camera.y) * math.min(1, dt * 10)
end

function love.draw()
    if not app then return end
    local stats = Render.draw(app)
    if app.renderSmoke and not app.renderSmokePrinted then
        app.renderSmokePrinted = true
        print("render-smoke=terrain3d")
        print("render-smoke-tiles=" .. tostring(stats.visibleTiles))
        print("render-smoke-triangles=" .. tostring(stats.triangles))
        print("render-smoke-billboards=" .. tostring(stats.billboards))
        love.event.quit(0)
    end
end

function love.keypressed(key)
    if not app then return end
    if key == "escape" then love.event.quit(0) end
    if key == "f" then
        app.mouseLook = not app.mouseLook
        if love.mouse and love.mouse.setRelativeMode then love.mouse.setRelativeMode(app.mouseLook) end
    end
    if key == "r" then
        app.world = WorldGen.new(os.time() % 1000000)
        app.player.x, app.player.y = 0, 0
        preloadApp(app)
    end
end

function love.mousemoved(_, _, dx, dy)
    if not (app and app.mouseLook) then return end
    app.camera.yaw = app.camera.yaw - dx * 0.0025
    app.camera.pitch = math.max(-0.42, math.min(0.38, app.camera.pitch - dy * 0.0018))
end
