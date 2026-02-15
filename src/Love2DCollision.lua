local Love2DCollisionModule = {}

-- @param circle1 as a table {x,y,radius}, circle2 as a table {x,y,radius}
-- @return boolean value depending on whether circles collide
function Love2DCollisionModule.CircleCollision(circle1, circle2)
    local dx = circle1.x - circle2.x
    local dy = circle1.y - circle2.y
    local distanceSquared = dx^2 + dy^2
    local combinedRadius = circle1.radius + circle2.radius
    return distanceSquared <= combinedRadius^2
end

-- @param rectangle1 as a table {x,y,width,height}, rectangle2 as a table {x,y,width,height}
-- @return boolean value depending on whether rectangles collide
function Love2DCollisionModule.RectangleCollision(rect1, rect2)
    local left1, right1, top1, bottom1 = rect1.x, rect1.x + rect1.width, rect1.y, rect1.y + rect1.height
    local left2, right2, top2, bottom2 = rect2.x, rect2.x + rect2.width, rect2.y, rect2.y + rect2.height
    return not (right1 < left2 or left1 > right2 or bottom1 < top2 or top1 > bottom2)
end

-- @param convex polygon as array of vertices {{x,y},{x,y},...}, convex polygon as array of vertices
-- @return boolean value depending on whether polygons collide (SAT algorithm)
function Love2DCollisionModule.PolygonCollision(poly1, poly2)
    local function getAxes(poly)
        local axes = {}
        for i = 1, #poly do
            local j = i % #poly + 1
            local edge = {poly[j][1] - poly[i][1], poly[j][2] - poly[i][2]}
            -- Normal (perpendicular)
            local len = math.sqrt(edge[1]^2 + edge[2]^2)
            if len > 0 then
                table.insert(axes, {-edge[2] / len, edge[1] / len})
            end
        end
        return axes
    end

    local function project(poly, axis)
        local min = poly[1][1] * axis[1] + poly[1][2] * axis[2]
        local max = min
        for i = 2, #poly do
            local dot = poly[i][1] * axis[1] + poly[i][2] * axis[2]
            if dot < min then min = dot end
            if dot > max then max = dot end
        end
        return min, max
    end

    local function testAxes(axes)
        for _, axis in ipairs(axes) do
            local min1, max1 = project(poly1, axis)
            local min2, max2 = project(poly2, axis)
            if max1 < min2 or max2 < min1 then
                return false
            end
        end
        return true
    end

    return testAxes(getAxes(poly1)) and testAxes(getAxes(poly2))
end

return Love2DCollisionModule