-- =============================================
-- Event System
-- Observer pattern, event bus, custom events
-- =============================================

local events = {}

-- =============================================
-- Event Emitter (Observer Pattern)
-- =============================================

---@class EventEmitter
---@field listeners table
local EventEmitter = {}
EventEmitter.__index = EventEmitter

---Create a new event emitter
---@return EventEmitter
function EventEmitter.new()
    local self = setmetatable({}, EventEmitter)
    self.listeners = {}
    return self
end

---Register an event listener
---@param eventName string Event name
---@param callback function Callback function
---@return function unsubscribe Function to unsubscribe this listener
function EventEmitter:on(eventName, callback)
    if not self.listeners[eventName] then
        self.listeners[eventName] = {}
    end

    table.insert(self.listeners[eventName], callback)

    -- Return unsubscribe function
    return function()
        self:off(eventName, callback)
    end
end

---Register a one-time event listener
---@param eventName string Event name
---@param callback function Callback function
---@return function unsubscribe Function to unsubscribe this listener
function EventEmitter:once(eventName, callback)
    local wrappedCallback
    wrappedCallback = function(...)
        callback(...)
        self:off(eventName, wrappedCallback)
    end

    return self:on(eventName, wrappedCallback)
end

---Remove an event listener
---@param eventName string Event name
---@param callback function Callback function to remove
function EventEmitter:off(eventName, callback)
    if not self.listeners[eventName] then
        return
    end

    for i, listener in ipairs(self.listeners[eventName]) do
        if listener == callback then
            table.remove(self.listeners[eventName], i)
            return
        end
    end
end

---Remove all listeners for an event
---@param eventName string Event name
function EventEmitter:removeAllListeners(eventName)
    if eventName then
        self.listeners[eventName] = {}
    else
        self.listeners = {}
    end
end

---Emit an event
---@param eventName string Event name
---@param ... any Event data to pass to listeners
function EventEmitter:emit(eventName, ...)
    if not self.listeners[eventName] then
        return
    end

    -- Create a copy to avoid issues if listeners modify the list
    local listenersCopy = {}
    for i, listener in ipairs(self.listeners[eventName]) do
        listenersCopy[i] = listener
    end

    for _, listener in ipairs(listenersCopy) do
        listener(...)
    end
end

---Get listener count for an event
---@param eventName string Event name
---@return number count Number of listeners
function EventEmitter:listenerCount(eventName)
    if not self.listeners[eventName] then
        return 0
    end

    return #self.listeners[eventName]
end

---Get all event names that have listeners
---@return table eventNames Array of event names
function EventEmitter:eventNames()
    local names = {}
    for name in pairs(self.listeners) do
        table.insert(names, name)
    end
    return names
end

-- =============================================
-- Event Bus (Global Event System)
-- =============================================

---@class EventBus
---@field emitter EventEmitter
local EventBus = {}
EventBus.__index = EventBus

---Create a new event bus
---@return EventBus
function EventBus.new()
    local self = setmetatable({}, EventBus)
    self.emitter = EventEmitter.new()
    return self
end

---Subscribe to an event
---@param eventName string Event name
---@param callback function Callback function
---@return function unsubscribe Unsubscribe function
function EventBus:subscribe(eventName, callback)
    return self.emitter:on(eventName, callback)
end

---Subscribe to an event (one time)
---@param eventName string Event name
---@param callback function Callback function
---@return function unsubscribe Unsubscribe function
function EventBus:subscribeOnce(eventName, callback)
    return self.emitter:once(eventName, callback)
end

---Unsubscribe from an event
---@param eventName string Event name
---@param callback function Callback function
function EventBus:unsubscribe(eventName, callback)
    self.emitter:off(eventName, callback)
end

---Publish an event
---@param eventName string Event name
---@param ... any Event data
function EventBus:publish(eventName, ...)
    self.emitter:emit(eventName, ...)
end

---Clear all subscribers for an event
---@param eventName string|nil Event name (nil to clear all)
function EventBus:clear(eventName)
    self.emitter:removeAllListeners(eventName)
end

---Get subscriber count
---@param eventName string Event name
---@return number count
function EventBus:subscriberCount(eventName)
    return self.emitter:listenerCount(eventName)
end

-- =============================================
-- Custom Event
-- =============================================

---@class Event
---@field name string
---@field data table
---@field timestamp number
---@field cancelled boolean
local Event = {}
Event.__index = Event

---Create a new event
---@param name string Event name
---@param data table|nil Event data
---@return Event
function Event.new(name, data)
    local self = setmetatable({}, Event)
    self.name = name
    self.data = data or {}
    self.timestamp = os.time()
    self.cancelled = false
    return self
end

---Cancel the event
function Event:cancel()
    self.cancelled = true
end

---Check if event is cancelled
---@return boolean cancelled
function Event:isCancelled()
    return self.cancelled
end

---Get event data
---@return table data
function Event:getData()
    return self.data
end

---Set event data
---@param key string Key
---@param value any Value
function Event:setData(key, value)
    self.data[key] = value
