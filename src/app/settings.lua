local Serialize = require("src.core.serialize")

local Settings = {}

local colorblindModes = { "off", "deuteranopia", "protanopia", "tritanopia" }
local settingsVersion = 1
local settingsHeader = "THOTH_LUA_SETTINGS"

local defaultKeybinds = {
    moveUp = "w",
    moveDown = "s",
    moveLeft = "a",
    moveRight = "d",
    interact = "space",
    pause = "escape",
}

local keybindActions = {
    "moveUp",
    "moveDown",
    "moveLeft",
    "moveRight",
    "interact",
    "pause",
}

local controls = {
    { kind = "slider", setting = "masterVolume", label = "Master Volume", step = 0.1, min = 0, max = 1 },
    { kind = "slider", setting = "musicVolume", label = "Music Volume", step = 0.1, min = 0, max = 1 },
    { kind = "slider", setting = "sfxVolume", label = "SFX Volume", step = 0.1, min = 0, max = 1 },
    { kind = "bind", binding = "moveUp", label = "Move Up" },
    { kind = "bind", binding = "moveDown", label = "Move Down" },
    { kind = "bind", binding = "moveLeft", label = "Move Left" },
    { kind = "bind", binding = "moveRight", label = "Move Right" },
    { kind = "bind", binding = "interact", label = "Interact" },
    { kind = "bind", binding = "pause", label = "Pause" },
    { kind = "toggle", setting = "highContrast", label = "High Contrast" },
    { kind = "cycle", setting = "colorblindMode", label = "Colorblind Mode" },
    { kind = "toggle", setting = "reducedMotion", label = "Reduced Motion" },
    { kind = "toggle", setting = "subtitles", label = "Subtitles" },
    { kind = "slider", setting = "fontScale", label = "Font Scale", step = 0.05, min = 0.8, max = 1.4 },
    { kind = "back", label = "Back" },
}

local function copyMap(source)
    local result = {}
    for key, value in pairs(source or {}) do
        result[key] = value
    end
    return result
end

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function validColorblindMode(value)
    for _, mode in ipairs(colorblindModes) do
        if mode == value then
            return true
        end
    end
    return false
end

local function validBindingKey(key)
    return type(key) == "string" and key ~= "escape" and key ~= "return" and key ~= "kpenter"
end

function Settings.defaults()
    return {
        masterVolume = 1,
        musicVolume = 0.8,
        sfxVolume = 1,
        highContrast = false,
        colorblindMode = "off",
        reducedMotion = false,
        subtitles = true,
        fontScale = 1,
        keybinds = copyMap(defaultKeybinds),
    }
end

function Settings.normalize(source)
    source = type(source) == "table" and source or {}
    local result = Settings.defaults()
    for _, control in ipairs(controls) do
        local setting = control.setting
        if control.kind == "slider" and type(source[setting]) == "number" then
            result[setting] = clamp(source[setting], control.min, control.max)
        elseif control.kind == "toggle" and type(source[setting]) == "boolean" then
            result[setting] = source[setting]
        elseif control.kind == "cycle" and validColorblindMode(source[setting]) then
            result[setting] = source[setting]
        end
    end
    local used = {}
    for _, action in ipairs(keybindActions) do
        used[result.keybinds[action]] = true
    end
    local sourceKeybinds = type(source.keybinds) == "table" and source.keybinds or {}
    for _, action in ipairs(keybindActions) do
        local key = sourceKeybinds[action]
        if validBindingKey(key) and (not used[key] or result.keybinds[action] == key) then
            used[result.keybinds[action]] = nil
            result.keybinds[action] = key
            used[key] = true
        end
    end
    return result
end

function Settings.toText(settings)
    return settingsHeader .. " " .. tostring(settingsVersion) .. "\n" .. Serialize.encode(Settings.normalize(settings)) .. "\n"
end

function Settings.fromText(text)
    local version, body = tostring(text or ""):match("^" .. settingsHeader .. "%s+(%d+)%s+(.+)$")
    if not version then
        return nil, "bad settings header"
    end
    if tonumber(version) ~= settingsVersion then
        return nil, "unsupported settings version " .. tostring(version)
    end
    local decoded, err = Serialize.decode(body)
    if type(decoded) ~= "table" then
        return nil, err or "bad settings body"
    end
    return Settings.normalize(decoded)
end

function Settings.write(settings, path)
    local text = Settings.toText(settings)
    if love and love.filesystem then
        return love.filesystem.write(path, text)
    end
    local file, err = io.open(path, "w")
    if not file then
        return false, err
    end
    file:write(text)
    file:close()
    return true
end

function Settings.read(path)
    local text
    if love and love.filesystem then
        text = love.filesystem.read(path)
    else
        local file, err = io.open(path, "r")
        if not file then
            return nil, err
        end
        text = file:read("*a")
        file:close()
    end
    if not text then
        return nil, "settings not found"
    end
    return Settings.fromText(text)
end

function Settings.controls()
    return controls
end

function Settings.keyForAction(settings, action, fallback)
    local keybinds = settings and settings.keybinds or defaultKeybinds
    return keybinds[action] or defaultKeybinds[action] or fallback
end

function Settings.isAction(settings, key, action, fallback)
    return key == Settings.keyForAction(settings, action, fallback)
end

function Settings.adjust(settings, setting, delta)
    for _, control in ipairs(controls) do
        if control.kind == "slider" and control.setting == setting then
            settings[setting] = clamp((settings[setting] or 0) + (delta or 0) * control.step, control.min, control.max)
            return true
        end
    end
    return false
end

function Settings.toggle(settings, setting)
    if type(settings[setting]) ~= "boolean" then
        return false
    end
    settings[setting] = not settings[setting]
    return true
end

function Settings.cycle(settings, setting, delta)
    if setting ~= "colorblindMode" then
        return false
    end
    local current = settings.colorblindMode or "off"
    local index = 1
    for candidate, mode in ipairs(colorblindModes) do
        if mode == current then
            index = candidate
            break
        end
    end
    index = ((index - 1 + (delta or 1)) % #colorblindModes) + 1
    settings.colorblindMode = colorblindModes[index]
    return true
end

function Settings.bindKey(settings, action, key)
    if key == "escape" or key == "return" or key == "kpenter" then
        return false, "reserved key"
    end
    settings.keybinds = settings.keybinds or copyMap(defaultKeybinds)
    for otherAction, otherKey in pairs(settings.keybinds) do
        if otherAction ~= action and otherKey == key then
            return false, "key already bound"
        end
    end
    settings.keybinds[action] = key
    return true
end

function Settings.valueText(settings, control)
    if control.kind == "slider" then
        return tostring(math.floor(((settings[control.setting] or 0) * 100) + 0.5)) .. "%"
    end
    if control.kind == "toggle" then
        return settings[control.setting] and "on" or "off"
    end
    if control.kind == "cycle" then
        return settings[control.setting] or "off"
    end
    if control.kind == "bind" then
        return Settings.keyForAction(settings, control.binding, "-")
    end
    return ""
end

return Settings
