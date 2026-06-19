local Simulation = require("src.game.simulation")
local Audio = require("src.app.audio")

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

local function worldDirectionForScreen(app, screenDirection)
    local index = screenDirectionIndexes[screenDirection] or 0
    local rotation = app and app.viewRotation or 0
    return worldDirections[((index + rotation) % 4) + 1]
end

local function isScreenDirectionDown(screenDirection)
    for _, key in ipairs(movementDirectionKeys[screenDirection] or {}) do
        if love.keyboard.isDown(key) then
            return true
        end
    end
    return false
end

local function heldScreenDirection(app)
    if app.activeMoveDirection and isScreenDirectionDown(app.activeMoveDirection) then
        return app.activeMoveDirection
    end
    for _, entry in ipairs(movementOrder) do
        local key, screenDirection = entry[1], entry[2]
        if love.keyboard.isDown(key) then
            app.activeMoveDirection = screenDirection
            return screenDirection
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
    if movementKeys[key] then
        requestMove(app, movementKeys[key])
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
    if key == "space" then
        if sim.mode == "estate" then
            sim:queue(Simulation.commands.startExpedition("buried_archive"))
            app.status = "start expedition"
        elseif sim.mode == "combat" then
            sim:queue(Simulation.commands.passTurn())
            app.status = "pass"
        elseif sim.expedition and sim.expedition.camping then
            sim:queue(Simulation.commands.finishCamp())
            app.status = "finish camp"
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
    local screenDirection = movementKeys[key]
    if screenDirection and app.activeMoveDirection == screenDirection and not isScreenDirectionDown(screenDirection) then
        app.activeMoveDirection = nil
    end
end

function Input.mousepressed(sim, app, x, y, button)
    if button ~= 1 then
        return
    end
    for _, hitbox in ipairs((app.ui and app.ui.enemyButtons) or {}) do
        if x >= hitbox.x and x <= hitbox.x + hitbox.w and y >= hitbox.y and y <= hitbox.y + hitbox.h then
            if app.pendingSkillKey and app.pendingTargetSide == "enemy" then
                sim:queue(Simulation.commands.combatSkill(app.pendingSkillKey, hitbox.rank, "enemy"))
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
    if app.worldView and sim.mode == "expedition" then
        local wx, wy = require("src.app.render").screenToWorld(app.worldView, x, y)
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

return Input
