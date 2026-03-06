local runtimeModule = require("thoth.game.runtime")
local love2dAdapter = require("thoth.adapters.love2d")
local scene = require("examples.shared.movement_scene")

local adapter = love2dAdapter.new(love)
local runtime = runtimeModule.new(adapter)
local player = scene.attach(runtime, runtime.input)
local hooks = adapter:registerLifecycle(runtime)

function love.update(dt)
    hooks.update(dt)
end

function love.draw()
    hooks.draw()
    love.graphics.print(("x=%.2f y=%.2f"):format(player.x, player.y), 10, 10)
end

function love.keypressed(key)
    hooks.keypressed(key)
end

function love.keyreleased(key)
    hooks.keyreleased(key)
end
