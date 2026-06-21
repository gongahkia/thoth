local RunCatalog = require("src.game.tactics.run_catalog")
local Rng = require("src.core.rng")
local State = require("src.game.tactics.state")

local Procgen = {}

local requiredGrammarParts = {
    "rooms",
    "corridors",
    "heightBands",
    "coverFields",
    "sightBreaks",
    "objectiveAnchors",
    "hazardLanes",
    "spawnPockets",
}

local boardGrammar = {
    id = "board_grammar_v1",
    parts = requiredGrammarParts,
    constraints = {
        minWidth = 7,
        minHeight = 5,
        compactBoard = true,
        deterministicAfterLoad = true,
    },
}

local hazardKinds = { "audit_static", "salt_leak", "ember_heat" }

local zoneGeneratorOrder = { "buried_archive", "salt_cistern", "ember_warrens" }

local zoneGenerators = {
    buried_archive = {
        id = "archive_generator_v1",
        zone = "buried_archive",
        material = "archive",
        hazardKind = "audit_static",
        objectiveId = "archive_shelf",
        objectiveKind = "protect_archive_shelf",
        sightBreakKind = "rolling_shelf",
        width = 8,
        height = 8,
    },
    salt_cistern = {
        id = "cistern_generator_v1",
        zone = "salt_cistern",
        material = "salt",
        hazardKind = "flood",
        objectiveId = "floodgate",
        objectiveKind = "repair_floodgate",
        sightBreakKind = "sluice_gate",
        width = 9,
        height = 7,
    },
    ember_warrens = {
        id = "warrens_generator_v1",
        zone = "ember_warrens",
        material = "ember",
        hazardKind = "burn",
        objectiveId = "kiln_chain",
        objectiveKind = "disable_kiln",
        sightBreakKind = "kiln_mouth",
        width = 8,
        height = 7,
    },
}

local function copyValue(value)
    if type(value) ~= "table" then
        return value
    end
    local result = {}
    for key, nested in pairs(value) do
        result[key] = copyValue(nested)
    end
    return result
end

local function tileKey(x, y)
    return tostring(x) .. ":" .. tostring(y)
end

