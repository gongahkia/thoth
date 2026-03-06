local runtimeModule = require("thoth.game.runtime")
local defoldAdapter = require("thoth.adapters.defold")
local scene = require("examples.shared.movement_scene")

local M = {}

function M.new()
    local adapter = defoldAdapter.new()
    local runtime = runtimeModule.new(adapter)
    local player = scene.attach(runtime, runtime.input)
    local hooks = adapter:registerLifecycle(runtime)

    return {
        update = hooks.update,
        on_input = hooks.on_input,
        draw = hooks.draw,
        get_player = function()
            return player
        end
    }
end

return M
