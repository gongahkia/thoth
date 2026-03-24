local thoth = require("thoth")

local showcase = {}

function showcase.run()
    local runtime = thoth.game.runtime.new(thoth.adapters.contract.nullAdapter(), {
        fixedDelta = 0.1,
        maxFrameDelta = 1,
    })

    local gameplay = runtime:use("gameplay", thoth.addons.gameplay, {
        resources = {
            energy = {current = 1, max = 5},
        },
        commandHandlers = {
            recharge = function(payload, context)
                context.gameplay.resources:add("energy", payload.amount)
            end,
        },
    })

    gameplay.cooldowns:start("dash", 0.2)
    gameplay.status:apply("focus", 0.3, {
        tags = {"buff"},
    })
    gameplay.commands:enqueue("recharge", {amount = 1})
    gameplay.commands:schedule("recharge", 0.2, {amount = 2})

    runtime:update(0.1)
    runtime:update(0.1)

    return {
        energy = gameplay.resources:current("energy"),
        dashReady = gameplay.cooldowns:ready("dash"),
        focusActive = gameplay.status:has("focus"),
        queuedCommands = #gameplay.commands:inspect(),
    }
end

return showcase
