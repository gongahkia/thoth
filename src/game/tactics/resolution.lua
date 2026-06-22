local Grid = require("src.core.grid")

local Resolution = {}

local function copyTiles(tiles)
    local result = {}
    for _, tile in ipairs(tiles or {}) do
        result[#result + 1] = { x = tile.x, y = tile.y }
    end
    return result
end

local function addTile(list, x, y)
    list[#list + 1] = { x = x, y = y }
end

local function addTileEffects(state, preview, x, y, damage)
    if not state:inBounds(x, y) then
        return
    end
    local tile = state:tileAt(x, y)
    if tile.hazard and tile.hazard.active then
        preview.hazardChain[#preview.hazardChain + 1] = { x = x, y = y, kind = tile.hazard.kind, damage = tile.hazard.damage or 0 }
    end
    local objective = state:objectiveAt(x, y)
    if objective and (damage or 0) > 0 then
        preview.objectiveDamage[#preview.objectiveDamage + 1] = { id = objective.id, x = x, y = y, damage = damage }
    end
end

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

function Resolution.actionPreview(state, command)
    local preview = {
        type = command.type,
        apCost = command.cost,
        affectedTiles = {},
        pushedPath = {},
        collision = nil,
        objectiveDamage = {},
        coverBreak = {},
        hazardChain = {},
    }
    if command.type == "move" then
        local unit = state:unit(command.unit)
        local delta = Grid.directions[command.direction]
        if unit and delta then
            local x = unit.x + delta.x
            local y = unit.y + delta.y
            addTile(preview.affectedTiles, x, y)
            addTileEffects(state, preview, x, y, 0)
        end
    elseif command.type == "attack" then
        local target = state:unit(command.target)
        if target then
            local attack = state:attackResolution(command.unit, command.target, command.damage or 1)
            addTile(preview.affectedTiles, target.x, target.y)
            addTileEffects(state, preview, target.x, target.y, attack.damage)
            preview.baseDamage = attack.baseDamage
            preview.damage = attack.damage
            preview.cover = attack.cover
            preview.effectiveCover = attack.effectiveCover
            preview.damageReduction = attack.damageReduction
            preview.damageReductionApplied = attack.damageReductionApplied
            preview.blocked = attack.blocked
            preview.flanked = attack.flanked
            preview.invalidatedCover = attack.invalidatedCover
            preview.flankingBonus = attack.flankingBonus
            preview.flankingRule = attack.flankingRule
        end
    elseif command.type == "heal" then
        local target = state:unit(command.target)
        if target then
            local amount = command.amount or 1
            addTile(preview.affectedTiles, target.x, target.y)
            preview.healing = { target = command.target, amount = amount, hpAfter = math.min(target.maxHp or target.hp or 0, (target.hp or 0) + amount) }
        end
    elseif command.type == "aoe" then
        preview.affectedTiles = copyTiles(command.tiles)
        for _, tile in ipairs(preview.affectedTiles) do
            addTileEffects(state, preview, tile.x, tile.y, command.damage or 1)
        end
    elseif command.type == "shove" then
        local target = state:unit(command.target)
        local delta = Grid.directions[command.direction]
        if target and delta then
            local x = target.x
            local y = target.y
            for _ = 1, command.distance or 1 do
                x = x + delta.x
                y = y + delta.y
                local ok, reason = state:canEnter(x, y, target.id)
                if not ok then
                    preview.collision = { x = x, y = y, reason = reason, damage = command.collisionDamage or 1 }
                    break
                end
                addTile(preview.pushedPath, x, y)
                addTile(preview.affectedTiles, x, y)
                addTileEffects(state, preview, x, y, command.collisionDamage or 1)
            end
        end
    elseif command.type == "dash" then
        local ok, steps = pcall(function()
            return state:dashUnit(command.unit, command.direction, command.distance, true)
        end)
        if ok then
            preview.dashPath = copyTiles(steps)
            for _, step in ipairs(steps) do
                addTile(preview.affectedTiles, step.x, step.y)
                addTileEffects(state, preview, step.x, step.y, 0)
            end
        else
            preview.error = tostring(steps):gsub("^.*:%d+: ", "")
        end
    elseif command.type == "swap" then
        local unit = state:unit(command.unit)
        local target = state:unit(command.target)
        if unit and target then
            preview.swap = { unit = command.unit, target = command.target, unitTile = { x = unit.x, y = unit.y }, targetTile = { x = target.x, y = target.y } }
            addTile(preview.affectedTiles, unit.x, unit.y)
            addTile(preview.affectedTiles, target.x, target.y)
        end
    elseif command.type == "damageTile" then
        addTile(preview.affectedTiles, command.x, command.y)
        local tile = state:tileAt(command.x, command.y)
        if tile.destructibleHp ~= nil then
            preview.coverBreak[#preview.coverBreak + 1] = { x = command.x, y = command.y, hpAfter = math.max(0, tile.destructibleHp - (command.damage or 1)), breaks = (command.damage or 1) >= tile.destructibleHp }
        end
    elseif command.type == "damageObjective" then
        local objective = state:objective(command.objective)
        if objective then
            addTile(preview.affectedTiles, objective.x, objective.y)
            preview.objectiveDamage[#preview.objectiveDamage + 1] = { id = objective.id, x = objective.x, y = objective.y, damage = command.damage or 1 }
        end
    elseif command.type == "repairObjective" then
        local objective = state:objective(command.objective)
        if objective then
            local amount = command.amount or 1
            addTile(preview.affectedTiles, objective.x, objective.y)
            preview.objectiveRepair = { id = objective.id, x = objective.x, y = objective.y, amount = amount, integrityAfter = math.min(objective.maxIntegrity or objective.integrity or 0, (objective.integrity or 0) + amount) }
        end
    elseif command.type == "convertTile" then
        addTile(preview.affectedTiles, command.x, command.y)
        preview.hazardChain[#preview.hazardChain + 1] = { x = command.x, y = command.y, conversion = command.conversion }
    elseif command.type == "obscurant" then
        addTile(preview.affectedTiles, command.x, command.y)
        preview.obscurant = { x = command.x, y = command.y, kind = command.kind, countdown = command.countdown }
    elseif command.type == "status" then
        local target = state:unit(command.target)
        if target then
            addTile(preview.affectedTiles, target.x, target.y)
            preview.status = { target = command.target, kind = command.status, turns = command.turns, amount = command.amount }
        end
    end
    return preview
end

return Resolution
