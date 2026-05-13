local CONFIG = require("config")

local Utils = require("modules/utils")
local UI = require("modules/ui")
local ProcGen = require("modules/procgen")
local Accessibility = require("modules/accessibility")
local Progression = require("modules/progression")
local Editor = require("modules/editor")
local Replay = require("modules/replay")
local SaveGame = require("modules/save_game")
local Settings = require("modules/settings")
local Items = require("modules/items")
local Survival = require("modules/survival")
local Fire = require("modules/fire")
local Wildlife = require("modules/wildlife")
local EntitySystem = require("modules/entity_system")
local Effects = require("modules/effects")
local SpriteRegistry = require("modules/sprite_registry")
local SoundEvents = require("modules/sound_events")
local World = require("modules/world")

local game = {
    screen = "title",
    previousScreen = "title",
    difficultyNames = {"pilgrim", "voyageur", "stalker", "interloper"},
    selectedDifficulty = "voyageur",
    titleIndex = 1,
    titleItems = {},
    pauseIndex = 1,
    pauseOptions = {
        {label = "Resume", action = "resume"},
        {label = "Settings", action = "settings"},
        {label = "Save Game", action = "save_game"},
        {label = "Load Game", action = "load_game"},
        {label = "Save Replay", action = "save_replay"},
        {label = "Restart", action = "restart"},
        {label = "Quit to Title", action = "quit_title"},
    },
    settingsScreen = {
        categories = {"audio", "gameplay", "accessibility"},
        categoryIndex = 1,
        optionIndex = 1,
        options = {},
    },
    replayScreen = {
        index = 1,
        entries = {},
    },
    saveScreen = {
        index = 1,
        entries = {},
        previousScreen = "title",
    },
    settings = nil,
    run = nil,
    input = {
        heldKeys = {},
    },
}

local sprites = {}
local fonts = {}
local updateRunSignals
local applyPendingShake
local refreshCraftMenu
local updateVisibility
local isVisibleTile
local isMappedTile
local updateCamera

local SETTINGS_DEFS = {
    audio = {
        {path = "audio.master", label = "Master", kind = "float", min = 0, max = 1, step = 0.1},
        {path = "audio.music", label = "Music", kind = "float", min = 0, max = 1, step = 0.1},
        {path = "audio.sfx", label = "SFX", kind = "float", min = 0, max = 1, step = 0.1},
    },
    gameplay = {
        {path = "gameplay.screenShake", label = "Screen Shake", kind = "bool"},
        {path = "gameplay.showHints", label = "Show Hints", kind = "bool"},
    },
    accessibility = {
        {path = "accessibility.colorblindMode", label = "Colorblind", kind = "enum", values = {"none", "protanopia", "deuteranopia", "tritanopia"}},
        {path = "accessibility.highContrast", label = "High Contrast", kind = "bool"},
        {path = "accessibility.slowMode", label = "Slow Mode", kind = "bool"},
        {path = "accessibility.fontScale", label = "Font Scale", kind = "float", min = 1.0, max = 2.5, step = 0.1},
        {path = "accessibility.visualAlerts", label = "Visual Alerts", kind = "bool"},
    },
}

local function formatBool(value)
    return value and "ON" or "OFF"
end

local function titleCase(value)
    return tostring(value):gsub("^%l", string.upper)
end

local function canonicalDifficultyName(name)
    return CONFIG.DIFFICULTY_ALIASES[name] or name or "voyageur"
end

local function formatModeLabel(mode)
    if mode == "daily" then
        return "Daily"
    elseif mode == "replay" then
        return "Replay"
    end
    return "Survival"
end

local function rebuildFonts()
    local scale = game.settings.accessibility.fontScale
    fonts.large = love.graphics.newFont(math.floor(CONFIG.FONT_SIZE_LARGE * scale))
    fonts.medium = love.graphics.newFont(math.floor(CONFIG.FONT_SIZE_MEDIUM * scale))
    fonts.small = love.graphics.newFont(math.floor(CONFIG.FONT_SIZE_SMALL * scale))
    fonts.hud = love.graphics.newFont(math.max(18, math.floor(CONFIG.FONT_SIZE_HUD * scale)))
    fonts.tiny = love.graphics.newFont(math.max(14, math.floor(CONFIG.FONT_SIZE_TINY * scale)))
end

local function configureWindow()
    love.window.setMode(CONFIG.WINDOW_WIDTH, CONFIG.WINDOW_HEIGHT, {
        fullscreen = true,
        fullscreentype = "desktop",
    })

    local width = CONFIG.WINDOW_WIDTH
    local height = CONFIG.WINDOW_HEIGHT
    if love.graphics and love.graphics.getDimensions then
        width, height = love.graphics.getDimensions()
    elseif love.window and love.window.getDesktopDimensions then
        width, height = love.window.getDesktopDimensions(1)
    end

    CONFIG.WINDOW_WIDTH = width
    CONFIG.WINDOW_HEIGHT = height
    CONFIG.GRID_WIDTH = math.floor(width / CONFIG.TILE_SIZE)
    CONFIG.GRID_HEIGHT = math.floor(height / CONFIG.TILE_SIZE)
end

local function buildTitleItems()
    game.titleItems = {
        {label = "Start Survival", action = "start"},
        {label = "Difficulty", value = titleCase(game.selectedDifficulty), action = "difficulty"},
        {label = "Daily Run", action = "daily"},
        {label = "Load Game", action = "load_game"},
        {label = "Settings", action = "settings"},
        {label = "Profile", action = "profile"},
        {label = "Replays", action = "replays"},
        {label = "Quit", action = "quit"},
    }
end

local function formatSettingValue(def)
    local value = Settings.get(def.path)
    if def.kind == "bool" then
        return formatBool(value)
    elseif def.kind == "float" then
        return string.format("%.1f", value)
    end
    return tostring(value)
end

local function refreshSettingsOptions()
    local category = game.settingsScreen.categories[game.settingsScreen.categoryIndex]
    local definitions = SETTINGS_DEFS[category]
    game.settingsScreen.options = {}

    for _, def in ipairs(definitions) do
        table.insert(game.settingsScreen.options, {
            label = def.label,
            path = def.path,
            value = formatSettingValue(def),
            definition = def,
        })
    end

    if game.settingsScreen.optionIndex > #game.settingsScreen.options then
        game.settingsScreen.optionIndex = #game.settingsScreen.options
    end
    if game.settingsScreen.optionIndex < 1 then
        game.settingsScreen.optionIndex = 1
    end
end

local function applyAudioSettings()
    SoundEvents.applySettings(game.settings)
end

local function persistSettings()
    Settings.save()
    game.settings = Settings.getAll()
    rebuildFonts()
    buildTitleItems()
    refreshSettingsOptions()
    applyAudioSettings()
end

local function adjustSetting(definition, direction)
    local current = Settings.get(definition.path)
    if definition.kind == "bool" then
        Settings.set(definition.path, not current)
    elseif definition.kind == "float" then
        local nextValue = Utils.clamp(current + (definition.step * direction), definition.min, definition.max)
        Settings.set(definition.path, math.floor(nextValue * 10 + 0.5) / 10)
    elseif definition.kind == "enum" then
        local currentIndex = 1
        for index, value in ipairs(definition.values) do
            if value == current then
                currentIndex = index
                break
            end
        end
        currentIndex = currentIndex + direction
        if currentIndex < 1 then
            currentIndex = #definition.values
        elseif currentIndex > #definition.values then
            currentIndex = 1
        end
        Settings.set(definition.path, definition.values[currentIndex])
    end
    persistSettings()
end

local function cycleDifficulty(direction)
    local currentIndex = 1
    for index, name in ipairs(game.difficultyNames) do
        if name == game.selectedDifficulty then
            currentIndex = index
            break
        end
    end
    currentIndex = currentIndex + direction
    if currentIndex < 1 then
        currentIndex = #game.difficultyNames
    elseif currentIndex > #game.difficultyNames then
        currentIndex = 1
    end
    game.selectedDifficulty = game.difficultyNames[currentIndex]
    buildTitleItems()
end

local function setRunMessage(text)
    if game.run then
        game.run.runtime.message = text
        game.run.runtime.messageTimer = 2.2
    end
end

local function coordKey(coord)
    return string.format("%d:%d", coord[1], coord[2])
end

local function stationLabel(station)
    if station.hasWorkbench and station.hasCuring then
        return "Workbench / Curing Rack"
    elseif station.hasWorkbench then
        return "Workbench"
    end
    return "Curing Rack"
end

local function countEntries(list, predicate)
    local total = 0
    for _, entry in ipairs(list or {}) do
        if not predicate or predicate(entry) then
            total = total + 1
        end
    end
    return total
end

local function buildReplayContext(run)
    local resourceNodes = World.readActiveCollection(run, "resourceNodes")
    local fishingSpots = World.readActiveCollection(run, "fishingSpots")
    local climbNodes = World.readActiveCollection(run, "climbNodes")
    local mapNodes = World.readActiveCollection(run, "mapNodes")
    local gates = World.readActiveCollection(run, "gates")
    local npcEncounters = World.readActiveCollection(run, "npcEncounters")
    local fires = World.readActiveCollection(run, "fires")
    local traps = World.readActiveCollection(run, "traps")
    local carcasses = World.readActiveCollection(run, "carcasses")
    return {
        mode = run.mode,
        isDaily = run.mode == "daily",
        dailySeed = run.mode == "daily" and run.seed or nil,
        sourceMode = run.sourceMode,
        weather = {
            current = run.world.weather.current,
            hoursUntilChange = run.world.weather.hoursUntilChange,
        },
        timeOfDay = run.world.timeOfDay,
        dayCount = run.world.dayCount,
        worldSource = run.world.source,
        currentDepth = run.world.currentDepth or run.player.depth or 0,
        endgameActivated = run.runtime and run.runtime.endgameActivated or false,
        runtimeObjects = {
            fires = #fires,
            traps = #traps,
            carcasses = #carcasses,
            openedResourceNodes = countEntries(resourceNodes, function(node) return node.opened == true end),
            unopenedResourceNodes = countEntries(resourceNodes, function(node) return node.opened ~= true end),
            fishingSpots = #fishingSpots,
            climbNodes = #climbNodes,
            mapNodes = #mapNodes,
            openedGates = countEntries(gates, function(gate) return gate.unlockState == true end),
            resolvedNPCs = countEntries(npcEncounters, function(encounter) return encounter.resolutionState == "resolved" end),
        },
        tileSimulation = World.activeSimulationSummary(run),
        weatherStation = {
            activated = run.runtime and run.runtime.endgameActivated or false,
            depth = run.runtime and run.runtime.endgameDepth or run.world.currentDepth or run.player.depth or 0,
        },
        player = {
            maxCondition = run.player.maxCondition,
            carryCapacity = run.player.carryCapacity,
            equippedTool = run.player.equippedTool,
            equippedWeapon = run.player.equippedWeapon,
            equippedMeleeWeapon = run.player.equippedMeleeWeapon,
            depth = run.player.depth or run.world.currentDepth or 0,
        },
    }
