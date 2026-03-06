local spatial = {}

local function intersects(a, b)
    return not (
        a.x + a.width < b.x or
        a.x > b.x + b.width or
        a.y + a.height < b.y or
        a.y > b.y + b.height
    )
end

local SpatialHash = {}
SpatialHash.__index = SpatialHash

function SpatialHash.new(cellSize)
    local self = setmetatable({}, SpatialHash)
    self.cellSize = cellSize or 64
    self.buckets = {}
    self.objects = {}
    return self
end

function SpatialHash:_key(cx, cy)
    return tostring(cx) .. ":" .. tostring(cy)
end

function SpatialHash:_cellsForRect(rect)
    local minX = math.floor(rect.x / self.cellSize)
    local minY = math.floor(rect.y / self.cellSize)
    local maxX = math.floor((rect.x + rect.width) / self.cellSize)
    local maxY = math.floor((rect.y + rect.height) / self.cellSize)

    local cells = {}
    for cy = minY, maxY do
        for cx = minX, maxX do
            table.insert(cells, self:_key(cx, cy))
        end
    end
    return cells
end

function SpatialHash:insert(id, x, y, width, height, data)
    self:remove(id)

    local rect = {
        id = id,
        x = x,
        y = y,
        width = width or 0,
        height = height or 0,
        data = data
    }
    rect.cells = self:_cellsForRect(rect)
    self.objects[id] = rect

    for _, key in ipairs(rect.cells) do
        self.buckets[key] = self.buckets[key] or {}
        self.buckets[key][id] = true
    end
end

function SpatialHash:remove(id)
    local rect = self.objects[id]
    if not rect then
        return
    end

    for _, key in ipairs(rect.cells or {}) do
        local bucket = self.buckets[key]
        if bucket then
            bucket[id] = nil
            if not next(bucket) then
                self.buckets[key] = nil
            end
        end
    end

    self.objects[id] = nil
end

function SpatialHash:update(id, x, y, width, height, data)
    self:insert(id, x, y, width, height, data)
end

function SpatialHash:queryRange(x, y, width, height)
    local queryRect = {x = x, y = y, width = width, height = height}
    local ids = {}
    local results = {}

    for _, key in ipairs(self:_cellsForRect(queryRect)) do
        local bucket = self.buckets[key]
        if bucket then
            for id in pairs(bucket) do
                if not ids[id] and self.objects[id] and intersects(self.objects[id], queryRect) then
                    ids[id] = true
                    table.insert(results, self.objects[id])
                end
            end
        end
    end

    return results
end

function SpatialHash:clear()
    self.buckets = {}
    self.objects = {}
end

local Quadtree = {}
Quadtree.__index = Quadtree

function Quadtree.new(bounds, maxObjects, maxLevels, level)
    local self = setmetatable({}, Quadtree)
    self.level = level or 0
    self.bounds = bounds
    self.maxObjects = maxObjects or 8
    self.maxLevels = maxLevels or 6
    self.objects = {}
    self.nodes = {}
    return self
end

function Quadtree:clear()
    self.objects = {}
    for i = 1, #self.nodes do
        self.nodes[i]:clear()
    end
    self.nodes = {}
end

function Quadtree:split()
    local subWidth = self.bounds.width / 2
    local subHeight = self.bounds.height / 2
    local x = self.bounds.x
    local y = self.bounds.y
    local nextLevel = self.level + 1

    self.nodes[1] = Quadtree.new({x = x + subWidth, y = y, width = subWidth, height = subHeight}, self.maxObjects, self.maxLevels, nextLevel)
    self.nodes[2] = Quadtree.new({x = x, y = y, width = subWidth, height = subHeight}, self.maxObjects, self.maxLevels, nextLevel)
    self.nodes[3] = Quadtree.new({x = x, y = y + subHeight, width = subWidth, height = subHeight}, self.maxObjects, self.maxLevels, nextLevel)
    self.nodes[4] = Quadtree.new({x = x + subWidth, y = y + subHeight, width = subWidth, height = subHeight}, self.maxObjects, self.maxLevels, nextLevel)
end

function Quadtree:getIndex(rect)
    local index = -1
    local verticalMidpoint = self.bounds.x + (self.bounds.width / 2)
    local horizontalMidpoint = self.bounds.y + (self.bounds.height / 2)

    local topQuadrant = rect.y < horizontalMidpoint and rect.y + rect.height <= horizontalMidpoint
    local bottomQuadrant = rect.y >= horizontalMidpoint

    if rect.x < verticalMidpoint and rect.x + rect.width <= verticalMidpoint then
        if topQuadrant then
            index = 2
        elseif bottomQuadrant then
            index = 3
        end
    elseif rect.x >= verticalMidpoint then
        if topQuadrant then
            index = 1
        elseif bottomQuadrant then
            index = 4
        end
    end

    return index
end

function Quadtree:insert(rect)
    if #self.nodes > 0 then
        local index = self:getIndex(rect)
        if index ~= -1 then
            self.nodes[index]:insert(rect)
            return
        end
    end

    table.insert(self.objects, rect)

    if #self.objects > self.maxObjects and self.level < self.maxLevels then
        if #self.nodes == 0 then
            self:split()
        end

        local i = 1
        while i <= #self.objects do
            local index = self:getIndex(self.objects[i])
            if index ~= -1 then
                self.nodes[index]:insert(table.remove(self.objects, i))
            else
                i = i + 1
            end
        end
    end
end

function Quadtree:retrieve(rect, results)
    results = results or {}
    local index = self:getIndex(rect)

    if index ~= -1 and #self.nodes > 0 then
        self.nodes[index]:retrieve(rect, results)
    elseif #self.nodes > 0 then
        for i = 1, 4 do
            self.nodes[i]:retrieve(rect, results)
        end
    end

    for _, object in ipairs(self.objects) do
        if intersects(object, rect) then
            table.insert(results, object)
        end
    end

    return results
end

spatial.SpatialHash = SpatialHash
spatial.Quadtree = Quadtree

function spatial.newSpatialHash(cellSize)
    return SpatialHash.new(cellSize)
end

function spatial.newQuadtree(bounds, maxObjects, maxLevels)
    return Quadtree.new(bounds, maxObjects, maxLevels)
end

return spatial
