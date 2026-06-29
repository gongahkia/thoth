local Atmosphere = {}

local seasons = { "spring", "summer", "autumn", "winter" }
local seasonIndex = { spring = 1, summer = 2, autumn = 3, winter = 4 }
local timeKeys = {
    { id = "dawn", time = 0 },
    { id = "noon", time = 0.25 },
    { id = "dusk", time = 0.5 },
    { id = "night", time = 0.75 },
    { id = "dawn", time = 1 },
}

local grades = {
    spring = {
        dawn = { tint = { 1.05, 0.94, 0.86 }, lift = { 0.035, 0.025, 0.03 }, exposure = 0.84, saturation = 0.9 },
        noon = { tint = { 0.96, 1.06, 0.96 }, lift = { 0.01, 0.025, 0.012 }, exposure = 1.05, saturation = 1.05 },
        dusk = { tint = { 1.08, 0.9, 0.82 }, lift = { 0.04, 0.015, 0.02 }, exposure = 0.82, saturation = 0.95 },
        night = { tint = { 0.42, 0.5, 0.78 }, lift = { 0.005, 0.008, 0.035 }, exposure = 0.42, saturation = 0.72 },
    },
    summer = {
        dawn = { tint = { 1.1, 0.92, 0.76 }, lift = { 0.045, 0.022, 0.018 }, exposure = 0.88, saturation = 0.95 },
        noon = { tint = { 1.05, 1.02, 0.88 }, lift = { 0.018, 0.018, 0.005 }, exposure = 1.08, saturation = 1.08 },
        dusk = { tint = { 1.14, 0.82, 0.66 }, lift = { 0.055, 0.018, 0.01 }, exposure = 0.8, saturation = 1.0 },
        night = { tint = { 0.35, 0.44, 0.82 }, lift = { 0.004, 0.006, 0.036 }, exposure = 0.38, saturation = 0.68 },
    },
    autumn = {
        dawn = { tint = { 1.12, 0.86, 0.72 }, lift = { 0.045, 0.016, 0.012 }, exposure = 0.82, saturation = 0.98 },
        noon = { tint = { 1.08, 0.93, 0.76 }, lift = { 0.025, 0.012, 0.004 }, exposure = 0.98, saturation = 1.02 },
        dusk = { tint = { 1.18, 0.74, 0.58 }, lift = { 0.06, 0.012, 0.006 }, exposure = 0.74, saturation = 1.05 },
        night = { tint = { 0.42, 0.4, 0.72 }, lift = { 0.006, 0.005, 0.03 }, exposure = 0.36, saturation = 0.66 },
    },
    winter = {
        dawn = { tint = { 0.82, 0.9, 1.12 }, lift = { 0.018, 0.024, 0.045 }, exposure = 0.8, saturation = 0.72 },
        noon = { tint = { 0.82, 0.96, 1.12 }, lift = { 0.014, 0.02, 0.035 }, exposure = 0.94, saturation = 0.78 },
        dusk = { tint = { 0.9, 0.78, 1.0 }, lift = { 0.026, 0.014, 0.04 }, exposure = 0.7, saturation = 0.68 },
        night = { tint = { 0.32, 0.4, 0.78 }, lift = { 0.004, 0.008, 0.04 }, exposure = 0.34, saturation = 0.58 },
    },
}

local function clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

local function mix(a, b, t)
    return a + (b - a) * t
end

local function mixColor(a, b, t)
    return { mix(a[1], b[1], t), mix(a[2], b[2], t), mix(a[3], b[3], t) }
end

local function mixGrade(a, b, t)
    return {
        tint = mixColor(a.tint, b.tint, t),
        lift = mixColor(a.lift, b.lift, t),
        exposure = mix(a.exposure, b.exposure, t),
        saturation = mix(a.saturation, b.saturation, t),
    }
end

function Atmosphere.new(options)
    options = options or {}
    local season = options.season or "summer"
    if not seasonIndex[season] then season = "summer" end
    return {
        time = (tonumber(options.time) or 0.25) % 1,
        season = season,
        dayLength = math.max(1, tonumber(options.dayLength) or 60),
    }
end

function Atmosphere.update(atmosphere, dt)
    if not atmosphere then return nil end
    atmosphere.time = ((atmosphere.time or 0) + (dt or 0) / math.max(1, atmosphere.dayLength or 60)) % 1
    return atmosphere
end

function Atmosphere.shiftSeason(atmosphere, delta)
    if not atmosphere then return nil end
    local index = seasonIndex[atmosphere.season] or 2
    index = ((index - 1 + (delta or 0)) % #seasons) + 1
    atmosphere.season = seasons[index]
    return atmosphere.season
end

function Atmosphere.seasons()
    local out = {}
    for index, season in ipairs(seasons) do out[index] = season end
    return out
end

function Atmosphere.grade(atmosphere)
    local state = atmosphere or Atmosphere.new()
    local time = (state.time or 0.25) % 1
    local season = seasonIndex[state.season] and state.season or "summer"
    local seasonGrades = grades[season]
    for index = 1, #timeKeys - 1 do
        local a, b = timeKeys[index], timeKeys[index + 1]
        if time >= a.time and time <= b.time then
            local span = b.time - a.time
            local t = span > 0 and (time - a.time) / span or 0
            return mixGrade(seasonGrades[a.id], seasonGrades[b.id], t)
        end
    end
    return seasonGrades.noon
end

function Atmosphere.palette(basePalette, atmosphere)
    local grade = Atmosphere.grade(atmosphere)
    local out = {}
    for index, color in ipairs(basePalette or {}) do
        local gray = (color[1] + color[2] + color[3]) / 3
        local r = gray + (color[1] - gray) * grade.saturation
        local g = gray + (color[2] - gray) * grade.saturation
        local b = gray + (color[3] - gray) * grade.saturation
        out[index] = {
            clamp(r * grade.tint[1] * grade.exposure + grade.lift[1], 0, 1),
            clamp(g * grade.tint[2] * grade.exposure + grade.lift[2], 0, 1),
            clamp(b * grade.tint[3] * grade.exposure + grade.lift[3], 0, 1),
        }
    end
    return out
end

function Atmosphere.paletteKey(atmosphere)
    local state = atmosphere or Atmosphere.new()
    local step = math.floor(((state.time or 0) % 1) * 240 + 0.5)
    return tostring(state.season or "summer") .. ":" .. tostring(step)
end

function Atmosphere.sunDirection(atmosphere)
    local state = atmosphere or Atmosphere.new()
    local time = (state.time or 0.25) % 1
    local angle = (time - 0.25) * math.pi * 2 -- noon = 0, dawn = -π/2, dusk = π/2
    local zenith = math.cos(angle) -- sun height above horizon, negative at night
    local horizon = -math.sin(angle) -- dawn east (+x), dusk west (-x)
    local elev = math.max(0.18, zenith) -- keep a soft floor so night still has shading
    local x = horizon * 0.85
    local y = -0.3
    local z = elev
    local length = math.sqrt(x * x + y * y + z * z)
    if length <= 0 then return { x = 0, y = 0, z = 1, daylight = 0 } end
    return {
        x = x / length,
        y = y / length,
        z = z / length,
        daylight = clamp(zenith, 0, 1),
    }
end

function Atmosphere.snapshot(atmosphere)
    return {
        time = atmosphere and atmosphere.time or 0.25,
        season = atmosphere and atmosphere.season or "summer",
        dayLength = atmosphere and atmosphere.dayLength or 60,
    }
end

return Atmosphere
