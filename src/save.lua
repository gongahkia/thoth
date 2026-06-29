local Survey = require("src.survey")
local Atmosphere = require("src.atmosphere")
local ViewScale = require("src.viewscale")

local Save = {}

local function isArray(value)
    local count = 0
    for k in pairs(value) do
        if type(k) ~= "number" or k < 1 or k % 1 ~= 0 then return false end
        count = math.max(count, k)
    end
    for index = 1, count do if value[index] == nil then return false end end
    return true, count
end

local function sortedKeys(value)
    local keys = {}
    for k in pairs(value) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    return keys
end

function Save.encode(value)
    local valueType = type(value)
    if valueType == "nil" then return "null" end
    if valueType == "boolean" or valueType == "number" then return tostring(value) end
    if valueType == "string" then return string.format("%q", value) end
    local array, count = isArray(value)
    local parts = {}
    if array then
        for index = 1, count do parts[#parts + 1] = Save.encode(value[index]) end
        return "[" .. table.concat(parts, ",") .. "]"
    end
    for _, key in ipairs(sortedKeys(value)) do
        parts[#parts + 1] = string.format("%q:%s", tostring(key), Save.encode(value[key]))
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

local function parser(text)
    local index = 1
    local function skip()
        while string.match(string.sub(text, index, index), "%s") do index = index + 1 end
    end
    local function parseString()
        local start = index
        index = index + 1
        while index <= #text do
            local char = string.sub(text, index, index)
            if char == "\\" then
                index = index + 2
            elseif char == '"' then
                index = index + 1
                return assert(loadstring("return " .. string.sub(text, start, index - 1)))()
            else
                index = index + 1
            end
        end
        error("unterminated string")
    end
    local parseValue
    local function parseArray()
        index = index + 1
        local out = {}
        skip()
        if string.sub(text, index, index) == "]" then index = index + 1 return out end
        while true do
            out[#out + 1] = parseValue()
            skip()
            local char = string.sub(text, index, index)
            if char == "]" then index = index + 1 return out end
            if char ~= "," then error("expected array comma") end
            index = index + 1
        end
    end
    local function parseObject()
        index = index + 1
        local out = {}
        skip()
        if string.sub(text, index, index) == "}" then index = index + 1 return out end
        while true do
            skip()
            local key = parseString()
            skip()
            if string.sub(text, index, index) ~= ":" then error("expected object colon") end
            index = index + 1
            out[key] = parseValue()
            skip()
            local char = string.sub(text, index, index)
            if char == "}" then index = index + 1 return out end
            if char ~= "," then error("expected object comma") end
            index = index + 1
        end
    end
    function parseValue()
        skip()
        local char = string.sub(text, index, index)
        if char == '"' then return parseString() end
        if char == "{" then return parseObject() end
        if char == "[" then return parseArray() end
        local tail = string.sub(text, index)
        if string.sub(tail, 1, 4) == "true" then index = index + 4 return true end
        if string.sub(tail, 1, 5) == "false" then index = index + 5 return false end
        if string.sub(tail, 1, 4) == "null" then index = index + 4 return nil end
        local numberText = string.match(tail, "^-?%d+%.?%d*[eE]?[+-]?%d*")
        if numberText and #numberText > 0 then
            index = index + #numberText
            return tonumber(numberText)
        end
        error("invalid json value")
    end
    return parseValue()
end

function Save.decode(text)
    return parser(text)
end

function Save.snapshot(app)
    local metadata = app.world:metadata()
    return {
        version = 1,
        seed = metadata.seed,
        world = {
            geologicTime = metadata.geologicTime,
            geologicTimeStep = metadata.geologicTimeStep,
            seaLevel = metadata.baseSeaLevel or metadata.seaLevel,
            seaLevelAmplitude1 = metadata.seaLevelAmplitude1,
            seaLevelPeriod1 = metadata.seaLevelPeriod1,
            seaLevelAmplitude2 = metadata.seaLevelAmplitude2,
            seaLevelPeriod2 = metadata.seaLevelPeriod2,
            seaLevelResidualAmplitude = metadata.seaLevelResidualAmplitude,
            worldCircumference = metadata.worldCircumference,
            omega = metadata.omega,
            legacyLatitude = metadata.legacyLatitude,
            hillslopeD = metadata.hillslopeD,
            hillslopeSc = metadata.hillslopeSc,
            hillslopeIterations = metadata.hillslopeIterations,
            debrisK = metadata.debrisK,
            debrisCriticalConcentration = metadata.debrisCriticalConcentration,
            debrisSedimentYield = metadata.debrisSedimentYield,
        },
        player = { x = app.player.x, y = app.player.y },
        camera = { yaw = app.camera.yaw, pitch = app.camera.pitch },
        atmosphere = Atmosphere.snapshot(app.atmosphere),
        display = {
            mouseLook = app.mouseLook == true,
            debugPerf = app.debugPerf == true,
            debugTopo = app.debugTopo == true,
            debugPanels = (function()
                if type(app.debugPanels) == "table" then
                    return {
                        plate = app.debugPanels.plate == true,
                        drainage = app.debugPanels.drainage == true,
                        erosion = app.debugPanels.erosion == true,
                        biome = app.debugPanels.biome == true,
                    }
                end
                local on = app.debugPanels == true
                return { plate = on, drainage = on, erosion = on, biome = on }
            end)(),
            viewScale = ViewScale.activeScale(app.viewScale),
        },
        survey = Survey.snapshot(app.survey),
    }
end

function Save.write(path, snapshot)
    local handle = assert(io.open(path, "w"))
    handle:write(Save.encode(snapshot))
    handle:write("\n")
    handle:close()
end

function Save.read(path)
    local handle = assert(io.open(path, "r"))
    local text = handle:read("*a")
    handle:close()
    return Save.decode(text)
end

return Save