end

-- =============================================
-- Event Queue (for deferred event processing)
-- =============================================

---@class EventQueue
---@field queue table
---@field emitter EventEmitter
local EventQueue = {}
EventQueue.__index = EventQueue

---Create a new event queue
---@return EventQueue
function EventQueue.new()
    local self = setmetatable({}, EventQueue)
    self.queue = {}
    self.emitter = EventEmitter.new()
    return self
end

---Enqueue an event
---@param eventName string Event name
---@param ... any Event data
function EventQueue:enqueue(eventName, ...)
    table.insert(self.queue, {
        name = eventName,
        data = {...}
    })
end

---Process all queued events
function EventQueue:process()
    while #self.queue > 0 do
        local event = table.remove(self.queue, 1)
        self.emitter:emit(event.name, table.unpack(event.data))
    end
end

---Process a specific number of events
---@param count number Number of events to process
function EventQueue:processN(count)
    for i = 1, count do
        if #self.queue == 0 then
            break
        end

        local event = table.remove(self.queue, 1)
        self.emitter:emit(event.name, table.unpack(event.data))
    end
end

---Get queue size
---@return number size
function EventQueue:size()
    return #self.queue
end

---Clear the queue
function EventQueue:clear()
    self.queue = {}
end

---Register an event listener
---@param eventName string Event name
---@param callback function Callback function
---@return function unsubscribe Unsubscribe function
function EventQueue:on(eventName, callback)
    return self.emitter:on(eventName, callback)
end

---Remove an event listener
---@param eventName string Event name
---@param callback function Callback function
function EventQueue:off(eventName, callback)
    self.emitter:off(eventName, callback)
end

-- =============================================
-- Signal (simplified event for single listeners)
-- =============================================

---@class Signal
---@field listeners table
local Signal = {}
Signal.__index = Signal

---Create a new signal
---@return Signal
function Signal.new()
    local self = setmetatable({}, Signal)
    self.listeners = {}
    return self
end

---Connect a listener
---@param callback function Callback function
---@return table connection Connection object with :disconnect() method
function Signal:connect(callback)
    table.insert(self.listeners, callback)

    return {
        disconnect = function()
            for i, listener in ipairs(self.listeners) do
                if listener == callback then
                    table.remove(self.listeners, i)
                    return
                end
            end
        end
    }
end

---Fire the signal
---@param ... any Arguments to pass to listeners
function Signal:fire(...)
    for _, listener in ipairs(self.listeners) do
        listener(...)
    end
end

---Disconnect all listeners
function Signal:disconnectAll()
    self.listeners = {}
end

---Get listener count
---@return number count
function Signal:getListenerCount()
    return #self.listeners
end

-- =============================================
-- Global Event Bus Instance
-- =============================================

local globalEventBus = EventBus.new()

---Get the global event bus
---@return EventBus
function events.getGlobalBus()
    return globalEventBus
end

---Subscribe to global event bus
---@param eventName string Event name
---@param callback function Callback function
---@return function unsubscribe
function events.subscribe(eventName, callback)
    return globalEventBus:subscribe(eventName, callback)
end

---Publish to global event bus
---@param eventName string Event name
---@param ... any Event data
function events.publish(eventName, ...)
    globalEventBus:publish(eventName, ...)
end

-- =============================================
-- Factory Functions
-- =============================================

---Create a new event emitter
---@return EventEmitter
function events.newEmitter()
    return EventEmitter.new()
end

---Create a new event bus
---@return EventBus
function events.newBus()
    return EventBus.new()
end

---Create a new event
---@param name string Event name
---@param data table|nil Event data
---@return Event
function events.newEvent(name, data)
    return Event.new(name, data)
end

---Create a new event queue
---@return EventQueue
function events.newQueue()
    return EventQueue.new()
end

---Create a new signal
---@return Signal
function events.newSignal()
    return Signal.new()
end

-- =============================================
-- Example Usage (commented out)
-- =============================================

--[[
-- Example 1: Basic event emitter
local emitter = events.newEmitter()

emitter:on("playerDamage", function(damage, source)
    print("Player took " .. damage .. " damage from " .. source)
end)

emitter:emit("playerDamage", 10, "enemy")

-- Example 2: Global event bus
events.subscribe("gameOver", function(score)
    print("Game Over! Score: " .. score)
end)

events.publish("gameOver", 12345)

-- Example 3: Event queue (for frame-deferred processing)
local queue = events.newQueue()

queue:on("spawn", function(x, y, type)
    print("Spawning " .. type .. " at " .. x .. ", " .. y)
end)

-- Enqueue events during frame
queue:enqueue("spawn", 100, 200, "enemy")
queue:enqueue("spawn", 300, 400, "powerup")

-- Process at end of frame
queue:process()

-- Example 4: Signal
local onHealthChanged = events.newSignal()

local connection = onHealthChanged:connect(function(newHealth)
    print("Health changed to: " .. newHealth)
end)

onHealthChanged:fire(75)

connection:disconnect()
]]

return events
