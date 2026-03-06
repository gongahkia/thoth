local tween = {}

local Easing = {
    linear = function(t) return t end,
    inQuad = function(t) return t * t end,
    outQuad = function(t) return t * (2 - t) end,
}

function Easing.inOutQuad(t)
    if t < 0.5 then
        return 2 * t * t
    end
    return -1 + (4 - 2 * t) * t
end

local Tween = {}
Tween.__index = Tween

function Tween.new(target, targetValues, duration, easing)
    assert(type(target) == "table", "Tween target must be a table")
    assert(type(targetValues) == "table", "Tween targetValues must be a table")
    assert(type(duration) == "number" and duration > 0, "Tween duration must be > 0")

    local self = setmetatable({}, Tween)
    self.target = target
    self.targetValues = targetValues
    self.startValues = {}
    self.duration = duration
    self.elapsed = 0
    self.easing = easing or Easing.linear
    self.playing = true
    self.onComplete = nil

    for key, _ in pairs(targetValues) do
        self.startValues[key] = target[key]
    end

    return self
end

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
    local eased = self.easing(progress)
    for key, endValue in pairs(self.targetValues) do
        local startValue = self.startValues[key]
        self.target[key] = startValue + (endValue - startValue) * eased
    end

    if not self.playing and self.onComplete then
        self.onComplete()
        self.onComplete = nil
    end
    return not self.playing
end

function Tween:setOnComplete(callback)
    self.onComplete = callback
    return self
end

function Tween:pause()
    self.playing = false
end

function Tween:resume()
    self.playing = true
end

local Timer = {}
Timer.__index = Timer

function Timer.new(duration, callback, repeatCount)
    assert(type(duration) == "number" and duration > 0, "Timer duration must be > 0")
    local self = setmetatable({}, Timer)
    self.duration = duration
    self.callback = callback
    self.repeatCount = repeatCount or 1
    self.elapsed = 0
    self.runs = 0
    self.done = false
    self.playing = true
    return self
end

function Timer:update(dt)
    if self.done or not self.playing then
        return false
    end

    self.elapsed = self.elapsed + dt
    while self.elapsed >= self.duration and not self.done do
        self.elapsed = self.elapsed - self.duration
        self.runs = self.runs + 1
        if self.callback then
            self.callback(self.runs)
        end
        if self.repeatCount >= 0 and self.runs >= self.repeatCount then
            self.done = true
        end
    end
    return self.done
end

function Timer:pause()
    self.playing = false
end

function Timer:resume()
    self.playing = true
end

local Timeline = {}
Timeline.__index = Timeline

function Timeline.new()
    local self = setmetatable({}, Timeline)
    self.tweens = {}
    self.timers = {}
    return self
end

function Timeline:addTween(item)
    table.insert(self.tweens, item)
    return item
end

function Timeline:addTimer(item)
    table.insert(self.timers, item)
    return item
end

function Timeline:update(dt)
    local i = 1
    while i <= #self.tweens do
        if self.tweens[i]:update(dt) then
            table.remove(self.tweens, i)
        else
            i = i + 1
        end
    end

    local j = 1
    while j <= #self.timers do
        if self.timers[j]:update(dt) then
            table.remove(self.timers, j)
        else
            j = j + 1
        end
    end
end

function Timeline:clear()
    self.tweens = {}
    self.timers = {}
end

tween.Tween = Tween
tween.Timer = Timer
tween.Timeline = Timeline
tween.Easing = Easing

function tween.newTween(target, targetValues, duration, easing)
    return Tween.new(target, targetValues, duration, easing)
end

function tween.newTimer(duration, callback, repeatCount)
    return Timer.new(duration, callback, repeatCount)
end

function tween.newTimeline()
    return Timeline.new()
end

return tween
