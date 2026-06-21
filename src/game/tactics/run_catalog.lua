local Rng = require("src.core.rng")
local Serialize = require("src.core.serialize")

local RunCatalog = {}

RunCatalog.boardTemplates = {
    { id = "kill_light", objective = "defeat marked threats", layout = "compact lanes with low objective load", pressure = "enemy intent density", validationFocus = "reachable threat tiles" },
    { id = "protect_heavy", objective = "protect multiple civilian or machinery nodes", layout = "wide cover field around anchors", pressure = "objective integrity", validationFocus = "objective feasibility" },
    { id = "extraction", objective = "carry cargo to extraction edge", layout = "route with branching exits", pressure = "exit access", validationFocus = "cargo path reachability" },
    { id = "repair", objective = "repair route machinery under threat", layout = "machinery anchors with tool routes", pressure = "repair AP timing", validationFocus = "interact tile access" },
    { id = "stealth", objective = "cross or extract while exposure stays below cap", layout = "sight gaps and hidden marks", pressure = "readable patrol intent", validationFocus = "LoS sanity" },
    { id = "split_squad", objective = "solve two separated anchors with one squad", layout = "two wings joined by toggled crossing", pressure = "route dependency", validationFocus = "bidirectional reachability" },
    { id = "holdout", objective = "hold claim or pressure tiles until countdown ends", layout = "defensible center with spawn edges", pressure = "reinforcement timing", validationFocus = "cover density" },
    { id = "boss_route", objective = "counter staged procedure and protect objective", layout = "large arena with weak-point rotations", pressure = "boss phase clock", validationFocus = "intent density and exit access" },
}

RunCatalog.boardValidators = {
    { id = "reachability", input = "walk graph", reject = "any spawn, objective, or exit is unreachable" },
    { id = "los_sanity", input = "height blockers and cover edges", reject = "declared LoS differs by camera rotation or crosses hard blockers" },
    { id = "cover_density", input = "cover tiles per threat lane", reject = "cover ratio outside template min/max" },
    { id = "objective_feasibility", input = "objective anchors and AP budget", reject = "objective cannot be reached or protected before first failure tick" },
    { id = "enemy_intent_density", input = "declared enemy footprints", reject = "too many threatened tiles for squad AP budget" },
    { id = "exit_access", input = "extract edges and cargo path", reject = "exit cannot be reached from objective or spawn" },
}

RunCatalog.difficultyWeights = {
    enemies = 5,
    objectives = 4,
    hazards = 3,
    cover = -2,
    reinforcements = 4,
    redactedIntent = 3,
    bossModifiers = 6,
}

RunCatalog.routeNodeTypes = {
    { id = "combat", risk = "standard board", reward = "baseline salvage", preview = "template and enemy family" },
    { id = "repair", risk = "machinery pressure", reward = "route integrity or unlock", preview = "repair objective and hazard" },
    { id = "enclave", risk = "faction demand", reward = "standing or survivor aid", preview = "faction meter delta" },
    { id = "market", risk = "debt or price pressure", reward = "tools, trinkets, supplies", preview = "stock and debt clause" },
    { id = "event", risk = "pre/post-board roll", reward = "modifier, standing, or resource", preview = "event timing window" },
    { id = "elite", risk = "partial intent enemy", reward = "rare unlock or high salvage", preview = "elite family and weak point" },
    { id = "boss", risk = "boss procedure", reward = "seal progress", preview = "boss variant and objective threat" },
    { id = "rest", risk = "time passes", reward = "heal, clear injury, or repair debt", preview = "week and dread change" },
    { id = "cursed_shortcut", risk = "dread or debt spike", reward = "skip route pressure", preview = "cost before commit" },
    { id = "high_reward_extraction", risk = "harder exit pressure", reward = "extra cargo and proof", preview = "cargo value and exit rules" },
}

RunCatalog.eventRngRules = {
    { id = "pre_board_complication", timing = "pre_board", roll = "before board seed locks", effect = "add board modifier or route pressure" },
    { id = "pre_board_offer", timing = "pre_board", roll = "before squad deployment", effect = "offer debt, tool, or faction trade" },
    { id = "post_board_reward", timing = "post_board", roll = "after deterministic resolution", effect = "adjust salvage, trinket, or standing reward" },
    { id = "post_board_consequence", timing = "post_board", roll = "after extraction or loss", effect = "apply injury, dread, faction, or route event" },
}

