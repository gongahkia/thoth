local camera = {}

local Camera = {}
Camera.__index = Camera

local function clamp(value, min, max)
    if value < min then
        return min
    end
    if value > max then
        return max
    end
    return value
end

function Camera.new(options)
    options = options or {}
    local self = setmetatable({}, Camera)
    self.x = options.x or 0
    self.y = options.y or 0
    self.zoom = options.zoom or 1
    self.viewportWidth = options.viewportWidth or 320
    self.viewportHeight = options.viewportHeight or 180
    self.bounds = nil
    self.target = nil
    self.followSmoothing = options.followSmoothing or 1
    self.shakeOffsetX = 0
    self.shakeOffsetY = 0
    self.shakeTime = 0
    self.shakeDuration = 0
    self.shakeIntensity = 0
    return self
end

function Camera:setPosition(x, y)
    self.x = x or self.x
    self.y = y or self.y
    return self:_applyBounds()
end

function Camera:move(dx, dy)
    self.x = self.x + (dx or 0)
    self.y = self.y + (dy or 0)
    return self:_applyBounds()
end

function Camera:setViewport(width, height)
    self.viewportWidth = width or self.viewportWidth
    self.viewportHeight = height or self.viewportHeight
    return self:_applyBounds()
end

function Camera:setZoom(zoom)
    assert(type(zoom) == "number" and zoom > 0, "Camera zoom must be > 0")
    self.zoom = zoom
    return self:_applyBounds()
end

function Camera:setBounds(x, y, width, height)
    self.bounds = {
        x = x,
        y = y,
        width = width,
        height = height,
    }
    return self:_applyBounds()
end

function Camera:setTarget(target, smoothing)
    self.target = target
    if smoothing ~= nil then
        self.followSmoothing = smoothing
    end
    return self
end

function Camera:centerOn(x, y)
    self.x = x - (self.viewportWidth / (2 * self.zoom))
    self.y = y - (self.viewportHeight / (2 * self.zoom))
    return self:_applyBounds()
end

function Camera:shake(intensity, duration)
    self.shakeIntensity = intensity or 0
    self.shakeDuration = duration or 0
    self.shakeTime = self.shakeDuration
    return self
end

function Camera:_applyBounds()
    if not self.bounds then
        return self
    end

    local maxX = self.bounds.x + self.bounds.width - (self.viewportWidth / self.zoom)
    local maxY = self.bounds.y + self.bounds.height - (self.viewportHeight / self.zoom)
    self.x = clamp(self.x, self.bounds.x, maxX)
    self.y = clamp(self.y, self.bounds.y, maxY)
    return self
end

function Camera:update(dt)
    dt = dt or 0

    if self.target then
        local targetX = self.target.x or self.x
        local targetY = self.target.y or self.y
        local desiredX = targetX - (self.viewportWidth / (2 * self.zoom))
        local desiredY = targetY - (self.viewportHeight / (2 * self.zoom))
        local factor = clamp((self.followSmoothing or 1) * dt, 0, 1)
        self.x = self.x + ((desiredX - self.x) * factor)
        self.y = self.y + ((desiredY - self.y) * factor)
        self:_applyBounds()
    end

    if self.shakeTime > 0 and self.shakeDuration > 0 then
        self.shakeTime = math.max(0, self.shakeTime - dt)
        local magnitude = (self.shakeTime / self.shakeDuration) * self.shakeIntensity
        self.shakeOffsetX = (math.random() * 2 - 1) * magnitude
        self.shakeOffsetY = (math.random() * 2 - 1) * magnitude
    else
        self.shakeOffsetX = 0
        self.shakeOffsetY = 0
    end

    return self
end

function Camera:worldToScreen(x, y)
    return ((x - self.x + self.shakeOffsetX) * self.zoom), ((y - self.y + self.shakeOffsetY) * self.zoom)
end

function Camera:screenToWorld(x, y)
    return (x / self.zoom) + self.x - self.shakeOffsetX, (y / self.zoom) + self.y - self.shakeOffsetY
end

camera.Camera = Camera

function camera.new(options)
    return Camera.new(options)
end

return camera
