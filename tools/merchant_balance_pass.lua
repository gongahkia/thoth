package.path = "./?.lua;./?/init.lua;./src/?.lua;./src/?/init.lua;" .. package.path

local Procgen = require("src.game.tactics.procgen")
local TacticalRuntime = require("src.game.tactical_runtime")

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

local route = Procgen.archiveRoute()
local rows = {}
local failures = 0

for index, variantId in ipairs(route.variantOrder or {}) do
    local state = Procgen.archiveRouteState(variantId)
    local runtime = TacticalRuntime.new(makeSim(7200 + index), { variantId = variantId })
    TacticalRuntime.refreshOverlays(runtime)
    local summary = runtime:summary()
    local objective = summary.objective or {}
    local players = #(summary.players or {})
    local enemies = #(summary.enemies or {})
    local intents = 0
    for _ in pairs(runtime.state.intents or {}) do
        intents = intents + 1
    end
    local movement = #(runtime.overlays.movement or {})
    local ok = state and players > 0 and enemies > 0 and intents > 0 and movement > 0 and objective.id ~= nil
    if not ok then
        failures = failures + 1
    end
    rows[#rows + 1] = {
        id = variantId,
        board = tostring((state.board and state.board.width) or "?") .. "x" .. tostring((state.board and state.board.height) or "?"),
        players = players,
        enemies = enemies,
        intents = intents,
        movement = movement,
        objective = tostring(objective.id or "-"),
        ok = ok,
    }
end

print("merchant_balance_pass=" .. (failures == 0 and "ok" or "fail"))
print("passes=" .. tostring(#rows))
print("merchant_passes=0")
print("baseline_passes=" .. tostring(#rows))
print("failures=" .. tostring(failures))
print("")
print("| id | board | players | enemies | intents | movement | objective | ok |")
print("|---|---:|---:|---:|---:|---:|---|---|")
for _, row in ipairs(rows) do
    print("| " .. row.id .. " | " .. row.board .. " | " .. tostring(row.players) .. " | " .. tostring(row.enemies) .. " | " .. tostring(row.intents) .. " | " .. tostring(row.movement) .. " | " .. row.objective .. " | " .. tostring(row.ok) .. " |")
end

if failures > 0 then
    os.exit(1)
end
