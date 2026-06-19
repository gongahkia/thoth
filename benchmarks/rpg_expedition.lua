package.path = "./?.lua;./?/init.lua;./src/?.lua;./src/?/init.lua;" .. package.path

local Simulation = require("src.game.simulation")

local ticks = tonumber(os.getenv("THOTH_BENCH_TICKS")) or 300
local runs = tonumber(os.getenv("THOTH_BENCH_RUNS")) or 8

local commands = {
    Simulation.commands.move("east"),
    Simulation.commands.move("east"),
    Simulation.commands.useItem("torch"),
    Simulation.commands.selectHero(2),
    Simulation.commands.move("east"),
    Simulation.commands.move("east"),
    Simulation.commands.move("east"),
    Simulation.commands.retreat(),
}

local maxTickMs = 0
local started = os.clock()
for run = 1, runs do
    local sim = Simulation.new(20260618 + run)
    for tick = 1, ticks do
        local command = commands[((tick - 1) % #commands) + 1]
        sim:queue(command)
        local tickStart = os.clock()
        sim:step()
        local tickMs = (os.clock() - tickStart) * 1000
        if tickMs > maxTickMs then
            maxTickMs = tickMs
        end
    end
end
local elapsedMs = (os.clock() - started) * 1000

print("benchmark=rpg_expedition")
print("runs=" .. runs)
print("ticks=" .. ticks)
print(string.format("elapsed_ms=%.3f", elapsedMs))
print(string.format("avg_ms_per_tick=%.6f", elapsedMs / math.max(1, ticks * runs)))
print(string.format("max_ms_per_tick=%.6f", maxTickMs))
