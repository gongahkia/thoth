package.path = "./?.lua;./?/init.lua;./src/?.lua;./src/?/init.lua;" .. package.path

local Simulation = require("src.game.simulation")
local Input = require("src.app.input")
local Render = require("src.app.render")
local Audio = require("src.app.audio")
local Save = require("src.game.save")

local sim
local app
local fixedDt = 1 / 60
local accumulator = 0

local function hasArg(args, target)
    for _, value in ipairs(args or {}) do
        if value == target then
            return true
        end
    end
    return false
end

local function addBenchmarkLine(state, y)
    state.world:setTile(0, y, 0, { id = "iron_ore", data = 240 })
    local miner = state:addMachine("burner_miner", 0, y, "east")
    miner.inventory:add("coal", 240)
    state:addMachine("belt", 1, y, "east")
    state:addMachine("inserter", 2, y, "east")
    local furnace = state:addMachine("furnace", 3, y, "east")
    furnace.inventory:add("coal", 240)
    state:addMachine("inserter", 4, y, "east")
    state:addMachine("chest", 5, y, "south")
end

local function setupRenderBenchmark(state)
    for line = 1, 18 do
        addBenchmarkLine(state, (line - 9) * 3)
    end
end

function love.load(args)
    love.graphics.setDefaultFilter("nearest", "nearest")
    sim = Simulation.new(20260618)
    local renderBenchmark = hasArg(args, "--render-benchmark")
    if renderBenchmark then
        setupRenderBenchmark(sim)
    end
    app = {
        camera = { x = 0, y = 0, zoom = 2 },
        paused = false,
        buildDirection = "east",
        viewRotation = 0,
        status = "ready",
        audio = Audio.load(),
        moveCooldown = 0,
        smoke = hasArg(args, "--smoke"),
        smokeFrames = 0,
        renderBenchmark = renderBenchmark,
        renderBenchmarkFrames = 180,
        renderBenchmarkCount = 0,
        renderBenchmarkTotalMs = 0,
        renderBenchmarkMaxMs = 0,
    }
    Render.load()
end

function love.update(dt)
    Input.update(sim, app, dt)
    accumulator = math.min(accumulator + dt, 0.25)
    local maxSteps = love.keyboard.isDown("lshift", "rshift") and 6 or 3
    local steps = 0
    while not app.paused and accumulator >= fixedDt and steps < maxSteps do
        sim:step()
        accumulator = accumulator - fixedDt
        steps = steps + 1
    end
    if app.paused then
        accumulator = 0
    end
    if app.smoke then
        app.smokeFrames = app.smokeFrames + 1
        if app.smokeFrames >= 3 then
            love.event.quit(0)
        end
    end
end

function love.draw()
    local started = app.renderBenchmark and love.timer.getTime() or nil
    Render.draw(sim, app)
    if app.renderBenchmark then
        local elapsedMs = (love.timer.getTime() - started) * 1000
        app.renderBenchmarkCount = app.renderBenchmarkCount + 1
        app.renderBenchmarkTotalMs = app.renderBenchmarkTotalMs + elapsedMs
        app.renderBenchmarkMaxMs = math.max(app.renderBenchmarkMaxMs, elapsedMs)
        if app.renderBenchmarkCount >= app.renderBenchmarkFrames then
            print("benchmark=render")
            print("frames=" .. app.renderBenchmarkCount)
            print(string.format("avg_draw_ms=%.6f", app.renderBenchmarkTotalMs / app.renderBenchmarkCount))
            print(string.format("max_draw_ms=%.6f", app.renderBenchmarkMaxMs))
            love.event.quit(0)
        end
    end
end

function love.keypressed(key)
    if key == "f5" then
        local ok, err = Save.write(sim, "save.thoth")
        app.status = ok and "saved" or ("save failed: " .. tostring(err))
        Audio.play(app.audio, ok and "save" or "invalid")
        return
    end
    if key == "f9" then
        local loaded, err = Save.read("save.thoth")
        if loaded then
            sim = loaded
            app.status = "loaded"
            Audio.play(app.audio, "load")
        else
            app.status = "load failed: " .. tostring(err)
            Audio.play(app.audio, "invalid")
        end
        return
    end
    Input.keypressed(sim, app, key)
end

function love.mousepressed(x, y, button)
    Input.mousepressed(sim, app, x, y, button)
end
