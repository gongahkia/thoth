local Defs = require("src.game.defs")
local Grid = require("src.core.grid")

local Render = {}

local atlas
local quads = {}
local tileSize = 32

local spriteNames = {
    "grass", "stone", "water", "tree", "stone", "iron_ore", "copper_ore", "coal_ore",
    "floor", "wood", "stone_item", "coal", "iron_ore_item", "iron_plate", "copper_ore_item", "copper_plate",
    "science_pack", "belt", "fast_belt", "inserter", "burner_miner", "furnace", "chest", "workbench",
    "assembler", "lab",
}

local machineColors = {
    workbench = { 165, 116, 64 },
    burner_miner = { 122, 106, 86 },
    belt = { 190, 164, 64 },
    fast_belt = { 222, 194, 72 },
    inserter = { 202, 150, 82 },
    furnace = { 116, 100, 92 },
    chest = { 154, 102, 52 },
    assembler = { 98, 142, 176 },
    lab = { 144, 104, 188 },
}

local stateColors = {
    ready = { 60, 134, 87 },
    need = { 180, 136, 54 },
    locked = { 76, 80, 86 },
    unaffordable = { 126, 66, 66 },
}

local itemNames = {
    iron_ore = "Fe Ore",
    iron_plate = "Fe Plate",
    copper_ore = "Cu Ore",
    copper_plate = "Cu Plate",
    science_pack = "Science",
    workbench = "Bench",
    burner_miner = "Miner",
    fast_belt = "Fast Belt",
}

local itemCodes = {
    iron_ore = "FeO",
    iron_plate = "FeP",
    copper_ore = "CuO",
    copper_plate = "CuP",
    science_pack = "Sci",
    workbench = "Bch",
    burner_miner = "Min",
    inserter = "Ins",
    furnace = "Fur",
    chest = "Box",
    assembler = "Asm",
    fast_belt = "Fst",
}

local function color(rgb, alpha)
    return (rgb[1] or 255) / 255, (rgb[2] or 255) / 255, (rgb[3] or 255) / 255, (alpha or 255) / 255
end

local function itemName(item)
    return itemNames[item] or Defs.item(item).name
end

local function itemCode(item)
    return itemCodes[item] or itemName(item):sub(1, 4)
end

local function itemRole(item)
    local def = Defs.item(item)
    if def.machine then
        return "mach"
    end
    if def.tile then
        return "tile"
    end
    if item == "coal" then
        return "fuel"
    end
    if item:match("_ore$") then
        return "ore"
    end
    if item:match("_plate$") then
        return "part"
    end
    if item == "science_pack" then
        return "sci"
    end
    return "mat"
end

local function drawSprite(name, x, y)
    if atlas and quads[name] then
        love.graphics.draw(atlas, quads[name], x, y, 0, 2, 2)
        return true
    end
    return false
end

function Render.load()
    if love.filesystem.getInfo("assets/sprites/thoth_atlas.png") then
        atlas = love.graphics.newImage("assets/sprites/thoth_atlas.png")
        local width, height = atlas:getDimensions()
        for index, name in ipairs(spriteNames) do
            local zero = index - 1
            local sx = (zero % 8) * 16
            local sy = math.floor(zero / 8) * 16
            if sx + 16 <= width and sy + 16 <= height then
                quads[name] = love.graphics.newQuad(sx, sy, 16, 16, width, height)
            end
        end
    end
end

function Render.drawTile(sim, x, y, screenX, screenY)
    local tile = sim.world:getTile(x, y, 0)
    if drawSprite(tile.id, screenX, screenY) then
        return
    end
    love.graphics.setColor(color(Defs.tile(tile.id).color))
    love.graphics.rectangle("fill", screenX, screenY, tileSize, tileSize)
end

function Render.drawMachine(machine, screenX, screenY)
    if drawSprite(machine.kind, screenX, screenY) then
        if machine.carriedItem then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.circle("fill", screenX + 16, screenY + 16, 4)
        end
        return
    end
    love.graphics.setColor(color(machineColors[machine.kind] or { 190, 190, 190 }))
    love.graphics.rectangle("fill", screenX + 4, screenY + 4, tileSize - 8, tileSize - 8)
