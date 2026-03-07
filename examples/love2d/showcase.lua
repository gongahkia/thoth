local runtimeModule = require("thoth.game.runtime")
local love2dAdapter = require("thoth.adapters.love2d")
local showcase = require("examples.shared.showcase_game")

local M = {}

function M.new(loveEnv)
    local adapter = love2dAdapter.new(loveEnv or love)
    local runtime = runtimeModule.new(adapter, {fixedDelta = 1 / 6})
    local game = showcase.attach(runtime)
    local hooks = adapter:registerLifecycle(runtime)

    local drawContext = adapter.love or loveEnv or love

    return {
        update = hooks.update,
        draw = function(...)
            hooks.draw(...)
            if drawContext and drawContext.graphics and type(drawContext.graphics.print) == "function" then
                local lines = game:renderLines()
                for i, line in ipairs(lines) do
                    drawContext.graphics.print(line, 10, 10 + ((i - 1) * 14))
                end
                if game:getWorld().debug then
                    runtime:drawDebugHud(function(text, x, y)
                        drawContext.graphics.print(text, x, y)
                    end, 220, 10, 14)
                end
            end
        end,
        keypressed = hooks.keypressed,
        keyreleased = hooks.keyreleased,
        gamepadpressed = hooks.gamepadpressed,
        gamepadreleased = hooks.gamepadreleased,
        touchpressed = hooks.touchpressed,
        touchreleased = hooks.touchreleased,
        textinput = hooks.textinput,
        get_game = function()
            return game
        end,
    }
end

return M
