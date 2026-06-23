local UICatalog = {}

UICatalog.icons = {
    { id = "ap", icon = "AP", shape = "pip", colorRole = "action", pattern = "solid", label = "action points" },
    { id = "move", icon = "MV", shape = "arrow", colorRole = "movement", pattern = "path", label = "move path" },
    { id = "cover", icon = "CV", shape = "edge shield", colorRole = "cover", pattern = "edge", label = "cover edge" },
    { id = "flanked", icon = "FL", shape = "broken shield", colorRole = "warning", pattern = "crosshatch", label = "flanked" },
    { id = "los", icon = "LOS", shape = "ray", colorRole = "sight", pattern = "line", label = "line of sight" },
    { id = "exact_intent", icon = "!", shape = "target", colorRole = "intent", pattern = "solid outline", label = "exact intent" },
    { id = "partial_intent", icon = "?", shape = "masked target", colorRole = "partial", pattern = "dashed outline", label = "partial intent" },
    { id = "hazard", icon = "HZ", shape = "triangle", colorRole = "hazard", pattern = "diagonal hatch", label = "hazard" },
    { id = "objective", icon = "OBJ", shape = "diamond", colorRole = "objective", pattern = "double outline", label = "objective" },
    { id = "destructible_hp", icon = "HP", shape = "cracked block", colorRole = "destructible", pattern = "tick marks", label = "destructible HP" },
    { id = "weak_point", icon = "WP", shape = "ring target", colorRole = "weakPoint", pattern = "ring", label = "weak point" },
    { id = "extraction", icon = "EX", shape = "exit chevron", colorRole = "extraction", pattern = "chevrons", label = "extraction" },
}

UICatalog.overlayFilters = {
    { id = "movement", icon = "move", shows = "reachable tiles, AP bands, carry path", hides = "enemy-only intent clutter" },
    { id = "enemy_intent", icon = "exact_intent", shows = "exact and partial enemy footprints", hides = "non-threat utility hints" },
    { id = "los", icon = "los", shows = "line of sight rays and blockers", hides = "movement AP bands" },
    { id = "cover", icon = "cover", shows = "cover edges, flanked edges, destructible cover", hides = "hazard-only tile marks" },
    { id = "objectives", icon = "objective", shows = "objective integrity, target links, extraction cargo", hides = "non-objective terrain" },
    { id = "hazards", icon = "hazard", shows = "hazard tiles, countdowns, forced movement", hides = "safe movement bands" },
    { id = "hidden_revealed", icon = "partial_intent", shows = "hidden marks, revealed facts, rotation secrets", hides = "known base terrain" },
}

UICatalog.accessibleOverlayPalette = {
    id = "intent_cover_hazard",
    source = "colorblind-safe blue/orange/yellow palette with non-color redundancy",
    modes = { "deuteranopia", "protanopia", "tritanopia", "grayscale" },
    checks = { "avoid_red_green_pairing", "distinct_lightness", "icon_pattern_shape_redundancy", "simulator_review" },
    roles = {
        intent = { hex = "#D55E00", color = { 0.84, 0.37, 0.00, 0.58 }, icon = "intent", pattern = "crosshatch", shape = "target", visible = true },
        cover = { hex = "#0072B2", color = { 0.00, 0.45, 0.70, 0.48 }, icon = "shield", pattern = "edge-hatch", shape = "edge shield", visible = true },
        hazard = { hex = "#F0E442", color = { 0.94, 0.89, 0.26, 0.56 }, icon = "hazard", pattern = "stripe", shape = "triangle", visible = true },
    },
}

UICatalog.tileInspectorTemplate = {
    title = "{tileName}",
    mechanicsLine = "{icon} {state}: {verb} {effect}; AP {apCost}; counter {counterplay}",
    loreLine = "{zoneTone}: {oneSentenceLore}",
    maxMechanicsLines = 1,
    maxLoreLines = 1,
    requiredTokens = { "icon", "state", "verb", "effect", "apCost", "counterplay", "zoneTone", "oneSentenceLore" },
    requiredFacts = {
        { id = "terrain", source = "tile schema", visible = true },
        { id = "cover", source = "cover edges", visible = true },
        { id = "los", source = "line of sight preview", visible = true },
        { id = "hazards", source = "tile hazard", visible = true },
        { id = "destructible_hp", source = "blocker state", visible = true },
        { id = "hidden_info", source = "reveal state", visible = true },
        { id = "vision_sources", source = "squad visibility", visible = true },
        { id = "intent_traces", source = "intent preview", visible = true },
    },
}

