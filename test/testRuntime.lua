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
