local I18n = {}

local locale = "en"

local function loadStrings(localeKey)
    local ok, data = pcall(require, "src.game.data.i18n." .. tostring(localeKey or "en"))
    if ok and type(data) == "table" then
        return type(data.strings) == "table" and data.strings or data
    end
    return {}
end

local strings = loadStrings(locale)

local function interpolate(text, vars)
    return (tostring(text or ""):gsub("{([%w_]+)}", function(key)
        local value = vars and vars[key]
        return value == nil and ("{" .. key .. "}") or tostring(value)
    end))
end

function I18n.t(key, vars)
    if key == nil then
        return ""
    end
    local text = strings[key] or tostring(key)
    if vars then
        return interpolate(text, vars)
    end
    return text
end

function I18n.use(localeKey)
    locale = localeKey or "en"
    strings = loadStrings(locale)
    return strings
end

function I18n.locale()
    return locale
end

function I18n.has(key)
    return key ~= nil and strings[key] ~= nil
end

function I18n.strings()
    return strings
end

return I18n