UICatalog.previewContract = {
    commitGate = "before_commit",
    fields = {
        { id = "ap_cost", source = "selected action and path", visible = true },
        { id = "movement_path", source = "pathfinder", visible = true },
        { id = "damage", source = "deterministic resolver", visible = true },
        { id = "push_path", source = "forced movement resolver", visible = true },
        { id = "collision", source = "forced movement collision", visible = true },
        { id = "cover_change", source = "cover edge diff", visible = true },
        { id = "objective_change", source = "objective integrity diff", visible = true },
        { id = "hazard_result", source = "hazard resolver", visible = true },
    },
}

UICatalog.tacticalHudContract = {
    id = "tactical_hud",
    requiredFields = {
        { id = "selected_unit_ap", source = "selected unit", visible = true },
        { id = "move_preview", source = "movement preview", visible = true },
        { id = "action_preview", source = "action preview", visible = true },
        { id = "enemy_intents", source = "intent preview", visible = true },
        { id = "objective_risk", source = "objective state", visible = true },
        { id = "turn_order", source = "unit order", visible = true },
    },
}

UICatalog.controllerPathContract = {
    id = "tactical_controller_path",
    principles = { "single_press_steps", "analog_or_digital_cursor", "cancel_before_commit", "preview_before_commit" },
    bindings = {
        cursor = "left_stick_or_dpad",
        select = "a",
        back = "b",
        inspect = "x",
        focus = "y",
        rotateLeft = "leftshoulder",
        rotateRight = "rightshoulder",
    },
    stages = {
        { id = "select_unit", input = "cursor plus select", output = "selectedUnitId", preview = "selectedUnitAp" },
        { id = "select_tile", input = "cursor plus inspect", output = "tileCursor", preview = "tileInspectorSummary and movePreview" },
        { id = "select_action", input = "focus action rail plus select", output = "pendingAction", preview = "actionPreview" },
        { id = "select_target", input = "cursor or shoulder cycle plus select", output = "target", preview = "targetPreview and intentTraces" },
        { id = "confirm_preview", input = "select confirm or back cancel", output = "queuedCommand", preview = "beforeCommitPreview" },
    },
}

UICatalog.rotationReadability = {
    rotations = { 0, 90, 180, 270 },
    appliesTo = { "movement", "enemy_intent", "los", "cover", "objectives", "hazards", "hidden_revealed" },
    checks = {
        { id = "symbol_visible", rule = "icon or shape remains visible at target zoom" },
        { id = "label_upright", rule = "text labels do not rotate with board plane" },
        { id = "logical_tile_stable", rule = "overlay logical tile stays unchanged after camera rotation" },
        { id = "screen_position_distinct", rule = "screen projection changes enough to confirm rotation" },
        { id = "non_color_redundant", rule = "shape or hatch carries meaning without color" },
        { id = "occlusion_clear", rule = "important symbol is not hidden by unit billboard or cover face" },
    },
}

UICatalog.tutorialSequence = {
    { id = "tactical_onboarding", teaches = "select/move/rotate/overwatch/end turn/react", board = "single-screen 6x6 scripted intent board", exitCheck = "player reacts to revealed intent" },
    { id = "movement", teaches = "movement", board = "two AP path with safe and unsafe route", exitCheck = "player previews AP path then commits move" },
    { id = "cover_flank", teaches = "cover/flank", board = "half cover lane with one flank tile", exitCheck = "player identifies protected and flanked edge" },
    { id = "intent", teaches = "intent", board = "one enemy exact attack footprint", exitCheck = "player prevents declared hit" },
    { id = "forced_movement", teaches = "forced movement", board = "push enemy out of objective lane", exitCheck = "player previews push path and collision" },
    { id = "destructible_terrain", teaches = "destructible terrain", board = "break cover to open LoS", exitCheck = "player previews cover HP and post-break line" },
    { id = "objective_pressure", teaches = "objective pressure", board = "protect machinery under exact intent", exitCheck = "player preserves objective integrity" },
    { id = "redacted_intent", teaches = "redacted intent", board = "partial elite footprint with reveal tool", exitCheck = "player reveals category into exact tiles" },
    { id = "boss_weak_point", teaches = "boss weak point", board = "rotation reveals back-face weak point", exitCheck = "player rotates and counters boss procedure" },
}

