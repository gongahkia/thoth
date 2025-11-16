-- =============================================
-- Entity-Component System (ECS) for Love2D
-- Lightweight ECS architecture for game development
-- =============================================

local ECS = {}

-- =============================================
-- Entity Management
-- =============================================

local nextEntityId = 1

---Create a new entity (just returns a unique ID)
---@return number entityId Unique entity identifier
function ECS.CreateEntity()
    local id = nextEntityId
    nextEntityId = nextEntityId + 1
    return id
end

-- =============================================
-- World (manages entities, components, and systems)
-- =============================================

---@class World
---@field entities table Set of all entity IDs
---@field components table Component storage {componentType -> {entityId -> componentData}}
---@field systems table Array of systems
local World = {}
World.__index = World

---Create a new ECS world
---@return World
function World.new()
    local self = setmetatable({}, World)
    self.entities = {}
    self.components = {}
    self.systems = {}
    return self
end

---Add an entity to the world
---@param entityId number Entity ID
function World:addEntity(entityId)
    self.entities[entityId] = true
end

---Remove an entity and all its components
---@param entityId number Entity ID
function World:removeEntity(entityId)
    self.entities[entityId] = nil

    -- Remove all components for this entity
    for componentType, componentMap in pairs(self.components) do
        componentMap[entityId] = nil
    end
end

---Check if entity exists in the world
---@param entityId number Entity ID
---@return boolean exists
function World:hasEntity(entityId)
    return self.entities[entityId] ~= nil
end

---Get all entity IDs
---@return table entities Array of entity IDs
function World:getAllEntities()
    local entityList = {}
    for entityId in pairs(self.entities) do
        table.insert(entityList, entityId)
    end
    return entityList
end

-- =============================================
-- Component Management
-- =============================================

---Add a component to an entity
---@param entityId number Entity ID
---@param componentType string Component type name
---@param componentData table Component data
function World:addComponent(entityId, componentType, componentData)
    if not self.components[componentType] then
        self.components[componentType] = {}
    end

    self.components[componentType][entityId] = componentData
end

---Remove a component from an entity
---@param entityId number Entity ID
---@param componentType string Component type name
function World:removeComponent(entityId, componentType)
    if self.components[componentType] then
        self.components[componentType][entityId] = nil
    end
end

---Get a component from an entity
---@param entityId number Entity ID
---@param componentType string Component type name
---@return table|nil component Component data or nil
function World:getComponent(entityId, componentType)
    if not self.components[componentType] then
        return nil
    end

    return self.components[componentType][entityId]
end

---Check if entity has a component
---@param entityId number Entity ID
---@param componentType string Component type name
---@return boolean hasComponent
function World:hasComponent(entityId, componentType)
    return self.components[componentType] ~= nil and
           self.components[componentType][entityId] ~= nil
end

---Get all components of a specific type
---@param componentType string Component type name
---@return table components Map of {entityId -> componentData}
function World:getComponentsOfType(componentType)
    return self.components[componentType] or {}
end

---Get all entities with specific components (query)
---@param ... string Component type names
---@return table entities Array of entity IDs that have all specified components
function World:queryEntities(...)
    local componentTypes = {...}
    local matchingEntities = {}

    for entityId in pairs(self.entities) do
        local hasAll = true

        for _, componentType in ipairs(componentTypes) do
            if not self:hasComponent(entityId, componentType) then
                hasAll = false
                break
            end
        end

        if hasAll then
            table.insert(matchingEntities, entityId)
        end
    end

    return matchingEntities
end

-- =============================================
-- System Management
-- =============================================

---@class System
---@field name string
---@field filter table Component types this system requires
---@field update function|nil Update function
---@field draw function|nil Draw function
---@field enabled boolean
local System = {}
System.__index = System

---Create a new system
---@param name string System name
---@param filter table Array of component type names
---@param callbacks table {update = function, draw = function}
---@return System
function System.new(name, filter, callbacks)
    local self = setmetatable({}, System)
    self.name = name
    self.filter = filter or {}
    self.update = callbacks.update
    self.draw = callbacks.draw
    self.enabled = true
    return self
end

---Add a system to the world
---@param system System System to add
function World:addSystem(system)
    table.insert(self.systems, system)
end

---Remove a system from the world
---@param systemName string Name of system to remove
function World:removeSystem(systemName)
    for i, system in ipairs(self.systems) do
        if system.name == systemName then
            table.remove(self.systems, i)
            return
        end
    end
