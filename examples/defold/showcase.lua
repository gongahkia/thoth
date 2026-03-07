local runtimeModule = require("thoth.game.runtime")
local defoldAdapter = require("thoth.adapters.defold")
local showcase = require("examples.shared.showcase_game")

local M = {}

function M.new()
    local adapter = defoldAdapter.new()
    local runtime = runtimeModule.new(adapter, {fixedDelta = 1 / 6})
    local game = showcase.attach(runtime)
    local hooks = adapter:registerLifecycle(runtime)

    return {
        update = hooks.update,
        on_input = hooks.on_input,
        draw = hooks.draw,
        get_lines = function()
            return game:renderLines()
        end,
        get_game = function()
            return game
        end,
    }
end

return M
