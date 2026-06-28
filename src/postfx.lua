local PostFX = {}
local Atmosphere = require("src.atmosphere")

local validScales = { [2] = true, [3] = true, [4] = true }
local paletteSize = 32
local paletteShaderSource = [[
extern Image paletteTex;
extern number paletteSize;

vec4 effect(vec4 color, Image texture, vec2 textureCoords, vec2 screenCoords)
{
    vec4 src = Texel(texture, textureCoords) * color;
    vec3 best = Texel(paletteTex, vec2(0.5 / paletteSize, 0.5)).rgb;
    number bestDistance = dot(src.rgb - best, src.rgb - best);
    for (int i = 1; i < 32; i++) {
        if (float(i) >= paletteSize) { break; }
        vec3 candidate = Texel(paletteTex, vec2((float(i) + 0.5) / paletteSize, 0.5)).rgb;
        number distance = dot(src.rgb - candidate, src.rgb - candidate);
        if (distance < bestDistance) {
            best = candidate;
            bestDistance = distance;
        }
    }
    return vec4(best, src.a);
}
]]

local palettes = {
    ["local"] = {
        { 0.025, 0.03, 0.04 }, { 0.05, 0.07, 0.08 }, { 0.08, 0.09, 0.08 }, { 0.09, 0.13, 0.18 },
        { 0.04, 0.12, 0.28 }, { 0.06, 0.25, 0.42 }, { 0.1, 0.42, 0.68 }, { 0.32, 0.58, 0.72 },
        { 0.06, 0.18, 0.1 }, { 0.1, 0.28, 0.13 }, { 0.18, 0.36, 0.18 }, { 0.34, 0.52, 0.22 },
        { 0.53, 0.58, 0.28 }, { 0.72, 0.63, 0.36 }, { 0.82, 0.73, 0.43 }, { 0.5, 0.42, 0.22 },
        { 0.28, 0.24, 0.2 }, { 0.36, 0.34, 0.31 }, { 0.48, 0.47, 0.42 }, { 0.62, 0.6, 0.53 },
        { 0.76, 0.68, 0.42 }, { 0.84, 0.78, 0.58 }, { 0.68, 0.74, 0.75 }, { 0.43, 0.55, 0.66 },
        { 0.6, 0.68, 0.69 }, { 0.78, 0.82, 0.78 }, { 0.86, 0.88, 0.84 }, { 0.92, 0.9, 0.76 },
        { 0.33, 0.22, 0.2 }, { 0.46, 0.28, 0.24 }, { 0.62, 0.4, 0.28 }, { 0.88, 0.56, 0.35 },
    },
    region = {
        { 0.02, 0.025, 0.04 }, { 0.05, 0.05, 0.08 }, { 0.08, 0.08, 0.12 }, { 0.12, 0.1, 0.16 },
        { 0.04, 0.1, 0.22 }, { 0.05, 0.18, 0.34 }, { 0.09, 0.32, 0.52 }, { 0.24, 0.48, 0.64 },
        { 0.07, 0.15, 0.12 }, { 0.13, 0.24, 0.16 }, { 0.24, 0.36, 0.19 }, { 0.42, 0.48, 0.22 },
        { 0.58, 0.52, 0.28 }, { 0.74, 0.58, 0.32 }, { 0.88, 0.68, 0.38 }, { 0.48, 0.34, 0.22 },
        { 0.24, 0.22, 0.23 }, { 0.34, 0.31, 0.32 }, { 0.48, 0.43, 0.4 }, { 0.64, 0.56, 0.48 },
        { 0.76, 0.66, 0.42 }, { 0.9, 0.78, 0.52 }, { 0.62, 0.6, 0.67 }, { 0.38, 0.44, 0.58 },
        { 0.58, 0.64, 0.66 }, { 0.76, 0.78, 0.72 }, { 0.88, 0.86, 0.78 }, { 0.96, 0.88, 0.7 },
        { 0.28, 0.16, 0.18 }, { 0.44, 0.22, 0.22 }, { 0.64, 0.34, 0.26 }, { 0.86, 0.48, 0.32 },
    },
    continent = {
        { 0.02, 0.03, 0.05 }, { 0.04, 0.06, 0.09 }, { 0.07, 0.09, 0.11 }, { 0.1, 0.12, 0.14 },
        { 0.03, 0.09, 0.2 }, { 0.05, 0.17, 0.32 }, { 0.08, 0.3, 0.48 }, { 0.2, 0.44, 0.58 },
        { 0.06, 0.16, 0.13 }, { 0.12, 0.26, 0.18 }, { 0.22, 0.36, 0.24 }, { 0.36, 0.48, 0.3 },
        { 0.5, 0.54, 0.36 }, { 0.66, 0.62, 0.42 }, { 0.78, 0.72, 0.5 }, { 0.44, 0.4, 0.3 },
        { 0.22, 0.24, 0.24 }, { 0.32, 0.34, 0.34 }, { 0.46, 0.48, 0.46 }, { 0.6, 0.62, 0.56 },
        { 0.7, 0.68, 0.5 }, { 0.82, 0.78, 0.58 }, { 0.6, 0.68, 0.76 }, { 0.36, 0.48, 0.64 },
        { 0.64, 0.72, 0.74 }, { 0.76, 0.82, 0.78 }, { 0.86, 0.88, 0.84 }, { 0.94, 0.92, 0.82 },
        { 0.24, 0.2, 0.22 }, { 0.38, 0.28, 0.27 }, { 0.56, 0.4, 0.34 }, { 0.78, 0.58, 0.42 },
    },
}

