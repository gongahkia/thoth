package.path = "./?.lua;./?/init.lua;./src/?.lua;./src/?/init.lua;" .. package.path

local Player = require("src.player")
local Render = require("src.render")
local Survey = require("src.survey")
local ViewScale = require("src.viewscale")
local WorldGen = require("src.worldgen")

local app
local terrainPreloadPadding = 0
local billboardPreloadPadding = 0
local preloadStride = 64
local maxSimDt = 1 / 30

local function now()
    return love.timer and love.timer.getTime and love.timer.getTime() or os.clock()
end

local function msSince(startTime)
    return (now() - startTime) * 1000
end

local function flag(value)
    return value and "1" or "0"
end

local function perfLine(app, message)
    if app and app.debugPerf then print("[perf] " .. message) end
end

local function frustumRadius(app)
    local renderRadius = app.camera.renderRadius or 62
    return math.ceil(math.sqrt(renderRadius * renderRadius + (renderRadius * 0.82) * (renderRadius * 0.82)))
end

local function chunkRange(app, radius, scaleId)
    local size = app.world:metadata().chunkSize
    local info = WorldGen.scaleInfo(scaleId)
    local minGX = math.floor((app.player.x - radius) / (info.factor or 1))
    local maxGX = math.floor((app.player.x + radius) / (info.factor or 1))
    local minGY = math.floor((app.player.y - radius) / (info.factor or 1))
    local maxGY = math.floor((app.player.y + radius) / (info.factor or 1))
    return math.floor(minGX / size),
        math.floor(maxGX / size),
        math.floor(minGY / size),
        math.floor(maxGY / size)
end

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

local function runtimeWorldOptions(args)
    return {
        hydrologyRegionChunks = tonumber(argValue(args, "--hydrology-region-chunks", 1)) or 1,
        hydrologyHaloCells = tonumber(argValue(args, "--hydrology-halo", 0)) or 0,
        hydrologyBasinChunks = tonumber(argValue(args, "--hydrology-basin-chunks", 8)) or 8,
        hydrologyBasinStride = tonumber(argValue(args, "--hydrology-basin-stride", 8)) or 8,
        hydrologyBasinHaloCells = tonumber(argValue(args, "--hydrology-basin-halo", 0)) or 0,
        hydrologyBasinFlowScale = tonumber(argValue(args, "--hydrology-basin-flow-scale", 0.6)) or 0.6,
    }
end

local function smoke(args)
    local world = WorldGen.new(tonumber(argValue(args, "--seed", 20260625)))
    local player = Player.new(0, 0)
    local renderStats = Render.visibleStats({ world = world, player = player, camera = Render.defaultCamera() }, 1280, 720)
    local totals = { land = 0, water = 0, river = 0, talus = 0, alluvial = 0, floodplain = 0, delta = 0, chunks = 0 }
    for _, scale in ipairs(world:metadata().scales) do
        for cy = -1, 1 do
            for cx = -1, 1 do
                local chunk = world:chunk(cx, cy, scale.id)
                totals.chunks = totals.chunks + 1
                for _, row in ipairs(chunk.cells) do
                    for _, cell in ipairs(row) do
                        if cell.water then totals.water = totals.water + 1 else totals.land = totals.land + 1 end
                        if cell.river then totals.river = totals.river + 1 end
                        if cell.talus then totals.talus = totals.talus + 1 end
                        if cell.alluvialFan then totals.alluvial = totals.alluvial + 1 end
                        if cell.floodplain then totals.floodplain = totals.floodplain + 1 end
                        if cell.delta then totals.delta = totals.delta + 1 end
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
    print("talus=" .. totals.talus)
    print("alluvial_fans=" .. totals.alluvial)
    print("floodplains=" .. totals.floodplain)
    print("deltas=" .. totals.delta)
    print("mesh_tiles=" .. renderStats.visibleTiles)
    print("triangles=" .. renderStats.triangles)
    print("river_strips=" .. renderStats.riverStrips)
    print("silhouettes=" .. renderStats.silhouetteStrips)
    print("billboards=" .. renderStats.billboards)
    print("landmarks=" .. renderStats.landmarks)
    print("camera_height=" .. string.format("%.3f", renderStats.cameraHeight))
    love.event.quit(0)
end

