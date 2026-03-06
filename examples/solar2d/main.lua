local runtimeModule = require("thoth.game.runtime")
local solarAdapter = require("thoth.adapters.solar2d")
local scene = require("examples.shared.movement_scene")

local M = {}

function M.new()
    local adapter = solarAdapter.new()
    local runtime = runtimeModule.new(adapter)
    local player = scene.attach(runtime, runtime.input)
    local hooks = adapter:registerLifecycle(runtime)

    return {
        enterFrame = hooks.enterFrame,
        key = hooks.key,
        axis = hooks.axis,
        draw = hooks.draw,
        get_player = function()
            return player
        end
    }
end

return M
