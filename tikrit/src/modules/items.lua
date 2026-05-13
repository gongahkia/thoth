local CONFIG = require("config")
local Utils = require("modules/utils")

local Items = {}

Items.aliases = {
    medicine = "painkillers",
}

Items.definitions = {
    matches = {label = "Matches", weight = 0.05, stackable = true},
    accelerant = {label = "Accelerant", weight = 0.3, stackable = true},
    tinder = {label = "Tinder", weight = 0.08, stackable = true},
    sticks = {label = "Sticks", weight = 0.2, stackable = true},
    firewood = {label = "Firewood", weight = 0.7, stackable = true},
    cloth = {label = "Cloth", weight = 0.15, stackable = true},
    sewing_kit = {label = "Sewing Kit", weight = 0.1, stackable = true},
    snow = {label = "Packed Snow", weight = 0.25, stackable = true},
    water = {label = "Water", weight = 0.45, stackable = true, thirst = 24},
    canned_food = {
        label = "Canned Food",
        weight = 0.65,
        stackable = true,
        calories = 420,
        perishable = true,
        decayPerHour = 0.28,
    },
    raw_meat = {
        label = "Raw Meat",
        weight = 0.8,
        stackable = true,
        calories = 260,
        perishable = true,
        decayPerHour = 1.25,
        foodPoisoningThreshold = 85,
    },
    cooked_meat = {
        label = "Cooked Meat",
        weight = 0.7,
        stackable = true,
        calories = 520,
        perishable = true,
        decayPerHour = 0.75,
        foodPoisoningThreshold = 20,
    },
    raw_fish = {
        label = "Raw Fish",
        weight = 0.55,
        stackable = true,
        calories = 220,
        perishable = true,
        decayPerHour = 1.1,
        foodPoisoningThreshold = 80,
    },
    cooked_fish = {
        label = "Cooked Fish",
        weight = 0.5,
        stackable = true,
        calories = 420,
        perishable = true,
        decayPerHour = 0.68,
        foodPoisoningThreshold = 20,
    },
    tea = {
        label = "Tea",
        weight = 0.3,
        stackable = true,
        thirst = 12,
        warmth = 12,
        condition = 2,
        perishable = true,
        decayPerHour = 0.35,
    },
    bandage = {
        label = "Bandage",
        weight = 0.1,
        stackable = true,
        treatment = {sprain = true},
    },
    painkillers = {
        label = "Painkillers",
        weight = 0.08,
        stackable = true,
        treatment = {sprain = true},
        condition = 1,
    },
    antiseptic = {
        label = "Antiseptic",
        weight = 0.12,
        stackable = true,
        treatment = {infectionRisk = true},
    },
    antibiotics = {
        label = "Antibiotics",
        weight = 0.08,
        stackable = true,
        treatment = {infection = true, infectionRisk = true},
    },
    torch = {label = "Torch", weight = 0.4, stackable = true, lightHours = 1.5, lightPower = 4},
    flare = {label = "Flare", weight = 0.25, stackable = true, lightHours = 2.5, lightPower = 5},
    bedroll = {label = "Bedroll", weight = 1.2, stackable = false, station = "field_shelter"},
    knife = {label = "Knife", weight = 0.4, stackable = false, equipSlot = "tool", toolType = "knife", tileDamage = 2, staminaCost = 2},
    hatchet = {label = "Hatchet", weight = 0.8, stackable = false, equipSlot = "tool", toolType = "axe", tileDamage = 3, staminaCost = 4},
    sword = {label = "Sword", weight = 1.1, stackable = false, equipSlot = "weapon", weaponClass = "melee", damage = 26, staminaCost = 18},
    bow = {label = "Bow", weight = 0.9, stackable = false, equipSlot = "weapon", combatRole = "utility", damage = 36, staminaCost = 16},
    arrow = {label = "Arrow", weight = 0.08, stackable = true, ammoRole = "hunting"},
    rope_bolt = {label = "Rope Bolt", weight = 0.12, stackable = true, ammoRole = "utility"},
    signal_bolt = {label = "Signal Bolt", weight = 0.1, stackable = true, ammoRole = "utility"},
    bridge_kit = {label = "Bridge Kit", weight = 1.4, stackable = true, toolRole = "traversal", station = "field"},
    survey_kit = {label = "Survey Kit", weight = 0.75, stackable = false, toolRole = "survey", station = "map"},
    snare = {label = "Snare", weight = 0.35, stackable = true},
    fishing_tackle = {label = "Fishing Tackle", weight = 0.18, stackable = true},
    charcoal = {label = "Charcoal", weight = 0.08, stackable = true},
    rabbit_pelt = {label = "Rabbit Pelt", weight = 0.35, stackable = true},
    deer_hide = {label = "Deer Hide", weight = 0.85, stackable = true},
    gut = {label = "Fresh Gut", weight = 0.18, stackable = true},
    cured_rabbit_pelt = {label = "Cured Rabbit Pelt", weight = 0.28, stackable = true},
    cured_deer_hide = {label = "Cured Deer Hide", weight = 0.72, stackable = true},
    cured_gut = {label = "Cured Gut", weight = 0.14, stackable = true},
    feather = {label = "Feather", weight = 0.02, stackable = true},
    rabbit_wraps = {label = "Rabbit Wraps", weight = 0.5, stackable = false},
}

