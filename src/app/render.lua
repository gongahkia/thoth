local Defs = require("src.game.defs")
local Grid = require("src.core.grid")
local World = require("src.game.world")

local Render = {}

local atlas
local quads = {}
local tileSize = 32
local isoTileW = 64
local isoTileH = 32
local isoBlockH = 18
local renderChunkTileSize = 16
local isoTerrainCache = { world = nil, chunks = {}, supported = nil }
local isoTileOrders = {}
local buildCardDefs = {}

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

local function shaded(rgb, amount, alpha)
    return math.min(1, ((rgb[1] or 255) * amount) / 255),
        math.min(1, ((rgb[2] or 255) * amount) / 255),
        math.min(1, ((rgb[3] or 255) * amount) / 255),
        alpha or 1
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

local function rebuildBuildCardDefs()
    buildCardDefs = {}
    for _, recipeKey in ipairs(Defs.buildRecipeOrder or Defs.recipeOrder) do
        local recipe = Defs.recipe(recipeKey)
        buildCardDefs[#buildCardDefs + 1] = {
            recipeKey = recipeKey,
            label = Defs.item(recipe.output.item).name .. " x" .. recipe.output.count,
        }
    end
end

local function clearList(list)
    for i = #list, 1, -1 do
        list[i] = nil
    end
end

function Render.prepareUi(app)
    app.ui = app.ui or {}
    app.ui.machineButtons = app.ui.machineButtons or {}
    app.ui.recipeCards = app.ui.recipeCards or {}
    app.ui.inventoryCells = app.ui.inventoryCells or {}
    app.ui.hotbarSlots = app.ui.hotbarSlots or {}
    app.ui.hotbarClears = app.ui.hotbarClears or {}
    clearList(app.ui.machineButtons)
    clearList(app.ui.recipeCards)
    clearList(app.ui.inventoryCells)
    clearList(app.ui.hotbarSlots)
    clearList(app.ui.hotbarClears)
end

function Render.rotateDelta(dx, dy, rotation)
    rotation = (rotation or 0) % 4
    if rotation == 1 then
        return -dy, dx
    end
    if rotation == 2 then
        return -dx, -dy
    end
    if rotation == 3 then
        return dy, -dx
    end
    return dx, dy
end

function Render.unrotateDelta(rx, ry, rotation)
    rotation = (rotation or 0) % 4
    if rotation == 1 then
        return ry, -rx
    end
    if rotation == 2 then
        return -rx, -ry
    end
    if rotation == 3 then
        return -ry, rx
    end
    return rx, ry
end

function Render.projectIso(view, x, y)
    local rx, ry = Render.rotateDelta(x - view.originX, y - view.originY, view.rotation)
    return view.centerX + (rx - ry) * view.halfW, view.centerY + (rx + ry) * view.halfH
end

function Render.screenToWorld(view, x, y)
    local sx = x - view.centerX
    local sy = y - view.centerY
    local rx = (sx / view.halfW + sy / view.halfH) / 2
    local ry = (sy / view.halfH - sx / view.halfW) / 2
    local dx, dy = Render.unrotateDelta(rx, ry, view.rotation)
    return math.floor(view.originX + dx + 0.5), math.floor(view.originY + dy + 0.5)
end

local function drawSprite(name, x, y)
    if atlas and quads[name] then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(atlas, quads[name], x, y, 0, 2, 2)
        return true
    end
    return false
end

function Render.load()
    isoTerrainCache.world = nil
    isoTerrainCache.chunks = {}
    isoTileOrders = {}
    rebuildBuildCardDefs()
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
    local tile = sim.world:peekTile(x, y, z or 0)
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

local function drawIsoDiamond(cx, cy, rgb, alpha)
    local halfW = isoTileW / 2
    local halfH = isoTileH / 2
    love.graphics.setColor(color(rgb, alpha or 255))
    love.graphics.polygon("fill", cx, cy - halfH, cx + halfW, cy, cx, cy + halfH, cx - halfW, cy)
    love.graphics.setColor(0, 0, 0, 0.18)
    love.graphics.polygon("line", cx, cy - halfH, cx + halfW, cy, cx, cy + halfH, cx - halfW, cy)
end

