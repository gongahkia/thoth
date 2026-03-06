local stackModule = {}

-- @param nil
-- @return empty stack
function stackModule.new()
    return {}
end

-- @param stack
-- @return boolean depending on whether a stack empty
function stackModule.isEmpty(stack)
    return #stack == 0
end

-- @param stack, value to be pushed onto stack
-- @return updated stack
function stackModule.push(stack, val)
    table.insert(stack, val)
    return stack
end

-- @param stack
-- @return popped value, updated stack
function stackModule.pop(stack)
    if stackModule.isEmpty(stack) then
        error("Stack is empty")
    end
    return table.remove(stack), stack
end

-- @param stack
-- @return top element of stack
function stackModule.peek(stack)
    if stackModule.isEmpty(stack) then
        error("Stack is empty")
    end
    return stack[#stack]
end

-- @param stack
-- @return stack size
function stackModule.size(stack)
    return #stack
end

return stackModule