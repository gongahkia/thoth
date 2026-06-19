package.path = "./?.lua;./?/init.lua;./src/?.lua;./src/?/init.lua;" .. package.path

local Simulation = require("src.game.simulation")
local Input = require("src.app.input")
local Render = require("src.app.render")
local Audio = require("src.app.audio")
local Save = require("src.game.save")
local Settings = require("src.app.settings")

local sim
local app
local fixedDt = 1 / 60
local accumulator = 0

local function hasArg(args, target)
    for _, value in ipairs(args or {}) do
        if value == target then
            return true
        end
    end
    return false
end

local function setupRenderBenchmark(state)
    state.player.x = 12
    state.player.y = 3
end

local function cueColor(cue)
    if cue == "danger" then
        return { 0.85, 0.18, 0.16 }
    end
    if cue == "victory" then
        return { 0.82, 0.66, 0.28 }
    end
    if cue == "combat" then
        return { 0.7, 0.24, 0.24 }
    end
    if cue == "loot" then
        return { 0.38, 0.72, 0.46 }
    end
    return { 0.42, 0.54, 0.76 }
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

local function playStatusCue(state, simulation)
    if simulation.status == state.lastCueStatus then
        return
    end
    state.lastCueStatus = simulation.status
    local cue = Audio.cueForStatus(simulation.status)
    if cue then
        Audio.play(state.audio, cue)
        state.eventFlash = { cue = cue, color = cueColor(cue), t = 0.45 }
    end
end

