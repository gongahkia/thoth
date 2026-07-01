local Export = require("src.export")
local UI = require("src.ui")
local WorldGen = require("src.worldgen")

local Menu = {}

local thumbnailSeed = 20260625
local thumbnailOptions = {
    hydrologyRegionChunks = 1,
    hydrologyHaloCells = 0,
    hydrologyBasinChunks = 8,
    hydrologyBasinStride = 8,
    cacheMaxEntries = 128,
}

local function theme()
    local t = UI.defaultTheme()
    t.text = { 0.84, 0.86, 0.76, 1 }
    t.muted = { 0.5, 0.54, 0.48, 1 }
    t.fill = { 0.045, 0.055, 0.055, 0.9 }
    t.fillHot = { 0.085, 0.115, 0.09, 0.95 }
    t.fillActive = { 0.14, 0.18, 0.12, 0.98 }
    t.border = { 0.34, 0.39, 0.32, 1 }
    t.borderHot = { 0.78, 0.68, 0.4, 1 }
    t.accent = { 0.82, 0.73, 0.43, 1 }
    return t
end

local function mapToImage(map)
    local imageData = love.image.newImageData(map.size, map.size)
    local index = 1
    for y = 0, map.size - 1 do
        for x = 0, map.size - 1 do
            local r, g, b = string.byte(map.pixels[index], 1, 3)
            imageData:setPixel(x, y, r / 255, g / 255, b / 255, 1)
            index = index + 1
        end
    end
    local image = love.graphics.newImage(imageData)
    image:setFilter("nearest", "nearest")
    return image
end

local function buildBackdrop()
    local world = WorldGen.new(thumbnailSeed, thumbnailOptions)
    local map = Export.renderMap(world, { size = 128, span = 1536, scale = "region", x = 0, y = 0 })
    return mapToImage(map), map.metadata
end

function Menu.new(args)
    local backdrop, metadata = buildBackdrop()
    return {
        state = "title",
        args = args or {},
        ui = UI.new(theme()),
        backdrop = backdrop,
        backdropMetadata = metadata,
        time = 0,
        action = nil,
    }
end

local function setState(menu, state)
    menu.state = state
    menu.ui.focus = nil
end

function Menu.update(menu, dt)
    menu.time = menu.time + dt
    local action = menu.action
    menu.action = nil
    return action
end

local function drawBackdrop(menu, width, height)
    love.graphics.clear(0.015, 0.02, 0.02, 1)
    local image = menu.backdrop
    local scale = math.max(width / image:getWidth(), height / image:getHeight()) * 1.35
    local tileW, tileH = image:getWidth() * scale, image:getHeight() * scale
    local ox = -((menu.time * 8) % tileW)
    local oy = -((menu.time * 3) % tileH)
    love.graphics.setColor(0.82, 0.86, 0.78, 1)
    for y = -1, 1 do
        for x = -1, 1 do love.graphics.draw(image, ox + x * tileW, oy + y * tileH, 0, scale, scale) end
    end
    love.graphics.setColor(0.02, 0.025, 0.022, 0.48)
    love.graphics.rectangle("fill", 0, 0, width, height)
end

local function panel(x, y, w, h)
    love.graphics.setColor(0.025, 0.03, 0.028, 0.88)
    love.graphics.rectangle("fill", x, y, w, h)
    love.graphics.setColor(0.32, 0.38, 0.32, 1)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1)
end

local function drawHeader(menu, x, y)
    local ui = menu.ui
    love.graphics.setFont(UI.font(ui, 54))
    love.graphics.setColor(0.82, 0.73, 0.43, 1)
    love.graphics.print("THOTH", x, y)
    UI.Label(ui, "terrain prototype", x + 3, y + 58, { size = 16, muted = true })
end

