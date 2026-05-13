local CONFIG = require("config")
local EntitySystem = require("modules/entity_system")
local Utils = require("modules/utils")

local WorldObjects = {}

local COLLECTIONS = {
    fires = "fire",
    traps = "snare_trap",
    carcasses = "carcass",
    resourceNodes = "loot_marker",
    fishingSpots = "fishing_spot",
    climbNodes = "climb_node",
    mapNodes = "map_node",
    gates = "traversal_gate",
    npcEncounters = "npc_encounter",
}

local function coordKey(coord)
    local gx, gy = Utils.pixelToGrid(coord[1], coord[2])
    return tostring(gx + 1) .. ":" .. tostring(gy + 1)
end

local function objectKey(kind, coord, options)
    if options and options.mergeKey then
        return options.mergeKey
    end
    return kind .. ":" .. coordKey(coord)
end

local function findExisting(level, key)
    for _, entity in ipairs(level.entities or {}) do
        if entity._worldObjectKey == key then
            return entity
        end
    end
    return nil
end

function WorldObjects.render(entity, context)
    if not context then
        return
    end
    if entity.kind == "fire" and context.drawFire then
        context.drawFire(entity.source or entity)
    elseif entity.kind == "snare_trap" and context.drawTrap then
        context.drawTrap(entity.source or entity)
    elseif entity.kind == "carcass" and context.drawCarcass then
        context.drawCarcass(entity.source or entity)
    elseif entity.kind == "loot_marker" and context.drawResourceNode then
        context.drawResourceNode(entity.source or entity)
    elseif entity.kind == "fishing_spot" and context.drawWorldMarker then
        context.drawWorldMarker("fishing", entity.source or entity)
    elseif entity.kind == "climb_node" and context.drawWorldMarker then
        context.drawWorldMarker("climb", entity.source or entity)
    elseif entity.kind == "map_node" and context.drawWorldMarker then
        local source = entity.source or entity
        context.drawWorldMarker(source.survey and "survey" or "map", source)
    elseif entity.kind == "traversal_gate" and context.drawWorldMarker then
        local source = entity.source or entity
        context.drawWorldMarker(source.unlockState and "gate_open" or "gate_locked", source)
    elseif entity.kind == "npc_encounter" and context.drawWorldMarker then
        context.drawWorldMarker("npc", entity.source or entity)
    end
end

local function interactMarker(entity, run, _level)
    local source = entity.source or entity
    if entity.kind == "fishing_spot" then
        local Wildlife = require("modules/wildlife")
        local ok, message = Wildlife.fish(run)
        if ok then
            run.runtime = run.runtime or {}
            run.runtime.pendingSound = "fish_catch"
        end
        return ok, message
    elseif entity.kind == "climb_node" then
        local Survival = require("modules/survival")
        local ok, message = Survival.useRopeClimb(run)
        if ok then
            run.runtime = run.runtime or {}
            run.runtime.pendingSound = "rope_climb"
        end
        return ok, message
    elseif entity.kind == "map_node" then
        local Survival = require("modules/survival")
        local ok, message
        if source.survey then
            ok, message = Survival.surveyArea(run)
            if not ok then
                ok, message = Survival.mapArea(run)
            end
        else
            ok, message = Survival.mapArea(run)
        end
        if ok then
            run.runtime = run.runtime or {}
            run.runtime.pendingSound = "map_reveal"
        end
        return ok, message
    elseif entity.kind == "traversal_gate" then
        local Survival = require("modules/survival")
        return Survival.useTraversalGate(run, source)
    elseif entity.kind == "npc_encounter" then
        local Survival = require("modules/survival")
        return Survival.interactNPC(run, source)
    end
    return false, nil
end

function WorldObjects.hit(entity, _run, _level, _toolDefinition)
    if entity and entity.kind == "loot_marker" then
        return false, "Open it instead."
    end
    return false, "That tool finds no purchase."
end

function WorldObjects.spawn(level, kind, coord, options)
    options = options or {}
    level.entities = level.entities or {}
    level.tileEntities = level.tileEntities or {}

    local key = objectKey(kind, coord, options)
    local entity = findExisting(level, key)
    if entity then
        entity.coord = {coord[1], coord[2]}
        entity.source = options.source or entity.source
        entity.hidden = options.hidden == true
        entity.render = entity.render or WorldObjects.render
        entity.interact = options.interact or entity.interact
        entity.hit = entity.hit or WorldObjects.hit
        entity._worldObjectCollection = options.collection or entity._worldObjectCollection
        if entity.source then
            entity.source._entityKey = entity._worldObjectKey
        end
        EntitySystem.updateTileIndex(level, entity)
        return entity
    end

    entity = EntitySystem.spawn(level, kind, coord, {
        width = options.width or CONFIG.TILE_SIZE - 2,
        height = options.height or CONFIG.TILE_SIZE - 2,
        solid = false,
        hidden = options.hidden == true,
        source = options.source,
        render = WorldObjects.render,
        interact = options.interact,
        hit = WorldObjects.hit,
        _worldObjectKey = key,
        _worldObjectCollection = options.collection,
    })
    if entity.source then
        entity.source._entityKey = entity._worldObjectKey
    end
    return entity
end

local function objectKindFor(collection, source)
    if collection == "resourceNodes" then
        if not source or source.type ~= "loot" then
            return nil
        end
        return "loot_marker"
    end
    if collection == "npcEncounters" and source and source.resolutionState ~= "active" then
        return nil
    end
    return COLLECTIONS[collection]
end

local function isHidden(collection, source)
    if collection == "gates" then
        return source.revealed == false
    elseif collection == "npcEncounters" then
        return source.resolutionState ~= "active"
    end
    return source.hidden == true and source.revealed ~= true
end

local function interactionFor(kind)
    if kind == "fishing_spot"
        or kind == "climb_node"
        or kind == "map_node"
        or kind == "traversal_gate"
        or kind == "npc_encounter" then
        return interactMarker
    end
    return nil
end

local function liveObjectKeys(level)
    local live = {}
    for collection in pairs(COLLECTIONS) do
        for _, source in ipairs(level[collection] or {}) do
            local kind = objectKindFor(collection, source)
            if kind and source.coord then
                local key = objectKey(kind, source.coord, {mergeKey = source._entityKey})
                live[key] = true
            end
        end
    end
    return live
end

local function pruneStale(level, live)
    local stale = {}
    for _, entity in ipairs(level.entities or {}) do
        if entity._worldObjectKey and not live[entity._worldObjectKey] then
            table.insert(stale, entity)
        end
    end
    for _, entity in ipairs(stale) do
        EntitySystem.remove(level, entity)
    end
end

function WorldObjects.mirrorLevel(level)
    if not level then
        return level
    end

    local live = liveObjectKeys(level)
    pruneStale(level, live)

    for collection in pairs(COLLECTIONS) do
        for _, source in ipairs(level[collection] or {}) do
            local kind = objectKindFor(collection, source)
            if kind and source.coord then
                local entity = WorldObjects.spawn(level, kind, source.coord, {
                    mergeKey = source._entityKey,
                    source = source,
                    collection = collection,
                    hidden = isHidden(collection, source),
                    interact = interactionFor(kind),
                })
                source._entityKey = entity._worldObjectKey
            end
        end
    end
    EntitySystem.rebuildTileIndex(level)
    return level
end

return WorldObjects
