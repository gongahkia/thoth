-- Test file for events module

local events = require("src.events")

print("=== Testing Events Module ===\n")

-- Test Event Emitter
print("Testing EventEmitter...")
local emitter = events.newEmitter()

local callCount = 0
local function listener(data)
    callCount = callCount + 1
    assert(data == "test", "should receive correct data")
end

emitter:on("testEvent", listener)
emitter:emit("testEvent", "test")

assert(callCount == 1, "listener should be called once")

emitter:emit("testEvent", "test")
assert(callCount == 2, "listener should be called again")

print("✓ EventEmitter works\n")

-- Test Once
print("Testing once...")
local onceCount = 0
emitter:once("onceEvent", function()
    onceCount = onceCount + 1
end)

emitter:emit("onceEvent")
emitter:emit("onceEvent")

assert(onceCount == 1, "once listener should only be called once")
print("✓ Once works\n")

-- Test Off
print("Testing off...")
local emitter2 = events.newEmitter()
local count = 0
local function testListener()
    count = count + 1
end

emitter2:on("event", testListener)
emitter2:emit("event")
assert(count == 1, "listener called once")

emitter2:off("event", testListener)
emitter2:emit("event")
assert(count == 1, "listener should not be called after off")

print("✓ Off works\n")

-- Test Multiple Listeners
print("Testing multiple listeners...")
local emitter3 = events.newEmitter()
local results = {}

emitter3:on("multi", function() table.insert(results, "A") end)
emitter3:on("multi", function() table.insert(results, "B") end)
emitter3:on("multi", function() table.insert(results, "C") end)

emitter3:emit("multi")
assert(#results == 3, "all listeners should be called")
assert(results[1] == "A" and results[2] == "B" and results[3] == "C", "listeners called in order")

print("✓ Multiple listeners work\n")

-- Test RemoveAllListeners
print("Testing removeAllListeners...")
local emitter4 = events.newEmitter()
local count4 = 0

emitter4:on("event", function() count4 = count4 + 1 end)
emitter4:on("event", function() count4 = count4 + 1 end)

emitter4:emit("event")
assert(count4 == 2, "both listeners called")

emitter4:removeAllListeners("event")
count4 = 0
emitter4:emit("event")
assert(count4 == 0, "no listeners after removeAll")

print("✓ RemoveAllListeners works\n")

-- Test ListenerCount
print("Testing listenerCount...")
local emitter5 = events.newEmitter()
assert(emitter5:listenerCount("test") == 0, "initially 0 listeners")

emitter5:on("test", function() end)
assert(emitter5:listenerCount("test") == 1, "1 listener after on")

emitter5:on("test", function() end)
assert(emitter5:listenerCount("test") == 2, "2 listeners after second on")

print("✓ ListenerCount works\n")

-- Test Event Bus
print("Testing EventBus...")
local bus = events.newBus()

local received = nil
local unsubscribe = bus:subscribe("message", function(data)
    received = data
end)

bus:publish("message", "hello")
assert(received == "hello", "should receive published message")

unsubscribe()
received = nil
bus:publish("message", "world")
assert(received == nil, "should not receive after unsubscribe")

print("✓ EventBus works\n")

-- Test Global Event Bus
print("Testing global event bus...")
local globalReceived = nil

events.subscribe("globalEvent", function(data)
    globalReceived = data
end)

events.publish("globalEvent", "global data")
assert(globalReceived == "global data", "should use global bus")

print("✓ Global event bus works\n")

-- Test Event Queue
print("Testing EventQueue...")
local queue = events.newQueue()

local queueResults = {}
queue:on("task", function(taskName)
    table.insert(queueResults, taskName)
end)

queue:enqueue("task", "Task 1")
queue:enqueue("task", "Task 2")
queue:enqueue("task", "Task 3")

assert(queue:size() == 3, "queue should have 3 events")

queue:process()

assert(#queueResults == 3, "all events should be processed")
assert(queueResults[1] == "Task 1", "events processed in order")
assert(queue:size() == 0, "queue should be empty after processing")

print("✓ EventQueue works\n")

-- Test ProcessN
print("Testing processN...")
local queue2 = events.newQueue()
local processed = 0

queue2:on("item", function()
    processed = processed + 1
end)

for i = 1, 10 do
    queue2:enqueue("item")
end

queue2:processN(5)
assert(processed == 5, "should process exactly 5 events")
assert(queue2:size() == 5, "should have 5 events remaining")

print("✓ ProcessN works\n")

-- Test Signal
print("Testing Signal...")
local signal = events.newSignal()

local signalCount = 0
local connection = signal:connect(function(value)
    signalCount = signalCount + value
end)

signal:fire(10)
assert(signalCount == 10, "signal listener called with 10")

signal:fire(5)
assert(signalCount == 15, "signal listener called again with 5")

connection:disconnect()
signal:fire(100)
assert(signalCount == 15, "listener not called after disconnect")

print("✓ Signal works\n")

-- Test Multiple Signal Listeners
print("Testing multiple signal listeners...")
local signal2 = events.newSignal()
local results2 = {}

local conn1 = signal2:connect(function(x) table.insert(results2, x * 2) end)
local conn2 = signal2:connect(function(x) table.insert(results2, x * 3) end)

signal2:fire(5)
assert(#results2 == 2, "both listeners called")
assert(results2[1] == 10 and results2[2] == 15, "correct values")

print("✓ Multiple signal listeners work\n")

-- Test DisconnectAll
print("Testing disconnectAll...")
local signal3 = events.newSignal()
local count3 = 0

signal3:connect(function() count3 = count3 + 1 end)
signal3:connect(function() count3 = count3 + 1 end)

signal3:fire()
assert(count3 == 2, "both listeners called")

signal3:disconnectAll()
count3 = 0
signal3:fire()
assert(count3 == 0, "no listeners after disconnectAll")

print("✓ DisconnectAll works\n")

-- Test Custom Event
print("Testing custom Event...")
local customEvent = events.newEvent("playerDamage", {damage = 10, source = "enemy"})

assert(customEvent.name == "playerDamage", "event has correct name")
assert(customEvent.data.damage == 10, "event has correct data")
assert(not customEvent:isCancelled(), "event not cancelled by default")

customEvent:cancel()
assert(customEvent:isCancelled(), "event should be cancelled")

customEvent:setData("critical", true)
assert(customEvent:getData().critical == true, "should set data")

print("✓ Custom Event works\n")

-- Test Unsubscribe Return Value
print("Testing unsubscribe return value...")
local bus2 = events.newBus()
local callCount2 = 0

local unsub = bus2:subscribe("test", function()
    callCount2 = callCount2 + 1
end)

bus2:publish("test")
assert(callCount2 == 1, "listener called")

unsub()
bus2:publish("test")
assert(callCount2 == 1, "listener not called after unsub()")

print("✓ Unsubscribe return value works\n")

print("=== All Events Tests Passed ===")
