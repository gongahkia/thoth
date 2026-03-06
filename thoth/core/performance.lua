-- =============================================
-- Performance Module
-- Benchmarking, profiling, and performance monitoring utilities
-- =============================================

local performance = {}

-- =============================================
-- Timer for measuring execution time
-- =============================================

---@class Timer
---@field startTime number
---@field endTime number|nil
local Timer = {}
Timer.__index = Timer

---Create a new timer
---@return Timer
function Timer.new()
    local self = setmetatable({}, Timer)
    self.startTime = os.clock()
    self.endTime = nil
    return self
end

---Stop the timer and return elapsed time
---@return number elapsed time in seconds
function Timer:stop()
    self.endTime = os.clock()
    return self:getElapsed()
end

---Get elapsed time (can be called multiple times)
---@return number elapsed time in seconds
function Timer:getElapsed()
    local endTime = self.endTime or os.clock()
    return endTime - self.startTime
end

---Reset the timer
function Timer:reset()
    self.startTime = os.clock()
    self.endTime = nil
end

---Create and start a new timer
---@return Timer
function performance.Timer()
    return Timer.new()
end

-- =============================================
-- Function Benchmarking
-- =============================================

---Benchmark a function by running it multiple times
---@param func function The function to benchmark
---@param iterations number Number of times to run the function
---@param ... any Arguments to pass to the function
---@return table results {total, average, min, max, iterations}
function performance.Benchmark(func, iterations, ...)
    iterations = iterations or 1000
    local args = {...}

    local times = {}
    local total = 0
    local min = math.huge
    local max = 0

    for i = 1, iterations do
        local timer = Timer.new()
        func(table.unpack(args))
        local elapsed = timer:stop()

        times[i] = elapsed
        total = total + elapsed
        min = math.min(min, elapsed)
        max = math.max(max, elapsed)
    end

    return {
        total = total,
        average = total / iterations,
        min = min,
        max = max,
        iterations = iterations,
        times = times
    }
end

---Compare performance of multiple functions
---@param functions table Array of {name, func, args} tables
---@param iterations number Number of iterations per function
---@return table results Array of benchmark results with names
function performance.Compare(functions, iterations)
    iterations = iterations or 1000
    local results = {}

    for i, entry in ipairs(functions) do
        local name = entry.name or ("Function " .. i)
        local func = entry.func
        local args = entry.args or {}

        local benchmark = performance.Benchmark(func, iterations, table.unpack(args))
        benchmark.name = name
        table.insert(results, benchmark)
    end

    -- Sort by average time (fastest first)
    table.sort(results, function(a, b) return a.average < b.average end)

    return results
end

-- =============================================
-- Memory Tracking
-- =============================================

---Get current memory usage in KB
---@return number memory usage in kilobytes
function performance.GetMemory()
    return collectgarbage("count")
end

---Measure memory used by a function call
---@param func function The function to measure
---@param ... any Arguments to pass to the function
---@return number memory Memory increase in KB
---@return any result Return value of the function
function performance.MeasureMemory(func, ...)
    collectgarbage("collect")
    local before = collectgarbage("count")

    local result = func(...)

    collectgarbage("collect")
    local after = collectgarbage("count")

    return after - before, result
end

-- =============================================
-- Profiler (call counting and timing)
-- =============================================

---@class Profiler
---@field profiles table
local Profiler = {}
Profiler.__index = Profiler

---Create a new profiler
---@return Profiler
function Profiler.new()
    local self = setmetatable({}, Profiler)
    self.profiles = {}
    return self
end

---Start profiling a named section
---@param name string Profile section name
function Profiler:start(name)
    if not self.profiles[name] then
        self.profiles[name] = {
            calls = 0,
            totalTime = 0,
            minTime = math.huge,
            maxTime = 0
        }
    end

    self.profiles[name].currentStart = os.clock()
end