local function drawIsoBlock(cx, cy, rgb, height)
    local halfW = isoTileW / 2
    local halfH = isoTileH / 2
    local topY = cy - height
    love.graphics.setColor(shaded(rgb, 0.54, 1))
    love.graphics.polygon("fill", cx - halfW, topY, cx, topY + halfH, cx, cy + halfH, cx - halfW, cy)
    love.graphics.setColor(shaded(rgb, 0.42, 1))
    love.graphics.polygon("fill", cx + halfW, topY, cx, topY + halfH, cx, cy + halfH, cx + halfW, cy)
    love.graphics.setColor(shaded(rgb, 0.9, 1))
    love.graphics.polygon("fill", cx, topY - halfH, cx + halfW, topY, cx, topY + halfH, cx - halfW, topY)
    love.graphics.setColor(0, 0, 0, 0.22)
    love.graphics.polygon("line", cx, topY - halfH, cx + halfW, topY, cx, topY + halfH, cx - halfW, topY)
end

local function drawIsoTile(world, x, y, z, screenX, screenY)
    local tile = world:peekTile(x, y, z or 0)
    local tileDef = Defs.tile(tile.id)
    drawIsoDiamond(screenX, screenY, tileDef.color)
    if tile.id == "tree" then
        love.graphics.setColor(0.33, 0.2, 0.12, 1)
        love.graphics.rectangle("fill", screenX - 4, screenY - 24, 8, 18)
        love.graphics.setColor(0.16, 0.38, 0.18, 1)
        love.graphics.circle("fill", screenX, screenY - 34, 17)
        love.graphics.setColor(0.08, 0.18, 0.08, 0.7)
        love.graphics.circle("line", screenX, screenY - 34, 17)
    elseif tileDef.resource then
        drawIsoDiamond(screenX, screenY - 7, { 126, 120, 138 }, 220)
    elseif tile.id == "stairs_down" or tile.id == "stairs_up" then
        drawIsoDiamond(screenX, screenY - 5, { 44, 38, 34 }, 230)
    end
end

local function canUseIsoTerrainCanvas()
    if isoTerrainCache.supported == nil then
        isoTerrainCache.supported = pcall(love.graphics.newCanvas, 1, 1)
    end
    return isoTerrainCache.supported
end

local function isoTerrainCacheKey(cx, cy, z, rotation)
    return tostring(z or 0) .. ":" .. tostring(rotation or 0) .. ":" .. cx .. ":" .. cy
end

local function isoTerrainRevision(world, cx, cy, z)
    local worldCx = World.floorDiv(cx * renderChunkTileSize, World.chunkSize)
    local worldCy = World.floorDiv(cy * renderChunkTileSize, World.chunkSize)
    return world:chunkRevision(worldCx, worldCy, z or 0)
end

local function isoTileOrder(rotation)
    rotation = (rotation or 0) % 4
    if not isoTileOrders[rotation] then
        local tiles = {}
        for localY = 0, renderChunkTileSize - 1 do
            for localX = 0, renderChunkTileSize - 1 do
                local rx, ry = Render.rotateDelta(localX, localY, rotation)
                tiles[#tiles + 1] = { x = localX, y = localY, rx = rx, ry = ry }
            end
        end
        table.sort(tiles, function(a, b)
            local ad = a.rx + a.ry
            local bd = b.rx + b.ry
            if ad == bd then
                return a.rx < b.rx
            end
            return ad < bd
        end)
        isoTileOrders[rotation] = tiles
    end
    return isoTileOrders[rotation]
end

local function buildIsoTerrainChunk(world, cx, cy, z, rotation)
    local halfW = isoTileW / 2
    local halfH = isoTileH / 2
    local topPad = 60
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    for localY = 0, renderChunkTileSize - 1 do
        for localX = 0, renderChunkTileSize - 1 do
            local rx, ry = Render.rotateDelta(localX, localY, rotation)
            local sx = (rx - ry) * halfW
            local sy = (rx + ry) * halfH
            minX = math.min(minX, sx - halfW)
            maxX = math.max(maxX, sx + halfW)
            minY = math.min(minY, sy - halfH - topPad)
            maxY = math.max(maxY, sy + halfH)
        end
    end
    minX = math.floor(minX)
    minY = math.floor(minY)
    local canvas = love.graphics.newCanvas(math.ceil(maxX - minX + 2), math.ceil(maxY - minY + 2))
    love.graphics.push("all")
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)
    for _, tileEntry in ipairs(isoTileOrder(rotation)) do
        local localX = tileEntry.x
        local localY = tileEntry.y
        local worldX = cx * renderChunkTileSize + localX
        local worldY = cy * renderChunkTileSize + localY
        local rx, ry = tileEntry.rx, tileEntry.ry
        drawIsoTile(world, worldX, worldY, z, (rx - ry) * halfW - minX, (rx + ry) * halfH - minY)
    end
    love.graphics.setCanvas()
    love.graphics.pop()
    return { canvas = canvas, offsetX = minX, offsetY = minY }