end

local function coordInZone(coord, zone)
    if not coord or not zone then
        return false
    end
    local gx, gy = Utils.pixelToGrid(coord[1], coord[2])
    local tileX = gx + 1
    local tileY = gy + 1
    local width = zone.width or zone.w
    local height = zone.height or zone.h
    return zone.x and zone.y and width and height
        and tileX >= zone.x and tileX < zone.x + width
        and tileY >= zone.y and tileY < zone.y + height
end

local function currentBiomeRegion(run, coord)
    local biomes = World.readActiveCollection(run, "biomes")
    for _, biome in ipairs(biomes) do
        if coordInZone(coord or run.player.coord, biome.zone) then
            return biome
        end
    end
    return nil
end

local function worldPixelSize(run)
    local grid = run and World.activeGrid(run) or {}
    return #(grid[1] or {}) * CONFIG.TILE_SIZE, #grid * CONFIG.TILE_SIZE
end

updateCamera = function(run)
    if not run then
        return
    end

    run.runtime.camera = run.runtime.camera or {x = 0, y = 0}
    local worldWidth, worldHeight = worldPixelSize(run)
    local maxX = math.max(0, worldWidth - CONFIG.WINDOW_WIDTH)
    local maxY = math.max(0, worldHeight - CONFIG.WINDOW_HEIGHT)
    local desiredX = run.player.coord[1] + (CONFIG.TILE_SIZE / 2) - (CONFIG.WINDOW_WIDTH / 2)
    local desiredY = run.player.coord[2] + (CONFIG.TILE_SIZE / 2) - (CONFIG.WINDOW_HEIGHT / 2)

    run.runtime.camera.x = Utils.clamp(desiredX, 0, maxX)
    run.runtime.camera.y = Utils.clamp(desiredY, 0, maxY)
end

local function refreshReplayEntries()
    local entries = {}
    for _, file in ipairs(Replay.listReplays()) do
        local replay = Replay.inspect(file)
        if replay then
            local replayMode = replay.context and replay.context.mode or (replay.context and replay.context.isDaily and "daily" or "survival")
            local details = string.format(
                "%s | %s | %s | %.1fs",
                replay.metadata.recordingDate ~= "" and replay.metadata.recordingDate or "Unknown date",
                formatModeLabel(replayMode),
                titleCase(canonicalDifficultyName(replay.difficulty)),
                replay.metadata.duration or 0
            )
            if replay.context and replay.context.isDaily and replay.context.dailySeed then
                details = details .. string.format(" | seed %s", tostring(replay.context.dailySeed))
            end
            table.insert(entries, {
                file = file,
                details = details,
            })
        end
    end
    game.replayScreen.entries = entries
    if game.replayScreen.index > #entries then
        game.replayScreen.index = #entries
    end
    if game.replayScreen.index < 1 then
        game.replayScreen.index = 1
    end
end

local function refreshSaveEntries()
    local entries = {}
    for _, entry in ipairs(SaveGame.listSaveEntries()) do
        local save = entry.snapshot
        if save then
            local world = entry.world or save.world or {}
            local details = string.format(
                "%s | %s | %s | depth %s | day %s",
                entry.savedAt or save.savedAt or "Unknown date",
                formatModeLabel(entry.mode or save.mode or "survival"),
                titleCase(canonicalDifficultyName(entry.difficultyName or save.difficultyName)),
                tostring(world.currentDepth or 0),
                tostring(world.dayCount or 1)
            )
            table.insert(entries, {
                file = entry.file,
                slot = entry.slot,
                label = entry.label,
                details = details,
            })
        end
    end
    game.saveScreen.entries = entries
    if game.saveScreen.index > #entries then
        game.saveScreen.index = #entries
    end
    if game.saveScreen.index < 1 then
        game.saveScreen.index = 1
    end
end

local function saveReplaySnapshot()
    if game.run and game.run.replayMode then
        setRunMessage("Playback runs cannot be re-saved.")
        return false
    end
    if not Replay.hasData() then
        setRunMessage("No replay data to save.")
        return false
    end
    if Replay.save() then
        refreshReplayEntries()
        setRunMessage("Replay saved.")
        return true
    end
    setRunMessage("Replay save failed.")
    return false
end

local function ensureLoadedRuntime(run)
    run.runtime = run.runtime or {}
    run.runtime.message = run.runtime.message or ""
    run.runtime.messageTimer = run.runtime.messageTimer or 0
    run.runtime.causeOfDeath = run.runtime.causeOfDeath or "exposure"
    run.runtime.currentVisibleTiles = run.runtime.currentVisibleTiles or {}
    run.runtime.interactionHint = run.runtime.interactionHint or ""
    run.runtime.craftMenuOpen = run.runtime.craftMenuOpen or false
    run.runtime.craftIndex = run.runtime.craftIndex or 1
    run.runtime.craftRecipes = run.runtime.craftRecipes or {}
    run.runtime.alerts = run.runtime.alerts or {
        wolfThreat = 0,
        blizzard = 0,
        fireRisk = 0,
        weakIce = 0,
    }
    run.runtime.stations = run.runtime.stations or {}
    run.runtime.camera = run.runtime.camera or {x = 0, y = 0}
    run.runtime.discoveryToast = run.runtime.discoveryToast or ""
    run.runtime.discoveryToastTimer = run.runtime.discoveryToastTimer or 0
    run.runtime.currentPOI = run.runtime.currentPOI or nil
    run.runtime.currentBiome = run.runtime.currentBiome or nil
    run.finished = run.finished or false
    run.replayMode = false
    run.replayProgress = 0
    run.feats = Progression.getFeats()
    run.startedAt = love.timer.getTime()
    run.input = nil
    run.player.alive = run.player.alive ~= false
    run.stats = run.stats or {}
    run.stats.daysSurvived = run.stats.daysSurvived or run.world.dayCount or 1
    run.stats.firesLit = run.stats.firesLit or 0
    run.stats.metersWalked = run.stats.metersWalked or 0
    run.stats.wolvesRepelled = run.stats.wolvesRepelled or 0
    run.stats.clothingRepairs = run.stats.clothingRepairs or 0
    run.stats.waterBoiled = run.stats.waterBoiled or 0
    run.stats.meatCooked = run.stats.meatCooked or 0
end

local function restoreLoadedRun(run)
    if not run then
        return false
    end
    Replay.stopRecording()
    Replay.stopPlayback()
    ensureLoadedRuntime(run)
    World.attachRun(run)
    game.run = run
    game.input.heldKeys = {}
    updateCamera(run)
    updateVisibility()
    refreshCraftMenu()
    updateRunSignals()
    SoundEvents.updateWeather(run.world.weather and run.world.weather.current or nil)
    Replay.startRecording(run.seed, canonicalDifficultyName(run.difficultyName), buildReplayContext(run))
    run.runtime.message = "Game loaded."
    run.runtime.messageTimer = 2
    game.screen = "game"
    return true
end

local function saveCurrentGame(slot, label)
    if not game.run then
        return false
    end
    if game.run.replayMode or Replay.isPlaying() then
        setRunMessage("Playback runs cannot be saved.")
        return false
    end
    local targetSlot = slot or "autosave"
    local targetLabel = label or (targetSlot == "autosave" and "Autosave" or nil)
    if SaveGame.saveRun(targetSlot, game.run, {label = targetLabel}) then
        refreshSaveEntries()
        game.run.lastSaveSlot = SaveGame.normalizeSlot(targetSlot)
        setRunMessage(targetSlot == "autosave" and "Autosave written." or "Game saved.")
        return true
    end
    setRunMessage("Game save failed.")
    return false
end

local function saveManualGame()
    if not game.run then
        return false
    end
    local slot = SaveGame.defaultSlotName(game.run)
    return saveCurrentGame(slot)
end

local function loadSaveFromSelection()
    local entry = game.saveScreen.entries[game.saveScreen.index]
    if not entry then
        return false
    end
    local run = SaveGame.loadRun(entry.slot or entry.file)
    if not run then
        return false
    end
    return restoreLoadedRun(run)
end

local function deleteSaveSelection()
    local entry = game.saveScreen.entries[game.saveScreen.index]
    if not entry then
        return false
    end
    if SaveGame.delete(entry.slot or entry.file) then
        refreshSaveEntries()
        if game.run then
            setRunMessage("Save deleted.")
        end
        return true
    end
    if game.run then
        setRunMessage("Save delete failed.")
    end
    return false
end

local function validReplayDepth(run, depth)
    if type(depth) ~= "number" then
        return nil
    end
    if run.world.levels and run.world.levels[depth] then
        return depth
    end
    return nil
end

local function replayEndgameRequested(context)
    return context
        and (context.endgameActivated == true
            or (context.weatherStation and context.weatherStation.activated == true))
end

local function replayContextDepth(run, context)
    context = context or {}
    local depth = validReplayDepth(run, context.currentDepth)
    if depth then
        return depth
    end
    if context.player then
        depth = validReplayDepth(run, context.player.depth)
        if depth then
            return depth
        end
    end
    if context.weatherStation then
        depth = validReplayDepth(run, context.weatherStation.depth)
        if depth then
            return depth
        end
    end
    if replayEndgameRequested(context) then
        depth = validReplayDepth(run, 1)
        if depth then
            return depth
        end
    end
    return validReplayDepth(run, 0) or run.world.currentDepth or 0
end