RunCatalog.seededRunExport = {
    version = 1,
    fields = {
        { id = "runSeed", type = "integer", source = "campaign start seed" },
        { id = "boardSeeds", type = "list", source = "per-board generator seeds" },
        { id = "routeChoices", type = "list", source = "chosen route node ids" },
        { id = "squadLoadout", type = "list", source = "unit class, tools, traits, injuries, debt" },
        { id = "eventRolls", type = "list", source = "pre-board and post-board event outcomes" },
        { id = "replayHashes", type = "list", source = "deterministic replay hash per board" },
    },
}

RunCatalog.eventPrompts = {
    { id = "event_route_01", alters = "route_choice", prompt = "Survey office posts a false safe route; choose longer scouting or accept redacted node preview." },
    { id = "event_route_02", alters = "route_choice", prompt = "A lamplighter beacon points through sealed stacks; spend fuel to reveal a shortcut." },
    { id = "event_route_03", alters = "route_choice", prompt = "Merchant runners offer a debt road that skips one combat and adds post-board payment." },
    { id = "event_route_04", alters = "route_choice", prompt = "A drowned map shows a cistern bypass; choose low-ground risk or normal route." },
    { id = "event_route_05", alters = "route_choice", prompt = "Ash marks reveal an ember side door; take it to dodge elites and raise heat pressure." },
    { id = "event_route_06", alters = "route_choice", prompt = "Custodians demand the legal road; ignoring it improves time and hurts faction standing." },
    { id = "event_route_07", alters = "route_choice", prompt = "A witness names a hidden enclave; divert for aid or keep boss-route tempo." },
    { id = "event_route_08", alters = "route_choice", prompt = "The Stack corrects the map; one node swaps with a repair route before entry." },
    { id = "event_route_09", alters = "route_choice", prompt = "A market caravan blocks the short road; pay supplies or take an event node." },
    { id = "event_route_10", alters = "route_choice", prompt = "A cursed shortcut opens under the archive; accept dread to skip one validator-safe board." },
    { id = "event_board_01", alters = "board_modifier", prompt = "Audit lenses are pre-lit; next board starts with one extra exact line intent." },
    { id = "event_board_02", alters = "board_modifier", prompt = "Salt pressure is unstable; first flood lane countdown starts one turn lower." },
    { id = "event_board_03", alters = "board_modifier", prompt = "Ash choke rolls across the room; center cover starts obscured." },
    { id = "event_board_04", alters = "board_modifier", prompt = "Claim desks are overturned; half cover increases and objective access narrows." },
    { id = "event_board_05", alters = "board_modifier", prompt = "A sealed door misfiles itself; one route opens and one LoS lane closes." },
    { id = "event_board_06", alters = "board_modifier", prompt = "Pressure bells are cracked; bell adds spawn late but flood lanes hit harder." },
    { id = "event_board_07", alters = "board_modifier", prompt = "Glass dust settles on cover; first line attack reflects unless cover is shattered." },
    { id = "event_board_08", alters = "board_modifier", prompt = "Route machinery is exposed; protect-heavy boards add one objective anchor." },
    { id = "event_board_09", alters = "board_modifier", prompt = "A witness drawer sticks open; one hidden mark begins revealed." },
    { id = "event_board_10", alters = "board_modifier", prompt = "Old water takes the floor; low-ground tiles start rough but drain routes improve." },
    { id = "event_squad_01", alters = "squad_state", prompt = "A survivor asks for escort; one unit starts carrying a civilian and gains route standing." },
    { id = "event_squad_02", alters = "squad_state", prompt = "Debt collectors call terms; accept AP tax now or lose market access." },
    { id = "event_squad_03", alters = "squad_state", prompt = "Smoke sickness spreads; one unit enters with reduced reveal range." },
    { id = "event_squad_04", alters = "squad_state", prompt = "A chirurgeon offers a clamp; clear one injury and add post-board debt." },
    { id = "event_squad_05", alters = "squad_state", prompt = "A lamplighter lends a flare; one unit gets free reveal on first turn." },
    { id = "event_squad_06", alters = "squad_state", prompt = "Surveyors draft a witness; one roster slot is locked for this board." },
    { id = "event_squad_07", alters = "squad_state", prompt = "Brine ruins boots; first water move costs +1 AP for the squad." },
    { id = "event_squad_08", alters = "squad_state", prompt = "Glass splinters in packs; carrying cargo risks one integrity loss on dash." },
    { id = "event_squad_09", alters = "squad_state", prompt = "A quiet vow steadies the team; first objective interaction costs 0 AP." },
    { id = "event_squad_10", alters = "squad_state", prompt = "The Estate withholds supplies; choose stress relief or tool recharge before entry." },
    { id = "event_reward_01", alters = "objective_reward", prompt = "A record is worth more intact; extraction reward doubles if cargo takes no damage." },
    { id = "event_reward_02", alters = "objective_reward", prompt = "Custodians pay for seals; bonus reward if no sealed doors are broken." },
    { id = "event_reward_03", alters = "objective_reward", prompt = "Lamplighters pay for proof; bonus reward if all hidden marks are revealed." },
    { id = "event_reward_04", alters = "objective_reward", prompt = "Merchants insure machinery; reward converts to gold if repair objective survives." },
    { id = "event_reward_05", alters = "objective_reward", prompt = "A survivor names kin; rescue objective grants standing instead of salvage." },
    { id = "event_reward_06", alters = "objective_reward", prompt = "A bell relic can be lifted; extra reward appears if flood toll never expires." },
    { id = "event_reward_07", alters = "objective_reward", prompt = "Ash glass is valuable; shattered reflectors add reward but raise heat." },
    { id = "event_reward_08", alters = "objective_reward", prompt = "Archive proof fragments scatter; broken evidence cover creates optional cargo." },
    { id = "event_reward_09", alters = "objective_reward", prompt = "A debt note matures; pay coin now to increase post-board trinket odds." },
    { id = "event_reward_10", alters = "objective_reward", prompt = "Boss-route seal wax hardens; finish fast to improve seal reward." },
    { id = "event_faction_01", alters = "faction_standing", prompt = "Custodians demand no collateral damage; comply for standing or break cover freely." },
    { id = "event_faction_02", alters = "faction_standing", prompt = "Lamplighters ask for beacon placement; spend AP on route beacon for standing." },
    { id = "event_faction_03", alters = "faction_standing", prompt = "Merchants claim salvage rights; give up cargo value or lose market standing." },
    { id = "event_faction_04", alters = "faction_standing", prompt = "Survey office requests a clean map; reveal all exits to gain standing." },
    { id = "event_faction_05", alters = "faction_standing", prompt = "An enclave hides fugitives; protect them to gain enclave standing and anger surveyors." },
    { id = "event_faction_06", alters = "faction_standing", prompt = "A bailiff offers legal cover; accept it and owe custodians a later route." },
    { id = "event_faction_07", alters = "faction_standing", prompt = "Lamplighter defectors sell a shortcut; buying it hurts official lamp standing." },
    { id = "event_faction_08", alters = "faction_standing", prompt = "Merchant collectors target a debtor; shield them to lose debt standing and gain survivor standing." },
    { id = "event_faction_09", alters = "faction_standing", prompt = "Custodian archivists want proof unburned; douse fuel stores for standing." },
    { id = "event_faction_10", alters = "faction_standing", prompt = "The Estate asks for speed over mercy; finish route fast or protect survivors for different standing." },
}

