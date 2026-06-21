local Resolution = {}

function Resolution.apply(state, command)
    return state:apply(command)
end

function Resolution.queue(state, command)
    return state:queue(command)
end

function Resolution.step(state)
    return state:step()
end

function Resolution.snapshot(state)
    return state:snapshot()
end

return Resolution
