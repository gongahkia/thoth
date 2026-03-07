local tilemap = {}

local Tilemap = {}
Tilemap.__index = Tilemap

function Tilemap.new(width, height, tileWidth, tileHeight)
    assert(type(width) == "number" and width > 0, "Tilemap width must be > 0")
    assert(type(height) == "number" and height > 0, "Tilemap height must be > 0")

    local self = setmetatable({}, Tilemap)
    self.width = width
    self.height = height
    self.tileWidth = tileWidth or 1
    self.tileHeight = tileHeight or self.tileWidth
    self.layers = {}
    return self
end

function Tilemap:addLayer(name, data)
    assert(type(name) == "string" and #name > 0, "Layer name must be a non-empty string")
    assert(type(data) == "table", "Layer data must be a table")
    self.layers[name] = data
    return self
end

function Tilemap:getLayer(name)
    return self.layers[name]
end

function Tilemap:getTile(name, x, y)
    local layer = assert(self.layers[name], "Layer '" .. tostring(name) .. "' not found")
    return layer[y] and layer[y][x] or nil
end

function Tilemap:setTile(name, x, y, value)
    local layer = assert(self.layers[name], "Layer '" .. tostring(name) .. "' not found")
    layer[y] = layer[y] or {}
    layer[y][x] = value
    return self
end

function Tilemap:isWalkable(name, x, y, walkable)
    walkable = walkable or function(value)
        return value ~= 0 and value ~= false and value ~= nil
    end
    return walkable(self:getTile(name, x, y), x, y)
end

function Tilemap:cellToWorld(x, y)
    return (x - 1) * self.tileWidth, (y - 1) * self.tileHeight
end

function Tilemap:worldToCell(worldX, worldY)
    return math.floor(worldX / self.tileWidth) + 1, math.floor(worldY / self.tileHeight) + 1
end

function Tilemap:eachCell(name, callback)
    local layer = assert(self.layers[name], "Layer '" .. tostring(name) .. "' not found")
    for y = 1, self.height do
        for x = 1, self.width do
            callback(x, y, layer[y] and layer[y][x] or nil)
        end
    end
end

tilemap.Tilemap = Tilemap

function tilemap.new(width, height, tileWidth, tileHeight)
    return Tilemap.new(width, height, tileWidth, tileHeight)
end

return tilemap