local function cloneItem(item)
    local copy = {}
    for key, value in pairs(item) do
        copy[key] = Utils.deepCopy(value)
    end
    return copy
end

function Items.normalizeKind(kind)
    return Items.aliases[kind] or kind
end

function Items.getDefinition(kind)
    return Items.definitions[Items.normalizeKind(kind)]
end

function Items.describe(kind)
    local normalized = Items.normalizeKind(kind)
    local definition = Items.getDefinition(normalized)
    return definition and definition.label or tostring(normalized)
end

function Items.isPerishable(kind)
    local definition = Items.getDefinition(kind)
    return definition and definition.perishable == true
end

function Items.create(kind, quantity)
    local normalized = Items.normalizeKind(kind)
    local definition = Items.getDefinition(normalized)
    local item = {
        kind = normalized,
        quantity = quantity or 1,
    }
    if definition and definition.perishable then
        item.condition = 100
    end
    return item
end

function Items.cloneInventory(inventory)
    local copy = {}
    for index, item in ipairs(inventory or {}) do
        copy[index] = cloneItem(item)
    end
    return copy
end

function Items.add(inventory, kind, quantity)
    inventory = inventory or {}
    quantity = quantity or 1
    local normalized = Items.normalizeKind(kind)
    local definition = Items.getDefinition(normalized)
    if definition and definition.stackable ~= false then
        for _, item in ipairs(inventory) do
            if Items.normalizeKind(item.kind) == normalized then
                item.kind = normalized
                item.quantity = item.quantity + quantity
                if definition.perishable and item.condition == nil then
                    item.condition = 100
                end
                return item
            end
        end
    end

    local item = Items.create(normalized, quantity)
    table.insert(inventory, item)
    return item
end

function Items.remove(inventory, kind, quantity)
    inventory = inventory or {}
    quantity = quantity or 1
    local normalized = Items.normalizeKind(kind)

    for index = #inventory, 1, -1 do
        local item = inventory[index]
        if Items.normalizeKind(item.kind) == normalized then
            item.kind = normalized
            local amount = math.min(quantity, item.quantity or 1)
            item.quantity = (item.quantity or 1) - amount
            quantity = quantity - amount
            if item.quantity <= 0 then
                table.remove(inventory, index)
            end
            if quantity <= 0 then
                return true
            end
        end
    end

    return false
end

function Items.count(inventory, kind)
    local total = 0
    local normalized = Items.normalizeKind(kind)
    for _, item in ipairs(inventory or {}) do
        if Items.normalizeKind(item.kind) == normalized then
            total = total + (item.quantity or 1)
        end
    end
    return total
end

function Items.totalWeight(inventory)
    local total = 0
    for _, item in ipairs(inventory or {}) do
        local definition = Items.getDefinition(item.kind)
        if definition then
            total = total + (definition.weight * (item.quantity or 1))
        end
    end
    return total
end

function Items.findIndex(inventory, kind)
    local normalized = Items.normalizeKind(kind)
    for index, item in ipairs(inventory or {}) do
        if Items.normalizeKind(item.kind) == normalized then
            return index
        end
    end
    return nil
end

function Items.findItem(inventory, kind)
    local index = Items.findIndex(inventory, kind)
    return index and inventory[index] or nil, index
end

function Items.adjustCondition(item, delta)
    if not item then
        return nil
    end
    item.condition = Utils.clamp((item.condition or 100) + delta, 0, 100)
    return item.condition
end

