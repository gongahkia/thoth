local fog = {}
local Fog = {}
Fog.__index = Fog

function Fog.new(width, height)
    assert(type(width) == "number" and width > 0, "width must be a positive number")
    assert(type(height) == "number" and height > 0, "height must be a positive number")
    local self = setmetatable({}, Fog)
    self.width = width
    self.height = height
    self.revealed = {}
    return self
end

local function cellKey(x, y)
    return string.format("%d:%d", x, y)
end

local function inBounds(self, x, y)
    return x >= 1 and x <= self.width and y >= 1 and y <= self.height
end

function Fog:reveal(cx, cy, radius)
    assert(type(radius) == "number" and radius >= 0, "radius must be a non-negative number")
    local r2 = radius * radius
    local ri = math.ceil(radius)
    for dy = -ri, ri do
        for dx = -ri, ri do
            if dx * dx + dy * dy <= r2 then
                local tx = cx + dx
                local ty = cy + dy
                if inBounds(self, tx, ty) then
                    self.revealed[cellKey(tx, ty)] = true
                end
            end
        end
    end
end

function Fog:revealRect(x, y, w, h)
    for ty = y, y + h - 1 do
        for tx = x, x + w - 1 do
            if inBounds(self, tx, ty) then
                self.revealed[cellKey(tx, ty)] = true
            end
        end
    end
end

function Fog:isRevealed(x, y)
    return self.revealed[cellKey(x, y)] == true
end

function Fog:reset()
    self.revealed = {}
end

function Fog:snapshot()
    local snap = {}
    for key in pairs(self.revealed) do
        snap[#snap + 1] = key
    end
    return {width = self.width, height = self.height, keys = snap}
end

function Fog:restore(snapshot)
    assert(type(snapshot) == "table", "Fog snapshot must be a table")
    self.width = snapshot.width or self.width
    self.height = snapshot.height or self.height
    self.revealed = {}
    for _, key in ipairs(snapshot.keys or {}) do
        self.revealed[key] = true
    end
    return self
end

fog.Fog = Fog

function fog.new(width, height)
    return Fog.new(width, height)
end

return fog
