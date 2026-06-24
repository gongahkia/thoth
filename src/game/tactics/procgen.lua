local RunCatalog = require("src.game.tactics.run_catalog")
local EnemyCatalog = require("src.game.tactics.enemy_catalog")
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
    "terrainTypes",
    "generationTechniques",
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

local hazardKinds = { "audit_static", "paper_cinder", "index_miasma" }

local terrainTypes = {
    { id = "sealed_void", kind = "wall", material = "void", blocker = true, losBlocker = true, tags = { "sealed_void" }, role = "boundary" },
    { id = "sealed_archive_mass", kind = "wall", material = "archive", blocker = true, losBlocker = true, tags = { "sealed_mass", "built_mass" }, role = "structural_backfill" },
    { id = "archive_floor", kind = "floor", material = "archive", tags = { "room" }, role = "baseline" },
    { id = "archive_terrace", kind = "archive_terrace", material = "archive", tags = { "height_band", "raised_archive_walk" }, role = "height" },
    { id = "archive_stair", kind = "archive_stair", material = "archive", tags = { "stair", "vertical_route" }, role = "vertical_route" },
    { id = "archive_rubble", kind = "rubble", material = "archive", moveCost = 1, tags = { "rough_terrain" }, role = "slow_ground" },
    { id = "archive_glass_floor", kind = "glass_floor", material = "glass", destructibleHp = 1, tags = { "fragile_floor" }, role = "fragile" },
    { id = "archive_chasm", kind = "archive_chasm", material = "void", blocker = true, losBlocker = false, tags = { "chasm", "sealed_void" }, role = "gap" },
    { id = "rolling_shelf", kind = "rolling_shelf", material = "archive", blockerKind = "destructible", blocker = true, losBlocker = true, destructibleHp = 2, tags = { "sight_break" }, role = "destructible_los" },
    { id = "audit_static_lane", kind = "audit_static_lane", material = "archive", hazard = { kind = "audit_static", damage = 1, timing = "end_turn" }, tags = { "hazard_lane" }, role = "hazard" },
    { id = "paper_cinder_lane", kind = "paper_cinder_lane", material = "ember", hazard = { kind = "paper_cinder", damage = 1, timing = "end_turn" }, tags = { "hazard_lane", "burn_hazard" }, role = "hazard" },
    { id = "index_miasma", kind = "index_miasma", material = "ash", hazard = { kind = "index_miasma", active = true, losModifier = "obscure" }, tags = { "obscurant", "hazard_lane" }, role = "obscurant" },
    { id = "brine_pool", kind = "brine_pool", material = "salt", moveCost = 1, hazard = { kind = "brine", active = true, damage = 1, timing = "end_turn" }, tags = { "flood_hazard", "rough_terrain" }, role = "water_hazard" },
    { id = "mirror_glass", kind = "mirror_glass", material = "glass", tags = { "reflective_los" }, role = "sightline_modifier" },
    { id = "temple_stone", kind = "temple_stone", material = "temple", tags = { "temple_floor" }, role = "district_floor" },
    { id = "sunken_water", kind = "sunken_water", material = "water", moveCost = 1, hazard = { kind = "waterlogged", active = true, timing = "enter" }, tags = { "shallow_water", "rough_terrain" }, role = "slow_ground" },
    { id = "root_tangle", kind = "root_tangle", material = "root", moveCost = 1, tags = { "root_choked", "rough_terrain" }, role = "slow_ground" },
    { id = "root_screen", kind = "root_screen", material = "root", hazard = { kind = "root_screen", active = true, losModifier = "obscure" }, tags = { "obscurant", "root_choked" }, role = "obscurant" },
    { id = "bell_stone", kind = "bell_stone", material = "bronze", tags = { "bell_chamber", "height_band" }, role = "height" },
    { id = "ash_glass", kind = "ash_glass", material = "glass", destructibleHp = 1, tags = { "fragile_floor", "ash_sanctum" }, role = "fragile" },
    { id = "heat_vent", kind = "heat_vent", material = "ash", hazard = { kind = "heat_vent", damage = 1, timing = "end_turn" }, tags = { "hazard_lane", "ash_sanctum" }, role = "hazard" },
    { id = "ritual_pillar", kind = "ritual_pillar", material = "temple", blockerKind = "destructible", blocker = true, losBlocker = true, destructibleHp = 3, tags = { "sight_break", "temple_pillar" }, role = "destructible_los" },
}

local generationTechniques = {
    { id = "rect_room_pair", output = "two readable combat rooms", counterplay = "clear flank lanes" },
    { id = "straight_spine_corridor", output = "central route pressure lane", counterplay = "break sight or cross early" },
    { id = "terrace_height_bands", output = "upper and lower tactical rows", counterplay = "use stairs or drop routes" },
    { id = "destructible_sight_breaks", output = "breakable LoS blockers", counterplay = "spend AP to open fire lanes" },
    { id = "hazard_lane_dressing", output = "seeded audit, cinder, or miasma lane", counterplay = "route around or cleanse" },
    { id = "special_terrain_scatter", output = "rubble, glass, and chasm accents", counterplay = "inspect AP cost and fragile floor" },
    { id = "stitched_expanse_regions", output = "route boards welded into one expanse", counterplay = "wake regions without state reset" },
    { id = "monument_switchback", output = "large ascent and descent structures", counterplay = "control high ground and stair mouths" },
    { id = "void_bridge_network", output = "bridges over blocking void", counterplay = "break bridges or defend crossings" },
    { id = "macro_graph_layout", output = "profile-driven critical path and side branches", counterplay = "read route shape before committing AP" },
    { id = "noise_heightfield", output = "seeded height, void, hazard, and material fields", counterplay = "use high ground and avoid noisy danger bands" },
    { id = "wfc_tile_dressing", output = "adjacency-safe shelves, stairs, bridges, and tile motifs", counterplay = "inspect local motif affordances" },
    { id = "graph_sprawl", output = "looped hub and shortcut layouts", counterplay = "reconnect paths and flank through branches" },
    { id = "cellular_mines", output = "worm-carved rooms and mine tunnels", counterplay = "clear pockets and destructible choke points" },
    { id = "open_field_noise", output = "broad noise-shaped terrain fields", counterplay = "cross sparse cover islands decisively" },
    { id = "spire_stack_generation", output = "stacked platforms, narrow bridges, and stair chains", counterplay = "control vertical chokepoints" },
    { id = "megastructure_sprawl", output = "overscaled ribs, shells, shafts, and dead slabs wrapped around playable routes", counterplay = "use huge blockers as readable cover and sight breaks" },
    { id = "temple_district_sprawl", output = "sunken courts, root catacombs, bell chambers, and ash sanctums stitched into one hub", counterplay = "read district terrain before committing routes" },
    { id = "catacomb_loop_network", output = "optional loops and side pockets around the critical route", counterplay = "spend AP for flank routes and landmarks" },
    { id = "soft_gate_shortcuts", output = "sealed shortcuts that reopen after local objectives", counterplay = "unlock return paths without loading a new board" },
    { id = "ambient_landmark_fill", output = "non-combat landmarks that make off-route space legible", counterplay = "navigate by visible shrines, bells, roots, and cistern marks" },
    { id = "tactical_repair_validation", output = "post-pass reachability, LoS, cover, and objective repairs", counterplay = "guaranteed readable tactical routes" },
}

local hybridProfiles = {
    spires = {
        id = "spires",
        maxHeight = 4,
        corridorWidth = 1,
        roomScale = 0.75,
        openNoise = 0.86,
        branchChance = 0.2,
        techniques = { "macro_graph_layout", "noise_heightfield", "wfc_tile_dressing", "spire_stack_generation", "void_bridge_network", "megastructure_sprawl", "tactical_repair_validation" },
    },
    sprawl = {
        id = "sprawl",
        maxHeight = 2,
        corridorWidth = 2,
        roomScale = 1.05,
        openNoise = 0.78,
        branchChance = 0.9,
        techniques = { "macro_graph_layout", "noise_heightfield", "wfc_tile_dressing", "graph_sprawl", "megastructure_sprawl", "tactical_repair_validation" },
    },
    open_wilds = {
        id = "open_wilds",
        maxHeight = 2,
        corridorWidth = 3,
        roomScale = 1.35,
        openNoise = 0.58,
        branchChance = 0.55,
        techniques = { "macro_graph_layout", "noise_heightfield", "wfc_tile_dressing", "open_field_noise", "hazard_lane_dressing", "tactical_repair_validation" },
    },
    rooms_mines = {
        id = "rooms_mines",
        maxHeight = 2,
        corridorWidth = 1,
        roomScale = 0.72,
        openNoise = 0.9,
        branchChance = 0.45,
        techniques = { "macro_graph_layout", "noise_heightfield", "wfc_tile_dressing", "cellular_mines", "destructible_sight_breaks", "tactical_repair_validation" },
    },
    mixed_archive = {
        id = "mixed_archive",
        maxHeight = 3,
        corridorWidth = 2,
        roomScale = 1.0,
        openNoise = 0.72,
        branchChance = 0.7,
        techniques = { "macro_graph_layout", "noise_heightfield", "wfc_tile_dressing", "graph_sprawl", "cellular_mines", "open_field_noise", "spire_stack_generation", "megastructure_sprawl", "tactical_repair_validation" },
    },
}

local terrainTypeById = {}
for _, terrainType in ipairs(terrainTypes) do
    terrainTypeById[terrainType.id] = terrainType
end

local generationTechniqueById = {}
for _, technique in ipairs(generationTechniques) do
    generationTechniqueById[technique.id] = technique
end

local zoneGeneratorOrder = { "buried_archive" }

local zoneEnemyFamilies = {
    buried_archive = "archive",
}

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
}

local archiveRouteId = "buried_archive_vertical_slice"

local archiveRouteVariantOrder = {
    "archive_entry_audit",
    "archive_shelf_protection",
    "archive_proof_extract",
    "archive_ledger_repair",
    "archive_sealed_shortcut",
    "archive_vault_regent_final",
}

