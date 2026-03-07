local contract = require("thoth.adapters.contract")
local solar2d = {}

local Adapter = {}
Adapter.__index = Adapter

function Adapter.new()
    local self = setmetatable({}, Adapter)
    self._delta = 0
    self._lastTimestamp = nil
    self.state = {
        keys = {},
        mouse = {},
        axes = {},
    }
    self.capabilities = contract.capabilities({
        clock = true,
        lifecycle = {
            supported = true,
            hooks = {"enterFrame", "key", "axis", "draw"},
        },
        keyboard = true,
        axis = true,
    })
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

function Adapter:onKeyEvent(event)
    if not event then
        return
    end
    local keyName = event.keyName or event.key or event.name
    if not keyName then
        return
    end

    local phase = event.phase
    if phase == "down" then
        self.state.keys[keyName] = true
    elseif phase == "up" then
        self.state.keys[keyName] = false
    end
end

function Adapter:onAxisEvent(event)
    if not event or not event.axis then
        return
    end
    self.state.axes[event.axis.name or event.axis.id or "axis"] = event.normalizedValue or event.value or 0
end

function Adapter:registerLifecycle(runtime, _options)
    local adapter = self

    return {
        enterFrame = function(event)
            local timestamp = event and event.time or nil
            if timestamp and adapter._lastTimestamp then
                adapter._delta = (timestamp - adapter._lastTimestamp) / 1000
            else
                adapter._delta = 1 / 60
            end
            adapter._lastTimestamp = timestamp
            runtime:update(adapter._delta)
        end,
        key = function(event)
            adapter:onKeyEvent(event)
            runtime:dispatchInput("key", event)
        end,
        axis = function(event)
            adapter:onAxisEvent(event)
            runtime:dispatchInput("axis", event)
        end,
        draw = function(...)
            runtime:draw(...)
        end
    }
end

function solar2d.new()
    return Adapter.new()
end

return solar2d
