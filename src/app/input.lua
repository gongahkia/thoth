local Simulation = require("src.game.simulation")
local Grid = require("src.core.grid")
local Audio = require("src.app.audio")

local Input = {}

local movementKeys = {
    w = "north",
    up = "north",
    d = "east",
    right = "east",
    s = "south",
    down = "south",
    a = "west",
    left = "west",
}

local craftKeys = {
    k = "workbench",
    f = "furnace",
    c = "chest",
    b = "belt",
    i = "inserter",
    m = "burner_miner",
    x = "assembler",
    l = "lab",
    t = "fast_belt",
}

function Input.update(sim, app, dt)
    app.moveCooldown = math.max(0, (app.moveCooldown or 0) - dt)
    if app.moveCooldown > 0 then
        return
    end
    for key, direction in pairs(movementKeys) do
        if love.keyboard.isDown(key) then
            sim:queue(Simulation.commands.move(direction))
            app.moveCooldown = 0.12
            return
        end
    end
end

function Input.keypressed(sim, app, key)
    if movementKeys[key] then
        sim:queue(Simulation.commands.move(movementKeys[key]))
        return
    end
    if key == "space" then
        sim:queue(Simulation.commands.mine(sim.player.facing))
        app.status = "mined"
        Audio.play(app.audio, "mine")
        return
    end
    if key == "p" then
        local item = sim:selectedItem()
        sim:queue(Simulation.commands.place(sim.player.facing, item, app.buildDirection))
        app.status = item and ("placed " .. item) or "nothing selected"
        Audio.play(app.audio, item and "place" or "invalid")
        return
    end
    if key == "r" then
        app.buildDirection = Grid.rotate(app.buildDirection)
        app.status = "build " .. app.buildDirection
        Audio.play(app.audio, "tick")
        return
    end
    if key == "e" then
        sim:queue(Simulation.commands.deposit(sim.player.facing, sim:selectedItem()))
        app.status = "deposit"
        Audio.play(app.audio, "place")
        return
    end
    if key == "backspace" then
        app.paused = not app.paused
        app.status = app.paused and "paused" or "running"
        Audio.play(app.audio, "tick")
        return
    end
    if key == "return" then
        app.paused = true
        sim:step()
        app.status = "stepped"
        Audio.play(app.audio, "tick")
        return
    end
    if key:match("^%d$") then
        local index = tonumber(key)
        if index == 0 then
            index = 10
        end
        sim:queue(Simulation.commands.selectHotbar(index))
        return
    end
    if craftKeys[key] then
        sim:queue(Simulation.commands.craft(craftKeys[key]))
        app.status = "crafted " .. craftKeys[key]
        Audio.play(app.audio, "craft")
    end
end

function Input.mousepressed(sim, app, x, y, button)
    if button ~= 1 then
        return
    end
    for _, action in ipairs((app.ui and app.ui.machineButtons) or {}) do
        if x >= action.x and x <= action.x + action.w and y >= action.y and y <= action.y + action.h then
            if action.action == "set_recipe" then
                sim:queue(Simulation.commands.setMachineRecipe(action.machineId, action.recipeKey))
                app.status = "recipe " .. action.recipeKey
                Audio.play(app.audio, "tick")
            elseif action.action == "deposit" then
                sim:queue(Simulation.commands.depositMachine(action.machineId, action.item, action.count))
                app.status = "deposit " .. tostring(action.count)
                Audio.play(app.audio, "place")
            elseif action.action == "withdraw" then
                sim:queue(Simulation.commands.withdrawMachine(action.machineId, action.item, action.count))
                app.status = "withdraw " .. tostring(action.count)
                Audio.play(app.audio, "place")
            end
            return
        end
    end
    for _, card in ipairs((app.ui and app.ui.recipeCards) or {}) do
        if x >= card.x and x <= card.x + card.w and y >= card.y and y <= card.y + card.h then
            app.selectedRecipe = card.recipeKey
            if card.state == "ready" then
                sim:queue(Simulation.commands.craft(card.recipeKey))
                app.status = "crafted " .. card.recipeKey
                Audio.play(app.audio, "craft")
            else
                app.status = card.state .. " " .. card.recipeKey
                Audio.play(app.audio, "invalid")
            end
            return
        end
    end
    if app.worldView then
        local wx = math.floor((x - app.worldView.offsetX) / app.worldView.tileSize)
        local wy = math.floor((y - app.worldView.offsetY) / app.worldView.tileSize)
        local machine = sim:machineAt(wx, wy, sim.player.z)
        app.selectedMachineId = machine and machine.id or nil
        app.status = machine and ("selected " .. machine.kind) or "cleared selection"
    end
end

return Input
