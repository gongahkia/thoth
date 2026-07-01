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

local seasons = {
    { label = "spring", value = "spring" },
    { label = "summer", value = "summer" },
    { label = "autumn", value = "autumn" },
    { label = "winter", value = "winter" },
}

local scopes = {
    { label = "Local", value = "local" },
    { label = "Region", value = "region" },
    { label = "Continent", value = "continent" },
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

local function createDefaults(args)
    return {
        tab = "General",
        name = "New World",
        seed = tostring(args and args.seed or ""),
        randomSeed = args and args.randomSeed or thumbnailSeed,
        scope = "local",
        allowExoticBiomes = false,
        geologicTime = 0,
        hydrologyRegionChunks = "1",
        hydrologyHaloCells = "0",
        hydrologyBasinChunks = "8",
        hydrologyBasinStride = "8",
        cacheMaxEntries = "512",
        pixelScale = "2",
        dayLength = "60",
        startSeason = "summer",
        previewDirtyAt = 0,
        previewKey = nil,
        preview = nil,
    }
end

local function numeric(value, fallback)
    return tonumber(value) or fallback
end

local function seedFor(create)
    local seed = tonumber(create.seed)
    if seed then return seed end
    return create.randomSeed or thumbnailSeed
end

local function previewOptions(create)
    return {
        scope = create.scope,
        allowExoticBiomes = create.allowExoticBiomes == true,
        geologicTime = create.geologicTime,
        hydrologyRegionChunks = numeric(create.hydrologyRegionChunks, 1),
        hydrologyHaloCells = numeric(create.hydrologyHaloCells, 0),
        hydrologyBasinChunks = numeric(create.hydrologyBasinChunks, 8),
        hydrologyBasinStride = numeric(create.hydrologyBasinStride, 8),
        cacheMaxEntries = numeric(create.cacheMaxEntries, 512),
    }
end

local function previewKey(create)
    return table.concat({
        seedFor(create),
        create.scope,
        create.allowExoticBiomes and "1" or "0",
        string.format("%.3f", create.geologicTime or 0),
        create.hydrologyRegionChunks,
        create.hydrologyHaloCells,
        create.hydrologyBasinChunks,
        create.hydrologyBasinStride,
        create.cacheMaxEntries,
    }, ":")
end

local function markPreviewDirty(menu)
    menu.create.previewDirtyAt = menu.time
end

local function rebuildPreview(menu)
    local create = menu.create
    local key = previewKey(create)
    local world = WorldGen.new(seedFor(create), previewOptions(create))
    local map = Export.renderMap(world, { size = 128, span = 768, scale = create.scope, x = 0, y = 0 })
    create.preview = mapToImage(map)
    create.previewKey = key
end

local function createArgs(create)
    local args = {
        "--seed", tostring(seedFor(create)),
        "--scope", tostring(create.scope),
        "--geologic-time", string.format("%.3f", create.geologicTime or 0),
        "--hydrology-region-chunks", tostring(numeric(create.hydrologyRegionChunks, 1)),
        "--hydrology-halo", tostring(numeric(create.hydrologyHaloCells, 0)),
        "--hydrology-basin-chunks", tostring(numeric(create.hydrologyBasinChunks, 8)),
        "--hydrology-basin-stride", tostring(numeric(create.hydrologyBasinStride, 8)),
        "--cache-max-entries", tostring(numeric(create.cacheMaxEntries, 512)),
        "--pixel-scale", tostring(numeric(create.pixelScale, 2)),
        "--day-length", tostring(numeric(create.dayLength, 60)),
        "--season", tostring(create.startSeason or "summer"),
    }
    if create.allowExoticBiomes then args[#args + 1] = "--allow-exotic-biomes" end
    return args
end

function Menu.new(args)
    local backdrop, metadata = buildBackdrop()
    return {
        state = "title",
        args = args or {},
        create = createDefaults(args or {}),
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
    if menu.state == "create" then
        local create = menu.create
        if previewKey(create) ~= create.previewKey and menu.time - (create.previewDirtyAt or 0) >= 0.5 then rebuildPreview(menu) end
    end
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
    local ui = menu.ui
    local create = menu.create
    UI.Label(ui, "CREATE WORLD", x, y, { size = 30 })
    local sidebarW = math.min(134, w * 0.32)
    for index, tab in ipairs({ "General", "Advanced" }) do
        if UI.Button(ui, tab, x, y + 48 + (index - 1) * 44, sidebarW, 36, { id = "create:tab:" .. tab, size = 16 }) then create.tab = tab end
    end
    backButton(menu, x, y + 150)
    local rx = x + sidebarW + 26
    local rw = w - sidebarW - 26
    if create.tab == "Advanced" then
        local fields = {
            { "Region Chunks", "hydrologyRegionChunks" },
            { "Halo Cells", "hydrologyHaloCells" },
            { "Basin Chunks", "hydrologyBasinChunks" },
            { "Basin Stride", "hydrologyBasinStride" },
            { "Cache Entries", "cacheMaxEntries" },
            { "Pixel Scale", "pixelScale" },
            { "Day Length", "dayLength" },
        }
        for index, field in ipairs(fields) do
            local fy = y + 48 + (index - 1) * 36
            UI.Label(ui, field[1], rx, fy + 6, { size = 14, muted = true })
            local nextValue, changed = UI.TextField(ui, create[field[2]], rx + 122, fy, math.min(116, rw - 122), 28, { id = "create:" .. field[2], size = 14 })
            create[field[2]] = nextValue
            if changed then markPreviewDirty(menu) end
        end
        local nextSeason, changed = UI.RadioGroup(ui, create.startSeason, seasons, rx, y + 306, rw, 26, { id = "create:season", size = 14 })
        create.startSeason = nextSeason
        if changed then markPreviewDirty(menu) end
    else
        UI.Label(ui, "Name", rx, y + 48, { size = 14, muted = true })
        create.name = UI.TextField(ui, create.name, rx + 64, y + 42, math.min(190, rw - 64), 30, { id = "create:name", size = 16 })
        UI.Label(ui, "Seed", rx, y + 86, { size = 14, muted = true })
        local seed, seedChanged = UI.TextField(ui, create.seed, rx + 64, y + 80, math.min(190, rw - 64), 30, { id = "create:seed", size = 16 })
        create.seed = seed
        if seedChanged then markPreviewDirty(menu) end
        local nextScope, scopeChanged = UI.RadioGroup(ui, create.scope, scopes, rx, y + 124, rw, 28, { id = "create:scope", size = 15 })
        create.scope = nextScope
        if scopeChanged then markPreviewDirty(menu) end
        local exotic, exoticChanged = UI.Checkbox(ui, create.allowExoticBiomes, "Exotic", rx, y + 214, rw, 28, { id = "create:exotic", size = 15 })
        create.allowExoticBiomes = exotic
        if exoticChanged then markPreviewDirty(menu) end
        UI.Label(ui, "Geologic " .. string.format("%.2f", create.geologicTime or 0), rx, y + 250, { size = 14, muted = true })
        local time, timeChanged = UI.Slider(ui, create.geologicTime, 0, 1, rx, y + 276, math.min(220, rw), 28, { id = "create:geologic" })
        create.geologicTime = time
        if timeChanged then markPreviewDirty(menu) end
    end
    if create.preview then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(create.preview, rx + math.max(0, rw - 128), y + 42, 0, 1, 1)
    else
        UI.Label(ui, "preview", rx + math.max(0, rw - 128), y + 92, { size = 16, muted = true })
    end
    if UI.Button(ui, "Create", rx, y + 346, math.min(160, rw), 38, { id = "create:launch" }) then menu.action = { kind = "play-create", args = createArgs(create) } end
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
    local panelW = menu.state == "create" and math.min(760, width - 32) or math.min(360, width - 32)
    local panelH = menu.state == "create" and math.min(500, height - 40) or math.min(430, height - 40)
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
