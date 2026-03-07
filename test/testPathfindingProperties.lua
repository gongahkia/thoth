local pathfinding = require("thoth.game.pathfinding")

local function assertOrthogonalPath(path)
    for i = 2, #path do
        local prev = path[i - 1]
        local curr = path[i]
        local dx = math.abs(curr.x - prev.x)
        local dy = math.abs(curr.y - prev.y)
        assert(dx + dy == 1, "Path step must be orthogonally adjacent")
    end
end

local openGrid = {}
for y = 1, 6 do
    openGrid[y] = {}
    for x = 1, 6 do
        openGrid[y][x] = 1
    end
end

local start = {x = 1, y = 1}
local goal = {x = 6, y = 4}
local openPath, openDistance = pathfinding.findPathGrid(openGrid, start, goal)
assert(openPath ~= nil)
assert(openDistance == 8)
assert(#openPath == openDistance + 1)
assert(openPath[1].x == start.x and openPath[1].y == start.y)
assert(openPath[#openPath].x == goal.x and openPath[#openPath].y == goal.y)
assertOrthogonalPath(openPath)

local blockedGrid = {
    {1, 1, 1},
    {0, 0, 0},
    {1, 1, 1},
}
local blockedPath, blockedDistance = pathfinding.findPathGrid(blockedGrid, {x = 1, y = 1}, {x = 3, y = 3})
assert(blockedPath == nil)
assert(blockedDistance == math.huge)

math.randomseed(4242)

for _ = 1, 40 do
    local grid = {}
    for y = 1, 6 do
        grid[y] = {}
        for x = 1, 6 do
            grid[y][x] = math.random() < 0.25 and 0 or 1
        end
    end

    grid[1][1] = 1
    grid[6][6] = 1

    local zeroPath, zeroDistance = pathfinding.findPathGrid(grid, {x = 1, y = 1}, {x = 6, y = 6}, {
        heuristic = function()
            return 0
        end,
    })
    local defaultPath, defaultDistance = pathfinding.findPathGrid(grid, {x = 1, y = 1}, {x = 6, y = 6})

    assert((zeroPath == nil) == (defaultPath == nil), "Default heuristic changed path existence")
    if zeroPath then
        assert(math.abs(zeroDistance - defaultDistance) < 1e-9, "Default heuristic changed optimal distance")
    end
end