UICatalog.tutorialBoardOrder = { "tactical_onboarding", "movement", "cover_flank", "intent", "push_pull", "destruction", "objectives" }

UICatalog.tutorialBoardSpecs = {
    tactical_onboarding = {
        id = "tactical_onboarding",
        teaches = "select/move/rotate/overwatch/end turn/react",
        singleScreen = true,
        scripted = true,
        noTextWalls = true,
        maxCueWords = 2,
        board = {
            width = 6,
            height = 6,
            tiles = {
                ["2:3"] = { kind = "archive_cover", coverEdges = { west = "half" }, tags = { "move_goal" } },
                ["3:3"] = { kind = "filing_lane", coverEdges = { east = "half" }, rotationMarks = { east = "sealed_intent" }, tags = { "rotate_read" } },
                ["4:3"] = { kind = "audit_line", tags = { "intent_lane" } },
                ["2:4"] = { kind = "lamp_tile", tags = { "overwatch_anchor" } },
            },
        },
        units = {
            { id = "warden", side = "player", class = "warden", x = 1, y = 3, hp = 6, ap = 3, maxAp = 3, visionRadius = 4 },
            { id = "lamplighter", side = "player", class = "lamplighter", x = 1, y = 4, hp = 4, ap = 3, maxAp = 3, visionRadius = 4 },
            { id = "bailiff", side = "enemy", x = 5, y = 3, hp = 4, ap = 0, visionRadius = 4 },
        },
        intents = {
            bailiff = {
                mode = "hiddenFootprint",
                category = "attack",
                source = "bailiff",
                sourceTile = { x = 5, y = 3 },
                targetTiles = { { x = 2, y = 3 }, { x = 2, y = 4 } },
                path = { { x = 5, y = 3 }, { x = 4, y = 3 }, { x = 3, y = 3 }, { x = 2, y = 3 } },
                damage = 2,
                effect = "filed_strike",
                label = "filed strike",
                revealRotations = { 1 },
                revealActions = { "inspect_intent" },
                revealClasses = { "lamplighter" },
                counterplay = { "overwatch", "move_out" },
            },
        },
        actions = {
            { id = "select_unit", kind = "select_unit", unit = "warden", tile = { x = 1, y = 3 }, cue = "select", icon = "cursor", preview = "selectedUnitAp" },
            { id = "move", kind = "move", unit = "warden", to = { x = 2, y = 3 }, cue = "move", icon = "move", preview = "movementPreview" },
            { id = "rotate_camera", kind = "rotate_camera", rotation = 1, cue = "rotate", icon = "compass", preview = "rotationCompass" },
            { id = "declare_overwatch", kind = "overwatch", unit = "lamplighter", facing = "east", range = 3, cue = "watch", icon = "cone", preview = "overwatchCone" },
            { id = "end_turn", kind = "end_turn", cue = "end", icon = "hourglass", preview = "intentResolution" },
            { id = "react_revealed_intent", kind = "react_revealed_intent", unit = "warden", target = "bailiff", revealAction = "inspect_intent", cue = "react", icon = "intent", preview = "revealedIntent" },
        },
        overlays = { "movement", "enemy_intent", "los", "cover", "hidden_revealed" },
        exitCheck = "react to revealed hidden footprint after overwatch setup",
    },
    movement = {
        id = "movement",
        teaches = "movement",
        board = { width = 4, height = 3, tiles = { ["3:2"] = { hazard = { kind = "brine", active = true, damage = 1 } } } },
        units = { { id = "warden", side = "player", x = 1, y = 2, ap = 2 } },
        actions = { { kind = "move", unit = "warden", to = { x = 2, y = 2 }, preview = "movementPreview" } },
        overlays = { "movement", "hazards" },
        exitCheck = "preview safe route and spend one AP",
    },
    cover_flank = {
        id = "cover_flank",
        teaches = "cover/flanking",
        board = { width = 4, height = 3, tiles = { ["2:2"] = { coverEdges = { west = "half" } } } },
        units = { { id = "warden", side = "player", x = 1, y = 2, ap = 2 }, { id = "bailiff", side = "enemy", x = 2, y = 2, hp = 4 } },
        actions = { { kind = "inspect_cover", from = { x = 1, y = 2 }, target = "bailiff", preview = "coverFromAttack" }, { kind = "flank", from = { x = 2, y = 3 }, target = "bailiff", preview = "flankFromAttack" } },
        overlays = { "cover", "los" },
        exitCheck = "identify protected edge and flank tile",
    },
    intent = {
        id = "intent",
        teaches = "intent",
        board = { width = 3, height = 3 },
        units = { { id = "warden", side = "player", x = 1, y = 2, ap = 2 }, { id = "bailiff", side = "enemy", x = 3, y = 2, hp = 3 } },
        intents = { bailiff = { mode = "exact", category = "attack", targetTiles = { { x = 1, y = 2 } }, damage = 1, effect = "strike" } },
        actions = { { kind = "inspect_intent", unit = "bailiff", preview = "intentPreview" }, { kind = "move", unit = "warden", to = { x = 1, y = 1 }, preview = "movementPreview" } },
        overlays = { "enemy_intent", "movement" },
        exitCheck = "move out of exact footprint",
    },
    push_pull = {
        id = "push_pull",
        teaches = "push/pull",
        board = { width = 5, height = 3, tiles = { ["4:2"] = { kind = "route_machine", objective = { id = "machine", kind = "protect", integrity = 2 } } } },
        units = { { id = "warden", side = "player", x = 2, y = 2, ap = 2 }, { id = "custodian", side = "enemy", x = 3, y = 2, hp = 3 } },
        actions = { { kind = "push", unit = "warden", target = "custodian", direction = "east", preview = "push_path" }, { kind = "pull", unit = "warden", target = "custodian", preview = "pull_path" } },
        overlays = { "movement", "enemy_intent", "objectives" },
        exitCheck = "preview push and pull before collision",
    },
    destruction = {
        id = "destruction",
        teaches = "destruction",
        board = { width = 4, height = 2, tiles = { ["2:1"] = { blocker = true, losBlocker = true, destructibleHp = 2, coverEdges = { west = "half" } } } },
        units = { { id = "exile", side = "player", x = 1, y = 1, ap = 2 }, { id = "husk", side = "enemy", x = 4, y = 1, hp = 4 } },
        actions = { { kind = "damageTile", unit = "exile", tile = { x = 2, y = 1 }, damage = 2, preview = "coverBreak" } },
        overlays = { "cover", "los" },
        exitCheck = "break cover and open LoS",
    },
    objectives = {
        id = "objectives",
        teaches = "objectives",
        board = { width = 4, height = 3 },
        units = { { id = "warden", side = "player", x = 1, y = 2, ap = 2 }, { id = "bailiff", side = "enemy", x = 4, y = 2, hp = 3 } },
        objectives = { { id = "machine", kind = "protect_route_machinery", x = 2, y = 2, integrity = 2, evacuateAt = { x = 1, y = 1 } } },
        intents = { bailiff = { mode = "exact", category = "destroy", targetTiles = { { x = 2, y = 2 } }, damage = 1, objectiveImpact = "machine", effect = "sabotage" } },
        actions = { { kind = "block_intent", unit = "warden", tile = { x = 2, y = 2 }, preview = "objective_change" } },
        overlays = { "objectives", "enemy_intent" },
        exitCheck = "protect objective from exact intent",
    },
}

