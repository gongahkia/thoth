-- Test file for performance module

local performance = require("src.performance")

print("=== Testing Performance Module ===\n")

-- Test Timer
print("Testing Timer...")
local timer = performance.Timer()
local sum = 0
for i = 1, 1000000 do
    sum = sum + i
end
local elapsed = timer:stop()
print("Timer test: Summed 1,000,000 numbers in " .. performance.FormatTime(elapsed))
assert(elapsed > 0, "Timer should measure positive time")
print("✓ Timer works\n")

-- Test Benchmark
print("Testing Benchmark...")
local function testFunc(n)
    local result = 0
    for i = 1, n do
        result = result + i
    end
    return result
end

local benchResult = performance.Benchmark(testFunc, 100, 1000)
print("Benchmark results:")
print("  Average: " .. performance.FormatTime(benchResult.average))
print("  Min: " .. performance.FormatTime(benchResult.min))
print("  Max: " .. performance.FormatTime(benchResult.max))
assert(benchResult.iterations == 100, "Should run 100 iterations")
print("✓ Benchmark works\n")

-- Test Compare
print("Testing Compare...")
local results = performance.Compare({
    {name = "Method 1", func = function(n) return n * n end, args = {100}},
    {name = "Method 2", func = function(n) return n ^ 2 end, args = {100}}
}, 1000)

print("Comparison results (sorted by speed):")
for i, result in ipairs(results) do
    print("  " .. i .. ". " .. result.name .. ": " .. performance.FormatTime(result.average))
end
print("✓ Compare works\n")

-- Test Memory
print("Testing GetMemory...")
local memBefore = performance.GetMemory()
print("Current memory: " .. performance.FormatMemory(memBefore))
assert(memBefore > 0, "Memory should be positive")
print("✓ GetMemory works\n")

-- Test MeasureMemory
print("Testing MeasureMemory...")
local memUsed, result = performance.MeasureMemory(function()
    local bigTable = {}
    for i = 1, 10000 do
        bigTable[i] = {value = i, squared = i * i}
    end
    return bigTable
end)
print("Memory used: " .. performance.FormatMemory(memUsed))
print("✓ MeasureMemory works\n")

-- Test Profiler
print("Testing Profiler...")
local profiler = performance.Profiler()

for i = 1, 100 do
    profiler:start("calculation")
    local x = 0
    for j = 1, 1000 do
        x = x + j
    end
    profiler:stop("calculation")
end

profiler:start("string_ops")
local str = ""
for i = 1, 100 do
    str = str .. "test"
end
profiler:stop("string_ops")

profiler:print()
local results = profiler:getResults()
assert(results.calculation.calls == 100, "Should have 100 calculation calls")
print("✓ Profiler works\n")

-- Test FPS Counter
print("Testing FPS Counter...")
local fpsCounter = performance.FPSCounter(0.1)
for i = 1, 50 do
    fpsCounter:update()
end
local fps = fpsCounter:getFPS()
print("FPS: " .. fps)
assert(fps >= 0, "FPS should be non-negative")
print("✓ FPS Counter works\n")

print("=== All Performance Tests Passed ===")