local function preloadApp(app, reason)
    local started = now()
    local view = ViewScale.params(app.viewScale, app.world)
    local viewRadius = frustumRadius(app)
    local configuredRadius = (reason == "load" or reason == "seed_reset") and app.preloadRadius or app.refreshPreloadRadius
    local terrainRadius = math.max(viewRadius * view.factor + terrainPreloadPadding, (configuredRadius or 0) * view.factor)
    local billboardRadius = math.max(viewRadius + billboardPreloadPadding, configuredRadius or 0)
    local terrainChunks = 0
    for _, scaleId in ipairs(ViewScale.preloadScales(app.viewScale)) do
        terrainChunks = terrainChunks + app.world:preloadAround(app.player.x, app.player.y, terrainRadius, scaleId)
    end
    local billboardChunks = view.factor <= 2.1 and app.world:preloadBillboardsAround(app.player.x, app.player.y, billboardRadius) or 0
    local size = app.world:metadata().chunkSize
    app.preloadedChunkX = math.floor(app.player.x / size)
    app.preloadedChunkY = math.floor(app.player.y / size)
    app.preloadedBandX = math.floor(app.player.x / preloadStride)
    app.preloadedBandY = math.floor(app.player.y / preloadStride)
    app.preloadedScale = view.target
    app.preloadedMinChunkX, app.preloadedMaxChunkX, app.preloadedMinChunkY, app.preloadedMaxChunkY = chunkRange(app, terrainRadius, view.target)
    local elapsed = msSince(started)
    if app.perf then app.perf.preloadMsThisFrame = (app.perf.preloadMsThisFrame or 0) + elapsed end
    perfLine(app, string.format(
        "preload reason=%s scale=%s factor=%.2f ms=%.2f terrain_chunks=%d billboard_chunks=%d terrain_radius=%.0f billboard_radius=%.0f chunk=%d,%d band=%d,%d",
        reason or "manual",
        view.target,
        view.factor,
        elapsed,
        terrainChunks,
        billboardChunks,
        terrainRadius,
        billboardRadius,
        app.preloadedChunkX,
        app.preloadedChunkY,
        app.preloadedBandX,
        app.preloadedBandY
    ))
end

local function refreshPreloadIfNeeded(app)
    local view = ViewScale.params(app.viewScale, app.world)
    local size = app.world:metadata().chunkSize
    local chunkX = math.floor(app.player.x / size)
    local chunkY = math.floor(app.player.y / size)
    local minChunkX, maxChunkX, minChunkY, maxChunkY = chunkRange(app, frustumRadius(app) * view.factor, view.target)
    if app.preloadedScale == view.target and app.preloadedMinChunkX and minChunkX >= app.preloadedMinChunkX and maxChunkX <= app.preloadedMaxChunkX and minChunkY >= app.preloadedMinChunkY and maxChunkY <= app.preloadedMaxChunkY then return end
    perfLine(app, string.format("preload_due scale=%s pos=%.2f,%.2f chunk=%d,%d visible_chunks=%d..%d,%d..%d loaded_chunks=%s..%s,%s..%s",
        view.target,
        app.player.x,
        app.player.y,
        chunkX,
        chunkY,
        minChunkX,
        maxChunkX,
        minChunkY,
        maxChunkY,
        tostring(app.preloadedMinChunkX),
        tostring(app.preloadedMaxChunkX),
        tostring(app.preloadedMinChunkY),
        tostring(app.preloadedMaxChunkY)
    ))
    preloadApp(app, "range")
end

local function perfSnapshot(app)
    local cache = app.world:cacheStats()
    local metrics = app.world:metricsSnapshot()
    local size = app.world:metadata().chunkSize
    local chunkX = math.floor(app.player.x / size)
    local chunkY = math.floor(app.player.y / size)
    local stats = app.perf.renderStats or {}
    local view = ViewScale.params(app.viewScale, app.world)
    return string.format(
        "frame=%d fps=%d dt=%.2fms sim_dt=%.2fms update=%.2fms draw=%.2fms preload=%.2fms scale=%s factor=%.2f pos=%.2f,%.2f chunk=%d,%d band=%d,%d yaw=%.3f pitch=%.3f moving=%s sprint=%s mesh=%s tris=%s billboards=%s rivers=%s silhouettes=%s landmarks=%s cache=%d chunks=%d hydro=%d basins=%d billboard_cache=%d misses=c%d/h%d/m%d/b%d cells=h%d/m%d",
        app.perf.frame or 0,
        love.timer.getFPS(),
        (app.perf.lastDt or 0) * 1000,
        (app.perf.simDt or 0) * 1000,
        app.perf.updateMs or 0,
        app.perf.drawMs or 0,
        app.perf.preloadMsThisFrame or 0,
        view.target,
        view.factor,
        app.player.x,
        app.player.y,
        chunkX,
        chunkY,
        math.floor(app.player.x / preloadStride),
        math.floor(app.player.y / preloadStride),
        app.camera.yaw or 0,
        app.camera.pitch or 0,
        flag(app.perf.moving),
        flag(app.perf.sprint),
        tostring(stats.visibleTiles),
        tostring(stats.triangles),
        tostring(stats.billboards),
        tostring(stats.riverStrips),
        tostring(stats.silhouetteStrips),
        tostring(stats.landmarks),
        cache.total,
        cache.chunks,
        cache.hydrology,
        cache.basins,
        cache.billboards,
        metrics.chunkMisses,
        metrics.hydrologyMisses,
        metrics.basinMisses,
        metrics.billboardMisses,
        metrics.hydrologyCells,
        metrics.basinCells
    )
