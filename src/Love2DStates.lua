-- =============================================
-- Scene/State Manager for Love2D
-- Manage game states, scenes, and transitions
-- =============================================

local Love2DStates = {}

-- =============================================
-- State/Scene Base
-- =============================================

---@class State
---@field name string
local State = {}
State.__index = State

---Create a new state
---@param name string State name
---@return State
function State.new(name)
    local self = setmetatable({}, State)
    self.name = name
    return self
end

-- Lifecycle callbacks (override these in your states)
function State:enter(previous, ...) end
function State:exit(next, ...) end
function State:update(dt) end
function State:draw() end
function State:keypressed(key, scancode, isrepeat) end
function State:keyreleased(key, scancode) end
function State:mousepressed(x, y, button, istouch, presses) end
function State:mousereleased(x, y, button, istouch, presses) end
function State:mousemoved(x, y, dx, dy, istouch) end
function State:wheelmoved(x, y) end
function State:textinput(text) end
function State:resize(w, h) end
function State:focus(focused) end

-- =============================================
-- State Manager
-- =============================================

---@class StateManager
---@field states table
---@field current State|nil
---@field stack table
local StateManager = {}
StateManager.__index = StateManager

---Create a new state manager
---@return StateManager
function StateManager.new()
    local self = setmetatable({}, StateManager)
    self.states = {}
    self.current = nil
    self.stack = {}
    return self
end

---Register a state
---@param state State State to register
function StateManager:add(state)
    self.states[state.name] = state
end

---Remove a state
---@param name string State name
function StateManager:remove(name)
    self.states[name] = nil
end

---Switch to a different state
---@param name string State name to switch to
---@param ... any Arguments to pass to the new state's enter function
function StateManager:switch(name, ...)
    local newState = self.states[name]

    if not newState then
        error("State '" .. name .. "' not found")
    end

    local previous = self.current

    -- Exit current state
    if self.current then
        self.current:exit(newState, ...)
    end

    -- Enter new state
    self.current = newState
    self.current:enter(previous, ...)
end

---Push a state onto the stack (pause current, switch to new)
---@param name string State name to push
---@param ... any Arguments to pass to the new state's enter function
function StateManager:push(name, ...)
    local newState = self.states[name]

    if not newState then
        error("State '" .. name .. "' not found")
    end

    -- Push current state to stack
    if self.current then
        table.insert(self.stack, self.current)
        self.current:exit(newState, ...)
    end

    -- Enter new state
    self.current = newState
    self.current:enter(nil, ...)
end

---Pop the current state and return to previous
---@param ... any Arguments to pass to the previous state's enter function
---@return boolean success Whether there was a state to pop
function StateManager:pop(...)
    if #self.stack == 0 then
        return false
    end

    local previous = table.remove(self.stack)

    -- Exit current state
    if self.current then
        self.current:exit(previous, ...)
    end

    -- Return to previous state
    self.current = previous
    self.current:enter(nil, ...)

    return true
end

---Get the current state
---@return State|nil current
function StateManager:getCurrent()
    return self.current
end

---Check if a specific state is current
---@param name string State name
---@return boolean isCurrent
function StateManager:isCurrent(name)
    return self.current and self.current.name == name
end

---Get stack depth
---@return number depth
function StateManager:getStackDepth()
    return #self.stack
end

---Clear the state stack
function StateManager:clearStack()
    self.stack = {}
end

-- =============================================
-- Love2D Callback Forwarding
-- =============================================

---Forward update to current state
---@param dt number Delta time
function StateManager:update(dt)
    if self.current and self.current.update then
        self.current:update(dt)
    end
end

---Forward draw to current state
function StateManager:draw()
    if self.current and self.current.draw then
        self.current:draw()
    end
end

---Forward keypressed to current state
---@param key string
---@param scancode string
---@param isrepeat boolean
function StateManager:keypressed(key, scancode, isrepeat)
    if self.current and self.current.keypressed then
        self.current:keypressed(key, scancode, isrepeat)
    end
end

---Forward keyreleased to current state
---@param key string
---@param scancode string
function StateManager:keyreleased(key, scancode)
    if self.current and self.current.keyreleased then
        self.current:keyreleased(key, scancode)
    end
end

---Forward mousepressed to current state
---@param x number
---@param y number
---@param button number
---@param istouch boolean
---@param presses number
function StateManager:mousepressed(x, y, button, istouch, presses)
    if self.current and self.current.mousepressed then
        self.current:mousepressed(x, y, button, istouch, presses)
    end
end

---Forward mousereleased to current state
---@param x number
---@param y number
---@param button number
---@param istouch boolean
---@param presses number
function StateManager:mousereleased(x, y, button, istouch, presses)
    if self.current and self.current.mousereleased then
        self.current:mousereleased(x, y, button, istouch, presses)
    end
end

---Forward mousemoved to current state
---@param x number
---@param y number
---@param dx number
---@param dy number
---@param istouch boolean
function StateManager:mousemoved(x, y, dx, dy, istouch)
    if self.current and self.current.mousemoved then
        self.current:mousemoved(x, y, dx, dy, istouch)
    end
end

---Forward wheelmoved to current state
---@param x number
---@param y number
function StateManager:wheelmoved(x, y)
    if self.current and self.current.wheelmoved then
        self.current:wheelmoved(x, y)
    end
end

