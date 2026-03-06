local runtimeModule = require("thoth.game.runtime")
local contract = require("thoth.adapters.contract")

local adapter = contract.nullAdapter()
local runtime = runtimeModule.new(adapter, {fixedDelta = 0.1, maxFrameDelta = 1})

runtime.input:bind("jump", "space")

local fixedCount = 0
local updateCount = 0
runtime:registerSystem({
    name = "counter",
    fixedUpdate = function(_rt, _dt)
        fixedCount = fixedCount + 1
    end,
    update = function(_rt, _dt)
        updateCount = updateCount + 1
    end
})

runtime:update(0.35)
assert(fixedCount == 3, "Expected 3 fixed updates with dt=0.35 and step=0.1")
assert(updateCount == 1, "Expected one variable update call per frame")

assert(runtime:enableSystem("counter", false))
runtime:update(0.2)
assert(fixedCount == 3, "Disabled systems should not run fixedUpdate")
assert(updateCount == 1, "Disabled systems should not run update")

assert(runtime:enableSystem("counter", true))
runtime:update(0.1)
assert(fixedCount == 4, "Re-enabled system should run again")
assert(updateCount == 2, "Re-enabled system should run variable update")

assert(runtime:enableSystem("missing-system", false) == false)
