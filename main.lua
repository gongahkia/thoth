package.path = "./?.lua;./?/init.lua;./src/?.lua;./src/?/init.lua;" .. package.path

local Simulation = require("src.game.simulation")
local Input = require("src.app.input")
local Render = require("src.app.render3d")
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

local function setupRenderBenchmark(state)
    state.player.x = 12
    state.player.y = 3
end

local function cueColor(cue)
    if cue == "danger" then
        return { 0.85, 0.18, 0.16 }
    end
    if cue == "victory" then
        return { 0.82, 0.66, 0.28 }
    end
    if cue == "combat" then
        return { 0.7, 0.24, 0.24 }
    end
    if cue == "loot" then
        return { 0.38, 0.72, 0.46 }
    end
    return { 0.42, 0.54, 0.76 }
end

local function startNextCutscene(state)
    if state.cutscene then
        return
    end
    local queue = state.cutsceneQueue
    if queue and #queue > 0 then
        state.cutscene = table.remove(queue, 1)
    end
end

local function playStatusCue(state, simulation)
    if simulation.status == state.lastCueStatus then
        return
    end
    state.lastCueStatus = simulation.status
    local cue = Audio.cueForStatus(simulation.status)
    if cue then
        Audio.play(state.audio, cue)
        state.eventFlash = { cue = cue, color = cueColor(cue), t = 0.45 }
    end
end

local function queueCutscenes(state, simulation)
    state.lastVisualEventId = state.lastVisualEventId or (simulation.eventSerial or 0)
    state.cutsceneQueue = state.cutsceneQueue or {}
    for _, event in ipairs(simulation.events or {}) do
        if event.id > state.lastVisualEventId then
            local cutscene = Render.cutsceneForEvent(event, simulation)
            if cutscene then
                state.cutsceneQueue[#state.cutsceneQueue + 1] = cutscene
            end
            state.lastVisualEventId = event.id
        end
    end
    startNextCutscene(state)
end

local function printRenderSmoke(state)
    if not state.renderSmoke or state.renderSmokePrinted then
        return
    end
    state.renderSmokePrinted = true
    print("render-smoke-renderer=" .. tostring(state.renderer))
    print("render-smoke-mode=" .. tostring(state.worldView and state.worldView.mode))
    print("render-smoke-rotation=" .. tostring(state.worldView and state.worldView.rotation))
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
        viewRotation = 0,
        renderer = "render3d",
        status = "ready",
        audio = Audio.load(),
        moveCooldown = 0,
        smoke = hasArg(args, "--smoke"),
        smokeFrames = 0,
        renderBenchmark = renderBenchmark,
        renderSmoke = hasArg(args, "--render-smoke"),
        renderBenchmarkFrames = 180,
        renderBenchmarkCount = 0,
        renderBenchmarkTotalMs = 0,
        renderBenchmarkMaxMs = 0,
        lastCueStatus = sim.status,
        lastVisualEventId = sim.eventSerial or 0,
        cutsceneQueue = {},
    }
    Render.load()
end

function love.update(dt)
    Input.update(sim, app, dt)
    Render.advanceCutscene(app, dt)
    startNextCutscene(app)
    if app.eventFlash then
        app.eventFlash.t = math.max(0, app.eventFlash.t - dt)
        if app.eventFlash.t <= 0 then
            app.eventFlash = nil
        end
    end
    accumulator = math.min(accumulator + dt, 0.25)
    local maxSteps = love.keyboard.isDown("lshift", "rshift") and 6 or 3
    local steps = 0
    while not app.paused and accumulator >= fixedDt and steps < maxSteps do
        sim:step()
        playStatusCue(app, sim)
        queueCutscenes(app, sim)
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
    printRenderSmoke(app)
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
            app.lastCueStatus = sim.status
            app.lastVisualEventId = sim.eventSerial or 0
            app.cutscene = nil
            app.cutsceneQueue = {}
            Audio.play(app.audio, "load")
        else
            app.status = "load failed: " .. tostring(err)
            Audio.play(app.audio, "invalid")
        end
        return
    end
    Input.keypressed(sim, app, key)
end

function love.keyreleased(key)
    Input.keyreleased(sim, app, key)
end

function love.mousepressed(x, y, button)
    Input.mousepressed(sim, app, x, y, button)
end