local function completeGoal(goals, goalId)
    for _, goal in ipairs(goals or {}) do
        if goal.id == goalId then
            goal.completed = true
        end
    end
end

local function applyReplayContext(run, context)
    if type(context) ~= "table" then
        World.changeDepth(run, validReplayDepth(run, 0) or run.world.currentDepth or 0)
        return
    end

    if context.weather then
        run.world.weather.current = context.weather.current or run.world.weather.current
        run.world.weather.hoursUntilChange = context.weather.hoursUntilChange or run.world.weather.hoursUntilChange
    end
    if context.timeOfDay ~= nil then
        run.world.timeOfDay = context.timeOfDay
    end
    if context.dayCount ~= nil then
        run.world.dayCount = context.dayCount
        run.stats.daysSurvived = context.dayCount
    end
    if context.player then
        run.player.maxCondition = context.player.maxCondition or run.player.maxCondition
        run.player.carryCapacity = context.player.carryCapacity or run.player.carryCapacity
        run.player.equippedTool = context.player.equippedTool or run.player.equippedTool
        run.player.equippedWeapon = context.player.equippedWeapon or run.player.equippedWeapon
        run.player.equippedMeleeWeapon = context.player.equippedMeleeWeapon or run.player.equippedMeleeWeapon
        run.player.condition = math.min(run.player.condition, run.player.maxCondition)
    end

    local targetDepth = replayContextDepth(run, context)
    World.changeDepth(run, targetDepth)

    if context.runtimeObjects then
        run.runtime.replayAudit = run.runtime.replayAudit or {}
        run.runtime.replayAudit.runtimeObjects = Utils.deepCopy(context.runtimeObjects)
    end
    if context.tileSimulation then
        run.runtime.replayAudit = run.runtime.replayAudit or {}
        run.runtime.replayAudit.tileSimulation = Utils.deepCopy(context.tileSimulation)
    end

    if replayEndgameRequested(context) then
        run.runtime.endgameActivated = true
        run.runtime.success = true
        run.runtime.endgameDepth = targetDepth
        run.stats.weatherStationActivated = true
        completeGoal(run.world.goals, "activate_ridge_weather_station")
        completeGoal(World.currentLevel(run).goals, "activate_ridge_weather_station")
    end
end

local function createRun(generated, difficultyName, options)
    local sourceMode = options.mode or "survival"
    if options.replayMode then
        sourceMode = (options.context and options.context.mode) or (options.context and options.context.isDaily and "daily") or "survival"
    end
    local run = {
        difficultyName = canonicalDifficultyName(difficultyName),
        mode = options.replayMode and "replay" or sourceMode,
        sourceMode = sourceMode,
        world = Utils.deepCopy(generated),
        player = Survival.createPlayer(Progression.getFeats()),
        stats = {
            daysSurvived = generated.dayCount,
            firesLit = 0,
            metersWalked = 0,
            wolvesRepelled = 0,
            clothingRepairs = 0,
            waterBoiled = 0,
            meatCooked = 0,
        },
        runtime = {
            message = "",
            messageTimer = 0,
            causeOfDeath = "exposure",
            currentVisibleTiles = {},
            interactionHint = "",
            craftMenuOpen = false,
            craftIndex = 1,
            craftRecipes = {},
            alerts = {
                wolfThreat = 0,
                blizzard = 0,
                fireRisk = 0,
                weakIce = 0,
            },
            pendingShake = nil,
            currentPOI = nil,
            stations = {},
            currentStation = nil,
            discoveryToast = "",
            discoveryToastTimer = 0,
            camera = {
                x = 0,
                y = 0,
            },
            currentBiome = nil,
        },
        finished = false,
        replayMode = options.replayMode or false,
        replayProgress = 0,
        feats = Progression.getFeats(),
        startedAt = love.timer.getTime(),
    }

    run.player.coord = {generated.playerStart[1], generated.playerStart[2]}
    run.player.lastSafeCoord = {generated.playerStart[1], generated.playerStart[2]}
    run.world.mappedTiles = run.world.mappedTiles or {}
    run.world.discoveredPOIs = run.world.discoveredPOIs or {}
    run.world.goals = run.world.goals or {}
    run.world.landmarks = run.world.landmarks or {}
    run.world.regions = run.world.regions or {}
    run.world.connections = run.world.connections or {}
    run.world.traversalRequirements = run.world.traversalRequirements or {}
    World.attachRun(run)
    World.ensureActiveCollections(run, {
        "traps",
        "carcasses",
        "fishingSpots",
        "climbNodes",
        "mapNodes",
        "workbenches",
        "curingStations",
        "curing",
        "pointsOfInterest",
        "biomes",
        "gates",
        "npcEncounters",
    })

    if options.replayMode then
        applyReplayContext(run, options.context or {})
    elseif options.context then
        applyReplayContext(run, options.context)
    end

    run.runtime.currentBiome = currentBiomeRegion(run, run.player.coord) and currentBiomeRegion(run, run.player.coord).name or nil

    return run
end

local function pointOfInterestKey(poi)
    local gridX, gridY = Utils.pixelToGrid(poi.coord[1], poi.coord[2])
    return string.format("%s@%d:%d", poi.name or "POI", gridX, gridY)
end

local function discoverPointOfInterest(run, poi)
    local key = pointOfInterestKey(poi)
    if run.world.discoveredPOIs[key] then
        return false
    end
    run.world.discoveredPOIs[key] = true
    for _, goal in ipairs(run.world.goals or {}) do
        if goal.poi == poi.name then
            goal.completed = true
        end
    end
    run.runtime.discoveryToast = poi.name or "Point of interest"
    run.runtime.discoveryToastTimer = 2.4
    SoundEvents.play("poi_discovery")
    return true
end

local function updatePointOfInterestState(run)
    run.runtime.currentPOI = nil
    local nearestDistance = math.huge
    local pointsOfInterest = World.readActiveCollection(run, "pointsOfInterest")

    for _, poi in ipairs(pointsOfInterest) do
        if poi.hidden and not poi.revealed then
            goto continue
        end
        local gridX, gridY = Utils.pixelToGrid(poi.coord[1], poi.coord[2])
        local tileX = gridX + 1
        local tileY = gridY + 1
        if isVisibleTile(tileX, tileY) or isMappedTile(tileX, tileY) then
            discoverPointOfInterest(run, poi)
        end

        if run.world.discoveredPOIs[pointOfInterestKey(poi)] then
            local distance = Utils.distance(run.player.coord[1], run.player.coord[2], poi.coord[1], poi.coord[2])
            if distance <= CONFIG.TILE_SIZE * 3 and distance < nearestDistance then
                nearestDistance = distance
                run.runtime.currentPOI = poi.name
            end
        end
        ::continue::
    end
end

local function discoverMappedPointOfInterest(run, centerCoord, radiusTiles)
    local radius = radiusTiles * CONFIG.TILE_SIZE
    local pointsOfInterest = World.readActiveCollection(run, "pointsOfInterest")
    for _, poi in ipairs(pointsOfInterest) do
        if (not poi.hidden or poi.revealed)
            and Utils.distance(centerCoord[1], centerCoord[2], poi.coord[1], poi.coord[2]) <= radius then
            discoverPointOfInterest(run, poi)
        end
    end
end

updateVisibility = function()
    if not game.run then
        return
    end
    local run = game.run
    local radius = Survival.visibleRadius(run)
    run.runtime.currentVisibleTiles = {}
    run.world.mappedTiles = run.world.mappedTiles or {}
    local grid = World.activeGrid(run)
    local px, py = Utils.pixelToGrid(run.player.coord[1], run.player.coord[2])
    for dy = -radius, radius do
        for dx = -radius, radius do
            if math.sqrt((dx * dx) + (dy * dy)) <= radius then
                local gx = px + dx + 1
                local gy = py + dy + 1
                if grid[gy] and grid[gy][gx] then
                    run.runtime.currentVisibleTiles[gx .. ":" .. gy] = true
                    run.world.mappedTiles[gx .. ":" .. gy] = true
                end
            end
        end
    end
    updatePointOfInterestState(run)
end

isVisibleTile = function(x, y)
    if not game.run then
        return false
    end
    return game.run.runtime.currentVisibleTiles[x .. ":" .. y] == true
end

isMappedTile = function(x, y)
    if not game.run or not game.run.world.mappedTiles then
        return false
    end
    return game.run.world.mappedTiles[x .. ":" .. y] == true
end

local function startNewRun(options)
    options = options or {}
    if Replay.isRecording() then
        Replay.stopRecording()
    end
    if Replay.isPlaying() then
        Replay.stopPlayback()
    end

    local difficulty = canonicalDifficultyName(options.difficulty or game.selectedDifficulty)
    local mode = options.replayMode and "replay" or (options.mode or (options.useDailyChallenge and "daily" or "survival"))
    local seed = Utils.setGameSeed(options.useDailyChallenge or false, options.seed)
    local generated = ProcGen.generateRunData(difficulty, {
        layout = options.editorLayout,
    })
    local run = createRun(generated, difficulty, {
        replayMode = options.replayMode,
        context = options.context,
        mode = mode,
    })

    run.seed = seed
    game.run = run
    game.input.heldKeys = {}
    updateCamera(run)
    updateVisibility()
    refreshCraftMenu()
    updateRunSignals()
    SoundEvents.updateWeather(run.world.weather.current)

    if run.replayMode then
        run.runtime.message = string.format("%s replay playback", formatModeLabel(run.sourceMode))
        run.runtime.messageTimer = 2
    else
        Replay.startRecording(seed, difficulty, buildReplayContext(run))
        if generated.source == "editor" then
            run.runtime.message = "Editor playtest"
            run.runtime.messageTimer = 2
        end
    end

    game.screen = "game"
end

local function returnToTitle()
    if Replay.isRecording() then
        Replay.stopRecording()
    end
    if Replay.isPlaying() then
        Replay.stopPlayback()
    end
    SoundEvents.stop("walking")
    SoundEvents.updateWeather(nil)
    game.run = nil
    game.input.heldKeys = {}
    game.pauseIndex = 1
    game.screen = "title"
    refreshReplayEntries()
end