end

local function isoTerrainChunk(world, cx, cy, z, rotation)
    if isoTerrainCache.world ~= world then
        isoTerrainCache.world = world
        isoTerrainCache.chunks = {}
    end
    rotation = (rotation or 0) % 4
    local key = isoTerrainCacheKey(cx, cy, z, rotation)
    local revision = isoTerrainRevision(world, cx, cy, z)
    local entry = isoTerrainCache.chunks[key]
    if not entry or entry.revision ~= revision then
        if (isoTerrainCache.buildsThisFrame or 0) >= (isoTerrainCache.buildLimit or 1) then
            return key, nil
        end
        isoTerrainCache.buildsThisFrame = (isoTerrainCache.buildsThisFrame or 0) + 1
        local built = buildIsoTerrainChunk(world, cx, cy, z, rotation)
        entry = { canvas = built.canvas, offsetX = built.offsetX, offsetY = built.offsetY, revision = revision }
        isoTerrainCache.chunks[key] = entry
    end
    return key, entry
end

local function drawIsoTerrainChunkLive(world, cx, cy, z, rotation, baseScreenX, baseScreenY)
    local halfW = isoTileW / 2
    local halfH = isoTileH / 2
    for _, tileEntry in ipairs(isoTileOrder(rotation)) do
        local worldX = cx * renderChunkTileSize + tileEntry.x
        local worldY = cy * renderChunkTileSize + tileEntry.y
        drawIsoTile(
            world,
            worldX,
            worldY,
            z,
            baseScreenX + (tileEntry.rx - tileEntry.ry) * halfW,
            baseScreenY + (tileEntry.rx + tileEntry.ry) * halfH)
    end
end

function Render.drawIsoMachine(machine, screenX, screenY)
    drawIsoBlock(screenX, screenY, machineColors[machine.kind] or { 190, 190, 190 }, isoBlockH)
    if machine.carriedItem then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.circle("fill", screenX, screenY - isoBlockH - 8, 4)
    end
end