local function addTag(tile, tag)
    tile.tags = tile.tags or {}
    for _, existing in ipairs(tile.tags) do
        if existing == tag then
            return
        end
    end
    tile.tags[#tile.tags + 1] = tag
end

local function carve(tiles, x, y, material, tag)
    local tile = tiles[tileKey(x, y)] or { kind = "floor", material = material, tags = {} }
    tile.kind = tile.kind == "wall" and "floor" or tile.kind
    tile.material = material
    tile.blockerKind = nil
    tile.blocker = false
    tile.losBlocker = false
    addTag(tile, tag or "playable")
    tiles[tileKey(x, y)] = tile
    return tile
end

local function rectTiles(rect)
    local result = {}
    for x = rect.x, rect.x + rect.width - 1 do
        for y = rect.y, rect.y + rect.height - 1 do
            result[#result + 1] = { x = x, y = y }
        end
    end
    return result
end

local function rowTiles(playable, fromX, toX, y)
    local result = {}
    for x = fromX, toX do
        if playable[tileKey(x, y)] then
            result[#result + 1] = { x = x, y = y }
        end
    end
    return result
end

local function applyCover(tile, edges)
    tile.coverEdges = tile.coverEdges or {}
    for direction, cover in pairs(edges) do
        tile.coverEdges[direction] = cover
    end
end

local function requireSize(width, height)
    if width < boardGrammar.constraints.minWidth or height < boardGrammar.constraints.minHeight then
        error("board grammar needs at least 7x5 tiles", 3)
    end
end

local function mergeOptions(base, overrides)
    local result = copyValue(base or {})
    for key, value in pairs(overrides or {}) do
        result[key] = copyValue(value)
    end
    return result
end

function Procgen.templates()
    return RunCatalog.templates()
end

function Procgen.validators()
    return RunCatalog.validators()
end

function Procgen.weights()
    return RunCatalog.weights()
end

function Procgen.requiredGrammarParts()
    return copyValue(requiredGrammarParts)
end

function Procgen.grammar()
    return copyValue(boardGrammar)
end

function Procgen.zoneGenerators()
    local result = {}
    for _, zoneId in ipairs(zoneGeneratorOrder) do
        result[#result + 1] = copyValue(zoneGenerators[zoneId])
    end
    return result
end

function Procgen.zoneGenerator(zoneId)
    return copyValue(zoneGenerators[zoneId])
end

function Procgen.validateGrammarBoard(spec)
    local report = { valid = true, missing = {}, counts = {} }
    local components = spec and spec.grammar and spec.grammar.components or {}
    for _, part in ipairs(requiredGrammarParts) do
        local count = #(components[part] or {})
        report.counts[part] = count
        if count == 0 then
            report.valid = false
            report.missing[#report.missing + 1] = part
        end
    end
    if not spec or not spec.board then
        report.valid = false
        report.missing[#report.missing + 1] = "board"
    end
    return report
end

function Procgen.generateBoard(seed, options)
    options = options or {}
    local width = options.width or 8
    local height = options.height or 8
    requireSize(width, height)

    local rng = Rng.new(seed or 1)
    local material = options.material or "archive"
    local zoneId = options.zone
    local generatorId = options.generatorId or "grammar_generator_v1"
    local roomHeight = math.min(4, height - 2)
    local midY = math.floor((height + 1) / 2)
    local roomY = math.max(1, math.min(height - roomHeight + 1, midY - math.floor(roomHeight / 2)))
    local bottomY = roomY + roomHeight - 1
    local secondY = math.min(bottomY, midY + 1)
    local hazardKind = options.hazardKind or hazardKinds[rng:range(1, #hazardKinds)]
    local highRow = rng:range(0, 1) == 0 and roomY or bottomY
    local objectiveId = options.objectiveId or "route_machine"
    local objectiveKind = options.objectiveKind or "protect_route_machinery"
    local objectiveIntegrity = options.objectiveIntegrity or 3
    local sightBreakKind = options.sightBreakKind or "sight_break"

    local tiles = {}
    for x = 1, width do
        for y = 1, height do
            tiles[tileKey(x, y)] = { kind = "wall", material = material, blockerKind = "hard", blocker = true, losBlocker = true, tags = { "sealed_void" } }
        end
    end

    local rooms = {
        { id = "entry_room", role = "squad_spawn", x = 1, y = roomY, width = 3, height = roomHeight },
        { id = "objective_room", role = "objective_pressure", x = width - 2, y = roomY, width = 3, height = roomHeight },
    }
    local corridors = {
        { id = "central_corridor", from = "entry_room", to = "objective_room", x = 4, y = midY, width = width - 6, height = 1 },
    }
    local playable = {}
    for _, room in ipairs(rooms) do
        room.tiles = rectTiles(room)
        for _, tile in ipairs(room.tiles) do
            playable[tileKey(tile.x, tile.y)] = true
            carve(tiles, tile.x, tile.y, material, "room")
        end
    end
    for _, corridor in ipairs(corridors) do
        corridor.tiles = rectTiles(corridor)
        for _, tile in ipairs(corridor.tiles) do
            playable[tileKey(tile.x, tile.y)] = true
            carve(tiles, tile.x, tile.y, material, "corridor")
        end
    end

    local heightBands = {
        { id = "upper_height_band", height = 1, tiles = rowTiles(playable, 1, width, highRow) },
        { id = "lower_height_band", height = 0, tiles = rowTiles(playable, 1, width, highRow == roomY and bottomY or roomY) },
    }
    for _, band in ipairs(heightBands) do
        for _, tileRef in ipairs(band.tiles) do
            local tile = tiles[tileKey(tileRef.x, tileRef.y)]
            tile.height = band.height
            addTag(tile, "height_band")
        end
    end

    local coverFields = {
        { id = "entry_cover_field", x = 2, y = midY, coverEdges = { east = "half", south = "half" } },
        { id = "objective_cover_field", x = width - 1, y = secondY, coverEdges = { west = "full", north = "half" } },
    }
    for _, field in ipairs(coverFields) do
        local tile = tiles[tileKey(field.x, field.y)]
        applyCover(tile, field.coverEdges)
        addTag(tile, "cover_field")
    end

    local sightBreaks = {
        { id = "entry_shelf_break", x = 2, y = roomY, destructibleHp = 2 },
        { id = "objective_shelf_break", x = width - 1, y = bottomY, destructibleHp = 2 },
    }
    for _, sightBreak in ipairs(sightBreaks) do
        local tile = tiles[tileKey(sightBreak.x, sightBreak.y)]
        tile.kind = sightBreakKind
        tile.blockerKind = "destructible"
        tile.blocker = true
        tile.losBlocker = true
        tile.destructibleHp = sightBreak.destructibleHp
        addTag(tile, "sight_break")
    end

    local hazardTiles = rowTiles(playable, 4, width - 3, midY)
    local hazardLanes = {
        { id = "central_hazard_lane", kind = hazardKind, tiles = hazardTiles },
    }
    for _, tileRef in ipairs(hazardTiles) do
        local tile = tiles[tileKey(tileRef.x, tileRef.y)]
        tile.hazard = { kind = hazardKind, damage = 1, timing = "end_turn" }
        addTag(tile, "hazard_lane")
    end

    local objectiveAnchors = {
        { id = objectiveId, kind = objectiveKind, x = width - 1, y = midY, integrity = objectiveIntegrity, evacuateAt = { x = 1, y = midY } },
    }
    for _, objective in ipairs(objectiveAnchors) do
        local tile = tiles[tileKey(objective.x, objective.y)]
        tile.objective = { id = objective.id, kind = objective.kind }
        addTag(tile, "objective_anchor")
    end

    local spawnPockets = {
        { id = "player_entry", side = "player", tiles = { { x = 1, y = midY }, { x = 1, y = secondY } } },
        { id = "enemy_pressure", side = "enemy", tiles = { { x = width, y = midY }, { x = width, y = secondY } } },
    }

    local spec = {
        seed = seed or 1,
        zone = zoneId,
        generator = {
            id = generatorId,
            zone = zoneId,
            material = material,
            hazardKind = hazardKind,
            objectiveKind = objectiveKind,
        },
        grammar = {
            id = boardGrammar.id,
            components = {
                rooms = rooms,
                corridors = corridors,
                heightBands = heightBands,
                coverFields = coverFields,
                sightBreaks = sightBreaks,
                objectiveAnchors = objectiveAnchors,
                hazardLanes = hazardLanes,
                spawnPockets = spawnPockets,
            },
        },
        board = { width = width, height = height, tiles = tiles },
        units = {
            { id = "warden", side = "player", x = spawnPockets[1].tiles[1].x, y = spawnPockets[1].tiles[1].y, hp = 6 },
            { id = "duelist", side = "player", x = spawnPockets[1].tiles[2].x, y = spawnPockets[1].tiles[2].y, hp = 5 },
            { id = "claimant", side = "enemy", x = spawnPockets[2].tiles[1].x, y = spawnPockets[2].tiles[1].y, hp = 4 },
        },
        objectives = objectiveAnchors,
    }
    spec.validation = Procgen.validateGrammarBoard(spec)
    return spec
end

function Procgen.state(seed, options)
    return State.new(Procgen.generateBoard(seed, options))
end

function Procgen.generateZoneBoard(zoneId, seed, options)
    local generator = zoneGenerators[zoneId]
    if not generator then
        error("unknown zone generator " .. tostring(zoneId), 2)
    end
    local merged = mergeOptions(generator, options)
    merged.zone = zoneId
    merged.generatorId = generator.id
    return Procgen.generateBoard(seed, merged)
end

function Procgen.zoneState(zoneId, seed, options)
    return State.new(Procgen.generateZoneBoard(zoneId, seed, options))
end

return Procgen