end

function Render.drawWorld(sim, app)
    local width, height = love.graphics.getDimensions()
    local px = sim.player.x * tileSize
    local py = sim.player.y * tileSize
    local offsetX = math.floor(width / 2 - px - tileSize / 2)
    local offsetY = math.floor(height / 2 - py - tileSize / 2)
    app.worldView = { offsetX = offsetX, offsetY = offsetY, tileSize = tileSize }
    local radiusX = math.ceil(width / tileSize / 2) + 2
    local radiusY = math.ceil(height / tileSize / 2) + 2
    for y = sim.player.y - radiusY, sim.player.y + radiusY do
        for x = sim.player.x - radiusX, sim.player.x + radiusX do
            Render.drawTile(sim, x, y, offsetX + x * tileSize, offsetY + y * tileSize)
        end
    end
    for _, machine in ipairs(sim.machines) do
        Render.drawMachine(machine, offsetX + machine.x * tileSize, offsetY + machine.y * tileSize)
    end
    local sx = offsetX + sim.player.x * tileSize
    local sy = offsetY + sim.player.y * tileSize
    drawSprite("player", sx, sy)
    love.graphics.setColor(0.1, 0.12, 0.14, 1)
    love.graphics.circle("fill", sx + 16, sy + 16, 11)
    love.graphics.setColor(0.92, 0.84, 0.62, 1)
    love.graphics.circle("fill", sx + 16, sy + 16, 7)
    local fx, fy = Grid.front(sim.player.x, sim.player.y, sim.player.facing)
    love.graphics.setColor(1, 1, 1, 0.2)
    love.graphics.rectangle("fill", offsetX + fx * tileSize, offsetY + fy * tileSize, tileSize, tileSize)
end

