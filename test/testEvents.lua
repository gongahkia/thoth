local events = require("thoth.core.events")

local emitter = events.newEmitter()
local count = 0
local off = emitter:on("x", function(v)
    count = count + v
end)

emitter:emit("x", 2)
assert(count == 2)
off()
emitter:emit("x", 2)
assert(count == 2)

local queue = events.newQueue()
local processed = 0
queue:on("job", function()
    processed = processed + 1
end)
queue:enqueue("job")
queue:enqueue("job")
queue:processN(1)
assert(processed == 1)
assert(queue:size() == 1)
