local t = require("thoth.core.tables")

local arr = {1, 2, 3}
assert(t.Count(arr) == 3)
assert(t.Pop(arr) == 3)
assert(t.Count(arr) == 2)

t.Push(arr, 9)
assert(arr[3] == 9)

local shifted = t.Shift(arr)
assert(shifted[1] == 2)
assert(shifted == arr)

local shiftedValue = t.ShiftValue(arr)
assert(shiftedValue == 2)
assert(arr[1] == 9)

t.Unshift(arr, 1)
assert(arr[1] == 1)

local mapped = t.Map(function(v) return v * 2 end, arr)
assert(mapped[1] == 2)

local filtered = t.Filter(function(v) return v % 2 == 1 end, arr)
assert(#filtered >= 1)

local reduced = t.Reduce(function(a, b) return a + b end, {1, 2, 3, 4})
assert(reduced == 10)

local reducedWithInitial = t.Reduce(function(a, b) return a + b end, {1, 2, 3}, 10)
assert(reducedWithInitial == 16)

local ok = pcall(function()
    t.Reduce(function(a, b) return a + b end, {})
end)
assert(ok == false)