end

local function maybeLogPerf(app)
    if not app.debugPerf then return end
    local time = now()
    local interval = app.perf.interval or 1
    local slowMs = app.perf.slowFrameMs or 24
    local dtMs = (app.perf.lastDt or 0) * 1000
    local slow = dtMs > slowMs or (app.perf.updateMs or 0) > slowMs or (app.perf.drawMs or 0) > slowMs or (app.perf.preloadMsThisFrame or 0) > slowMs
    if slow or time - (app.perf.lastLogAt or 0) >= interval then
        app.perf.lastLogAt = time
        perfLine(app, (slow and "slow " or "tick ") .. perfSnapshot(app))
    end
end

function love.load(args)
    if hasArg(args, "--smoke") then
        smoke(args)
        return
    end
    love.graphics.setDefaultFilter("nearest", "nearest")
    app = {
        world = WorldGen.new(tonumber(argValue(args, "--seed", 20260625)), runtimeWorldOptions(args)),
        worldOptions = runtimeWorldOptions(args),
        survey = Survey.new(),
        viewScale = nil,
        player = Player.new(0, 0),
        camera = Render.defaultCamera(),
        paused = false,
        mouseLook = true,
        renderSmoke = hasArg(args, "--render-smoke"),
        walkSmoke = hasArg(args, "--walk-smoke"),
        walkSmokeFrames = tonumber(argValue(args, "--walk-smoke-frames", 240)) or 240,
        walkSmokeTurn = tonumber(argValue(args, "--walk-smoke-turn", 0.18)) or 0.18,
        preloadRadius = tonumber(argValue(args, "--preload-radius", 64)) or 64,
        refreshPreloadRadius = tonumber(argValue(args, "--refresh-preload-radius", 72)) or 72,
        debugPerf = hasArg(args, "--debug-perf") or hasArg(args, "--log-fps") or hasArg(args, "--walk-smoke"),
    }
    app.viewScale = ViewScale.new(app.world)
    ViewScale.update(app.viewScale, 0, app.world, app.player.x, app.player.y)
    app.perf = {
        frame = 0,
        interval = tonumber(argValue(args, "--perf-interval", 1)) or 1,
        slowFrameMs = tonumber(argValue(args, "--slow-frame-ms", 24)) or 24,
        lastLogAt = now(),
    }
    perfLine(app, string.format("load seed=%s scale=%s render_radius=%d preload_radius=%d refresh_radius=%d preload_stride=%d hydrology_regions=%d hydrology_halo=%d basin_chunks=%d basin_stride=%d slow_ms=%.1f interval=%.2f",
        tostring(app.world:metadata().seed),
        ViewScale.activeScale(app.viewScale),
        app.camera.renderRadius or 0,
        app.preloadRadius,
        app.refreshPreloadRadius,
        preloadStride,
        app.world:metadata().hydrologyRegionChunks or 0,
        app.world:metadata().hydrologyHaloCells or 0,
        app.world:metadata().hydrologyBasinChunks or 0,
        app.world:metadata().hydrologyBasinStride or 0,
        app.perf.slowFrameMs,
        app.perf.interval
    ))
    preloadApp(app, "load")
    if love.mouse and love.mouse.setRelativeMode then love.mouse.setRelativeMode(true) end
end

