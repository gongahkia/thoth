local unionfind = {}

local UnionFind = {}
UnionFind.__index = UnionFind

function UnionFind.new(values)
    local self = setmetatable({}, UnionFind)
    self.parent = {}
    self.rank = {}
    if type(values) == "table" then
        for _, value in ipairs(values) do
            self:add(value)
        end
    end
    return self
end

function UnionFind:add(value)
    if self.parent[value] == nil then
        self.parent[value] = value
        self.rank[value] = 0
    end
    return self
end

function UnionFind:find(value)
    assert(self.parent[value] ~= nil, "UnionFind value not found")
    if self.parent[value] ~= value then
        self.parent[value] = self:find(self.parent[value])
    end
    return self.parent[value]
end

function UnionFind:union(a, b)
    self:add(a)
    self:add(b)
    local rootA = self:find(a)
    local rootB = self:find(b)
    if rootA == rootB then
        return rootA
    end

    if self.rank[rootA] < self.rank[rootB] then
        rootA, rootB = rootB, rootA
    end
    self.parent[rootB] = rootA
    if self.rank[rootA] == self.rank[rootB] then
        self.rank[rootA] = self.rank[rootA] + 1
    end
    return rootA
end

function UnionFind:connected(a, b)
    if self.parent[a] == nil or self.parent[b] == nil then
        return false
    end
    return self:find(a) == self:find(b)
end

function UnionFind:groups()
    local groups = {}
    for value in pairs(self.parent) do
        local root = self:find(value)
        groups[root] = groups[root] or {}
        groups[root][#groups[root] + 1] = value
    end
    return groups
end

unionfind.UnionFind = UnionFind

function unionfind.new(values)
    return UnionFind.new(values)
end

return unionfind
