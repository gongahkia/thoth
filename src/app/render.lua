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

local function color(rgb, alpha)
    return (rgb[1] or 255) / 255, (rgb[2] or 255) / 255, (rgb[3] or 255) / 255, (alpha or 255) / 255
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

function Render.drawHud(sim, app)
    love.graphics.setColor(0.06, 0.07, 0.08, 0.86)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), 88)
    love.graphics.setColor(0.9, 0.92, 0.86, 1)
    love.graphics.print("Thoth  tick " .. sim.tick .. "  " .. sim:objectiveText(), 16, 12)
    love.graphics.print("status " .. tostring(app.status), 16, 34)
    love.graphics.print("inv " .. stacksText(sim.player.inventory), 16, 56)
    for i = 1, 10 do
        local x = 16 + (i - 1) * 46
        love.graphics.setColor(i == sim.player.selectedHotbar and 0.95 or 0.25, 0.8, 0.35, 1)
        love.graphics.rectangle("line", x, love.graphics.getHeight() - 44, 38, 32)
        love.graphics.setColor(0.9, 0.92, 0.86, 1)
        love.graphics.print(sim.player.hotbar[i] or "-", x + 4, love.graphics.getHeight() - 36)
    end
end

function Render.draw(sim, app)
    love.graphics.clear(0.07, 0.08, 0.08, 1)
    Render.drawWorld(sim, app)
    Render.drawHud(sim, app)
end

return Render