local archiveRouteVariants = {
    archive_entry_audit = {
        id = "archive_entry_audit",
        zone = "buried_archive",
        nodeKind = "combat",
        template = "kill_light",
        routeDepth = 1,
        seed = 6101,
        reward = { salvage = 2, proof = 1 },
        complication = "audit_static_claim_line",
        preview = "compact entry stacks with known audit-static lane and a stealth-read docket",
        generatorOptions = { width = 8, height = 8, objectiveId = "entry_shelf", objectiveKind = "stealth_read", profile = "rooms_mines" },
        directorOptions = { failureClock = 3, threatenedTiles = 4, reinforcementTurn = 3 },
    },
    archive_shelf_protection = {
        id = "archive_shelf_protection",
        zone = "buried_archive",
        nodeKind = "combat",
        template = "protect_heavy",
        routeDepth = 2,
        seed = 6102,
        reward = { salvage = 1, standing = "custodian" },
        complication = "two_turn_shelf_pressure",
        preview = "wider stacks around a higher-integrity shelf anchor",
        generatorOptions = { width = 9, height = 8, objectiveId = "deep_shelf", objectiveKind = "protect_archive_shelf", objectiveIntegrity = 4, profile = "sprawl" },
        directorOptions = { failureClock = 4, threatenedTiles = 5, reinforcementTurn = 4 },
    },
    archive_proof_extract = {
        id = "archive_proof_extract",
        zone = "buried_archive",
        nodeKind = "high_reward_extraction",
        template = "extraction",
        routeDepth = 2,
        seed = 6103,
        reward = { proof = 3, salvage = 1 },
        complication = "exit_access_pressure",
        preview = "proof cache must remain reachable to the entry evacuation tile",
        generatorOptions = { width = 8, height = 7, objectiveId = "proof_cache", objectiveKind = "extract_record", profile = "open_wilds" },
        directorOptions = { failureClock = 3, threatenedTiles = 5, reinforcementTurn = 3 },
    },
    archive_ledger_repair = {
        id = "archive_ledger_repair",
        zone = "buried_archive",
        nodeKind = "repair",
        template = "repair",
        routeDepth = 3,
        seed = 6104,
        reward = { routeIntegrity = 1, salvage = 1 },
        complication = "repair_ap_timing",
        preview = "ledger machinery sits past a central audit lane",
        generatorOptions = { width = 9, height = 7, objectiveId = "ledger_machine", objectiveKind = "repair_machinery", profile = "spires" },
        directorOptions = { includeAlpha = true, alphaTurn = 4, failureClock = 3, threatenedTiles = 4, reinforcementTurn = 4 },
    },
    archive_sealed_shortcut = {
        id = "archive_sealed_shortcut",
        zone = "buried_archive",
        nodeKind = "cursed_shortcut",
        template = "stealth",
        routeDepth = 3,
        seed = 6105,
        reward = { skipPressure = 1, proof = 1 },
        complication = "audit_lens_lock",
        preview = "short board with tighter sight breaks and a disable objective",
        generatorOptions = { width = 7, height = 7, objectiveId = "audit_lens", objectiveKind = "disable_audit_lens", profile = "rooms_mines" },
        directorOptions = { failureClock = 3, threatenedTiles = 6, reinforcementTurn = 3 },
    },
    archive_elite_claim = {
        id = "archive_elite_claim",
        zone = "buried_archive",
        nodeKind = "elite",
        template = "holdout",
        routeDepth = 4,
        seed = 6106,
        reward = { rareUnlock = "archive_claim_counter", salvage = 2 },
        complication = "partial_intent_elite",
        preview = "elite claim pressure with one redacted footprint",
        generatorOptions = { width = 9, height = 8, objectiveId = "claim_docket", objectiveKind = "hold_claim", profile = "sprawl" },
        directorOptions = { includeElite = true, eliteId = "shelf_knight", eliteIds = { "codex_advocate", "shelf_knight", "writ_cantor", "null_censor" }, failureClock = 4, threatenedTiles = 7, reinforcementTurn = 4 },
    },
    archive_vault_regent_final = {
        id = "archive_vault_regent_final",
        zone = "buried_archive",
        nodeKind = "boss",
        template = "boss_route",
        routeDepth = 4,
        seed = 6106,
        reward = { sealProgress = 1, classOption = "boss_claim_counter" },
        complication = "regent_claim_beams",
        preview = "Vault Regent final procedure with staged claim beams and legal cover",
        bossId = "vault_regent",
        generatorOptions = { width = 9, height = 7, objectiveId = "vault_regent", objectiveKind = "boss_procedure", objectiveIntegrity = 5, profile = "mixed_archive" },
        directorOptions = { bossId = "vault_regent", failureClock = 5, threatenedTiles = 8, intentCap = 10, reinforcementTurn = 4 },
    },
}

