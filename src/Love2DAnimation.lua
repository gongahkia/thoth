-- =============================================
-- Animation System for Love2D
-- Sprite sheets, frame-based animation, tweening/easing
-- =============================================

local Love2DAnimation = {}

-- =============================================
-- Sprite Sheet Animation
-- =============================================

---@class SpriteSheet
---@field image any Love2D image
---@field frameWidth number
---@field frameHeight number
---@field frames table
---@field frameCount number
local SpriteSheet = {}
SpriteSheet.__index = SpriteSheet

---Create a new sprite sheet
---@param imagePath string Path to sprite sheet image
---@param frameWidth number Width of each frame
---@param frameHeight number Height of each frame
---@return SpriteSheet
function SpriteSheet.new(imagePath, frameWidth, frameHeight)
    local self = setmetatable({}, SpriteSheet)

    -- Note: In actual Love2D usage, you would load the image
    -- self.image = love.graphics.newImage(imagePath)
    self.imagePath = imagePath
    self.frameWidth = frameWidth
    self.frameHeight = frameHeight
    self.frames = {}
    self.frameCount = 0

    return self
end

---Add a frame quad to the sprite sheet
---@param x number X position in sprite sheet
---@param y number Y position in sprite sheet
---@return number frameIndex Index of the added frame
function SpriteSheet:addFrame(x, y)
    -- Note: In actual Love2D usage:
    -- local quad = love.graphics.newQuad(x, y, self.frameWidth, self.frameHeight,
    --                                     self.image:getWidth(), self.image:getHeight())
    local frame = {
        x = x,
        y = y,
        width = self.frameWidth,
        height = self.frameHeight
    }

    table.insert(self.frames, frame)
    self.frameCount = self.frameCount + 1

    return self.frameCount
end

---Generate frames in a grid pattern
---@param columns number Number of columns in the sprite sheet
---@param rows number Number of rows in the sprite sheet
function SpriteSheet:generateGrid(columns, rows)
    for row = 0, rows - 1 do
        for col = 0, columns - 1 do
            self:addFrame(col * self.frameWidth, row * self.frameHeight)
        end
    end
end

---Get a specific frame
---@param index number Frame index
---@return table frame Frame data
function SpriteSheet:getFrame(index)
    return self.frames[index]
end

-- =============================================
-- Animation
-- =============================================

---@class Animation
---@field spriteSheet SpriteSheet
---@field frames table Array of frame indices
---@field currentFrame number
---@field frameDuration number
---@field elapsed number
---@field loop boolean
---@field playing boolean
---@field onComplete function|nil
local Animation = {}
Animation.__index = Animation

---Create a new animation
---@param spriteSheet SpriteSheet Sprite sheet to use
---@param frames table Array of frame indices
---@param frameDuration number Duration of each frame in seconds
---@param loop boolean|nil Whether to loop (default: true)
---@return Animation
function Animation.new(spriteSheet, frames, frameDuration, loop)
    local self = setmetatable({}, Animation)

    self.spriteSheet = spriteSheet
    self.frames = frames
    self.currentFrame = 1
    self.frameDuration = frameDuration or 0.1
    self.elapsed = 0
    self.loop = loop == nil and true or loop
    self.playing = true
    self.onComplete = nil

    return self
end

---Update the animation
---@param dt number Delta time
function Animation:update(dt)
    if not self.playing then
        return
    end

    self.elapsed = self.elapsed + dt

    if self.elapsed >= self.frameDuration then
        self.elapsed = self.elapsed - self.frameDuration
        self.currentFrame = self.currentFrame + 1

        if self.currentFrame > #self.frames then
            if self.loop then
                self.currentFrame = 1
            else
                self.currentFrame = #self.frames
                self.playing = false

                if self.onComplete then
                    self.onComplete()
                end
            end
        end
    end
end

---Draw the current frame
---@param x number X position
---@param y number Y position
---@param rotation number|nil Rotation in radians
---@param scaleX number|nil X scale
---@param scaleY number|nil Y scale
function Animation:draw(x, y, rotation, scaleX, scaleY)
    rotation = rotation or 0
    scaleX = scaleX or 1
    scaleY = scaleY or 1

    local frameIndex = self.frames[self.currentFrame]
    local frame = self.spriteSheet:getFrame(frameIndex)

    -- Note: In actual Love2D usage:
    -- love.graphics.draw(self.spriteSheet.image, frame,
    --                    x, y, rotation, scaleX, scaleY)

    -- For now, we just store the draw parameters
    return {
        frame = frame,
        x = x,
        y = y,
        rotation = rotation,
        scaleX = scaleX,
        scaleY = scaleY
    }
end

---Get current frame data
---@return table frame Current frame
function Animation:getCurrentFrame()
    local frameIndex = self.frames[self.currentFrame]
    return self.spriteSheet:getFrame(frameIndex)
end

---Play the animation
function Animation:play()
    self.playing = true
end

---Pause the animation
function Animation:pause()
    self.playing = false
