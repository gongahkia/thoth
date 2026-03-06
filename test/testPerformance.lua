local perf = require("thoth.core.performance")

local timer = perf.Timer()
local sum = 0
for i = 1, 10000 do
    sum = sum + i
end
local elapsed = timer:stop()
assert(elapsed >= 0)

local result = perf.Benchmark(function(x) return x + 1 end, 10, 1)
assert(result.iterations == 10)
assert(result.average >= 0)

local profiler = perf.Profiler()
profiler:start("work")
for _ = 1, 1000 do end
profiler:stop("work")
local profile = profiler:getResults()
assert(profile.work.calls == 1)
