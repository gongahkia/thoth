local commands = require("thoth.addons.gameplay.commands")
local cooldowns = require("thoth.addons.gameplay.cooldowns")
local resources = require("thoth.addons.gameplay.resources")
local status = require("thoth.addons.gameplay.status")

local gameplay = {
    commands = commands,
    cooldowns = cooldowns,
    resources = resources,
    status = status,
}

function gameplay.install(runtime, options)
    options = options or {}

    local handle = {
        resources = resources.new(options.resources),
        cooldowns = cooldowns.new(options.cooldowns),
        status = status.new(options.status),
        commands = commands.new(options.commandHandlers),
    }

    runtime:registerSystem({
        name = options.systemName or "gameplay_addons",
        priority = options.priority or 50,
        fixedUpdate = function(rt, dt)
            handle.cooldowns:update(dt)
            handle.status:update(dt)
            handle.commands:update(dt, {
                runtime = rt,
                gameplay = handle,
            })
        end,
    })

    return handle
end

function gameplay.snapshot(handle)
    return {
        resources = handle.resources:snapshot(),
        cooldowns = handle.cooldowns:snapshot(),
        status = handle.status:snapshot(),
        commands = handle.commands:snapshot(),
    }
end

function gameplay.restore(handle, _runtime, snapshot)
    snapshot = snapshot or {}
    handle.resources:restore(snapshot.resources or {})
    handle.cooldowns:restore(snapshot.cooldowns or {})
    handle.status:restore(snapshot.status or {})
    handle.commands:restore(snapshot.commands or {})
end

return gameplay