---Forward textinput to current state
---@param text string
function StateManager:textinput(text)
    if self.current and self.current.textinput then
        self.current:textinput(text)
    end
end

---Forward resize to current state
---@param w number
---@param h number
function StateManager:resize(w, h)
    if self.current and self.current.resize then
        self.current:resize(w, h)
    end
end

---Forward focus to current state
---@param focused boolean
function StateManager:focus(focused)
    if self.current and self.current.focus then
        self.current:focus(focused)
    end
end

-- =============================================
-- Transition Effects
-- =============================================

---@class Transition
---@field duration number
---@field elapsed number
---@field fromState State
---@field toState State
---@field callback function
local Transition = {}
Transition.__index = Transition

---Create a new transition
---@param duration number Transition duration in seconds
---@param callback function Transition effect function(progress)
---@return Transition
function Transition.new(duration, callback)
    local self = setmetatable({}, Transition)
    self.duration = duration
    self.elapsed = 0
    self.fromState = nil
    self.toState = nil
    self.callback = callback or function() end
    return self
end

---Update the transition
---@param dt number Delta time
---@return boolean complete Whether transition is complete
function Transition:update(dt)
    self.elapsed = self.elapsed + dt
    local progress = math.min(self.elapsed / self.duration, 1.0)

    self.callback(progress)

    return progress >= 1.0
end

---@class StateManagerWithTransitions
---@field manager StateManager
---@field currentTransition Transition|nil
local StateManagerWithTransitions = {}
StateManagerWithTransitions.__index = StateManagerWithTransitions

---Create a state manager with transitions
---@return StateManagerWithTransitions
function StateManagerWithTransitions.new()
    local self = setmetatable({}, StateManagerWithTransitions)
    self.manager = StateManager.new()
    self.currentTransition = nil
    return self
end

-- Forward StateManager methods
StateManagerWithTransitions.add = function(self, state)
    return self.manager:add(state)
end

StateManagerWithTransitions.remove = function(self, name)
    return self.manager:remove(name)
end

StateManagerWithTransitions.getCurrent = function(self)
    return self.manager:getCurrent()
end

StateManagerWithTransitions.isCurrent = function(self, name)
    return self.manager:isCurrent(name)
end

---Switch state with transition
---@param name string State name
---@param transition Transition|nil Transition effect
---@param ... any Arguments for new state
function StateManagerWithTransitions:switchWithTransition(name, transition, ...)
    if transition then
        self.currentTransition = transition
        self.currentTransition.fromState = self.manager.current
        self.currentTransition.toState = self.manager.states[name]
    end

    self.manager:switch(name, ...)
end

---Update with transition support
---@param dt number Delta time
function StateManagerWithTransitions:update(dt)
    if self.currentTransition then
        local complete = self.currentTransition:update(dt)

        if complete then
            self.currentTransition = nil
        end
    end

    self.manager:update(dt)
end

---Draw with transition support
function StateManagerWithTransitions:draw()
    self.manager:draw()
end

-- Forward other Love2D callbacks
StateManagerWithTransitions.keypressed = function(self, ...) return self.manager:keypressed(...) end
StateManagerWithTransitions.keyreleased = function(self, ...) return self.manager:keyreleased(...) end
StateManagerWithTransitions.mousepressed = function(self, ...) return self.manager:mousepressed(...) end
StateManagerWithTransitions.mousereleased = function(self, ...) return self.manager:mousereleased(...) end
StateManagerWithTransitions.mousemoved = function(self, ...) return self.manager:mousemoved(...) end
StateManagerWithTransitions.wheelmoved = function(self, ...) return self.manager:wheelmoved(...) end
StateManagerWithTransitions.textinput = function(self, ...) return self.manager:textinput(...) end
StateManagerWithTransitions.resize = function(self, ...) return self.manager:resize(...) end
StateManagerWithTransitions.focus = function(self, ...) return self.manager:focus(...) end

-- =============================================
-- Factory Functions
-- =============================================

---Create a new state
---@param name string State name
---@return State
function Love2DStates.newState(name)
    return State.new(name)
end

---Create a new state manager
---@return StateManager
function Love2DStates.newManager()
    return StateManager.new()
end

---Create a state manager with transition support
---@return StateManagerWithTransitions
function Love2DStates.newManagerWithTransitions()
    return StateManagerWithTransitions.new()
end

---Create a fade transition
---@param duration number Transition duration
---@return Transition
function Love2DStates.fadeTransition(duration)
    return Transition.new(duration, function(progress)
        -- This would set fade alpha in Love2D
        -- love.graphics.setColor(1, 1, 1, 1 - progress)
    end)
end

-- =============================================
-- Example Usage (commented out)
-- =============================================

--[[
-- Create states
local menuState = Love2DStates.newState("menu")
function menuState:enter()
    print("Entered menu")
end
function menuState:draw()
    -- Draw menu
end

local gameState = Love2DStates.newState("game")
function gameState:enter()
    print("Entered game")
end
function gameState:draw()
    -- Draw game
end

-- Create manager
local stateManager = Love2DStates.newManager()
stateManager:add(menuState)
stateManager:add(gameState)
stateManager:switch("menu")

-- In your Love2D callbacks:
function love.update(dt)
    stateManager:update(dt)
end

function love.draw()
    stateManager:draw()
end

function love.keypressed(key)
    if key == "space" then
        stateManager:switch("game")
    end
    stateManager:keypressed(key)
end
]]

return Love2DStates
