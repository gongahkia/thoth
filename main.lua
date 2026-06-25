package.path = "./?.lua;./?/init.lua;./src/?.lua;./src/?/init.lua;" .. package.path

local Input = require("src.app.input")
local Render = require("src.app.render")
local Audio = require("src.app.audio")
local Accessibility = require("src.app.accessibility")
local Save = require("src.game.save")
local Replay = require("src.game.replay")
local ReplayViewer = require("src.app.replay_viewer")
local Settings = require("src.app.settings")
local Achievements = require("src.app.achievements")
local SpritePipeline = require("src.app.sprite_pipeline")
local ModelPipeline = require("src.app.model_pipeline")
local TacticsState = require("src.game.tactics.state")
local TacticalRuntime = require("src.game.tactical_runtime")
local SquadLoadout = require("src.game.tactics.squad_loadout")

local sim
local app

local function newTacticalSim(seed)
    local world = { tiles = {} }
    function world:setTile(x, y, z, tile)
        self.tiles[tostring(x) .. ":" .. tostring(y) .. ":" .. tostring(z or 0)] = tile
    end
    function world:peekTile(x, y, z)
        return self.tiles[tostring(x) .. ":" .. tostring(y) .. ":" .. tostring(z or 0)] or { id = "archive_floor", data = 0 }
    end
    function world:getTile(x, y, z)
        return self:peekTile(x, y, z)
    end
    local party = {
        { rank = 1, name = "warden", class = "warden", level = 1, hp = 6, maxHp = 6, stress = 0 },
        { rank = 2, name = "duelist", class = "duelist", level = 1, hp = 5, maxHp = 5, stress = 0 },
        { rank = 3, name = "apothecary", class = "apothecary", level = 1, hp = 4, maxHp = 4, stress = 0 },
        { rank = 4, name = "thief", class = "thief", level = 1, hp = 4, maxHp = 4, stress = 0 },
    }
    return {
        seed = seed,
        mode = "tactical",
        status = "tactical",
        tick = 0,
        player = { x = 0, y = 0, z = 0, selectedHero = 1 },
        world = world,
        estate = { gold = 0, heirlooms = 0 },
        log = { "route online" },
        narration = "render smoke",
        currentRoomKey = function()
            return "tactical"
        end,
        nextStepText = function()
            return "read the route"
        end,
        objectiveChecklist = function()
            return { { title = "route", items = { { label = "render overlays", done = true } } } }
        end,
        missionProgressText = function()
            return "route online"
        end,
        partyState = function()
            return party
        end,
        snapshot = function(self)
            return { version = 4, seed = self.seed, mode = self.mode, status = self.status, tick = self.tick, player = self.player }
        end,
    }
end

local function hasArg(args, target)
    for _, value in ipairs(args or {}) do
        if value == target then
            return true
        end
    end
    return false
end

local function argValue(args, target, fallback)
    for index, value in ipairs(args or {}) do
        if value == target then
            return args[index + 1] or fallback
        end
    end
    return fallback
end

