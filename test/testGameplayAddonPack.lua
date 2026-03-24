local gameplay = require("thoth.addons.gameplay")
local runtimeModule = require("thoth.game.runtime")
local contract = require("thoth.adapters.contract")

local executed = 0
local runtime = runtimeModule.new(contract.nullAdapter(), {
    fixedDelta = 0.1,
    maxFrameDelta = 1,
})

local handle = runtime:use("gameplay", gameplay, {
    resources = {
        energy = {current = 3, max = 5},
    },
    commandHandlers = {
        award_energy = function(payload, context)
            executed = executed + 1
            context.gameplay.resources:add("energy", payload.amount)
        end,
    },
})

assert(handle == runtime:getExtension("gameplay"), "Runtime should expose the installed gameplay extension handle")
assert(handle.resources:current("energy") == 3)

handle.cooldowns:start("dash", 0.2)
handle.status:apply("poison", 0.2, {
    tags = {"damage"},
})
handle.commands:enqueue("award_energy", {amount = 1})
handle.commands:schedule("award_energy", 0.2, {amount = 2})

runtime:update(0.1)

assert(handle.resources:current("energy") == 4, "Immediate queued commands should execute on the next fixed step")
assert(math.abs(handle.cooldowns:remaining("dash") - 0.1) < 1e-9)
assert(handle.status:has("poison"))

local snapshot = runtime:snapshot()
assert(snapshot.extensions.gameplay.resources.energy.current == 4, "Runtime snapshots should include gameplay extension state")

handle.resources:add("energy", -4)
runtime:update(0.1)
assert(handle.resources:current("energy") == 2, "Delayed commands should execute during later fixed steps")
assert(handle.cooldowns:ready("dash"))
assert(not handle.status:has("poison"))

runtime:restore(snapshot)
assert(handle.resources:current("energy") == 4, "Restore should restore gameplay resources")
assert(math.abs(handle.cooldowns:remaining("dash") - 0.1) < 1e-9, "Restore should restore gameplay cooldowns")
assert(handle.status:has("poison"), "Restore should restore gameplay statuses")

runtime:update(0.1)
assert(handle.resources:current("energy") == 5, "Restored delayed commands should execute after restore")
assert(executed == 3, "Command handlers should execute deterministically across replayed gameplay state")
