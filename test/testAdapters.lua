local contract = require("thoth.adapters.contract")
local love2d = require("thoth.adapters.love2d")
local defold = require("thoth.adapters.defold")
local solar2d = require("thoth.adapters.solar2d")

local a1 = love2d.new(nil)
local a2 = defold.new()
local a3 = solar2d.new()
local a4 = contract.nullAdapter()

assert(contract.validate(a1))
assert(contract.validate(a2))
assert(contract.validate(a3))
assert(contract.validate(a4))

assert(contract.supports(a1, "lifecycle"))
assert(contract.supports(a1, "keyboard"))
assert(contract.supports(a1, "mouse"))
assert(contract.supports(a1, "textInput"))
assert(contract.supports(a1, "touch"))
assert(contract.supports(a1, "gamepad"))
assert(contract.supports(a1, "window"))

assert(contract.supports(a2, "lifecycle"))
assert(contract.supports(a2, "axis"))
assert(not contract.supports(a2, "textInput"))

assert(contract.supports(a3, "lifecycle"))
assert(contract.supports(a3, "keyboard"))
assert(contract.supports(a3, "touch"))
assert(not contract.supports(a3, "mouse"))

assert(contract.supports(a4, "clock"))
assert(contract.supports(a4, "axis"))
assert(not contract.supports(a4, "lifecycle"))

local hooks = a2:registerLifecycle({
    update = function() end,
    draw = function() end,
    dispatchInput = function() end,
})
assert(type(hooks.update) == "function")
assert(type(hooks.on_input) == "function")
