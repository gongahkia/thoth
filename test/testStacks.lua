local s = require("thoth.core.stacks")

local stack = s.new()
assert(s.isEmpty(stack))

s.push(stack, 10)
s.push(stack, 20)
assert(s.size(stack) == 2)
assert(s.peek(stack) == 20)

local value = s.pop(stack)
assert(value == 20)
assert(s.size(stack) == 1)
