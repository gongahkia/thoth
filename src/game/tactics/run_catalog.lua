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

return RunCatalog
