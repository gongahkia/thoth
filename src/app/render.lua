local Defs = require("src.game.defs")
local Grid = require("src.core.grid")
local World = require("src.game.world")

local Render = {}

local isoTileW = 64
local isoTileH = 32
local isoBlockH = 18
local renderChunkTileSize = 16
local isoTerrainCache = { world = nil, chunks = {}, supported = nil }
local isoTileOrders = {}

local tileAccents = {
    relic_cache = { 0.95, 0.78, 0.28, 1 },
    whispering_idol = { 0.62, 0.42, 0.86, 1 },
    wire_snare = { 0.74, 0.24, 0.22, 1 },
    camp_marker = { 0.78, 0.64, 0.38, 1 },
    boss_sigil = { 0.86, 0.2, 0.3, 1 },
    exit_gate = { 0.24, 0.72, 0.8, 1 },
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
    love.graphics.setColor(0.055, 0.06, 0.07, alpha or 0.88)
    love.graphics.rectangle("fill", x, y, w, h)
    love.graphics.setColor(0.22, 0.24, 0.24, 0.9)
    love.graphics.rectangle("line", x, y, w, h)
end

local function clearList(list)
    for i = #list, 1, -1 do
        list[i] = nil
    end
end

function Render.prepareUi(app)
    app.ui = app.ui or {}
    app.ui.skillButtons = app.ui.skillButtons or {}
    app.ui.heroButtons = app.ui.heroButtons or {}
    app.ui.enemyButtons = app.ui.enemyButtons or {}
    app.ui.itemButtons = app.ui.itemButtons or {}
    app.ui.missionButtons = app.ui.missionButtons or {}
    app.ui.recruitButtons = app.ui.recruitButtons or {}
    app.ui.provisionButtons = app.ui.provisionButtons or {}
    app.ui.estateActionButtons = app.ui.estateActionButtons or {}
    app.ui.rosterButtons = app.ui.rosterButtons or {}
    clearList(app.ui.skillButtons)
    clearList(app.ui.heroButtons)
    clearList(app.ui.enemyButtons)
    clearList(app.ui.itemButtons)
    clearList(app.ui.missionButtons)
    clearList(app.ui.recruitButtons)
    clearList(app.ui.provisionButtons)
    clearList(app.ui.estateActionButtons)
    clearList(app.ui.rosterButtons)
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

function Render.load()
    isoTerrainCache.world = nil
    isoTerrainCache.chunks = {}
    isoTileOrders = {}
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
    love.graphics.setColor(shaded(rgb, 0.52, 1))
    love.graphics.polygon("fill", cx - halfW, topY, cx, topY + halfH, cx, cy + halfH, cx - halfW, cy)
    love.graphics.setColor(shaded(rgb, 0.42, 1))
    love.graphics.polygon("fill", cx + halfW, topY, cx, topY + halfH, cx, cy + halfH, cx + halfW, cy)
    love.graphics.setColor(shaded(rgb, 0.95, 1))
    love.graphics.polygon("fill", cx, topY - halfH, cx + halfW, topY, cx, topY + halfH, cx - halfW, topY)
    love.graphics.setColor(0, 0, 0, 0.22)
    love.graphics.polygon("line", cx, topY - halfH, cx + halfW, topY, cx, topY + halfH, cx - halfW, topY)
end

local function drawIsoTile(world, x, y, z, screenX, screenY)
    local tile = world:peekTile(x, y, z or 0)
    local tileDef = Defs.tile(tile.id)
    drawIsoDiamond(screenX, screenY, tileDef.color)
    local accent = tileAccents[tile.id]
    if accent then
        love.graphics.setColor(accent)
        love.graphics.circle("fill", screenX, screenY - 9, 8)
        love.graphics.setColor(0, 0, 0, 0.35)
        love.graphics.circle("line", screenX, screenY - 9, 8)
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
    local topPad = 50
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
        local worldX = cx * renderChunkTileSize + tileEntry.x
        local worldY = cy * renderChunkTileSize + tileEntry.y
        drawIsoTile(world, worldX, worldY, z, (tileEntry.rx - tileEntry.ry) * halfW - minX, (tileEntry.rx + tileEntry.ry) * halfH - minY)
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
        drawIsoTile(world, worldX, worldY, z, baseScreenX + (tileEntry.rx - tileEntry.ry) * halfW, baseScreenY + (tileEntry.rx + tileEntry.ry) * halfH)
    end
end

local function drawObject(object, screenX, screenY)
    if object.type == "encounter" then
        drawIsoBlock(screenX, screenY, { 126, 46, 54 }, isoBlockH)
    elseif object.type == "boss" then
        drawIsoBlock(screenX, screenY, { 150, 40, 68 }, isoBlockH + 8)
    elseif object.type == "exit" then
        drawIsoBlock(screenX, screenY, { 60, 144, 154 }, isoBlockH)
    else
        drawIsoBlock(screenX, screenY, { 146, 116, 70 }, isoBlockH - 3)
    end
end

function Render.drawWorld(sim, app)
    local width, height = love.graphics.getDimensions()
    local rightDockW = 318
    local topHudH = 76
    local bottomTrayH = 120
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
        isoTerrainCache.buildLimit = 2
        local visibleChunkKeys = {}
        local chunks = {}
        for cy = World.floorDiv(minY, renderChunkTileSize), World.floorDiv(maxY, renderChunkTileSize) do
            for cx = World.floorDiv(minX, renderChunkTileSize), World.floorDiv(maxX, renderChunkTileSize) do
                local screenX, screenY = Render.projectIso(app.worldView, cx * renderChunkTileSize, cy * renderChunkTileSize)
                if screenX >= -renderChunkTileSize * isoTileW and screenX <= width + renderChunkTileSize * isoTileW
                    and screenY >= -renderChunkTileSize * isoTileH and screenY <= height + renderChunkTileSize * isoTileH
                then
                    local key, entry = isoTerrainChunk(sim.world, cx, cy, sim.player.z, rotation)
                    visibleChunkKeys[key] = true
                    chunks[#chunks + 1] = { entry = entry, cx = cx, cy = cy, baseX = screenX, baseY = screenY, x = entry and screenX + entry.offsetX or screenX, y = entry and screenY + entry.offsetY or screenY }
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
                    drawIsoTile(sim.world, x, y, sim.player.z, centerX + (rx - ry) * isoTileW / 2, centerY + (rx + ry) * isoTileH / 2)
                end
            end
        end
    end
    for _, object in ipairs(sim:objectsInRect(minX, maxX, minY, maxY, sim.player.z)) do
        local sx, sy = Render.projectIso(app.worldView, object.x, object.y)
        drawObject(object, sx, sy)
    end
    love.graphics.setColor(0.08, 0.1, 0.11, 1)
    love.graphics.ellipse("fill", centerX, centerY + 5, 16, 8)
    love.graphics.setColor(0.88, 0.82, 0.58, 1)
    love.graphics.circle("fill", centerX, centerY - 12, 12)
    local fx, fy = Grid.front(sim.player.x, sim.player.y, sim.player.facing)
    local highlightX, highlightY = Render.projectIso(app.worldView, fx, fy)
    love.graphics.setColor(1, 1, 1, 0.18)
    love.graphics.polygon("fill", highlightX, highlightY - isoTileH / 2, highlightX + isoTileW / 2, highlightY, highlightX, highlightY + isoTileH / 2, highlightX - isoTileW / 2, highlightY)
end

local function checklistText(group)
    local parts = { group.title }
    for _, item in ipairs(group.items) do
        parts[#parts + 1] = (item.done and "[x]" or "[ ]") .. item.label
    end
    return table.concat(parts, " ")
end

function Render.drawHud(sim, app)
    local width = love.graphics.getWidth()
    panel(0, 0, width, 76, 0.9)
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print("Thoth  tick " .. sim.tick .. "  " .. sim.mode .. "  pos " .. sim.player.x .. "," .. sim.player.y .. "  view " .. ((app.viewRotation or 0) * 90), 16, 10)
    love.graphics.printf("status " .. tostring(app.status or sim.status), width - 286, 10, 270, "right")
    love.graphics.printf("next " .. sim:nextStepText(), 16, 32, width - 320)
    local checklist = sim:objectiveChecklist()[1]
    love.graphics.printf(checklistText(checklist), 16, 54, width - 32)
    love.graphics.printf(sim:missionProgressText(), width - 286, 54, 270, "right")
end

local function drawHeroRows(sim, app, x, y, w)
    for _, hero in ipairs(sim:partyState()) do
        local rowY = y + (hero.rank - 1) * 42
        local active = hero.rank == sim.player.selectedHero
        love.graphics.setColor(active and 0.2 or 0.12, active and 0.24 or 0.14, active and 0.18 or 0.13, 1)
        love.graphics.rectangle("fill", x, rowY, w, 36)
        love.graphics.setColor(active and 0.82 or 0.32, active and 0.72 or 0.34, active and 0.34 or 0.28, 1)
        love.graphics.rectangle("line", x, rowY, w, 36)
        love.graphics.setColor(0.94, 0.96, 0.9, 1)
        love.graphics.print(hero.rank .. " " .. hero.name .. " / " .. hero.class .. " L" .. (hero.level or 1), x + 6, rowY + 4)
        love.graphics.setColor(0.74, 0.82, 0.74, 1)
        love.graphics.print("hp " .. hero.hp .. "/" .. hero.maxHp .. "  stress " .. hero.stress, x + 6, rowY + 19)
        if hero.deathsDoor then
            love.graphics.setColor(0.94, 0.34, 0.28, 1)
            love.graphics.print("door", x + w - 54, rowY + 19)
        elseif hero.affliction then
            love.graphics.setColor(0.9, 0.46, 0.42, 1)
            love.graphics.print(hero.affliction, x + w - 74, rowY + 19)
        elseif hero.virtue then
            love.graphics.setColor(0.56, 0.82, 0.66, 1)
            love.graphics.print(hero.virtue, x + w - 64, rowY + 19)
        elseif hero.diseases and #hero.diseases > 0 then
            love.graphics.setColor(0.68, 0.72, 0.46, 1)
            love.graphics.print("ill", x + w - 34, rowY + 19)
        end
        app.ui.heroButtons[#app.ui.heroButtons + 1] = { x = x, y = rowY, w = w, h = 36, rank = hero.rank }
    end
end

local function stacksText(inventory)
    local parts = {}
    if not inventory then
        return "-"
    end
    for _, stack in ipairs(inventory:stacks()) do
        parts[#parts + 1] = stack.item .. ":" .. stack.count
    end
    return #parts > 0 and table.concat(parts, "  ") or "-"
end

local function firstOpenTrinketSlot(hero)
    for slot = 1, 2 do
        if not hero.trinkets or not hero.trinkets[slot] then
            return slot
        end
    end
    return nil
end

local function selectedEstateHero(sim, app)
    local selected = app.estateHeroId and sim:heroById(app.estateHeroId)
    if selected and selected.alive then
        return selected
    end
    return sim:heroAtRank(sim.player.selectedHero) or sim:heroAtRank(1) or sim.estate.roster[1]
end

local function addEstateAction(app, label, x, y, w, action)
    love.graphics.setColor(action.enabled and 0.15 or 0.09, action.enabled and 0.18 or 0.09, action.enabled and 0.16 or 0.09, 1)
    love.graphics.rectangle("fill", x, y, w, 28)
    love.graphics.setColor(action.enabled and 0.48 or 0.25, action.enabled and 0.54 or 0.25, action.enabled and 0.38 or 0.25, 1)
    love.graphics.rectangle("line", x, y, w, 28)
    love.graphics.setColor(action.enabled and 0.86 or 0.42, action.enabled and 0.88 or 0.42, action.enabled and 0.8 or 0.42, 1)
    love.graphics.printf(label, x + 4, y + 7, w - 8, "center")
    if action.enabled then
        action.x = x
        action.y = y
        action.w = w
        action.h = 28
        app.ui.estateActionButtons[#app.ui.estateActionButtons + 1] = action
    end
end

local function drawRosterBrowser(sim, app, x, y, w, h)
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print("Roster", x, y)
    local selected = selectedEstateHero(sim, app)
    for index, hero in ipairs(sim.estate.roster) do
        local rowY = y + 22 + (index - 1) * 34
        if rowY + 28 > y + h then
            break
        end
        local active = selected and selected.id == hero.id
        local class = Defs.heroClass(hero.class)
        love.graphics.setColor(active and 0.2 or 0.11, active and 0.23 or 0.13, active and 0.18 or 0.13, 1)
        love.graphics.rectangle("fill", x, rowY, w, 28)
        love.graphics.setColor(active and 0.72 or 0.32, active and 0.62 or 0.34, active and 0.32 or 0.28, 1)
        love.graphics.rectangle("line", x, rowY, w, 28)
        love.graphics.setColor(hero.alive and 0.9 or 0.48, hero.alive and 0.92 or 0.44, hero.alive and 0.86 or 0.42, 1)
        love.graphics.printf(hero.name .. " / " .. class.name .. " L" .. (hero.level or 1), x + 4, rowY + 6, w - 8, "left")
        app.ui.rosterButtons[#app.ui.rosterButtons + 1] = { x = x, y = rowY, w = w, h = 28, heroId = hero.id }
    end
    return selected
end

local function drawSelectedEstateHero(sim, app, hero, x, y, w)
    if not hero then
        return
    end
    local class = Defs.heroClass(hero.class)
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print(hero.name .. " / " .. class.name, x, y)
    love.graphics.setColor(0.74, 0.78, 0.72, 1)
    love.graphics.printf("hp " .. hero.hp .. "/" .. sim:maxHp(hero) .. " stress " .. hero.stress .. " weapon " .. (hero.weapon or 0) .. " armor " .. (hero.armor or 0), x, y + 18, w)

    local actionY = y + 44
    for index, skillKey in ipairs(hero.skills or {}) do
        addEstateAction(app, "train " .. index, x + ((index - 1) % 3) * 82, actionY + math.floor((index - 1) / 3) * 34, 76, { action = "upgradeSkill", heroId = hero.id, skillKey = skillKey, enabled = true })
    end
    addEstateAction(app, "weapon", x, actionY + 40, 76, { action = "upgradeGear", heroId = hero.id, kind = "weapon", enabled = true })
    addEstateAction(app, "armor", x + 82, actionY + 40, 76, { action = "upgradeGear", heroId = hero.id, kind = "armor", enabled = true })
    addEstateAction(app, "dismiss", x + 164, actionY + 40, 76, { action = "dismissHero", heroId = hero.id, enabled = not sim:heroRank(hero.id) and sim:livingRosterCount() > 4 and (hero.recovering or 0) <= 0 })
    for index, activityKey in ipairs(Defs.estateActivityOrder) do
        local activity = Defs.estateActivity(activityKey)
        addEstateAction(app, (activity.short or activity.name) .. " " .. activity.cost, x + ((index - 1) % 3) * 82, actionY + 74 + math.floor((index - 1) / 3) * 34, 76, { action = "recoverHero", heroId = hero.id, activityKey = activityKey, enabled = (hero.recovering or 0) <= 0 })
    end

    local trinketY = actionY + 118
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print("Trinkets", x, trinketY)
    for slot = 1, 2 do
        local key = hero.trinkets and hero.trinkets[slot]
        addEstateAction(app, key and ("slot " .. slot .. " -" ) or ("slot " .. slot), x + (slot - 1) * 82, trinketY + 22, 76, { action = "unequipTrinket", heroId = hero.id, slot = slot, enabled = key ~= false and key ~= nil })
    end
    local openSlot = firstOpenTrinketSlot(hero)
    local trinketIndex = 0
    for _, key in ipairs(Defs.trinketOrder) do
        local count = (sim.estate.trinkets or {})[key] or 0
        if count > 0 then
            trinketIndex = trinketIndex + 1
            local trinket = Defs.trinket(key)
            local bx = x + ((trinketIndex - 1) % 3) * 82
            local by = trinketY + 56 + math.floor((trinketIndex - 1) / 3) * 34
            addEstateAction(app, (trinket.short or key) .. ":" .. count, bx, by, 50, { action = "equipTrinket", heroId = hero.id, trinketKey = key, slot = openSlot, enabled = openSlot ~= nil })
            addEstateAction(app, "$" .. (trinket.value or 0), bx + 52, by, 24, { action = "sellTrinket", trinketKey = key, enabled = true })
        end
    end

    local treatY = trinketY + 126
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print("Treatment", x, treatY)
    local index = 0
    for _, key in ipairs(hero.quirks or {}) do
        local quirk = Defs.quirk(key)
        if quirk and quirk.kind == "negative" then
            addEstateAction(app, key, x + (index % 3) * 82, treatY + 22 + math.floor(index / 3) * 34, 76, { action = "treatQuirk", heroId = hero.id, quirkKey = key, enabled = true })
            index = index + 1
        elseif quirk and quirk.kind == "positive" then
            local locked = hero.lockedQuirks and hero.lockedQuirks[key]
            addEstateAction(app, (locked and "*" or "+") .. key, x + (index % 3) * 82, treatY + 22 + math.floor(index / 3) * 34, 76, { action = "lockQuirk", heroId = hero.id, quirkKey = key, enabled = not locked })
            index = index + 1
        end
    end
    for _, key in ipairs(hero.diseases or {}) do
        addEstateAction(app, key, x + (index % 3) * 82, treatY + 22 + math.floor(index / 3) * 34, 76, { action = "treatDisease", heroId = hero.id, diseaseKey = key, enabled = true })
        index = index + 1
    end

    local rankY = treatY + 90
    for rank = 1, 4 do
        addEstateAction(app, "rank " .. rank, x + (rank - 1) * 62, rankY, 56, { action = "assignParty", heroId = hero.id, rank = rank, enabled = true })
    end
end

function Render.drawSidePanel(sim, app)
    local width, height = love.graphics.getDimensions()
    local x = width - 306
    local y = 88
    panel(x, y, 292, height - 104, 0.88)
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print("Party", x + 10, y + 10)
    drawHeroRows(sim, app, x + 10, y + 34, 272)
    local detailY = y + 214
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print("Supplies", x + 10, detailY)
    love.graphics.setColor(0.75, 0.78, 0.72, 1)
    love.graphics.printf(sim.expedition and stacksText(sim.expedition.supplies) or "-", x + 10, detailY + 20, 272)
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print("Loot", x + 10, detailY + 74)
    love.graphics.setColor(0.75, 0.78, 0.72, 1)
    love.graphics.printf(sim.expedition and stacksText(sim.expedition.loot) or ("gold:" .. sim.estate.gold .. " heirlooms:" .. sim.estate.heirlooms), x + 10, detailY + 94, 272)
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print("Log", x + 10, detailY + 150)
    love.graphics.setColor(0.72, 0.76, 0.72, 1)
    local log = sim.expedition and sim.expedition.log or sim.log
    for i = math.max(1, #log - 5), #log do
        love.graphics.print(log[i], x + 10, detailY + 154 + (i - math.max(1, #log - 5) + 1) * 18)
    end
end

function Render.drawCombatOverlay(sim, app)
    if sim.mode ~= "combat" or not sim.combat then
        return
    end
    local width, height = love.graphics.getDimensions()
    local x = 28
    local y = height - 206
    local w = width - 370
    panel(x, y, w, 186, 0.93)
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print("Combat  round " .. sim.combat.round, x + 10, y + 8)
    local active = sim:activeHero()
    love.graphics.print(active and (active.name .. " acts") or "enemy turn", x + 170, y + 8)
    for rank = 1, 4 do
        local hero = sim:heroAtRank(rank)
        local hx = x + 18 + (rank - 1) * 92
        love.graphics.setColor(0.14, 0.18, 0.15, 1)
        love.graphics.rectangle("fill", hx, y + 38, 82, 58)
        love.graphics.setColor(0.42, 0.52, 0.38, 1)
        love.graphics.rectangle("line", hx, y + 38, 82, 58)
        love.graphics.setColor(0.9, 0.92, 0.86, 1)
        love.graphics.printf(hero and hero.name or "-", hx + 4, y + 44, 74, "center")
        if hero then
            love.graphics.printf(hero.hp .. "hp " .. hero.stress .. "s", hx + 4, y + 66, 74, "center")
            app.ui.heroButtons[#app.ui.heroButtons + 1] = { x = hx, y = y + 38, w = 82, h = 58, rank = rank, side = "ally" }
        end
    end
    for rank = 1, 4 do
        local enemy = sim:enemyAtRank(rank)
        local ex = x + w - 386 + (rank - 1) * 92
        love.graphics.setColor(0.2, 0.11, 0.12, 1)
        love.graphics.rectangle("fill", ex, y + 38, 82, 58)
        love.graphics.setColor(0.58, 0.28, 0.28, 1)
        love.graphics.rectangle("line", ex, y + 38, 82, 58)
        love.graphics.setColor(0.94, 0.86, 0.82, 1)
        love.graphics.printf(enemy and Defs.enemy(enemy.kind).name or "-", ex + 4, y + 44, 74, "center")
        if enemy then
            love.graphics.printf(enemy.hp .. "hp", ex + 4, y + 66, 74, "center")
            app.ui.enemyButtons[#app.ui.enemyButtons + 1] = { x = ex, y = y + 38, w = 82, h = 58, rank = rank, side = "enemy" }
        end
    end
    local skillY = y + 116
    for _, skill in ipairs(sim:availableSkills()) do
        local sx = x + 12 + (skill.index - 1) * 150
        love.graphics.setColor(skill.usable and 0.18 or 0.1, skill.usable and 0.22 or 0.1, skill.usable and 0.2 or 0.1, 1)
        love.graphics.rectangle("fill", sx, skillY, 140, 42)
        love.graphics.setColor(skill.usable and 0.74 or 0.34, skill.usable and 0.66 or 0.34, skill.usable and 0.36 or 0.32, 1)
        love.graphics.rectangle("line", sx, skillY, 140, 42)
        love.graphics.setColor(skill.usable and 0.94 or 0.46, skill.usable and 0.96 or 0.46, skill.usable and 0.9 or 0.46, 1)
        love.graphics.printf(skill.index .. " " .. skill.name, sx + 6, skillY + 8, 128, "center")
        if skill.usable then
            local def = Defs.skill(skill.key)
            app.ui.skillButtons[#app.ui.skillButtons + 1] = { x = sx, y = skillY, w = 140, h = 42, skillKey = skill.key, targetSide = def.target == "ally" and "ally" or (def.target == "enemy" and "enemy" or nil), immediate = def.target == "self" or def.target == "party" }
        end
    end
end

function Render.drawCampOverlay(sim)
    if not (sim.expedition and sim.expedition.camping) then
        return
    end
    local width, height = love.graphics.getDimensions()
    local x = 28
    local y = height - 164
    local w = width - 370
    panel(x, y, w, 144, 0.93)
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print("Camp  respite " .. sim.expedition.camping.respite, x + 10, y + 8)
    local skillY = y + 44
    for _, skill in ipairs(sim:availableCampSkills()) do
        local sx = x + 12 + (skill.index - 1) * 150
        love.graphics.setColor(skill.usable and 0.18 or 0.1, skill.usable and 0.22 or 0.1, skill.usable and 0.2 or 0.1, 1)
        love.graphics.rectangle("fill", sx, skillY, 140, 54)
        love.graphics.setColor(skill.usable and 0.74 or 0.34, skill.usable and 0.66 or 0.34, skill.usable and 0.36 or 0.32, 1)
        love.graphics.rectangle("line", sx, skillY, 140, 54)
        love.graphics.setColor(skill.usable and 0.94 or 0.46, skill.usable and 0.96 or 0.46, skill.usable and 0.9 or 0.46, 1)
        love.graphics.printf(skill.index .. " " .. skill.name, sx + 6, skillY + 8, 128, "center")
        love.graphics.printf("cost " .. skill.cost, sx + 6, skillY + 30, 128, "center")
    end
end

function Render.drawEstatePanel(sim, app)
    if app.panel ~= "estate" and sim.mode ~= "estate" then
        return
    end
    local x = 24
    local y = 92
    panel(x, y, 720, 610, 0.92)
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print("Estate", x + 10, y + 10)
    love.graphics.print("week " .. (sim.estate.week or 1) .. "  gold " .. sim.estate.gold .. "  heirlooms " .. sim.estate.heirlooms, x + 10, y + 34)
    local campaign = sim.estate.campaign or {}
    local bosses = 0
    for _, key in ipairs(Defs.locationOrder) do
        if campaign.bossKills and campaign.bossKills[key] then
            bosses = bosses + 1
        end
    end
    love.graphics.print("renown " .. (campaign.renown or 0) .. "  dread " .. (campaign.dread or 0) .. "  bosses " .. bosses .. "/" .. #Defs.locationOrder, x + 390, y + 34)
    love.graphics.setColor(0.74, 0.78, 0.72, 1)
    love.graphics.print("roster " .. sim:livingRosterCount() .. "/" .. sim:rosterLimit() .. "  recruits " .. #sim.estate.recruits, x + 10, y + 58)
    if sim.estate.currentEvent then
        love.graphics.print("event " .. Defs.townEvent(sim.estate.currentEvent).name, x + 220, y + 58)
    end
    local upgrades = {}
    for _, key in ipairs(Defs.estateBuildingOrder) do
        upgrades[#upgrades + 1] = key .. ":" .. sim:buildingLevel(key)
    end
    love.graphics.printf(table.concat(upgrades, "  "), x + 10, y + 78, 312)
    local trinkets = {}
    for _, key in ipairs(Defs.trinketOrder) do
        local count = (sim.estate.trinkets or {})[key] or 0
        if count > 0 then
            trinkets[#trinkets + 1] = key .. ":" .. count
        end
    end
    love.graphics.printf(#trinkets > 0 and table.concat(trinkets, "  ") or "no trinkets", x + 10, y + 100, 312)
    love.graphics.print("Market", x + 10, y + 122)
    for index, offer in ipairs(sim.estate.trinketStock or {}) do
        local trinket = Defs.trinket(offer.trinket)
        addEstateAction(app, (trinket.short or offer.trinket) .. " " .. offer.price, x + 70 + (index - 1) * 112, y + 116, 104, { action = "buyTrinket", stockIndex = index, enabled = sim.estate.gold >= (offer.price or 0) })
    end
    love.graphics.printf("cart " .. stacksText(sim.estate.provisionCart), x + 10, y + 146, 400)
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print("Missions", x + 10, y + 174)
    for index, key in ipairs(Defs.missionOrder) do
        local mission = Defs.mission(key)
        local bx = x + 10 + ((index - 1) % 2) * 205
        local by = y + 196 + math.floor((index - 1) / 2) * 34
        love.graphics.setColor(0.13, 0.16, 0.15, 1)
        love.graphics.rectangle("fill", bx, by, 196, 28)
        love.graphics.setColor(0.42, 0.48, 0.36, 1)
        love.graphics.rectangle("line", bx, by, 196, 28)
        love.graphics.setColor(0.86, 0.88, 0.8, 1)
        love.graphics.printf(mission.kind .. " / " .. mission.location, bx + 4, by + 7, 188, "center")
        app.ui.missionButtons[#app.ui.missionButtons + 1] = { x = bx, y = by, w = 196, h = 28, missionKey = key }
    end
    local recruitY = y + 380
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print("Recruits", x + 10, recruitY)
    for index, recruit in ipairs(sim.estate.recruits or {}) do
        local bx = x + 10 + ((index - 1) % 3) * 136
        local by = recruitY + 24 + math.floor((index - 1) / 3) * 34
        love.graphics.setColor(0.13, 0.14, 0.16, 1)
        love.graphics.rectangle("fill", bx, by, 128, 28)
        love.graphics.setColor(0.38, 0.42, 0.52, 1)
        love.graphics.rectangle("line", bx, by, 128, 28)
        love.graphics.setColor(0.86, 0.88, 0.8, 1)
        love.graphics.printf(recruit.name .. " " .. Defs.heroClass(recruit.class).name, bx + 4, by + 7, 120, "center")
        app.ui.recruitButtons[#app.ui.recruitButtons + 1] = { x = bx, y = by, w = 128, h = 28, recruitIndex = index }
    end
    local provisionY = y + 472
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print("Provisions", x + 10, provisionY)
    local provisionItems = { "torch", "ration", "bandage", "laudanum", "skeleton_key", "salve" }
    for index, itemKey in ipairs(provisionItems) do
        local item = Defs.item(itemKey)
        local bx = x + 10 + ((index - 1) % 3) * 136
        local by = provisionY + 24 + math.floor((index - 1) / 3) * 34
        love.graphics.setColor(0.14, 0.13, 0.12, 1)
        love.graphics.rectangle("fill", bx, by, 128, 28)
        love.graphics.setColor(0.48, 0.42, 0.32, 1)
        love.graphics.rectangle("line", bx, by, 128, 28)
        love.graphics.setColor(0.86, 0.88, 0.8, 1)
        love.graphics.printf(item.name .. " " .. item.cost .. "g", bx + 4, by + 7, 120, "center")
        app.ui.provisionButtons[#app.ui.provisionButtons + 1] = { x = bx, y = by, w = 128, h = 28, item = itemKey }
    end
    local selected = drawRosterBrowser(sim, app, x + 446, y + 10, 252, 254)
    drawSelectedEstateHero(sim, app, selected, x + 446, y + 286, 252)
end

function Render.draw(sim, app)
    love.graphics.clear(0.055, 0.058, 0.065, 1)
    Render.prepareUi(app)
    Render.drawWorld(sim, app)
    Render.drawHud(sim, app)
    Render.drawSidePanel(sim, app)
    Render.drawCombatOverlay(sim, app)
    Render.drawCampOverlay(sim)
    Render.drawEstatePanel(sim, app)
end

return Render
