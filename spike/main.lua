package.path = table.concat({
    "?.lua",
    "?/init.lua",
    package.path,
}, ";")

local g3d = require("g3d")
local grid
local billboards = {}
local gridSize = 20
local viewSize = 26
local cameraDistance = 28
local cameraPitch = math.rad(30)
local baseYaw = math.rad(45)
local cameraYaw = baseYaw
local targetYaw = baseYaw
local snapIndex = 1
local snapYaws = {0, math.pi / 2, math.pi, math.pi * 3 / 2}
local snapSpeed = 6
local twoPi = math.pi * 2
local verifyBillboard = false
local verifySnap = 1
local verifyCapture = false
local verifyPendingName
local verifyFps = false
local verifyFpsElapsed = 0
local verifyFpsMin = math.huge
local verifyFpsWarmup = 2
local verifyFpsDuration = 3
local verifySim = false
local simVerifyTick = 0
local simVerifyTicks = 180
local simVerifyLive
local simVerifyExpectedSnapshot
local simVerifySerialize
local simCommands
local verifySave = false
local verifySaveRan = false

local function vert(x, y, z, u, v)
    v = v or 0.5
    return {x, y, z, u, v, 0, 0, 1, 1, 1, 1, 1}
end

local function quad(out, a, b, c, d)
    out[#out + 1] = a
    out[#out + 1] = b
    out[#out + 1] = c
    out[#out + 1] = a
    out[#out + 1] = c
    out[#out + 1] = d
end

local function textureU(index, cells)
    return (index + 0.5) / cells
end

local function tileU(x, y)
    local mid = gridSize / 2
    if x == gridSize - 1 and y == mid then
        return textureU(2, 6)
    elseif x == mid and y == gridSize - 1 then
        return textureU(3, 6)
    elseif x == 0 and y == mid then
        return textureU(4, 6)
    elseif x == mid and y == 0 then
        return textureU(5, 6)
    end
    return ((x + y) % 2 == 0) and textureU(0, 6) or textureU(1, 6)
end

local function tileVerts()
    local out = {}
    local half = gridSize / 2
    for y = 0, gridSize - 1 do
        for x = 0, gridSize - 1 do
            local left = x - half
            local right = left + 0.96
            local top = y - half
            local bottom = top + 0.96
            local u = tileU(x, y)
            quad(out,
                vert(left, top, 0, u),
                vert(right, top, 0, u),
                vert(right, bottom, 0, u),
                vert(left, bottom, 0, u))
        end
    end
    return out
end

local function billboardVerts(width, height)
    local halfWidth = width / 2
    local out = {}
    quad(out,
        vert(-halfWidth, 0, 0, 0, 0.25),
        vert(halfWidth, 0, 0, 0.25, 0.25),
        vert(halfWidth, 0, height, 0.25, 0),
        vert(-halfWidth, 0, height, 0, 0))
    return out
end

local function gridTexture()
    local data = love.image.newImageData(6, 1)
    data:setPixel(0, 0, 0.34, 0.37, 0.42, 1)
    data:setPixel(1, 0, 0.48, 0.50, 0.55, 1)
    data:setPixel(2, 0, 0.82, 0.18, 0.18, 1)
    data:setPixel(3, 0, 0.20, 0.68, 0.28, 1)
    data:setPixel(4, 0, 0.20, 0.34, 0.82, 1)
    data:setPixel(5, 0, 0.86, 0.78, 0.22, 1)
    local image = love.graphics.newImage(data)
    image:setFilter("nearest", "nearest")
    return image
end

local function spriteTexture()
    local image = love.graphics.newImage("assets/george.png")
    image:setFilter("nearest", "nearest")
    return image
end

local function applyIsoCamera()
    local horizontal = math.cos(cameraPitch) * cameraDistance
    local x = math.cos(cameraYaw) * horizontal
    local y = -math.sin(cameraYaw) * horizontal
    local z = math.sin(cameraPitch) * cameraDistance
    g3d.camera.lookAt(x, y, z, 0, 0, 0)
    g3d.camera.updateOrthographicMatrix(viewSize)
end

local function faceSpriteToCamera()
    for _, billboard in ipairs(billboards) do
        billboard:setRotation(0, 0, math.pi / 2 - cameraYaw)
    end
end

local function snapCamera(delta)
    snapIndex = ((snapIndex - 1 + delta) % #snapYaws) + 1
    targetYaw = baseYaw + snapYaws[snapIndex]
end

local function stepCamera(dt)
    local diff = ((targetYaw - cameraYaw + math.pi) % twoPi) - math.pi
    local step = math.min(1, dt * snapSpeed)
    cameraYaw = cameraYaw + diff * step
    applyIsoCamera()
    faceSpriteToCamera()
end

local function loadSimulationVerifier()
    local Serialize = require("src.core.serialize")
    local Simulation = require("src.game.simulation")
    simCommands = {
        Simulation.commands.move("east"),
        Simulation.commands.move("east"),
        Simulation.commands.useItem("torch"),
        Simulation.commands.selectHero(2),
        Simulation.commands.move("east"),
        Simulation.commands.move("east"),
        Simulation.commands.move("east"),
        Simulation.commands.retreat(),
    }
    local baseline = Simulation.new(20260618)
    for tick = 1, simVerifyTicks do
        baseline:queue(simCommands[((tick - 1) % #simCommands) + 1])
        baseline:step()
    end
    simVerifyLive = Simulation.new(20260618)
    simVerifyExpectedSnapshot = Serialize.encode(baseline:snapshot())
    simVerifySerialize = Serialize
end

local function runSaveVerifier()
    local Serialize = require("src.core.serialize")
    local Simulation = require("src.game.simulation")
    local Save = require("src.game.save")
    local sim = Simulation.new(20260619)
    local commands = {
        Simulation.commands.move("east"),
        Simulation.commands.useItem("torch"),
        Simulation.commands.selectHero(2),
        Simulation.commands.move("east"),
        Simulation.commands.retreat(),
    }
    for tick = 1, 40 do
        sim:queue(commands[((tick - 1) % #commands) + 1])
        sim:step()
    end
    love.filesystem.setIdentity("thoth-spike")
    local path = "spike-save-roundtrip.thoth"
    local ok, writeErr = Save.write(sim, path)
    if not ok then
        print("save-write-error=" .. tostring(writeErr))
        love.event.quit(1)
        return
    end
    local loaded, readErr = Save.read(path)
    if not loaded then
        print("save-read-error=" .. tostring(readErr))
        love.event.quit(1)
        return
    end
    local matched = Serialize.encode(sim:snapshot()) == Serialize.encode(loaded:snapshot())
    print("save-roundtrip-path=" .. love.filesystem.getSaveDirectory() .. "/" .. path)
    print("save-roundtrip-match=" .. tostring(matched))
    love.filesystem.remove(path)
    love.event.quit(matched and 0 or 1)
end

local function addBillboard(image, x, y, width, height)
    local billboard = g3d.newModel(billboardVerts(width, height), image, {x, y, 0})
    billboard:makeNormals()
    billboards[#billboards + 1] = billboard
end

local function loadBillboards()
    local image = spriteTexture()
    local heroPositions = {
        {-1.2, -1.2},
        {1.2, -1.2},
        {-1.2, 1.2},
        {1.2, 1.2},
    }
    for _, pos in ipairs(heroPositions) do
        addBillboard(image, pos[1], pos[2], 2.4, 2.4)
    end
    for i = 1, 30 do
        local ring = 4 + (i % 5)
        local angle = (i - 1) / 30 * twoPi
        addBillboard(image, math.cos(angle) * ring, math.sin(angle) * ring, 1.7, 1.7)
    end
end

function love.load()
    for _, launchArg in ipairs(arg or {}) do
        if launchArg == "--verify-billboard" then
            verifyBillboard = true
        elseif launchArg == "--verify-fps" then
            verifyFps = true
        elseif launchArg == "--verify-sim" then
            verifySim = true
        elseif launchArg == "--verify-save" then
            verifySave = true
        end
    end
    if verifySim then
        loadSimulationVerifier()
        print("sim-verify-start ticks=" .. simVerifyTicks)
    end
    if verifyBillboard then
        love.filesystem.setIdentity("thoth-spike")
        print("verify-output=" .. love.filesystem.getSaveDirectory())
    end
    love.window.setTitle("Thoth g3d tile grid spike")
    grid = g3d.newModel(tileVerts(), gridTexture())
    grid:makeNormals()
    loadBillboards()
    applyIsoCamera()
    faceSpriteToCamera()
end

local function setSnap(index)
    snapIndex = index
    targetYaw = baseYaw + snapYaws[snapIndex]
    cameraYaw = targetYaw
    applyIsoCamera()
    faceSpriteToCamera()
end

function love.update(dt)
    if verifyBillboard then
        if not verifyCapture then
            setSnap(verifySnap)
            verifyPendingName = "billboard-snap-" .. verifySnap .. ".png"
            verifyCapture = true
        end
        return
    end
    stepCamera(dt)
    if verifySave and not verifySaveRan then
        verifySaveRan = true
        runSaveVerifier()
        return
    end
    if verifySim then
        simVerifyTick = simVerifyTick + 1
        simVerifyLive:queue(simCommands[((simVerifyTick - 1) % #simCommands) + 1])
        simVerifyLive:step()
        if simVerifyTick >= simVerifyTicks then
            local actual = simVerifySerialize.encode(simVerifyLive:snapshot())
            local matched = actual == simVerifyExpectedSnapshot
            print("sim-verify-ticks=" .. simVerifyTick)
            print("sim-verify-match=" .. tostring(matched))
            love.event.quit(matched and 0 or 1)
        end
    end
    if verifyFps then
        verifyFpsElapsed = verifyFpsElapsed + dt
        if verifyFpsElapsed >= verifyFpsWarmup then
            local fps = love.timer.getFPS()
            if fps > 0 then
                verifyFpsMin = math.min(verifyFpsMin, fps)
            end
        end
        if verifyFpsElapsed >= verifyFpsWarmup + verifyFpsDuration then
            print("fps-min=" .. tostring(verifyFpsMin))
            love.event.quit(verifyFpsMin >= 60 and 0 or 1)
        end
    end
    if love.keyboard.isDown("escape") then
        love.event.push("quit")
    end
end

function love.keypressed(key)
    if key == "q" then
        snapCamera(-1)
    elseif key == "e" then
        snapCamera(1)
    end
end

function love.draw()
    grid:draw()
    for _, billboard in ipairs(billboards) do
        billboard:draw()
    end
    love.graphics.setDepthMode()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("q/e rotate snap " .. snapIndex .. "/4 34 billboards fps " .. love.timer.getFPS(), 16, 16)
    love.graphics.setDepthMode("lequal", true)
    if verifyPendingName then
        local name = verifyPendingName
        verifyPendingName = nil
        love.graphics.captureScreenshot(function(data)
            data:encode("png", name)
            print("captured " .. name)
            verifySnap = verifySnap + 1
            verifyCapture = false
            if verifySnap > #snapYaws then
                love.event.push("quit")
            end
        end)
    end
end

function love.resize(width, height)
    g3d.camera.resize(width, height)
    applyIsoCamera()
end
