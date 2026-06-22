package.path = "./?.lua;./?/init.lua;./src/?.lua;./src/?/init.lua;" .. package.path

local TacticalRuntime = require("src.game.tactical_runtime")

local ticks = tonumber(os.getenv("THOTH_BENCH_TICKS")) or 300
local runs = tonumber(os.getenv("THOTH_BENCH_RUNS")) or 8
local includeRender = os.getenv("THOTH_BENCH_RENDER") == "1"

local function runRenderBenchmark()
    local command = os.getenv("THOTH_BENCH_RENDER_COMMAND")
    if not command or command == "" then
        command = (os.getenv("LOVE") or "love") .. " . --render-benchmark"
    end
    print("render_command=" .. command)
    local handle = assert(io.popen(command .. " 2>&1"))
    local output = handle:read("*a")
    local ok, reason, code = handle:close()
    io.write(output)
    if not ok then
        error("render benchmark failed: " .. tostring(reason) .. " " .. tostring(code))
    end
end

local function makeSim(seed)
    return {
        seed = seed,
        mode = "tactical",
        status = "tactical",
        tick = 0,
        player = { x = 0, y = 0, z = 0 },
        world = {
            setTile = function() end,
        },
    }
end

local maxTickMs = 0
local started = os.clock()
for run = 1, runs do
    local runtime = TacticalRuntime.new(makeSim(20260618 + run))
    for tick = 1, ticks do
        local tickStart = os.clock()
        if tick % 4 == 0 then
            runtime:handleKey("tab")
        elseif tick % 2 == 0 then
            runtime:handleKey("right")
        else
            TacticalRuntime.refreshOverlays(runtime)
        end
        local tickMs = (os.clock() - tickStart) * 1000
        if tickMs > maxTickMs then
            maxTickMs = tickMs
        end
    end
end
local elapsedMs = (os.clock() - started) * 1000

print("benchmark=tactical_route")
print("runs=" .. runs)
print("ticks=" .. ticks)
print(string.format("elapsed_ms=%.3f", elapsedMs))
print(string.format("avg_ms_per_tick=%.6f", elapsedMs / math.max(1, ticks * runs)))
print(string.format("max_ms_per_tick=%.6f", maxTickMs))

if includeRender then
    runRenderBenchmark()
end
