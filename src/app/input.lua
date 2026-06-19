local Simulation = require("src.game.simulation")
local Audio = require("src.app.audio")
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

local function rotateView(app, delta)
    app.viewRotation = ((app.viewRotation or 0) + delta) % 4
    app.status = "view " .. (app.viewRotation * 90)
end

local function play(app, cue)
    Audio.play(app.audio, cue)
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
        sim:queue(Simulation.commands.curioChoice(modal.x, modal.y, modal.z, modal.key, choice))
    else
        sim:queue(Simulation.commands.curioChoice(modal.x, modal.y, modal.z, modal.key, "leave_alone"))
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
        sim:queue(Simulation.commands.move(direction))
        app.status = "move " .. direction
        app.moveCooldown = 0.12
    end
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
            sim:queue(Simulation.commands.startExpedition("buried_archive"))
            app.status = "start expedition"
        elseif sim.mode == "combat" then
            sim:queue(Simulation.commands.passTurn())
            app.status = "pass"
        elseif sim.expedition and sim.expedition.camping then
            sim:queue(Simulation.commands.finishCamp())
            app.status = "finish camp"
        elseif openCurioModal(sim, app) then
            return
        else
            sim:queue(Simulation.commands.interact())
            app.status = "interact"
        end
        play(app, "tick")
        return
    end
    if key == "tab" then
        app.panel = app.panel == "estate" and nil or "estate"
        app.status = app.panel or "map"
        play(app, "tick")
        return
    end
    if key == "c" then
        sim:queue(Simulation.commands.camp())
        app.status = "camp"
        play(app, "save")
        return
    end
    if key == "r" then
        sim:queue(Simulation.commands.retreat())
        app.status = "retreat"
        play(app, "invalid")
        return
    end
    if key == "t" then
        sim:queue(Simulation.commands.useItem("torch"))
        app.status = "torch"
        play(app, "produce")
        return
    end
    if key == "h" then
        sim:queue(Simulation.commands.useItem("ration"))
        app.status = "ration"
        play(app, "craft")
        return
    end
    if key:match("^[1-4]$") then
        local index = tonumber(key)
        if sim.mode == "combat" then
            sim:queue(Simulation.commands.combatSkill(index))
            app.status = "skill " .. index
            play(app, "place")
        elseif sim.expedition and sim.expedition.camping then
            sim:queue(Simulation.commands.campSkill(index))
            app.status = "camp skill " .. index
            play(app, "craft")
        else
            sim:queue(Simulation.commands.selectHero(index))
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
                sim:queue(Simulation.commands.campSkill(hitbox.skillKey))
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
                sim:queue(Simulation.commands.campSkill(app.pendingCampSkillKey, hitbox.rank))
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
                sim:queue(Simulation.commands.combatSkill(app.pendingSkillKey, hitbox.rank, "enemy", hitbox.partKey))
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
                sim:queue(Simulation.commands.combatSkill(hitbox.skillKey, hitbox.targetRank, hitbox.targetSide))
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
                sim:queue(Simulation.commands.combatSkill(app.pendingSkillKey, hitbox.rank, "ally"))
                app.status = "target ally " .. hitbox.rank
                app.pendingSkillKey = nil
                app.pendingTargetSide = nil
            else
                sim:queue(Simulation.commands.selectHero(hitbox.rank))
                app.status = "hero " .. hitbox.rank
            end
            play(app, "tick")
            return
        end
    end
    for _, hitbox in ipairs((app.ui and app.ui.missionButtons) or {}) do
        if x >= hitbox.x and x <= hitbox.x + hitbox.w and y >= hitbox.y and y <= hitbox.y + hitbox.h then
            sim:queue(Simulation.commands.startExpedition(hitbox.missionKey))
            app.status = "mission " .. hitbox.missionKey
            play(app, "save")
            return
        end
    end
    for _, hitbox in ipairs((app.ui and app.ui.recruitButtons) or {}) do
        if x >= hitbox.x and x <= hitbox.x + hitbox.w and y >= hitbox.y and y <= hitbox.y + hitbox.h then
            sim:queue(Simulation.commands.recruitHero(hitbox.recruitIndex))
            app.status = "recruit " .. hitbox.recruitIndex
            play(app, "craft")
            return
        end
    end
    for _, hitbox in ipairs((app.ui and app.ui.provisionButtons) or {}) do
        if x >= hitbox.x and x <= hitbox.x + hitbox.w and y >= hitbox.y and y <= hitbox.y + hitbox.h then
            sim:queue(Simulation.commands.buyProvision(hitbox.item, 1))
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
    for _, hitbox in ipairs((app.ui and app.ui.estateActionButtons) or {}) do
        if x >= hitbox.x and x <= hitbox.x + hitbox.w and y >= hitbox.y and y <= hitbox.y + hitbox.h then
            if hitbox.tooltipKey then
                app.trinketTooltipKey = hitbox.tooltipKey
            end
            if hitbox.action == "upgradeSkill" then
                sim:queue(Simulation.commands.upgradeSkill(hitbox.heroId, hitbox.skillKey))
            elseif hitbox.action == "upgradeGear" then
                sim:queue(Simulation.commands.upgradeGear(hitbox.heroId, hitbox.kind))
            elseif hitbox.action == "equipTrinket" then
                sim:queue(Simulation.commands.equipTrinket(hitbox.heroId, hitbox.trinketKey, hitbox.slot))
            elseif hitbox.action == "unequipTrinket" then
                sim:queue(Simulation.commands.unequipTrinket(hitbox.heroId, hitbox.slot))
            elseif hitbox.action == "sellTrinket" then
                sim:queue(Simulation.commands.sellTrinket(hitbox.trinketKey))
            elseif hitbox.action == "buyTrinket" then
                sim:queue(Simulation.commands.buyTrinket(hitbox.stockIndex))
            elseif hitbox.action == "upgradeBuilding" then
                sim:queue(Simulation.commands.upgradeBuilding(hitbox.buildingKey))
            elseif hitbox.action == "recoverHero" then
                sim:queue(Simulation.commands.recoverHero(hitbox.heroId, hitbox.activityKey))
            elseif hitbox.action == "dismissHero" then
                sim:queue(Simulation.commands.dismissHero(hitbox.heroId))
            elseif hitbox.action == "treatQuirk" then
                sim:queue(Simulation.commands.treatQuirk(hitbox.heroId, hitbox.quirkKey))
            elseif hitbox.action == "lockQuirk" then
                sim:queue(Simulation.commands.lockQuirk(hitbox.heroId, hitbox.quirkKey))
            elseif hitbox.action == "treatDisease" then
                sim:queue(Simulation.commands.treatDisease(hitbox.heroId, hitbox.diseaseKey))
            elseif hitbox.action == "assignParty" then
                sim:queue(Simulation.commands.assignParty(hitbox.heroId, hitbox.rank))
            elseif hitbox.action == "rosterFilter" then
                app.rosterFilter = hitbox.filter
            elseif hitbox.action == "rosterSort" then
                app.rosterSort = hitbox.sort
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
                sim:queue(Simulation.commands.move("east"))
            elseif dx == -1 then
                sim:queue(Simulation.commands.move("west"))
            elseif dy == 1 then
                sim:queue(Simulation.commands.move("south"))
            else
                sim:queue(Simulation.commands.move("north"))
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
            sim:queue(Simulation.commands.assignParty(heroId, hitbox.rank))
            app.status = "assign rank " .. hitbox.rank
            play(app, "craft")
            return
        end
    end
end

return Input
