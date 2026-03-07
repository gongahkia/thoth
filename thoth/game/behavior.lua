local behavior = {}

behavior.SUCCESS = "success"
behavior.FAILURE = "failure"
behavior.RUNNING = "running"

local function wrap(kind, impl)
    return {
        kind = kind,
        tick = impl,
    }
end

function behavior.condition(fn)
    return wrap("condition", function(context)
        return fn(context) and behavior.SUCCESS or behavior.FAILURE
    end)
end

function behavior.action(fn)
    return wrap("action", function(context)
        return fn(context) or behavior.SUCCESS
    end)
end

function behavior.sequence(children)
    return wrap("sequence", function(context)
        for _, child in ipairs(children) do
            local result = child.tick(context)
            if result ~= behavior.SUCCESS then
                return result
            end
        end
        return behavior.SUCCESS
    end)
end

function behavior.selector(children)
    return wrap("selector", function(context)
        for _, child in ipairs(children) do
            local result = child.tick(context)
            if result == behavior.SUCCESS or result == behavior.RUNNING then
                return result
            end
        end
        return behavior.FAILURE
    end)
end

function behavior.invert(child)
    return wrap("invert", function(context)
        local result = child.tick(context)
        if result == behavior.SUCCESS then
            return behavior.FAILURE
        end
        if result == behavior.FAILURE then
            return behavior.SUCCESS
        end
        return result
    end)
end

function behavior.repeatUntilFailure(child, limit)
    return wrap("repeatUntilFailure", function(context)
        local iterations = 0
        while limit == nil or iterations < limit do
            iterations = iterations + 1
            local result = child.tick(context)
            if result == behavior.FAILURE then
                return behavior.SUCCESS
            end
            if result == behavior.RUNNING then
                return behavior.RUNNING
            end
        end
        return behavior.SUCCESS
    end)
end

function behavior.tick(node, context)
    return node.tick(context or {})
end

return behavior
