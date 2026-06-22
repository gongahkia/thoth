package.path = "./?.lua;./?/init.lua;./src/?.lua;./src/?/init.lua;" .. package.path

local Procgen = require("src.game.tactics.procgen")

local Validator = {}

Validator.fixedSeeds = {
    7101, 7102, 7103, 7104, 7105,
    7106, 7107, 7108, 7109, 7110,
    7111, 7112, 7113, 7114, 7115,
    7116, 7117, 7118, 7119, 7120,
    7121, 7122, 7123, 7124, 7125,
}

Validator.invariants = {
    "objective_reachable",
    "squad_spawn_safe",
    "enemy_placement_solvable",
}

local function tileKey(x, y)
    return tostring(x) .. ":" .. tostring(y)
end

local function sortedKeys(values)
    local keys = {}
    for key in pairs(values or {}) do
        keys[#keys + 1] = key
    end
    table.sort(keys, function(a, b)
        return tostring(a) < tostring(b)
    end)
    return keys
end

local function addReject(rejects, reason)
    rejects[#rejects + 1] = reason
end

local function inBounds(board, x, y)
    return board and x and y and x >= 1 and y >= 1 and x <= board.width and y <= board.height
end

local function tileOpen(board, x, y)
    if not inBounds(board, x, y) then
        return false
    end
    local tile = (board.tiles or {})[tileKey(x, y)] or {}
    return tile.blocker ~= true and tile.blockerKind ~= "hard"
end

local function startsForSide(spec, side)
    local result = {}
    for _, unit in ipairs(spec.units or {}) do
        if unit.side == side then
            result[#result + 1] = { x = unit.x, y = unit.y, id = unit.id }
        end
    end
    return result
end

local function flood(board, starts)
    local seen = {}
    local queue = {}
    for _, start in ipairs(starts or {}) do
        if tileOpen(board, start.x, start.y) then
            local key = tileKey(start.x, start.y)
            if not seen[key] then
                seen[key] = true
                queue[#queue + 1] = { x = start.x, y = start.y }
            end
        end
    end
    local index = 1
    while queue[index] do
        local node = queue[index]
        index = index + 1
        for _, delta in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
            local x = node.x + delta[1]
            local y = node.y + delta[2]
            local key = tileKey(x, y)
            if not seen[key] and tileOpen(board, x, y) then
                seen[key] = true
                queue[#queue + 1] = { x = x, y = y }
            end
        end
    end
    return seen
end

local function checkSquadSpawn(spec, rejects)
    local board = spec.board
    local occupied = {}
    local players = startsForSide(spec, "player")
    if #players == 0 then
        addReject(rejects, "squad_spawn_missing")
    end
    for _, unit in ipairs(players) do
        local key = tileKey(unit.x, unit.y)
        local tile = board and board.tiles and board.tiles[key] or {}
        if not tileOpen(board, unit.x, unit.y) then
            addReject(rejects, "squad_spawn_blocked:" .. tostring(unit.id))
        end
        if tile and tile.hazard and next(tile.hazard) ~= nil then
            addReject(rejects, "squad_spawn_hazard:" .. tostring(unit.id))
        end
        if occupied[key] then
            addReject(rejects, "unit_overlap:" .. key)
        end
        occupied[key] = true
    end
    local pockets = spec.grammar and spec.grammar.components and spec.grammar.components.spawnPockets or {}
    for _, pocket in ipairs(pockets) do
        if pocket.side == "player" then
            for _, tile in ipairs(pocket.tiles or {}) do
                if not tileOpen(board, tile.x, tile.y) then
                    addReject(rejects, "player_spawn_pocket_blocked:" .. pocket.id)
                end
            end
        end
    end
    return players, occupied
end

local function checkObjectives(spec, reachable, rejects)
    if #(spec.objectives or {}) == 0 then
        addReject(rejects, "objective_missing")
    end
    for _, objective in ipairs(spec.objectives or {}) do
        if not reachable[tileKey(objective.x, objective.y)] then
            addReject(rejects, "objective_unreachable:" .. tostring(objective.id))
        end
        local exit = objective.evacuateAt
        if exit and not reachable[tileKey(exit.x, exit.y)] then
            addReject(rejects, "objective_exit_unreachable:" .. tostring(objective.id))
        end
    end
end

local function checkEnemies(spec, reachable, occupied, rejects)
    local enemies = startsForSide(spec, "enemy")
    if #enemies == 0 then
        addReject(rejects, "enemy_missing")
    end
    for _, unit in ipairs(enemies) do
        local key = tileKey(unit.x, unit.y)
        if not tileOpen(spec.board, unit.x, unit.y) then
            addReject(rejects, "enemy_spawn_blocked:" .. tostring(unit.id))
        end
        if occupied[key] then
            addReject(rejects, "unit_overlap:" .. key)
        end
        occupied[key] = true
        if not reachable[key] then
            addReject(rejects, "enemy_unreachable:" .. tostring(unit.id))
        end
    end
    for _, rule in ipairs(((spec.encounterDirector or {}).spawnBlockRules) or {}) do
        if not (rule.spawnPocket and rule.onBlocked and rule.visible == true) then
            addReject(rejects, "spawn_block_rule_invalid:" .. tostring(rule.spawnPocket or "?"))
        end
    end
end

local function summaryForSpec(spec)
    local enemies = 0
    local players = 0
    for _, unit in ipairs(spec.units or {}) do
        if unit.side == "enemy" then
            enemies = enemies + 1
        elseif unit.side == "player" then
            players = players + 1
        end
    end
    local objective = spec.objectives and spec.objectives[1] or {}
    return {
        variantId = spec.generator and spec.generator.variantId,
        board = tostring((spec.board and spec.board.width) or "?") .. "x" .. tostring((spec.board and spec.board.height) or "?"),
        players = players,
        enemies = enemies,
        objective = objective.id,
    }
end

function Validator.validateSpec(spec, context)
    context = context or {}
    local rejects = {}
    if not (spec and spec.board) then
        return { accepted = false, rejectReasons = { "board_missing" }, context = context }
    end
    if spec.validation and spec.validation.valid == false then
        addReject(rejects, "grammar_invalid")
    end
    if spec.budget and spec.budget.accepted == false then
        for _, reason in ipairs(spec.budget.rejectReasons or {}) do
            addReject(rejects, "budget:" .. tostring(reason))
        end
    end
    local players, occupied = checkSquadSpawn(spec, rejects)
    local reachable = flood(spec.board, players)
    checkObjectives(spec, reachable, rejects)
    checkEnemies(spec, reachable, occupied, rejects)
    return {
        seed = context.seed or spec.seed,
        variantId = context.variantId or (spec.generator and spec.generator.variantId),
        accepted = #rejects == 0,
        rejectReasons = rejects,
        summary = summaryForSpec(spec),
    }
end

local function jsonEscape(value)
    return tostring(value):gsub('[%z\1-\31\\"]', function(ch)
        local escapes = { ['"'] = '\\"', ["\\"] = "\\\\", ["\b"] = "\\b", ["\f"] = "\\f", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }
        return escapes[ch] or string.format("\\u%04x", ch:byte())
    end)
end

local function isArray(value)
    local count = 0
    for key in pairs(value) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
            return false
        end
        count = math.max(count, key)
    end
    return count == #value
end

local function encodeJson(value)
    local kind = type(value)
    if kind == "nil" then
        return "null"
    end
    if kind == "boolean" or kind == "number" then
        return tostring(value)
    end
    if kind == "string" then
        return '"' .. jsonEscape(value) .. '"'
    end
    if kind ~= "table" then
        return '"' .. jsonEscape(value) .. '"'
    end
    local parts = {}
    if isArray(value) then
        for index = 1, #value do
            parts[#parts + 1] = encodeJson(value[index])
        end
        return "[" .. table.concat(parts, ",") .. "]"
    end
    for _, key in ipairs(sortedKeys(value)) do
        parts[#parts + 1] = encodeJson(tostring(key)) .. ":" .. encodeJson(value[key])
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

function Validator.encodeJson(value)
    return encodeJson(value)
end

local function writeFile(path, body)
    local dir = path:match("^(.*)/[^/]+$")
    if dir and dir ~= "" then
        os.execute("mkdir -p " .. dir)
    end
    local file, err = io.open(path, "w")
    if not file then
        return false, err
    end
    file:write(body)
    file:close()
    return true
end

function Validator.run(options)
    options = options or {}
    local route = Procgen.archiveRoute()
    local variants = route.variantOrder or {}
    local seeds = options.seeds or Validator.fixedSeeds
    local results = {}
    local rejects = {}
    for index, seed in ipairs(seeds) do
        local variantId = variants[((index - 1) % #variants) + 1]
        local ok, specOrErr = pcall(Procgen.generateArchiveRouteBoard, variantId, seed)
        local result
        if ok then
            result = Validator.validateSpec(specOrErr, { seed = seed, variantId = variantId })
        else
            result = { seed = seed, variantId = variantId, accepted = false, rejectReasons = { "generator_error:" .. tostring(specOrErr) }, summary = {} }
        end
        results[#results + 1] = result
        if not result.accepted then
            rejects[#rejects + 1] = { seed = seed, variantId = variantId, reasons = result.rejectReasons }
        end
    end
    local report = {
        validator = "procgen_validator_v1",
        routeId = route.id,
        seedCount = #seeds,
        rejectCount = #rejects,
        accepted = #rejects == 0,
        invariants = Validator.invariants,
        results = results,
        rejects = rejects,
    }
    local outputPath = options.outputPath or "dist/validator-report.json"
    local ok, err = writeFile(outputPath, encodeJson(report) .. "\n")
    if not ok then
        error(err, 2)
    end
    report.outputPath = outputPath
    return report
end

local function argValue(args, flag, fallback)
    for index, value in ipairs(args or {}) do
        if value == flag then
            return args[index + 1] or fallback
        end
    end
    return fallback
end

function Validator.main(args)
    local budget = tonumber(argValue(args, "--reject-budget", "0")) or 0
    local report = Validator.run({ outputPath = argValue(args, "--out", "dist/validator-report.json") })
    print("validator=" .. tostring(report.validator))
    print("validator-seeds=" .. tostring(report.seedCount))
    print("validator-budget=" .. tostring(budget))
    print("validator-rejects=" .. tostring(report.rejectCount))
    print("validator-report=" .. tostring(report.outputPath))
    return report.rejectCount <= budget and 0 or 1
end

local moduleName = ...
if moduleName ~= "tools.validator" then
    os.exit(Validator.main(arg))
end

return Validator