function Render.drawWorld(sim, app)
    local width, height = love.graphics.getDimensions()
    local rightDockW = 316
    local topHudH = 76
    local bottomTrayH = 128
    local centerX = math.floor((width - rightDockW) / 2)
    local centerY = math.floor((topHudH + height - bottomTrayH) / 2)
    local rotation = (app.viewRotation or 0) % 4
    app.worldView = app.worldView or {}
    app.worldView.mode = "iso"
    app.worldView.centerX = centerX
    app.worldView.centerY = centerY
    app.worldView.halfW = isoTileW / 2
    app.worldView.halfH = isoTileH / 2
    app.worldView.originX = sim.player.x
    app.worldView.originY = sim.player.y
    app.worldView.rotation = rotation
    local radius = math.ceil(width / isoTileW / 2 + height / isoTileH / 2) + 4
    local minX = sim.player.x - radius
    local maxX = sim.player.x + radius
    local minY = sim.player.y - radius
    local maxY = sim.player.y + radius
    if canUseIsoTerrainCanvas() then
        isoTerrainCache.buildsThisFrame = 0
        isoTerrainCache.buildLimit = 1
        local visibleChunkKeys = {}
        local chunks = {}
        local minChunkX = World.floorDiv(minX, renderChunkTileSize)
        local maxChunkX = World.floorDiv(maxX, renderChunkTileSize)
        local minChunkY = World.floorDiv(minY, renderChunkTileSize)
        local maxChunkY = World.floorDiv(maxY, renderChunkTileSize)
        for cy = minChunkY, maxChunkY do
            for cx = minChunkX, maxChunkX do
                local baseX = cx * renderChunkTileSize
                local baseY = cy * renderChunkTileSize
                local screenX, screenY = Render.projectIso(app.worldView, baseX, baseY)
                if screenX >= -renderChunkTileSize * isoTileW and screenX <= width + renderChunkTileSize * isoTileW
                    and screenY >= -renderChunkTileSize * isoTileH and screenY <= height + renderChunkTileSize * isoTileH
                then
                    local key, entry = isoTerrainChunk(sim.world, cx, cy, sim.player.z, rotation)
                    visibleChunkKeys[key] = true
                    chunks[#chunks + 1] = {
                        entry = entry,
                        cx = cx,
                        cy = cy,
                        baseX = screenX,
                        baseY = screenY,
                        x = entry and screenX + entry.offsetX or screenX,
                        y = entry and screenY + entry.offsetY or screenY,
                    }
                end
            end
        end
        table.sort(chunks, function(a, b)
            if a.y == b.y then
                return a.x < b.x
            end
            return a.y < b.y
        end)
        love.graphics.setColor(1, 1, 1, 1)
        for _, chunk in ipairs(chunks) do
            if chunk.entry then
                love.graphics.draw(chunk.entry.canvas, chunk.x, chunk.y)
            else
                drawIsoTerrainChunkLive(sim.world, chunk.cx, chunk.cy, sim.player.z, rotation, chunk.baseX, chunk.baseY)
            end
        end
        for key in pairs(isoTerrainCache.chunks) do
            if not visibleChunkKeys[key] then
                isoTerrainCache.chunks[key] = nil
            end
        end
    else
        for sum = -radius * 2, radius * 2 do
            for rx = -radius, radius do
                local ry = sum - rx
                if ry >= -radius and ry <= radius then
                    local dx, dy = Render.unrotateDelta(rx, ry, rotation)
                    local x = sim.player.x + dx
                    local y = sim.player.y + dy
                    local screenX = centerX + (rx - ry) * isoTileW / 2
                    local screenY = centerY + (rx + ry) * isoTileH / 2
                    if screenX >= -isoTileW and screenX <= width + isoTileW
                        and screenY >= topHudH - isoTileH and screenY <= height + isoTileH
                    then
                        drawIsoTile(sim.world, x, y, sim.player.z, screenX, screenY)
                    end
                end
            end
        end
    end
    local visibleMachines = {}
    for _, machine in ipairs(sim:machinesInRect(minX, maxX, minY, maxY, sim.player.z)) do
        local screenX, screenY = Render.projectIso(app.worldView, machine.x, machine.y)
        if screenX >= -isoTileW and screenX <= width + isoTileW
            and screenY >= topHudH - isoTileH and screenY <= height + isoTileH
        then
            visibleMachines[#visibleMachines + 1] = { machine = machine, x = screenX, y = screenY }
        end
    end
    table.sort(visibleMachines, function(a, b)
        if a.y == b.y then
            return a.machine.id < b.machine.id
        end
        return a.y < b.y
    end)
    for _, entry in ipairs(visibleMachines) do
        Render.drawIsoMachine(entry.machine, entry.x, entry.y)
    end
    love.graphics.setColor(0.1, 0.12, 0.14, 1)
    love.graphics.ellipse("fill", centerX, centerY + 5, 13, 7)
    love.graphics.setColor(0.92, 0.84, 0.62, 1)
    love.graphics.circle("fill", centerX, centerY - 10, 10)
    local fx, fy = Grid.front(sim.player.x, sim.player.y, sim.player.facing)
    local highlightX, highlightY = Render.projectIso(app.worldView, fx, fy)
    love.graphics.setColor(1, 1, 1, 0.2)
    love.graphics.polygon(
        "fill",
        highlightX, highlightY - isoTileH / 2,
        highlightX + isoTileW / 2, highlightY,
        highlightX, highlightY + isoTileH / 2,
        highlightX - isoTileW / 2, highlightY)
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
    for index, cardDef in ipairs(buildCardDefs) do
        local recipeKey = cardDef.recipeKey
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
        love.graphics.print(cardDef.label, panelX + 18, y + 4)
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
    local header = "Thoth  tick " .. sim.tick
        .. "  pos " .. sim.player.x .. "," .. sim.player.y .. "," .. sim.player.z
        .. "  face " .. sim.player.facing
        .. "  view " .. ((app.viewRotation or 0) * 90) .. "deg"
    love.graphics.print(header, 16, 10)
    love.graphics.printf("status " .. tostring(app.status), width - 276, 10, 260, "right")
    love.graphics.printf("next " .. sim:nextStepText(), 16, 30, width - 320)
    local checklist = sim:objectiveChecklist()
    love.graphics.printf(checklistText(activeChecklist(checklist)), 16, 54, width - 32)
    local progress = sim:achievementProgress()
    local fps = love.timer and love.timer.getFPS and love.timer.getFPS() or 0
    love.graphics.printf("fps " .. fps .. "  ach " .. sim:unlockedAchievementCount() .. "/" .. #progress, width - 276, 54, 260, "right")
end

function Render.draw(sim, app)
    love.graphics.clear(0.07, 0.08, 0.08, 1)
    Render.prepareUi(app)
    Render.drawWorld(sim, app)
    Render.drawHud(sim, app)
    drawTutorialPanel(sim)
    drawMachinePanel(sim, app)
    drawInventoryPanel(sim, app)
    drawRecipeCards(sim, app)
end

return Render