local function finalizeDeath()
    local run = game.run
    if not run or run.finished then
        return
    end
    run.finished = true
    run.player.alive = false
    Replay.stopRecording()
    Replay.stopPlayback()
    SoundEvents.stop("walking")
    SoundEvents.updateWeather(nil)
    if not run.replayMode then
        Progression.recordRun(run.stats)
    end
    Effects.startScreenShake(game.settings.gameplay.screenShake, CONFIG.SCREEN_SHAKE_INTENSITY * 1.2, CONFIG.SCREEN_SHAKE_DURATION * 1.5)
    SoundEvents.play("player_death")
    game.screen = "death"
end

local function finalizeSuccess()
    local run = game.run
    if not run or run.finished then
        return
    end
    run.finished = true
    run.player.alive = true
    Replay.stopRecording()
    Replay.stopPlayback()
    SoundEvents.stop("walking")
    SoundEvents.updateWeather(nil)
    if not run.replayMode then
        Progression.recordRun(run.stats)
    end
    setRunMessage("You activated the Weather Station.")
end

local function setDoorState()
    if not game.run then
        return
    end
    for _, structure in ipairs(game.run.world.structures or {}) do
        if structure.type == "cabin" then
            local doorCoord = {(structure.door.x - 1) * CONFIG.TILE_SIZE, (structure.door.y - 1) * CONFIG.TILE_SIZE}
            local isNear = Utils.distance(game.run.player.coord[1], game.run.player.coord[2], doorCoord[1], doorCoord[2]) <= CONFIG.TILE_SIZE * 1.2
            if isNear ~= structure.doorOpen then
                structure.doorOpen = isNear
                if isNear then
                    SoundEvents.play("door_open")
                end
            end
        end
    end
end

local function currentTileAtCoord(coord)
    local run = game.run
    local gx, gy = Utils.pixelToGrid(coord[1], coord[2])
    local grid = World.activeGrid(run)
    local row = grid[gy + 1]
    return row and row[gx + 1], gx + 1, gy + 1
end

local function tileAtRunCoord(run, coord)
    local gx, gy = Utils.pixelToGrid(coord[1], coord[2])
    local grid = World.activeGrid(run)
    local row = grid[gy + 1]
    return row and row[gx + 1], gx + 1, gy + 1
end

local function canOccupy(coord)
    local corners = {
        {coord[1], coord[2]},
        {coord[1] + CONFIG.TILE_SIZE - 2, coord[2]},
        {coord[1], coord[2] + CONFIG.TILE_SIZE - 2},
        {coord[1] + CONFIG.TILE_SIZE - 2, coord[2] + CONFIG.TILE_SIZE - 2},
    }
    for _, corner in ipairs(corners) do
        local tile = currentTileAtCoord(corner)
        if not Survival.isWalkableTile(tile) then
            return false
        end
    end
    return true
end

local function isMovementKeyDown(...)
    if Replay.isPlaying() then
        for index = 1, select("#", ...) do
            local key = select(index, ...)
            if game.input.heldKeys[key] then
                return true
            end
        end
        return false
    end
    return love.keyboard.isDown(...)
end

local function getMoveSpeed(isSprinting)
    local player = game.run.player
    local overweight = math.max(0, player.carryWeight - player.carryCapacity)
    local speed = CONFIG.PLAYER_WALK_SPEED
    if player.afflictions.sprain then
        speed = speed - CONFIG.SPRAIN_MOVE_PENALTY
        isSprinting = false
    end
    if overweight >= CONFIG.BADLY_OVERWEIGHT_THRESHOLD then
        speed = CONFIG.PLAYER_BADLY_OVERWEIGHT_SPEED
    elseif overweight > 0 then
        speed = CONFIG.PLAYER_OVERWEIGHT_SPEED
    elseif isSprinting then
        speed = CONFIG.PLAYER_SPRINT_SPEED
    end
    return Accessibility.getAdjustedSpeed(game.settings, speed)
end

local function consumeStamina(player, amount)
    if (player.stamina or 0) < amount then
        return false
    end
    player.stamina = math.max(0, player.stamina - amount)
    player.staminaRegenDelay = CONFIG.PLAYER_STAMINA_REGEN_DELAY
    return true
end

local function combatFacing(player)
    if player.lastMoveX ~= 0 or player.lastMoveY ~= 0 then
        return player.lastMoveX, player.lastMoveY
    end
    return player.combatFacingX or CONFIG.PLAYER_ATTACK_FACING_FALLBACK_X, player.combatFacingY or 0
end

local function queueAttack(kind)
    local player = game.run.player
    if player.attackState then
        return false, "You are already committed to an action."
    end

    if kind == "bow" then
        if player.equippedWeapon ~= "bow" then
            return false, "You need a bow ready."
        end
        if Items.count(player.inventory, "arrow") < 1 then
            return false, "You have no arrows."
        end
        if not consumeStamina(player, CONFIG.PLAYER_BOW_COST) then
            return false, "Too winded to draw the bow."
        end
        player.attackState = {
            kind = "bow",
            timer = CONFIG.PLAYER_BOW_WINDUP,
            recovery = CONFIG.PLAYER_BOW_RECOVERY,
            resolved = false,
        }
        return true, "You draw the bow."
    end

    if player.equippedWeapon ~= "sword" then
        return false, "You need a sword ready."
    end
    if not consumeStamina(player, CONFIG.PLAYER_MELEE_COST) then
        return false, "Too winded to swing."
    end
    player.attackState = {
        kind = "melee",
        timer = CONFIG.PLAYER_MELEE_WINDUP,
        recovery = CONFIG.PLAYER_MELEE_RECOVERY,
        resolved = false,
    }
    return true, "You commit to a sword slash."
end

local function performDodge()
    local player = game.run.player
    if player.attackState then
        return false, "You are mid-action."
    end
    if not consumeStamina(player, CONFIG.PLAYER_DODGE_COST) then
        return false, "Too exhausted to dodge."
    end

    local dx, dy = combatFacing(player)
    local length = math.sqrt((dx * dx) + (dy * dy))
    if length <= 0 then
        dx, dy = 0, 1
        length = 1
    end
    dx = dx / length
    dy = dy / length
    local dodgeDistance = CONFIG.PLAYER_DODGE_DISTANCE_TILES * CONFIG.TILE_SIZE
    local target = {
        player.coord[1] + (dx * dodgeDistance),
        player.coord[2] + (dy * dodgeDistance),
    }
    if canOccupy(target) then
        player.coord = target
    end
    player.invulnTimer = CONFIG.PLAYER_DODGE_DURATION
    player.combatFacingX = dx
    player.combatFacingY = dy
    game.run.runtime.pendingPulse = {
        kind = "impact",
        coord = {player.coord[1], player.coord[2]},
    }
    updateCamera(game.run)
    updateVisibility()
    return true, "You dodge through the opening."
end

local function movePlayer(dt)
    local player = game.run.player
    if player.attackState and player.attackState.timer > 0 then
        SoundEvents.stop("walking")
        return false
    end
    local dx, dy = 0, 0
    if isMovementKeyDown("w", "up") then
        dy = dy - 1
    end
    if isMovementKeyDown("s", "down") then
        dy = dy + 1
    end
    if isMovementKeyDown("a", "left") then
        dx = dx - 1
    end
    if isMovementKeyDown("d", "right") then
        dx = dx + 1
    end

    local sprinting = isMovementKeyDown("lshift", "rshift")
    if player.afflictions.sprain or math.max(0, player.carryWeight - player.carryCapacity) > 0 then
        sprinting = false
    end
    local moved = dx ~= 0 or dy ~= 0
    if not moved then
        SoundEvents.stop("walking")
        return false
    end

    local length = math.sqrt((dx * dx) + (dy * dy))
    dx = dx / length
    dy = dy / length
    player.lastMoveX = dx
    player.lastMoveY = dy
    player.combatFacingX = dx
    player.combatFacingY = dy

    local speed = getMoveSpeed(sprinting)
    local previous = {player.coord[1], player.coord[2]}
    local stepX = dx * speed * dt
    local stepY = dy * speed * dt
    local movedAxis = false
    local targetX = {player.coord[1] + stepX, player.coord[2]}
    if canOccupy(targetX) then
        player.coord = targetX
        movedAxis = true
    end
    local targetY = {player.coord[1], player.coord[2] + stepY}
    if canOccupy(targetY) then
        player.coord = targetY
        movedAxis = true
    end

    if movedAxis then
        local tile = currentTileAtCoord(player.coord)
        if tile ~= "weak_ice" and tile ~= "ice" then
            player.lastSafeCoord = {player.coord[1], player.coord[2]}
        end
        local distance = Utils.distance(previous[1], previous[2], player.coord[1], player.coord[2])
        game.run.stats.metersWalked = game.run.stats.metersWalked + (distance / CONFIG.TILE_SIZE)
        local transitioned, transitionMessage = World.stepPlayer(game.run)
        if transitioned or transitionMessage then
            setRunMessage(transitionMessage)
        end
    else
        player.coord = previous
    end

    if not SoundEvents.isPlaying("walking") then
        SoundEvents.play("walking")
    end
    return sprinting
end

local function gatherNode(node)
    for _, item in ipairs(node.loot or {}) do
        Items.add(game.run.player.inventory, item.kind, item.quantity or 1)
    end
    Items.sortInventory(game.run.player.inventory)
    Survival.updateCarryWeight(game.run.player)
    SoundEvents.play("item_pickup")
end

local function findNearbyNode()
    local resourceNodes = World.readActiveCollection(game.run, "resourceNodes")
    for index, node in ipairs(resourceNodes) do
        if node.hidden and not node.revealed then
            goto continue
        end
        local distance = Utils.distance(game.run.player.coord[1], game.run.player.coord[2], node.coord[1], node.coord[2])
        if distance <= CONFIG.TILE_SIZE * 1.2 then
            return node, index
        end
        ::continue::
    end
    return nil
end

local function findNearbySnowShelter()
    local snowShelters = World.readActiveCollection(game.run, "snowShelters")
    for _, shelter in ipairs(snowShelters) do
        local distance = Utils.distance(game.run.player.coord[1], game.run.player.coord[2], shelter.coord[1], shelter.coord[2])
        if distance <= CONFIG.TILE_SIZE * 1.2 then
            return shelter
        end
    end
    return nil
