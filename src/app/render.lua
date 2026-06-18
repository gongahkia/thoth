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
    splitter = { 214, 178, 74 },
    circuit_inserter = { 94, 172, 136 },
    provider_chest = { 86, 152, 106 },
    requester_chest = { 92, 132, 190 },
    logistic_port = { 106, 168, 190 },
    train_stop = { 154, 142, 116 },
    pipe = { 78, 150, 176 },
    offshore_pump = { 64, 124, 168 },
    generator = { 176, 126, 66 },
    power_pole = { 160, 136, 92 },
    electric_miner = { 92, 156, 156 },
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

local function panel(x, y, w, h, alpha)
    love.graphics.setColor(0.06, 0.07, 0.08, alpha or 0.82)
    love.graphics.rectangle("fill", x, y, w, h)
end

local function itemName(item)
    return itemNames[item] or Defs.item(item).name
end

local function itemCode(item)
    return itemCodes[item] or itemName(item):sub(1, 4)
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

function Render.drawTile(sim, x, y, z, screenX, screenY)
    local tile = sim.world:getTile(x, y, z or 0)
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
            Render.drawTile(sim, x, y, sim.player.z, offsetX + x * tileSize, offsetY + y * tileSize)
        end
    end
    for _, machine in ipairs(sim.machines) do
        if (machine.z or 0) == sim.player.z then
            Render.drawMachine(machine, offsetX + machine.x * tileSize, offsetY + machine.y * tileSize)
        end
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
    if machine.kind == "chest" or machine.kind == "provider_chest" or machine.kind == "requester_chest" then
        return "any item", "stored item"
    end
    if machine.kind == "logistic_port" then
        return "Logistic Drone", "delivery capacity"
    end
    if machine.kind == "train_stop" then
        return "any item", "freight storage"
    end
    if machine.kind == "pipe" then
        return "Water Barrel", machine.carriedItem or "front pipe"
    end
    if machine.kind == "offshore_pump" then
        return "adjacent water", "Water Barrel"
    end
    if machine.kind == "generator" then
        return "Coal", "power"
    end
    if machine.kind == "power_pole" then
        return "near power", "network link"
    end
    if machine.kind == "electric_miner" then
        return "power + ore tile", "ore"
    end
    return "-", "-"
end

