package.path = table.concat({
    "?.lua",
    "?/init.lua",
    package.path,
}, ";")

local g3d = require("g3d")
local grid
local sprite
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

local function spriteVerts()
    local out = {}
    quad(out,
        vert(-0.45, 0, 0, 0.25),
        vert(0.45, 0, 0, 0.25),
        vert(0.45, 0, 1.35, 0.25),
        vert(-0.45, 0, 1.35, 0.25))
    return out
end

local function gridTexture()
    local data = love.image.newImageData(2, 1)
    data:setPixel(0, 0, 0.34, 0.37, 0.42, 1)
    data:setPixel(1, 0, 0.48, 0.50, 0.55, 1)
    local image = love.graphics.newImage(data)
    image:setFilter("nearest", "nearest")
    return image
end

local function spriteTexture()
    local data = love.image.newImageData(1, 1)
    data:setPixel(0, 0, 0.78, 0.30, 0.22, 1)
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

local function faceSpriteToCamera()
    if sprite then
        sprite:setRotation(0, 0, math.pi / 2 - cameraYaw)
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

function love.load()
    love.window.setTitle("Thoth g3d tile grid spike")
    grid = g3d.newModel(tileVerts(), gridTexture())
    grid:makeNormals()
    sprite = g3d.newModel(spriteVerts(), spriteTexture(), {0, 0, 0})
    sprite:makeNormals()
    applyIsoCamera()
    faceSpriteToCamera()
end

function love.update(dt)
    stepCamera(dt)
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
    sprite:draw()
    love.graphics.setDepthMode()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("q/e rotate snap " .. snapIndex .. "/4 billboard", 16, 16)
    love.graphics.setDepthMode("lequal", true)
end

function love.resize(width, height)
    g3d.camera.resize(width, height)
    applyIsoCamera()
end
