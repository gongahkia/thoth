local Utils = require("modules/utils")
local World = require("modules/world")

local SaveGame = {}

local FILE_VERSION = "1.0"
local SAVE_DIR = "saves"

local TRANSIENT_KEYS = {
    entities = true,
    tileEntities = true,
    _entity = true,
    _entityKey = true,
    _furnitureEntity = true,
    _furnitureKey = true,
    _tileKey = true,
    _wildlifeEntity = true,
    _worldObjectKey = true,
    source = true,
    render = true,
    interact = true,
    hit = true,
    tick = true,
}

local function getFilesystem()
    if love and love.filesystem then
        return {
            createDirectory = function(path)
                love.filesystem.createDirectory(path)
            end,
            getDirectoryItems = function(path)
                return love.filesystem.getDirectoryItems(path)
            end,
            read = function(path)
                return love.filesystem.read(path)
            end,
            write = function(path, contents)
                return love.filesystem.write(path, contents)
            end,
            remove = function(path)
                if love.filesystem.remove then
                    return love.filesystem.remove(path)
                end
                return false
            end,
        }
    end

    return {
        createDirectory = function(path)
            os.execute(string.format('mkdir -p "%s"', path))
        end,
        getDirectoryItems = function(path)
            local items = {}
            local handle = io.popen(string.format('ls -1 "%s" 2>/dev/null', path))
            if not handle then
                return items
            end
            for line in handle:lines() do
                table.insert(items, line)
            end
            handle:close()
            return items
        end,
        read = function(path)
            local handle = io.open(path, "r")
            if not handle then
                return nil
            end
            local contents = handle:read("*all")
            handle:close()
            return contents
        end,
        write = function(path, contents)
            local handle = io.open(path, "w")
            if not handle then
                return false
            end
            handle:write(contents)
            handle:close()
            return true
        end,
        remove = function(path)
            return os.remove(path) == true
        end,
    }
end

local function normalizeSlot(slot)
    slot = tostring(slot or "autosave")
    slot = slot:gsub("%.lua$", "")
    slot = slot:gsub("[^%w_%-%s]", "_"):gsub("%s+", "_")
    if slot == "" then
        slot = "autosave"
    end
    return slot .. ".lua"
end

local function labelFromSlot(slot)
    slot = normalizeSlot(slot):gsub("%.lua$", "")
    slot = slot:gsub("_", " ")
    return (slot:gsub("^%l", string.upper))
end

local function defaultLabel(run)
    local world = run and run.world or {}
    local mode = run and run.mode or "survival"
    local day = world.dayCount or (run and run.stats and run.stats.daysSurvived) or 1
    local depth = world.currentDepth or (run and run.player and run.player.depth) or 0
    local modeLabel = (mode:gsub("^%l", string.upper))
    return string.format("%s Day %s Depth %s", modeLabel, tostring(day), tostring(depth))
end

local function stableKeys(tbl)
    local keys = {}
    for key in pairs(tbl) do
        table.insert(keys, key)
    end
    table.sort(keys, function(left, right)
        if type(left) == type(right) then
            return tostring(left) < tostring(right)
        end
        return type(left) < type(right)
    end)
    return keys
end

local function sanitize(value, seen, keyName)
    if TRANSIENT_KEYS[keyName] or type(value) == "function" or type(value) == "userdata" or type(value) == "thread" then
        return nil
    end
    if type(value) ~= "table" then
        return value
    end
    seen = seen or {}
    if seen[value] then
        return nil
    end
    seen[value] = true
    local copy = {}
    for key, inner in pairs(value) do
        local sanitizedKey = sanitize(key, seen)
        local sanitizedValue = sanitize(inner, seen, key)
        if sanitizedKey ~= nil and sanitizedValue ~= nil then
            copy[sanitizedKey] = sanitizedValue
        end
    end
    seen[value] = nil
    return copy
end

local function quote(value)
    return string.format("%q", value)
end

local function serializeValue(value)
    local valueType = type(value)
    if valueType == "string" then
        return quote(value)
    elseif valueType == "number" or valueType == "boolean" then
        return tostring(value)
    elseif valueType == "table" then
        local parts = {"{"}
        for _, key in ipairs(stableKeys(value)) do
            local keyLiteral
            if type(key) == "string" and key:match("^[%a_][%w_]*$") then
                keyLiteral = key
            else
                keyLiteral = "[" .. serializeValue(key) .. "]"
            end
            table.insert(parts, keyLiteral .. "=" .. serializeValue(value[key]) .. ",")
        end
        table.insert(parts, "}")
        return table.concat(parts)
    end
    return "nil"
end

local function clearTransientLevelState(level)
    level.entities = {}
    level.tileEntities = {}
    for _, collection in ipairs({
        "resourceNodes",
        "workbenches",
        "curingStations",
        "snowShelters",
        "fires",
        "traps",
        "carcasses",
        "fishingSpots",
        "climbNodes",
        "mapNodes",
        "gates",
        "npcEncounters",
    }) do
        for _, entry in ipairs(level[collection] or {}) do
            entry._entity = nil
            entry._entityKey = nil
        end
    end
    for _, list in pairs(level.wildlife or {}) do
        for _, actor in ipairs(list) do
            actor._wildlifeEntity = nil
            actor._tileKey = nil
            actor.render = nil
        end
    end
end

local function prepareWorldForRestore(world)
    world.entities = nil
    world.tileEntities = nil
    for _, level in pairs(world.levels or {}) do
        clearTransientLevelState(level)
    end
