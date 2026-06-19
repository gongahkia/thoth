package.path = table.concat({
    "?.lua",
    "?/init.lua",
    package.path,
}, ";")

local g3d = require("g3d")
local grid
local gridSize = 20
local viewSize = 26
local cameraDistance = 28
local cameraPitch = math.rad(30)
local baseYaw = math.rad(45)
local cameraYaw = baseYaw
local targetYaw = baseYaw
local snapIndex = 1
local snapYaws = {0, math.pi / 2, math.pi, math.pi * 3 / 2}
local snapTimer = 0
local snapDelay = 1.6
local snapSpeed = 6
local twoPi = math.pi * 2

local function vert(x, y, z, u)
    local v = 0.5
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

local function tileVerts()
    local out = {}
    local half = gridSize / 2
    for y = 0, gridSize - 1 do
        for x = 0, gridSize - 1 do
            local left = x - half
            local right = left + 0.96
            local top = y - half
            local bottom = top + 0.96
            local u = ((x + y) % 2 == 0) and 0.25 or 0.75
            quad(out,
                vert(left, top, 0, u),
                vert(right, top, 0, u),
                vert(right, bottom, 0, u),
                vert(left, bottom, 0, u))
        end
    end
    return out
end

local function texture()
    local data = love.image.newImageData(2, 1)
    data:setPixel(0, 0, 0.34, 0.37, 0.42, 1)
    data:setPixel(1, 0, 0.48, 0.50, 0.55, 1)
    local image = love.graphics.newImage(data)
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

local function snapCamera(delta)
    snapIndex = ((snapIndex - 1 + delta) % #snapYaws) + 1
    targetYaw = baseYaw + snapYaws[snapIndex]
end

local function stepCamera(dt)
    local diff = ((targetYaw - cameraYaw + math.pi) % twoPi) - math.pi
    local step = math.min(1, dt * snapSpeed)
    cameraYaw = cameraYaw + diff * step
    applyIsoCamera()
end

function love.load()
    love.window.setTitle("Thoth g3d tile grid spike")
    grid = g3d.newModel(tileVerts(), texture())
    grid:makeNormals()
    applyIsoCamera()
end

function love.update(dt)
    snapTimer = snapTimer + dt
    if snapTimer >= snapDelay then
        snapTimer = snapTimer - snapDelay
        snapCamera(1)
    end
    stepCamera(dt)
    if love.keyboard.isDown("escape") then
        love.event.push("quit")
    end
end

function love.draw()
    grid:draw()
    love.graphics.setDepthMode()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("g3d 20x20 grid snap " .. snapIndex .. "/4", 16, 16)
    love.graphics.setDepthMode("lequal", true)
end

function love.resize(width, height)
    g3d.camera.resize(width, height)
    applyIsoCamera()
end
