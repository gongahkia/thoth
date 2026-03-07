local spatial = require("thoth.game.spatial")

math.randomseed(12345)

local function intersects(a, b)
    return not (
        a.x + a.width < b.x or
        a.x > b.x + b.width or
        a.y + a.height < b.y or
        a.y > b.y + b.height
    )
end

local quadtree = spatial.newQuadtree({x = 0, y = 0, width = 256, height = 256}, 4, 6)
local rects = {}

for i = 1, 60 do
    local width = math.random(4, 24)
    local height = math.random(4, 24)
    local rect = {
        id = tostring(i),
        x = math.random(0, 256 - width),
        y = math.random(0, 256 - height),
        width = width,
        height = height,
    }
    rects[#rects + 1] = rect
    quadtree:insert(rect)
end

local boundaryRect = {id = "boundary", x = 120, y = 120, width = 24, height = 24}
rects[#rects + 1] = boundaryRect
quadtree:insert(boundaryRect)

for _ = 1, 80 do
    local query = {
        x = math.random(0, 220),
        y = math.random(0, 220),
        width = math.random(8, 36),
        height = math.random(8, 36),
    }

    local expected = {}
    for _, rect in ipairs(rects) do
        if intersects(rect, query) then
            expected[rect.id] = true
        end
    end

    local actual = {}
    for _, rect in ipairs(quadtree:retrieve(query)) do
        assert(not actual[rect.id], "Quadtree returned duplicate rect " .. rect.id)
        assert(expected[rect.id], "Quadtree returned unexpected rect " .. rect.id)
        actual[rect.id] = true
        expected[rect.id] = nil
    end

    assert(next(expected) == nil, "Quadtree missed an intersecting rect")
end

local boundaryResults = {}
for _, rect in ipairs(quadtree:retrieve({x = 118, y = 118, width = 10, height = 10})) do
    boundaryResults[rect.id] = true
end
assert(boundaryResults.boundary)

quadtree:clear()
assert(#quadtree:retrieve({x = 0, y = 0, width = 256, height = 256}) == 0)