end

function SaveGame.snapshotRun(run, options)
    options = options or {}
    World.attachRun(run)
    local snapshot = {
        version = FILE_VERSION,
        savedAt = os.date("%Y-%m-%d %H:%M:%S"),
        slot = options.slot and normalizeSlot(options.slot) or nil,
        slotLabel = options.label or options.slotLabel,
        difficultyName = run.difficultyName,
        mode = run.mode,
        sourceMode = run.sourceMode,
        seed = run.seed,
        world = sanitize(run.world),
        player = sanitize(run.player),
        stats = sanitize(run.stats),
        runtime = sanitize({
            success = run.runtime and run.runtime.success or false,
            endgameActivated = run.runtime and run.runtime.endgameActivated or false,
            endgameDepth = run.runtime and run.runtime.endgameDepth,
            causeOfDeath = run.runtime and run.runtime.causeOfDeath,
        }),
    }
    snapshot.slotLabel = snapshot.slotLabel or defaultLabel(run)
    snapshot.world.currentDepth = run.world.currentDepth or run.player.depth or 0
    snapshot.player.depth = run.player.depth or snapshot.world.currentDepth
    return snapshot
end

function SaveGame.restoreRun(snapshot)
    if type(snapshot) ~= "table" or type(snapshot.world) ~= "table" or type(snapshot.player) ~= "table" then
        return nil, "Invalid save data."
    end

    local run = {
        difficultyName = snapshot.difficultyName,
        mode = snapshot.mode,
        sourceMode = snapshot.sourceMode,
        seed = snapshot.seed,
        world = Utils.deepCopy(snapshot.world),
        player = Utils.deepCopy(snapshot.player),
        stats = Utils.deepCopy(snapshot.stats or {}),
        runtime = Utils.deepCopy(snapshot.runtime or {}),
        restoredFromSave = true,
    }
    prepareWorldForRestore(run.world)
    World.attachRun(run)
    local depth = run.world.currentDepth or run.player.depth or 0
    World.changeDepth(run, depth, run.player.coord)
    return run
end

function SaveGame.serialize(snapshot)
    return "return " .. serializeValue(sanitize(snapshot))
end

function SaveGame.deserialize(contents)
    if type(contents) ~= "string" or contents == "" then
        return nil
    end
    local chunk = load(contents, "tikrit_save", "t", {})
    if not chunk then
        return nil
    end
    local ok, result = pcall(chunk)
    if not ok or type(result) ~= "table" then
        return nil
    end
    return result
end

function SaveGame.normalizeSlot(slot)
    return normalizeSlot(slot)
end

function SaveGame.slotLabel(slot, snapshot)
    return (snapshot and snapshot.slotLabel) or labelFromSlot(slot)
end

function SaveGame.defaultSlotName(run)
    local world = run and run.world or {}
    local seed = run and run.seed or "run"
    local day = world.dayCount or (run and run.stats and run.stats.daysSurvived) or 1
    local depth = world.currentDepth or (run and run.player and run.player.depth) or 0
    local timestamp = os.date("%Y%m%d_%H%M%S")
    return normalizeSlot(string.format("manual_%s_day_%s_depth_%s_seed_%s", timestamp, tostring(day), tostring(depth), tostring(seed)))
end

function SaveGame.saveRun(slot, run, options)
    local fs = getFilesystem()
    fs.createDirectory(SAVE_DIR)
    local normalized = normalizeSlot(slot)
    options = options or {}
    options.slot = normalized
    return fs.write(SAVE_DIR .. "/" .. normalized, SaveGame.serialize(SaveGame.snapshotRun(run, options)))
end

function SaveGame.loadRun(slot)
    local contents = getFilesystem().read(SAVE_DIR .. "/" .. normalizeSlot(slot))
    local snapshot = SaveGame.deserialize(contents)
    if not snapshot then
        return nil, "Save not found or invalid."
    end
    return SaveGame.restoreRun(snapshot)
end

function SaveGame.inspect(slot)
    return SaveGame.deserialize(getFilesystem().read(SAVE_DIR .. "/" .. normalizeSlot(slot)))
end

function SaveGame.listSaves()
    local fs = getFilesystem()
    fs.createDirectory(SAVE_DIR)
    local saves = {}
    for _, item in ipairs(fs.getDirectoryItems(SAVE_DIR) or {}) do
        if item:match("%.lua$") then
            table.insert(saves, item)
        end
    end
    table.sort(saves)
    return saves
end

function SaveGame.listSaveEntries()
    local entries = {}
    for _, slot in ipairs(SaveGame.listSaves()) do
        local snapshot = SaveGame.inspect(slot)
        if snapshot then
            table.insert(entries, {
                slot = slot,
                file = slot,
                label = SaveGame.slotLabel(slot, snapshot),
                savedAt = snapshot.savedAt,
                difficultyName = snapshot.difficultyName,
                mode = snapshot.mode,
                world = snapshot.world,
                snapshot = snapshot,
            })
        end
    end
    table.sort(entries, function(left, right)
        local leftTime = left.savedAt or ""
        local rightTime = right.savedAt or ""
        if leftTime == rightTime then
            return left.slot < right.slot
        end
        return leftTime > rightTime
    end)
    return entries
end

function SaveGame.delete(slot)
    local fs = getFilesystem()
    fs.createDirectory(SAVE_DIR)
    return fs.remove(SAVE_DIR .. "/" .. normalizeSlot(slot))
end

return SaveGame
