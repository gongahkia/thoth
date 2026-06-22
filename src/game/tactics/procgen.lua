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

local hazardKinds = { "audit_static" }

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
    "archive_elite_claim",
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
        preview = "compact entry stacks with known audit-static lane",
        generatorOptions = { width = 8, height = 8, objectiveId = "entry_shelf" },
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
        generatorOptions = { width = 9, height = 8, objectiveId = "deep_shelf", objectiveIntegrity = 4 },
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
        generatorOptions = { width = 8, height = 7, objectiveId = "proof_cache", objectiveKind = "extract_record" },
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
        generatorOptions = { width = 9, height = 7, objectiveId = "ledger_machine", objectiveKind = "repair_machinery" },
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
        generatorOptions = { width = 7, height = 7, objectiveId = "audit_lens", objectiveKind = "disable_audit_lens" },
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
        generatorOptions = { width = 9, height = 8, objectiveId = "claim_docket", objectiveKind = "hold_claim" },
        directorOptions = { includeElite = true, eliteId = "shelf_knight", eliteIds = { "codex_advocate", "shelf_knight", "writ_cantor" }, failureClock = 4, threatenedTiles = 7, reinforcementTurn = 4 },
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
        reward = "proof, salvage, route integrity, and one rare unlock",
        detail = "six deterministic Buried Archive procedural board variants",
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
            boardVerb = enemy.boardVerb,
            spawnPocket = enemy.spawnPocket,
            intentType = enemy.intentType,
            intent = copyValue(enemy.intent),
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
        intent = copyValue(intent),
        intentType = intent and intent.intentType,
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
    for _, y in ipairs({ objective.y - 1, objective.y + 1 }) do
        if y >= 1 and y <= spec.board.height then
            local tile = spec.board.tiles[tileKey(blockerX, y)]
            if tile and tile.kind ~= "wall" then
                tile.kind = "warden_shelf_blocker"
                tile.blockerKind = "mobile"
                tile.blocker = true
                tile.losBlocker = true
                tile.destructibleHp = 3
                tile.terrainInteraction = alpha.terrainInteraction
                tile.alphaTerrain = alpha.id
                addTag(tile, "alpha_terrain")
                addTag(tile, "shelf_warden")
                blockers[#blockers + 1] = { x = blockerX, y = y, interaction = alpha.terrainInteraction }
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
    local first = pickIndexed(common, poolIndex(seed or 1, 0, #common))
    local second = pickIndexed(common, poolIndex(seed or 1, 3, #common))
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
        { turn = options.reinforcementTurn or 3 + ((seed or 1) % 2), enemy = pickIndexed(common, poolIndex(seed or 1, 6, #common)).id, spawnPocket = enemySpawn.id, visibleWarningTurn = 1, cap = 1, blockable = true, warning = "marked spawn pocket", onBlocked = "delay_one_turn_until_cap" },
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
        intentDensity = {
            exact = 2,
            partial = elite and 1 or 0,
            alpha = alpha and 1 or 0,
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
    }
    spec.validation = Procgen.validateGrammarBoard(spec)
    spec.budget = Procgen.difficultyBudget(spec)
    if not RunCatalog.boardTemplate(variant.template) then
        error("unknown archive route template " .. tostring(variant.template), 2)
    end
    return spec
end

function Procgen.archiveRouteState(variantId, seed, options)
    return State.new(Procgen.generateArchiveRouteBoard(variantId, seed, options))
end

return Procgen
