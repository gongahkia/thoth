local runtimeModule = require("thoth.game.runtime")
local contract = require("thoth.adapters.contract")

local runtime = runtimeModule.new(contract.nullAdapter(), {
    fixedDelta = 0.1,
    maxFrameDelta = 1,
})

local installed = false
local restored = false

local extension = {
    install = function(rt, options)
        installed = true
        return {
            runtime = rt,
            value = options.value or 0,
        }
    end,
    snapshot = function(handle)
        return {
            value = handle.value,
        }
    end,
    restore = function(handle, _runtime, snapshot)
        restored = true
        handle.value = snapshot.value
    end,
}

local handle = runtime:use("sample", extension, {value = 12})
assert(installed, "Extension install hook should run")
assert(handle == runtime:getExtension("sample"), "Runtime should return the installed extension handle")
assert(handle.value == 12)

local snapshot = runtime:snapshot()
assert(snapshot.extensions.sample.value == 12, "Runtime snapshot should include extension-managed state")

handle.value = 99
runtime:restore(snapshot)

assert(restored, "Runtime restore should call the extension restore hook")
assert(handle.value == 12, "Runtime restore should restore extension-managed state")
