local linkedListModule = {}

-- node structure for linked list
local Node = {}
Node.__index = Node

-- defining a metamethod for node table
function Node.new(val)
    local self = setmetatable({}, Node)
    self.val = val
    self.next = nil
    return self
end

-- @param nil
-- @return empty linked list
function linkedListModule.new()
    return {head = nil}
end

-- @param linked list
-- @return boolean depending on whether linked list empty
function linkedListModule.isEmpty(list)
    return list.head == nil
end

-- @param linked list, value to be inserted at end of linked list
-- @return updated linked list
function linkedListModule.insert(list, val)
    local newList = {head = list.head}
    local newNode = Node.new(val)
    if newList.head == nil then
        newList.head = newNode
    else
        local current = newList.head
        while current.next do
            current = current.next
        end
        current.next = newNode
    end
    return newList
end

-- @param linked list, value to be deleted
-- @return updated linked list
function linkedListModule.delete(list, val)
    local newList = {head = list.head}
    if newList.head == nil then
        return newList
    end
    if newList.head.val == val then
        newList.head = newList.head.next
        return newList
    end
    local current = newList.head
    while current.next do
        if current.next.val == val then
            current.next = current.next.next
            break
        end
        current = current.next
    end
    return newList
end

-- @param linked list, search value
-- @return boolean depending on whether value found
function linkedListModule.search(list, val)
    local current = list.head
    while current do
        if current.val == val then
            return true
        end
        current = current.next
    end
    return false
end

-- @param linked list
-- @return number of nodes in the linked list
function linkedListModule.size(list)
    local count = 0
    local current = list.head
    while current do
        count = count + 1
        current = current.next
    end
    return count
end

linkedListModule.length = linkedListModule.size

return linkedListModule