local function drawTitle(menu, x, y, w)
    local ui = menu.ui
    drawHeader(menu, x, y)
    local bx, by, bw, bh = x + 4, y + 104, math.min(260, w - 8), 42
    if UI.Button(ui, "Play", bx, by, bw, bh, { id = "title:play" }) then setState(menu, "library") end
    if UI.Button(ui, "Create World", bx, by + 52, bw, bh, { id = "title:create" }) then setState(menu, "create") end
    if UI.Button(ui, "Settings", bx, by + 104, bw, bh, { id = "title:settings" }) then setState(menu, "settings") end
    if UI.Button(ui, "Quit", bx, by + 156, bw, bh, { id = "title:quit", danger = true }) then menu.action = "quit" end
    UI.Label(ui, "thumbnail seed " .. tostring(thumbnailSeed), bx, by + 214, { size = 14, muted = true })
end

local function backButton(menu, x, y)
    if UI.Button(menu.ui, "Back", x, y, 112, 36, { id = menu.state .. ":back", size = 18 }) then setState(menu, "title") end
end

local function drawLibrary(menu, x, y, w)
    UI.Label(menu.ui, "MY WORLDS", x, y, { size = 30 })
    UI.List(menu.ui, "worlds", { { label = "Default Seed" } }, x, y + 50, math.min(320, w), 76, { rowH = 38 })
    if UI.Button(menu.ui, "Play Default", x, y + 144, math.min(220, w), 40, { id = "library:default" }) then menu.action = "play-default" end
    backButton(menu, x, y + 202)
end

local function drawCreate(menu, x, y, w)
    UI.Label(menu.ui, "CREATE WORLD", x, y, { size = 30 })
    UI.Label(menu.ui, "Default", x, y + 52, { size = 18, muted = true })
    if UI.Button(menu.ui, "Create", x, y + 88, math.min(220, w), 40, { id = "create:default" }) then menu.action = "play-default" end
    backButton(menu, x, y + 146)
end

local function drawSettings(menu, x, y, w)
    UI.Label(menu.ui, "SETTINGS", x, y, { size = 30 })
    UI.List(menu.ui, "settings-tabs", {
        { label = "Controls" },
        { label = "Display" },
        { label = "Audio" },
        { label = "Debug" },
    }, x, y + 50, math.min(260, w), 156, { rowH = 38 })
    backButton(menu, x, y + 226)
end

function Menu.draw(menu)
    local width, height = love.graphics.getDimensions()
    drawBackdrop(menu, width, height)
    UI.begin(menu.ui)
    local panelW = math.min(360, width - 32)
    local panelH = math.min(430, height - 40)
    local x = math.floor(math.max(16, width * 0.08))
    local y = math.floor((height - panelH) * 0.5)
    panel(x, y, panelW, panelH)
    local innerX, innerY, innerW = x + 28, y + 26, panelW - 56
    if menu.state == "title" then
        drawTitle(menu, innerX, innerY, innerW)
    elseif menu.state == "library" then
        drawLibrary(menu, innerX, innerY, innerW)
    elseif menu.state == "create" then
        drawCreate(menu, innerX, innerY, innerW)
    elseif menu.state == "settings" then
        drawSettings(menu, innerX, innerY, innerW)
    end
    UI.finish(menu.ui)
end

function Menu.keypressed(menu, key)
    UI.keypressed(menu.ui, key)
    if key == "escape" then
        if menu.state == "title" then return "quit" end
        setState(menu, "title")
    elseif key == "return" and menu.state == "title" then
        setState(menu, "library")
    end
end

function Menu.textinput(menu, text)
    UI.textinput(menu.ui, text)
end

function Menu.mousepressed(menu, x, y, button)
    UI.mousepressed(menu.ui, x, y, button)
end

function Menu.mousereleased(menu, x, y, button)
    UI.mousereleased(menu.ui, x, y, button)
end

function Menu.wheelmoved(menu, x, y)
    UI.wheelmoved(menu.ui, x, y)
end

return Menu