local function percentile(values, fraction)
    if #values == 0 then
        return 0
    end
    local sorted = {}
    for index, value in ipairs(values) do
        sorted[index] = value
    end
    table.sort(sorted)
    local rank = math.ceil(#sorted * fraction)
    rank = math.max(1, math.min(#sorted, rank))
    return sorted[rank]
end

local function capturePreviewIfNeeded(state)
    if not (state and state.previewCapture and not state.previewCaptured and love and love.graphics) then
        return false
    end
    state.previewCaptured = true
    local path = state.previewCapture
    love.graphics.captureScreenshot(function(imageData)
        local encoded = imageData:encode("png")
        local file = io.open(path, "wb")
        if file then
            file:write(encoded:getString())
            file:close()
            print("preview-capture=" .. path)
            love.event.quit(0)
        else
            print("preview-capture-error=" .. path)
            love.event.quit(1)
        end
    end)
    return true
end

local function runSpriteImport(args)
    local frameWidth, frameHeight = SpritePipeline.parseFrameSize(argValue(args, "--sprite-frame", "32x32"))
    if not frameWidth then
        print("sprite-import-error=bad-frame")
        love.event.quit(1)
        return
    end
    local source = argValue(args, "--sprite-source", "assets/sprites/oga_700_sprites.png")
    local atlas = argValue(args, "--sprite-atlas", "assets/sprites/oga_700_sprites.png")
    local manifest = argValue(args, "--sprite-manifest", "assets/sprites/oga_700_sprites.lua")
    local columns = tonumber(argValue(args, "--sprite-columns", nil))
    local plan, err = SpritePipeline.importWithLove(source, atlas, manifest, { frameWidth = frameWidth, frameHeight = frameHeight, columns = columns })
    if not plan then
        print("sprite-import-error=" .. tostring(err))
        love.event.quit(1)
        return
    end
    print("sprite-import-frames=" .. tostring(plan.frames))
    print("sprite-import-atlas=" .. tostring(plan.atlasPath))
    print("sprite-import-manifest=" .. tostring(plan.manifestPath))
    love.event.quit(0)
end

local function whiteTexture()
    local data = love.image.newImageData(1, 1)
    data:setPixel(0, 0, 1, 1, 1, 1)
    local image = love.graphics.newImage(data)
    image:setFilter("nearest", "nearest")
    return image
end

local function runModelImport(args)
    local source = argValue(args, "--model-source", "vendor/g3d/assets/cube.obj")
    local modelPath = argValue(args, "--model-out", "dist/model-import-smoke/cube.obj")
    local manifest = argValue(args, "--model-manifest", "dist/model-import-smoke/models.lua")
    local id = argValue(args, "--model-id", "smoke_cube")
    local result, err = ModelPipeline.import(source, modelPath, manifest, { id = id })
    if not result then
        print("model-import-error=" .. tostring(err))
        love.event.quit(1)
        return
    end
    local loaded = false
    local ok, g3d = pcall(require, "vendor.g3d.g3d")
    if ok then
        local model = ModelPipeline.newG3dModel(g3d, result, whiteTexture())
        loaded = model and model.mesh ~= nil
    end
    print("model-import-format=" .. tostring(result.format))
    print("model-import-vertices=" .. tostring(result.vertexCount))
    print("model-import-g3d=" .. tostring(loaded))
    love.event.quit(loaded and 0 or 1)
end

local function setupRenderBenchmark(state)
    state.player.x = 12
    state.player.y = 3
end

local function startNextCutscene(state)
    if state.cutscene then
        return
    end
    local queue = state.cutsceneQueue
    if queue and #queue > 0 then
        state.cutscene = table.remove(queue, 1)
    end
end

local function uiFeedbackKind(cue)
    if cue == "invalid" or cue == "ui_error" then
        return "error"
    end
    if cue == "save" or cue == "load" or cue == "craft" or cue == "place" or cue == "produce" or cue == "ui_confirm" then
        return "success"
    end
    return nil
end

local function playUi(state, cue)
    Audio.play(state.audio, cue)
    local kind = uiFeedbackKind(cue)
    if kind then
        Render.markUiFeedback(state, kind)
    end
end

local function advanceCombatJuice(state, dt)
    if not state then
        return
    end
    state.combatHitPause = math.max(0, (state.combatHitPause or 0) - (dt or 0))
    state.combatShake = math.max(0, (state.combatShake or 0) - (dt or 0))
    if state.combatShake <= 0 then
        state.combatShakeMagnitude = 0
    end
    for index = #(state.tacticalHitFlashes or {}), 1, -1 do
        local flash = state.tacticalHitFlashes[index]
        flash.t = (flash.t or 0) - (dt or 0)
        if flash.t <= 0 then
            table.remove(state.tacticalHitFlashes, index)
        end
    end
    for index = #(state.damageNumbers or {}), 1, -1 do
        local number = state.damageNumbers[index]
        number.t = (number.t or 0) - (dt or 0)
        if number.t <= 0 then
            table.remove(state.damageNumbers, index)
        end
    end
end

local function addTacticalHitFeedback(state, event)
    if not (state and event and event.x and event.y) then
        return
    end
    local blocked = event.blocked == true or (event.amount or 0) <= 0
    local missed = event.missed == true -- RNG miss: distinct lighter feedback
    local crit = event.crit == true -- RNG crit: amplified juice
    local kind = missed and "miss" or (blocked and "blocked" or (crit and "crit" or "hp"))
    local duration = event.killed and 1.05 or (crit and 0.95 or 0.7)
    state.damageNumbers = state.damageNumbers or {}
    state.damageNumbers[#state.damageNumbers + 1] = {
        tactical = true,
        kind = kind,
        amount = event.amount or 0,
        targetSide = event.targetSide,
        x = event.x,
        y = event.y,
        t = duration,
        duration = duration,
        killed = event.killed == true,
        blocked = blocked,
        missed = missed,
        crit = crit,
    }
    state.tacticalHitFlashes = state.tacticalHitFlashes or {}
    state.tacticalHitFlashes[#state.tacticalHitFlashes + 1] = {
        x = event.x,
        y = event.y,
        t = crit and 0.42 or 0.28, -- crit flash lingers longer
        duration = crit and 0.42 or 0.28,
        targetSide = event.targetSide,
        blocked = blocked,
        missed = missed,
        crit = crit,
    }
    -- hitstop: misses ~0, crits ~3x normal; blocked light; killed heavy
    local pause = missed and 0.012 or (blocked and 0.035 or (crit and 0.13 or 0.055))
    if event.killed then pause = math.max(pause, 0.16) end
    state.combatHitPause = math.max(state.combatHitPause or 0, pause)
    local shake = missed and 0.08 or (blocked and 0.16 or (crit and 0.42 or 0.24))
    if event.killed then shake = math.max(shake, 0.46) end
    state.combatShake = math.max(state.combatShake or 0, shake)
    -- shake magnitude scales: miss < blocked < hit < crit < killed
    local magnitude
    if missed then
        magnitude = 1
    elseif blocked then
        magnitude = 2
    else
        magnitude = event.targetSide == "player" and 7 or 5
        if crit then magnitude = magnitude + 4 end
    end
    if event.killed then magnitude = magnitude + 3 end
    state.combatShakeMagnitude = math.max(state.combatShakeMagnitude or 0, magnitude)
end

local function consumeTacticalHitEvents(state)
    local runtime = state and state.tactics
    if not (runtime and type(runtime.drainHitEvents) == "function") then
        return 0
    end
    local events = runtime:drainHitEvents()
    for _, event in ipairs(events or {}) do
        addTacticalHitFeedback(state, event)
    end
    return #(events or {})
end

local function resetVisualState(state, simulation)
    state.moveCooldown = 0
    state.lastCueStatus = simulation.status
    state.lastAudioEventId = simulation.eventSerial or 0
    state.lastVisualEventId = simulation.eventSerial or 0
    state.cutscene = nil
    state.cutsceneQueue = {}
    state.eventFlash = nil
    state.lastJuiceEventId = simulation.eventSerial or 0
    state.damageNumbers = {}
    state.tacticalHitFlashes = {}
    state.combatHitPause = 0
    state.combatShake = 0
    state.combatShakeMagnitude = 0
    state.pendingSkillKey = nil
    state.pendingTargetSide = nil
end

local function turnView(state, delta)
    local steps = Render.rotationSteps(state)
    local from = state.viewRotationVisual or state.viewRotation or 0
    local target = ((state.viewRotation or 0) + delta) % steps
    local diff = target - from
    while diff > steps / 2 do
        diff = diff - steps
    end
    while diff < -steps / 2 do
        diff = diff + steps
    end
    state.previousViewRotation = (state.viewRotation or 0) % steps
    state.viewRotation = target
    if Render.reducedMotion(state) then
        state.viewRotationVisual = target
        state.viewTurn = nil
    else
        state.viewTurn = { from = from, to = from + diff, t = 0, duration = 0.18 }
    end
    state.status = "view " .. tostring(math.floor(Render.rotationDegrees(state.viewRotation, steps) + 0.5))
end

local function startTutorial(state)
    if state.tutorialSeen then
        return
    end
    state.tutorial = { active = true, index = 1 }
    state.status = "tutorial"
end

local function describeSave(loaded)
    if not loaded then
        return "no save"
    end
    local week = loaded.estate and loaded.estate.week or 1
    return "save found: week " .. tostring(week) .. " / " .. tostring(loaded.mode)
end

local function persistSettings(state)
    if not (state and state.settings) then
        return false, "settings unavailable"
    end
    local ok, err = Settings.write(state.settings, "settings.thoth")
    if not ok then
        state.settingsStatus = "settings save failed: " .. tostring(err)
    end
    return ok, err
end

local function refreshContinueState(state)
    local loaded = Save.read("save.thoth")
    state.canContinue = loaded ~= nil
    state.saveStatus = describeSave(loaded)
end

local function refreshReplayState(state)
    local data = Replay.read("replay.thoth")
    state.canReplay = data ~= nil
    state.replayStatus = data and Replay.summary(data) or "no replay"
end

local function enterTacticalGame(state, squadLoadout)
    local loadout = squadLoadout or state.squadLoadout
    local tutorialMission = loadout and loadout.missionId == "tutorial"
    sim = newTacticalSim(20260618)
    state.tacticalMode = true
    state.uiState = "game"
    state.status = tutorialMission and "tutorial mission" or "tactical prototype"
    state.tutorial = nil
    state.tutorialSeen = not tutorialMission
    state.tutorialMission = tutorialMission
    state.tutorialMissionComplete = false
    state.tacticalZoom = 1.75
    state.tacticalHover = nil
    state.tacticalCameraUserMoved = false
    state.tacticalCameraCenterX = nil
    state.tacticalCameraCenterY = nil
    state.tacticalDrag = nil
    resetVisualState(state, sim)
    state.squadLoadout = loadout
    state.squadSelect = nil
    local partyMoveDelay = state.settings and state.settings.reducedMotion and 0 or 0.12
    state.tactics = TacticalRuntime.new(sim, { squadLoadout = state.squadLoadout, tutorial = tutorialMission, aiDebug = state.tacticalAiDebug == true, partyMovement = state.settings and state.settings.partyMovement == true, exploration = state.settings and state.settings.partyMovement == true, partyMoveStepDelay = partyMoveDelay, rngEnabled = true })
    state.tacticalOverlays = state.tactics.overlays
    TacticalRuntime.syncWorld(sim, state.tactics)
    if tutorialMission then
        startTutorial(state)
    end
end

local function clampValue(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

local function parseTileKey(key)
    local x, y = tostring(key):match("^(%-?%d+):(%-?%d+)$")
    return tonumber(x), tonumber(y)
end

local function setTacticalCaptureCursor(state, x, y, hover)
    local runtime = state and state.tactics
    local board = runtime and runtime.state and runtime.state.board
    if not (runtime and board and x and y) then
        return false
    end
    x = clampValue(math.floor(x), 1, board.width)
    y = clampValue(math.floor(y), 1, board.height)
    runtime:setCursor(x, y)
    state.tacticalHover = hover == false and nil or { x = x, y = y }
    state.tacticalOverlays = runtime.overlays
    TacticalRuntime.syncWorld(sim, runtime)
    return true
end

local function selectTacticalCaptureUnit(state, unitId)
    local runtime = state and state.tactics
    local unit = runtime and runtime.state and runtime.state:unit(unitId)
    if not unit then
        return nil
    end
    runtime.selectedUnitId = unit.id
    setTacticalCaptureCursor(state, unit.x, unit.y, false)
    return unit
end

local function configureFogPreviewCapture(state)
    local runtime = state and state.tactics
    if not runtime then
        return
    end
    local visibility = runtime and runtime:visibilityGrid()
    local keys = {}
    for key, fogged in pairs((visibility and visibility.fog) or {}) do
        if fogged then
            keys[#keys + 1] = key
        end
    end
    table.sort(keys)
    local x, y = parseTileKey(keys[#keys] or "")
    if x and y then
        setTacticalCaptureCursor(state, x, y)
    end
    runtime.message = "fog-of-war: dim archive tiles hide unit and intent footprints"
end

local function configureOverwatchPreviewCapture(state)
    local runtime = state and state.tactics
    local unit = selectTacticalCaptureUnit(state, "lamplighter") or selectTacticalCaptureUnit(state, "warden")
    if not (runtime and unit) then
        return
    end
    local board = runtime.state.board
    local direction = unit.x + 4 <= board.width and "east" or "west"
    local targetX = direction == "east" and unit.x + 4 or unit.x - 4
    setTacticalCaptureCursor(state, targetX, unit.y)
    runtime:setOverwatchPreview(direction, 4, 2)
    state.tacticalOverlays = runtime.overlays
    runtime.message = "overwatch cone: explicit AP spend, watched tiles, trigger limit"
end

local function configureIntentLegendPreviewCapture(state)
    local runtime = state and state.tactics
    local entries = Render.tacticalIntentLegendEntries(state)
    local entry = entries[1]
    for _, candidate in ipairs(entries) do
        if #(candidate.targetTiles or {}) > 0 then
            entry = candidate
            break
        end
    end
    if not (runtime and entry) then
        return
    end
    state.tacticalIntentHover = {
        unit = entry.unit,
        sourceTile = entry.sourceTile,
        targetTiles = entry.targetTiles,
    }
    local focus = (entry.targetTiles and entry.targetTiles[1]) or entry.sourceTile
    if focus then
        setTacticalCaptureCursor(state, focus.x, focus.y)
    end
    runtime.message = "intent legend: source and target tiles are highlighted before commit"
end

local function configureHubPreviewCapture(state)
    local runtime = state and state.tactics
    if not runtime then
        return
    end
    setTacticalCaptureCursor(state, 40, 27)
    Render.setTacticalCameraCenter(state, runtime.originX + 38, runtime.originY + 25)
    runtime.message = "semi-open hub: optional temple districts branch around the archive spine"
end

local function configureTacticalPreviewCapture(state, previewState)
    if not (state and state.tactics and previewState) then
        return
    end
    state.tacticalPreviewState = previewState
    state.tacticalIntentHover = nil
    state.tacticalHover = nil
    if previewState == "fog" then
        configureFogPreviewCapture(state)
    elseif previewState == "overwatch" then
        configureOverwatchPreviewCapture(state)
    elseif previewState == "intent" or previewState == "intent-legend" then
        configureIntentLegendPreviewCapture(state)
    elseif previewState == "hub" then
        configureHubPreviewCapture(state)
    else
        state.tacticalPreviewState = "default"
    end
end

local function enterSquadLoadout(state, missionId)
    missionId = missionId or "mission1"
    sim = newTacticalSim(20260618)
    state.tacticalMode = false
    state.uiState = "squad_loadout"
    state.status = missionId == "tutorial" and "tutorial loadout" or "squad loadout"
    state.tutorial = nil
    state.tutorialMission = false
    state.tutorialMissionComplete = false
    state.tacticalHover = nil
    state.tactics = nil
    state.tacticalOverlays = nil
    state.squadLoadout = nil
    state.squadSelect = SquadLoadout.defaultSelection({ missionId = missionId })
    resetVisualState(state, sim)
end

local function startSelectedSquad(state)
    local loadout, err = SquadLoadout.runtimeLoadout(state.squadSelect or SquadLoadout.defaultSelection())
    if not loadout then
        state.status = tostring(err)
        playUi(state, "invalid")
        return false
    end
    enterTacticalGame(state, loadout)
    return true
end

local function requestQuit(state)
    state.quitRequested = true
    state.quitConfirmed = true
    if love and love.event then
        love.event.quit(0)
    end
end

local function advanceViewTurn(state, dt)
    if not state then
        return
    end
    if state.settings and state.settings.reducedMotion then
        state.viewRotationVisual = state.viewRotation or 0
        state.viewTurn = nil
        return
    end
    local turn = state.viewTurn
    if not turn then
        state.viewRotationVisual = state.viewRotationVisual or state.viewRotation or 0
        return
    end
    turn.t = math.min(turn.duration or 0.18, (turn.t or 0) + (dt or 0))
    local ratio = (turn.duration or 0.18) > 0 and (turn.t / turn.duration) or 1
    ratio = ratio * ratio * (3 - 2 * ratio)
    state.viewRotationVisual = (turn.from or 0) + ((turn.to or turn.from or 0) - (turn.from or 0)) * ratio
    if turn.t >= (turn.duration or 0.18) then
        state.viewRotationVisual = state.viewRotation or 0
        state.viewTurn = nil
    end
end

local function selectedTitleItem(state)
    local items = Render.titleMenuItems(state)
    local index = state.titleMenuIndex or 1
    if not (items[index] and items[index].enabled) then
        for candidate, item in ipairs(items) do
            if item.enabled then
                state.titleMenuIndex = candidate
                return item
            end
        end
    end
    return items[index]
end

local function moveTitleSelection(state, delta)
    local items = Render.titleMenuItems(state)
    local index = state.titleMenuIndex or 1
    for _ = 1, #items do
        index = ((index - 1 + delta) % #items) + 1
        if items[index].enabled then
            state.titleMenuIndex = index
            return
        end
    end
end

local function activateTitleAction(state, action)
    if action == "new" then
        enterSquadLoadout(state, "tutorial")
        return
    end
    if action == "continue" then
        local loaded, err = Save.read("save.thoth")
        if loaded then
            enterTacticalGame(state)
            state.status = "loaded"
        else
            state.canContinue = false
            state.saveStatus = "load failed: " .. tostring(err)
            state.titleStatus = state.saveStatus
            playUi(state, "invalid")
        end
        return
    end
    if action == "replay" then
        local viewer, err = ReplayViewer.load("replay.thoth")
        if viewer then
            enterTacticalGame(state)
            state.status = viewer.status
            state.replayViewer = true
            state.replayData = viewer.data
            state.cutscene = nil
            state.cutsceneQueue = viewer.cutscenes
            startNextCutscene(state)
            playUi(state, "load")
        else
            state.canReplay = false
            state.replayStatus = "replay failed: " .. tostring(err)
            state.titleStatus = state.replayStatus
            playUi(state, "invalid")
        end
        return
    end
    if action == "settings" then
        state.settingsReturnState = "title"
        state.uiState = "settings"
        state.titleStatus = "settings"
        return
    end
    if action == "credits" then
        state.creditsReturnState = "title"
        state.uiState = "credits"
        state.titleStatus = "credits"
        return
    end
    if action == "quit" then
        requestQuit(state)
    end
end

local function keyTitle(state, key)
    if key == "up" or key == "w" then
        moveTitleSelection(state, -1)
        Audio.play(state.audio, "tick")
        return
    end
    if key == "down" or key == "s" then
        moveTitleSelection(state, 1)
        Audio.play(state.audio, "tick")
        return
    end
    if key == "return" or key == "kpenter" or key == "space" then
        local item = selectedTitleItem(state)
        if item and item.enabled then
            activateTitleAction(state, item.action)
            playUi(state, item.action == "quit" and "invalid" or "tick")
        end
        return
    end
    if key == "escape" then
        requestQuit(state)
    end
end

local function mouseTitle(state, x, y)
    for _, hitbox in ipairs((state.ui and state.ui.titleButtons) or {}) do
        if x >= hitbox.x and x <= hitbox.x + hitbox.w and y >= hitbox.y and y <= hitbox.y + hitbox.h then
            if hitbox.enabled then
                state.titleMenuIndex = hitbox.index
                activateTitleAction(state, hitbox.action)
                playUi(state, hitbox.action == "quit" and "invalid" or "tick")
            end
            return true
        end
    end
    return false
end

local function keySquadLoadout(state, key)
    state.squadSelect = state.squadSelect or SquadLoadout.defaultSelection()
    if key == "up" or key == "w" then
        SquadLoadout.moveFocus(state.squadSelect, -1)
        Audio.play(state.audio, "tick")
        return
    end
    if key == "down" or key == "s" then
        SquadLoadout.moveFocus(state.squadSelect, 1)
        Audio.play(state.audio, "tick")
        return
    end
    if key == "space" then
        SquadLoadout.toggle(state.squadSelect)
        Audio.play(state.audio, "tick")
        return
    end
    if key == "return" or key == "kpenter" then
        if startSelectedSquad(state) then
            Audio.play(state.audio, "tick")
        end
        return
    end
    if key == "escape" or key == "backspace" then
        state.uiState = "title"
        state.squadSelect = nil
        refreshContinueState(state)
        Audio.play(state.audio, "tick")
    end
end

local function mouseSquadLoadout(state, x, y)
    state.squadSelect = state.squadSelect or SquadLoadout.defaultSelection()
    for _, hitbox in ipairs((state.ui and state.ui.squadLoadoutButtons) or {}) do
        if x >= hitbox.x and x <= hitbox.x + hitbox.w and y >= hitbox.y and y <= hitbox.y + hitbox.h then
            if hitbox.index then
                state.squadSelect.focus = hitbox.index
            end
            if hitbox.action == "toggle" then
                SquadLoadout.toggle(state.squadSelect, hitbox.index)
                Audio.play(state.audio, "tick")
            elseif hitbox.action == "start" then
                if startSelectedSquad(state) then
                    Audio.play(state.audio, "tick")
                end
            elseif hitbox.action == "back" then
                state.uiState = "title"
                state.squadSelect = nil
                refreshContinueState(state)
                Audio.play(state.audio, "tick")
            end
            return true
        end
    end
    return false
end

local function keySettings(state, key)
    if state.captureBinding then
        if key == "escape" then
            state.captureBinding = nil
            state.settingsStatus = "binding canceled"
            playUi(state, "invalid")
            return
        end
        local ok, err = Settings.bindKey(state.settings, state.captureBinding, key)
        state.settingsStatus = ok and ("bound " .. state.captureBinding .. " to " .. key) or tostring(err)
        if ok then
            persistSettings(state)
        end
        state.captureBinding = nil
        playUi(state, ok and "save" or "invalid")
        return
    end
    local controls = Settings.controls()
    state.settingsFocus = math.max(1, math.min(state.settingsFocus or 1, #controls))
    if key == "up" or key == "w" then
        state.settingsFocus = ((state.settingsFocus - 2) % #controls) + 1
        Audio.play(state.audio, "tick")
        return
    end
    if key == "down" or key == "s" then
        state.settingsFocus = (state.settingsFocus % #controls) + 1
        Audio.play(state.audio, "tick")
        return
    end
    local control = controls[state.settingsFocus]
    if key == "left" or key == "a" then
        local changed = false
        if control.kind == "slider" then
            changed = Settings.adjust(state.settings, control.setting, -1)
        elseif control.kind == "cycle" then
            changed = Settings.cycle(state.settings, control.setting, -1)
        end
        Audio.applySettings(state.audio, state.settings)
        if changed then
            persistSettings(state)
        end
        Audio.play(state.audio, "tick")
        return
    end
    if key == "right" or key == "d" then
        local changed = false
        if control.kind == "slider" then
            changed = Settings.adjust(state.settings, control.setting, 1)
        elseif control.kind == "cycle" then
            changed = Settings.cycle(state.settings, control.setting, 1)
        end
        Audio.applySettings(state.audio, state.settings)
        if changed then
            persistSettings(state)
        end
        Audio.play(state.audio, "tick")
        return
    end
    if key == "space" or key == "return" or key == "kpenter" then
        if control.kind == "toggle" then
            if Settings.toggle(state.settings, control.setting) then
                persistSettings(state)
            end
            Audio.play(state.audio, "tick")
        elseif control.kind == "cycle" then
            if Settings.cycle(state.settings, control.setting, 1) then
                persistSettings(state)
            end
            Audio.play(state.audio, "tick")
        elseif control.kind == "slider" then
            if Settings.adjust(state.settings, control.setting, 1) then
                persistSettings(state)
            end
            Audio.applySettings(state.audio, state.settings)
            Audio.play(state.audio, "tick")
        elseif control.kind == "bind" then
            state.captureBinding = control.binding
            state.settingsStatus = "press key for " .. control.binding
            Audio.play(state.audio, "tick")
        elseif control.kind == "back" then
            state.uiState = state.settingsReturnState or "title"
            Audio.play(state.audio, "tick")
        end
        return
    end
    if key == "escape" or key == "backspace" then
        state.uiState = state.settingsReturnState or "title"
        Audio.play(state.audio, "tick")
    end
end

local function activateSettingsHitbox(state, hitbox)
    if hitbox.index then
        state.settingsFocus = hitbox.index
    end
    if hitbox.action == "adjust" then
        if Settings.adjust(state.settings, hitbox.setting, hitbox.delta or 1) then
            persistSettings(state)
        end
        Audio.applySettings(state.audio, state.settings)
        Audio.play(state.audio, "tick")
    elseif hitbox.action == "toggle" then
        if Settings.toggle(state.settings, hitbox.setting) then
            persistSettings(state)
        end
        Audio.play(state.audio, "tick")
    elseif hitbox.action == "cycle" then
        if Settings.cycle(state.settings, hitbox.setting, hitbox.delta or 1) then
            persistSettings(state)
        end
        Audio.play(state.audio, "tick")
    elseif hitbox.action == "bind" then
        state.captureBinding = hitbox.binding
        state.settingsStatus = "press key for " .. tostring(hitbox.binding)
        Audio.play(state.audio, "tick")
    elseif hitbox.action == "back" then
        state.uiState = state.settingsReturnState or "title"
        Audio.play(state.audio, "tick")
    end
end

local function mouseSettings(state, x, y)
    for _, hitbox in ipairs((state.ui and state.ui.settingsButtons) or {}) do
        if x >= hitbox.x and x <= hitbox.x + hitbox.w and y >= hitbox.y and y <= hitbox.y + hitbox.h then
            activateSettingsHitbox(state, hitbox)
            return true
        end
    end
    return false
end

local function openPause(state)
    state.paused = true
    state.pauseMenuIndex = state.pauseMenuIndex or 1
    state.pauseStatus = "paused"
end

local function midExpedition()
    return false
end

local function openConfirm(state, title, body, confirmAction)
    state.confirmDialog = { title = title, body = body, confirmAction = confirmAction }
    state.confirmMenuIndex = 1
end

local function closeConfirm(state)
    state.confirmDialog = nil
    state.confirmMenuIndex = nil
end

local function quitToTitle(state)
    sim = newTacticalSim(20260618)
    state.tactics = nil
    state.tacticalOverlays = nil
    state.tacticalMode = false
    state.squadSelect = nil
    state.squadLoadout = nil
    state.paused = false
    state.uiState = "title"
    state.pauseStatus = nil
    closeConfirm(state)
    resetVisualState(state, sim)
    refreshContinueState(state)
end

local function activatePauseAction(state, action)
    if action == "resume" then
        state.paused = false
        state.pauseStatus = nil
        return
    end
    if action == "save" then
        local ok, err = Save.write(sim, "save.thoth")
        state.pauseStatus = ok and "saved" or ("save failed: " .. tostring(err))
        refreshContinueState(state)
        playUi(state, ok and "save" or "invalid")
        return
    end
    if action == "settings" then
        state.settingsReturnState = "game"
        state.uiState = "settings"
        Audio.play(state.audio, "tick")
        return
    end
    if action == "quitTitle" then
        if midExpedition() then
            openConfirm(state, "Quit to Title", "Abandon this expedition and return to title?", "quitTitle")
            playUi(state, "invalid")
            return
        end
        quitToTitle(state)
    end
end

local function keyPause(state, key)
    local items = Render.pauseMenuItems()
    if key == "up" or key == "w" then
        state.pauseMenuIndex = ((state.pauseMenuIndex or 1) - 2) % #items + 1
        Audio.play(state.audio, "tick")
        return
    end
    if key == "down" or key == "s" then
        state.pauseMenuIndex = ((state.pauseMenuIndex or 1) % #items) + 1
        Audio.play(state.audio, "tick")
        return
    end
    if key == "return" or key == "kpenter" or key == "space" then
        local item = items[state.pauseMenuIndex or 1]
        activatePauseAction(state, item.action)
        Audio.play(state.audio, "tick")
        return
    end
    if key == "escape" or Settings.isAction(state.settings, key, "pause", "escape") then
        state.paused = false
        state.pauseStatus = nil
        Audio.play(state.audio, "tick")
    end
end

local function mousePause(state, x, y)
    for _, hitbox in ipairs((state.ui and state.ui.pauseButtons) or {}) do
        if x >= hitbox.x and x <= hitbox.x + hitbox.w and y >= hitbox.y and y <= hitbox.y + hitbox.h then
            state.pauseMenuIndex = hitbox.index
            activatePauseAction(state, hitbox.action)
            Audio.play(state.audio, "tick")
            return true
        end
    end
    return false
end

local function activateConfirmAction(state, action)
    if action == "cancel" then
        closeConfirm(state)
        Audio.play(state.audio, "tick")
        return
    end
    local confirmAction = state.confirmDialog and state.confirmDialog.confirmAction
    closeConfirm(state)
    if confirmAction == "quitTitle" then
        quitToTitle(state)
        Audio.play(state.audio, "tick")
        return
    end
    if confirmAction == "quitApp" then
        state.quitConfirmed = true
        if love and love.event then
            love.event.quit(0)
        end
    end
end

local function keyConfirm(state, key)
    local items = Render.confirmMenuItems()
    if key == "left" or key == "a" or key == "up" or key == "w" then
        state.confirmMenuIndex = ((state.confirmMenuIndex or 1) - 2) % #items + 1
        Audio.play(state.audio, "tick")
        return
    end
    if key == "right" or key == "d" or key == "down" or key == "s" then
        state.confirmMenuIndex = ((state.confirmMenuIndex or 1) % #items) + 1
        Audio.play(state.audio, "tick")
        return
    end
    if key == "return" or key == "kpenter" or key == "space" then
        local item = items[state.confirmMenuIndex or 1]
        activateConfirmAction(state, item.action)
        return
    end
    if key == "escape" or key == "backspace" then
        activateConfirmAction(state, "cancel")
    end
end

local function mouseConfirm(state, x, y)
    for _, hitbox in ipairs((state.ui and state.ui.confirmButtons) or {}) do
        if x >= hitbox.x and x <= hitbox.x + hitbox.w and y >= hitbox.y and y <= hitbox.y + hitbox.h then
            state.confirmMenuIndex = hitbox.index
            activateConfirmAction(state, hitbox.action)
            return true
        end
    end
    return false
end

local function campaignEnded(simulation)
    local campaign = simulation and simulation.estate and simulation.estate.campaign
    return campaign and (campaign.lost == true or campaign.victory == true)
end

local function syncGameOverState(state)
    if state.uiState == "game" and campaignEnded(sim) then
        state.paused = false
        state.uiState = "gameover"
        state.gameOverMenuIndex = state.gameOverMenuIndex or 1
        state.gameOverStatus = "campaign ended"
        refreshContinueState(state)
        return true
    end
    return false
end

local function selectedGameOverItem(state)
    local items = Render.gameOverMenuItems(state)
    local index = state.gameOverMenuIndex or 1
    if not (items[index] and items[index].enabled) then
        for candidate, item in ipairs(items) do
            if item.enabled then
                state.gameOverMenuIndex = candidate
                return item
            end
        end
    end
    return items[index]
end

local function moveGameOverSelection(state, delta)
    local items = Render.gameOverMenuItems(state)
    local index = state.gameOverMenuIndex or 1
    for _ = 1, #items do
        index = ((index - 1 + delta) % #items) + 1
        if items[index].enabled then
            state.gameOverMenuIndex = index
            return
        end
    end
end

local function activateGameOverAction(state, action)
    if action == "restart" then
        enterSquadLoadout(state, "tutorial")
        Audio.play(state.audio, "tick")
        return
    end
    if action == "title" then
        sim = newTacticalSim(20260618)
        state.tactics = nil
        state.tacticalOverlays = nil
        state.tacticalMode = false
        state.squadSelect = nil
        state.squadLoadout = nil
        state.paused = false
        state.uiState = "title"
        state.gameOverStatus = nil
        resetVisualState(state, sim)
        refreshContinueState(state)
        Audio.play(state.audio, "tick")
        return
    end
    if action == "credits" then
        state.creditsReturnState = "gameover"
        state.uiState = "credits"
        Audio.play(state.audio, "tick")
    end
end

local function keyGameOver(state, key)
    if key == "left" or key == "a" or key == "up" or key == "w" then
        moveGameOverSelection(state, -1)
        Audio.play(state.audio, "tick")
        return
    end
    if key == "right" or key == "d" or key == "down" or key == "s" then
        moveGameOverSelection(state, 1)
        Audio.play(state.audio, "tick")
        return
    end
    if key == "return" or key == "kpenter" or key == "space" then
        local item = selectedGameOverItem(state)
        if item and item.enabled then
            activateGameOverAction(state, item.action)
        end
        return
    end
    if key == "escape" then
        activateGameOverAction(state, "title")
    end
end

local function mouseGameOver(state, x, y)
    for _, hitbox in ipairs((state.ui and state.ui.gameOverButtons) or {}) do
        if x >= hitbox.x and x <= hitbox.x + hitbox.w and y >= hitbox.y and y <= hitbox.y + hitbox.h then
            state.gameOverMenuIndex = hitbox.index
            if hitbox.enabled then
                activateGameOverAction(state, hitbox.action)
            end
            return true
        end
    end
    return false
end

local function keyCredits(state, key)
    if key == "up" or key == "w" then
        state.creditsScroll = math.max(0, (state.creditsScroll or 0) - 1)
        Audio.play(state.audio, "tick")
        return
    end
    if key == "down" or key == "s" then
        state.creditsScroll = (state.creditsScroll or 0) + 1
        Audio.play(state.audio, "tick")
        return
    end
    if key == "escape" or key == "backspace" or key == "return" or key == "kpenter" or key == "space" then
        state.uiState = state.creditsReturnState or "title"
        Audio.play(state.audio, "tick")
    end
end

local function mouseCredits(state, x, y)
    for _, hitbox in ipairs((state.ui and state.ui.creditsButtons) or {}) do
        if x >= hitbox.x and x <= hitbox.x + hitbox.w and y >= hitbox.y and y <= hitbox.y + hitbox.h then
            state.uiState = state.creditsReturnState or "title"
            Audio.play(state.audio, "tick")
            return true
        end
    end
    return false
end

local function openJournal(state, returnState)
    state.journalReturnState = returnState or "game"
    state.uiState = "journal"
    state.journalTab = state.journalTab or "documents"
    state.journalIndex = state.journalIndex or 1
    state.status = "journal"
end

local function keyJournal(state, key)
    local summary = Render.journalSummary(sim)
    local items = state.journalTab == "epitaphs" and summary.epitaphs or summary.documents
    if key == "left" or key == "a" or key == "right" or key == "d" then
        state.journalTab = state.journalTab == "documents" and "epitaphs" or "documents"
        state.journalIndex = 1
        Audio.play(state.audio, "tick")
        return
    end
    if key == "up" or key == "w" then
        state.journalIndex = math.max(1, (state.journalIndex or 1) - 1)
        Audio.play(state.audio, "tick")
        return
    end
    if key == "down" or key == "s" then
        state.journalIndex = math.min(math.max(1, #items), (state.journalIndex or 1) + 1)
        Audio.play(state.audio, "tick")
        return
    end
    if key == "escape" or key == "backspace" or key == "return" or key == "kpenter" then
        state.uiState = state.journalReturnState or "game"
        Audio.play(state.audio, "tick")
    end
end

local function mouseJournal(state, x, y)
    for _, hitbox in ipairs((state.ui and state.ui.journalButtons) or {}) do
        if x >= hitbox.x and x <= hitbox.x + hitbox.w and y >= hitbox.y and y <= hitbox.y + hitbox.h then
            if hitbox.action == "tab" then
                state.journalTab = hitbox.tab
                state.journalIndex = 1
            elseif hitbox.action == "select" then
                state.journalIndex = hitbox.selection
            elseif hitbox.action == "back" then
                state.uiState = state.journalReturnState or "game"
            end
            Audio.play(state.audio, "tick")
            return true
        end
    end
    return false
end

local function closeTutorial(state)
    state.tutorialSeen = true
    state.tutorial = nil
    state.status = "ready"
end

local function keyTutorial(state, key)
    local steps = Render.tutorialSteps()
    if key == "escape" or key == "backspace" then
        closeTutorial(state)
        Audio.play(state.audio, "tick")
        return
    end
    if key == "left" or key == "a" or key == "up" or key == "w" then
        state.tutorial.index = math.max(1, (state.tutorial.index or 1) - 1)
        Audio.play(state.audio, "tick")
        return
    end
    if key == "right" or key == "d" or key == "down" or key == "s" or key == "return" or key == "kpenter" or key == "space" then
        if (state.tutorial.index or 1) >= #steps then
            closeTutorial(state)
        else
            state.tutorial.index = (state.tutorial.index or 1) + 1
        end
        Audio.play(state.audio, "tick")
    end
end

local function mouseTutorial(state, x, y)
    for _, hitbox in ipairs((state.ui and state.ui.tutorialButtons) or {}) do
        if x >= hitbox.x and x <= hitbox.x + hitbox.w and y >= hitbox.y and y <= hitbox.y + hitbox.h then
            if hitbox.action == "skip" then
                closeTutorial(state)
            elseif hitbox.action == "prev" and hitbox.enabled then
                state.tutorial.index = math.max(1, (state.tutorial.index or 1) - 1)
            elseif hitbox.action == "next" then
                keyTutorial(state, "return")
                return true
            end
            Audio.play(state.audio, "tick")
            return true
        end
    end
    return false
end

local function printRenderSmoke(state)
    if not state.renderSmoke or state.renderSmokePrinted then
        return
    end
    state.renderSmokePrinted = true
    print("render-smoke-renderer=" .. tostring(state.renderer))
    print("render-smoke-mode=" .. tostring(state.worldView and state.worldView.mode))
    print("render-smoke-rotation=" .. tostring(state.worldView and state.worldView.rotation))
    local hud = Render.expeditionHudSummary(sim)
    print("render-smoke-hud-torch=" .. tostring(hud.torch))
    print("render-smoke-hud-room=" .. tostring(hud.currentRoom))
    print("render-smoke-hud-party=" .. tostring(hud.partyCount))
    local overlays = (state.worldView and state.worldView.tacticalOverlays) or {}
    print("render-smoke-overlay-total=" .. tostring(overlays.total or 0))
    print("render-smoke-overlay-movement=" .. tostring(overlays.movement or 0))
    print("render-smoke-overlay-los=" .. tostring(overlays.los or 0))
    print("render-smoke-overlay-cover=" .. tostring(overlays.cover or 0))
    print("render-smoke-overlay-flank=" .. tostring(overlays.flank or 0))
    print("render-smoke-overlay-intent=" .. tostring(overlays.intent or 0))
    print("render-smoke-overlay-hazard=" .. tostring(overlays.hazard or 0))
    if love and love.event then
        love.event.quit(0)
    end
end

local function printTacticalSmoke(state)
    if not state.tacticalSmoke or state.tacticalSmokePrinted then
        return
    end
    state.tacticalSmokePrinted = true
    local summary = state.tactics and state.tactics:summary() or {}
    local overlays = (state.worldView and state.worldView.tacticalOverlays) or {}
    print("tactical-smoke-mode=" .. tostring(summary.mode))
    print("tactical-smoke-route=" .. tostring(summary.route and summary.route.id))
    print("tactical-smoke-variant=" .. tostring(summary.route and summary.route.variantId))
    print("tactical-smoke-route-step=" .. tostring(summary.routeIndex) .. "/" .. tostring(summary.routeCount))
    print("tactical-smoke-legacy-expedition=" .. tostring(sim and sim.mode == "expedition"))
    print("tactical-smoke-phase=" .. tostring(summary.phase))
    print("tactical-smoke-selected=" .. tostring(summary.selected))
    print("tactical-smoke-player-units=" .. tostring(#(summary.players or {})))
    print("tactical-smoke-enemy-units=" .. tostring(#(summary.enemies or {})))
    local board = state.tactics and state.tactics.state and state.tactics.state.board
    print("tactical-smoke-board-size=" .. tostring(board and board.width or "-") .. "x" .. tostring(board and board.height or "-"))
    local heightTiles, destructibleTiles, highCoverTiles = 0, 0, 0
    for _, tile in pairs((board and board.tiles) or {}) do
        if (tile.height or 0) > 0 then
            heightTiles = heightTiles + 1
        end
        if tile.destructibleHp ~= nil then
            destructibleTiles = destructibleTiles + 1
        end
        if (tile.height or 0) >= 2 then
            for _, cover in pairs(tile.coverEdges or {}) do
                if cover ~= "none" then
                    highCoverTiles = highCoverTiles + 1
                    break
                end
            end
        end
    end
    local descentRoutes = 0
    for _, route in ipairs((board and board.verticalRoutes) or {}) do
        if route.kind == "descend" then
            descentRoutes = descentRoutes + 1
        end
    end
    print("tactical-smoke-height-tiles=" .. tostring(heightTiles))
    print("tactical-smoke-destructibles=" .. tostring(destructibleTiles))
    print("tactical-smoke-vertical-routes=" .. tostring(#((board and board.verticalRoutes) or {})))
    print("tactical-smoke-descents=" .. tostring(descentRoutes))
    print("tactical-smoke-sightlines=" .. tostring(#((board and board.sightlines) or {})))
    print("tactical-smoke-high-cover=" .. tostring(highCoverTiles))
    print("tactical-smoke-terrain-types=" .. tostring(#((board and board.terrainTypes) or {})))
    print("tactical-smoke-generation-techniques=" .. tostring(#((board and board.generationTechniques) or {})))
    print("tactical-smoke-districts=" .. tostring(#((board and board.districts) or {})))
    print("tactical-smoke-soft-gates=" .. tostring(#((board and board.softGates) or {})))
    print("tactical-smoke-landmarks=" .. tostring(#((board and board.landmarks) or {})))
    print("tactical-smoke-optional-open-ratio=" .. string.format("%.2f", (board and board.metrics and board.metrics.optionalOpenRatio) or 0))
    print("tactical-smoke-grid=" .. tostring(state.worldView and state.worldView.tacticalGrid or 0))
    print("tactical-smoke-enemy-cards=" .. tostring(#Render.tacticalEnemyHudRows(state)))
    print("tactical-smoke-intent-badges=" .. tostring(state.worldView and state.worldView.tacticalIntentBadges or 0))
    print("tactical-smoke-intents=" .. tostring(overlays.intent or 0))
    print("tactical-smoke-movement=" .. tostring(overlays.movement or 0))
    print("tactical-smoke-forecast=" .. tostring(state.worldView and state.worldView.tacticalForecast or 0))
    print("tactical-smoke-zoom=" .. string.format("%.2f", Render.tacticalZoom(state)))
    print("tactical-smoke-preview-state=" .. tostring(state.tacticalPreviewState or "default"))
    print("tactical-smoke-objective=" .. tostring(summary.objective and summary.objective.integrity) .. "/" .. tostring(summary.objective and summary.objective.maxIntegrity))
    local hudAudit = Render.tacticalHudLayoutAudit(1920, 1080, 6)
    print("tactical-smoke-hud-layout=" .. tostring(hudAudit.ok))
    print("tactical-smoke-hud-portraits=" .. tostring(hudAudit.visiblePortraits))
    print("tactical-smoke-hud-ap-pools=" .. tostring(hudAudit.apPools))
    print("tactical-smoke-hud-overlaps=" .. tostring(#hudAudit.overlaps))
    local inspector = Render.tacticalTileInspectorSummary(state)
    print("tactical-smoke-inspector=" .. tostring(inspector ~= nil))
    print("tactical-smoke-inspector-lines=" .. tostring(#Render.tacticalTileInspectorLines(inspector)))
    local legend = Render.tacticalIntentLegendEntries(state)
    local legendTargets = 0
    for _, entry in ipairs(legend) do
        legendTargets = legendTargets + #(entry.targetTiles or {})
    end
    print("tactical-smoke-intent-legend=" .. tostring(#legend))
    print("tactical-smoke-intent-targets=" .. tostring(legendTargets))
    local compass = Render.rotationCompass(state.viewRotation or 0)
    print("tactical-smoke-compass=" .. tostring(compass.degrees))
    print("tactical-smoke-ghost-arrows=" .. tostring(#Render.tacticalGhostArrowEntries(state)))
    print("tactical-smoke-ai-debug=" .. tostring(state.tacticalAiDebug == true))
    print("tactical-smoke-ai-debug-overlays=" .. tostring(overlays.aiDebug or 0))
    print("tactical-smoke-ai-doctrine=" .. tostring(summary.aiDoctrine and summary.aiDoctrine.id or "-"))
    io.stdout:flush()
    if not state.previewCapture then
        os.exit(0)
    end
end

local function printTitleSmoke(state)
    if not state.titleSmoke or state.titleSmokePrinted then
        return
    end
    state.titleSmokePrinted = true
    local actions = {}
    for _, hitbox in ipairs((state.ui and state.ui.titleButtons) or {}) do
        actions[#actions + 1] = hitbox.action
    end
    print("title-smoke-state=" .. tostring(state.uiState))
    print("title-smoke-buttons=" .. table.concat(actions, ","))
    print("title-smoke-continue=" .. tostring(state.canContinue == true))
    print("title-smoke-replay=" .. tostring(state.canReplay == true))
end

local function printSettingsSmoke(state)
    if not state.settingsSmoke or state.settingsSmokePrinted then
        return
    end
    state.settingsSmokePrinted = true
    local actions = {}
    local settings = {}
    for _, hitbox in ipairs((state.ui and state.ui.settingsButtons) or {}) do
        actions[hitbox.action] = true
        if hitbox.setting then
            settings[hitbox.setting] = true
        end
    end
    print("settings-smoke-state=" .. tostring(state.uiState))
    print("settings-smoke-controls=" .. tostring(#Settings.controls()))
    print("settings-smoke-adjust=" .. tostring(actions.adjust == true))
    print("settings-smoke-bind=" .. tostring(actions.bind == true))
    print("settings-smoke-toggle=" .. tostring(actions.toggle == true))
    print("settings-smoke-tactical-accessibility=" .. tostring(settings.highContrastTiles and settings.intentIconScale and settings.coverEdgePalette and settings.intentText))
end

local function printEstateSmoke(state)
    if not state.estateSmoke or state.estateSmokePrinted then
        return
    end
    state.estateSmokePrinted = true
    local buildingButtons = 0
    local gearButtons = 0
    local trinketButtons = 0
    local trinketTooltips = 0
    for _, hitbox in ipairs((state.ui and state.ui.estateActionButtons) or {}) do
        if hitbox.action == "upgradeBuilding" then
            buildingButtons = buildingButtons + 1
        elseif hitbox.action == "upgradeGear" then
            gearButtons = gearButtons + 1
        elseif hitbox.action == "equipTrinket" or hitbox.action == "unequipTrinket" then
            trinketButtons = trinketButtons + 1
        end
        if hitbox.tooltipKey then
            trinketTooltips = trinketTooltips + 1
        end
    end
    print("estate-smoke-mode=" .. tostring(sim and sim.mode))
    print("estate-smoke-buildings=" .. tostring(buildingButtons))
    print("estate-smoke-gear-actions=" .. tostring(gearButtons))
    print("estate-smoke-trinket-actions=" .. tostring(trinketButtons))
    print("estate-smoke-trinket-tooltips=" .. tostring(trinketTooltips))
    print("estate-smoke-roster=" .. tostring(#((state.ui and state.ui.rosterButtons) or {})))
    print("estate-smoke-party-slots=" .. tostring(#((state.ui and state.ui.partyRankSlots) or {})))
    print("estate-smoke-missions=" .. tostring(#((state.ui and state.ui.missionButtons) or {})))
end

local function printCombatSmoke(state)
    if not state.combatSmoke or state.combatSmokePrinted then
        return
    end
    state.combatSmokePrinted = true
    local allyTargets = 0
    for _, hitbox in ipairs((state.ui and state.ui.heroButtons) or {}) do
        if hitbox.side == "ally" then
            allyTargets = allyTargets + 1
        end
    end
    local summary = Render.combatHudSummary(sim, state)
    print("combat-smoke-mode=" .. tostring(sim and sim.mode))
    print("combat-smoke-turns=" .. tostring(#summary.turns))
    print("combat-smoke-skills=" .. tostring(#((state.ui and state.ui.skillButtons) or {})))
    print("combat-smoke-ally-targets=" .. tostring(allyTargets))
    print("combat-smoke-enemy-targets=" .. tostring(#((state.ui and state.ui.enemyButtons) or {})))
end

local function printCurioSmoke(state)
    if not state.curioSmoke or state.curioSmokePrinted then
        return
    end
    state.curioSmokePrinted = true
    local enabled = 0
    for _, hitbox in ipairs((state.ui and state.ui.curioButtons) or {}) do
        if hitbox.enabled then
            enabled = enabled + 1
        end
    end
    print("curio-smoke-modal=" .. tostring(state.curioModal and state.curioModal.key))
    print("curio-smoke-buttons=" .. tostring(#((state.ui and state.ui.curioButtons) or {})))
    print("curio-smoke-enabled=" .. tostring(enabled))
end

local function printCampSmoke(state)
    if not state.campSmoke or state.campSmokePrinted then
        return
    end
    state.campSmokePrinted = true
    local summary = Render.campHudSummary(sim, state)
    print("camp-smoke-active=" .. tostring(summary.active))
    print("camp-smoke-skills=" .. tostring(#((state.ui and state.ui.campSkillButtons) or {})))
    print("camp-smoke-heroes=" .. tostring(#((state.ui and state.ui.campHeroButtons) or {})))
    print("camp-smoke-respite=" .. tostring(summary.respite))
end

local function printPauseSmoke(state)
    if not state.pauseSmoke or state.pauseSmokePrinted then
        return
    end
    state.pauseSmokePrinted = true
    print("pause-smoke-paused=" .. tostring(state.paused))
    print("pause-smoke-buttons=" .. tostring(#((state.ui and state.ui.pauseButtons) or {})))
end

local function printConfirmSmoke(state)
    if not state.confirmSmoke or state.confirmSmokePrinted then
        return
    end
    state.confirmSmokePrinted = true
    local actions = {}
    for _, hitbox in ipairs((state.ui and state.ui.confirmButtons) or {}) do
        actions[#actions + 1] = hitbox.action
    end
    print("confirm-smoke-open=" .. tostring(state.confirmDialog ~= nil))
    print("confirm-smoke-paused=" .. tostring(state.paused))
    print("confirm-smoke-buttons=" .. table.concat(actions, ","))
end

local function printGameOverSmoke(state)
    if not state.gameOverSmoke or state.gameOverSmokePrinted then
        return
    end
    state.gameOverSmokePrinted = true
    local actions = {}
    for _, hitbox in ipairs((state.ui and state.ui.gameOverButtons) or {}) do
        actions[#actions + 1] = hitbox.action
    end
    local summary = Render.gameOverSummary(sim)
    print("gameover-smoke-state=" .. tostring(state.uiState))
    print("gameover-smoke-reason=" .. tostring(summary.reason))
    print("gameover-smoke-route=" .. tostring(summary.route))
    print("gameover-smoke-dread-tier=" .. tostring(summary.dreadTier))
    print("gameover-smoke-factions=" .. tostring(#summary.factions))
    print("gameover-smoke-buttons=" .. table.concat(actions, ","))
end

local function printCreditsSmoke(state)
    if not state.creditsSmoke or state.creditsSmokePrinted then
        return
    end
    state.creditsSmokePrinted = true
    local data = Render.creditsData()
    print("credits-smoke-state=" .. tostring(state.uiState))
    print("credits-smoke-assets=" .. tostring(#data.assets))
    print("credits-smoke-libraries=" .. tostring(#data.libraries))
    print("credits-smoke-back=" .. tostring(#((state.ui and state.ui.creditsButtons) or {})))
end

local function printKeyboardSmoke(state)
    if not state.keyboardSmoke or state.keyboardSmokePrinted then
        return
    end
    state.keyboardSmokePrinted = true
    local count = #Input.focusables(state)
    local entry = Input.cycleFocus(state, 1)
    local tabbed = entry ~= nil and state.keyboardFocus ~= nil
    local backed = Input.back(sim, state)
    print("keyboard-smoke-focusables=" .. tostring(count > 0))
    print("keyboard-smoke-tab=" .. tostring(tabbed))
    print("keyboard-smoke-back=" .. tostring(backed))
end

local function printControllerSmoke(state)
    if not state.controllerSmoke or state.controllerSmokePrinted then
        return
    end
    state.controllerSmokePrinted = true
    local axisState = {}
    local tacticalSim = newTacticalSim(9005)
    local runtime = TacticalRuntime.new(tacticalSim)
    runtime:handleKey(Input.gamepadButtonKey("dpright"))
    runtime:handleKey(Input.gamepadAxisKey("lefty", -0.8, axisState))
    runtime:handleKey(Input.gamepadButtonKey("a"))
    print("controller-smoke-a=" .. tostring(Input.gamepadButtonKey("a")))
    print("controller-smoke-b=" .. tostring(Input.gamepadButtonKey("b")))
    print("controller-smoke-axis=" .. tostring(Input.gamepadAxisKey("leftx", 0.8, axisState)))
    print("controller-smoke-tactical-cursor=" .. tostring(runtime.cursor.x) .. "," .. tostring(runtime.cursor.y))
    print("controller-smoke-tactical-activate=" .. tostring(runtime.state:unit("warden").x) .. "," .. tostring(runtime.state:unit("warden").y))
end

local function printJournalSmoke(state)
    if not state.journalSmoke or state.journalSmokePrinted then
        return
    end
    state.journalSmokePrinted = true
    local summary = Render.journalSummary(sim)
    print("journal-smoke-state=" .. tostring(state.uiState))
    print("journal-smoke-documents=" .. tostring(#summary.documents))
    print("journal-smoke-epitaphs=" .. tostring(#summary.epitaphs))
    print("journal-smoke-buttons=" .. tostring(#((state.ui and state.ui.journalButtons) or {})))
end

local function printTutorialSmoke(state)
    if not state.tutorialSmoke or state.tutorialSmokePrinted then
        return
    end
    state.tutorialSmokePrinted = true
    local steps = Render.tutorialSteps()
    local first = steps[1] or {}
    print("tutorial-smoke-mode=" .. tostring(sim and sim.mode))
    print("tutorial-smoke-active=" .. tostring(state.tutorial and state.tutorial.active == true))
    print("tutorial-smoke-steps=" .. tostring(#steps))
    print("tutorial-smoke-first=" .. tostring(first.key))
    local board = first.board or {}
    print("tutorial-smoke-board=" .. tostring(board.id))
    print("tutorial-smoke-board-size=" .. tostring(board.board and board.board.width) .. "x" .. tostring(board.board and board.board.height))
    print("tutorial-smoke-script=" .. tostring(#(board.actions or {})))
    print("tutorial-smoke-buttons=" .. tostring(#((state.ui and state.ui.tutorialButtons) or {})))
end

local function printToastSmoke(state)
    if not state.toastSmoke or state.toastSmokePrinted then
        return
    end
    state.toastSmokePrinted = true
    print("toast-smoke-unlocked=" .. tostring(state.achievements and state.achievements.first_document == true))
    print("toast-smoke-count=" .. tostring(#(state.toasts or {})))
end

local function printPolishSmoke(state)
    if not state.polishSmoke or state.polishSmokePrinted then
        return
    end
    state.polishSmokePrinted = true
    local hitbox = state.ui and state.ui.titleButtons and state.ui.titleButtons[1]
    Render.markUiPulse(state, hitbox, "press")
    state.uiHot = hitbox and { group = "titleButtons", index = 1 } or nil
    print("polish-smoke-hitbox=" .. tostring(hitbox ~= nil))
    print("polish-smoke-pulse=" .. tostring(state.uiPulse ~= nil))
    print("polish-smoke-draw=" .. tostring(Render.drawUiMicroAnimations(state) > 0))
end

function love.load(args)
    local loadStartedAt = love.timer.getTime()
    love.graphics.setDefaultFilter("nearest", "nearest")
    if love.graphics.setLineStyle then love.graphics.setLineStyle("rough") end -- crisp pixel edges, no AA, matches bitmap-font aesthetic
    if hasArg(args, "--sprite-import") then
        app = { importMode = true }
        runSpriteImport(args)
        return
    end
    if hasArg(args, "--model-import") then
        app = { importMode = true }
        runModelImport(args)
        return
    end
    sim = newTacticalSim(20260618)
    local renderBenchmark = hasArg(args, "--render-benchmark")
    local loadBenchmark = hasArg(args, "--load-benchmark")
    local titleSmoke = hasArg(args, "--title-smoke")
    local settingsSmoke = hasArg(args, "--settings-smoke")
    local estateSmoke = hasArg(args, "--estate-smoke")
    local combatSmoke = hasArg(args, "--combat-smoke")
    local curioSmoke = hasArg(args, "--curio-smoke")
    local campSmoke = hasArg(args, "--camp-smoke")
    local pauseSmoke = hasArg(args, "--pause-smoke")
    local gameOverSmoke = hasArg(args, "--gameover-smoke")
    local creditsSmoke = hasArg(args, "--credits-smoke")
    local confirmSmoke = hasArg(args, "--confirm-smoke")
    local keyboardSmoke = hasArg(args, "--keyboard-smoke")
    local controllerSmoke = hasArg(args, "--controller-smoke")
    local journalSmoke = hasArg(args, "--journal-smoke")
    local tutorialSmoke = hasArg(args, "--tutorial-smoke")
    local toastSmoke = hasArg(args, "--toast-smoke")
    local polishSmoke = hasArg(args, "--polish-smoke")
    local tacticalSmoke = hasArg(args, "--tactical-smoke")
    local tacticalAiDebug = hasArg(args, "--tactical-ai-debug")
    local tacticalPreviewState = argValue(args, "--tactical-preview-state", nil)
    local accessibilityExport = argValue(args, "--accessibility-export", nil)
    local smoke = hasArg(args, "--smoke") or accessibilityExport ~= nil or titleSmoke or settingsSmoke or estateSmoke or combatSmoke or curioSmoke or campSmoke or pauseSmoke or gameOverSmoke or creditsSmoke or confirmSmoke or keyboardSmoke or controllerSmoke or journalSmoke or tutorialSmoke or toastSmoke or polishSmoke or tacticalSmoke
    local renderSmoke = hasArg(args, "--render-smoke")
    local previewCapture = argValue(args, "--preview-capture", nil)
    local renderBenchmarkFrames = tonumber(os.getenv("THOTH_RENDER_BENCH_FRAMES")) or 180
    local renderBenchmarkWarmupFrames = tonumber(os.getenv("THOTH_RENDER_BENCH_WARMUP")) or 30
    if renderBenchmark then
        setupRenderBenchmark(sim)
    end
    local loadedSettings = Settings.read("settings.thoth")
    if estateSmoke then
        sim:endExpedition(true)
        sim.estate.heirlooms = math.max(sim.estate.heirlooms or 0, 20)
    end
    if keyboardSmoke then
        sim:endExpedition(true)
        sim.estate.heirlooms = math.max(sim.estate.heirlooms or 0, 20)
    end
    if combatSmoke then
        sim:startCombat("entry", sim:currentRoomKey() or "0:0")
    end
    if curioSmoke then
        sim.player.facing = "east"
        sim.world:setTile(sim.player.x + 1, sim.player.y, sim.player.z, { id = "salt_font", data = 0 })
    end
    if campSmoke then
        sim.world:setTile(sim.player.x, sim.player.y, sim.player.z, { id = "camp_marker", data = 0 })
        sim:camp()
    end
    if gameOverSmoke then
        sim:endExpedition(true)
        sim.estate.campaign.dreadLimit = 2
        sim.estate.campaign.dread = 2
        sim:evaluateCampaignState()
    end
    if journalSmoke then
        sim:collectDocument("archive_writ_01", "smoke")
        local hero = sim:heroAtRank(1)
        hero.deathsDoor = true
        hero.deathblowResist = 0
        sim:damageHero(hero, hero.hp + 1)
    end
    if toastSmoke then
        sim:collectDocument("archive_writ_01", "smoke")
    end
    app = {
        camera = { x = 0, y = 0, zoom = 2 },
        paused = false,
        uiState = (titleSmoke and "title") or (polishSmoke and "title") or (settingsSmoke and "settings") or (gameOverSmoke and "gameover") or (creditsSmoke and "credits") or ((smoke or renderBenchmark or renderSmoke or loadBenchmark) and "game" or "title"),
        titleMenuIndex = 1,
        titleTime = 0,
        viewRotation = 0,
        viewRotationVisual = 0,
        renderer = "render3d",
        status = "ready",
        settings = loadedSettings or Settings.defaults(),
        settingsFocus = 1,
        audio = Audio.load(),
        moveCooldown = 0,
        smoke = smoke,
        smokeFrames = 0,
        renderBenchmark = renderBenchmark,
        loadBenchmark = loadBenchmark,
        renderSmoke = renderSmoke,
        previewCapture = previewCapture,
        accessibilityExport = accessibilityExport,
        previewCaptured = false,
        titleSmoke = titleSmoke,
        settingsSmoke = settingsSmoke,
        estateSmoke = estateSmoke,
        combatSmoke = combatSmoke,
        curioSmoke = curioSmoke,
        campSmoke = campSmoke,
        pauseSmoke = pauseSmoke,
        gameOverSmoke = gameOverSmoke,
        creditsSmoke = creditsSmoke,
        confirmSmoke = confirmSmoke,
        keyboardSmoke = keyboardSmoke,
        controllerSmoke = controllerSmoke,
        journalSmoke = journalSmoke,
        tutorialSmoke = tutorialSmoke,
        toastSmoke = toastSmoke,
        polishSmoke = polishSmoke,
        tacticalSmoke = tacticalSmoke,
        tacticalAiDebug = tacticalAiDebug,
        achievements = {},
        toasts = {},
        renderBenchmarkFrames = renderBenchmarkFrames,
        renderBenchmarkWarmupFrames = renderBenchmarkWarmupFrames,
        renderBenchmarkWarmupCount = 0,
        renderBenchmarkCount = 0,
        renderBenchmarkTotalMs = 0,
        renderBenchmarkMaxMs = 0,
        renderBenchmarkFrameTotalMs = 0,
        renderBenchmarkFrameMaxMs = 0,
        renderBenchmarkDrawSamples = {},
        renderBenchmarkFrameSamples = {},
        lastCueStatus = sim.status,
        lastAudioEventId = sim.eventSerial or 0,
        lastVisualEventId = sim.eventSerial or 0,
        lastJuiceEventId = sim.eventSerial or 0,
        damageNumbers = {},
        tacticalHitFlashes = {},
        combatHitPause = 0,
        combatShake = 0,
        combatShakeMagnitude = 0,
        cutsceneQueue = {},
    }
    refreshContinueState(app)
    refreshReplayState(app)
    Audio.applySettings(app.audio, app.settings)
    Audio.setMusicContext(app.audio, Audio.contextForState(app, sim), 0)
    Audio.updateMusic(app.audio, 0)
    if curioSmoke then
        app.curioModal = Render.curioModalForTarget(sim)
    end
    if renderBenchmark then
        enterTacticalGame(app)
    end
    if renderSmoke then
        app.tactics = {
            originX = sim.player.x - 1,
            originY = sim.player.y - 1,
            cursor = { x = 1, y = 1 },
            selectedUnitId = "lamplighter",
            state = TacticsState.new({
                board = {
                    width = 4,
                    height = 4,
                    tiles = {
                        ["2:2"] = {
                            kind = "claim_desk",
                            coverEdges = { north = "half", west = "full" },
                            hazard = { kind = "ink_spread", damage = 1 },
                        },
                    },
                },
                units = {
                    { id = "lamplighter", x = 1, y = 1 },
                },
            }),
            overlays = {
                movement = { { x = 1, y = 2 }, { x = 2, y = 1 } },
                los = { ["3:1"] = true },
                flanks = { { x = 3, y = 2 } },
                intents = { { x = 4, y = 2, label = "audit_line" } },
            },
        }
    end
    if tacticalSmoke then
        enterTacticalGame(app)
        configureTacticalPreviewCapture(app, tacticalPreviewState)
        app.tacticalSmoke = true
        app.smoke = true
    end
    if pauseSmoke then
        openPause(app)
    end
    if confirmSmoke then
        openPause(app)
        openConfirm(app, "Quit to Title", "Abandon this expedition and return to title?", "quitTitle")
    end
    if journalSmoke then
        openJournal(app, "game")
    end
    if tutorialSmoke then
        enterTacticalGame(app, SquadLoadout.runtimeLoadout(SquadLoadout.tutorialSelection()))
    end
    Achievements.update(sim, app)
    Render.load()
    if loadBenchmark then
        print("benchmark=load")
        print("renderer=" .. tostring(app.renderer))
        print("mode=" .. tostring(sim and sim.mode))
        print(string.format("load_ms=%.6f", (love.timer.getTime() - loadStartedAt) * 1000))
        love.event.quit(0)
    end
    if accessibilityExport then
        local ok, err = Accessibility.write(accessibilityExport, sim, app)
        print(ok and ("accessibility-export=" .. accessibilityExport) or ("accessibility-export-error=" .. tostring(err)))
        love.event.quit(ok and 0 or 1)
    end
end

function love.update(dt)
    if app and app.importMode then
        return
    end
    if app.renderBenchmark and not app.renderBenchmarkDone then
        app.renderBenchmarkFrameStartedAt = love.timer.getTime()
    end
    app.titleTime = (app.settings and app.settings.reducedMotion) and 0 or ((app.titleTime or 0) + dt)
    advanceViewTurn(app, dt)
    Audio.updateForState(app.audio, dt, app, sim)
    Achievements.updateToasts(app, dt)
    if app.uiPulse and app.settings and app.settings.reducedMotion then
        app.uiPulse = nil
    elseif app.uiPulse then
        app.uiPulse.t = (app.uiPulse.t or 0) - dt
        if app.uiPulse.t <= 0 then
            app.uiPulse = nil
        end
    end
    advanceCombatJuice(app, dt)
    if app.uiState ~= "game" then
        if app.smoke then
            app.smokeFrames = app.smokeFrames + 1
            if app.smokeFrames >= 3 then
                love.event.quit(0)
            end
        end
        return
    end
    if syncGameOverState(app) then
        return
    end
    if app.tactics then
        local partyAdvanced = TacticalRuntime.advancePartyMove(app.tactics, dt)
        TacticalRuntime.syncWorld(sim, app.tactics)
        consumeTacticalHitEvents(app)
        if partyAdvanced then
            app.tacticalOverlays = app.tactics.overlays
            app.tacticalSummaryCache = nil
            if love and love.mouse and love.mouse.getPosition then
                local x, y = love.mouse.getPosition()
                Input.updateTacticalHover(app, x, y)
            end
        end
    end
    if app.tutorialMission and app.tactics and app.tactics.routeComplete and not app.tutorialMissionComplete and #(app.damageNumbers or {}) == 0 then
        app.tutorialMissionComplete = true
        enterSquadLoadout(app, "mission1")
        return
    end
    if app.smoke then
        app.smokeFrames = app.smokeFrames + 1
        if app.smokeFrames >= 3 then
            love.event.quit(0)
        end
    end
end

function love.draw()
    if app and app.importMode then
        return
    end
    Render.applyFont(app)
    if app.uiState == "title" then
        Render.drawTitle(sim, app)
        printTitleSmoke(app)
        printPolishSmoke(app)
        capturePreviewIfNeeded(app)
        return
    end
    if app.uiState == "settings" then
        Render.drawSettings(app)
        printSettingsSmoke(app)
        capturePreviewIfNeeded(app)
        return
    end
    if app.uiState == "squad_loadout" then
        Render.drawSquadLoadout(sim, app)
        capturePreviewIfNeeded(app)
        return
    end
    if app.uiState == "gameover" then
        Render.drawGameOver(sim, app)
        printGameOverSmoke(app)
        capturePreviewIfNeeded(app)
        return
    end
    if app.uiState == "credits" then
        Render.drawCredits(app)
        printCreditsSmoke(app)
        capturePreviewIfNeeded(app)
        return
    end
    if app.uiState == "journal" then
        Render.drawJournal(sim, app)
        printJournalSmoke(app)
        capturePreviewIfNeeded(app)
        return
    end
    local started = app.renderBenchmark and love.timer.getTime() or nil
    Render.draw(sim, app)
    printRenderSmoke(app)
    printTacticalSmoke(app)
    printEstateSmoke(app)
    printCombatSmoke(app)
    printCurioSmoke(app)
    printCampSmoke(app)
    printPauseSmoke(app)
    printConfirmSmoke(app)
    printKeyboardSmoke(app)
    printControllerSmoke(app)
    printTutorialSmoke(app)
    printToastSmoke(app)
    capturePreviewIfNeeded(app)
    if app.renderBenchmark and not app.renderBenchmarkDone then
        local finishedAt = love.timer.getTime()
        local elapsedMs = (finishedAt - started) * 1000
        local frameMs = (finishedAt - (app.renderBenchmarkFrameStartedAt or started)) * 1000
        if (app.renderBenchmarkWarmupCount or 0) < (app.renderBenchmarkWarmupFrames or 0) then
            app.renderBenchmarkWarmupCount = (app.renderBenchmarkWarmupCount or 0) + 1
            return
        end
        app.renderBenchmarkCount = app.renderBenchmarkCount + 1
        app.renderBenchmarkTotalMs = app.renderBenchmarkTotalMs + elapsedMs
        app.renderBenchmarkMaxMs = math.max(app.renderBenchmarkMaxMs, elapsedMs)
        app.renderBenchmarkFrameTotalMs = app.renderBenchmarkFrameTotalMs + frameMs
        app.renderBenchmarkFrameMaxMs = math.max(app.renderBenchmarkFrameMaxMs, frameMs)
        app.renderBenchmarkDrawSamples[#app.renderBenchmarkDrawSamples + 1] = elapsedMs
        app.renderBenchmarkFrameSamples[#app.renderBenchmarkFrameSamples + 1] = frameMs
        if app.renderBenchmarkCount >= app.renderBenchmarkFrames then
            app.renderBenchmarkDone = true
            print("benchmark=render")
            print("renderer=" .. tostring(app.renderer))
            print("mode=" .. tostring(app.worldView and app.worldView.mode))
            print("frames=" .. app.renderBenchmarkCount)
            print(string.format("avg_draw_ms=%.6f", app.renderBenchmarkTotalMs / app.renderBenchmarkCount))
            print(string.format("max_draw_ms=%.6f", app.renderBenchmarkMaxMs))
            print(string.format("p99_draw_ms=%.6f", percentile(app.renderBenchmarkDrawSamples, 0.99)))
            print(string.format("avg_frame_ms=%.6f", app.renderBenchmarkFrameTotalMs / app.renderBenchmarkCount))
            print(string.format("max_frame_ms=%.6f", app.renderBenchmarkFrameMaxMs))
            print(string.format("p99_frame_ms=%.6f", percentile(app.renderBenchmarkFrameSamples, 0.99)))
            love.event.quit(0)
        end
    end
end

local gamepadAxisState = {}

local function refreshTacticalPointerState(state)
    if not (state and state.tactics) then
        return
    end
    local steps = Render.rotationSteps(state)
    state.viewRotation = (state.viewRotation or 0) % steps
    if not state.viewTurn then
        state.viewRotationVisual = state.viewRotation
    end
    if love and love.mouse and love.mouse.getPosition then
        local x, y = love.mouse.getPosition()
        Input.updateTacticalHover(state, x, y)
    elseif state.tacticalHover then
        state.tacticalInspector = Render.tacticalTileInspectorSummary(state)
    end
    state.tacticalOverlays = state.tactics.overlays
    state.tacticalSummaryCache = nil
end

local function handleKey(key)
    if app.uiState == "title" then
        keyTitle(app, key)
        return
    end
    if app.uiState == "settings" then
        keySettings(app, key)
        return
    end
    if app.uiState == "squad_loadout" then
        keySquadLoadout(app, key)
        return
    end
    if app.uiState == "gameover" then
        keyGameOver(app, key)
        return
    end
    if app.uiState == "credits" then
        keyCredits(app, key)
        return
    end
    if app.uiState == "journal" then
        keyJournal(app, key)
        return
    end
    if app.tutorial and app.tutorial.active then
        keyTutorial(app, key)
        return
    end
    if app.confirmDialog then
        keyConfirm(app, key)
        return
    end
    if app.paused then
        keyPause(app, key)
        return
    end
    if Settings.isAction(app.settings, key, "pause", "escape") then
        if Input.back(sim, app) then
            return
        end
        openPause(app)
        Audio.play(app.audio, "tick")
        return
    end
    if key == "j" then
        openJournal(app, "game")
        Audio.play(app.audio, "tick")
        return
    end
    if key == "f5" then
        local ok, err = Save.write(sim, "save.thoth")
        app.status = ok and "saved" or ("save failed: " .. tostring(err))
        refreshContinueState(app)
        playUi(app, ok and "save" or "invalid")
        return
    end
    if key == "f9" then
        local loaded, err = Save.read("save.thoth")
        if loaded then
            enterTacticalGame(app)
            app.status = "loaded"
            app.lastCueStatus = sim.status
            app.lastVisualEventId = sim.eventSerial or 0
            app.cutscene = nil
            app.cutsceneQueue = {}
            syncGameOverState(app)
            playUi(app, "load")
        else
            app.status = "load failed: " .. tostring(err)
            playUi(app, "invalid")
        end
        return
    end
    if key == "f3" and app.tactics then
        app.tacticalAiDebug = TacticalRuntime.toggleAiDebug(app.tactics)
        app.tacticalOverlays = app.tactics.overlays
        app.tacticalSummaryCache = nil
        Audio.play(app.audio, "tick")
        return
    end
    if key == "[" then
        turnView(app, -1)
        refreshTacticalPointerState(app)
        Audio.play(app.audio, "tick")
    elseif key == "]" then
        turnView(app, 1)
        refreshTacticalPointerState(app)
        Audio.play(app.audio, "tick")
    elseif app.tactics and app.tactics.handleKey and app.tactics:handleKey(key) then
        TacticalRuntime.syncWorld(sim, app.tactics)
        refreshTacticalPointerState(app)
        consumeTacticalHitEvents(app)
        Audio.play(app.audio, "tick")
    else
        playUi(app, "invalid")
    end
end

local function updateTacticalMouseHover(x, y)
    if not (app and app.uiState == "game" and app.tactics and not app.paused and not app.confirmDialog) then
        return false
    end
    return Input.updateTacticalHover(app, x, y)
end

local function tacticalBoardContains(x, y)
    local rect = app and app.worldView and app.worldView.boardRect
    if not rect then
        return true
    end
    return x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
end

local function beginTacticalDrag(x, y, button)
    if not (app and app.uiState == "game" and app.tactics and not app.paused and not app.confirmDialog) then
        return false
    end
    local _, group = Render.hitboxAt(app, x, y)
    if group or not tacticalBoardContains(x, y) then
        return false
    end
    app.tacticalDrag = {
        button = button,
        startX = x,
        startY = y,
        lastX = x,
        lastY = y,
        active = button ~= 1,
    }
    return true
end

local function updateTacticalDrag(x, y)
    local drag = app and app.tacticalDrag
    if not drag then
        return false
    end
    local movedX = x - drag.startX
    local movedY = y - drag.startY
    if not drag.active and (movedX * movedX + movedY * movedY) < 36 then
        return true
    end
    drag.active = true
    local dx, dy = Render.tacticalDragWorldDelta(app, drag.lastX, drag.lastY, x, y)
    if dx and dy then
        Render.panTacticalCamera(app, dx, dy)
        app.status = "pan " .. string.format("%.1f", app.tacticalCameraCenterX or 0) .. "," .. string.format("%.1f", app.tacticalCameraCenterY or 0)
    end
    drag.lastX = x
    drag.lastY = y
    app.tacticalIntentHover = nil
    return true
end

local function mouseTactical(x, y, button)
    if Input.updateTacticalIntentHover(app, x, y) then
        Audio.play(app.audio, "tick")
        return true
    end
    if not updateTacticalMouseHover(x, y) then
        playUi(app, "invalid")
        return true
    end
    local tileX, tileY = Render.tacticalTileAt(app, x, y)
    if app.tactics:handleMouseTile(tileX, tileY, button) then
        TacticalRuntime.evaluate(app.tactics)
        app.tacticalOverlays = app.tactics.overlays
        TacticalRuntime.syncWorld(sim, app.tactics)
        consumeTacticalHitEvents(app)
        Audio.play(app.audio, "tick")
    else
        playUi(app, "invalid")
    end
    return true
end

function love.keypressed(key)
    if key == "c" and love.keyboard.isDown("lctrl", "rctrl") then
        requestQuit(app)
        return
    end
    handleKey(key)
end

function love.gamepadpressed(_, button)
    local key = Input.gamepadButtonKey(button)
    if key then
        handleKey(key)
    end
end

function love.gamepadaxis(_, axis, value)
    local key = Input.gamepadAxisKey(axis, value, gamepadAxisState)
    if key then
        handleKey(key)
    end
end

function love.mousepressed(x, y, button)
    local hitbox, group = Render.hitboxAt(app, x, y)
    if button == 1 then
        Render.markUiPulse(app, hitbox, "press")
    end
    if button == 1 and app.uiState == "title" then
        mouseTitle(app, x, y)
        return
    end
    if button == 1 and app.uiState == "settings" then
        mouseSettings(app, x, y)
        return
    end
    if button == 1 and app.uiState == "squad_loadout" then
        mouseSquadLoadout(app, x, y)
        return
    end
    if button == 1 and app.uiState == "gameover" then
        mouseGameOver(app, x, y)
        return
    end
    if button == 1 and app.uiState == "credits" then
        mouseCredits(app, x, y)
        return
    end
    if button == 1 and app.uiState == "journal" then
        mouseJournal(app, x, y)
        return
    end
    if button == 1 and app.tutorial and app.tutorial.active then
        mouseTutorial(app, x, y)
        return
    end
    if button == 1 and app.confirmDialog then
        mouseConfirm(app, x, y)
        return
    end
    if button == 1 and app.paused then
        mousePause(app, x, y)
        return
    end
    if app.uiState == "game" and app.tactics and (button == 1 or button == 3) and not group and beginTacticalDrag(x, y, button) then
        return
    end
    if app.uiState == "game" then
        mouseTactical(x, y, button)
        return
    end
end

function love.wheelmoved(_, y)
    if app.uiState == "game" and not app.paused and not app.confirmDialog and y ~= 0 then
        local zoom = Render.adjustTacticalZoom(app, y)
        app.status = "zoom " .. tostring(math.floor(zoom * 100 + 0.5)) .. "%"
        Audio.play(app.audio, "tick")
        return
    end
    if app.uiState == "credits" then
        app.creditsScroll = math.max(0, (app.creditsScroll or 0) - y)
    end
end

function love.mousemoved(x, y)
    if updateTacticalDrag(x, y) then
        return
    end
    local _, group, index = Render.hitboxAt(app, x, y)
    app.uiHot = group and { group = group, index = index } or nil
    if group == "tacticalIntentButtons" then
        Input.updateTacticalIntentHover(app, x, y)
    elseif not group then
        if app then
            app.tacticalIntentHover = nil
        end
        updateTacticalMouseHover(x, y)
    elseif app then
        app.tacticalIntentHover = nil
    end
end

function love.mousereleased(x, y, button)
    local drag = app and app.tacticalDrag
    if drag and drag.button == button then
        app.tacticalDrag = nil
        if drag.active then
            return
        end
        mouseTactical(x, y, button)
        return
    end
    if app then
        Input.mousereleased(sim, app, x, y, button)
    end
end

function love.quit()
    if app and (app.smoke or app.renderBenchmark or app.loadBenchmark) then
        return false
    end
    if app and app.uiState == "game" and not app.quitConfirmed and midExpedition() then
        if not app.confirmDialog then
            openPause(app)
            openConfirm(app, "Quit Game", "Abandon this expedition and quit?", "quitApp")
        end
        return true
    end
    return false
end
