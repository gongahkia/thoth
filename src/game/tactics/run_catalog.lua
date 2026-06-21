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

return RunCatalog