function PostFX.parsePixelScale(value)
    local scale = tonumber(value or 2)
    if not scale or scale ~= math.floor(scale) or not validScales[scale] then
        error("--pixel-scale must be 2, 3, or 4", 2)
    end
    return scale
end

function PostFX.lowResSize(width, height, scale)
    return math.max(1, math.floor(width / scale)), math.max(1, math.floor(height / scale))
end

function PostFX.paletteFor(id, atmosphere)
    local base = palettes[id] or palettes["local"]
    if atmosphere then return Atmosphere.palette(base, atmosphere) end
    return base
end

function PostFX.paletteIds()
    return { "local", "region", "continent" }
end

function PostFX.activePaletteId(app)
    return (app and app.viewScale and app.viewScale.target) or "local"
end

local function ensurePaletteTexture(app)
    local id = PostFX.activePaletteId(app)
    local key = id .. ":" .. Atmosphere.paletteKey(app.atmosphere)
    local palette = PostFX.paletteFor(id, app.atmosphere)
    if app.paletteTexture and app.paletteTextureId == key then return app.paletteTexture, id, #palette end
    local imageData = love.image.newImageData(#palette, 1)
    for index, color in ipairs(palette) do imageData:setPixel(index - 1, 0, color[1], color[2], color[3], 1) end
    app.paletteTexture = love.graphics.newImage(imageData)
    app.paletteTexture:setFilter("nearest", "nearest")
    app.paletteTextureId = key
    return app.paletteTexture, id, #palette
end

local function paletteShader(app)
    app.shaders = app.shaders or {}
    if not app.shaders.paletteQuantize then app.shaders.paletteQuantize = love.graphics.newShader(paletteShaderSource) end
    return app.shaders.paletteQuantize
end

function PostFX.ensureCanvas(app, width, height)
    local scale = app.pixelScale or 2
    local canvasWidth, canvasHeight = PostFX.lowResSize(width, height, scale)
    if app.lowResCanvas and app.lowResCanvasWidth == canvasWidth and app.lowResCanvasHeight == canvasHeight and app.lowResCanvasScale == scale then
        return app.lowResCanvas, canvasWidth, canvasHeight, scale
    end
    app.lowResCanvas = love.graphics.newCanvas(canvasWidth, canvasHeight)
    app.lowResCanvas:setFilter("nearest", "nearest")
    app.lowResCanvasWidth = canvasWidth
    app.lowResCanvasHeight = canvasHeight
    app.lowResCanvasScale = scale
    return app.lowResCanvas, canvasWidth, canvasHeight, scale
end

function PostFX.resize(app, width, height)
    if not app then return end
    app.lowResCanvas = nil
    return PostFX.ensureCanvas(app, width, height)
end

function PostFX.draw(app, drawScene, drawHud)
    local width, height = love.graphics.getDimensions()
    local canvas, canvasWidth, canvasHeight, scale = PostFX.ensureCanvas(app, width, height)
    love.graphics.push("all")
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 1)
    local stats = drawScene(canvasWidth, canvasHeight)
    love.graphics.pop()

    love.graphics.clear(0, 0, 0, 1)
    love.graphics.setColor(1, 1, 1, 1)
    local palette, paletteId, colors = ensurePaletteTexture(app)
    local shader = paletteShader(app)
    shader:send("paletteTex", palette)
    shader:send("paletteSize", colors)
    love.graphics.setShader(shader)
    love.graphics.draw(canvas, 0, 0, 0, scale, scale)
    love.graphics.setShader()
    stats = drawHud(width, height, stats) or stats or {}
    stats.pixelScale = scale
    stats.lowResCanvasWidth = canvasWidth
    stats.lowResCanvasHeight = canvasHeight
    stats.paletteId = paletteId
    stats.paletteSize = colors
    stats.paletteKey = app.paletteTextureId
    return stats
end

return PostFX
