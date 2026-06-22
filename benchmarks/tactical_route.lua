local Simulation = require("src.game.simulation")
local TacticalRuntime = require("src.game.tactical_runtime")

local runs = tonumber(os.getenv("THOTH_BENCH_RUNS")) or 4
local ticks = tonumber(os.getenv("THOTH_BENCH_TICKS")) or 60
local clock = os.clock
local elapsed = 0
local maxTick = 0

for run = 1, runs do
    local sim = Simulation.new(20260618 + run)
    local runtime = TacticalRuntime.new(sim)
    for tick = 1, ticks do
        local started = clock()
        if tick % 4 == 0 then
            runtime:handleKey("tab")
        elseif tick % 2 == 0 then
            runtime:handleKey("right")
        else
            TacticalRuntime.refreshOverlays(runtime)
            runtime:summary()
        end
        local ms = (clock() - started) * 1000
        elapsed = elapsed + ms
        if ms > maxTick then
            maxTick = ms
        end
    end
end

print("benchmark=tactical_route")
print("runs=" .. tostring(runs))
print("ticks=" .. tostring(ticks))
print(string.format("elapsed_ms=%.3f", elapsed))
print(string.format("avg_ms_per_tick=%.6f", elapsed / math.max(1, runs * ticks)))
print(string.format("max_ms_per_tick=%.6f", maxTick))
