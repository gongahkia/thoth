local q = require("thoth.core.queues")

local queue = q.new()
assert(q.isEmpty(queue))
assert(queue.first == 1 and queue.last == 0)

q.push(queue, 10)
q.push(queue, 20)
q.push(queue, 30)
assert(q.size(queue) == 3)
assert(q.peek(queue) == 10)

local value = q.pop(queue)
assert(value == 10)
assert(q.size(queue) == 2)
assert(q.peek(queue) == 20)