end

local function findNearbyCoordEntry(list)
    for index, entry in ipairs(list or {}) do
        local distance = Utils.distance(game.run.player.coord[1], game.run.player.coord[2], entry.coord[1], entry.coord[2])
        if distance <= CONFIG.TILE_SIZE * 1.2 then
            return entry, index
        end
    end
    return nil
end

local function findNearbyNPC(run)
    run = run or game.run
    local encounters = {}
    if run then
        encounters = World.readActiveCollection(run, "npcEncounters")
    end
    for _, encounter in ipairs(encounters) do
        if encounter.resolutionState == "active" then
            local distance = Utils.distance(run.player.coord[1], run.player.coord[2], encounter.coord[1], encounter.coord[2])
            if distance <= CONFIG.NPC_INTERACT_RADIUS_TILES * CONFIG.TILE_SIZE then
                return encounter
            end
        end
    end
    return nil
end

local function collectEncounterInventory(run, encounter)
    for _, item in ipairs(encounter.inventory or {}) do
        Items.add(run.player.inventory, item.kind, item.quantity or 1)
    end
    Items.sortInventory(run.player.inventory)
    Survival.updateCarryWeight(run.player)
end

local function resolveEncounterRumors(run, encounter)
    local changed = false
    for _, rumor in ipairs(encounter.rumors or {}) do
        local revealed = Survival.revealRumorTarget(run, rumor)
        changed = revealed or changed
    end
    return changed
end

local function interactWithNPC(run)
    local encounter = findNearbyNPC(run)
    return Survival.interactNPC(run, encounter)
end

refreshCraftMenu = function()
    if not game.run then
        return
    end
    game.run.runtime.craftRecipes = Survival.availableCraftRecipes(game.run)
    if game.run.runtime.craftIndex > #game.run.runtime.craftRecipes then
        game.run.runtime.craftIndex = #game.run.runtime.craftRecipes
    end
    if game.run.runtime.craftIndex < 1 then
        game.run.runtime.craftIndex = 1
    end
end

applyPendingShake = function()
    local pending = game.run and game.run.runtime.pendingShake
    if not pending then
        if game.run and game.run.runtime.pendingPulse then
            Effects.addPulse(game.run.runtime.pendingPulse.kind, game.run.runtime.pendingPulse.coord)
            game.run.runtime.pendingPulse = nil
        end
        return
    end
    Effects.startScreenShake(
        game.settings.gameplay.screenShake,
        pending.intensity or CONFIG.SCREEN_SHAKE_INTENSITY,
        pending.duration or CONFIG.SCREEN_SHAKE_DURATION
    )
    game.run.runtime.pendingShake = nil
    if game.run and game.run.runtime.pendingPulse then
        Effects.addPulse(game.run.runtime.pendingPulse.kind, game.run.runtime.pendingPulse.coord)
        game.run.runtime.pendingPulse = nil
    end
end

local function playPendingRuntimeSound(run)
    if run and run.runtime and run.runtime.pendingSound then
        SoundEvents.play(run.runtime.pendingSound)
        run.runtime.pendingSound = nil
    end
end

local function rebuildStationView(run)
    local stationsByKey = {}
    local function ensureStation(coord)
        local key = coordKey(coord)
        if not stationsByKey[key] then
            stationsByKey[key] = {
                coord = {coord[1], coord[2]},
                hasWorkbench = false,
                hasCuring = false,
                curingCount = 0,
                readyCount = 0,
            }
        end
        return stationsByKey[key]
    end

    local workbenches = World.readActiveCollection(run, "workbenches")
    local curingStations = World.readActiveCollection(run, "curingStations")
    local curingItems = World.readActiveCollection(run, "curing")

    for _, workbench in ipairs(workbenches) do
        local station = ensureStation(workbench.coord)
        station.hasWorkbench = true
    end
    for _, rack in ipairs(curingStations) do
        local station = ensureStation(rack.coord)
        station.hasCuring = true
    end
    for _, curing in ipairs(curingItems) do
        local station = ensureStation(curing.coord)
        station.hasCuring = true
        if curing.hoursRemaining <= 0 then
            station.readyCount = station.readyCount + 1
        else
            station.curingCount = station.curingCount + 1
        end
    end

    local stations = {}
    local nearestStation
    local nearestDistance = math.huge
    for _, station in pairs(stationsByKey) do
        station.label = stationLabel(station)
        station.state = station.readyCount > 0 and "ready" or (station.curingCount > 0 and "curing" or "idle")
        local tile = tileAtRunCoord(run, station.coord)
        station.overlayOnly = tile == "cabin_workbench"
        table.insert(stations, station)

        local distance = Utils.distance(run.player.coord[1], run.player.coord[2], station.coord[1], station.coord[2])
        if distance <= CONFIG.TILE_SIZE * 1.2 and distance < nearestDistance then
            nearestDistance = distance
            nearestStation = station
        end
    end

    table.sort(stations, function(left, right)
        if left.coord[2] == right.coord[2] then
            return left.coord[1] < right.coord[1]
        end
        return left.coord[2] < right.coord[2]
    end)

    run.runtime.stations = stations
    run.runtime.currentStation = nearestStation
end

updateRunSignals = function()
    local run = game.run
    if not run then
        return
    end

    rebuildStationView(run)

    local node = findNearbyNode()
    local shelter = findNearbySnowShelter()
    local trap = Wildlife.findNearbyTrap(run)
    local carcass = Wildlife.findNearbyCarcass(run)
    local fishingSpots = World.readActiveCollection(run, "fishingSpots")
    local climbNodes = World.readActiveCollection(run, "climbNodes")
    local mapNodes = World.readActiveCollection(run, "mapNodes")
    local fishingSpot = findNearbyCoordEntry(fishingSpots)
    local climbNode = findNearbyCoordEntry(climbNodes)
    local mapNode = findNearbyCoordEntry(mapNodes)
    local gate = Survival.findNearbyTraversalGate(run, true)
    local npcEncounter = findNearbyNPC(run)
    local currentStation = run.runtime.currentStation
    local currentBiome = currentBiomeRegion(run, run.player.coord)
    local alerts = {
        wolfThreat = 0,
        blizzard = 0,
        fireRisk = 0,
        weakIce = 0,
    }
    run.runtime.currentBiome = currentBiome and currentBiome.name or nil

    local tile = Survival.currentTile(run)
    if tile == "weak_ice" or (run.player.weakIceHours or 0) > 0 then
        alerts.weakIce = 0.9
    end

    local sheltered = Survival.isSheltered(run, run.player.coord)
    if run.world.weather.current == "blizzard" and not sheltered then
        alerts.blizzard = 0.55
    end

    local nearestFire, fireDistance = Fire.findNearest(run)
    local fireNearby = nearestFire
        and fireDistance <= CONFIG.FIRE_HEAT_RADIUS_TILES * CONFIG.TILE_SIZE
        and nearestFire.remainingBurnHours > 0

    if not sheltered and run.player.warmth < 35 and not fireNearby then
        alerts.fireRisk = Utils.clamp((35 - run.player.warmth) / 35, 0.2, 1)
    end

    local wolfAlertDistance = CONFIG.WOLF_DETECTION_RADIUS_TILES * CONFIG.TILE_SIZE
    local activeWildlife = World.activeWildlife(run)
    for _, listName in ipairs({"wolves", "raiders"}) do
        for _, hostile in ipairs(activeWildlife[listName] or {}) do
            local distance = Utils.distance(run.player.coord[1], run.player.coord[2], hostile.coord[1], hostile.coord[2])
            if distance <= wolfAlertDistance then
                local intensity = Utils.clamp(1 - (distance / wolfAlertDistance), 0.2, 1)
                if hostile.state == "charge" or hostile.state == "windup" then
                    intensity = 1
                elseif hostile.state == "stalk" then
                    intensity = math.max(intensity, 0.65)
                end
                alerts.wolfThreat = math.max(alerts.wolfThreat, intensity)
            end
        end
    end

    if tile == "weak_ice" then
        run.runtime.interactionHint = "Move off the weak ice."
    elseif trap and trap.state == "caught" then
        run.runtime.interactionHint = "E collect rabbit from the snare."
    elseif carcass then
        run.runtime.interactionHint = "E harvest the carcass."
    elseif fishingSpot then
        run.runtime.interactionHint = "E fish the hole."
    elseif npcEncounter then
        run.runtime.interactionHint = "E speak with the traveler."
    elseif gate then
        if gate.unlockState then
            run.runtime.interactionHint = "E take the opened route."
        elseif gate.toolType == "rope_bolt" then
            run.runtime.interactionHint = "E fire a rope bolt to open the route."
        elseif gate.toolType == "bridge_kit" then
            run.runtime.interactionHint = "E repair the crossing with a bridge kit."
        else
            run.runtime.interactionHint = "E fire a signal bolt to unlock the route."
        end
    elseif climbNode then
        run.runtime.interactionHint = "E climb the rope."
    elseif mapNode and Items.count(run.player.inventory, "survey_kit") > 0 then
        if Items.count(run.player.inventory, "charcoal") > 0 then
            run.runtime.interactionHint = "M map the area, G survey distant routes."
        else
            run.runtime.interactionHint = "G survey distant routes."
        end
    elseif mapNode and Items.count(run.player.inventory, "charcoal") > 0 then
        run.runtime.interactionHint = "M map the area with charcoal."
    elseif currentStation then
        if currentStation.hasWorkbench and currentStation.hasCuring then
            if currentStation.state == "ready" then
                run.runtime.interactionHint = "C craft at the Workbench / Curing Rack. E collect cured items."
            else
                run.runtime.interactionHint = "C craft at the Workbench / Curing Rack. X hang fresh hides or gut to cure."
            end
        elseif currentStation.hasWorkbench then
            run.runtime.interactionHint = "C craft at the Workbench."
        elseif currentStation.state == "ready" then
            run.runtime.interactionHint = "E collect cured items."
        else
            run.runtime.interactionHint = "X hang fresh hides or gut to cure."
        end
    elseif node and not node.opened then
        if node.type == "wood" then
            run.runtime.interactionHint = "E gather wood."
        elseif node.type == "cache" then
            run.runtime.interactionHint = "E open the supply cache."
        else
            run.runtime.interactionHint = "E scavenge supplies."
        end
    elseif run.runtime.craftMenuOpen then
        run.runtime.interactionHint = "Crafting."
    elseif shelter then
        run.runtime.interactionHint = "R rest, X repair or dismantle shelter."
    elseif fireNearby then
        run.runtime.interactionHint = "E cook or boil. F feed the fire."
    elseif Survival.canSleepAt(run) then
        run.runtime.interactionHint = "R rest here."
    elseif run.player.equippedWeapon == "bow" and Items.count(run.player.inventory, "arrow") > 0 then
        run.runtime.interactionHint = "Space fire, Q dodge."
    elseif run.player.equippedWeapon == "sword" then
        run.runtime.interactionHint = "Space slash, Q dodge."
    elseif run.world.weather.current == "blizzard" and not sheltered then
        run.runtime.interactionHint = "Find shelter or light a fire."
    else
        run.runtime.interactionHint = ""
    end

    run.runtime.alerts = alerts
