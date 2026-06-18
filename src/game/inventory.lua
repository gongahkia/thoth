local Defs = require("src.game.defs")

local Inventory = {}
Inventory.__index = Inventory

function Inventory.new(stacks)
    local self = setmetatable({ counts = {} }, Inventory)
    if stacks then
        for _, stack in ipairs(stacks) do
            self:add(stack.item, stack.count)
        end
    end
    return self
end

function Inventory:add(item, count)
    if not item or count <= 0 then
        return false
    end
    if not Defs.item(item) then
        return false
    end
    self.counts[item] = (self.counts[item] or 0) + count
    return true
end

function Inventory:consume(item, count)
    if self:count(item) < count then
        return false
    end
    self.counts[item] = self.counts[item] - count
    if self.counts[item] <= 0 then
        self.counts[item] = nil
    end
    return true
end

function Inventory:canConsume(items)
    for item, count in pairs(items) do
        if self:count(item) < count then
            return false
        end
    end
    return true
end

function Inventory:consumeAll(items)
    if not self:canConsume(items) then
        return false
    end
    for item, count in pairs(items) do
        self:consume(item, count)
    end
    return true
end

function Inventory:count(item)
    return self.counts[item] or 0
end

function Inventory:firstMatching(items)
    for _, item in ipairs(items) do
        if self:count(item) > 0 then
            return item
        end
    end
    return nil
end

function Inventory:stacks()
    local stacks = {}
    for _, item in ipairs(Defs.itemOrder) do
        local count = self:count(item)
        if count > 0 then
            stacks[#stacks + 1] = { item = item, count = count }
        end
    end
    return stacks
end

function Inventory:clone()
    return Inventory.new(self:stacks())
end

return Inventory