local function stacksText(inventory)
    local parts = {}
    for _, stack in ipairs(inventory:stacks()) do
        parts[#parts + 1] = stack.item .. ":" .. stack.count
    end
    return table.concat(parts, "  ")
end

local function inputText(inputs)
    local parts = {}
    for _, item in ipairs(Defs.itemOrder) do
        local count = inputs[item]
        if count then
            parts[#parts + 1] = count .. " " .. Defs.item(item).name
        end
    end
    return table.concat(parts, ", ")
end

local function outputText(output)
    return Defs.item(output.item).name .. " x" .. output.count
end

local function missingText(sim, inputs)
    local parts = {}
    for _, item in ipairs(Defs.itemOrder) do
        local count = inputs[item]
        local have = count and sim:itemCount(item) or 0
        if count and have < count then
            parts[#parts + 1] = Defs.item(item).name .. " " .. have .. "/" .. count
        end
    end
    return table.concat(parts, ", ")
end

local function recipeState(sim, recipeKey)
    local recipe = Defs.recipe(recipeKey)
    if not recipe then
        return "locked", "missing recipe"
    end
    if not sim:isRecipeUnlocked(recipeKey) then
        return "locked", "research required"
    end
    if recipe.station == "workbench" and not sim:hasAdjacentWorkbench() then
        return "need", "need adjacent workbench"
    end
    if recipe.station ~= "hand" and recipe.station ~= "workbench" then
        return "need", "made in " .. recipe.station
    end
    local missing = missingText(sim, recipe.inputs)
    if missing ~= "" then
        return "unaffordable", missing
    end
    return "ready", inputText(recipe.inputs)
end

local function targetMachine(sim, app)
    if app.selectedMachineId then
        local selected = sim:machineById(app.selectedMachineId)
        if selected then
            return selected, "clicked"
        end
        app.selectedMachineId = nil
    end
    local x, y = Grid.front(sim.player.x, sim.player.y, sim.player.facing)
    return sim:machineAt(x, y, sim.player.z), "faced"
end

local function addButton(app, x, y, w, h, label, payload, enabled)
    love.graphics.setColor(enabled and 0.22 or 0.12, enabled and 0.28 or 0.12, enabled and 0.24 or 0.12, 1)
    love.graphics.rectangle("fill", x, y, w, h)
    love.graphics.setColor(enabled and 0.78 or 0.32, enabled and 0.9 or 0.34, enabled and 0.78 or 0.34, 1)
    love.graphics.rectangle("line", x, y, w, h)
    love.graphics.setColor(enabled and 0.94 or 0.46, enabled and 0.96 or 0.46, enabled and 0.9 or 0.46, 1)
    love.graphics.print(label, x + 6, y + 5)
    if enabled then
        payload.x = x
        payload.y = y
        payload.w = w
        payload.h = h
        app.ui.machineButtons[#app.ui.machineButtons + 1] = payload
    end
end

local function machineRecipe(machine)
    if machine.kind == "furnace" or machine.kind == "assembler" then
        return Defs.machineRecipe(machine.kind, machine.recipeKey)
    end
    return nil
end

local function machineIoText(machine)
    local recipe = machineRecipe(machine)
    if recipe then
        return inputText(recipe.inputs), outputText(recipe.output)
    end
    if machine.kind == "burner_miner" then
        return "Coal", "ore from tile"
    end
    if machine.kind == "lab" then
        return "Science Pack", "research"
    end
    if machine.kind == "belt" or machine.kind == "fast_belt" then
        return "back side", machine.carriedItem or "front side"
    end
    if machine.kind == "inserter" then
        return "back cell", "front cell"
    end
    if machine.kind == "chest" then
        return "any item", "stored item"
    end
    return "-", "-"
end

local function drawMachinePanel(sim, app)
    app.ui.machineButtons = {}
    local machine, source = targetMachine(sim, app)
    local x = 16
    local y = 132
    local w = 328
    love.graphics.setColor(0.06, 0.07, 0.08, 0.86)
    love.graphics.rectangle("fill", x, y, w, 356)
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print("Machine", x + 10, y + 8)
    if not machine then
        love.graphics.setColor(0.66, 0.68, 0.62, 1)
        love.graphics.print("Face or click a machine", x + 10, y + 32)
        return
    end

    local machineDef = Defs.machine(machine.kind)
    local input, output = machineIoText(machine)
    love.graphics.setColor(0.96, 0.96, 0.9, 1)
    love.graphics.print(machineDef.name .. " #" .. machine.id .. "  " .. source, x + 10, y + 32)
    love.graphics.setColor(0.78, 0.82, 0.76, 1)
    love.graphics.print("status " .. machine.status .. "  dir " .. machine.direction, x + 10, y + 52)
    love.graphics.print("progress " .. machine.progress .. "  fuel " .. machine.fuel, x + 10, y + 72)
    love.graphics.print("input " .. input, x + 10, y + 92)
    love.graphics.print("output " .. output, x + 10, y + 112)
    love.graphics.print("inv " .. (stacksText(machine.inventory) ~= "" and stacksText(machine.inventory) or "-"), x + 10, y + 132)
    if machine.carriedItem then
        love.graphics.print("carried " .. machine.carriedItem, x + 10, y + 152)
    end

    local buttonY = y + 176
    local recipeOrder = Defs.machineRecipeOrder[machine.kind]
    if recipeOrder then
        love.graphics.setColor(0.9, 0.92, 0.86, 1)
        love.graphics.print("Recipe", x + 10, buttonY)
        local buttonX = x + 10
        for _, recipeKey in ipairs(recipeOrder) do
            local recipe = Defs.machineRecipe(machine.kind, recipeKey)
            local label = recipe.name or recipeKey
            local active = machine.recipeKey == recipeKey
            addButton(app, buttonX, buttonY + 20, 118, 24, label, {
                action = "set_recipe",
                machineId = machine.id,
                recipeKey = recipeKey,
            }, not active)
            buttonX = buttonX + 124
        end
        buttonY = buttonY + 54
    end

    local selected = sim:selectedItem()
    local selectedCount = selected and sim:itemCount(selected) or 0
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print("Deposit " .. (selected or "-") .. " " .. selectedCount, x + 10, buttonY)
    local canDeposit = selected ~= nil and selectedCount > 0
    addButton(app, x + 10, buttonY + 20, 50, 24, "1", { action = "deposit", machineId = machine.id, item = selected, count = 1 }, canDeposit)
    addButton(app, x + 66, buttonY + 20, 50, 24, "5", { action = "deposit", machineId = machine.id, item = selected, count = 5 }, canDeposit)
    addButton(app, x + 122, buttonY + 20, 58, 24, "all", { action = "deposit", machineId = machine.id, item = selected, count = "all" }, canDeposit)

    local withdrawY = buttonY + 56
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print("Withdraw", x + 10, withdrawY)
    for index, stack in ipairs(machine.inventory:stacks()) do
        if index > 3 then
            love.graphics.print("+" .. (#machine.inventory:stacks() - 3) .. " more", x + 10, withdrawY + 22 + (index - 1) * 28)
            break
        end
        local rowY = withdrawY + 22 + (index - 1) * 28
        love.graphics.print(stack.item .. " " .. stack.count, x + 10, rowY + 4)
        addButton(app, x + 128, rowY, 42, 24, "1", { action = "withdraw", machineId = machine.id, item = stack.item, count = 1 }, true)
        addButton(app, x + 176, rowY, 42, 24, "5", { action = "withdraw", machineId = machine.id, item = stack.item, count = 5 }, true)
        addButton(app, x + 224, rowY, 54, 24, "all", { action = "withdraw", machineId = machine.id, item = stack.item, count = "all" }, true)
    end
end

local function drawRecipeCards(sim, app)
    app.ui.recipeCards = {}
    local panelX = love.graphics.getWidth() - 284
    local panelY = 132
    local cardW = 268
    local cardH = 48
    love.graphics.setColor(0.06, 0.07, 0.08, 0.82)
    love.graphics.rectangle("fill", panelX - 8, panelY - 32, cardW + 16, 600)
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print("Build", panelX, panelY - 24)
    for index, recipeKey in ipairs(Defs.recipeOrder) do
        local recipe = Defs.recipe(recipeKey)
        local y = panelY + (index - 1) * (cardH + 7)
        local state, detail = recipeState(sim, recipeKey)
        local rgb = stateColors[state] or stateColors.locked
        love.graphics.setColor(color(rgb, app.selectedRecipe == recipeKey and 245 or 205))
        love.graphics.rectangle("fill", panelX, y, cardW, cardH)
        love.graphics.setColor(app.selectedRecipe == recipeKey and 1 or 0.2, 0.2, 0.2, 1)
        love.graphics.rectangle("line", panelX, y, cardW, cardH)
        love.graphics.setColor(0.96, 0.96, 0.9, 1)
        love.graphics.print(Defs.item(recipe.output.item).name .. " x" .. recipe.output.count, panelX + 8, y + 6)
        love.graphics.setColor(0.86, 0.88, 0.82, 1)
        love.graphics.print(state .. "  " .. detail, panelX + 8, y + 25)
        app.ui.recipeCards[#app.ui.recipeCards + 1] = {
            x = panelX,
            y = y,
            w = cardW,
            h = cardH,
            recipeKey = recipeKey,
            state = state,
        }
    end
end

local function drawInventoryPanel(sim, app)
    app.ui.inventoryCells = {}
    app.ui.hotbarSlots = {}
    app.ui.hotbarClears = {}
    local panelW = 536
    local panelH = 210
    local panelX = math.floor((love.graphics.getWidth() - panelW) / 2)
    local panelY = love.graphics.getHeight() - panelH - 12
    local cellW = 84
    local cellH = 38
    love.graphics.setColor(0.06, 0.07, 0.08, 0.86)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH)
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print("Inventory", panelX + 10, panelY + 8)
    if app.selectedInventoryItem then
        love.graphics.print("assign " .. itemName(app.selectedInventoryItem), panelX + 110, panelY + 8)
    end
    for index, item in ipairs(Defs.itemOrder) do
        local col = (index - 1) % 6
        local row = math.floor((index - 1) / 6)
        local x = panelX + 10 + col * (cellW + 4)
        local y = panelY + 30 + row * (cellH + 4)
        local count = sim:itemCount(item)
        local active = app.selectedInventoryItem == item
        love.graphics.setColor(count > 0 and 0.16 or 0.09, active and 0.28 or 0.17, count > 0 and 0.18 or 0.09, 1)
        love.graphics.rectangle("fill", x, y, cellW, cellH)
        love.graphics.setColor(active and 0.92 or 0.32, active and 0.96 or 0.38, active and 0.82 or 0.34, 1)
        love.graphics.rectangle("line", x, y, cellW, cellH)
        love.graphics.setColor(count > 0 and 0.94 or 0.44, count > 0 and 0.96 or 0.44, count > 0 and 0.9 or 0.44, 1)
        love.graphics.print(itemName(item), x + 4, y + 3)
        love.graphics.print(itemRole(item) .. " " .. count, x + 4, y + 20)
        app.ui.inventoryCells[#app.ui.inventoryCells + 1] = { x = x, y = y, w = cellW, h = cellH, item = item, count = count }
    end

    local hotbarY = panelY + 164
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print("Hotbar", panelX + 10, hotbarY - 18)
    for i = 1, 10 do
        local x = panelX + 10 + (i - 1) * 51
        local item = sim.player.hotbar[i]
        local active = i == sim.player.selectedHotbar
        love.graphics.setColor(active and 0.24 or 0.12, active and 0.32 or 0.16, active and 0.22 or 0.14, 1)
        love.graphics.rectangle("fill", x, hotbarY, 46, 34)
        love.graphics.setColor(active and 0.95 or 0.35, active and 0.82 or 0.44, active and 0.32 or 0.28, 1)
        love.graphics.rectangle("line", x, hotbarY, 46, 34)
        love.graphics.setColor(0.94, 0.96, 0.9, 1)
        love.graphics.print(item and itemCode(item) or "-", x + 5, hotbarY + 10)
        love.graphics.setColor(0.42, 0.16, 0.16, item and 1 or 0.35)
        love.graphics.rectangle("fill", x + 32, hotbarY + 2, 12, 12)
        love.graphics.setColor(0.96, 0.84, 0.78, item and 1 or 0.35)
        love.graphics.print("x", x + 35, hotbarY + 1)
        app.ui.hotbarSlots[#app.ui.hotbarSlots + 1] = { x = x, y = hotbarY, w = 46, h = 34, index = i }
        app.ui.hotbarClears[#app.ui.hotbarClears + 1] = { x = x + 32, y = hotbarY + 2, w = 12, h = 12, index = i, enabled = item ~= nil }
    end
end

local function checklistText(group)
    local parts = { group.title }
    for _, item in ipairs(group.items) do
        local mark = item.blocked and "[-]" or item.done and "[x]" or "[ ]"
        parts[#parts + 1] = mark .. item.label
    end
    return table.concat(parts, " ")
end

function Render.drawHud(sim, app)
    love.graphics.setColor(0.06, 0.07, 0.08, 0.86)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), 124)
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print("Thoth  tick " .. sim.tick, 16, 10)
    love.graphics.print("next " .. sim:nextStepText(), 16, 30)
    love.graphics.print("status " .. tostring(app.status), 16, 50)
    local checklist = sim:objectiveChecklist()
    love.graphics.print(checklistText(checklist[1]), 16, 76)
    love.graphics.print(checklistText(checklist[2]), 16, 96)
    love.graphics.print(checklistText(checklist[4]), 500, 76)
    love.graphics.print(checklistText(checklist[3]), 500, 96)
    love.graphics.print(checklistText(checklist[5]), 820, 96)
end

function Render.draw(sim, app)
    love.graphics.clear(0.07, 0.08, 0.08, 1)
    app.ui = {}
    Render.drawWorld(sim, app)
    Render.drawHud(sim, app)
    drawMachinePanel(sim, app)
    drawInventoryPanel(sim, app)
    drawRecipeCards(sim, app)
end

return Render
