local UICatalog = {}

UICatalog.icons = {
    { id = "ap", icon = "AP", shape = "pip", colorRole = "action", pattern = "solid", label = "action points" },
    { id = "move", icon = "MV", shape = "arrow", colorRole = "movement", pattern = "path", label = "move path" },
    { id = "cover", icon = "CV", shape = "edge shield", colorRole = "cover", pattern = "edge", label = "cover edge" },
    { id = "flanked", icon = "FL", shape = "broken shield", colorRole = "warning", pattern = "crosshatch", label = "flanked" },
    { id = "los", icon = "LOS", shape = "ray", colorRole = "sight", pattern = "line", label = "line of sight" },
    { id = "exact_intent", icon = "!", shape = "target", colorRole = "intent", pattern = "solid outline", label = "exact intent" },
    { id = "partial_intent", icon = "?", shape = "masked target", colorRole = "partial", pattern = "dashed outline", label = "partial intent" },
    { id = "hazard", icon = "HZ", shape = "triangle", colorRole = "hazard", pattern = "diagonal hatch", label = "hazard" },
    { id = "objective", icon = "OBJ", shape = "diamond", colorRole = "objective", pattern = "double outline", label = "objective" },
    { id = "destructible_hp", icon = "HP", shape = "cracked block", colorRole = "destructible", pattern = "tick marks", label = "destructible HP" },
    { id = "weak_point", icon = "WP", shape = "ring target", colorRole = "weakPoint", pattern = "ring", label = "weak point" },
    { id = "extraction", icon = "EX", shape = "exit chevron", colorRole = "extraction", pattern = "chevrons", label = "extraction" },
}

UICatalog.overlayFilters = {
    { id = "movement", icon = "move", shows = "reachable tiles, AP bands, carry path", hides = "enemy-only intent clutter" },
    { id = "enemy_intent", icon = "exact_intent", shows = "exact and partial enemy footprints", hides = "non-threat utility hints" },
    { id = "los", icon = "los", shows = "line of sight rays and blockers", hides = "movement AP bands" },
    { id = "cover", icon = "cover", shows = "cover edges, flanked edges, destructible cover", hides = "hazard-only tile marks" },
    { id = "objectives", icon = "objective", shows = "objective integrity, target links, extraction cargo", hides = "non-objective terrain" },
    { id = "hazards", icon = "hazard", shows = "hazard tiles, countdowns, forced movement", hides = "safe movement bands" },
    { id = "hidden_revealed", icon = "partial_intent", shows = "hidden marks, revealed facts, rotation secrets", hides = "known base terrain" },
}

function UICatalog.icon(id)
    for _, icon in ipairs(UICatalog.icons) do
        if icon.id == id then
            return icon
        end
    end
    return nil
end

function UICatalog.iconLanguage()
    return UICatalog.icons
end

function UICatalog.overlays()
    return UICatalog.overlayFilters
end

return UICatalog
