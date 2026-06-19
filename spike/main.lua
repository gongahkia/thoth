package.path = table.concat({
    "?.lua",
    "?/init.lua",
    package.path,
}, ";")

local g3d = require("g3d")
local cube
local angle = 0

local function vert(x, y, z, u, v)
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

local function cubeVerts()
    local s = 0.5
    local p = {
        lbf = vert(-s, -s, -s, 0, 0),
        rbf = vert(s, -s, -s, 1, 0),
        rff = vert(s, s, -s, 1, 1),
        lff = vert(-s, s, -s, 0, 1),
        lbt = vert(-s, -s, s, 0, 0),
        rbt = vert(s, -s, s, 1, 0),
        rft = vert(s, s, s, 1, 1),
        lft = vert(-s, s, s, 0, 1),
    }
    local out = {}
    quad(out, p.lbf, p.rbf, p.rff, p.lff)
    quad(out, p.lbt, p.lft, p.rft, p.rbt)
    quad(out, p.lbf, p.lff, p.lft, p.lbt)
    quad(out, p.rbf, p.rbt, p.rft, p.rff)
    quad(out, p.lff, p.rff, p.rft, p.lft)
    quad(out, p.lbf, p.lbt, p.rbt, p.rbf)
    return out
end

local function texture()
    local data = love.image.newImageData(1, 1)
    data:setPixel(0, 0, 0.7, 0.8, 0.95, 1)
    return love.graphics.newImage(data)
end

function love.load()
    love.window.setTitle("Thoth g3d cube spike")
    cube = g3d.newModel(cubeVerts(), texture())
    cube:makeNormals()
    g3d.camera.lookAt(4, -6, 4, 0, 0, 0)
    g3d.camera.updateOrthographicMatrix(4)
end

function love.update(dt)
    angle = angle + dt * 0.7
    cube:setRotation(0, 0, angle)
    if love.keyboard.isDown("escape") then
        love.event.push("quit")
    end
end

function love.draw()
    cube:draw()
    love.graphics.setDepthMode()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("g3d cube spike", 16, 16)
    love.graphics.setDepthMode("lequal", true)
end

function love.resize(width, height)
    g3d.camera.resize(width, height)
    g3d.camera.updateOrthographicMatrix(4)
end
