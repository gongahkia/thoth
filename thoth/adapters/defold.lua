local defold = {}

local Adapter = {}
Adapter.__index = Adapter

function Adapter.new()
    local self = setmetatable({}, Adapter)
    self._delta = 0
    self.state = {
        keys = {},
        mouse = {},
        axes = {},
    }
    self.capabilities = {
        lifecycle = true,
        rendering = false,
        input = true
    }
    return self
end

function Adapter:now()
    return os.clock()
end

function Adapter:delta()
    return self._delta
end

function Adapter:isDown(binding)
    local kind = binding.kind or "key"
    local id = binding.id
    if kind == "mouse" then
        return self.state.mouse[id] == true
    end
    return self.state.keys[id] == true
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

function Adapter:onInput(actionId, action)
    action = action or {}
    local name = tostring(actionId)

    if action.value then
        self.state.axes[name] = action.value
    end

    if action.pressed then
        self.state.keys[name] = true
        self.state.mouse[name] = true
    elseif action.released then
        self.state.keys[name] = false
        self.state.mouse[name] = false
    end
end

function Adapter:registerLifecycle(runtime, _options)
    local adapter = self

    return {
        update = function(dt)
            adapter._delta = dt or 0
            runtime:update(dt)
        end,
        on_input = function(actionId, action)
            adapter:onInput(actionId, action)
            runtime:dispatchInput("on_input", actionId, action)
        end,
        on_message = function(messageId, message, sender)
            runtime:dispatchInput("on_message", messageId, message, sender)
        end,
        draw = function(...)
            runtime:draw(...)
        end
    }
end

function defold.new()
    return Adapter.new()
end

return defold
