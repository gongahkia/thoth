local collision = {}

local function clamp(value, min, max)
    if value < min then
        return min
    end
    if value > max then
        return max
    end
    return value
end

function collision.rect(x, y, width, height)
    return {x = x, y = y, width = width, height = height}
end

function collision.circle(x, y, radius)
    return {x = x, y = y, radius = radius}
end

function collision.pointInRect(point, rect)
    return point.x >= rect.x and point.x <= rect.x + rect.width and point.y >= rect.y and point.y <= rect.y + rect.height
end

function collision.pointInCircle(point, circle)
    local dx = point.x - circle.x
    local dy = point.y - circle.y
    return (dx * dx) + (dy * dy) <= (circle.radius * circle.radius)
end

function collision.rectsOverlap(a, b)
    return not (
        a.x + a.width < b.x or
        a.x > b.x + b.width or
        a.y + a.height < b.y or
        a.y > b.y + b.height
    )
end

function collision.circlesOverlap(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    local radius = a.radius + b.radius
    return (dx * dx) + (dy * dy) <= (radius * radius)
end

function collision.circleRectOverlap(circle, rect)
    local closestX = clamp(circle.x, rect.x, rect.x + rect.width)
    local closestY = clamp(circle.y, rect.y, rect.y + rect.height)
    local dx = circle.x - closestX
    local dy = circle.y - closestY
    return (dx * dx) + (dy * dy) <= (circle.radius * circle.radius)
end

function collision.segmentIntersectsRect(x1, y1, x2, y2, rect)
    local dx = x2 - x1
    local dy = y2 - y1
    local tmin = 0
    local tmax = 1

    local function clip(p, q)
        if p == 0 then
            return q >= 0
        end
        local r = q / p
        if p < 0 then
            if r > tmax then
                return false
            end
            if r > tmin then
                tmin = r
            end
        else
            if r < tmin then
                return false
            end
            if r < tmax then
                tmax = r
            end
        end
        return true
    end

    if clip(-dx, x1 - rect.x)
        and clip(dx, rect.x + rect.width - x1)
        and clip(-dy, y1 - rect.y)
        and clip(dy, rect.y + rect.height - y1) then
        return true
    end

    return false
end

function collision.raycastRect(origin, direction, length, rect)
    local dx = direction.x * length
    local dy = direction.y * length
    if not collision.segmentIntersectsRect(origin.x, origin.y, origin.x + dx, origin.y + dy, rect) then
        return nil
    end

    return {
        hit = true,
        endX = origin.x + dx,
        endY = origin.y + dy,
    }
end

return collision