---Stop profiling a named section
---@param name string Profile section name
function Profiler:stop(name)
    if not self.profiles[name] or not self.profiles[name].currentStart then
        return
    end

    local elapsed = os.clock() - self.profiles[name].currentStart
    local profile = self.profiles[name]

    profile.calls = profile.calls + 1
    profile.totalTime = profile.totalTime + elapsed
    profile.minTime = math.min(profile.minTime, elapsed)
    profile.maxTime = math.max(profile.maxTime, elapsed)
    profile.currentStart = nil
end

---Get profiling results
---@return table results Profiling data for all sections
function Profiler:getResults()
    local results = {}

    for name, profile in pairs(self.profiles) do
        results[name] = {
            calls = profile.calls,
            totalTime = profile.totalTime,
            averageTime = profile.calls > 0 and (profile.totalTime / profile.calls) or 0,
            minTime = profile.minTime ~= math.huge and profile.minTime or 0,
            maxTime = profile.maxTime
        }
    end

    return results
end

---Reset all profiling data
function Profiler:reset()
    self.profiles = {}
end

---Print formatted profiling results
function Profiler:print()
    print("\n=== Profile Results ===")
    local results = self:getResults()

    -- Convert to array for sorting
    local sortedResults = {}
    for name, data in pairs(results) do
        data.name = name
        table.insert(sortedResults, data)
    end

    -- Sort by total time (highest first)
    table.sort(sortedResults, function(a, b) return a.totalTime > b.totalTime end)

    for _, result in ipairs(sortedResults) do
        print(string.format("%-30s | Calls: %6d | Total: %.6fs | Avg: %.6fs | Min: %.6fs | Max: %.6fs",
            result.name,
            result.calls,
            result.totalTime,
            result.averageTime,
            result.minTime,
            result.maxTime
        ))
    end
    print("=======================\n")
end

---Create a new profiler instance
---@return Profiler
function performance.Profiler()
    return Profiler.new()
end

-- =============================================
-- FPS Counter (for Love2D)
-- =============================================

---@class FPSCounter
---@field frames number
---@field lastTime number
---@field fps number
---@field updateInterval number
local FPSCounter = {}
FPSCounter.__index = FPSCounter

---Create a new FPS counter
---@param updateInterval number How often to update FPS (in seconds), default 0.5
---@return FPSCounter
function FPSCounter.new(updateInterval)
    local self = setmetatable({}, FPSCounter)
    self.frames = 0
    self.lastTime = os.clock()
    self.fps = 0
    self.updateInterval = updateInterval or 0.5
    return self
end

---Update the FPS counter (call every frame)
function FPSCounter:update()
    self.frames = self.frames + 1
    local currentTime = os.clock()
    local elapsed = currentTime - self.lastTime

    if elapsed >= self.updateInterval then
        self.fps = self.frames / elapsed
        self.frames = 0
        self.lastTime = currentTime
    end
end

---Get current FPS
---@return number fps Current frames per second
function FPSCounter:getFPS()
    return self.fps
end

---Create a new FPS counter
---@param updateInterval number Update interval in seconds
---@return FPSCounter
function performance.FPSCounter(updateInterval)
    return FPSCounter.new(updateInterval)
end

-- =============================================
-- Utility Functions
-- =============================================

---Format time in a human-readable way
---@param seconds number Time in seconds
---@return string formatted Formatted time string
function performance.FormatTime(seconds)
    if seconds < 0.000001 then
        return string.format("%.3f ns", seconds * 1000000000)
    elseif seconds < 0.001 then
        return string.format("%.3f μs", seconds * 1000000)
    elseif seconds < 1 then
        return string.format("%.3f ms", seconds * 1000)
    else
        return string.format("%.3f s", seconds)
    end
end

---Format memory in a human-readable way
---@param kb number Memory in kilobytes
---@return string formatted Formatted memory string
function performance.FormatMemory(kb)
    if kb < 1024 then
        return string.format("%.2f KB", kb)
    elseif kb < 1024 * 1024 then
        return string.format("%.2f MB", kb / 1024)
    else
        return string.format("%.2f GB", kb / (1024 * 1024))
    end
end

return performance
