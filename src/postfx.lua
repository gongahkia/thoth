local PostFX = {}

local validScales = { [2] = true, [3] = true, [4] = true }

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
    love.graphics.draw(canvas, 0, 0, 0, scale, scale)
    stats = drawHud(width, height, stats) or stats or {}
    stats.pixelScale = scale
    stats.lowResCanvasWidth = canvasWidth
    stats.lowResCanvasHeight = canvasHeight
    return stats
end

return PostFX
