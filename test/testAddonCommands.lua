local commands = require("thoth.addons.gameplay.commands")

local executed = {}
local manager = commands.new({
    move = function(payload, context, entry)
        executed[#executed + 1] = {
            name = entry.name,
            x = payload.x,
            y = context.y,
        }
    end,
})

local immediateId = manager:enqueue("move", {x = 1})
local delayedId = manager:schedule("move", 0.5, {x = 2})
local cancelledId = manager:schedule("move", 1.0, {x = 3})

local inspected = manager:inspect()
assert(#inspected == 3, "Inspect should expose queued commands")
assert(inspected[1].id == immediateId and inspected[2].id == delayedId and inspected[3].id == cancelledId)

assert(manager:cancel(cancelledId), "Cancel should remove a queued command")

local context = {y = 9}
local ran = manager:update(0.25, context)
assert(#ran == 1 and ran[1].id == immediateId, "Zero-delay commands should execute on the next update")
assert(#executed == 1 and executed[1].x == 1 and executed[1].y == 9)

local snapshot = manager:snapshot()
manager:update(0.25, context)
assert(#executed == 2 and executed[2].x == 2, "Scheduled commands should execute once their delay elapses")

manager:restore(snapshot)
executed = {}
manager:update(0.25, context)
assert(#executed == 1 and executed[1].x == 2, "Restore should restore queued command state")