local archiveRoute = {
    id = archiveRouteId,
    zone = "buried_archive",
    start = "archive_entry_audit",
    variantOrder = archiveRouteVariantOrder,
    boardCount = #archiveRouteVariantOrder,
    preview = {
        risk = "audit static, shelf cover, and visible reinforcements",
        reward = "proof, salvage, route integrity, shortcut pressure, and seal progress",
        detail = "six deterministic Buried Archive mission variants with distinct objective families",
        visible = true,
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

local function componentListByIds(source, ids)
    local result = {}
    for _, id in ipairs(ids or {}) do
        if source[id] then
            result[#result + 1] = copyValue(source[id])
        end
    end
    return result
end

local function terrainTypesUsedByTiles(tiles)
    local used = {}
    local ordered = {}
    for _, terrainType in ipairs(terrainTypes) do
        ordered[#ordered + 1] = terrainType.id
    end
    for _, tile in pairs(tiles or {}) do
        if tile.terrainType then
            used[tile.terrainType] = true
        end
    end
    local result = {}
    for _, id in ipairs(ordered) do
        if used[id] then
            result[#result + 1] = copyValue(terrainTypeById[id])
        end
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

local function removeTag(tile, tag)
    if not (tile and tile.tags) then
        return
    end
    for index = #tile.tags, 1, -1 do
        if tile.tags[index] == tag then
            table.remove(tile.tags, index)
        end
    end
end

local function clearSealedTags(tile)
    removeTag(tile, "sealed_void")
    removeTag(tile, "sealed_mass")
    removeTag(tile, "built_mass")
end

local function stampTerrain(tile, terrainTypeId)
    local terrainType = terrainTypeById[terrainTypeId]
    if not (tile and terrainType) then
        return tile
    end
    tile.terrainType = terrainType.id
    tile.kind = terrainType.kind or tile.kind
    tile.material = terrainType.material or tile.material
    if terrainType.blocker ~= nil then
        tile.blocker = terrainType.blocker
    end
    if terrainType.losBlocker ~= nil then
        tile.losBlocker = terrainType.losBlocker
    end
    if terrainType.blockerKind then
        tile.blockerKind = terrainType.blockerKind
    end
    if terrainType.moveCost ~= nil then
        tile.moveCost = terrainType.moveCost
    end
    if terrainType.destructibleHp ~= nil then
        tile.destructibleHp = terrainType.destructibleHp
    end
    if terrainType.hazard then
        tile.hazard = copyValue(terrainType.hazard)
    end
    for _, tag in ipairs(terrainType.tags or {}) do
        addTag(tile, tag)
    end
    return tile
end

local function carve(tiles, x, y, material, tag)
    local tile = tiles[tileKey(x, y)] or { kind = "floor", material = material, tags = {} }
    tile.kind = tile.kind == "wall" and "floor" or tile.kind
    tile.material = material
    tile.blockerKind = nil
    tile.blocker = false
    tile.losBlocker = false
    clearSealedTags(tile)
    stampTerrain(tile, "archive_floor")
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

local function pickIndexed(list, index)
    return list[((index - 1) % #list) + 1]
end

local function archiveVariantFor(variantId)
    local variant = archiveRouteVariants[variantId]
    if not variant then
        error("unknown archive route variant " .. tostring(variantId), 3)
    end
    return variant
end

local function pathTiles(from, to)
    local result = {}
    local stepX = from.x <= to.x and 1 or -1
    for x = from.x, to.x, stepX do
        result[#result + 1] = { x = x, y = from.y }
    end
    if from.y ~= to.y then
        local stepY = from.y <= to.y and 1 or -1
        for y = from.y + stepY, to.y, stepY do
            result[#result + 1] = { x = to.x, y = y }
        end
    end
    return result
end

local function spawnPocketById(spec, id)
    local pockets = spec and spec.grammar and spec.grammar.components and spec.grammar.components.spawnPockets or {}
    for _, pocket in ipairs(pockets) do
        if pocket.id == id then
            return pocket
        end
    end
    return nil
end

local function markUsed(used, x, y)
    used[tileKey(x, y)] = true
end

local function tileOpen(spec, used, x, y)
    if not (spec and spec.board and x and y and x >= 1 and y >= 1 and x <= spec.board.width and y <= spec.board.height) then
        return false
    end
    local tile = (spec.board.tiles or {})[tileKey(x, y)] or {}
    return not used[tileKey(x, y)] and tile.blocker ~= true
end

local function enemySpawnTile(spec, spawnPocketId, index, used)
    local pocket = spawnPocketById(spec, spawnPocketId)
    local tiles = pocket and pocket.tiles or {}
    if #tiles > 0 then
        for offset = 0, #tiles - 1 do
            local tile = tiles[((index + offset - 1) % #tiles) + 1]
            if tile and tileOpen(spec, used, tile.x, tile.y) then
                markUsed(used, tile.x, tile.y)
                return tile
            end
        end
    end
    for x = spec.board.width, 1, -1 do
        for y = 1, spec.board.height do
            if tileOpen(spec, used, x, y) then
                markUsed(used, x, y)
                return { x = x, y = y }
            end
        end
    end
    error("no open enemy spawn tile", 2)
end

local function applyEncounterUnits(spec, director)
    local units = {}
    local used = {}
    for _, unit in ipairs(spec.units or {}) do
        if unit.side ~= "enemy" then
            units[#units + 1] = unit
            markUsed(used, unit.x, unit.y)
        end
    end
    for index, enemy in ipairs(director.enemyMix or {}) do
        local tile = enemySpawnTile(spec, enemy.spawnPocket, index, used)
        units[#units + 1] = {
            id = enemy.id,
            name = enemy.name,
            kind = enemy.kind or enemy.id,
            side = "enemy",
            role = enemy.role,
            archetype = enemy.archetype,
            ai = copyValue(enemy.ai),
            boardVerb = enemy.boardVerb,
            spawnPocket = enemy.spawnPocket,
            intentType = enemy.intentType,
            intent = copyValue(enemy.intent),
            statusEffect = copyValue(enemy.statusEffect),
            partialIntent = copyValue(enemy.partialIntent),
            maskedIntent = copyValue(enemy.maskedIntent),
            weakPoints = copyValue(enemy.weakPoints),
            terrainInteraction = enemy.terrainInteraction,
            x = tile.x,
            y = tile.y,
            hp = enemy.hp or 4,
        }
    end
    spec.units = units
end

local function enemyEntry(enemy, role, spawnPocket)
    local intent = enemy.maskedIntent or enemy.exactIntent or enemy.partialIntent
    return {
        id = enemy.id,
        name = enemy.name,
        kind = enemy.id,
        archetype = enemy.archetype,
        role = role,
        spawnPocket = spawnPocket,
        ai = copyValue(enemy.ai),
        intent = copyValue(intent),
        intentType = intent and intent.intentType,
        statusEffect = copyValue(intent and intent.statusEffect),
        partialIntent = copyValue(enemy.partialIntent),
        maskedIntent = copyValue(enemy.maskedIntent),
        weakPoints = copyValue(enemy.weakPoints),
        terrainInteraction = enemy.terrainInteraction,
        boardVerb = enemy.boardVerb or enemy.waterPressureVerb or enemy.heatAshGlassVerb or enemy.terrainInteraction,
    }
end

local function applyAlphaTerrain(spec, alpha)
    if not (spec and spec.board and spec.board.tiles and alpha and alpha.terrainInteraction) then
        return nil
    end
    local objective = spec.objectives and spec.objectives[1] or { x = spec.board.width - 1, y = math.floor((spec.board.height + 1) / 2) }
    local components = spec.grammar and spec.grammar.components or {}
    local blockers = {}
    local blockerX = math.max(1, objective.x - 1)
    local occupied = {}
    for _, unit in ipairs(spec.units or {}) do
        occupied[tileKey(unit.x, unit.y)] = true
    end
    local function reachableWithBlock(blockX, blockY)
        local from = objective.evacuateAt
        if not (from and from.x and from.y) then
            return true
        end
        local queue = { { x = from.x, y = from.y } }
        local seen = { [tileKey(from.x, from.y)] = true }
        local index = 1
        while queue[index] do
            local node = queue[index]
            index = index + 1
            if node.x == objective.x and node.y == objective.y then
                return true
            end
            for _, delta in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
                local x, y = node.x + delta[1], node.y + delta[2]
                local key = tileKey(x, y)
                local tile = spec.board.tiles[key]
                if tile and not seen[key] and not (x == blockX and y == blockY) and tile.blocker ~= true then
                    seen[key] = true
                    queue[#queue + 1] = { x = x, y = y }
                end
            end
        end
        return false
    end
    local candidateRows = { objective.y - 1, objective.y + 1, objective.y - 2, objective.y + 2, objective.y }
    local blockerCandidates = {}
    local seenCandidates = {}
    local function addBlockerCandidate(x, y)
        local key = tileKey(x, y)
        if x >= 1 and y >= 1 and x <= spec.board.width and y <= spec.board.height and not seenCandidates[key] and not (x == objective.x and y == objective.y) then
            seenCandidates[key] = true
            blockerCandidates[#blockerCandidates + 1] = { x = x, y = y }
        end
    end
    for _, y in ipairs(candidateRows) do
        addBlockerCandidate(blockerX, y)
    end
    addBlockerCandidate(math.max(1, blockerX - 1), objective.y)
    addBlockerCandidate(math.min(spec.board.width, blockerX + 1), objective.y)
    for pass = 1, 2 do
        for _, ref in ipairs(blockerCandidates) do
            if #blockers >= 2 then
                break
            end
            local tile = spec.board.tiles[tileKey(ref.x, ref.y)]
            local key = tileKey(ref.x, ref.y)
            local openEnough = tile and tile.kind ~= "wall" and tile.blocker ~= true and not tile.objective and not occupied[key] and reachableWithBlock(ref.x, ref.y)
            if pass == 2 and tile and not tile.objective and (tile.kind == "wall" or tile.blocker == true) then
                openEnough = not occupied[key]
            end
            if openEnough then
                tile.kind = "warden_shelf_blocker"
                tile.blockerKind = "mobile"
                tile.blocker = true
                tile.losBlocker = true
                tile.destructibleHp = 3
                tile.terrainInteraction = alpha.terrainInteraction
                tile.alphaTerrain = alpha.id
                addTag(tile, "alpha_terrain")
                addTag(tile, "shelf_warden")
                blockers[#blockers + 1] = { x = ref.x, y = ref.y, interaction = alpha.terrainInteraction }
            end
        end
    end
    local lane = {}
    for x = math.max(1, objective.x - 3), objective.x do
        local tile = spec.board.tiles[tileKey(x, objective.y)]
        if tile and tile.kind ~= "wall" then
            tile.hazard = { kind = "warden_audit_beam", damage = 1, timing = "alpha_spawn_turn", alpha = alpha.id }
            addTag(tile, "alpha_audit_beam")
            lane[#lane + 1] = { x = x, y = objective.y }
        end
    end
    components.alphaTerrain = {
        { id = alpha.id .. "_terrain", enemy = alpha.id, interaction = alpha.terrainInteraction, blockers = blockers, hazardLane = { kind = "warden_audit_beam", tiles = lane }, deterministic = true },
    }
    spec.alphaTerrain = copyValue(components.alphaTerrain[1])
    return spec.alphaTerrain
end

local function poolIndex(seed, offset, count)
    return ((seed + offset - 1) % count) + 1
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

function Procgen.terrainTypes()
    return copyValue(terrainTypes)
end

function Procgen.generationTechniques()
    return copyValue(generationTechniques)
end

function Procgen.hybridProfiles()
    local result = {}
    for _, id in ipairs({ "spires", "sprawl", "open_wilds", "rooms_mines", "mixed_archive" }) do
        result[#result + 1] = copyValue(hybridProfiles[id])
    end
    return result
end

function Procgen.hazardKinds()
    return copyValue(hazardKinds)
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

function Procgen.archiveRoute()
    return copyValue(archiveRoute)
end

function Procgen.archiveRouteVariants()
    local result = {}
    for _, variantId in ipairs(archiveRouteVariantOrder) do
        result[#result + 1] = copyValue(archiveRouteVariants[variantId])
    end
    return result
end

function Procgen.archiveRouteVariant(variantId)
    local variant = archiveRouteVariants[variantId]
    return variant and copyValue(variant) or nil
end

function Procgen.directEncounter(zoneId, seed, boardSpec, options)
    options = options or {}
    local familyId = zoneEnemyFamilies[zoneId]
    local family = EnemyCatalog.family(familyId)
    if not family then
        error("unknown encounter director zone " .. tostring(zoneId), 2)
    end
    local common = EnemyCatalog.common(familyId)
    local elites = EnemyCatalog.elites(familyId)
    local alpha = options.includeAlpha and EnemyCatalog.alpha(familyId) or nil
    local first = pickIndexed(common, poolIndex(seed or 1, 1, #common))
    local second = pickIndexed(common, poolIndex(seed or 1, 6, #common))
    local elite = nil
    if options.includeElite then
        local rng = Rng.new((seed or 1) + 17017)
        local elitePool = elites
        if options.eliteIds then
            elitePool = {}
            for _, eliteId in ipairs(options.eliteIds) do
                local poolElite = EnemyCatalog.elite(familyId, eliteId)
                if not poolElite then
                    error("unknown elite " .. tostring(eliteId), 2)
                end
                elitePool[#elitePool + 1] = poolElite
            end
        end
        elite = options.eliteId and EnemyCatalog.elite(familyId, options.eliteId) or pickIndexed(elitePool, rng:range(1, #elitePool))
        if not elite then
            error("unknown elite " .. tostring(options.eliteId), 2)
        end
    end
    local objective = boardSpec and boardSpec.objectives and boardSpec.objectives[1] or nil
    local components = boardSpec and boardSpec.grammar and boardSpec.grammar.components or {}
    local enemySpawn = components.spawnPockets and components.spawnPockets[2] or { id = "enemy_pressure", tiles = {} }
    local playerSpawn = components.spawnPockets and components.spawnPockets[1] or { id = "player_entry", tiles = { { x = 1, y = 1 } } }
    local retreatFrom = objective and { x = objective.x, y = objective.y } or playerSpawn.tiles[1]
    local retreatTo = objective and objective.evacuateAt or playerSpawn.tiles[1]
    local enemyMix = {
        enemyEntry(first, "opening_pressure", enemySpawn.id),
        enemyEntry(second, "objective_pressure", enemySpawn.id),
    }
    if elite then
        enemyMix[#enemyMix + 1] = enemyEntry(elite, "partial_intent_pressure", enemySpawn.id)
    end
    local reinforcementTiming = {
        { turn = options.reinforcementTurn or 3 + ((seed or 1) % 2), enemy = pickIndexed(common, poolIndex(seed or 1, 12, #common)).id, spawnPocket = enemySpawn.id, visibleWarningTurn = 1, cap = 1, blockable = true, warning = "marked spawn pocket", onBlocked = "delay_one_turn_until_cap" },
    }
    local alphaSpawn = nil
    if alpha then
        local spawn = alpha.midRunSpawn or {}
        alphaSpawn = {
            turn = options.alphaTurn or spawn.turn or 4,
            enemy = alpha.id,
            role = spawn.role or "alpha_mid_run_elite",
            tier = "alpha",
            intentType = alpha.exactIntent and alpha.exactIntent.intentType,
            boardVerb = alpha.boardVerb,
            terrainInteraction = alpha.terrainInteraction,
            terrainMutation = copyValue(alpha.terrainMutation),
            spawnPocket = spawn.spawnPocket or enemySpawn.id,
            visibleWarningTurn = spawn.visibleWarningTurn or 2,
            cap = 1,
            blockable = spawn.blockable ~= false,
            warning = "Shelf Warden shifts archive shelves before entering",
            onBlocked = "delay_one_turn_until_cap",
        }
        reinforcementTiming[#reinforcementTiming + 1] = alphaSpawn
    end
    return {
        id = (zoneId or "unknown") .. "_director_v1",
        zone = zoneId,
        family = familyId,
        enemyMix = enemyMix,
        alphaSpawn = alphaSpawn,
        boss = options.bossId and { id = options.bossId, intent = "boss_stage_masks", objectiveKind = objective and objective.kind } or nil,
        intentDensity = {
            exact = 2,
            partial = elite and 1 or 0,
            alpha = alpha and 1 or 0,
            boss = options.bossId and 1 or 0,
            threatenedTiles = options.threatenedTiles or (elite and 6 or 4),
            cap = options.intentCap or 8,
        },
        objectivePressure = {
            objectiveId = objective and objective.id,
            objectiveKind = objective and objective.kind,
            startsTurn = 1,
            failureClock = options.failureClock or 3,
            visible = true,
        },
        reinforcementTiming = reinforcementTiming,
        spawnBlockRules = {
            { spawnPocket = enemySpawn.id, blocker = "unit_or_blocker_on_all_spawn_tiles", checked = "start_of_reinforcement_turn", onBlocked = "delay_one_turn_until_cap", cap = 1, visible = true, preview = "spawn pocket marks blocked tiles and delayed enemy" },
        },
        retreatRoutes = {
            { id = "route_to_entry", from = retreatFrom, to = retreatTo, tiles = pathTiles(retreatFrom, retreatTo), consequence = "retreat_costs_route_pressure" },
        },
    }
end

local function spawnPocketIds(spec)
    local ids = {}
    local pockets = spec and spec.grammar and spec.grammar.components and spec.grammar.components.spawnPockets or {}
    for _, pocket in ipairs(pockets) do
        ids[pocket.id] = true
    end
    return ids
end

function Procgen.auditReinforcementRules(spec)
    local report = { ok = true, missing = {}, invalid = {}, coverage = {} }
    local director = spec and spec.encounterDirector or spec
    local pockets = spawnPocketIds(spec)
    local blockRules = {}
    for _, rule in ipairs(director and director.spawnBlockRules or {}) do
        blockRules[rule.spawnPocket] = rule
    end
    for _, reinforcement in ipairs(director and director.reinforcementTiming or {}) do
        local id = reinforcement.spawnPocket or "unknown"
        report.coverage[id] = (report.coverage[id] or 0) + 1
        if not (reinforcement.turn and reinforcement.visibleWarningTurn and reinforcement.visibleWarningTurn < reinforcement.turn and reinforcement.enemy and reinforcement.spawnPocket) then
            table.insert(report.invalid, id .. ".reinforcement")
        end
        if reinforcement.blockable ~= true or not reinforcement.onBlocked then
            table.insert(report.invalid, id .. ".blockable")
        end
        if next(pockets) and not pockets[reinforcement.spawnPocket] then
            table.insert(report.invalid, id .. ".spawnPocket")
        end
        local rule = blockRules[reinforcement.spawnPocket]
        if not rule then
            table.insert(report.missing, id .. ".spawnBlockRule")
        elseif not (rule.blocker and rule.checked and rule.onBlocked and rule.visible == true and rule.preview) then
            table.insert(report.invalid, id .. ".spawnBlockRule")
        end
    end
    if not director or #(director.reinforcementTiming or {}) == 0 then
        table.insert(report.missing, "reinforcementTiming")
    end
    report.ok = #report.missing == 0 and #report.invalid == 0
    return report
end

function Procgen.difficultyBudget(spec, options)
    options = options or {}
    local grammarReport = Procgen.validateGrammarBoard(spec)
    local components = spec and spec.grammar and spec.grammar.components or {}
    local director = spec and spec.encounterDirector or nil
    local weights = RunCatalog.weights()
    local enemyCount = director and #(director.enemyMix or {}) or 0
    local objectiveCount = #(spec and spec.objectives or {})
    local hazardCount = #(components.hazardLanes or {})
    local coverCount = #(components.coverFields or {})
    local reinforcementCount = director and #(director.reinforcementTiming or {}) or 0
    local redactedCount = director and director.intentDensity and (director.intentDensity.partial or 0) or 0
    local bossCount = spec and spec.generator and spec.generator.objectiveKind == "boss_procedure" and 1 or 0
    local contributors = {
        enemies = enemyCount * weights.enemies,
        objectives = objectiveCount * weights.objectives,
        hazards = hazardCount * weights.hazards,
        cover = coverCount * weights.cover,
        reinforcements = reinforcementCount * weights.reinforcements,
        redactedIntent = redactedCount * weights.redactedIntent,
        bossModifiers = bossCount * weights.bossModifiers,
    }
    local total = 0
    for _, value in pairs(contributors) do
        total = total + value
    end
    local report = {
        accepted = true,
        total = total,
        max = options.max or 32,
        contributors = contributors,
        rejectReasons = {},
        grammar = grammarReport,
    }
    local function reject(reason)
        report.accepted = false
        report.rejectReasons[#report.rejectReasons + 1] = reason
    end
    if not grammarReport.valid then
        reject("grammar_invalid")
    end
    if objectiveCount == 0 then
        reject("objective_missing")
    end
    if coverCount == 0 then
        reject("cover_missing")
    end
    if director and director.intentDensity and (director.intentDensity.threatenedTiles or 0) > (director.intentDensity.cap or 0) then
        reject("intent_density_exceeded")
    end
    if director and (not director.retreatRoutes or not director.retreatRoutes[1] or #(director.retreatRoutes[1].tiles or {}) == 0) then
        reject("retreat_route_missing")
    end
    if director and #(director.reinforcementTiming or {}) > 0 and #(director.spawnBlockRules or {}) == 0 then
        reject("spawn_block_rule_missing")
    end
    if total > report.max then
        reject("budget_exceeded")
    end
    return report
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

local function clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

local function frac(value)
    return value - math.floor(value)
end

local function noise2(seed, x, y, salt)
    return frac(math.sin((x or 0) * 127.1 + (y or 0) * 311.7 + (seed or 1) * 74.7 + (salt or 0) * 19.19) * 43758.5453)
end

local function smoothNoise(seed, x, y, salt)
    local ix = math.floor(x)
    local iy = math.floor(y)
    local fx = x - ix
    local fy = y - iy
    local a = noise2(seed, ix, iy, salt)
    local b = noise2(seed, ix + 1, iy, salt)
    local c = noise2(seed, ix, iy + 1, salt)
    local d = noise2(seed, ix + 1, iy + 1, salt)
    fx = fx * fx * (3 - 2 * fx)
    fy = fy * fy * (3 - 2 * fy)
    local x1 = a + (b - a) * fx
    local x2 = c + (d - c) * fx
    return x1 + (x2 - x1) * fy
end

local function fbmNoise(seed, x, y, salt)
    local total = 0
    local amplitude = 0.5
    local frequency = 0.18
    local norm = 0
    for octave = 1, 4 do
        total = total + smoothNoise(seed + octave * 97, x * frequency, y * frequency, salt + octave * 13) * amplitude
        norm = norm + amplitude
        amplitude = amplitude * 0.5
        frequency = frequency * 2
    end
    return norm > 0 and total / norm or 0
end

local function hybridProfile(options)
    local id = (options and options.profile) or "mixed_archive"
    local profile = hybridProfiles[id] or hybridProfiles.mixed_archive
    return profile, profile.id
end

local function roomFromCenter(id, role, width, height, cx, cy, roomW, roomH, shape)
    roomW = clamp(math.floor(roomW + 0.5), 2, math.max(2, width - 1))
    roomH = clamp(math.floor(roomH + 0.5), 2, math.max(2, height - 1))
    local x = clamp(math.floor(cx - roomW * 0.5 + 0.5), 1, math.max(1, width - roomW + 1))
    local y = clamp(math.floor(cy - roomH * 0.5 + 0.5), 1, math.max(1, height - roomH + 1))
    return { id = id, role = role, x = x, y = y, width = roomW, height = roomH, shape = shape or "rect", center = { x = clamp(math.floor(cx + 0.5), 1, width), y = clamp(math.floor(cy + 0.5), 1, height) } }
end

local function hybridRoomPlan(profile, width, height, rng)
    local rooms = {}
    local scale = profile.roomScale or 1
    local baseW = clamp(math.floor(width * 0.18 * scale + 0.5), 2, 5)
    local baseH = clamp(math.floor(height * 0.24 * scale + 0.5), 2, 5)
    local function add(id, role, fx, fy, w, h, shape)
        rooms[#rooms + 1] = roomFromCenter(id, role, width, height, width * fx, height * fy, w or baseW, h or baseH, shape)
    end
    if profile.id == "spires" then
        add("entry_platform", "squad_spawn", 0.16, 0.58, baseW, baseH, "platform")
        add("lower_spire", "ascent", 0.34, 0.34, baseW, baseH, "platform")
        add("mid_bridge_spire", "bridge_hub", 0.55, 0.66, baseW, baseH, "platform")
        add("objective_spire", "objective_pressure", 0.84, 0.42, baseW, baseH, "platform")
    elseif profile.id == "sprawl" then
        add("entry_hub", "squad_spawn", 0.14, 0.55, baseW, baseH, "rect")
        add("north_loop", "branch", 0.36, 0.28, baseW, baseH, "rect")
        add("south_loop", "branch", 0.38, 0.76, baseW, baseH, "rect")
        add("central_hub", "hub", 0.58, 0.52, baseW + 1, baseH, "rect")
        add("upper_shortcut", "shortcut", 0.74, 0.24, baseW, baseH, "rect")
        add("objective_hub", "objective_pressure", 0.86, 0.62, baseW, baseH, "rect")
    elseif profile.id == "open_wilds" then
        add("entry_edge", "squad_spawn", 0.12, 0.52, baseW, baseH, "open")
        add("open_field", "field", 0.46, 0.5, math.max(baseW + 2, math.floor(width * 0.34)), math.max(baseH + 2, math.floor(height * 0.42)), "open")
        add("objective_outcrop", "objective_pressure", 0.86, 0.5, baseW + 1, baseH, "open")
    elseif profile.id == "rooms_mines" then
        add("entry_room", "squad_spawn", 0.14, 0.52, baseW, baseH, "rect")
        add("upper_pocket", "mine_room", 0.32, 0.28, baseW, baseH, "rect")
        add("lower_pocket", "mine_room", 0.48, 0.68, baseW, baseH, "rect")
        add("claim_pocket", "mine_room", 0.68, 0.38, baseW, baseH, "rect")
        add("objective_room", "objective_pressure", 0.86, 0.56, baseW, baseH, "rect")
    else
        add("entry_room", "squad_spawn", 0.12, 0.52, baseW, baseH, "rect")
        add("mine_branch", "mine_room", 0.3, 0.28, baseW, baseH, "rect")
        add("open_archive", "field", 0.48, 0.58, baseW + 2, baseH + 1, "open")
        add("spire_stack", "ascent", 0.63, 0.28, baseW, baseH, "platform")
        add("side_archive", "branch", 0.75, 0.72, baseW, baseH, "rect")
        add("objective_room", "objective_pressure", 0.88, 0.5, baseW, baseH, "rect")
    end
    return rooms
end

local function newHybridContext(seed, options, profile, profileId)
    local width = options.width or (profileId == "open_wilds" and 24 or profileId == "sprawl" and 22 or 16)
    local height = options.height or (profileId == "open_wilds" and 18 or 16)
    requireSize(width, height)
    local ctx = {
        seed = seed or 1,
        rng = Rng.new(seed or 1),
        profile = profile,
        profileId = profileId,
        width = width,
        height = height,
        material = options.material or "archive",
        zone = options.zone,
        generatorId = options.generatorId or "hybrid_generator_v1",
        objectiveId = options.objectiveId or "route_machine",
        objectiveKind = options.objectiveKind or "protect_route_machinery",
        objectiveIntegrity = options.objectiveIntegrity or 3,
        hazardKind = options.hazardKind or hazardKinds[((seed or 1) % #hazardKinds) + 1],
        tiles = {},
        playable = {},
        critical = {},
        reserved = {},
        criticalPath = {},
        corridors = {},
        rooms = {},
        noiseFields = {},
        wfcTiles = {},
        cellularMines = {},
        repairs = {},
    }
    for x = 1, width do
        for y = 1, height do
            ctx.tiles[tileKey(x, y)] = { kind = "wall", material = ctx.material, blockerKind = "hard", blocker = true, losBlocker = true, terrainType = "sealed_void", tags = { "sealed_void" } }
        end
    end
    return ctx
end

local function carveHybridTile(ctx, x, y, tag, critical)
    if not (x >= 1 and y >= 1 and x <= ctx.width and y <= ctx.height) then
        return nil
    end
    local tile = carve(ctx.tiles, x, y, ctx.material, tag or "hybrid_playable")
    ctx.playable[tileKey(x, y)] = true
    if critical then
        ctx.critical[tileKey(x, y)] = true
        ctx.criticalPath[#ctx.criticalPath + 1] = { x = x, y = y }
    end
    return tile
end

local function carveHybridBrush(ctx, x, y, radius, tag, critical)
    local refs = {}
    radius = radius or 0
    for dx = -radius, radius do
        for dy = -radius, radius do
            if math.abs(dx) + math.abs(dy) <= radius then
                local tile = carveHybridTile(ctx, x + dx, y + dy, tag, critical)
                if tile then
                    refs[#refs + 1] = { x = x + dx, y = y + dy }
                end
            end
        end
    end
    return refs
end

local function carveHybridRooms(ctx, rooms)
    for _, room in ipairs(rooms) do
        room.tiles = {}
        for x = room.x, room.x + room.width - 1 do
            for y = room.y, room.y + room.height - 1 do
                local dx = math.abs((x + 0.5) - room.center.x) / math.max(1, room.width * 0.5)
                local dy = math.abs((y + 0.5) - room.center.y) / math.max(1, room.height * 0.5)
                local keep = room.shape == "rect" or (dx + dy <= 1.35) or noise2(ctx.seed, x, y, 31) > 0.36
                if keep then
                    carveHybridTile(ctx, x, y, room.role)
                    room.tiles[#room.tiles + 1] = { x = x, y = y }
                end
            end
        end
        ctx.rooms[#ctx.rooms + 1] = room
    end
end

local function carveHybridPath(ctx, fromRoom, toRoom, id, width)
    local from = fromRoom.center
    local to = toRoom.center
    local refs = {}
    local path = pathTiles(from, to)
    local radius = math.max(0, math.floor((width or 1) / 2))
    for _, ref in ipairs(path) do
        local brushed = carveHybridBrush(ctx, ref.x, ref.y, radius, "corridor", true)
        for _, tile in ipairs(brushed) do
            refs[#refs + 1] = tile
        end
    end
    ctx.corridors[#ctx.corridors + 1] = { id = id, from = fromRoom.id, to = toRoom.id, width = width or 1, tiles = refs }
end

local function carveHybridGraph(ctx)
    for index = 1, #ctx.rooms - 1 do
        carveHybridPath(ctx, ctx.rooms[index], ctx.rooms[index + 1], "critical_" .. tostring(index), ctx.profile.corridorWidth)
    end
    if #ctx.rooms >= 4 and (ctx.profile.branchChance or 0) > 0.5 then
        carveHybridPath(ctx, ctx.rooms[2], ctx.rooms[#ctx.rooms - 1], "loop_shortcut", math.max(1, ctx.profile.corridorWidth - 1))
    end
    if ctx.profileId == "sprawl" and #ctx.rooms >= 6 then
        carveHybridPath(ctx, ctx.rooms[3], ctx.rooms[6], "sprawl_reconnect", 1)
    end
end

local function carveHybridOpenNoise(ctx)
    if ctx.profile.openNoise >= 0.86 then
        return
    end
    for x = 2, ctx.width - 1 do
        for y = 2, ctx.height - 1 do
            local value = fbmNoise(ctx.seed, x, y, 41)
            if value > ctx.profile.openNoise then
                carveHybridTile(ctx, x, y, "open_field_noise")
                ctx.noiseFields[#ctx.noiseFields + 1] = { id = "open_" .. tostring(#ctx.noiseFields + 1), kind = "open_field", x = x, y = y, value = value }
            end
        end
    end
end

local function carveHybridMines(ctx)
    if not (ctx.profileId == "rooms_mines" or ctx.profileId == "mixed_archive") then
        return
    end
    for branch = 1, 3 do
        local room = ctx.rooms[((branch * 2 - 1) % #ctx.rooms) + 1]
        local x, y = room.center.x, room.center.y
        local refs = {}
        for step = 1, math.max(8, math.floor((ctx.width + ctx.height) * 0.45)) do
            refs[#refs + 1] = { x = x, y = y }
            carveHybridTile(ctx, x, y, "cellular_mine")
            local direction = ctx.rng:range(1, 4)
            x = clamp(x + (direction == 1 and 1 or direction == 2 and -1 or 0), 2, ctx.width - 1)
            y = clamp(y + (direction == 3 and 1 or direction == 4 and -1 or 0), 2, ctx.height - 1)
        end
        ctx.cellularMines[#ctx.cellularMines + 1] = { id = "mine_worm_" .. tostring(branch), tiles = refs }
    end
end

local function applyHybridNoise(ctx)
    local minHeight, maxHeight, noiseSamples, voidTiles = nil, nil, 0, 0
    for x = 1, ctx.width do
        for y = 1, ctx.height do
            local tile = ctx.tiles[tileKey(x, y)]
            local heightValue = fbmNoise(ctx.seed, x, y, 53)
            local voidValue = fbmNoise(ctx.seed, x, y, 67)
            if ctx.playable[tileKey(x, y)] and tile.blocker ~= true then
                local height = math.floor(heightValue * ((ctx.profile.maxHeight or 2) + 1))
                tile.height = height
                minHeight = minHeight and math.min(minHeight, height) or height
                maxHeight = maxHeight and math.max(maxHeight, height) or height
                noiseSamples = noiseSamples + 1
                stampTerrain(tile, height > 0 and "archive_terrace" or "archive_floor")
                addTag(tile, "noise_heightfield")
            elseif voidValue > (ctx.profileId == "spires" and 0.56 or 0.78) then
                stampTerrain(tile, "archive_chasm")
                addTag(tile, "noise_void")
                voidTiles = voidTiles + 1
            end
        end
    end
    ctx.noiseFields[#ctx.noiseFields + 1] = { id = "heightfield", kind = "noise_heightfield", samples = noiseSamples, minHeight = minHeight or 0, maxHeight = maxHeight or 0, voidTiles = voidTiles }
end

local function sortedPlayable(ctx)
    local refs = {}
    for key in pairs(ctx.playable) do
        local x, y = key:match("^(%-?%d+):(%-?%d+)$")
        refs[#refs + 1] = { x = tonumber(x), y = tonumber(y), key = key }
    end
    table.sort(refs, function(a, b)
        if a.y == b.y then
            return a.x < b.x
        end
        return a.y < b.y
    end)
    return refs
end

local function safeMotifTile(ctx, ref)
    local tile = ctx.tiles[tileKey(ref.x, ref.y)]
    local key = tileKey(ref.x, ref.y)
    return tile and tile.blocker ~= true and not tile.objective and not ctx.critical[key] and not ctx.reserved[key]
end

local function placeCover(ctx, components, ref, id)
    local tile = ctx.tiles[tileKey(ref.x, ref.y)]
    if not tile then
        return false
    end
    applyCover(tile, { west = "half", north = (ref.x + ref.y) % 2 == 0 and "half" or nil })
    addTag(tile, "cover_field")
    components.coverFields[#components.coverFields + 1] = { id = id, x = ref.x, y = ref.y, coverEdges = copyValue(tile.coverEdges), height = tile.height or 0 }
    ctx.wfcTiles[#ctx.wfcTiles + 1] = { id = id, motif = "cover_edge", x = ref.x, y = ref.y }
    return true
end

local function placeSightBreak(ctx, components, ref, id)
    if not safeMotifTile(ctx, ref) then
        return false
    end
    local tile = ctx.tiles[tileKey(ref.x, ref.y)]
    stampTerrain(tile, "rolling_shelf")
    tile.kind = "rolling_shelf"
    tile.blockerKind = "destructible"
    tile.blocker = true
    tile.losBlocker = true
    tile.destructibleHp = 2
    addTag(tile, "sight_break")
    components.sightBreaks[#components.sightBreaks + 1] = { id = id, x = ref.x, y = ref.y, destructibleHp = 2 }
    ctx.wfcTiles[#ctx.wfcTiles + 1] = { id = id, motif = "destructible_shelf", x = ref.x, y = ref.y }
    return true
end

local function placeSpecialTerrain(ctx, components, ref, id, terrainType)
    if not safeMotifTile(ctx, ref) then
        return false
    end
    local tile = ctx.tiles[tileKey(ref.x, ref.y)]
    stampTerrain(tile, terrainType)
    addTag(tile, "special_terrain")
    components.specialTerrain[#components.specialTerrain + 1] = { id = id, terrainType = terrainType, x = ref.x, y = ref.y }
    ctx.wfcTiles[#ctx.wfcTiles + 1] = { id = id, motif = terrainType, x = ref.x, y = ref.y }
    return true
end

local function repairHybridPathHeights(ctx, components)
    local previous = nil
    local routeTiles = {}
    for _, ref in ipairs(ctx.criticalPath) do
        local tile = ctx.tiles[tileKey(ref.x, ref.y)]
        if tile and tile.blocker ~= true then
            if previous then
                local prevTile = ctx.tiles[tileKey(previous.x, previous.y)]
                local delta = (tile.height or 0) - (prevTile.height or 0)
                if math.abs(delta) > 1 then
                    tile.height = (prevTile.height or 0) + (delta > 0 and 1 or -1)
                    ctx.repairs[#ctx.repairs + 1] = { id = "height_step_" .. tostring(#ctx.repairs + 1), x = ref.x, y = ref.y, reason = "clamp_path_height_delta" }
                end
                if (tile.height or 0) ~= (prevTile.height or 0) then
                    stampTerrain(tile, "archive_stair")
                    stampTerrain(prevTile, "archive_stair")
                    addTag(tile, "vertical_route")
                    addTag(prevTile, "vertical_route")
                    components.verticalRoutes[#components.verticalRoutes + 1] = { id = "stair_" .. tostring(#components.verticalRoutes + 1), kind = (tile.height or 0) > (prevTile.height or 0) and "ascend" or "descend", fromHeight = prevTile.height or 0, toHeight = tile.height or 0, tiles = { { x = previous.x, y = previous.y }, { x = ref.x, y = ref.y } } }
                end
            end
            routeTiles[#routeTiles + 1] = { x = ref.x, y = ref.y }
            previous = ref
        end
    end
    if #routeTiles > 0 then
        components.heightBands[#components.heightBands + 1] = { id = "noise_route_band", height = "mixed", tiles = routeTiles }
    end
end

local function ensureHybridPath(ctx, from, to)
    local queue = { { x = from.x, y = from.y } }
    local seen = { [tileKey(from.x, from.y)] = true }
    local index = 1
    while queue[index] do
        local node = queue[index]
        index = index + 1
        if node.x == to.x and node.y == to.y then
            return true
        end
        for _, offset in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
            local nx, ny = node.x + offset[1], node.y + offset[2]
            local key = tileKey(nx, ny)
            local tile = ctx.tiles[key]
            if tile and not seen[key] and tile.blocker ~= true then
                seen[key] = true
                queue[#queue + 1] = { x = nx, y = ny }
            end
        end
    end
    for _, ref in ipairs(pathTiles(from, to)) do
        carveHybridTile(ctx, ref.x, ref.y, "repair_path", true)
    end
    ctx.repairs[#ctx.repairs + 1] = { id = "reachability_repair", from = copyValue(from), to = copyValue(to) }
    return false
end

local function applyHybridMotifs(ctx, components)
    local refs = sortedPlayable(ctx)
    local coverPlaced = 0
    local sightPlaced = 0
    local specialPlaced = 0
    for index, ref in ipairs(refs) do
        if safeMotifTile(ctx, ref) and coverPlaced < 4 and index % 5 == 0 then
            coverPlaced = coverPlaced + (placeCover(ctx, components, ref, "hybrid_cover_" .. tostring(coverPlaced + 1)) and 1 or 0)
        elseif safeMotifTile(ctx, ref) and sightPlaced < 2 and index % 7 == 0 then
            sightPlaced = sightPlaced + (placeSightBreak(ctx, components, ref, "hybrid_shelf_" .. tostring(sightPlaced + 1)) and 1 or 0)
        elseif safeMotifTile(ctx, ref) and specialPlaced < 4 and index % 6 == 0 then
            local specialIds = ctx.profileId == "open_wilds" and { "brine_pool", "mirror_glass", "archive_rubble", "archive_glass_floor" } or { "archive_rubble", "archive_glass_floor", "mirror_glass", "archive_chasm" }
            specialPlaced = specialPlaced + (placeSpecialTerrain(ctx, components, ref, "hybrid_special_" .. tostring(specialPlaced + 1), specialIds[(specialPlaced % #specialIds) + 1]) and 1 or 0)
        end
    end
    if coverPlaced == 0 then
        for _, ref in ipairs(refs) do
            if safeMotifTile(ctx, ref) and placeCover(ctx, components, ref, "hybrid_cover_fallback") then
                coverPlaced = 1
                break
            end
        end
    end
    if sightPlaced == 0 then
        for _, ref in ipairs(refs) do
            if safeMotifTile(ctx, ref) and placeSightBreak(ctx, components, ref, "hybrid_shelf_fallback") then
                sightPlaced = 1
                break
            end
        end
    end
    local hazardTiles = {}
    local maxHazards = clamp(math.floor(#ctx.criticalPath * 0.18), 2, 6)
    for index, ref in ipairs(ctx.criticalPath) do
        if #hazardTiles < maxHazards and index > 2 and index % 3 == 0 then
            local tile = ctx.tiles[tileKey(ref.x, ref.y)]
            if tile and tile.blocker ~= true and not tile.objective then
                local terrainTypeId = ctx.hazardKind == "paper_cinder" and "paper_cinder_lane" or (ctx.hazardKind == "index_miasma" and "index_miasma" or "audit_static_lane")
                stampTerrain(tile, terrainTypeId)
                addTag(tile, "hazard_lane")
                hazardTiles[#hazardTiles + 1] = { x = ref.x, y = ref.y }
            end
        end
    end
    components.hazardLanes[#components.hazardLanes + 1] = { id = "hybrid_hazard_lane", kind = ctx.hazardKind, tiles = hazardTiles }
    components.wfcTiles = copyValue(ctx.wfcTiles)
    components.noiseFields = copyValue(ctx.noiseFields)
    components.cellularMines = copyValue(ctx.cellularMines)
end

local function spawnTilesFor(ctx, room, count)
    local tiles = {}
    for _, ref in ipairs(room.tiles or {}) do
        local tile = ctx.tiles[tileKey(ref.x, ref.y)]
        if tile and tile.blocker ~= true then
            tiles[#tiles + 1] = { x = ref.x, y = ref.y }
            if #tiles >= count then
                return tiles
            end
        end
    end
    tiles[#tiles + 1] = copyValue(room.center)
    return tiles
end

local function finalizeHybridSpec(ctx, options)
    local entryRoom = ctx.rooms[1]
    local objectiveRoom = ctx.rooms[#ctx.rooms]
    local playerTiles = spawnTilesFor(ctx, entryRoom, 6)
    local enemyTiles = spawnTilesFor(ctx, objectiveRoom, 4)
    local objective = { id = ctx.objectiveId, kind = ctx.objectiveKind, x = objectiveRoom.center.x, y = objectiveRoom.center.y, integrity = ctx.objectiveIntegrity, maxIntegrity = ctx.objectiveIntegrity, evacuateAt = copyValue(playerTiles[1]) }
    carveHybridTile(ctx, objective.x, objective.y, "objective_anchor", true)
    for _, ref in ipairs(playerTiles) do
        ctx.reserved[tileKey(ref.x, ref.y)] = true
    end
    for _, ref in ipairs(enemyTiles) do
        ctx.reserved[tileKey(ref.x, ref.y)] = true
    end
    ctx.reserved[tileKey(objective.x, objective.y)] = true
    local objectiveTile = ctx.tiles[tileKey(objective.x, objective.y)]
    objectiveTile.objective = { id = objective.id, kind = objective.kind }
    ensureHybridPath(ctx, playerTiles[1], objective)
    local components = {
        rooms = copyValue(ctx.rooms),
        corridors = copyValue(ctx.corridors),
        heightBands = {},
        coverFields = {},
        sightBreaks = {},
        verticalRoutes = {},
        objectiveAnchors = { objective },
        hazardLanes = {},
        spawnPockets = {
            { id = "player_entry", side = "player", tiles = playerTiles },
            { id = "enemy_pressure", side = "enemy", tiles = enemyTiles },
        },
        specialTerrain = {},
        repairs = ctx.repairs,
    }
    repairHybridPathHeights(ctx, components)
    applyHybridMotifs(ctx, components)
    components.terrainTypes = terrainTypesUsedByTiles(ctx.tiles)
    components.generationTechniques = componentListByIds(generationTechniqueById, ctx.profile.techniques)
    local spec = {
        seed = ctx.seed,
        zone = ctx.zone,
        generator = {
            id = ctx.generatorId,
            zone = ctx.zone,
            material = ctx.material,
            profile = ctx.profileId,
            pipeline = { "macro_graph", "noise_fields", "wfc_tile_dressing", "repair_validation" },
            objectiveKind = ctx.objectiveKind,
            hazardKind = ctx.hazardKind,
        },
        grammar = {
            id = "hybrid_board_grammar_v1",
            components = components,
        },
        board = { width = ctx.width, height = ctx.height, tiles = ctx.tiles, profile = ctx.profileId, terrainTypes = components.terrainTypes, generationTechniques = components.generationTechniques, heightBands = components.heightBands, coverFields = components.coverFields, sightBreaks = components.sightBreaks, verticalRoutes = components.verticalRoutes },
        units = {
            { id = "warden", side = "player", x = playerTiles[1].x, y = playerTiles[1].y, hp = 6 },
            { id = "duelist", side = "player", x = (playerTiles[2] or playerTiles[1]).x, y = (playerTiles[2] or playerTiles[1]).y, hp = 5 },
            { id = "claimant", side = "enemy", x = enemyTiles[1].x, y = enemyTiles[1].y, hp = 4 },
        },
        objectives = { objective },
    }
    spec.validation = Procgen.validateGrammarBoard(spec)
    return spec
end

function Procgen.generateHybridBoard(seed, options)
    options = options or {}
    local profile, profileId = hybridProfile(options)
    local ctx = newHybridContext(seed, options, profile, profileId)
    local rooms = hybridRoomPlan(profile, ctx.width, ctx.height, ctx.rng)
    carveHybridRooms(ctx, rooms)
    carveHybridGraph(ctx)
    carveHybridOpenNoise(ctx)
    carveHybridMines(ctx)
    applyHybridNoise(ctx)
    return finalizeHybridSpec(ctx, options)
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
            tiles[tileKey(x, y)] = { kind = "wall", material = material, blockerKind = "hard", blocker = true, losBlocker = true, terrainType = "sealed_void", tags = { "sealed_void" } }
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
            stampTerrain(tile, band.height > 0 and "archive_terrace" or "archive_floor")
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
        stampTerrain(tile, "rolling_shelf")
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
        local terrainTypeId = hazardKind == "paper_cinder" and "paper_cinder_lane" or (hazardKind == "index_miasma" and "index_miasma" or "audit_static_lane")
        stampTerrain(tile, terrainTypeId)
        tile.hazard = tile.hazard or { kind = hazardKind, damage = 1, timing = "end_turn" }
        addTag(tile, "hazard_lane")
    end

    local specialTerrain = {}
    local function scatterTerrain(id, x, y)
        local key = tileKey(x, y)
        local tile = tiles[key]
        if tile and tile.kind ~= "wall" and not tile.objective and tile.blocker ~= true then
            stampTerrain(tile, id)
            specialTerrain[#specialTerrain + 1] = { id = id .. "_" .. tostring(#specialTerrain + 1), terrainType = id, x = x, y = y }
        end
    end
    scatterTerrain("archive_glass_floor", math.min(width - 2, 3), math.min(bottomY, roomY + 1))
    scatterTerrain("archive_rubble", math.min(width - 2, 3), bottomY)
    scatterTerrain("archive_chasm", math.min(width - 2, 3), roomY)

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
                terrainTypes = terrainTypesUsedByTiles(tiles),
                generationTechniques = componentListByIds(generationTechniqueById, { "rect_room_pair", "straight_spine_corridor", "terrace_height_bands", "destructible_sight_breaks", "hazard_lane_dressing", "special_terrain_scatter" }),
                specialTerrain = specialTerrain,
            },
        },
        board = { width = width, height = height, tiles = tiles, terrainTypes = terrainTypesUsedByTiles(tiles), generationTechniques = componentListByIds(generationTechniqueById, { "rect_room_pair", "straight_spine_corridor", "terrace_height_bands", "destructible_sight_breaks", "hazard_lane_dressing", "special_terrain_scatter" }) },
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
    if merged.profile or merged.hybrid then
        merged.profile = merged.profile or "mixed_archive"
        merged.generatorId = generator.id .. "_hybrid_v1"
        return Procgen.generateHybridBoard(seed, merged)
    end
    return Procgen.generateBoard(seed, merged)
end

function Procgen.zoneState(zoneId, seed, options)
    return State.new(Procgen.generateZoneBoard(zoneId, seed, options))
end

function Procgen.generateDirectedZoneBoard(zoneId, seed, options)
    options = options or {}
    local spec = Procgen.generateZoneBoard(zoneId, seed, options)
    if options.includeAlpha then
        applyAlphaTerrain(spec, EnemyCatalog.alpha(zoneEnemyFamilies[zoneId]))
    end
    spec.encounterDirector = Procgen.directEncounter(zoneId, seed, spec, options)
    applyEncounterUnits(spec, spec.encounterDirector)
    return spec
end

function Procgen.generateArchiveRouteBoard(variantId, seed, options)
    options = options or {}
    local variant = archiveVariantFor(variantId)
    local generatorOptions = mergeOptions(variant.generatorOptions, options.generatorOptions)
    local directorOptions = mergeOptions(variant.directorOptions, options.directorOptions)
    local merged = mergeOptions(generatorOptions, directorOptions)
    if options.includeElite ~= nil then
        merged.includeElite = options.includeElite
    end
    local boardSeed = seed or variant.seed
    local spec = Procgen.generateDirectedZoneBoard("buried_archive", boardSeed, merged)
    spec.generator.variantId = variant.id
    spec.generator.template = variant.template
    spec.generator.routeId = archiveRouteId
    spec.archiveRoute = {
        id = archiveRouteId,
        zone = "buried_archive",
        variantId = variant.id,
        nodeKind = variant.nodeKind,
        template = variant.template,
        routeDepth = variant.routeDepth,
        boardSeed = boardSeed,
        reward = copyValue(variant.reward),
        complication = variant.complication,
        preview = variant.preview,
        bossId = variant.bossId,
    }
    spec.validation = Procgen.validateGrammarBoard(spec)
    spec.budget = Procgen.difficultyBudget(spec)
    if not RunCatalog.boardTemplate(variant.template) then
        error("unknown archive route template " .. tostring(variant.template), 2)
    end
    return spec
end

local archiveExpansePlacements = {
    archive_entry_audit = { x = 0, y = 0 },
    archive_shelf_protection = { x = 10, y = 0 },
    archive_proof_extract = { x = 21, y = 1 },
    archive_ledger_repair = { x = 5, y = 10 },
    archive_sealed_shortcut = { x = 17, y = 10 },
    archive_vault_regent_final = { x = 23, y = 15 },
}

local function openExpanseTile(tiles, x, y, material, kind, height, tag)
    local tile = tiles[tileKey(x, y)] or { kind = "wall", material = material, blocker = true, losBlocker = true, tags = { "sealed_mass" } }
    tile.kind = kind or "floor"
    tile.material = material
    tile.blockerKind = nil
    tile.blocker = false
    tile.losBlocker = false
    tile.height = height or tile.height or 0
    tile.tags = tile.tags or {}
    clearSealedTags(tile)
    if kind == "archive_chasm" then
        stampTerrain(tile, "archive_chasm")
    elseif kind == "brine_pool" then
        stampTerrain(tile, "brine_pool")
    elseif kind == "index_miasma" then
        stampTerrain(tile, "index_miasma")
    elseif kind == "mirror_glass" then
        stampTerrain(tile, "mirror_glass")
    elseif kind == "glass_floor" then
        stampTerrain(tile, "archive_glass_floor")
    elseif kind == "temple_stone" then
        stampTerrain(tile, "temple_stone")
    elseif kind == "sunken_water" then
        stampTerrain(tile, "sunken_water")
    elseif kind == "root_tangle" then
        stampTerrain(tile, "root_tangle")
    elseif kind == "root_screen" then
        stampTerrain(tile, "root_screen")
    elseif kind == "bell_stone" then
        stampTerrain(tile, "bell_stone")
    elseif kind == "ash_glass" then
        stampTerrain(tile, "ash_glass")
    elseif kind == "heat_vent" then
        stampTerrain(tile, "heat_vent")
    elseif kind == "ritual_pillar" then
        stampTerrain(tile, "ritual_pillar")
    elseif kind == "rubble" then
        stampTerrain(tile, "archive_rubble")
    else
        stampTerrain(tile, (height or 0) > 0 and "archive_terrace" or "archive_floor")
    end
    if tag then
        addTag(tile, tag)
    end
    tiles[tileKey(x, y)] = tile
    return tile
end

local function copyRegionSpecIntoExpanse(target, source, placement, variantId, firstRegion)
    local regions = target.regions
    local region = {
        id = variantId,
        x = placement.x + 1,
        y = placement.y + 1,
        width = source.board.width,
        height = source.board.height,
        objectives = {},
        enemies = {},
    }
    for key, tile in pairs(source.board.tiles or {}) do
        local x, y = key:match("^(%-?%d+):(%-?%d+)$")
        x, y = tonumber(x), tonumber(y)
        local tx, ty = placement.x + x, placement.y + y
        if tx >= 1 and ty >= 1 and tx <= target.width and ty <= target.height then
            local copied = copyValue(tile)
            copied.tags = copied.tags or {}
            addTag(copied, "route_region")
            addTag(copied, variantId)
            target.tiles[tileKey(tx, ty)] = copied
        end
    end
    for _, objective in ipairs(source.objectives or {}) do
        local copied = copyValue(objective)
        copied.x = placement.x + copied.x
        copied.y = placement.y + copied.y
        copied.evacuateAt = copied.evacuateAt and { x = placement.x + copied.evacuateAt.x, y = placement.y + copied.evacuateAt.y } or copied.evacuateAt
        copied.region = variantId
        target.objectives[#target.objectives + 1] = copied
        region.objectives[#region.objectives + 1] = copied.id
    end
    for _, unit in ipairs(source.units or {}) do
        local copied = copyValue(unit)
        copied.x = placement.x + copied.x
        copied.y = placement.y + copied.y
        copied.region = variantId
        if unit.side == "enemy" then
            copied.kind = copied.kind or unit.id
            if not firstRegion then
                copied.id = unit.id .. "__" .. variantId
                copied.alive = false
            end
            region.enemies[#region.enemies + 1] = copied.id
            target.units[#target.units + 1] = copied
        elseif firstRegion then
            target.units[#target.units + 1] = copied
        end
    end
    regions[#regions + 1] = region
end

local function carveExpanseCorridor(target, x1, y1, x2, y2, height)
    local xStep = x1 <= x2 and 1 or -1
    for x = x1, x2, xStep do
        openExpanseTile(target.tiles, x, y1, "archive", "floor", height or 0, "expanse_path")
    end
    local yStep = y1 <= y2 and 1 or -1
    for y = y1, y2, yStep do
        openExpanseTile(target.tiles, x2, y, "archive", "floor", height or 0, "expanse_path")
    end
end

local function expanseTileRefs(values)
    local result = {}
    for _, value in ipairs(values or {}) do
        result[#result + 1] = { x = value.x or value[1], y = value.y or value[2] }
    end
    return result
end

local function recordExpanseHeightBand(target, id, bandHeight, tiles)
    target.heightBands = target.heightBands or {}
    local refs = expanseTileRefs(tiles)
    target.heightBands[#target.heightBands + 1] = { id = id, height = bandHeight, tiles = refs }
    for _, ref in ipairs(refs) do
        local tile = target.tiles[tileKey(ref.x, ref.y)]
        if tile then
            addTag(tile, "height_band")
        end
    end
end

local function recordExpanseVerticalRoute(target, id, kind, fromHeight, toHeight, tiles)
    target.verticalRoutes = target.verticalRoutes or {}
    local refs = expanseTileRefs(tiles)
    target.verticalRoutes[#target.verticalRoutes + 1] = { id = id, kind = kind, fromHeight = fromHeight, toHeight = toHeight, tiles = refs }
    for _, ref in ipairs(refs) do
        local tile = target.tiles[tileKey(ref.x, ref.y)]
        if tile then
            addTag(tile, "vertical_route")
            addTag(tile, kind == "descend" and "descent_route" or "ascent_route")
            addTag(tile, "stair")
        end
    end
end

local function recordExpanseCoverField(target, id, x, y, coverEdges)
    target.coverFields = target.coverFields or {}
    local tile = target.tiles[tileKey(x, y)]
    if tile then
        tile.coverEdges = coverEdges
        addTag(tile, "cover_field")
        if (tile.height or 0) >= 2 then
            addTag(tile, "high_cover")
        end
    end
    target.coverFields[#target.coverFields + 1] = { id = id, x = x, y = y, coverEdges = copyValue(coverEdges), height = tile and tile.height or 0 }
end

local function recordExpanseSightline(target, id, fromTile, toTile, tiles)
    target.sightlines = target.sightlines or {}
    target.sightlines[#target.sightlines + 1] = { id = id, from = copyValue(fromTile), to = copyValue(toTile), tiles = expanseTileRefs(tiles) }
end

local function recordExpanseSightBreak(target, id, x, y, destructibleHp)
    target.sightBreaks = target.sightBreaks or {}
    target.sightBreaks[#target.sightBreaks + 1] = { id = id, x = x, y = y, destructibleHp = destructibleHp }
    local tile = target.tiles[tileKey(x, y)]
    if tile then
        addTag(tile, "sight_break")
    end
end

local function recordMegastructureTile(target, groupId, tile, x, y)
    target.megaStructures = target.megaStructures or {}
    target.megaStructureById = target.megaStructureById or {}
    local group = target.megaStructureById[groupId]
    if not group then
        group = { id = groupId, tiles = {} }
        target.megaStructureById[groupId] = group
        target.megaStructures[#target.megaStructures + 1] = group
    end
    group.tiles[#group.tiles + 1] = { x = x, y = y, height = tile.height or 0, kind = tile.kind }
end

local function markExpanseMegastructure(target, groupId, x, y, height, kind)
    if not (target and target.tiles and x and y and x >= 1 and y >= 1 and x <= target.width and y <= target.height) then
        return false
    end
    local tile = target.tiles[tileKey(x, y)]
    if not (tile and tile.blocker == true) then
        return false
    end
    tile.kind = kind or "megastructure_rib"
    tile.material = "archive"
    tile.height = math.max(tile.height or 0, height or 6)
    tile.blockerKind = "hard"
    tile.blocker = true
    tile.losBlocker = true
    addTag(tile, "megastructure")
    addTag(tile, groupId)
    addTag(tile, kind or "structural_rib")
    recordMegastructureTile(target, groupId, tile, x, y)
    return true
end

local function markRegionShell(target, region, seed)
    if not region then
        return
    end
    local groupId = "shell_" .. tostring(region.id or "region")
    local baseHeight = 5 + ((seed or 1) + (region.x or 0) + (region.y or 0)) % 4
    for x = region.x - 1, region.x + region.width do
        markExpanseMegastructure(target, groupId, x, region.y - 1, baseHeight, "megastructure_shell")
        markExpanseMegastructure(target, groupId, x, region.y + region.height, baseHeight + 1, "megastructure_shell")
    end
    for y = region.y - 1, region.y + region.height do
        markExpanseMegastructure(target, groupId, region.x - 1, y, baseHeight + 1, "megastructure_shell")
        markExpanseMegastructure(target, groupId, region.x + region.width, y, baseHeight, "megastructure_shell")
    end
end

local function markOptionalTile(target, x, y)
    target.optionalTileKeys = target.optionalTileKeys or {}
    target.optionalTileKeys[tileKey(x, y)] = true
end

local function recordExpanseLandmark(target, id, districtId, x, y, kind)
    target.landmarks = target.landmarks or {}
    local tile = target.tiles[tileKey(x, y)]
    if tile then
        tile.interact = tile.interact or { id = id, kind = kind or "landmark" }
        addTag(tile, "landmark")
        addTag(tile, id)
    end
    target.landmarks[#target.landmarks + 1] = { id = id, district = districtId, x = x, y = y, kind = kind or "landmark" }
end

local function recordExpanseSoftGate(target, id, districtId, x, y, unlock)
    target.softGates = target.softGates or {}
    local tile = target.tiles[tileKey(x, y)]
    if tile then
        tile.interact = tile.interact or { id = id, kind = "soft_gate" }
        addTag(tile, "soft_gate")
        addTag(tile, id)
    end
    target.softGates[#target.softGates + 1] = { id = id, district = districtId, x = x, y = y, unlock = unlock or "local_landmark" }
end

local function districtTerrain(districtId, x, y, seed)
    local value = noise2(seed or 1, x, y, 307)
    if districtId == "sunken_court" then
        if value > 0.58 then
            return "sunken_water", 0
        end
        return "temple_stone", (x + y) % 5 == 0 and 1 or 0
    elseif districtId == "root_catacombs" then
        if value > 0.76 then
            return "root_screen", 0
        end
        return "root_tangle", value > 0.42 and 1 or 0
    elseif districtId == "bell_chambers" then
        return "bell_stone", 1 + ((x * 3 + y + (seed or 1)) % 4)
    elseif districtId == "ash_sanctum" then
        if value > 0.76 then
            return "heat_vent", 0
        elseif value < 0.24 then
            return "ash_glass", 1
        end
        return "temple_stone", (x + y) % 4 == 0 and 2 or 0
    end
    return "temple_stone", 0
end

local function openDistrictTile(target, districtId, x, y, seed, tag)
    local kind, height = districtTerrain(districtId, x, y, seed)
    local tile = openExpanseTile(target.tiles, x, y, "temple", kind, height, tag or districtId)
    addTag(tile, "district")
    addTag(tile, districtId)
    addTag(tile, "optional_path")
    if kind == "bell_stone" and ((x + y) % 3 == 0) then
        addTag(tile, "stair")
    end
    markOptionalTile(target, x, y)
    return tile
end

local function carveOptionalCorridor(target, districtId, x1, y1, x2, y2, seed)
    local xStep = x1 <= x2 and 1 or -1
    for x = x1, x2, xStep do
        openDistrictTile(target, districtId, x, y1, seed, "catacomb_loop")
    end
    local yStep = y1 <= y2 and 1 or -1
    for y = y1, y2, yStep do
        openDistrictTile(target, districtId, x2, y, seed, "catacomb_loop")
    end
end

local function placeDistrictPillar(target, districtId, x, y)
    local tile = openExpanseTile(target.tiles, x, y, "temple", "ritual_pillar", 3, districtId)
    addTag(tile, "district")
    addTag(tile, districtId)
    recordExpanseSightBreak(target, districtId .. "_pillar_" .. tostring(x) .. "_" .. tostring(y), x, y, tile.destructibleHp or 3)
end

local function addTempleDistrict(target, district)
    target.districts = target.districts or {}
    target.districts[#target.districts + 1] = {
        id = district.id,
        name = district.name,
        role = district.role,
        x = district.x,
        y = district.y,
        width = district.width,
        height = district.height,
        optional = true,
    }
    local bandTiles = {}
    for x = district.x, district.x + district.width - 1 do
        for y = district.y, district.y + district.height - 1 do
            if not (x == district.x and y == district.y) and noise2(target.seed or 1, x, y, district.salt or 0) > 0.14 then
                local tile = openDistrictTile(target, district.id, x, y, target.seed or 1, district.role)
                if (tile.height or 0) > 0 then
                    bandTiles[#bandTiles + 1] = { x = x, y = y }
                end
            end
        end
    end
    if #bandTiles > 0 then
        recordExpanseHeightBand(target, district.id .. "_height_band", "mixed", bandTiles)
    end
    for _, pillar in ipairs(district.pillars or {}) do
        placeDistrictPillar(target, district.id, pillar.x, pillar.y)
    end
    for _, cover in ipairs(district.cover or {}) do
        recordExpanseCoverField(target, district.id .. "_cover_" .. tostring(cover.x) .. "_" .. tostring(cover.y), cover.x, cover.y, cover.edges)
    end
    for _, landmark in ipairs(district.landmarks or {}) do
        recordExpanseLandmark(target, landmark.id, district.id, landmark.x, landmark.y, landmark.kind)
    end
    for _, gate in ipairs(district.softGates or {}) do
        recordExpanseSoftGate(target, gate.id, district.id, gate.x, gate.y, gate.unlock)
    end
end

local function addTempleCatacombHub(target, seed)
    target.seed = seed or target.seed or 1
    target.districts = {
        { id = "archive_spine", name = "Archive Spine", role = "critical_route", x = 1, y = 1, width = 32, height = 24, optional = false },
    }
    carveOptionalCorridor(target, "sunken_court", 29, 5, 35, 7, seed)
    carveOptionalCorridor(target, "root_catacombs", 8, 20, 8, 27, seed)
    carveOptionalCorridor(target, "bell_chambers", 24, 20, 22, 27, seed)
    carveOptionalCorridor(target, "ash_sanctum", 29, 20, 35, 27, seed)
    local districts = {
        {
            id = "sunken_court", name = "Sunken Court", role = "flooded_ritual_court", x = 35, y = 4, width = 9, height = 7, salt = 401,
            pillars = { { x = 37, y = 6 }, { x = 42, y = 9 } },
            cover = { { x = 36, y = 8, edges = { north = "half", west = "half" } }, { x = 41, y = 5, edges = { east = "half", south = "half" } } },
            landmarks = { { id = "moon_basin", x = 39, y = 7, kind = "basin" }, { id = "flooded_lintel", x = 43, y = 10, kind = "lintel" } },
            softGates = { { id = "court_sluice_gate", x = 35, y = 7, unlock = "moon_basin" } },
        },
        {
            id = "root_catacombs", name = "Root Catacombs", role = "overgrown_crypt_loop", x = 3, y = 27, width = 10, height = 6, salt = 503,
            pillars = { { x = 5, y = 30 }, { x = 10, y = 28 } },
            cover = { { x = 7, y = 31, edges = { west = "half", south = "half" } }, { x = 11, y = 30, edges = { east = "half" } } },
            landmarks = { { id = "root_idol", x = 4, y = 29, kind = "idol" }, { id = "buried_tablet", x = 12, y = 32, kind = "tablet" } },
            softGates = { { id = "root_lattice_shortcut", x = 8, y = 27, unlock = "root_idol" } },
        },
        {
            id = "bell_chambers", name = "Bell Chambers", role = "vertical_bell_cavity", x = 19, y = 27, width = 8, height = 7, salt = 607,
            pillars = { { x = 21, y = 28 }, { x = 25, y = 32 } },
            cover = { { x = 23, y = 29, edges = { north = "full", west = "half" } }, { x = 26, y = 31, edges = { east = "half", south = "half" } } },
            landmarks = { { id = "silent_bell", x = 22, y = 33, kind = "bell" }, { id = "hanging_stair", x = 26, y = 27, kind = "stair" } },
        },
        {
            id = "ash_sanctum", name = "Ash Sanctum", role = "burned_inner_shrine", x = 35, y = 24, width = 9, height = 7, salt = 709,
            pillars = { { x = 37, y = 26 }, { x = 42, y = 29 } },
            cover = { { x = 39, y = 25, edges = { north = "half", east = "half" } }, { x = 41, y = 30, edges = { west = "full" } } },
            landmarks = { { id = "charred_mandala", x = 40, y = 27, kind = "mandala" }, { id = "ember_niche", x = 43, y = 25, kind = "niche" } },
            softGates = { { id = "ash_veil_gate", x = 35, y = 27, unlock = "charred_mandala" } },
        },
    }
    for _, district in ipairs(districts) do
        addTempleDistrict(target, district)
    end
    recordExpanseSightline(target, "bell_chamber_high_sight", { x = 23, y = 29, height = 4 }, { x = 35, y = 27, height = 0 }, { { x = 23, y = 29 }, { x = 28, y = 28 }, { x = 35, y = 27 } })
    recordExpanseVerticalRoute(target, "bell_chamber_stair_chain", "ascend", 1, 4, { { x = 22, y = 27 }, { x = 23, y = 28 }, { x = 24, y = 29 }, { x = 25, y = 30 } })
end

local function addExpanseMegastructureSprawl(target, seed)
    target.megaStructures = {}
    target.megaStructureById = {}
    for _, region in ipairs(target.regions or {}) do
        markRegionShell(target, region, seed)
    end
    local slabs = {
        { id = "dead_upper_slab_west", x = 2, y = 9, width = 5, height = 3, z = 8 },
        { id = "dead_upper_slab_mid", x = 11, y = 7, width = 6, height = 2, z = 7 },
        { id = "dead_upper_slab_east", x = 24, y = 8, width = 6, height = 3, z = 9 },
        { id = "collapsed_city_plate", x = 5, y = 17, width = 7, height = 3, z = 6 },
        { id = "terminal_far_wall", x = 28, y = 11, width = 3, height = 9, z = 10 },
    }
    for _, slab in ipairs(slabs) do
        for x = slab.x, slab.x + slab.width - 1 do
            for y = slab.y, slab.y + slab.height - 1 do
                markExpanseMegastructure(target, slab.id, x, y, slab.z, "hanging_slab")
            end
        end
    end
    local ribs = 0
    for key, tile in pairs(target.tiles or {}) do
        if tile and tile.blocker ~= true then
            local x, y = key:match("^(%-?%d+):(%-?%d+)$")
            x, y = tonumber(x), tonumber(y)
            for _, offset in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
                local nx, ny = x + offset[1], y + offset[2]
                if ribs < 120 and noise2(seed or 1, nx, ny, 211) > 0.78 then
                    local height = 4 + math.floor(noise2(seed or 1, nx, ny, 223) * 6)
                    if markExpanseMegastructure(target, "route_canyon_ribs", nx, ny, height, "megastructure_rib") then
                        ribs = ribs + 1
                    end
                end
            end
        end
    end
    local shafts = {
        { x = 19, y = 8, height = 10 },
        { x = 21, y = 15, height = 9 },
        { x = 30, y = 6, height = 11 },
        { x = 13, y = 20, height = 8 },
    }
    for index, shaft in ipairs(shafts) do
        markExpanseMegastructure(target, "vertical_shaft_" .. tostring(index), shaft.x, shaft.y, shaft.height, "archive_shaft")
        markExpanseMegastructure(target, "vertical_shaft_" .. tostring(index), shaft.x + 1, shaft.y, shaft.height - 1, "archive_shaft")
        markExpanseMegastructure(target, "vertical_shaft_" .. tostring(index), shaft.x, shaft.y + 1, shaft.height - 2, "archive_shaft")
    end
    target.megaStructureById = nil
end

local function addExpanseSetPieces(target, seed)
    target.heightBands = target.heightBands or {}
    target.coverFields = target.coverFields or {}
    target.sightBreaks = target.sightBreaks or {}
    target.verticalRoutes = target.verticalRoutes or {}
    target.sightlines = target.sightlines or {}
    carveExpanseCorridor(target, 8, 4, 12, 4, 1)
    carveExpanseCorridor(target, 18, 4, 23, 5, 2)
    carveExpanseCorridor(target, 8, 5, 8, 14, 1)
    carveExpanseCorridor(target, 14, 14, 20, 14, 2)
    carveExpanseCorridor(target, 24, 18, 28, 18, 3)
    carveExpanseCorridor(target, 18, 16, 24, 16, 0)
    for x = 12, 18 do
        for y = 3, 6 do
            local tile = openExpanseTile(target.tiles, x, y, "archive", "floor", 2, "raised_archive_walk")
            if x == 12 or x == 18 then
                addTag(tile, "stair")
            end
        end
    end
    for x = 24, 29 do
        for y = 16, 20 do
            local h = (x >= 27 and y <= 18) and 4 or 3
            local tile = openExpanseTile(target.tiles, x, y, "archive", "floor", h, "monument_stack")
            if x == 24 or y == 20 then
                addTag(tile, "stair")
            end
        end
    end
    local ascent = {}
    for i = 0, 4 do
        local x = 20 + i
        local tile = openExpanseTile(target.tiles, x, 12, "archive", "floor", i, "monument_stair")
        addTag(tile, "stair")
        ascent[#ascent + 1] = { x = x, y = 12 }
    end
    local descent = {}
    for i = 0, 4 do
        local y = 12 + i
        local tile = openExpanseTile(target.tiles, 24, y, "archive", "floor", 4 - i, "monument_stair")
        addTag(tile, "stair")
        descent[#descent + 1] = { x = 24, y = y }
    end
    recordExpanseVerticalRoute(target, "ledger_spire_ascent", "ascend", 0, 4, ascent)
    recordExpanseVerticalRoute(target, "claim_stack_descent", "descend", 4, 0, descent)
    recordExpanseHeightBand(target, "ledger_spire_height", 4, { { x = 24, y = 12 }, { x = 27, y = 17 } })
    recordExpanseSightline(target, "spire_high_to_low", { x = 24, y = 12, height = 4 }, { x = 20, y = 12, height = 0 }, ascent)
    recordExpanseSightline(target, "low_arcade_to_tower", { x = 20, y = 16, height = 0 }, { x = 28, y = 16, height = 4 }, { { x = 20, y = 16 }, { x = 21, y = 16 }, { x = 22, y = 16 }, { x = 23, y = 16 }, { x = 24, y = 16 }, { x = 28, y = 16 } })
    local column = openExpanseTile(target.tiles, 22, 16, "archive", "sight_column", 4, "destructible_cover")
    column.losBlocker = true
    column.destructibleHp = 2
    column.collapseHeight = 0
    column.collapseKind = "rubble"
    column.coverEdges = { east = "full", west = "full", north = "half" }
    recordExpanseSightBreak(target, "breakable_sight_column", 22, 16, 2)
    recordExpanseCoverField(target, "spire_full_cover", 23, 12, { north = "full", west = "half" })
    recordExpanseCoverField(target, "descent_half_cover", 24, 14, { east = "half", south = "half" })
    local bridge = openExpanseTile(target.tiles, 9, 4, "archive", "ledger_bridge", 1, "destructible_bridge")
    bridge.destructibleHp = 3
    bridge.collapseHeight = 0
    bridge.collapseKind = "rubble"
    bridge.coverEdges = { north = "half", south = "half" }
    recordExpanseCoverField(target, "bridge_cover", 9, 4, bridge.coverEdges)
    recordExpanseSightBreak(target, "destructible_bridge", 9, 4, 3)
    local tower = target.tiles[tileKey(27, 17)]
    if tower then
        tower.destructibleHp = 4
        tower.collapseHeight = 1
        tower.collapseKind = "rubble"
        tower.coverEdges = { west = "full", south = "half" }
        addTag(tower, "destructible_structure")
        recordExpanseCoverField(target, "tower_full_cover", 27, 17, tower.coverEdges)
    end
    for x = 14, 17 do
        local tile = openExpanseTile(target.tiles, x, 5, "archive", "floor", 2, "hazard_lane")
        tile.hazard = { kind = "audit_static", damage = 1, timing = "end_turn" }
    end
    for y = 7, 11 do
        openExpanseTile(target.tiles, 19, y, "void", "archive_chasm", 0, "void_bridge_network")
    end
    for x = 18, 20 do
        local tile = openExpanseTile(target.tiles, x, 9, "archive", "ledger_bridge", 1, "destructible_bridge")
        tile.destructibleHp = 2
        tile.collapseHeight = 0
        tile.collapseKind = "rubble"
        tile.coverEdges = { north = "half", south = "half" }
    end
    for x = 12, 15 do
        openExpanseTile(target.tiles, x, 9, "salt", "brine_pool", 0, "terrain_variety")
    end
    for x = 16, 18 do
        openExpanseTile(target.tiles, x, 10, "ash", "index_miasma", 0, "terrain_variety")
    end
    for x = 25, 27 do
        openExpanseTile(target.tiles, x, 19, "glass", "glass_floor", 3, "terrain_variety")
    end
    openExpanseTile(target.tiles, 26, 18, "glass", "mirror_glass", 4, "terrain_variety")
    addTempleCatacombHub(target, seed)
    addExpanseMegastructureSprawl(target, seed)
end

local function expanseMetrics(target)
    local openTiles, optionalTiles = 0, 0
    local optional = target.optionalTileKeys or {}
    for key, tile in pairs(target.tiles or {}) do
        if tile and tile.blocker ~= true then
            openTiles = openTiles + 1
            if optional[key] then
                optionalTiles = optionalTiles + 1
            end
        end
    end
    return {
        openTiles = openTiles,
        optionalTiles = optionalTiles,
        optionalOpenRatio = openTiles > 0 and optionalTiles / openTiles or 0,
        districts = #(target.districts or {}),
        softGates = #(target.softGates or {}),
        landmarks = #(target.landmarks or {}),
    }
end

function Procgen.generateArchiveExpanse(seed, options)
    options = options or {}
    local width = options.width or 48
    local height = options.height or 36
    local target = { seed = seed or archiveRouteVariants.archive_entry_audit.seed, width = width, height = height, tiles = {}, units = {}, objectives = {}, regions = {} }
    local expanseTechniqueIds = { "stitched_expanse_regions", "macro_graph_layout", "noise_heightfield", "wfc_tile_dressing", "graph_sprawl", "cellular_mines", "open_field_noise", "spire_stack_generation", "monument_switchback", "void_bridge_network", "megastructure_sprawl", "temple_district_sprawl", "catacomb_loop_network", "soft_gate_shortcuts", "ambient_landmark_fill", "terrace_height_bands", "destructible_sight_breaks", "hazard_lane_dressing", "special_terrain_scatter", "tactical_repair_validation" }
    for x = 1, width do
        for y = 1, height do
            target.tiles[tileKey(x, y)] = { kind = "wall", material = "archive", blockerKind = "hard", blocker = true, losBlocker = true, terrainType = "sealed_archive_mass", tags = { "sealed_mass", "built_mass" } }
        end
    end
    for index, variantId in ipairs(archiveRouteVariantOrder) do
        local source = Procgen.generateArchiveRouteBoard(variantId, seed and (seed + index - 1) or nil)
        copyRegionSpecIntoExpanse(target, source, archiveExpansePlacements[variantId], variantId, index == 1)
    end
    addExpanseSetPieces(target, seed or archiveRouteVariants.archive_entry_audit.seed)
    target.metrics = expanseMetrics(target)
    local spec = {
        seed = seed or archiveRouteVariants.archive_entry_audit.seed,
        zone = "buried_archive",
        generator = { id = "archive_expanse_generator_v1", zone = "buried_archive", material = "archive", routeId = archiveRouteId, expanse = true },
        grammar = {
            id = "archive_expanse_grammar_v1",
            components = {
                rooms = target.regions,
                corridors = { { id = "expanse_spine", from = "archive_entry_audit", to = "archive_vault_regent_final" } },
                heightBands = target.heightBands,
                coverFields = target.coverFields,
                sightBreaks = target.sightBreaks,
                verticalRoutes = target.verticalRoutes,
                sightlines = target.sightlines,
                megaStructures = target.megaStructures,
                districts = target.districts,
                softGates = target.softGates,
                landmarks = target.landmarks,
                metrics = target.metrics,
                objectiveAnchors = target.objectives,
                hazardLanes = { { id = "raised_audit_lane", kind = "audit_static", tiles = { { x = 14, y = 5 }, { x = 15, y = 5 }, { x = 16, y = 5 }, { x = 17, y = 5 } } } },
                spawnPockets = { { id = "player_entry", side = "player", tiles = { { x = 1, y = 4 }, { x = 1, y = 5 }, { x = 1, y = 2 }, { x = 2, y = 5 }, { x = 3, y = 2 }, { x = 3, y = 3 } } } },
                terrainTypes = terrainTypesUsedByTiles(target.tiles),
                generationTechniques = componentListByIds(generationTechniqueById, expanseTechniqueIds),
            },
        },
        board = { width = width, height = height, tiles = target.tiles, expanse = true, regions = target.regions, districts = target.districts, softGates = target.softGates, landmarks = target.landmarks, metrics = target.metrics, heightBands = target.heightBands, coverFields = target.coverFields, sightBreaks = target.sightBreaks, verticalRoutes = target.verticalRoutes, sightlines = target.sightlines, megaStructures = target.megaStructures, terrainTypes = terrainTypesUsedByTiles(target.tiles), generationTechniques = componentListByIds(generationTechniqueById, expanseTechniqueIds) },
        units = target.units,
        objectives = target.objectives,
        archiveRoute = {
            id = archiveRouteId,
            zone = "buried_archive",
            variantId = archiveRouteVariantOrder[1],
            nodeKind = "expanse",
            template = "unified_expanse",
            routeDepth = 1,
            boardSeed = seed or archiveRouteVariants.archive_entry_audit.seed,
            preview = "one continuous Archive expanse with raised walks, destructible bridges, and staged route threats",
            regions = copyValue(target.regions),
            expanse = true,
        },
    }
    spec.validation = Procgen.validateGrammarBoard(spec)
    spec.budget = Procgen.difficultyBudget(spec)
    return spec
end

function Procgen.archiveRouteState(variantId, seed, options)
    return State.new(Procgen.generateArchiveRouteBoard(variantId, seed, options))
end

return Procgen
