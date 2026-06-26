package.path = "./?.lua;./?/init.lua;./src/?.lua;./src/?/init.lua;" .. package.path

local WorldGen = require("src.worldgen")

local prefix = ...
local jobs = love.thread.getChannel(prefix .. ".jobs")
local responses = love.thread.getChannel(prefix .. ".response")
local world
local worldKey

local function simpleCell(cell)
    local out = {}
    for k, v in pairs(cell) do
        local kind = type(v)
        if kind == "number" or kind == "string" or kind == "boolean" then out[k] = v end
    end
    return out
end

local function simpleChunk(chunk)
    local rows = {}
    for y, row in ipairs(chunk.cells) do
        rows[y] = {}
        for x, cell in ipairs(row) do
            rows[y][x] = simpleCell(cell)
        end
    end
    return {
        x = chunk.x,
        y = chunk.y,
        scale = chunk.scale,
        scaleFactor = chunk.scaleFactor,
        size = chunk.size,
        cells = rows,
    }
end

local function workerKey(message)
    local options = message.options or {}
    return table.concat({
        message.seed,
        options.chunkSize or "",
        options.seaLevel or "",
        options.hydrologyRegionChunks or "",
        options.hydrologyHaloCells or "",
        options.hydrologyBasinChunks or "",
        options.hydrologyBasinStride or "",
        options.hydrologyBasinHaloCells or "",
        options.hydrologyBasinFlowScale or "",
        options.cacheMaxEntries or "",
    }, "|")
end

while true do
    local message = jobs:demand()
    if message.quit then break end
    local ok, result = pcall(function()
        local key = workerKey(message)
        if not world or key ~= worldKey then
            world = WorldGen.new(message.seed, message.options or {})
            worldKey = key
        end
        return simpleChunk(world:chunk(message.chunkX, message.chunkY, message.scale))
    end)
    responses:push({
        key = message.key,
        ok = ok,
        chunk = ok and result or nil,
        error = ok and nil or tostring(result),
    })
end