local function drawMachinePanel(sim, app)
    app.ui.machineButtons = {}
    local machine, source = targetMachine(sim, app)
    if not machine then
        return
    end

    local x = 16
    local y = 88
    local w = 304
    panel(x, y, w, 342, 0.84)
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print("Machine", x + 10, y + 8)

    local machineDef = Defs.machine(machine.kind)
    local input, output = machineIoText(machine)
    love.graphics.setColor(0.96, 0.96, 0.9, 1)
    love.graphics.print(machineDef.name .. " #" .. machine.id .. "  " .. source, x + 10, y + 32)
    love.graphics.setColor(0.78, 0.82, 0.76, 1)
    love.graphics.print("status " .. machine.status .. "  dir " .. machine.direction, x + 10, y + 52)
    love.graphics.print("progress " .. machine.progress .. "  fuel " .. machine.fuel, x + 10, y + 72)
    love.graphics.print("input " .. input, x + 10, y + 92)
    love.graphics.print("output " .. output, x + 10, y + 112)
    local stacks = stacksText(machine.inventory)
    love.graphics.printf("inv " .. (stacks ~= "" and stacks or "-"), x + 10, y + 132, w - 20)
    local detailY = y + 152
    if machine.carriedItem then
        love.graphics.print("carried " .. machine.carriedItem, x + 10, detailY)
        detailY = detailY + 18
    end
    if machine.kind == "circuit_inserter" then
        love.graphics.print("circuit " .. (machine.filterItem or "-") .. " " .. machine.circuitComparator .. " " .. machine.circuitThreshold, x + 10, detailY)
        detailY = detailY + 18
    end
    if machine.kind == "requester_chest" then
        love.graphics.print("request " .. (machine.requestItem or "-") .. " < " .. machine.requestThreshold, x + 10, detailY)
    end

    local buttonY = math.max(y + 176, detailY + 22)
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
    local width, height = love.graphics.getDimensions()
    local panelW = 292
    local panelX = width - panelW - 12
    local panelY = 88
    local panelH = height - panelY - 16
    local cardW = panelW - 20
    local cardH = 40
    local gap = 6
    panel(panelX, panelY, panelW, panelH, 0.84)
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print("Build", panelX + 10, panelY + 8)
    for index, recipeKey in ipairs(Defs.buildRecipeOrder or Defs.recipeOrder) do
        local recipe = Defs.recipe(recipeKey)
        local y = panelY + 32 + (index - 1) * (cardH + gap)
        if y + cardH > panelY + panelH - 10 then
            break
        end
        local state, detail = recipeState(sim, recipeKey)
        local rgb = stateColors[state] or stateColors.locked
        love.graphics.setColor(color(rgb, app.selectedRecipe == recipeKey and 245 or 205))
        love.graphics.rectangle("fill", panelX + 10, y, cardW, cardH)
        love.graphics.setColor(app.selectedRecipe == recipeKey and 1 or 0.2, 0.2, 0.2, 1)
        love.graphics.rectangle("line", panelX + 10, y, cardW, cardH)
        love.graphics.setColor(0.96, 0.96, 0.9, 1)
        love.graphics.print(Defs.item(recipe.output.item).name .. " x" .. recipe.output.count, panelX + 18, y + 4)
        love.graphics.setColor(0.86, 0.88, 0.82, 1)
        love.graphics.printf(state .. "  " .. detail, panelX + 18, y + 21, cardW - 16)
        app.ui.recipeCards[#app.ui.recipeCards + 1] = {
            x = panelX + 10,
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
    local width, height = love.graphics.getDimensions()
    local visibleItems = {}
    for _, item in ipairs(Defs.inventoryPanelOrder or Defs.itemOrder) do
        if sim:itemCount(item) > 0 or app.selectedInventoryItem == item then
            visibleItems[#visibleItems + 1] = item
        end
    end
    local hasInventory = #visibleItems > 0
    local rightDockW = 316
    local panelW = math.min(820, math.max(560, width - rightDockW - 36))
    local panelH = hasInventory and 118 or 72
    local panelX = 16
    local panelY = height - panelH - 12
    local cellW = 76
    local cellH = 30
    panel(panelX, panelY, panelW, panelH, 0.84)
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print("Inventory", panelX + 10, panelY + 8)
    if app.selectedInventoryItem then
        love.graphics.print("assign " .. itemName(app.selectedInventoryItem), panelX + 110, panelY + 8)
    elseif not hasInventory then
        love.graphics.setColor(0.62, 0.66, 0.58, 1)
        love.graphics.print("empty", panelX + 110, panelY + 8)
    end
    if hasInventory then
        for index, item in ipairs(visibleItems) do
            local x = panelX + 10 + (index - 1) * (cellW + 4)
            if x + cellW > panelX + panelW - 10 then
                break
            end
            local y = panelY + 30
            local count = sim:itemCount(item)
            local active = app.selectedInventoryItem == item
            love.graphics.setColor(count > 0 and 0.16 or 0.09, active and 0.28 or 0.17, count > 0 and 0.18 or 0.09, 1)
            love.graphics.rectangle("fill", x, y, cellW, cellH)
            love.graphics.setColor(active and 0.92 or 0.32, active and 0.96 or 0.38, active and 0.82 or 0.34, 1)
            love.graphics.rectangle("line", x, y, cellW, cellH)
            love.graphics.setColor(count > 0 and 0.94 or 0.44, count > 0 and 0.96 or 0.44, count > 0 and 0.9 or 0.44, 1)
            love.graphics.print(itemCode(item), x + 4, y + 3)
            love.graphics.print(count, x + 4, y + 17)
            app.ui.inventoryCells[#app.ui.inventoryCells + 1] = { x = x, y = y, w = cellW, h = cellH, item = item, count = count }
        end
    end

    local hotbarY = panelY + (hasInventory and 72 or 30)
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print("Hotbar", panelX + 10, hotbarY - 18)
    for i = 1, 10 do
        local x = panelX + 10 + (i - 1) * 50
        local item = sim.player.hotbar[i]
        local active = i == sim.player.selectedHotbar
        love.graphics.setColor(active and 0.24 or 0.12, active and 0.32 or 0.16, active and 0.22 or 0.14, 1)
        love.graphics.rectangle("fill", x, hotbarY, 44, 30)
        love.graphics.setColor(active and 0.95 or 0.35, active and 0.82 or 0.44, active and 0.32 or 0.28, 1)
        love.graphics.rectangle("line", x, hotbarY, 44, 30)
        love.graphics.setColor(0.94, 0.96, 0.9, 1)
        love.graphics.print(item and itemCode(item) or "-", x + 5, hotbarY + 8)
        love.graphics.setColor(0.42, 0.16, 0.16, item and 1 or 0.35)
        love.graphics.rectangle("fill", x + 30, hotbarY + 2, 12, 12)
        love.graphics.setColor(0.96, 0.84, 0.78, item and 1 or 0.35)
        love.graphics.print("x", x + 33, hotbarY + 1)
        app.ui.hotbarSlots[#app.ui.hotbarSlots + 1] = { x = x, y = hotbarY, w = 44, h = 30, index = i }
        app.ui.hotbarClears[#app.ui.hotbarClears + 1] = { x = x + 30, y = hotbarY + 2, w = 12, h = 12, index = i, enabled = item ~= nil }
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

local function activeChecklist(checklist)
    for _, group in ipairs(checklist) do
        for _, item in ipairs(group.items) do
            if not item.done and not item.blocked then
                return group
            end
        end
    end
    return checklist[1]
end

local function drawTutorialPanel(sim)
    local state = sim:tutorialState()
    if not state.active then
        return
    end
    local x = 16
    local y = 88
    local w = 304
    panel(x, y, w, 126, 0.84)
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print("Tutorial", x + 10, y + 8)
    for index, step in ipairs(sim:tutorialProgress()) do
        love.graphics.setColor(step.complete and 0.72 or 0.86, step.complete and 0.92 or 0.72, step.complete and 0.62 or 0.42, 1)
        love.graphics.print((step.complete and "[x]" or "[ ]") .. step.label, x + 10, y + 8 + index * 20)
    end
end

function Render.drawHud(sim, app)
    local width = love.graphics.getWidth()
    panel(0, 0, width, 76, 0.86)
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print("Thoth  tick " .. sim.tick, 16, 10)
    love.graphics.printf("status " .. tostring(app.status), width - 276, 10, 260, "right")
    love.graphics.printf("next " .. sim:nextStepText(), 16, 30, width - 320)
    local checklist = sim:objectiveChecklist()
    love.graphics.printf(checklistText(activeChecklist(checklist)), 16, 54, width - 32)
    local progress = sim:achievementProgress()
    love.graphics.printf("ach " .. sim:unlockedAchievementCount() .. "/" .. #progress, width - 276, 54, 260, "right")
end

function Render.draw(sim, app)
    love.graphics.clear(0.07, 0.08, 0.08, 1)
    app.ui = {}
    Render.drawWorld(sim, app)
    Render.drawHud(sim, app)
    drawTutorialPanel(sim)
    drawMachinePanel(sim, app)
    drawInventoryPanel(sim, app)
    drawRecipeCards(sim, app)
end

return Render
