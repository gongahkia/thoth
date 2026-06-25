package.path = "./?.lua;./?/init.lua;./src/?.lua;./src/?/init.lua;" .. package.path

local Player = require("src.player")
local Render = require("src.render")
local WorldGen = require("src.worldgen")

local app

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
    love.event.quit(0)
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
        camera = { x = 0, y = 0 },
        scaleIndex = 1,
        overlayIndex = 1,
        overlays = { "biome", "plates", "uplift", "rainfall", "flow", "erosion" },
        paused = false,
    }
end

function love.update(dt)
    if not app then return end
    Player.update(app.player, dt, {
        up = love.keyboard.isDown("w", "up"),
        down = love.keyboard.isDown("s", "down"),
        left = love.keyboard.isDown("a", "left"),
        right = love.keyboard.isDown("d", "right"),
        sprint = love.keyboard.isDown("lshift", "rshift"),
    }, app.world)
    app.camera.x = app.camera.x + (app.player.x - app.camera.x) * math.min(1, dt * 10)
    app.camera.y = app.camera.y + (app.player.y - app.camera.y) * math.min(1, dt * 10)
end

function love.draw()
    if not app then return end
    Render.draw(app)
end

function love.keypressed(key)
    if not app then return end
    if key == "escape" then love.event.quit(0) end
    if key == "1" then app.scaleIndex = 1 end
    if key == "2" then app.scaleIndex = 2 end
    if key == "3" then app.scaleIndex = 3 end
    if key == "[" then app.scaleIndex = math.max(1, app.scaleIndex - 1) end
    if key == "]" then app.scaleIndex = math.min(#app.world:metadata().scales, app.scaleIndex + 1) end
    if key == "tab" then app.overlayIndex = (app.overlayIndex % #app.overlays) + 1 end
    if key == "r" then
        app.world = WorldGen.new(os.time() % 1000000)
        app.player.x, app.player.y = 0, 0
    end
end

function love.wheelmoved(_, y)
    if not app or y == 0 then return end
    app.scaleIndex = math.max(1, math.min(#app.world:metadata().scales, app.scaleIndex + (y > 0 and -1 or 1)))
end
