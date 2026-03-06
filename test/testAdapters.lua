local contract = require("thoth.adapters.contract")
local love2d = require("thoth.adapters.love2d")
local defold = require("thoth.adapters.defold")
local solar2d = require("thoth.adapters.solar2d")

local a1 = love2d.new(nil)
local a2 = defold.new()
local a3 = solar2d.new()

assert(contract.validate(a1))
assert(contract.validate(a2))
assert(contract.validate(a3))

local hooks = a2:registerLifecycle({
    update = function() end,
    draw = function() end,
    dispatchInput = function() end,
})
assert(type(hooks.update) == "function")
assert(type(hooks.on_input) == "function")
