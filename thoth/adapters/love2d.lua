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
        axes = {}
    }
    self.capabilities = {
        lifecycle = true,
        rendering = true,
        input = true
    }
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

    if self.state.keys[id] ~= nil then
        return self.state.keys[id]
    end
    return keyboardDown(self.love, id)
end

function Adapter:getAxis(binding)
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
        textinput = function(text)
            runtime:dispatchInput("textinput", text)
        end
    }
end

function love2d.new(loveEnv)
    return Adapter.new(loveEnv)
end

return love2d
