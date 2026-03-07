local ecs = require("thoth.game.ecs")
local behavior = require("thoth.game.behavior")

local entities = {
    {id = 1, kind = "player", hp = 10},
    {id = 2, kind = "enemy", hp = 3},
    {id = 3, kind = "enemy", hp = 0},
}

local enemies = ecs.query(entities, {kind = "enemy"})
assert(#enemies == 2)
assert(ecs.first(entities, function(entity)
    return entity.hp <= 0
end).id == 3)

local groups = ecs.groupBy(entities, "kind")
assert(#groups.enemy == 2 and #groups.player == 1)

ecs.updateEach(entities, {kind = "enemy"}, function(entity)
    entity.hp = entity.hp + 1
end)
assert(entities[2].hp == 4 and entities[3].hp == 1)

ecs.removeWhere(entities, function(entity)
    return entity.hp <= 1
end)
assert(#entities == 2)

local context = {
    hasTarget = true,
    attacks = 0,
}

local tree = behavior.sequence({
    behavior.condition(function(ctx)
        return ctx.hasTarget
    end),
    behavior.action(function(ctx)
        ctx.attacks = ctx.attacks + 1
        return behavior.SUCCESS
    end),
})

assert(behavior.tick(tree, context) == behavior.SUCCESS)
assert(context.attacks == 1)

local fallback = behavior.selector({
    behavior.condition(function()
        return false
    end),
    behavior.action(function()
        return behavior.SUCCESS
    end),
})
assert(behavior.tick(fallback, context) == behavior.SUCCESS)

local inverted = behavior.invert(behavior.condition(function()
    return false
end))
assert(behavior.tick(inverted, context) == behavior.SUCCESS)

local repeats = 0
local repeatNode = behavior.repeatUntilFailure(behavior.action(function()
    repeats = repeats + 1
    if repeats >= 3 then
        return behavior.FAILURE
    end
    return behavior.SUCCESS
end), 5)
assert(behavior.tick(repeatNode, context) == behavior.SUCCESS)
assert(repeats == 3)
