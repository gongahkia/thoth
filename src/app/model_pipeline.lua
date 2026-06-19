local Serialize = require("src.core.serialize")

local ModelPipeline = {}

local function readFile(path)
    local file, err = io.open(path, "rb")
    if not file then
        return nil, err
    end
    local data = file:read("*a")
    file:close()
    return data
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

local function basename(path)
    return tostring(path or ""):match("([^/\\]+)$") or "model.obj"
end

local function idFromPath(path)
    local name = basename(path)
    name = name:gsub("%.%w+$", "")
    return name:gsub("[^%w_]+", "_"):lower()
end

local function updateBounds(bounds, x, y, z)
    bounds.min[1] = math.min(bounds.min[1], x)
    bounds.min[2] = math.min(bounds.min[2], y)
    bounds.min[3] = math.min(bounds.min[3], z)
    bounds.max[1] = math.max(bounds.max[1], x)
    bounds.max[2] = math.max(bounds.max[2], y)
    bounds.max[3] = math.max(bounds.max[3], z)
end

function ModelPipeline.detectFormat(path)
    local ext = tostring(path or ""):match("%.([%w]+)$")
    return ext and ext:lower() or nil
end

function ModelPipeline.parseObj(text)
    local positions, uvs, normals = {}, {}, {}
    local vertices = {}
    local bounds = { min = { math.huge, math.huge, math.huge }, max = { -math.huge, -math.huge, -math.huge } }
    for line in tostring(text or ""):gmatch("[^\r\n]+") do
        local words = {}
        for word in line:gmatch("([^%s]+)") do
            words[#words + 1] = word
        end
        if words[1] == "v" then
            local x, y, z = tonumber(words[2]), tonumber(words[3]), tonumber(words[4])
            if not (x and y and z) then
                return nil, "invalid obj vertex"
            end
            positions[#positions + 1] = { x, y, z }
            updateBounds(bounds, x, y, z)
        elseif words[1] == "vt" then
            uvs[#uvs + 1] = { tonumber(words[2]) or 0, tonumber(words[3]) or 0 }
        elseif words[1] == "vn" then
            normals[#normals + 1] = { tonumber(words[2]) or 0, tonumber(words[3]) or 0, tonumber(words[4]) or 0 }
        elseif words[1] == "f" then
            local face = {}
            for index = 2, #words do
                local v, vt, vn = words[index]:match("^(%-?%d+)/?(%-?%d*)/?(%-?%d*)$")
                v, vt, vn = tonumber(v), tonumber(vt), tonumber(vn)
                if not v or v <= 0 or (vt and vt <= 0) or (vn and vn <= 0) then
                    return nil, "invalid obj face token: " .. tostring(words[index])
                end
                local p = positions[v]
                if not p then
                    return nil, "obj face references missing vertex"
                end
                local uv = vt and uvs[vt] or nil
                local normal = vn and normals[vn] or nil
                face[#face + 1] = {
                    p[1], p[2], p[3],
                    uv and uv[1] or 0, uv and uv[2] or 0,
                    normal and normal[1] or 0, normal and normal[2] or 0, normal and normal[3] or 0,
                }
            end
            if #face < 3 then
                return nil, "obj face has fewer than 3 vertices"
            end
            for index = 2, #face - 1 do
                vertices[#vertices + 1] = face[1]
                vertices[#vertices + 1] = face[index]
                vertices[#vertices + 1] = face[index + 1]
            end
        end
    end
    if #vertices == 0 then
        return nil, "obj has no triangles"
    end
    return {
        format = "obj",
        vertices = vertices,
        vertexCount = #vertices,
        triangleCount = #vertices / 3,
        bounds = bounds,
    }
end

function ModelPipeline.manifestEntry(result, sourcePath, modelPath, id)
    return {
        id = id or idFromPath(modelPath),
        format = result.format,
        path = modelPath,
        source = sourcePath,
        vertices = result.vertexCount,
        triangles = result.triangleCount,
        bounds = result.bounds,
    }
end

function ModelPipeline.manifestText(entries)
    return "return " .. Serialize.encode({ generatedBy = "src/app/model_pipeline.lua", models = entries }) .. "\n"
end

function ModelPipeline.loadManifest(text)
    local body = tostring(text or ""):match("^%s*return%s+(.+)$") or text
    return Serialize.decode(body)
end

function ModelPipeline.import(sourcePath, modelPath, manifestPath, options)
    options = options or {}
    local format = ModelPipeline.detectFormat(sourcePath)
    if format ~= "obj" then
        return nil, "g3d import currently requires obj source"
    end
    local text, err = readFile(sourcePath)
    if not text then
        return nil, err
    end
    local parsed
    parsed, err = ModelPipeline.parseObj(text)
    if not parsed then
        return nil, err
    end
    local wrote
    wrote, err = writeFile(modelPath, text)
    if not wrote then
        return nil, err
    end
    local entry = ModelPipeline.manifestEntry(parsed, sourcePath, modelPath, options.id)
    wrote, err = writeFile(manifestPath, ModelPipeline.manifestText({ entry }))
    if not wrote then
        return nil, err
    end
    parsed.entry = entry
    return parsed
end

function ModelPipeline.newG3dModel(g3d, parsed, texture, transform)
    if not (g3d and parsed and parsed.vertices) then
        return nil, "missing g3d model input"
    end
    local model = g3d.newModel(parsed.vertices, texture, transform and transform.translation, transform and transform.rotation, transform and transform.scale)
    model:makeNormals()
    return model
end

return ModelPipeline