end

local function interact()
    local facingOk, facingMessage = World.interactFacing(game.run)
    if facingOk or facingMessage then
        setRunMessage(facingMessage)
        applyPendingShake()
        playPendingRuntimeSound(game.run)
        updateVisibility()
        updateCamera(game.run)
        updateRunSignals()
        refreshCraftMenu()
        return facingOk
    end

    local npcEncounter = findNearbyNPC(game.run)
    if npcEncounter then
        local ok, message = interactWithNPC(game.run)
        setRunMessage(message)
        updateVisibility()
        updateRunSignals()
        refreshCraftMenu()
        return ok
    end

    local gate = Survival.findNearbyTraversalGate(game.run, true)
    if gate then
        local ok, message = Survival.useTraversalGate(game.run, gate)
        setRunMessage(message)
        applyPendingShake()
        updateVisibility()
        updateCamera(game.run)
        updateRunSignals()
        return ok
    end

    local trap = Wildlife.findNearbyTrap(game.run)
    if trap and trap.state == "caught" then
        local ok, message = Wildlife.collectTrap(game.run)
        setRunMessage(message)
        refreshCraftMenu()
        if ok then
            SoundEvents.play("snare_catch")
        end
        return ok
    end

    local carcass = Wildlife.findNearbyCarcass(game.run)
    if carcass then
        local ok, message = Wildlife.harvestNearbyCarcass(game.run)
        setRunMessage(message)
        updateVisibility()
        updateRunSignals()
        refreshCraftMenu()
        if ok then
            SoundEvents.play("harvest")
        end
        return ok
    end

    local fishingSpots = World.readActiveCollection(game.run, "fishingSpots")
    local fishingSpot = findNearbyCoordEntry(fishingSpots)
    if fishingSpot then
        local ok, message = Wildlife.fish(game.run)
        setRunMessage(message)
        updateVisibility()
        updateRunSignals()
        if ok then
            SoundEvents.play("fish_catch")
        end
        return ok
    end

    local climbNodes = World.readActiveCollection(game.run, "climbNodes")
    local climbNode = findNearbyCoordEntry(climbNodes)
    if climbNode then
        local ok, message = Survival.useRopeClimb(game.run)
        setRunMessage(message)
        applyPendingShake()
        updateVisibility()
        updateRunSignals()
        if ok then
            SoundEvents.play("rope_climb")
        end
        return ok
    end

    local curingStations = World.readActiveCollection(game.run, "curingStations")
    local curingStation = findNearbyCoordEntry(curingStations)
    if curingStation then
        local ok, message = Survival.collectCuredItems(game.run)
        if not ok then
            ok, message = Survival.startCuring(game.run)
        end
        setRunMessage(message)
        refreshCraftMenu()
        return ok
    end

    local node, index = findNearbyNode()
    if node and not node.opened then
        node.opened = true
        gatherNode(node)
        if node.type ~= "cache" then
            local resourceNodes = World.readActiveCollection(game.run, "resourceNodes")
            table.remove(resourceNodes, index)
        end
        if node.type == "wood" then
            setRunMessage("You break down some wood.")
        elseif node.type == "cache" then
            setRunMessage("You open a supply cache.")
        else
            setRunMessage("You scavenge the area.")
        end
        return
    end

    local ok, message = Fire.interact(game.run)
    if ok or message ~= "No fire to work from." then
        setRunMessage(message)
        return
    end

    if Survival.canSleepAt(game.run) then
        setRunMessage("You can rest here. Press R.")
    else
        setRunMessage("Nothing useful nearby.")
    end
end

local function performContextAction()
    local trap = Wildlife.findNearbyTrap(game.run)
    if trap then
        if trap.state == "caught" then
            local ok, message = Wildlife.collectTrap(game.run)
            setRunMessage(message)
            refreshCraftMenu()
            if ok then
                SoundEvents.play("snare_catch")
            end
            return ok
        end
    end

    local ok, message = Wildlife.placeSnare(game.run)
    if ok then
        setRunMessage(message)
        refreshCraftMenu()
        SoundEvents.play("snare_set")
        return ok
    end

    ok, message = Survival.dismantleSnowShelter(game.run)
    if not ok then
        ok, message = Survival.repairSnowShelter(game.run)
    end
    if ok then
        setRunMessage(message)
        refreshCraftMenu()
        return ok
    end

    ok, message = Survival.collectCuredItems(game.run)
    if not ok then
        ok, message = Survival.startCuring(game.run)
    end
    setRunMessage(message)
    refreshCraftMenu()
    return ok
end

local function performFireAction()
    local nearestFire, distance = Fire.findNearest(game.run)
    if nearestFire and distance <= CONFIG.FIRE_HEAT_RADIUS_TILES * CONFIG.TILE_SIZE then
        local ok, message = Fire.feed(game.run)
        if not ok then
            ok, message = Fire.interact(game.run)
        end
        Survival.updateCarryWeight(game.run.player)
        setRunMessage(message)
        return ok
    end

    local ok, message = Fire.start(game.run, love.keyboard.isDown("lshift", "rshift"))
    Survival.updateCarryWeight(game.run.player)
    if not ok then
        Effects.startScreenShake(game.settings.gameplay.screenShake, CONFIG.SCREEN_SHAKE_INTENSITY * 0.7, CONFIG.SCREEN_SHAKE_DURATION)
    end
    setRunMessage(message)
    return ok
end

local function simulateHours(hours, sleeping)
    local steps = math.max(1, math.floor(hours / 0.25))
    local stepHours = hours / steps
    for _ = 1, steps do
        if not game.run.player.alive then
            break
        end
        Survival.advanceTime(game.run, stepHours)
        Fire.update(game.run, stepHours)
        Wildlife.update(game.run, stepHours)
        Survival.update(game.run, stepHours, {sleeping = sleeping})
        setDoorState()
        applyPendingShake()
    end
    updateVisibility()
    updateCamera(game.run)
    refreshCraftMenu()
    updateRunSignals()
    if game.run.player.condition <= 0 or not game.run.player.alive then
        finalizeDeath()
    end
end

local function rest()
    if not Survival.canSleepAt(game.run) then
        setRunMessage("You need a bed, bedroll, cave, or shelter.")
        return
    end

    simulateHours(CONFIG.SLEEP_REST_HOURS, true)
    if game.run and game.run.player.alive then
        if game.run.feats.Beddown then
            game.run.player.fatigue = Utils.clamp(game.run.player.fatigue + 8, 0, CONFIG.MAX_FATIGUE)
        end
        setRunMessage("You sleep for a short stretch.")
    end
end

local function toggleCraftMenu()
    if not Survival.isSheltered(game.run, game.run.player.coord) and not Survival.isWorkbenchNearby(game.run) then
        local ok, message = Survival.craftSnowShelter(game.run)
        setRunMessage(message)
        refreshCraftMenu()
        if ok then
            SoundEvents.play("craft")
        end
        return ok
    end

    game.run.runtime.craftMenuOpen = not game.run.runtime.craftMenuOpen
    refreshCraftMenu()
    if game.run.runtime.craftMenuOpen then
        setRunMessage("Crafting open.")
    else
        setRunMessage("Crafting closed.")
    end
    return true
end

local function toggleBow()
    if game.run.player.equippedWeapon == "bow" then
        game.run.player.equippedWeapon = nil
        setRunMessage("You lower the bow.")
        return true
    end

    if Items.count(game.run.player.inventory, "bow") > 0 then
        game.run.player.equippedWeapon = "bow"
        setRunMessage("You ready the bow.")
        SoundEvents.play("bow_ready")
        return true
    end

    setRunMessage("No bow in your pack.")
    return false
end

local function toggleSword()
    if game.run.player.equippedWeapon == "sword" then
        game.run.player.equippedWeapon = nil
        game.run.player.equippedMeleeWeapon = "sword"
        setRunMessage("You lower the sword.")
        return true
    end

    if Items.count(game.run.player.inventory, "sword") > 0 then
        game.run.player.equippedWeapon = "sword"
        game.run.player.equippedMeleeWeapon = "sword"
        setRunMessage("You ready the sword.")
        return true
    end

    setRunMessage("No sword in your pack.")
    return false
end

