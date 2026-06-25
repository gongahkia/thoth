local TacticsState = require("src.game.tactics.state")
local TacticalRuntime = require("src.game.tactical_runtime")

local clock = os.clock
local sizesEnv = os.getenv("THOTH_LARGE_MAP_SIZES") or "32x24,64x48,128x96"
local topologiesEnv = os.getenv("THOTH_LARGE_MAP_TOPOLOGIES") or "square,triangle,hex"
local runs = tonumber(os.getenv("THOTH_LARGE_MAP_RUNS")) or 3
local moveBudget = tonumber(os.getenv("THOTH_LARGE_MAP_MOVE_BUDGET"))

local function splitCsv(value)
    local result = {}
    for part in tostring(value or ""):gmatch("[^,]+") do
        result[#result + 1] = part
    end
    return result
end

local function parseSize(value)
    local width, height = tostring(value):match("^(%d+)x(%d+)$")
    return tonumber(width), tonumber(height)
end

local function tileKey(x, y)
    return tostring(x) .. ":" .. tostring(y)
end

local function safeTile(x, y, width, height)
    if x <= 8 and y <= 5 then
        return true
    end
    if x >= width - 8 and y >= height - 5 then
        return true
    end
    return false
end

local function makeBoard(width, height, topology)
    local tiles = {}
    for y = 1, height do
        for x = 1, width do
            if not safeTile(x, y, width, height) and ((x * 17 + y * 31) % 29 == 0) then
                tiles[tileKey(x, y)] = { blocker = true, losBlocker = true, height = 1, kind = "archive_stack" }
            elseif ((x * 7 + y * 13) % 41 == 0) then
                tiles[tileKey(x, y)] = { height = 1, kind = "archive_step" }
            end
        end
    end
    return { width = width, height = height, topology = topology, tiles = tiles }
end

local function makeUnits(width, height)
    local units = {
        { id = "warden", class = "warden", side = "player", x = 2, y = 2, hp = 6, ap = moveBudget or math.max(width, height), maxAp = moveBudget or math.max(width, height), visionRadius = 8 },
        { id = "duelist", class = "duelist", side = "player", x = 1, y = 2, hp = 5, ap = 3, maxAp = 3, visionRadius = 8 },
        { id = "mender", class = "mender", side = "player", x = 2, y = 1, hp = 4, ap = 3, maxAp = 3, visionRadius = 8 },
        { id = "harrier", class = "harrier", side = "player", x = 3, y = 2, hp = 4, ap = 3, maxAp = 3, visionRadius = 8 },
        { id = "enemy_1", kind = "bailiff", side = "enemy", x = math.max(1, width - 3), y = math.max(1, height - 2), hp = 4, ap = 2, maxAp = 2, visionRadius = 7 },
        { id = "enemy_2", kind = "bailiff", side = "enemy", x = math.max(1, width - 5), y = math.max(1, height - 4), hp = 4, ap = 2, maxAp = 2, visionRadius = 7 },
    }
    return units
end

local function makeRuntime(width, height, topology)
    local state = TacticsState.new({
        board = makeBoard(width, height, topology),
        selectedUnitId = "warden",
        defaultAp = 3,
        units = makeUnits(width, height),
    })
    return {
        active = true,
        state = state,
        selectedUnitId = "warden",
        cursor = { x = width, y = height },
        cache = {},
        overlays = {},
        lastSeenEnemies = {},
        turn = 1,
        visibilityGrid = TacticalRuntime.visibilityGrid,
        enemyVisible = TacticalRuntime.enemyVisible,
    }
end

local function measure(label, fn)
    local total = 0
    local maxMs = 0
    local count = math.max(1, runs)
    for _ = 1, count do
        local started = clock()
        fn()
        local ms = (clock() - started) * 1000
        total = total + ms
        if ms > maxMs then
            maxMs = ms
        end
    end
    return { label = label, avg = total / count, max = maxMs }
end

print("benchmark=tactical_large_map")
print("runs=" .. tostring(runs))
for _, topology in ipairs(splitCsv(topologiesEnv)) do
    for _, size in ipairs(splitCsv(sizesEnv)) do
        local width, height = parseSize(size)
        if width and height then
            local runtime = makeRuntime(width, height, topology)
            local state = runtime.state
            local selected = state:unit("warden")
            local results = {
                measure("visibility", function()
                    state:visibilityGrid("player")
                end),
                measure("movement", function()
                    state:movementPreview(selected.id)
                end),
                measure("movement_no_paths", function()
                    state:movementPreview(selected.id, { includePaths = false })
                end),
                measure("party_path", function()
                    TacticalRuntime.partyPathTo(runtime, width, height)
                end),
                measure("overlay_refresh", function()
                    runtime.cache = {}
                    TacticalRuntime.refreshOverlays(runtime)
                end),
            }
            print("case=" .. tostring(topology) .. ":" .. tostring(width) .. "x" .. tostring(height))
            for _, result in ipairs(results) do
                print(string.format("%s_avg_ms=%.6f", result.label, result.avg))
                print(string.format("%s_max_ms=%.6f", result.label, result.max))
            end
        end
    end
end