local runMapZones = {
    buried_archive = { boss = "vault_regent", enclave = "custodian annex", hazard = "audit static" },
    salt_cistern = { boss = "pearl_choir", enclave = "drowned pump ward", hazard = "flood lane" },
    ember_warrens = { boss = "cinder_prioress", enclave = "ash shelter", hazard = "burn lane" },
}

local runMapZoneOrder = { "buried_archive", "salt_cistern", "ember_warrens" }

local function copyValue(value)
    if type(value) ~= "table" then
        return value
    end
    local result = {}
    for key, nested in pairs(value) do
        result[key] = copyValue(nested)
    end
    return result
end

local function preview(risk, reward, detail)
    return { risk = risk, reward = reward, detail = detail, visible = true }
end

local function eventFor(seed)
    local rng = Rng.new(seed or 1)
    return RunCatalog.eventPrompts[rng:range(1, #RunCatalog.eventPrompts)]
end

local function eventsForAlter(alter)
    local result = {}
    for _, event in ipairs(RunCatalog.eventPrompts) do
        if not alter or event.alters == alter then
            result[#result + 1] = event
        end
    end
    return #result > 0 and result or RunCatalog.eventPrompts
end

local function eventRuleFor(timing)
    local matches = {}
    for _, rule in ipairs(RunCatalog.eventRngRules) do
        if rule.timing == timing then
            matches[#matches + 1] = rule
        end
    end
    return matches
end

local function node(id, kind, depth, data)
    local result = copyValue(data or {})
    result.id = id
    result.kind = kind
    result.depth = depth
    result.next = result.next or {}
    return result
end

local function hashText(text, seed)
    local hash = seed or 1
    for index = 1, #text do
        hash = Rng.hash(hash, text:byte(index), index, #text)
    end
    return string.format("%08x", hash)
end

local function boardSeedFor(runSeed, nodeId, index)
    return Rng.hash(runSeed or 1, index, #nodeId, 2707)
end

function RunCatalog.boardTemplate(id)
    for _, template in ipairs(RunCatalog.boardTemplates) do
        if template.id == id then
            return template
        end
    end
    return nil
end

function RunCatalog.templates()
    return RunCatalog.boardTemplates
end

function RunCatalog.validators()
    return RunCatalog.boardValidators
end

function RunCatalog.weights()
    return RunCatalog.difficultyWeights
end

function RunCatalog.routeNodes()
    return RunCatalog.routeNodeTypes
end

function RunCatalog.eventRules()
    return RunCatalog.eventRngRules
end

function RunCatalog.seededExport()
    return RunCatalog.seededRunExport
end

function RunCatalog.events()
    return RunCatalog.eventPrompts
end

function RunCatalog.exportSeededRun(seed, options)
    options = options or {}
    local map = options.map or RunCatalog.generateMap(seed, { zone = options.zone })
    local routeChoices = copyValue(options.routeChoices or map.choices)
    local eventLayer = options.eventLayer or RunCatalog.rollEventLayer(seed, options.eventContext)
    local boardSeeds = {}
    local replayHashes = {}
    for index, nodeId in ipairs(routeChoices) do
        local boardSeed = boardSeedFor(seed, nodeId, index)
        boardSeeds[#boardSeeds + 1] = { nodeId = nodeId, seed = boardSeed }
        replayHashes[#replayHashes + 1] = hashText(Serialize.encode({
            runSeed = seed or 1,
            boardSeed = boardSeed,
            nodeId = nodeId,
            preEvent = eventLayer.preBoard.eventId,
            postEvent = eventLayer.postBoard.eventId,
        }), seed or 1)
    end
    local export = {
        version = RunCatalog.seededRunExport.version,
        runSeed = seed or 1,
        boardSeeds = boardSeeds,
        routeChoices = routeChoices,
        squadLoadout = copyValue(options.squadLoadout or {
            { id = "warden", class = "warden", tools = { "brace", "shove" } },
            { id = "duelist", class = "duelist", tools = { "dash", "flank" } },
        }),
        eventRolls = { eventLayer.preBoard, eventLayer.postBoard },
        replayHashes = replayHashes,
    }
    export.exportHash = hashText(Serialize.encode(export), seed or 1)
    return export
end

function RunCatalog.validateSeededRunExport(export)
    local report = { valid = true, missing = {} }
    for _, field in ipairs(RunCatalog.seededRunExport.fields) do
        if export == nil or export[field.id] == nil then
            report.valid = false
            report.missing[#report.missing + 1] = field.id
        end
    end
    if export and (#(export.boardSeeds or {}) ~= #(export.routeChoices or {}) or #(export.replayHashes or {}) ~= #(export.routeChoices or {})) then
        report.valid = false
        report.missing[#report.missing + 1] = "route_seed_hash_alignment"
    end
    return report
end

function RunCatalog.generateMap(seed, options)
    options = options or {}
    local rng = Rng.new(seed or 1)
    local zoneId = options.zone or runMapZoneOrder[rng:range(1, #runMapZoneOrder)]
    local zone = runMapZones[zoneId] or runMapZones.buried_archive
    local event = eventFor((seed or 1) + 404)
    local nodes = {
        node("start", "start", 0, {
            zone = zoneId,
            preview = preview("none", "choose route", "branch into tactical pressure"),
            next = { "combat_route", "enclave_request" },
        }),
        node("combat_route", "combat", 1, {
            zone = zoneId,
            template = "kill_light",
            preview = preview("standard combat", "baseline salvage", "known enemy family and " .. zone.hazard),
            next = { "event_node", "elite_route" },
        }),
        node("enclave_request", "enclave", 1, {
            zone = zoneId,
            request = { enclave = zone.enclave, ask = "protect local machinery", reward = "standing and repair aid", failure = "route dread +1" },
            preview = preview("objective pressure", "enclave standing", "local request before board load"),
            next = { "event_node", "repair_route" },
        }),
        node("event_node", "event", 2, {
            zone = zoneId,
            eventId = event.id,
            eventTiming = event.alters,
            preview = preview("pre/post mission complication", "modifier or resource", event.prompt),
            next = { "boss_gate" },
        }),
        node("elite_route", "elite", 2, {
            zone = zoneId,
            template = "protect_heavy",
            preview = preview("partial intent elite", "rare unlock", "higher enemy intent density"),
            next = { "boss_gate" },
        }),
        node("repair_route", "repair", 2, {
            zone = zoneId,
            template = "repair",
            preview = preview("machinery pressure", "route integrity", "repair objective under " .. zone.hazard),
            next = { "boss_gate" },
        }),
        node("boss_gate", "boss", 3, {
            zone = zoneId,
            gate = { boss = zone.boss, requires = { "one depth-2 node cleared" }, preview = "boss variant and objective threat" },
            preview = preview("boss procedure", "seal progress", "requires one route commitment"),
            next = {},
        }),
    }
    local byId = {}
    for _, entry in ipairs(nodes) do
        byId[entry.id] = entry
    end
    return {
        seed = seed or 1,
        zone = zoneId,
        start = "start",
        bossGate = "boss_gate",
        choices = { "combat_route", "enclave_request" },
        nodes = nodes,
        nodeById = byId,
    }
end

function RunCatalog.rollEvent(seed, timing, context)
    context = context or {}
    if timing ~= "pre_board" and timing ~= "post_board" then
        error("event roll timing must be pre_board or post_board", 2)
    end
    local rng = Rng.new((seed or 1) + (timing == "pre_board" and 7001 or 9001))
    local rules = eventRuleFor(timing)
    local rule = rules[rng:range(1, #rules)]
    local events = eventsForAlter(context.alters)
    local event = events[rng:range(1, #events)]
    return {
        timing = timing,
        ruleId = rule.id,
        roll = rule.roll,
        effect = rule.effect,
        eventId = event.id,
        alters = event.alters,
        prompt = event.prompt,
        boardStarted = false,
    }
end

function RunCatalog.rollEventLayer(seed, context)
    context = context or {}
    return {
        seed = seed or 1,
        boardSeed = context.boardSeed or ((seed or 1) + 1),
        preBoard = RunCatalog.rollEvent(seed, "pre_board", context.preBoard),
        postBoard = RunCatalog.rollEvent(seed, "post_board", context.postBoard),
        tacticalResolutionRng = false,
        boardStartLocksRng = true,
    }
end

function RunCatalog.validateEventLayer(layer)
    local report = { valid = true, missing = {} }
    if not layer or not layer.preBoard or layer.preBoard.timing ~= "pre_board" then
        report.valid = false
        report.missing[#report.missing + 1] = "pre_board"
    end
    if not layer or not layer.postBoard or layer.postBoard.timing ~= "post_board" then
        report.valid = false
        report.missing[#report.missing + 1] = "post_board"
    end
    if not layer or layer.tacticalResolutionRng ~= false or layer.boardStartLocksRng ~= true then
        report.valid = false
        report.missing[#report.missing + 1] = "tactical_rng_lock"
    end
    return report
end

function RunCatalog.validateMap(map)
    local report = { valid = true, missing = {}, counts = { choices = #(map and map.choices or {}) } }
    local neededKinds = { combat = true, event = true, enclave = true, boss = true }
    local seenKinds = {}
    local byId = map and map.nodeById or {}
    for _, entry in ipairs(map and map.nodes or {}) do
        seenKinds[entry.kind] = true
        if not entry.preview or not entry.preview.risk or not entry.preview.reward then
            report.valid = false
            report.missing[#report.missing + 1] = entry.id .. ".preview"
        end
        for _, nextId in ipairs(entry.next or {}) do
            if not byId[nextId] then
                report.valid = false
                report.missing[#report.missing + 1] = entry.id .. "->" .. tostring(nextId)
            end
        end
    end
    for kind in pairs(neededKinds) do
        if not seenKinds[kind] then
            report.valid = false
            report.missing[#report.missing + 1] = kind
        end
    end
    return report
end

return RunCatalog
