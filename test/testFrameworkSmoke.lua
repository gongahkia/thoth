local runtimeModule = require("thoth.game.runtime")
local scene = require("examples.shared.movement_scene")
local love2d = require("thoth.adapters.love2d")
local defold = require("thoth.adapters.defold")
local solar2d = require("thoth.adapters.solar2d")

local function simulate(adapter)
    local runtime = runtimeModule.new(adapter, {fixedDelta = 1 / 60})
    local player = scene.attach(runtime, runtime.input)
    runtime.input:bind("move_x", {axis = {positive = "right", negative = "left"}})

    adapter.state.keys.right = true
    runtime:update(1 / 60)
    runtime:update(1 / 60)
    adapter.state.keys.right = false

    return player.x
end

local xLove = simulate(love2d.new(nil))
local xDefold = simulate(defold.new())
local xSolar = simulate(solar2d.new())

assert(xLove > 0, "Love2D smoke test should move player")
assert(xDefold > 0, "Defold smoke test should move player")
assert(xSolar > 0, "Solar2D smoke test should move player")
