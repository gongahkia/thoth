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
queue:process()
assert(processed == 2)
assert(queue:size() == 0)

local ordered = {}
for i = 1, 200 do
    queue:enqueue("job", i)
end
queue:on("job", function(v)
    ordered[#ordered + 1] = v
end)
queue:process()
assert(#ordered == 200)
assert(ordered[1] == 1 and ordered[200] == 200)