local function handleGameplayActionKey(key)
    if key == "e" then
        interact()
    elseif key == "f" then
        performFireAction()
    elseif key == "r" then
        rest()
    elseif key == "c" then
        toggleCraftMenu()
    elseif key == "x" then
        performContextAction()
    elseif key == "h" then
        local ok, message = Survival.repairWorstClothing(game.run)
        setRunMessage(message)
        refreshCraftMenu()
    elseif key == "t" then
        local ok, message = Survival.autoTreat(game.run)
        setRunMessage(message)
        if ok then
            SoundEvents.play("treat")
        end
    elseif key == "m" then
        local ok, message = Survival.mapArea(game.run)
        setRunMessage(message)
        applyPendingShake()
        updateVisibility()
        if ok then
            local mapNodes = World.readActiveCollection(game.run, "mapNodes")
            local mapNode = findNearbyCoordEntry(mapNodes)
            if mapNode then
                discoverMappedPointOfInterest(game.run, mapNode.coord, CONFIG.MAP_REVEAL_RADIUS)
            end
        end
        updateRunSignals()
        if ok then
            SoundEvents.play("map_reveal")
        end
    elseif key == "g" then
        local ok, message = Survival.surveyArea(game.run)
        setRunMessage(message)
        applyPendingShake()
        updateVisibility()
        updateRunSignals()
    elseif key == "q" then
        local ok, message = performDodge()
        setRunMessage(message)
        applyPendingShake()
        updateRunSignals()
    elseif key == "b" then
        toggleBow()
    elseif key == "v" then
        toggleSword()
    elseif key == "space" then
        local weapon = game.run.player.equippedWeapon
        local ok, message
        if weapon == "bow" then
            ok, message = queueAttack("bow")
        elseif weapon == "sword" then
            ok, message = queueAttack("melee")
        elseif game.run.player.equippedTool then
            ok, message = World.hitFacing(game.run, game.run.player.equippedTool)
            if ok then
                Survival.updateCarryWeight(game.run.player)
                refreshCraftMenu()
                updateVisibility()
                updateRunSignals()
            end
        else
            ok, message = false, "Ready a sword, bow, or tool first."
        end
        setRunMessage(message)
    else
        local index = tonumber(key)
        if index then
            local ok, message = Survival.consumeInventoryIndex(game.run, index)
            setRunMessage(message)
            refreshCraftMenu()
        end
    end
end

local function applyReplayInput(input)
    if input.type == "keydown" then
        game.input.heldKeys[input.key] = true
        handleGameplayActionKey(input.key)
    elseif input.type == "keyup" then
        game.input.heldKeys[input.key] = nil
    end
end

local function updateCombatState(run, dt)
    local player = run.player

    if (player.invulnTimer or 0) > 0 then
        player.invulnTimer = math.max(0, player.invulnTimer - dt)
    end

    if player.attackState then
        player.attackState.timer = player.attackState.timer - dt
        if player.attackState.timer <= 0 and not player.attackState.resolved then
            local ok, message
            if player.attackState.kind == "bow" then
                ok, message = Wildlife.fireBow(run, true)
                SoundEvents.play("bow_fire")
                if ok then
                    SoundEvents.play("arrow_hit")
                end
            else
                ok, message = Wildlife.playerMeleeAttack(run)
                if ok then
                    SoundEvents.play("harvest")
                end
            end
            player.attackState.resolved = true
            player.attackState.timer = player.attackState.recovery
            setRunMessage(message)
            applyPendingShake()
        elseif player.attackState.timer <= 0 and player.attackState.resolved then
            player.attackState = nil
        end
    end

    if (player.staminaRegenDelay or 0) > 0 then
        player.staminaRegenDelay = math.max(0, player.staminaRegenDelay - dt)
    elseif not player.attackState then
        player.stamina = math.min(
            player.maxStamina,
            player.stamina + (CONFIG.PLAYER_STAMINA_REGEN_PER_SECOND * dt)
        )
    end
end

local function updateGame(dt)
    local run = game.run
    if not run then
        return
    end

    Replay.update(dt)
    while Replay.isPlaying() do
        local replayInput = Replay.getNextInput()
        if not replayInput then
            break
        end
        applyReplayInput(replayInput)
    end
    run.replayProgress = Replay.getPlaybackProgress()
    SoundEvents.updateWeather(run.world.weather.current)

    if run.runtime.messageTimer > 0 then
        run.runtime.messageTimer = run.runtime.messageTimer - dt
        if run.runtime.messageTimer <= 0 then
            run.runtime.message = ""
        end
    end
    if run.runtime.discoveryToastTimer > 0 then
        run.runtime.discoveryToastTimer = run.runtime.discoveryToastTimer - dt
        if run.runtime.discoveryToastTimer <= 0 then
            run.runtime.discoveryToast = ""
        end
    end

    if run.finished then
        return
    end

    Effects.update(dt)
    updateCombatState(run, dt)

    if run.runtime.craftMenuOpen then
        updateVisibility()
        updateRunSignals()
        return
    end

    local sprinting = movePlayer(dt)
    local hours = dt * CONFIG.GAME_HOURS_PER_REAL_SECOND
    Survival.advanceTime(run, hours)
    Fire.update(run, hours)
    Wildlife.update(run, hours)
    World.tick(run, hours)
    Survival.update(run, hours, {sprinting = sprinting})
    setDoorState()
    applyPendingShake()
    updateVisibility()
    updateCamera(run)
    refreshCraftMenu()
    updateRunSignals()

    if run.runtime.endgameActivated then
        finalizeSuccess()
    elseif run.player.condition <= 0 or not run.player.alive then
        finalizeDeath()
    end
end

local function drawTile(tile, drawX, drawY)
    SpriteRegistry.drawTile(sprites, tile, drawX, drawY, game.settings)
end

local function tileCoord(coord)
    local gx, gy = Utils.pixelToGrid(coord[1], coord[2])
    return gx + 1, gy + 1
end

local function shouldDrawLegacyEntry(entry)
    return not (entry and (entry._entityKey or (entry._entity and entry._entity.render)))
end

local function hasEntityStation(level, station)
    local x, y = tileCoord(station.coord)
    for _, entity in ipairs(EntitySystem.getTileEntities(level, x, y)) do
        if entity.station or entity.stations then
            return true
        end
    end
    return false
end

local function drawWorld()
    local run = game.run
    local level = World.currentLevel(run)
    local grid = World.activeGrid(run)
    local resourceNodes = World.readActiveCollection(run, "resourceNodes")
    local pointsOfInterest = World.readActiveCollection(run, "pointsOfInterest")
    Wildlife.mirrorLevel(level)
    updateCamera(run)

    love.graphics.clear(0.02, 0.05, 0.08, 1)
    love.graphics.push()
    if Effects.screenShake.active then
        love.graphics.translate(Effects.screenShake.offsetX, Effects.screenShake.offsetY)
    end
    love.graphics.translate(-run.runtime.camera.x, -run.runtime.camera.y)

    for y = 1, #grid do
        for x = 1, #grid[y] do
            if isVisibleTile(x, y) or isMappedTile(x, y) then
                local drawX = (x - 1) * CONFIG.TILE_SIZE
                local drawY = (y - 1) * CONFIG.TILE_SIZE
                drawTile(grid[y][x], drawX, drawY)
                if not isVisibleTile(x, y) then
                    Accessibility.setColor(game.settings, 0, 0, 0, 0.58)
                    love.graphics.rectangle("fill", drawX, drawY, CONFIG.TILE_SIZE, CONFIG.TILE_SIZE)
                end
            end
        end
    end

    for _, structure in ipairs(level.structures or {}) do
        if structure.type == "cabin" and isVisibleTile(structure.door.x, structure.door.y) then
            SpriteRegistry.drawDoor(sprites, structure.doorOpen,
                (structure.door.x - 1) * CONFIG.TILE_SIZE,
                (structure.door.y - 1) * CONFIG.TILE_SIZE,
                game.settings)
        end
    end

    for _, node in ipairs(resourceNodes) do
        local gx, gy = Utils.pixelToGrid(node.coord[1], node.coord[2])
        if shouldDrawLegacyEntry(node) and (not node.hidden or node.revealed) and isVisibleTile(gx + 1, gy + 1) then
            SpriteRegistry.drawResourceNode(sprites, node, game.settings)
        end
    end

    EntitySystem.render(level, {
        drawTile = function(tile, x, y)
            local gx, gy = tileCoord({x, y})
            if isVisibleTile(gx, gy) then
                SpriteRegistry.drawTile(sprites, tile, x, y, game.settings)
            end
        end,
        drawResourceNode = function(node)
            local gx, gy = tileCoord(node.coord)
            if (not node.hidden or node.revealed) and isVisibleTile(gx, gy) then
                SpriteRegistry.drawResourceNode(sprites, node, game.settings)
            end
        end,
        drawStation = function(station)
            local gx, gy = tileCoord(station.coord)
            if isVisibleTile(gx, gy) then
                SpriteRegistry.drawStation(sprites, station, game.settings)
            end
        end,
        drawWildlife = function(actor)
            local gx, gy = tileCoord(actor.coord)
            if isVisibleTile(gx, gy) then
                SpriteRegistry.drawWildlife(sprites, actor, game.settings)
            end
        end,
        drawFire = function(fire)
            local gx, gy = tileCoord(fire.coord)
            if isVisibleTile(gx, gy) then
                SpriteRegistry.drawFire(sprites, fire, game.settings, love.timer.getTime())
            end
        end,
        drawTrap = function(trap)
            local gx, gy = tileCoord(trap.coord)
            if isVisibleTile(gx, gy) then
                SpriteRegistry.drawTrap(sprites, trap, game.settings)
            end
        end,
        drawCarcass = function(carcass)
            local gx, gy = tileCoord(carcass.coord)
            if isVisibleTile(gx, gy) then
                SpriteRegistry.drawCarcass(sprites, carcass, game.settings)
            end
        end,
        drawWorldMarker = function(kind, marker)
            local gx, gy = tileCoord(marker.coord)
            if isVisibleTile(gx, gy) then
                SpriteRegistry.drawWorldMarker(sprites, kind, marker.coord, game.settings)
            end
        end,
    })

    for _, station in ipairs(run.runtime.stations or {}) do
        local gx, gy = Utils.pixelToGrid(station.coord[1], station.coord[2])
        if not hasEntityStation(level, station) and isVisibleTile(gx + 1, gy + 1) then
            SpriteRegistry.drawStation(sprites, station, game.settings)
        end
    end

    love.graphics.setFont(fonts.small)
    for _, poi in ipairs(pointsOfInterest) do
        if poi.hidden and not poi.revealed then
            goto continue
        end
        local gx, gy = Utils.pixelToGrid(poi.coord[1], poi.coord[2])
        local key = pointOfInterestKey(poi)
        if run.world.discoveredPOIs[key] and (isVisibleTile(gx + 1, gy + 1) or isMappedTile(gx + 1, gy + 1)) then
            Accessibility.setColor(game.settings, 0.92, 0.95, 1, isVisibleTile(gx + 1, gy + 1) and 0.95 or 0.62)
            love.graphics.print(poi.name, poi.coord[1] - 4, poi.coord[2] - 14)
        end
        ::continue::
    end

    Effects.drawWorldOverlay(game.settings, run)
    SpriteRegistry.drawPlayer(sprites, run.player.alive, run.player.coord, game.settings)

    love.graphics.pop()
    UI.drawHUD(run, fonts, game.settings, sprites)
    UI.drawCraftMenu(run, fonts, game.settings)
    Accessibility.drawVisualAlerts(game.settings, run.runtime.alerts, love.timer.getTime())
