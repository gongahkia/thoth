local Audio = require("src.app.audio")
local Render = require("src.app.render")
local Settings = require("src.app.settings")

local Input = {}

local movementOrder = {
    { "w", "up" },
    { "up", "up" },
    { "d", "right" },
    { "right", "right" },
    { "s", "down" },
    { "down", "down" },
    { "a", "left" },
    { "left", "left" },
}

local movementKeys = {}
local movementDirectionKeys = { up = {}, right = {}, down = {}, left = {} }
for _, entry in ipairs(movementOrder) do
    movementKeys[entry[1]] = entry[2]
    movementDirectionKeys[entry[2]][#movementDirectionKeys[entry[2]] + 1] = entry[1]
end

local screenDirectionIndexes = { up = 0, right = 1, down = 2, left = 3 }
local worldDirections = { "north", "east", "south", "west" }
local boundMovementOrder = {
    { "moveUp", "up" },
    { "moveRight", "right" },
    { "moveDown", "down" },
    { "moveLeft", "left" },
}
local screenDirectionActions = {
    up = "moveUp",
    right = "moveRight",
    down = "moveDown",
    left = "moveLeft",
}
local focusGroups = {
    "curioButtons",
    "campSkillButtons",
    "campHeroButtons",
    "skillButtons",
    "enemyButtons",
    "heroButtons",
    "missionButtons",
    "recruitButtons",
    "provisionButtons",
    "rosterButtons",
    "partyRankSlots",
    "estateActionButtons",
}
local gamepadButtonKeys = {
    a = "return",
    b = "escape",
    x = "space",
    y = "tab",
    back = "tab",
    start = "escape",
    dpup = "up",
    dpdown = "down",
    dpleft = "left",
    dpright = "right",
    leftshoulder = "[",
    rightshoulder = "]",
}

local legacyCommands = setmetatable({}, {
    __index = function(_, commandType)
        return function(...)
            return { type = commandType, args = { ... } }
        end
    end,
})

local function worldDirectionForScreen(app, screenDirection)
    local index = screenDirectionIndexes[screenDirection] or 0
    local rotation = app and app.viewRotation or 0
    return worldDirections[((index + rotation) % 4) + 1]
end

local function isScreenDirectionDown(screenDirection, app)
    for _, key in ipairs(movementDirectionKeys[screenDirection] or {}) do
        if love.keyboard.isDown(key) then
            return true
        end
    end
    local action = screenDirectionActions[screenDirection]
    local bound = action and Settings.keyForAction(app and app.settings, action)
    if bound and love.keyboard.isDown(bound) then
        return true
    end
    return false
end

local function heldScreenDirection(app)
    if app.activeMoveDirection and isScreenDirectionDown(app.activeMoveDirection, app) then
        return app.activeMoveDirection
    end
    for _, entry in ipairs(movementOrder) do
        local key, screenDirection = entry[1], entry[2]
        if love.keyboard.isDown(key) then
            app.activeMoveDirection = screenDirection
            return screenDirection
        end
    end
    for _, entry in ipairs(boundMovementOrder) do
        local key = Settings.keyForAction(app and app.settings, entry[1])
        if key and love.keyboard.isDown(key) then
            app.activeMoveDirection = entry[2]
            return entry[2]
        end
    end
    app.activeMoveDirection = nil
    return nil
end

local function requestMove(app, screenDirection)
    app.moveIntent = screenDirection
    app.activeMoveDirection = screenDirection
end

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

local function rotateView(app, delta)
    local from = app.viewRotationVisual or app.viewRotation or 0
    local target = ((app.viewRotation or 0) + delta) % 4
    local diff = target - from
    while diff > 2 do
        diff = diff - 4
    end
    while diff < -2 do
        diff = diff + 4
    end
    app.previousViewRotation = (app.viewRotation or 0) % 4
    app.viewRotation = target
    if Render.reducedMotion(app) then
        app.viewRotationVisual = target
        app.viewTurn = nil
    else
        app.viewTurn = { from = from, to = from + diff, t = 0, duration = 0.24 }
    end
    app.status = "view " .. (app.viewRotation * 90)
end

local function play(app, cue)
    Audio.play(app.audio, cue)
    if cue == "invalid" or cue == "ui_error" then
        Render.markUiFeedback(app, "error")
    elseif cue == "save" or cue == "load" or cue == "craft" or cue == "place" or cue == "produce" or cue == "ui_confirm" then
        Render.markUiFeedback(app, "success")
    end
end

local function focusables(app)
    local result = {}
    for _, group in ipairs(focusGroups) do
        for index, hitbox in ipairs((app.ui and app.ui[group]) or {}) do
            if hitbox.enabled ~= false then
                result[#result + 1] = { group = group, index = index, hitbox = hitbox }
            end
        end
    end
    return result
end

local function sameFocus(a, b)
    return a and b and a.group == b.group and a.index == b.index
end

local function focusedEntry(app, entries)
    entries = entries or focusables(app)
    for position, entry in ipairs(entries) do
        if sameFocus(app.keyboardFocus, entry) then
            return entry, position
        end
    end
    return nil, nil
end

function Input.focusables(app)
    return focusables(app)
end

function Input.cycleFocus(app, delta)
    local entries = focusables(app)
    if #entries == 0 then
        app.keyboardFocus = nil
        return nil
    end
    local _, position = focusedEntry(app, entries)
    position = position or (delta > 0 and 0 or 1)
    local nextPosition = ((position - 1 + delta) % #entries) + 1
    app.keyboardFocus = { group = entries[nextPosition].group, index = entries[nextPosition].index }
    return entries[nextPosition]
end

function Input.focusedEntry(app)
    return focusedEntry(app)
end

function Input.gamepadButtonKey(button)
    return gamepadButtonKeys[button]
end

function Input.tacticalGamepadMap()
    return copyValue({
        cursor = { axes = { "leftx", "lefty" }, digital = { "dpup", "dpright", "dpdown", "dpleft" } },
        select = { button = "a", key = gamepadButtonKeys.a },
        back = { button = "b", key = gamepadButtonKeys.b },
        inspect = { button = "x", key = gamepadButtonKeys.x },
        focus = { button = "y", key = gamepadButtonKeys.y },
        rotateLeft = { button = "leftshoulder", key = gamepadButtonKeys.leftshoulder },
        rotateRight = { button = "rightshoulder", key = gamepadButtonKeys.rightshoulder },
    })
end

function Input.gamepadAxisKey(axis, value, axisState)
    axisState = axisState or {}
    local key
    if axis == "leftx" then
        key = value <= -0.55 and "left" or (value >= 0.55 and "right" or nil)
    elseif axis == "lefty" then
        key = value <= -0.55 and "up" or (value >= 0.55 and "down" or nil)
    end
    if not key then
        axisState[axis] = nil
        return nil
    end
    if axisState[axis] == key then
        return nil
    end
    axisState[axis] = key
    return key
end

function Input.updateTacticalHover(app, x, y)
    if not (app and app.tactics) then
        return false
    end
    local tileX, tileY = Render.tacticalTileAt(app, x, y)
    if not tileX then
        app.tacticalHover = nil
        app.tacticalInspector = nil
        return false
    end
    app.tacticalHover = { x = tileX, y = tileY, screenX = x, screenY = y }
    app.tacticalInspector = Render.tacticalTileInspectorSummary(app)
    return true
end

function Input.updateTacticalIntentHover(app, x, y)
    for _, hitbox in ipairs((app and app.ui and app.ui.tacticalIntentButtons) or {}) do
        if x >= hitbox.x and x <= hitbox.x + hitbox.w and y >= hitbox.y and y <= hitbox.y + hitbox.h then
            app.tacticalIntentHover = {
                unit = hitbox.intentUnit,
                sourceTile = hitbox.sourceTile,
                targetTiles = hitbox.targetTiles or {},
            }
            local tile = hitbox.targetTiles and hitbox.targetTiles[1] or hitbox.sourceTile
            if tile then
                app.tacticalHover = { x = tile.x, y = tile.y, screenX = x, screenY = y }
                app.tacticalInspector = Render.tacticalTileInspectorSummary(app)
            end
            return true
        end
    end
    if app then
        app.tacticalIntentHover = nil
    end
    return false
end

local function boundMovementDirection(app, key)
    for _, entry in ipairs(boundMovementOrder) do
        if Settings.isAction(app and app.settings, key, entry[1]) then
            return entry[2]
        end
    end
    return nil
end

local function activeRender(app)
    if app and (app.renderer == "render3d" or (app.worldView and app.worldView.mode == "render3d")) then
        return require("src.app.render")
    end
    return require("src.app.render")
end

local function openCurioModal(sim, app)
    local modal = activeRender(app).curioModalForTarget(sim)
    if modal then
        local tile = sim.world and sim.world:getTile(modal.x, modal.y, modal.z or 0)
        local object = { x = modal.x, y = modal.y, z = modal.z or 0, tile = tile and tile.id }
        if sim.objectsInRect then
            for _, candidate in ipairs(sim:objectsInRect(modal.x, modal.x, modal.y, modal.y, modal.z or 0)) do
                if candidate.x == modal.x and candidate.y == modal.y then
                    object = candidate
                    break
                end
            end
        end
        local reveal = activeRender(app).objectRevealState(sim, app, object)
        if reveal and reveal.hidden then
            app.status = reveal.puzzleHidden and "rotate view to reveal" or "hidden by architecture"
            play(app, "invalid")
            return true
        end
        app.curioModal = modal
        app.status = "curio " .. modal.key
        play(app, "tick")
        return true
    end
    return false
end

local function chooseCurio(sim, app, choice)
    local modal = app.curioModal
    if not modal then
        return false
    end
    app.curioModal = nil
    app.curioResult = { title = modal.title, text = modal.result, t = 1.8 }
    if choice ~= "leave_alone" then
        sim:queue(legacyCommands.curioChoice(modal.x, modal.y, modal.z, modal.key, choice))
    else
        sim:queue(legacyCommands.curioChoice(modal.x, modal.y, modal.z, modal.key, "leave_alone"))
    end
    app.status = "curio " .. tostring(choice)
    play(app, choice == "leave_alone" and "tick" or "produce")
    return true
end

function Input.update(sim, app, dt)
    app.moveCooldown = math.max(0, (app.moveCooldown or 0) - dt)
    if app.moveCooldown > 0 or sim.mode ~= "expedition" then
        return
    end
    local screenDirection = app.moveIntent or heldScreenDirection(app)
    app.moveIntent = nil
    if screenDirection then
        local direction = worldDirectionForScreen(app, screenDirection)
        sim:queue(legacyCommands.move(direction))
        app.status = "move " .. direction
        app.moveCooldown = 0.12
    end
end

function Input.activateFocused(sim, app)
    local entry = focusedEntry(app)
    if not entry then
        entry = Input.cycleFocus(app, 1)
    end
    if not entry then
        return false
    end
    local hitbox = entry.hitbox
    if entry.group == "partyRankSlots" then
        local heroId = app.dragHeroId or app.estateHeroId
        if heroId then
            sim:queue(legacyCommands.assignParty(heroId, hitbox.rank))
            app.status = "assign rank " .. hitbox.rank
            app.dragHeroId = nil
            app.uiPulse = { x = hitbox.x, y = hitbox.y, w = hitbox.w, h = hitbox.h, t = 0.22, kind = "press" }
            play(app, "craft")
            return true
        end
        play(app, "invalid")
        return true
    end
    app.uiPulse = { x = hitbox.x, y = hitbox.y, w = hitbox.w, h = hitbox.h, t = 0.22, kind = "press" }
    Input.mousepressed(sim, app, hitbox.x + hitbox.w / 2, hitbox.y + hitbox.h / 2, 1)
    return true
end

function Input.back(sim, app)
    if app.curioModal then
        app.curioModal = nil
        play(app, "tick")
        return true
    end
    if app.pendingSkillKey then
        app.pendingSkillKey = nil
        app.pendingTargetSide = nil
        app.status = "target canceled"
        play(app, "tick")
        return true
    end
    if app.pendingCampSkillKey then
        app.pendingCampSkillKey = nil
        app.status = "camp canceled"
        play(app, "tick")
        return true
    end
    if app.trinketTooltipKey then
        app.trinketTooltipKey = nil
        play(app, "tick")
        return true
    end
    if app.keyboardFocus then
        app.keyboardFocus = nil
        play(app, "tick")
        return true
    end
    if app.panel == "estate" and sim.mode ~= "estate" then
        app.panel = nil
        app.status = "map"
        play(app, "tick")
        return true
    end
    return false
end

function Input.keypressed(sim, app, key)
    if app.curioModal then
        if key == "escape" then
            app.curioModal = nil
            play(app, "tick")
            return
        end
        if key:match("^[1-4]$") then
            local choice = app.curioModal.choices[tonumber(key)]
            if choice and choice.enabled then
                chooseCurio(sim, app, choice.key)
            else
                play(app, "invalid")
            end
            return
        end
    end
    if key == "tab" then
        local delta = love.keyboard.isDown("lshift", "rshift") and -1 or 1
        local entry = Input.cycleFocus(app, delta)
        if entry then
            app.status = "focus " .. entry.group
            play(app, "tick")
            return
        end
        app.panel = app.panel == "estate" and nil or "estate"
        app.status = app.panel or "map"
        play(app, "tick")
        return
    end
    if key == "return" or key == "kpenter" then
        if Input.activateFocused(sim, app) then
            return
        end
    end
    if key == "backspace" then
        if Input.back(sim, app) then
            return
        end
    end
    local screenDirection = movementKeys[key] or boundMovementDirection(app, key)
    if screenDirection then
        requestMove(app, screenDirection)
        return
    end
    if key == "[" then
        rotateView(app, -1)
        play(app, "tick")
        return
    end
    if key == "]" then
        rotateView(app, 1)
        play(app, "tick")
        return
    end
    if Settings.isAction(app and app.settings, key, "interact", "space") then
        if sim.mode == "estate" then
            sim:queue(legacyCommands.startExpedition("buried_archive"))
            app.status = "start expedition"
        elseif sim.mode == "combat" then
            sim:queue(legacyCommands.passTurn())
            app.status = "pass"
        elseif sim.expedition and sim.expedition.camping then
            sim:queue(legacyCommands.finishCamp())
            app.status = "finish camp"
        elseif openCurioModal(sim, app) then
            return
        else
            sim:queue(legacyCommands.interact())
            app.status = "interact"
        end
        play(app, "tick")
        return
    end
    if key == "c" then
        sim:queue(legacyCommands.camp())
        app.status = "camp"
        play(app, "save")
        return
    end
    if key == "r" then
        sim:queue(legacyCommands.retreat())
        app.status = "retreat"
        play(app, "invalid")
        return
    end
    if key == "t" then
        sim:queue(legacyCommands.useItem("torch"))
        app.status = "torch"
        play(app, "produce")
        return
    end
    if key == "h" then
        sim:queue(legacyCommands.useItem("ration"))
        app.status = "ration"
        play(app, "craft")
        return
    end
    if key:match("^[1-4]$") then
        local index = tonumber(key)
        if sim.mode == "combat" then
            sim:queue(legacyCommands.combatSkill(index))
            app.status = "skill " .. index
            play(app, "place")
        elseif sim.expedition and sim.expedition.camping then
            sim:queue(legacyCommands.campSkill(index))
            app.status = "camp skill " .. index
            play(app, "craft")
        else
            sim:queue(legacyCommands.selectHero(index))
            app.status = "hero " .. index
            play(app, "tick")
        end
    end
end

function Input.keyreleased(sim, app, key)
    local screenDirection = movementKeys[key] or boundMovementDirection(app, key)
    if screenDirection and app.activeMoveDirection == screenDirection and not isScreenDirectionDown(screenDirection, app) then
        app.activeMoveDirection = nil
    end
end

function Input.mousepressed(sim, app, x, y, button)
    if button ~= 1 then
        return
    end
    if app.curioModal then
        for _, hitbox in ipairs((app.ui and app.ui.curioButtons) or {}) do
            if x >= hitbox.x and x <= hitbox.x + hitbox.w and y >= hitbox.y and y <= hitbox.y + hitbox.h then
                if hitbox.enabled then
                    chooseCurio(sim, app, hitbox.choice)
                else
                    play(app, "invalid")
                end
                return
            end
        end
        return
    end
    for _, hitbox in ipairs((app.ui and app.ui.campSkillButtons) or {}) do
        if x >= hitbox.x and x <= hitbox.x + hitbox.w and y >= hitbox.y and y <= hitbox.y + hitbox.h then
            if hitbox.target == "party" then
                sim:queue(legacyCommands.campSkill(hitbox.skillKey))
                app.pendingCampSkillKey = nil
                app.status = "camp skill " .. hitbox.skillKey
            else
                app.pendingCampSkillKey = hitbox.skillKey
                app.status = "assign camp " .. hitbox.skillKey
            end
            play(app, "craft")
            return
        end
    end
    for _, hitbox in ipairs((app.ui and app.ui.campHeroButtons) or {}) do
        if x >= hitbox.x and x <= hitbox.x + hitbox.w and y >= hitbox.y and y <= hitbox.y + hitbox.h then
            if app.pendingCampSkillKey then
                sim:queue(legacyCommands.campSkill(app.pendingCampSkillKey, hitbox.rank))
                app.status = "camp hero " .. hitbox.rank
                app.pendingCampSkillKey = nil
                play(app, "craft")
            end
            return
        end
    end
    for _, hitbox in ipairs((app.ui and app.ui.enemyButtons) or {}) do
        if x >= hitbox.x and x <= hitbox.x + hitbox.w and y >= hitbox.y and y <= hitbox.y + hitbox.h then
            if app.pendingSkillKey and app.pendingTargetSide == "enemy" then
                sim:queue(legacyCommands.combatSkill(app.pendingSkillKey, hitbox.rank, "enemy", hitbox.partKey))
                app.status = "target enemy " .. hitbox.rank
                app.pendingSkillKey = nil
                app.pendingTargetSide = nil
                play(app, "place")
            end
            return
        end
    end
    for _, hitbox in ipairs((app.ui and app.ui.skillButtons) or {}) do
        if x >= hitbox.x and x <= hitbox.x + hitbox.w and y >= hitbox.y and y <= hitbox.y + hitbox.h then
            if hitbox.immediate or not hitbox.targetSide then
                sim:queue(legacyCommands.combatSkill(hitbox.skillKey, hitbox.targetRank, hitbox.targetSide))
                app.pendingSkillKey = nil
                app.pendingTargetSide = nil
                app.status = "skill " .. hitbox.skillKey
            else
                app.pendingSkillKey = hitbox.skillKey
                app.pendingTargetSide = hitbox.targetSide
                app.status = "target " .. hitbox.targetSide
            end
            play(app, "place")
            return
        end
    end
    for _, hitbox in ipairs((app.ui and app.ui.heroButtons) or {}) do
        if x >= hitbox.x and x <= hitbox.x + hitbox.w and y >= hitbox.y and y <= hitbox.y + hitbox.h then
            if app.pendingSkillKey and app.pendingTargetSide == "ally" and hitbox.side == "ally" then
                sim:queue(legacyCommands.combatSkill(app.pendingSkillKey, hitbox.rank, "ally"))
                app.status = "target ally " .. hitbox.rank
                app.pendingSkillKey = nil
                app.pendingTargetSide = nil
            else
                sim:queue(legacyCommands.selectHero(hitbox.rank))
                app.status = "hero " .. hitbox.rank
            end
            play(app, "tick")
            return
        end
    end
    for _, hitbox in ipairs((app.ui and app.ui.missionButtons) or {}) do
        if x >= hitbox.x and x <= hitbox.x + hitbox.w and y >= hitbox.y and y <= hitbox.y + hitbox.h then
            sim:queue(legacyCommands.startExpedition(hitbox.missionKey))
            app.status = "mission " .. hitbox.missionKey
            play(app, "save")
            return
        end
    end
    for _, hitbox in ipairs((app.ui and app.ui.recruitButtons) or {}) do
        if x >= hitbox.x and x <= hitbox.x + hitbox.w and y >= hitbox.y and y <= hitbox.y + hitbox.h then
            sim:queue(legacyCommands.recruitHero(hitbox.recruitIndex))
            app.status = "recruit " .. hitbox.recruitIndex
            play(app, "craft")
            return
        end
    end
    for _, hitbox in ipairs((app.ui and app.ui.provisionButtons) or {}) do
        if x >= hitbox.x and x <= hitbox.x + hitbox.w and y >= hitbox.y and y <= hitbox.y + hitbox.h then
            sim:queue(legacyCommands.buyProvision(hitbox.item, 1))
            app.status = "buy " .. hitbox.item
            play(app, "produce")
            return
        end
    end
    for _, hitbox in ipairs((app.ui and app.ui.rosterButtons) or {}) do
        if x >= hitbox.x and x <= hitbox.x + hitbox.w and y >= hitbox.y and y <= hitbox.y + hitbox.h then
            app.estateHeroId = hitbox.heroId
            app.dragHeroId = hitbox.heroId
            app.status = "roster " .. hitbox.heroId
            play(app, "tick")
            return
        end
    end
    local estateMinimal = app and app.settings and app.settings.estateMinimal -- ignore building/trinket actions in lean prototype mode
    for _, hitbox in ipairs((app.ui and app.ui.estateActionButtons) or {}) do
        if x >= hitbox.x and x <= hitbox.x + hitbox.w and y >= hitbox.y and y <= hitbox.y + hitbox.h then
            if hitbox.tooltipKey then
                app.trinketTooltipKey = hitbox.tooltipKey
            end
            if hitbox.action == "upgradeSkill" then
                sim:queue(legacyCommands.upgradeSkill(hitbox.heroId, hitbox.skillKey))
            elseif hitbox.action == "upgradeGear" then
                sim:queue(legacyCommands.upgradeGear(hitbox.heroId, hitbox.kind))
            elseif hitbox.action == "equipTrinket" and not estateMinimal then
                sim:queue(legacyCommands.equipTrinket(hitbox.heroId, hitbox.trinketKey, hitbox.slot))
            elseif hitbox.action == "unequipTrinket" and not estateMinimal then
                sim:queue(legacyCommands.unequipTrinket(hitbox.heroId, hitbox.slot))
            elseif hitbox.action == "sellTrinket" and not estateMinimal then
                sim:queue(legacyCommands.sellTrinket(hitbox.trinketKey))
            elseif hitbox.action == "buyTrinket" and not estateMinimal then
                sim:queue(legacyCommands.buyTrinket(hitbox.stockIndex))
            elseif hitbox.action == "upgradeBuilding" and not estateMinimal then
                sim:queue(legacyCommands.upgradeBuilding(hitbox.buildingKey))
            elseif hitbox.action == "recoverHero" then
                sim:queue(legacyCommands.recoverHero(hitbox.heroId, hitbox.activityKey))
            elseif hitbox.action == "dismissHero" then
                sim:queue(legacyCommands.dismissHero(hitbox.heroId))
            elseif hitbox.action == "treatQuirk" then
                sim:queue(legacyCommands.treatQuirk(hitbox.heroId, hitbox.quirkKey))
            elseif hitbox.action == "lockQuirk" then
                sim:queue(legacyCommands.lockQuirk(hitbox.heroId, hitbox.quirkKey))
            elseif hitbox.action == "treatDisease" then
                sim:queue(legacyCommands.treatDisease(hitbox.heroId, hitbox.diseaseKey))
            elseif hitbox.action == "assignParty" then
                sim:queue(legacyCommands.assignParty(hitbox.heroId, hitbox.rank))
            elseif hitbox.action == "rosterFilter" then
                app.rosterFilter = hitbox.filter
            elseif hitbox.action == "rosterSort" then
                app.rosterSort = hitbox.sort
            elseif hitbox.action == "openJournal" then
                app.journalReturnState = "game"
                app.uiState = "journal"
            end
            app.status = hitbox.action
            play(app, "craft")
            return
        end
    end
    if app.worldView and sim.mode == "expedition" then
        local wx, wy = activeRender(app).screenToWorld(app.worldView, x, y)
        local dx = wx - sim.player.x
        local dy = wy - sim.player.y
        if math.abs(dx) + math.abs(dy) == 1 then
            if dx == 1 then
                sim:queue(legacyCommands.move("east"))
            elseif dx == -1 then
                sim:queue(legacyCommands.move("west"))
            elseif dy == 1 then
                sim:queue(legacyCommands.move("south"))
            else
                sim:queue(legacyCommands.move("north"))
            end
        end
    end
end

function Input.mousereleased(sim, app, x, y, button)
    if button ~= 1 or not app.dragHeroId then
        return
    end
    local heroId = app.dragHeroId
    app.dragHeroId = nil
    for _, hitbox in ipairs((app.ui and app.ui.partyRankSlots) or {}) do
        if x >= hitbox.x and x <= hitbox.x + hitbox.w and y >= hitbox.y and y <= hitbox.y + hitbox.h then
            sim:queue(legacyCommands.assignParty(heroId, hitbox.rank))
            app.status = "assign rank " .. hitbox.rank
            play(app, "craft")
            return
        end
    end
end

return Input
