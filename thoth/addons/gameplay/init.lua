local commands = require("thoth.addons.gameplay.commands")
local cooldowns = require("thoth.addons.gameplay.cooldowns")
local inventory = require("thoth.addons.gameplay.inventory")
local resources = require("thoth.addons.gameplay.resources")
local scoring = require("thoth.addons.gameplay.scoring")
local skills = require("thoth.addons.gameplay.skills")
local status = require("thoth.addons.gameplay.status")

local gameplay = {
    commands = commands,
    cooldowns = cooldowns,
    inventory = inventory,
    resources = resources,
    scoring = scoring,
    skills = skills,
    status = status,
}

function gameplay.install(runtime, options)
    options = options or {}

    local handle = {
        resources = resources.new(options.resources),
        cooldowns = cooldowns.new(options.cooldowns),
        status = status.new(options.status),
        commands = commands.new(options.commandHandlers),
        inventory = options.inventory and inventory.new(options.inventory) or nil,
        scoring = options.scoring and scoring.new(options.scoring) or nil,
        skills = options.skills and skills.new(options.skills) or nil,
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
            if handle.scoring then
                handle.scoring:update(dt, rt.clock or 0)
            end
        end,
    })

    return handle
end

function gameplay.snapshot(handle)
    local snap = {
        resources = handle.resources:snapshot(),
        cooldowns = handle.cooldowns:snapshot(),
        status = handle.status:snapshot(),
        commands = handle.commands:snapshot(),
    }
    if handle.scoring then
        snap.scoring = handle.scoring:snapshot()
    end
    if handle.skills then
        snap.skills = handle.skills:snapshot()
    end
    return snap
end

function gameplay.restore(handle, _runtime, snapshot)
    snapshot = snapshot or {}
    handle.resources:restore(snapshot.resources or {})
    handle.cooldowns:restore(snapshot.cooldowns or {})
    handle.status:restore(snapshot.status or {})
    handle.commands:restore(snapshot.commands or {})
    if handle.scoring and snapshot.scoring then
        handle.scoring:restore(snapshot.scoring)
    end
    if handle.skills and snapshot.skills then
        handle.skills:restore(snapshot.skills)
    end
end

return gameplay
