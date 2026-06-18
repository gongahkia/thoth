local Grid = {}

Grid.directions = {
    north = { x = 0, y = -1 },
    east = { x = 1, y = 0 },
    south = { x = 0, y = 1 },
    west = { x = -1, y = 0 },
}

Grid.order = { "north", "east", "south", "west" }

function Grid.delta(direction)
    return Grid.directions[direction] or Grid.directions.south
end

function Grid.rotate(direction)
    for i, value in ipairs(Grid.order) do
        if value == direction then
            return Grid.order[(i % #Grid.order) + 1]
        end
    end
    return "east"
end

function Grid.left(direction)
    for i, value in ipairs(Grid.order) do
        if value == direction then
            return Grid.order[((i + 2) % #Grid.order) + 1]
        end
    end
    return "north"
end

function Grid.right(direction)
    return Grid.rotate(direction)
end

function Grid.front(x, y, direction)
    local delta = Grid.delta(direction)
    return x + delta.x, y + delta.y
end

function Grid.back(x, y, direction)
    local delta = Grid.delta(direction)
    return x - delta.x, y - delta.y
end

function Grid.key(x, y, z)
    return tostring(z or 0) .. ":" .. tostring(x) .. ":" .. tostring(y)
end

function Grid.manhattan(ax, ay, bx, by)
    return math.abs(ax - bx) + math.abs(ay - by)
end

return Grid