UICatalog.screenshotSmokeTarget = {
    id = "tactical_overlay_smoke",
    fixture = "overlay_all_layers",
    viewport = { width = 1280, height = 720 },
    overlays = { "movement", "enemy_intent", "los", "cover", "objectives", "hazards", "hidden_revealed" },
    rotations = { 0, 90, 180, 270 },
    assertions = {
        "non_empty_overlay_layers",
        "icons_visible",
        "non_color_patterns_visible",
        "no_text_overlap",
        "logical_tiles_stable",
    },
}

function UICatalog.icon(id)
    for _, icon in ipairs(UICatalog.icons) do
        if icon.id == id then
            return icon
        end
    end
    return nil
end

function UICatalog.iconLanguage()
    return UICatalog.icons
end

function UICatalog.overlays()
    return UICatalog.overlayFilters
end

function UICatalog.accessiblePalette()
    return UICatalog.accessibleOverlayPalette
end

function UICatalog.tileInspector()
    return UICatalog.tileInspectorTemplate
end

function UICatalog.preview()
    return UICatalog.previewContract
end

local function sortedKeys(values)
    local keys = {}
    for key in pairs(values or {}) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

local inspectorDirections = { "north", "east", "south", "west" }

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

local function copyList(values)
    local result = {}
    for _, value in ipairs(values or {}) do
        result[#result + 1] = copyValue(value)
    end
    return result
end

local function coverFacts(tile)
    local result = {}
    for _, direction in ipairs(inspectorDirections) do
        local cover = tile.coverEdges and tile.coverEdges[direction]
        if cover and cover ~= "none" then
            result[#result + 1] = { direction = direction, cover = cover }
        end
    end
    return result
end

local function tileListContains(tiles, x, y)
    for _, tile in ipairs(tiles or {}) do
        if tile.x == x and tile.y == y then
            return true
        end
    end
    return false
end

local function tileMatches(tile, x, y)
    return tile and tile.x == x and tile.y == y
end

local function intentRoleForTile(preview, x, y)
    if tileMatches(preview.sourceTile, x, y) then
        return "source"
    end
    if tileListContains(preview.targetTiles, x, y) then
        return "target"
    end
    if tileListContains(preview.path, x, y) then
        return "path"
    end
    if preview.trigger and tileListContains(preview.trigger.targetTiles, x, y) then
        return "trigger"
    end
    if preview.anchor and preview.anchor.kind == "tile" and tileMatches(preview.anchor, x, y) then
        return "anchor"
    end
    return nil
end

local function intentTraceFacts(state, x, y, options)
    local result = {}
    for _, unitId in ipairs(sortedKeys(state and state.intents or {})) do
        local preview = state:intentPreview(unitId, (options and options.intentOptions) or options or {})
        local role = preview and intentRoleForTile(preview, x, y)
        if role then
            result[#result + 1] = {
                unit = unitId,
                role = role,
                mode = preview.mode,
                category = preview.category,
                damage = preview.damage,
                effect = preview.effect,
                countdown = preview.countdown,
            }
        end
    end
    return result
end

local function resolveLosSource(state, options)
    options = options or {}
    if options.losFrom then
        return { unit = options.losFrom.unit or options.losFrom.unitId, x = options.losFrom.x, y = options.losFrom.y }
    end
    local unitId = options.unitId or options.sourceUnitId or (state and state.selectedUnitId)
    local unit = unitId and state and state:unit(unitId)
    if unit then
        return { unit = unit.id, x = unit.x, y = unit.y }
    end
    return nil
end

local function losFact(state, x, y, source)
    if not source then
        return nil
    end
    local los
    if source.x == x and source.y == y then
        los = { visible = true, heightDelta = 0, modifiers = {}, obscured = false }
    else
        los = state:sightlineProfile(source.x, source.y, x, y)
    end
    return {
        from = { unit = source.unit, x = source.x, y = source.y },
        visible = los.visible,
        blockedBy = copyValue(los.blockedBy),
        heightDelta = los.heightDelta,
        vantage = los.vantage,
        cover = los.cover,
        effectiveCover = los.effectiveCover,
        damageReduction = los.damageReduction,
        flanked = los.flanked,
        coverIgnoredByHeight = los.coverIgnoredByHeight,
        obscured = los.obscured == true,
        modifiers = copyList(los.modifiers),
    }
end

local function visionSourceFacts(state, x, y, side)
    local result = {}
    for _, unit in ipairs(state:unitsForSide(side or "player")) do
        if state:computeVisibleTiles(unit)[tostring(x) .. ":" .. tostring(y)] then
            result[#result + 1] = { unit = unit.id, x = unit.x, y = unit.y, radius = unit.visionRadius }
        end
    end
    return result
end

function UICatalog.tacticalHud()
    return UICatalog.tacticalHudContract
end

function UICatalog.controllerPath()
    return UICatalog.controllerPathContract
end

function UICatalog.tileInspectorSummary(state, x, y, options)
    options = options or {}
    local tile = state:tileAt(x, y)
    local blocker = state:blockerAt(x, y)
    local occupant = state:unitAt(x, y)
    local rotation = options.rotation or options.viewRotation or 0
    local rotationMark = state:rotationMarkAt(x, y, rotation)
    return {
        terrain = {
            x = x,
            y = y,
            kind = tile.kind,
            material = tile.material,
            state = tile.state,
            height = tile.height,
            blockerKind = tile.blockerKind,
            movementBlocked = tile.blocker,
            losBlocked = tile.losBlocker,
            tags = copyList(tile.tags),
            occupant = occupant and occupant.id,
        },
        cover = coverFacts(tile),
        los = losFact(state, x, y, resolveLosSource(state, options)),
        hazards = copyValue(tile.hazard),
        destructibleHp = {
            hp = tile.destructibleHp,
            blockerKind = blocker.kind,
            movement = blocker.movement,
            los = blocker.los,
            destructible = blocker.destructible,
        },
        hiddenInfo = {
            revealed = tile.revealed,
            hidden = tile.revealed == false,
            currentRotationMark = rotationMark,
            revealClasses = copyList(tile.revealClasses),
            revealActions = copyList(tile.revealActions),
            weakPointRevealed = tile.weakPointRevealed,
            weakPoint = tile.weakPointRevealed and tile.weakPoint or nil,
        },
        visionSources = visionSourceFacts(state, x, y, options.side or "player"),
        intentTraces = intentTraceFacts(state, x, y, options),
    }
end

function UICatalog.tacticalHudSummary(state, previews)
    previews = previews or {}
    local selected = state and state.selectedUnitId and state:unit(state.selectedUnitId) or nil
    local intents = {}
    for _, unitId in ipairs(sortedKeys(state and state.intents or {})) do
        local unit = state:unit(unitId)
        if unit and unit.side == "enemy" then
            local preview = state:intentPreview(unitId, previews.intentOptions)
            intents[#intents + 1] = { unit = unitId, mode = preview and preview.mode, category = preview and preview.category, damage = preview and preview.damage }
        end
    end
    local objectives = {}
    for _, objectiveId in ipairs(sortedKeys(state and state.objectives or {})) do
        local objective = state:objective(objectiveId)
        objectives[#objectives + 1] = { id = objectiveId, kind = objective.kind, integrity = objective.integrity, status = state:objectiveStatus(objectiveId) }
    end
    local turns = {}
    for _, unitId in ipairs(sortedKeys(state and state.units or {})) do
        local unit = state:unit(unitId)
        if unit.alive and not unit.evacuated then
            turns[#turns + 1] = { unit = unitId, side = unit.side, ap = unit.ap }
        end
    end
    return {
        selectedUnitAp = selected and { unit = selected.id, ap = selected.ap, maxAp = selected.maxAp },
        movePreview = previews.move,
        actionPreview = previews.action,
        enemyIntents = intents,
        objectiveRisk = objectives,
        turnOrder = turns,
    }
end

function UICatalog.rotationChecks()
    return UICatalog.rotationReadability
end

function UICatalog.tutorials()
    return UICatalog.tutorialSequence
end

function UICatalog.tutorialBoards()
    local result = {}
    for _, id in ipairs(UICatalog.tutorialBoardOrder) do
        result[#result + 1] = UICatalog.tutorialBoardSpecs[id]
    end
    return result
end

function UICatalog.tutorialBoard(id)
    return UICatalog.tutorialBoardSpecs[id]
end

function UICatalog.screenshotSmoke()
    return UICatalog.screenshotSmokeTarget
end

return UICatalog
