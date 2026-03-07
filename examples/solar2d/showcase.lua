local runtimeModule = require("thoth.game.runtime")
local solarAdapter = require("thoth.adapters.solar2d")
local showcase = require("examples.shared.showcase_game")

local M = {}

function M.new()
    local adapter = solarAdapter.new()
    local runtime = runtimeModule.new(adapter, {fixedDelta = 1 / 6})
    local game = showcase.attach(runtime)
    local hooks = adapter:registerLifecycle(runtime)

    return {
        enterFrame = hooks.enterFrame,
        key = hooks.key,
        axis = hooks.axis,
        touch = hooks.touch,
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