end

---Stop and reset the animation
function Animation:stop()
    self.playing = false
    self.currentFrame = 1
    self.elapsed = 0
end

---Set completion callback
---@param callback function Function to call when animation completes
function Animation:setOnComplete(callback)
    self.onComplete = callback
end

-- =============================================
-- Animator (manages multiple animations)
-- =============================================

---@class Animator
---@field animations table
---@field current string|nil
local Animator = {}
Animator.__index = Animator

---Create a new animator
---@return Animator
function Animator.new()
    local self = setmetatable({}, Animator)
    self.animations = {}
    self.current = nil
    return self
end

---Add an animation
---@param name string Animation name
---@param animation Animation Animation object
function Animator:add(name, animation)
    self.animations[name] = animation
end

---Switch to a different animation
---@param name string Animation name
---@param reset boolean|nil Whether to reset the animation (default: true)
function Animator:switch(name, reset)
    if reset == nil then reset = true end

    if self.current and self.animations[self.current] then
        self.animations[self.current]:stop()
    end

    self.current = name

    if reset and self.animations[name] then
        self.animations[name]:stop()
        self.animations[name]:play()
    end
end

---Update current animation
---@param dt number Delta time
function Animator:update(dt)
    if self.current and self.animations[self.current] then
        self.animations[self.current]:update(dt)
    end
end

---Draw current animation
---@param x number X position
---@param y number Y position
---@param rotation number|nil Rotation
---@param scaleX number|nil X scale
---@param scaleY number|nil Y scale
function Animator:draw(x, y, rotation, scaleX, scaleY)
    if self.current and self.animations[self.current] then
        return self.animations[self.current]:draw(x, y, rotation, scaleX, scaleY)
    end
end

---Get current animation
---@return Animation|nil animation
function Animator:getCurrent()
    if self.current then
        return self.animations[self.current]
    end
    return nil
end

-- =============================================
-- Easing Functions
-- =============================================

local Easing = {}

-- Linear
function Easing.linear(t)
    return t
end

-- Quadratic
function Easing.inQuad(t)
    return t * t
end

function Easing.outQuad(t)
    return t * (2 - t)
end

function Easing.inOutQuad(t)
    if t < 0.5 then
        return 2 * t * t
    else
        return -1 + (4 - 2 * t) * t
    end
end

-- Cubic
function Easing.inCubic(t)
    return t * t * t
end

function Easing.outCubic(t)
    local f = t - 1
    return f * f * f + 1
end

function Easing.inOutCubic(t)
    if t < 0.5 then
        return 4 * t * t * t
    else
        local f = 2 * t - 2
        return 0.5 * f * f * f + 1
    end
end

-- Quartic
function Easing.inQuart(t)
    return t * t * t * t
end

function Easing.outQuart(t)
    local f = t - 1
    return 1 - f * f * f * f
end

function Easing.inOutQuart(t)
    if t < 0.5 then
        return 8 * t * t * t * t
    else
        local f = t - 1
        return 1 - 8 * f * f * f * f
    end
end

-- Quintic
function Easing.inQuint(t)
    return t * t * t * t * t
end

function Easing.outQuint(t)
    local f = t - 1
    return f * f * f * f * f + 1
end

function Easing.inOutQuint(t)
    if t < 0.5 then
        return 16 * t * t * t * t * t
    else
        local f = 2 * t - 2
        return 0.5 * f * f * f * f * f + 1
    end
end

-- Sine
function Easing.inSine(t)
    return 1 - math.cos(t * math.pi / 2)
end

function Easing.outSine(t)
    return math.sin(t * math.pi / 2)
end

function Easing.inOutSine(t)
    return 0.5 * (1 - math.cos(math.pi * t))
end

-- Exponential
function Easing.inExpo(t)
    return t == 0 and 0 or math.pow(2, 10 * (t - 1))
end

function Easing.outExpo(t)
    return t == 1 and 1 or 1 - math.pow(2, -10 * t)
end

function Easing.inOutExpo(t)
    if t == 0 or t == 1 then
        return t
    end

    if t < 0.5 then
        return 0.5 * math.pow(2, 20 * t - 10)
    else
        return 0.5 * (2 - math.pow(2, -20 * t + 10))
    end
end

-- Circular
function Easing.inCirc(t)
    return 1 - math.sqrt(1 - t * t)
end

function Easing.outCirc(t)
    return math.sqrt(1 - (t - 1) * (t - 1))
end

function Easing.inOutCirc(t)
    if t < 0.5 then
        return 0.5 * (1 - math.sqrt(1 - 4 * t * t))
    else
        return 0.5 * (math.sqrt(1 - (2 * t - 2) * (2 * t - 2)) + 1)
    end
end

-- Back
function Easing.inBack(t)
    local s = 1.70158
    return t * t * ((s + 1) * t - s)
end

function Easing.outBack(t)
    local s = 1.70158
    local f = t - 1
    return f * f * ((s + 1) * f + s) + 1
