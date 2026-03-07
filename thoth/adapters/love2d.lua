local contract = require("thoth.adapters.contract")
local love2d = {}

local function keyboardDown(env, key)
    if env and env.keyboard and type(env.keyboard.isDown) == "function" then
        return env.keyboard.isDown(key)
    end
    return false
end

local function mouseDown(env, button)
    if env and env.mouse and type(env.mouse.isDown) == "function" then
        return env.mouse.isDown(button)
    end
    return false
end

local Adapter = {}
Adapter.__index = Adapter

function Adapter.new(loveEnv)
    local self = setmetatable({}, Adapter)
    self.love = loveEnv or _G.love
    self._delta = 0
    self.state = {
        keys = {},
        mouse = {},
        axes = {},
        gamepad = {
            buttons = {},
            axes = {},
        },
        touch = {},
    }
    self.capabilities = contract.capabilities({
        clock = true,
        lifecycle = {
            supported = true,
            hooks = {"update", "draw", "keypressed", "keyreleased", "mousepressed", "mousereleased", "textinput"},
        },
        keyboard = true,
        mouse = true,
        axis = true,
        textInput = true,
        touch = true,
        gamepad = true,
        window = true,
    })
    return self
end

function Adapter:now()
    if self.love and self.love.timer and type(self.love.timer.getTime) == "function" then
        return self.love.timer.getTime()
    end
    return os.clock()
end

function Adapter:delta()
    return self._delta
end

function Adapter:isDown(binding)
    local kind = binding.kind or "key"
    local id = binding.id

    if kind == "mouse" then
        if self.state.mouse[id] ~= nil then
            return self.state.mouse[id]
        end
        return mouseDown(self.love, id)
    end

    if kind == "gamepad" then
        return self.state.gamepad.buttons[id] == true
    end

    if kind == "touch" then
        if id ~= nil then
            return self.state.touch[id] == true
        end
        return next(self.state.touch) ~= nil
    end

    if self.state.keys[id] ~= nil then
        return self.state.keys[id]
    end
    return keyboardDown(self.love, id)
end

function Adapter:getAxis(binding)
    if binding.device == "gamepad" and binding.name and self.state.gamepad.axes[binding.name] ~= nil then
        return self.state.gamepad.axes[binding.name]
    end

    if binding.name and self.state.axes[binding.name] ~= nil then
        return self.state.axes[binding.name]
    end

    local positive = binding.positive and self:isDown({kind = "key", id = binding.positive}) or false
    local negative = binding.negative and self:isDown({kind = "key", id = binding.negative}) or false
    if positive and not negative then
        return 1
    elseif negative and not positive then
        return -1
    end
    return 0
end

function Adapter:setAxis(name, value)
    self.state.axes[name] = value
end

function Adapter:setGamepadAxis(name, value)
    self.state.gamepad.axes[name] = value
end

function Adapter:setTouch(id, down)
    if down then
        self.state.touch[id] = true
    else
        self.state.touch[id] = nil
    end
end

function Adapter:getWindowSize()
    if self.love and self.love.graphics and type(self.love.graphics.getDimensions) == "function" then
        return self.love.graphics.getDimensions()
    end
    return nil, nil
end

function Adapter:registerLifecycle(runtime, _options)
    local adapter = self

    return {
        update = function(dt)
            adapter._delta = dt
            runtime:update(dt)
        end,
        draw = function(...)
            runtime:draw(...)
        end,
        keypressed = function(key)
            adapter.state.keys[key] = true
            runtime:dispatchInput("keypressed", key)
        end,
        keyreleased = function(key)
            adapter.state.keys[key] = false
            runtime:dispatchInput("keyreleased", key)
        end,
        mousepressed = function(_x, _y, button)
            adapter.state.mouse[button] = true
            runtime:dispatchInput("mousepressed", button)
        end,
        mousereleased = function(_x, _y, button)
            adapter.state.mouse[button] = false
            runtime:dispatchInput("mousereleased", button)
        end,
        gamepadpressed = function(_joystick, button)
            adapter.state.gamepad.buttons[button] = true
            runtime:dispatchInput("gamepadpressed", button)
        end,
        gamepadreleased = function(_joystick, button)
            adapter.state.gamepad.buttons[button] = false
            runtime:dispatchInput("gamepadreleased", button)
        end,
        touchpressed = function(id)
            adapter:setTouch(id, true)
            runtime:dispatchInput("touchpressed", id)
        end,
        touchreleased = function(id)
            adapter:setTouch(id, false)
            runtime:dispatchInput("touchreleased", id)
        end,
        textinput = function(text)
            runtime:dispatchInput("textinput", text)
        end
    }
end

function love2d.new(loveEnv)
    return Adapter.new(loveEnv)
end

return love2d