end

---Get a system by name
---@param systemName string System name
---@return System|nil system
function World:getSystem(systemName)
    for _, system in ipairs(self.systems) do
        if system.name == systemName then
            return system
        end
    end
    return nil
end

---Enable a system
---@param systemName string System name
function World:enableSystem(systemName)
    local system = self:getSystem(systemName)
    if system then
        system.enabled = true
    end
end

---Disable a system
---@param systemName string System name
function World:disableSystem(systemName)
    local system = self:getSystem(systemName)
    if system then
        system.enabled = false
    end
end

-- =============================================
-- System Execution
-- =============================================

---Update all systems
---@param dt number Delta time
function World:update(dt)
    for _, system in ipairs(self.systems) do
        if system.enabled and system.update then
            -- Get entities matching this system's filter
            local entities = self:queryEntities(table.unpack(system.filter))

            -- Call system update with matching entities
            system.update(self, entities, dt)
        end
    end
end

---Draw all systems
function World:draw()
    for _, system in ipairs(self.systems) do
        if system.enabled and system.draw then
            -- Get entities matching this system's filter
            local entities = self:queryEntities(table.unpack(system.filter))

            -- Call system draw with matching entities
            system.draw(self, entities)
        end
    end
end

-- =============================================
-- Utility Functions
-- =============================================

---Count entities with specific components
---@param ... string Component type names
---@return number count
function World:countEntities(...)
    return #self:queryEntities(...)
end

---Clear all entities and components (keeps systems)
function World:clear()
    self.entities = {}
    self.components = {}
end

---Get statistics about the world
---@return table stats {entities, components, systems}
function World:getStats()
    local entityCount = 0
    for _ in pairs(self.entities) do
        entityCount = entityCount + 1
    end

    local componentTypeCount = 0
    local componentInstanceCount = 0
    for componentType, componentMap in pairs(self.components) do
        componentTypeCount = componentTypeCount + 1
        for _ in pairs(componentMap) do
            componentInstanceCount = componentInstanceCount + 1
        end
    end

    return {
        entities = entityCount,
        componentTypes = componentTypeCount,
        componentInstances = componentInstanceCount,
        systems = #self.systems
    }
end

-- =============================================
-- Factory Functions
-- =============================================

---Create a new ECS world
---@return World
function ECS.CreateWorld()
    return World.new()
end

---Create a new system
---@param name string System name
---@param filter table Array of component type names
---@param callbacks table {update = function, draw = function}
---@return System
function ECS.CreateSystem(name, filter, callbacks)
    return System.new(name, filter, callbacks)
end

-- =============================================
-- Example Usage (commented out)
-- =============================================

--[[
-- Example: Simple game with position and velocity

local world = ECS.CreateWorld()

-- Create entities
local player = ECS.CreateEntity()
world:addEntity(player)
world:addComponent(player, "position", {x = 100, y = 100})
world:addComponent(player, "velocity", {x = 50, y = 0})
world:addComponent(player, "sprite", {image = "player.png"})

local enemy = ECS.CreateEntity()
world:addEntity(enemy)
world:addComponent(enemy, "position", {x = 300, y = 200})
world:addComponent(enemy, "velocity", {x = -30, y = 0})
world:addComponent(enemy, "sprite", {image = "enemy.png"})

-- Create movement system
local movementSystem = ECS.CreateSystem("movement", {"position", "velocity"}, {
    update = function(world, entities, dt)
        for _, entityId in ipairs(entities) do
            local pos = world:getComponent(entityId, "position")
            local vel = world:getComponent(entityId, "velocity")

            pos.x = pos.x + vel.x * dt
            pos.y = pos.y + vel.y * dt
        end
    end
})

world:addSystem(movementSystem)

-- Create render system
local renderSystem = ECS.CreateSystem("render", {"position", "sprite"}, {
    draw = function(world, entities)
        for _, entityId in ipairs(entities) do
            local pos = world:getComponent(entityId, "position")
            local sprite = world:getComponent(entityId, "sprite")

            -- Draw sprite at position (pseudo-code)
            -- love.graphics.draw(sprite.image, pos.x, pos.y)
        end
    end
})

world:addSystem(renderSystem)

-- In your game loop:
-- function love.update(dt)
--     world:update(dt)
-- end

-- function love.draw()
--     world:draw()
-- end
]]

return ECS
