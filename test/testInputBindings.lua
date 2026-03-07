local input = require("thoth.game.input")
local love2d = require("thoth.adapters.love2d")
local contract = require("thoth.adapters.contract")

local adapter = love2d.new(nil)
local manager = input.new(adapter)

manager:bind("dash", {gamepadButton = "a"})
adapter.state.gamepad.buttons.a = true
manager:update()
assert(manager:down("dash"), "Gamepad button bindings should resolve through the input manager")

manager:rebind("dash", {gamepadButton = "b"})
adapter.state.gamepad.buttons.a = false
adapter.state.gamepad.buttons.b = true
manager:update()
assert(manager:down("dash"), "Rebinding should replace the old binding with the new one")

manager:bind("touch_any", {touch = true})
adapter:setTouch("finger-1", true)
manager:update()
assert(manager:down("touch_any"), "Touch bindings should resolve through the input manager")
adapter:setTouch("finger-1", false)

manager:bind("move_x", {
    gamepadAxis = "leftx",
    deadzone = 0.2,
    curve = "square",
    scale = 1,
})
adapter:setGamepadAxis("leftx", 0.5)
manager:update()
local expected = ((0.5 - 0.2) / 0.8)
expected = expected * expected
assert(math.abs(manager:axis("move_x") - expected) < 1e-9, "Axis modifiers should apply deadzone and response curve")

local file = "test_tmp_bindings.lua"
local ok, err = manager:saveBindings(file)
assert(ok, err)

local restored = input.new(contract.nullAdapter())
local profile, loadErr = restored:loadBindings(file, true)
assert(profile, loadErr)

local exported = restored:exportBindings()
assert(exported.contexts.default.dash.digital[1].kind == "gamepad")
assert(exported.contexts.default.touch_any.digital[1].kind == "touch")
assert(exported.contexts.default.move_x.axis[1].device == "gamepad")

os.remove(file)
