local frame = require("thoth.game.frame")
local inputModule = require("thoth.game.input")
local randomModule = require("thoth.game.random")
local stateModule = require("thoth.game.state")
local tweenModule = require("thoth.game.tween")
local tasksModule = require("thoth.game.tasks")
local contract = require("thoth.adapters.contract")

local runtime = {}

local Runtime = {}
Runtime.__index = Runtime

local function shallowCopy(tbl)
    local copy = {}
    for key, value in pairs(tbl) do
        copy[key] = value
    end
    return copy
end

local function sortSystems(systems)
    table.sort(systems, function(a, b)
        local pa = a.priority or 0
        local pb = b.priority or 0
        if pa == pb then
            return (a.name or "") < (b.name or "")
        end
        return pa < pb
    end)
end

function Runtime.new(adapter, options)
    options = options or {}
    if adapter == nil then
        adapter = contract.nullAdapter()
    end
    contract.assertValid(adapter)

    local self = setmetatable({}, Runtime)
    self.adapter = adapter
    self.scheduler = frame.new(options)
    self.systems = {}
    self.input = inputModule.new(adapter)
    self.random = randomModule.new(options.seed)
    self.state = stateModule.new()
    self.timeline = tweenModule.newTimeline()
    self.tasks = tasksModule.new()
    self.context = options.context or {}
    self.frameInfo = {
        index = 0,
        time = 0,
        fixedIndex = 0,
        fixedTime = 0,
        lastDelta = 0,
        fixedDelta = self.scheduler.fixedDelta,
        fixedStepsLastFrame = 0,
        alpha = 0,
    }
    return self
end

function Runtime:getFrameInfo()
    return shallowCopy(self.frameInfo)
end

function Runtime:getSeed()
    return self.random:getInitialSeed()
end

function Runtime:setSeed(seed)
    return self.random:setSeed(seed)
end

function Runtime:randomNumber(min, max)
    return self.random:random(min, max)
end

function Runtime:randomChoice(values)
    return self.random:choice(values)
end

function Runtime:registerSystem(system)
    assert(type(system) == "table", "System must be a table")
    assert(type(system.update) == "function" or type(system.fixedUpdate) == "function" or type(system.draw) == "function",
        "System must provide at least one of: update, fixedUpdate, draw")
    if system.enabled == nil then
        system.enabled = true
    end
    table.insert(self.systems, system)
    sortSystems(self.systems)
    return system
end

function Runtime:enableSystem(name, enabled)
    local system = self:getSystem(name)
    if not system then
        return false
    end
    system.enabled = enabled ~= false
    return true
end

function Runtime:removeSystem(name)
    for i, system in ipairs(self.systems) do
        if system.name == name then
            table.remove(self.systems, i)
            return true
        end
    end
    return false
end

function Runtime:getSystem(name)
    for _, system in ipairs(self.systems) do
        if system.name == name then
            return system
        end
    end
    return nil
end

function Runtime:update(dt)
    if dt == nil and self.adapter and type(self.adapter.delta) == "function" then
        dt = self.adapter:delta()
    end
    dt = dt or self.scheduler.fixedDelta
    self.frameInfo.index = self.frameInfo.index + 1
    self.frameInfo.lastDelta = dt
    self.frameInfo.time = self.frameInfo.time + dt
    self.frameInfo.fixedDelta = self.scheduler.fixedDelta

    self.input:update()
    self.tasks:update(dt)
    self.timeline:update(dt)
    self.state:update(dt)

    local steps, alpha = self.scheduler:advance(dt, function(stepDt, stepIndex)
        self.frameInfo.fixedIndex = self.frameInfo.fixedIndex + 1
        self.frameInfo.fixedTime = self.frameInfo.fixedTime + stepDt
        for _, system in ipairs(self.systems) do
            if system.enabled ~= false and type(system.fixedUpdate) == "function" then
                system.fixedUpdate(self, stepDt, stepIndex)
            end
        end
    end)
    self.frameInfo.fixedStepsLastFrame = steps
    self.frameInfo.alpha = alpha

    for _, system in ipairs(self.systems) do
        if system.enabled ~= false and type(system.update) == "function" then
            system.update(self, dt)
        end
    end
end

function Runtime:draw(...)
    self.state:draw(...)
    for _, system in ipairs(self.systems) do
        if system.enabled ~= false and type(system.draw) == "function" then
            system.draw(self, ...)
        end
    end
end

function Runtime:dispatchInput(eventName, ...)
    for _, system in ipairs(self.systems) do
        if system.enabled ~= false and type(system.onInput) == "function" then
            system.onInput(self, eventName, ...)
        end
    end
    self.state:dispatch(eventName, ...)
end

function Runtime:attachLifecycle(options)
    if not self.adapter or type(self.adapter.registerLifecycle) ~= "function" then
        return nil
    end
    return self.adapter:registerLifecycle(self, options or {})
end

runtime.Runtime = Runtime

function runtime.new(adapter, options)
    return Runtime.new(adapter, options)
end

return runtime