end

local function openSettings(previousScreen)
    game.previousScreen = previousScreen
    game.screen = "settings"
    refreshSettingsOptions()
end

local function openReplayScreen()
    refreshReplayEntries()
    game.screen = "replays"
end

local function openSaveScreen(previousScreen)
    game.saveScreen.previousScreen = previousScreen or game.screen
    refreshSaveEntries()
    game.screen = "saves"
end

local function startReplayFromSelection()
    local entry = game.replayScreen.entries[game.replayScreen.index]
    if not entry then
        return false
    end
    if not Replay.load(entry.file) then
        return false
    end
    local replay = Replay.inspect(entry.file)
    if not replay then
        return false
    end
    startNewRun({
        difficulty = canonicalDifficultyName(replay.difficulty or game.selectedDifficulty),
        seed = replay.seed,
        replayMode = true,
        context = replay.context or {},
    })
    return Replay.startPlayback()
end

function love.load()
    love.window.setTitle(string.format("%s v%s", CONFIG.WINDOW_TITLE, CONFIG.VERSION))
    configureWindow()

    game.settings = Settings.load()
    Progression.load()

    rebuildFonts()
    buildTitleItems()
    refreshSettingsOptions()

    sprites = SpriteRegistry.load()
    SoundEvents.init()
    SoundEvents.load()
    applyAudioSettings()
    SoundEvents.play("ambient")

    Effects.init()
    Editor.init()
    Editor.setPlaytestCallback(function(layout)
        startNewRun({
            editorLayout = layout,
            mode = "survival",
        })
    end)
    Replay.init()
    refreshReplayEntries()
    refreshSaveEntries()

    love._tikritDebug = {
        getGameState = function()
            return game
        end,
        getSoundEventLog = function()
            return SoundEvents.getEventLog()
        end,
        startEditorPlaytest = function(layout)
            startNewRun({
                editorLayout = layout,
                mode = "survival",
            })
        end,
        startReplayContext = function(context, seed, difficulty)
            startNewRun({
                seed = seed,
                difficulty = difficulty,
                replayMode = true,
                context = context or {},
            })
            return game.run
        end,
        saveCurrentGame = function()
            return saveCurrentGame()
        end,
        saveManualGame = function()
            return saveManualGame()
        end,
        deleteSaveSlot = function(slot)
            return SaveGame.delete(slot)
        end,
        loadSaveSlot = function(slot)
            local run = SaveGame.loadRun(slot)
            if not run then
                return nil
            end
            restoreLoadedRun(run)
            return game.run
        end,
        refreshSaveEntries = function()
            refreshSaveEntries()
            return game.saveScreen.entries
        end,
    }
end

function love.update(dt)
    if Editor.isActive() then
        Editor.update(dt)
        return
    end

    if game.screen == "game" then
        updateGame(dt)
    end
end

function love.draw()
    if Editor.isActive() then
        Editor.draw()
        return
    end

    if game.screen == "title" then
        UI.drawTitleScreen(game, fonts, game.settings)
    elseif game.screen == "settings" then
        UI.drawSettingsScreen(game.settingsScreen, fonts, game.settings)
    elseif game.screen == "profile" then
        UI.drawProfileScreen(Progression.data, fonts, game.settings)
    elseif game.screen == "replays" then
        UI.drawReplayScreen(game.replayScreen, fonts, game.settings)
    elseif game.screen == "saves" then
        UI.drawSaveScreen(game.saveScreen, fonts, game.settings)
    elseif game.screen == "game" then
        drawWorld()
    elseif game.screen == "pause" then
        drawWorld()
        UI.drawPauseScreen(game.pauseOptions, game.pauseIndex, fonts, game.settings)
    elseif game.screen == "death" then
        UI.drawDeathScreen(game.run, fonts, game.settings)
    end
end

function love.keypressed(key)
    if Replay.isRecording() and game.screen == "game" then
        Replay.recordKeyState(key, true, love.timer.getTime() - game.run.startedAt)
    end

    if Editor.isActive() then
        Editor.keypressed(key)
        return
    end

    if key == "f5" and game.screen ~= "game" then
        Editor.toggle()
        return
    end

    if Replay.isPlaying() and game.screen == "game" then
        if key == "escape" then
            returnToTitle()
        end
        return
    end

    if game.screen == "title" then
        if key == "up" then
            game.titleIndex = math.max(1, game.titleIndex - 1)
        elseif key == "down" then
            game.titleIndex = math.min(#game.titleItems, game.titleIndex + 1)
        elseif key == "left" and game.titleIndex == 2 then
            cycleDifficulty(-1)
        elseif key == "right" and game.titleIndex == 2 then
            cycleDifficulty(1)
        elseif key == "return" then
            local action = game.titleItems[game.titleIndex] and game.titleItems[game.titleIndex].action
            if action == "start" then
                startNewRun()
            elseif action == "difficulty" then
                cycleDifficulty(1)
            elseif action == "daily" then
                startNewRun({useDailyChallenge = true})
            elseif action == "load_game" then
                openSaveScreen("title")
            elseif action == "settings" then
                openSettings("title")
            elseif action == "profile" then
                game.previousScreen = "title"
                game.screen = "profile"
            elseif action == "replays" then
                openReplayScreen()
            elseif action == "quit" then
                love.event.quit()
            end
        elseif key == "escape" then
            love.event.quit()
        end
        return
    end

    if game.screen == "settings" then
        if key == "tab" then
            game.settingsScreen.categoryIndex = (game.settingsScreen.categoryIndex % #game.settingsScreen.categories) + 1
            refreshSettingsOptions()
        elseif key == "up" then
            game.settingsScreen.optionIndex = math.max(1, game.settingsScreen.optionIndex - 1)
        elseif key == "down" then
            game.settingsScreen.optionIndex = math.min(#game.settingsScreen.options, game.settingsScreen.optionIndex + 1)
        elseif key == "left" or key == "right" then
            local option = game.settingsScreen.options[game.settingsScreen.optionIndex]
            if option then
                adjustSetting(option.definition, key == "left" and -1 or 1)
            end
        elseif key == "escape" then
            game.screen = game.previousScreen
        end
        return
    end

    if game.screen == "profile" then
        if key == "escape" or key == "return" then
            game.screen = game.previousScreen
        end
        return
    end

    if game.screen == "replays" then
        if key == "up" then
            game.replayScreen.index = math.max(1, game.replayScreen.index - 1)
        elseif key == "down" then
            game.replayScreen.index = math.min(#game.replayScreen.entries, game.replayScreen.index + 1)
        elseif key == "r" then
            refreshReplayEntries()
        elseif key == "return" then
            startReplayFromSelection()
        elseif key == "escape" then
            game.screen = "title"
        end
        return
    end

    if game.screen == "saves" then
        if key == "up" then
            game.saveScreen.index = math.max(1, game.saveScreen.index - 1)
        elseif key == "down" then
            game.saveScreen.index = math.min(#game.saveScreen.entries, game.saveScreen.index + 1)
        elseif key == "r" then
            refreshSaveEntries()
        elseif key == "d" or key == "delete" or key == "backspace" then
            deleteSaveSelection()
        elseif key == "return" then
            loadSaveFromSelection()
        elseif key == "escape" then
            game.screen = game.saveScreen.previousScreen or "title"
        end
        return
    end

    if game.screen == "game" then
        if game.run and game.run.runtime.craftMenuOpen then
            if key == "up" then
                game.run.runtime.craftIndex = math.max(1, game.run.runtime.craftIndex - 1)
            elseif key == "down" then
                game.run.runtime.craftIndex = math.min(#game.run.runtime.craftRecipes, game.run.runtime.craftIndex + 1)
            elseif key == "return" then
                local recipe = game.run.runtime.craftRecipes[game.run.runtime.craftIndex]
                if recipe then
                    local ok, message = Survival.craftRecipe(game.run, recipe.key)
                    setRunMessage(message)
                    refreshCraftMenu()
                    if ok then
                        SoundEvents.play("craft")
                    end
                end
            elseif key == "escape" or key == "c" then
                game.run.runtime.craftMenuOpen = false
                updateRunSignals()
            end
            return
        end
        if key == "escape" or key == "p" then
            game.screen = "pause"
        else
            handleGameplayActionKey(key)
        end
        return
    end

    if game.screen == "pause" then
        if key == "up" then
            game.pauseIndex = math.max(1, game.pauseIndex - 1)
        elseif key == "down" then
            game.pauseIndex = math.min(#game.pauseOptions, game.pauseIndex + 1)
        elseif key == "return" then
            local action = game.pauseOptions[game.pauseIndex] and game.pauseOptions[game.pauseIndex].action
            if action == "resume" then
                game.screen = "game"
            elseif action == "settings" then
                openSettings("pause")
            elseif action == "save_game" then
                saveManualGame()
            elseif action == "load_game" then
                openSaveScreen("pause")
            elseif action == "save_replay" then
                saveReplaySnapshot()
            elseif action == "restart" then
                startNewRun()
            elseif action == "quit_title" then
                returnToTitle()
            end
        elseif key == "escape" or key == "p" then
            game.screen = "game"
        end
        return
    end

    if game.screen == "death" then
        if key == "s" and game.run and not game.run.replayMode then
            saveReplaySnapshot()
        elseif key == "return" or key == "escape" then
            returnToTitle()
        end
    end
end

function love.keyreleased(key)
    if Replay.isRecording() and game.screen == "game" then
        Replay.recordKeyState(key, false, love.timer.getTime() - game.run.startedAt)
    end
    if Replay.isPlaying() and game.screen == "game" then
        game.input.heldKeys[key] = nil
    end
end

function love.mousereleased(x, y, button)
    if Editor.isActive() then
        Editor.mousereleased(x, y, button)
    end
end

function love.wheelmoved(x, y)
    if Editor.isActive() then
        Editor.wheelmoved(x, y)
    end
end