local function updateCarryWeight(player)
    player.carryWeight = Items.totalWeight(player.inventory)
end

local function inflictFoodPoisoning(run)
    run.player.afflictions = run.player.afflictions or {}
    run.player.afflictions.foodPoisoningHours = math.max(
        run.player.afflictions.foodPoisoningHours or 0,
        CONFIG.FOOD_POISONING_HOURS
    )
end

local function placeBedroll(run)
    local World = require("modules/world")
    local TileRegistry = require("modules/tile_registry")
    local Furniture = require("modules/furniture")
    World.attachRun(run)
    local tile, level = World.currentTile(run)
    if tile == "weak_ice" or tile == "ice" or tile == "lake" or not TileRegistry.isWalkable(tile, level) then
        return false, "You need firm ground for the bedroll."
    end
    Furniture.spawn(level, "bedroll", {run.player.coord[1], run.player.coord[2]}, {
        placed = true,
        pickup = true,
    })
    Items.remove(run.player.inventory, "bedroll", 1)
    updateCarryWeight(run.player)
    return true, "You lay out the bedroll."
end

function Items.use(run, itemOrKind, _target)
    if not run or not run.player then
        return false, "No one can use that."
    end

    local item = type(itemOrKind) == "table" and itemOrKind or Items.findItem(run.player.inventory, itemOrKind)
    if not item then
        return false, "Nothing in that slot."
    end

    local definition = Items.getDefinition(item.kind)
    if not definition then
        return false, "That item cannot be used."
    end

    if definition.equipSlot == "tool" then
        run.player.equippedTool = item.kind
        return true, "Equipped " .. Items.describe(item.kind) .. "."
    elseif definition.equipSlot == "weapon" then
        run.player.equippedWeapon = item.kind
        if definition.weaponClass == "melee" then
            run.player.equippedMeleeWeapon = item.kind
        end
        return true, "Readied " .. Items.describe(item.kind) .. "."
    elseif item.kind == "bedroll" then
        return placeBedroll(run)
    end

    local used = false
    local message = "That item is used indirectly."

    if definition.calories then
        run.player.calories = Utils.clamp(run.player.calories + definition.calories, CONFIG.MAX_CALORIES)
        used = true
    end
    if definition.thirst then
        run.player.thirst = Utils.clamp(run.player.thirst + definition.thirst, CONFIG.MAX_THIRST)
        used = true
    end
    if definition.warmth then
        run.player.warmth = Utils.clamp(run.player.warmth + definition.warmth, CONFIG.MAX_WARMTH)
        used = true
    end
    if definition.condition then
        run.player.condition = Utils.clamp(run.player.condition + definition.condition, run.player.maxCondition)
        used = true
    end
    if definition.lightHours then
        run.player.equippedLight = item.kind
        run.player.equippedLightHours = definition.lightHours
        used = true
    end
    if definition.treatment then
        local afflictions = run.player.afflictions or {}
        local treated = false
        if definition.treatment.sprain and afflictions.sprain then
            afflictions.sprain = false
            afflictions.sprainRisk = 0
            afflictions.sprainRecovery = CONFIG.SPRAIN_RECOVERY_HOURS
            treated = true
        end
        if definition.treatment.infectionRisk and (afflictions.infectionRiskHours or 0) > 0 then
            afflictions.infectionRiskHours = 0
            treated = true
        end
        if definition.treatment.infection and afflictions.infection then
            afflictions.infection = false
            treated = true
        end
        used = used or treated
    end

    if not used then
        return false, message
    end

    if definition.perishable and item.condition ~= nil then
        local threshold = definition.foodPoisoningThreshold or -1
        if item.condition <= threshold then
            inflictFoodPoisoning(run)
        end
    end

    Items.remove(run.player.inventory, item.kind, 1)
    Items.sortInventory(run.player.inventory)
    updateCarryWeight(run.player)
    return true, "Used " .. Items.describe(item.kind) .. "."
end

function Items.sortInventory(inventory)
    table.sort(inventory, function(left, right)
        local leftLabel = Items.describe(left.kind)
        local rightLabel = Items.describe(right.kind)
        if leftLabel == rightLabel then
            local leftCondition = left.condition or 101
            local rightCondition = right.condition or 101
            if leftCondition == rightCondition then
                return (left.quantity or 1) > (right.quantity or 1)
            end
            return leftCondition > rightCondition
        end
        return leftLabel < rightLabel
    end)
end

return Items
