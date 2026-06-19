local Serialize = require("src.core.serialize")

local SpritePipeline = {}

local function positiveInteger(value, name)
    value = tonumber(value)
    if not value or value < 1 or value % 1 ~= 0 then
        return nil, name .. " must be a positive integer"
    end
    return value
end

local function writeFile(path, data)
    local file, err = io.open(path, "wb")
    if not file then
        return nil, err
    end
    file:write(data)
    file:close()
    return true
end

function SpritePipeline.parseFrameSize(value)
    local width, height = tostring(value or ""):match("^(%d+)x(%d+)$")
    width = tonumber(width)
    height = tonumber(height)
    if not width or not height then
        return nil, "frame size must use WxH"
    end
    return width, height
end

function SpritePipeline.plan(sourceWidth, sourceHeight, options)
    options = options or {}
    local frameWidth, err = positiveInteger(options.frameWidth or 16, "frameWidth")
    if not frameWidth then
        return nil, err
    end
    local frameHeight
    frameHeight, err = positiveInteger(options.frameHeight or frameWidth, "frameHeight")
    if not frameHeight then
        return nil, err
    end
    sourceWidth, err = positiveInteger(sourceWidth, "sourceWidth")
    if not sourceWidth then
        return nil, err
    end
    sourceHeight, err = positiveInteger(sourceHeight, "sourceHeight")
    if not sourceHeight then
        return nil, err
    end
    if sourceWidth % frameWidth ~= 0 then
        return nil, "source width must be divisible by frame width"
    end
    if sourceHeight % frameHeight ~= 0 then
        return nil, "source height must be divisible by frame height"
    end
    local sourceColumns = sourceWidth / frameWidth
    local sourceRows = sourceHeight / frameHeight
    local frames = sourceColumns * sourceRows
    local columns
    columns, err = positiveInteger(options.columns or sourceColumns, "columns")
    if not columns then
        return nil, err
    end
    local rows = math.ceil(frames / columns)
    return {
        sourceWidth = sourceWidth,
        sourceHeight = sourceHeight,
        sourceColumns = sourceColumns,
        sourceRows = sourceRows,
        frameWidth = frameWidth,
        frameHeight = frameHeight,
        columns = columns,
        rows = rows,
        frames = frames,
        atlasWidth = columns * frameWidth,
        atlasHeight = rows * frameHeight,
    }
end

function SpritePipeline.frameRect(plan, frame)
    local index = (frame or 1) - 1
    if index < 0 or index >= plan.frames then
        return nil, "frame out of range"
    end
    return {
        sourceX = (index % plan.sourceColumns) * plan.frameWidth,
        sourceY = math.floor(index / plan.sourceColumns) * plan.frameHeight,
        atlasX = (index % plan.columns) * plan.frameWidth,
        atlasY = math.floor(index / plan.columns) * plan.frameHeight,
        width = plan.frameWidth,
        height = plan.frameHeight,
    }
end

function SpritePipeline.manifest(plan, imagePath, sourcePath)
    return {
        image = imagePath,
        source = sourcePath,
        frameWidth = plan.frameWidth,
        frameHeight = plan.frameHeight,
        columns = plan.columns,
        rows = plan.rows,
        frames = plan.frames,
        atlasWidth = plan.atlasWidth,
        atlasHeight = plan.atlasHeight,
        generatedBy = "src/app/sprite_pipeline.lua",
    }
end

function SpritePipeline.manifestText(plan, imagePath, sourcePath)
    return "return " .. Serialize.encode(SpritePipeline.manifest(plan, imagePath, sourcePath)) .. "\n"
end

function SpritePipeline.loadManifest(text)
    local body = tostring(text or ""):match("^%s*return%s+(.+)$") or text
    return Serialize.decode(body)
end

function SpritePipeline.importWithLove(sourcePath, atlasPath, manifestPath, options)
    if not (love and love.image) then
        return nil, "love.image unavailable"
    end
    local ok, sourceOrErr = pcall(love.image.newImageData, sourcePath)
    if not ok then
        return nil, sourceOrErr
    end
    local source = sourceOrErr
    local plan, err = SpritePipeline.plan(source:getWidth(), source:getHeight(), options)
    if not plan then
        return nil, err
    end
    local atlas = love.image.newImageData(plan.atlasWidth, plan.atlasHeight)
    for frame = 1, plan.frames do
        local rect = SpritePipeline.frameRect(plan, frame)
        atlas:paste(source, rect.atlasX, rect.atlasY, rect.sourceX, rect.sourceY, rect.width, rect.height)
    end
    local data = atlas:encode("png"):getString()
    local wrote
    wrote, err = writeFile(atlasPath, data)
    if not wrote then
        return nil, err
    end
    wrote, err = writeFile(manifestPath, SpritePipeline.manifestText(plan, atlasPath, sourcePath))
    if not wrote then
        return nil, err
    end
    plan.atlasPath = atlasPath
    plan.manifestPath = manifestPath
    return plan
end

return SpritePipeline
