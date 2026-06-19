local Simulation = require("src.game.simulation")
local Grid = require("src.core.grid")
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
for _, entry in ipairs(movementOrder) do
    movementKeys[entry[1]] = entry[2]
end

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

local screenDirectionIndexes = {
    up = 0,
    right = 1,
    down = 2,
    left = 3,
}

local worldDirections = { "north", "east", "south", "west" }

local function worldDirectionForScreen(app, screenDirection)
    local index = screenDirectionIndexes[screenDirection] or 0
    local rotation = app and app.viewRotation or 0
    return worldDirections[((index + rotation) % 4) + 1]
end

local function movementStatus(sim, direction)
    local x, y = Grid.front(sim.player.x, sim.player.y, direction)
    local z = sim.player.z or 0
    local tile = sim.world:getTile(x, y, z)
    local stairs = tile.id == "stairs_down" or tile.id == "stairs_up"
    if sim:isWalkable(x, y, z) or (not sim:machineAt(x, y, z) and stairs) then
        return "move " .. direction .. " -> " .. x .. "," .. y .. "," .. z
    end
    return "blocked " .. direction .. " @ " .. x .. "," .. y .. "," .. z
end

local function queueMove(sim, app, screenDirection)
    local direction = worldDirectionForScreen(app, screenDirection)
    sim:queue(Simulation.commands.move(direction))
    app.status = movementStatus(sim, direction)
end

local function rotateView(app, delta)
    app.viewRotation = ((app.viewRotation or 0) + delta) % 4
    app.status = "view rotated " .. (app.viewRotation * 90) .. "deg"
end

function Input.update(sim, app, dt)
    app.moveCooldown = math.max(0, (app.moveCooldown or 0) - dt)
    if app.moveCooldown > 0 then
        return
    end
    for _, entry in ipairs(movementOrder) do
        local key, screenDirection = entry[1], entry[2]
        if love.keyboard.isDown(key) then
            queueMove(sim, app, screenDirection)
            app.moveCooldown = 0.12
            return
        end
    end
end

function Input.keypressed(sim, app, key)
    if movementKeys[key] then
        queueMove(sim, app, movementKeys[key])
        return
    end
    if key == "[" then
        rotateView(app, -1)
        Audio.play(app.audio, "tick")
        return
    end
    if key == "]" then
        rotateView(app, 1)
        Audio.play(app.audio, "tick")
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
    for _, clear in ipairs((app.ui and app.ui.hotbarClears) or {}) do
        if clear.enabled and x >= clear.x and x <= clear.x + clear.w and y >= clear.y and y <= clear.y + clear.h then
            sim:queue(Simulation.commands.assignHotbar(clear.index, nil))
            app.status = "cleared hotbar " .. clear.index
            Audio.play(app.audio, "tick")
            return
        end
    end
    for _, slot in ipairs((app.ui and app.ui.hotbarSlots) or {}) do
        if x >= slot.x and x <= slot.x + slot.w and y >= slot.y and y <= slot.y + slot.h then
            if app.selectedInventoryItem then
                sim:queue(Simulation.commands.assignHotbar(slot.index, app.selectedInventoryItem))
                app.status = "assigned hotbar " .. slot.index
            else
                sim:queue(Simulation.commands.selectHotbar(slot.index))
                app.status = "selected hotbar " .. slot.index
            end
            Audio.play(app.audio, "tick")
            return
        end
    end
    for _, cell in ipairs((app.ui and app.ui.inventoryCells) or {}) do
        if x >= cell.x and x <= cell.x + cell.w and y >= cell.y and y <= cell.y + cell.h then
            if cell.count > 0 then
                app.selectedInventoryItem = cell.item
                app.status = "assign " .. cell.item
                Audio.play(app.audio, "tick")
            else
                app.status = "empty " .. cell.item
                Audio.play(app.audio, "invalid")
            end
            return
        end
    end
    if app.worldView then
        local wx
        local wy
        if app.worldView.mode == "iso" then
            local sx = x - app.worldView.centerX
            local sy = y - app.worldView.centerY
            local rx = (sx / app.worldView.halfW + sy / app.worldView.halfH) / 2
            local ry = (sy / app.worldView.halfH - sx / app.worldView.halfW) / 2
            local rotation = (app.worldView.rotation or 0) % 4
            local dx, dy
            if rotation == 1 then
                dx, dy = ry, -rx
            elseif rotation == 2 then
                dx, dy = -rx, -ry
            elseif rotation == 3 then
                dx, dy = -ry, rx
            else
                dx, dy = rx, ry
            end
            wx = math.floor(app.worldView.originX + dx + 0.5)
            wy = math.floor(app.worldView.originY + dy + 0.5)
        else
            wx = math.floor((x - app.worldView.offsetX) / app.worldView.tileSize)
            wy = math.floor((y - app.worldView.offsetY) / app.worldView.tileSize)
        end
        local machine = sim:machineAt(wx, wy, sim.player.z)
        app.selectedMachineId = machine and machine.id or nil
        app.status = machine and ("selected " .. machine.kind) or "cleared selection"
    end
end

return Input