function love.update(dt)
    if not app then return end
    local started = now()
    app.perf.preloadMsThisFrame = 0
    app.perf.lastDt = dt
    local simDt = math.min(dt, maxSimDt)
    app.perf.simDt = simDt
    local turn = (love.keyboard.isDown("e", "right") and 1 or 0) - (love.keyboard.isDown("q", "left") and 1 or 0)
    local pitch = (love.keyboard.isDown("down") and 1 or 0) - (love.keyboard.isDown("up") and 1 or 0)
    if app.walkSmoke then turn = app.walkSmokeTurn end
    app.camera.yaw = app.camera.yaw + turn * simDt * 1.9
    app.camera.pitch = math.max(-0.42, math.min(0.38, app.camera.pitch + pitch * simDt * 0.85))
    local input = {
        forward = app.walkSmoke or love.keyboard.isDown("w"),
        back = love.keyboard.isDown("s"),
        left = love.keyboard.isDown("a", "left"),
        right = love.keyboard.isDown("d", "right"),
        sprint = app.walkSmoke and true or love.keyboard.isDown("lshift", "rshift"),
        yaw = app.camera.yaw,
    }
    app.perf.moving = input.forward or input.back or input.left or input.right
    app.perf.sprint = input.sprint
    Player.update(app.player, simDt, input, app.world)
    ViewScale.update(app.viewScale, simDt, app.world, app.player.x, app.player.y)
    refreshPreloadIfNeeded(app)
    app.camera.x = app.camera.x + (app.player.x - app.camera.x) * math.min(1, simDt * 10)
    app.camera.y = app.camera.y + (app.player.y - app.camera.y) * math.min(1, simDt * 10)
    app.perf.updateMs = msSince(started)
end

function love.draw()
    if not app then return end
    local started = now()
    local stats = Render.draw(app)
    app.perf.drawMs = msSince(started)
    app.perf.renderStats = stats
    app.perf.frame = (app.perf.frame or 0) + 1
    maybeLogPerf(app)
    if app.renderSmoke and not app.renderSmokePrinted then
        app.renderSmokePrinted = true
        print("render-smoke=terrain3d")
        print("render-smoke-tiles=" .. tostring(stats.visibleTiles))
        print("render-smoke-triangles=" .. tostring(stats.triangles))
        print("render-smoke-river-strips=" .. tostring(stats.riverStrips))
        print("render-smoke-silhouettes=" .. tostring(stats.silhouetteStrips))
        print("render-smoke-billboards=" .. tostring(stats.billboards))
        print("render-smoke-landmarks=" .. tostring(stats.landmarks))
        love.event.quit(0)
    end
    if app.walkSmoke and app.perf.frame >= app.walkSmokeFrames then
        print("walk-smoke=terrain3d")
        print("walk-smoke-frames=" .. tostring(app.perf.frame))
        print("walk-smoke-pos=" .. string.format("%.2f,%.2f", app.player.x, app.player.y))
        print("walk-smoke-final=" .. perfSnapshot(app))
        love.event.quit(0)
    end
end

function love.keypressed(key)
    if not app then return end
    if key == "escape" then love.event.quit(0) end
    if app.walkSmoke then return end
    if key == "f" then
        app.mouseLook = not app.mouseLook
        if love.mouse and love.mouse.setRelativeMode then love.mouse.setRelativeMode(app.mouseLook) end
    end
    if key == "l" then
        app.debugPerf = not app.debugPerf
        print("[perf] debug=" .. tostring(app.debugPerf))
    end
    if key == "m" then
        Survey.mark(app.survey, app.world, app.player.x, app.player.y, ViewScale.activeScale(app.viewScale))
        print("[survey] cells=" .. tostring(app.survey.cellCount) .. " discoveries=" .. tostring(app.survey.discoveryCount))
    end
    if key == "tab" then
        local scale = ViewScale.shift(app.viewScale, app.world, 1, app.player.x, app.player.y)
        print("[scale] " .. tostring(scale))
        preloadApp(app, "scale")
    end
    if key == "r" then
        app.world = WorldGen.new(os.time() % 1000000, app.worldOptions)
        app.survey = Survey.new()
        app.viewScale = ViewScale.new(app.world)
        app.player.x, app.player.y = 0, 0
        app.perf.preloadMsThisFrame = 0
        preloadApp(app, "seed_reset")
    end
end

function love.mousemoved(_, _, dx, dy)
    if not (app and app.mouseLook) or app.walkSmoke then return end
    app.camera.yaw = app.camera.yaw + dx * 0.0025
    app.camera.pitch = math.max(-0.42, math.min(0.38, app.camera.pitch - dy * 0.0018))
end