local function queueCutscenes(state, simulation)
    state.lastVisualEventId = state.lastVisualEventId or (simulation.eventSerial or 0)
    state.cutsceneQueue = state.cutsceneQueue or {}
    for _, event in ipairs(simulation.events or {}) do
        if event.id > state.lastVisualEventId then
            local cutscene = Render.cutsceneForEvent(event, simulation)
            if cutscene then
                state.cutsceneQueue[#state.cutsceneQueue + 1] = cutscene
            end
            state.lastVisualEventId = event.id
        end
    end
    startNextCutscene(state)
end

local function resetVisualState(state, simulation)
    accumulator = 0
    state.moveCooldown = 0
    state.lastCueStatus = simulation.status
    state.lastVisualEventId = simulation.eventSerial or 0
    state.cutscene = nil
    state.cutsceneQueue = {}
    state.eventFlash = nil
    state.pendingSkillKey = nil
    state.pendingTargetSide = nil
end

local function describeSave(loaded)
    if not loaded then
        return "no save"
    end
    local week = loaded.estate and loaded.estate.week or 1
    return "save found: week " .. tostring(week) .. " / " .. tostring(loaded.mode)
end

local function refreshContinueState(state)
    local loaded = Save.read("save.thoth")
    state.canContinue = loaded ~= nil
    state.saveStatus = describeSave(loaded)
end

local function enterGame(state, simulation, status)
    sim = simulation
    state.uiState = "game"
    state.status = status or "ready"
    resetVisualState(state, sim)
end

local function requestQuit(state)
    state.quitRequested = true
    if love and love.event then
        love.event.quit(0)
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
        enterGame(state, Simulation.new(20260618), "new game")
        return
    end
    if action == "continue" then
        local loaded, err = Save.read("save.thoth")
        if loaded then
            enterGame(state, loaded, "loaded")
        else
            state.canContinue = false
            state.saveStatus = "load failed: " .. tostring(err)
            state.titleStatus = state.saveStatus
            Audio.play(state.audio, "invalid")
        end
        return
    end
    if action == "settings" then
        state.settingsReturnState = "title"
        state.uiState = "settings"
        state.titleStatus = "settings"
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
            Audio.play(state.audio, item.action == "quit" and "invalid" or "tick")
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
                Audio.play(state.audio, hitbox.action == "quit" and "invalid" or "tick")
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
            Audio.play(state.audio, "invalid")
            return
        end
        local ok, err = Settings.bindKey(state.settings, state.captureBinding, key)
        state.settingsStatus = ok and ("bound " .. state.captureBinding .. " to " .. key) or tostring(err)
        state.captureBinding = nil
        Audio.play(state.audio, ok and "save" or "invalid")
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
        if control.kind == "slider" then
            Settings.adjust(state.settings, control.setting, -1)
        elseif control.kind == "cycle" then
            Settings.cycle(state.settings, control.setting, -1)
        end
        Audio.applySettings(state.audio, state.settings)
        Audio.play(state.audio, "tick")
        return
    end
    if key == "right" or key == "d" then
        if control.kind == "slider" then
            Settings.adjust(state.settings, control.setting, 1)
        elseif control.kind == "cycle" then
            Settings.cycle(state.settings, control.setting, 1)
        end
        Audio.applySettings(state.audio, state.settings)
        Audio.play(state.audio, "tick")
        return
    end
    if key == "space" or key == "return" or key == "kpenter" then
        if control.kind == "toggle" then
            Settings.toggle(state.settings, control.setting)
            Audio.play(state.audio, "tick")
        elseif control.kind == "cycle" then
            Settings.cycle(state.settings, control.setting, 1)
            Audio.play(state.audio, "tick")
        elseif control.kind == "slider" then
            Settings.adjust(state.settings, control.setting, 1)
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
        Settings.adjust(state.settings, hitbox.setting, hitbox.delta or 1)
        Audio.applySettings(state.audio, state.settings)
        Audio.play(state.audio, "tick")
    elseif hitbox.action == "toggle" then
        Settings.toggle(state.settings, hitbox.setting)
        Audio.play(state.audio, "tick")
    elseif hitbox.action == "cycle" then
        Settings.cycle(state.settings, hitbox.setting, hitbox.delta or 1)
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
end

local function printSettingsSmoke(state)
    if not state.settingsSmoke or state.settingsSmokePrinted then
        return
    end
    state.settingsSmokePrinted = true
    local actions = {}
    for _, hitbox in ipairs((state.ui and state.ui.settingsButtons) or {}) do
        actions[hitbox.action] = true
    end
    print("settings-smoke-state=" .. tostring(state.uiState))
    print("settings-smoke-controls=" .. tostring(#Settings.controls()))
    print("settings-smoke-adjust=" .. tostring(actions.adjust == true))
    print("settings-smoke-bind=" .. tostring(actions.bind == true))
    print("settings-smoke-toggle=" .. tostring(actions.toggle == true))
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

function love.load(args)
    love.graphics.setDefaultFilter("nearest", "nearest")
    sim = Simulation.new(20260618)
    local renderBenchmark = hasArg(args, "--render-benchmark")
    local titleSmoke = hasArg(args, "--title-smoke")
    local settingsSmoke = hasArg(args, "--settings-smoke")
    local estateSmoke = hasArg(args, "--estate-smoke")
    local combatSmoke = hasArg(args, "--combat-smoke")
    local curioSmoke = hasArg(args, "--curio-smoke")
    local smoke = hasArg(args, "--smoke") or titleSmoke or settingsSmoke or estateSmoke or combatSmoke or curioSmoke
    local renderSmoke = hasArg(args, "--render-smoke")
    local renderBenchmarkFrames = tonumber(os.getenv("THOTH_RENDER_BENCH_FRAMES")) or 180
    if renderBenchmark then
        setupRenderBenchmark(sim)
    end
    if estateSmoke then
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
    app = {
        camera = { x = 0, y = 0, zoom = 2 },
        paused = false,
        uiState = (titleSmoke and "title") or (settingsSmoke and "settings") or ((smoke or renderBenchmark or renderSmoke) and "game" or "title"),
        titleMenuIndex = 1,
        titleTime = 0,
        viewRotation = 0,
        renderer = "render3d",
        status = "ready",
        settings = Settings.defaults(),
        settingsFocus = 1,
        audio = Audio.load(),
        moveCooldown = 0,
        smoke = smoke,
        smokeFrames = 0,
        renderBenchmark = renderBenchmark,
        renderSmoke = renderSmoke,
        titleSmoke = titleSmoke,
        settingsSmoke = settingsSmoke,
        estateSmoke = estateSmoke,
        combatSmoke = combatSmoke,
        curioSmoke = curioSmoke,
        renderBenchmarkFrames = renderBenchmarkFrames,
        renderBenchmarkCount = 0,
        renderBenchmarkTotalMs = 0,
        renderBenchmarkMaxMs = 0,
        lastCueStatus = sim.status,
        lastVisualEventId = sim.eventSerial or 0,
        cutsceneQueue = {},
    }
    refreshContinueState(app)
    Audio.applySettings(app.audio, app.settings)
    if curioSmoke then
        app.curioModal = Render.curioModalForTarget(sim)
    end
    Render.load()
end

function love.update(dt)
    app.titleTime = (app.titleTime or 0) + dt
    if app.uiState ~= "game" then
        if app.smoke then
            app.smokeFrames = app.smokeFrames + 1
            if app.smokeFrames >= 3 then
                love.event.quit(0)
            end
        end
        return
    end
    Input.update(sim, app, dt)
    Render.advanceCutscene(app, dt)
    startNextCutscene(app)
    if app.eventFlash then
        app.eventFlash.t = math.max(0, app.eventFlash.t - dt)
        if app.eventFlash.t <= 0 then
            app.eventFlash = nil
        end
    end
    if app.curioResult then
        app.curioResult.t = math.max(0, (app.curioResult.t or 0) - dt)
        if app.curioResult.t <= 0 then
            app.curioResult = nil
        end
    end
    accumulator = math.min(accumulator + dt, 0.25)
    local maxSteps = love.keyboard.isDown("lshift", "rshift") and 6 or 3
    local steps = 0
    while not app.paused and accumulator >= fixedDt and steps < maxSteps do
        sim:step()
        playStatusCue(app, sim)
        queueCutscenes(app, sim)
        accumulator = accumulator - fixedDt
        steps = steps + 1
    end
    if app.paused then
        accumulator = 0
    end
    if app.smoke then
        app.smokeFrames = app.smokeFrames + 1
        if app.smokeFrames >= 3 then
            love.event.quit(0)
        end
    end
end

function love.draw()
    if app.uiState == "title" then
        Render.drawTitle(sim, app)
        printTitleSmoke(app)
        return
    end
    if app.uiState == "settings" then
        Render.drawSettings(app)
        printSettingsSmoke(app)
        return
    end
    local started = app.renderBenchmark and love.timer.getTime() or nil
    Render.draw(sim, app)
    printRenderSmoke(app)
    printEstateSmoke(app)
    printCombatSmoke(app)
    printCurioSmoke(app)
    if app.renderBenchmark then
        local elapsedMs = (love.timer.getTime() - started) * 1000
        app.renderBenchmarkCount = app.renderBenchmarkCount + 1
        app.renderBenchmarkTotalMs = app.renderBenchmarkTotalMs + elapsedMs
        app.renderBenchmarkMaxMs = math.max(app.renderBenchmarkMaxMs, elapsedMs)
        if app.renderBenchmarkCount >= app.renderBenchmarkFrames then
            print("benchmark=render")
            print("renderer=" .. tostring(app.renderer))
            print("mode=" .. tostring(app.worldView and app.worldView.mode))
            print("frames=" .. app.renderBenchmarkCount)
            print(string.format("avg_draw_ms=%.6f", app.renderBenchmarkTotalMs / app.renderBenchmarkCount))
            print(string.format("max_draw_ms=%.6f", app.renderBenchmarkMaxMs))
            love.event.quit(0)
        end
    end
end

function love.keypressed(key)
    if app.uiState == "title" then
        keyTitle(app, key)
        return
    end
    if app.uiState == "settings" then
        keySettings(app, key)
        return
    end
    if key == "f5" then
        local ok, err = Save.write(sim, "save.thoth")
        app.status = ok and "saved" or ("save failed: " .. tostring(err))
        refreshContinueState(app)
        Audio.play(app.audio, ok and "save" or "invalid")
        return
    end
    if key == "f9" then
        local loaded, err = Save.read("save.thoth")
        if loaded then
            sim = loaded
            app.status = "loaded"
            app.lastCueStatus = sim.status
            app.lastVisualEventId = sim.eventSerial or 0
            app.cutscene = nil
            app.cutsceneQueue = {}
            Audio.play(app.audio, "load")
        else
            app.status = "load failed: " .. tostring(err)
            Audio.play(app.audio, "invalid")
        end
        return
    end
    Input.keypressed(sim, app, key)
end

function love.keyreleased(key)
    if app.uiState ~= "game" then
        return
    end
    Input.keyreleased(sim, app, key)
end

function love.mousepressed(x, y, button)
    if button == 1 and app.uiState == "title" then
        mouseTitle(app, x, y)
        return
    end
    if button == 1 and app.uiState == "settings" then
        mouseSettings(app, x, y)
        return
    end
    Input.mousepressed(sim, app, x, y, button)
end

function love.mousereleased(x, y, button)
    if app.uiState ~= "game" then
        return
    end
    Input.mousereleased(sim, app, x, y, button)
end