end

function Easing.inOutBack(t)
    local s = 1.70158 * 1.525

    if t < 0.5 then
        return 0.5 * (4 * t * t * ((s + 1) * 2 * t - s))
    else
        local f = 2 * t - 2
        return 0.5 * (f * f * ((s + 1) * f + s) + 2)
    end
end

-- Elastic
function Easing.inElastic(t)
    if t == 0 or t == 1 then
        return t
    end

    return -math.pow(2, 10 * (t - 1)) * math.sin((t - 1.1) * 5 * math.pi)
end

function Easing.outElastic(t)
    if t == 0 or t == 1 then
        return t
    end

    return math.pow(2, -10 * t) * math.sin((t - 0.1) * 5 * math.pi) + 1
end

function Easing.inOutElastic(t)
    if t == 0 or t == 1 then
        return t
    end

    t = t * 2

    if t < 1 then
        return -0.5 * math.pow(2, 10 * (t - 1)) * math.sin((t - 1.1) * 5 * math.pi)
    else
        return 0.5 * math.pow(2, -10 * (t - 1)) * math.sin((t - 1.1) * 5 * math.pi) + 1
    end
end

-- Bounce
function Easing.outBounce(t)
    if t < 1 / 2.75 then
        return 7.5625 * t * t
    elseif t < 2 / 2.75 then
        t = t - 1.5 / 2.75
        return 7.5625 * t * t + 0.75
    elseif t < 2.5 / 2.75 then
        t = t - 2.25 / 2.75
        return 7.5625 * t * t + 0.9375
    else
        t = t - 2.625 / 2.75
        return 7.5625 * t * t + 0.984375
    end
end

function Easing.inBounce(t)
    return 1 - Easing.outBounce(1 - t)
end

function Easing.inOutBounce(t)
    if t < 0.5 then
        return 0.5 * Easing.inBounce(t * 2)
    else
        return 0.5 * Easing.outBounce(t * 2 - 1) + 0.5
    end
end

-- =============================================
-- Tween
-- =============================================

---@class Tween
---@field target table
---@field targetValues table
---@field startValues table
---@field duration number
---@field elapsed number
---@field easing function
---@field onComplete function|nil
---@field playing boolean
local Tween = {}
Tween.__index = Tween

---Create a new tween
---@param target table Object to tween
---@param targetValues table Target property values
---@param duration number Tween duration in seconds
---@param easing function|nil Easing function (default: linear)
---@return Tween
function Tween.new(target, targetValues, duration, easing)
    local self = setmetatable({}, Tween)

    self.target = target
    self.targetValues = targetValues
    self.startValues = {}
    self.duration = duration
    self.elapsed = 0
    self.easing = easing or Easing.linear
    self.onComplete = nil
    self.playing = true

    -- Store start values
    for key, _ in pairs(targetValues) do
        self.startValues[key] = target[key]
    end

    return self
end

---Update the tween
---@param dt number Delta time
---@return boolean complete Whether tween is complete
function Tween:update(dt)
    if not self.playing then
        return false
    end

    self.elapsed = self.elapsed + dt

    if self.elapsed >= self.duration then
        self.elapsed = self.duration
        self.playing = false
    end

    local progress = self.elapsed / self.duration
    local easedProgress = self.easing(progress)

    -- Update target properties
    for key, endValue in pairs(self.targetValues) do
        local startValue = self.startValues[key]
        self.target[key] = startValue + (endValue - startValue) * easedProgress
    end

    if not self.playing and self.onComplete then
        self.onComplete()
    end

    return not self.playing
end

---Set completion callback
---@param callback function
function Tween:setOnComplete(callback)
    self.onComplete = callback
end

---Pause the tween
function Tween:pause()
    self.playing = false
end

---Resume the tween
function Tween:resume()
    self.playing = true
end

-- =============================================
-- Factory Functions
-- =============================================

---Create a new sprite sheet
---@param imagePath string
---@param frameWidth number
---@param frameHeight number
---@return SpriteSheet
function Love2DAnimation.newSpriteSheet(imagePath, frameWidth, frameHeight)
    return SpriteSheet.new(imagePath, frameWidth, frameHeight)
end

---Create a new animation
---@param spriteSheet SpriteSheet
---@param frames table
---@param frameDuration number
---@param loop boolean|nil
---@return Animation
function Love2DAnimation.newAnimation(spriteSheet, frames, frameDuration, loop)
    return Animation.new(spriteSheet, frames, frameDuration, loop)
end

---Create a new animator
---@return Animator
function Love2DAnimation.newAnimator()
    return Animator.new()
end

---Create a new tween
---@param target table
---@param targetValues table
---@param duration number
---@param easing function|nil
---@return Tween
function Love2DAnimation.newTween(target, targetValues, duration, easing)
    return Tween.new(target, targetValues, duration, easing)
end

-- Export easing functions
Love2DAnimation.Easing = Easing

return Love2DAnimation
