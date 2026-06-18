package.path = "./?.lua;./?/init.lua;./src/?.lua;./src/?/init.lua;" .. package.path

local Simulation = require("src.game.simulation")

local ticks = tonumber(os.getenv("THOTH_BENCH_TICKS")) or 300
local burnerLines = tonumber(os.getenv("THOTH_BENCH_BURNER_LINES")) or 8
local poweredLines = tonumber(os.getenv("THOTH_BENCH_POWERED_LINES")) or 4

local function addBurnerLine(sim, y)
    sim.world:setTile(0, y, 0, { id = "iron_ore", data = ticks + 20 })
    local miner = sim:addMachine("burner_miner", 0, y, "east")
    miner.inventory:add("coal", ticks)
    sim:addMachine("belt", 1, y, "east")
    sim:addMachine("inserter", 2, y, "east")
    local furnace = sim:addMachine("furnace", 3, y, "east")
    furnace.inventory:add("coal", ticks)
    sim:addMachine("inserter", 4, y, "east")
    sim:addMachine("chest", 5, y, "south")
end

local function addPoweredLine(sim, y)
    sim.world:setTile(0, y, 0, { id = "iron_ore", data = ticks + 20 })
    local generator = sim:addMachine("generator", -2, y, "east")
    generator.inventory:add("coal", ticks)
    sim:addMachine("power_pole", -1, y, "south")
    sim:addMachine("electric_miner", 0, y, "east")
    sim:addMachine("chest", 1, y, "south")
end

local function machineCount(sim)
    local count = 0
    for _ in ipairs(sim.machines) do
        count = count + 1
    end
    return count
end

local sim = Simulation.new(20260618)
for line = 1, burnerLines do
    addBurnerLine(sim, (line - 1) * 3)
end
for line = 1, poweredLines do
    addPoweredLine(sim, (burnerLines + line + 2) * 3)
end

local maxTickMs = 0
local started = os.clock()
for _ = 1, ticks do
    local tickStart = os.clock()
    sim:step()
    local tickMs = (os.clock() - tickStart) * 1000
    if tickMs > maxTickMs then
        maxTickMs = tickMs
    end
end
local elapsedMs = (os.clock() - started) * 1000

print("benchmark=mixed_factory")
print("ticks=" .. ticks)
print("machines=" .. machineCount(sim))
print(string.format("elapsed_ms=%.3f", elapsedMs))
print(string.format("avg_ms_per_tick=%.6f", elapsedMs / math.max(1, ticks)))
print(string.format("max_ms_per_tick=%.6f", maxTickMs))
