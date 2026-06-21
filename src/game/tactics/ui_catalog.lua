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

UICatalog.tileInspectorTemplate = {
    title = "{tileName}",
    mechanicsLine = "{icon} {state}: {verb} {effect}; AP {apCost}; counter {counterplay}",
    loreLine = "{zoneTone}: {oneSentenceLore}",
    maxMechanicsLines = 1,
    maxLoreLines = 1,
    requiredTokens = { "icon", "state", "verb", "effect", "apCost", "counterplay", "zoneTone", "oneSentenceLore" },
}

UICatalog.previewContract = {
    commitGate = "before_commit",
    fields = {
        { id = "ap_cost", source = "selected action and path", visible = true },
        { id = "movement_path", source = "pathfinder", visible = true },
        { id = "damage", source = "deterministic resolver", visible = true },
        { id = "push_path", source = "forced movement resolver", visible = true },
        { id = "collision", source = "forced movement collision", visible = true },
        { id = "cover_change", source = "cover edge diff", visible = true },
        { id = "objective_change", source = "objective integrity diff", visible = true },
        { id = "hazard_result", source = "hazard resolver", visible = true },
    },
}

UICatalog.rotationReadability = {
    rotations = { 0, 90, 180, 270 },
    appliesTo = { "movement", "enemy_intent", "los", "cover", "objectives", "hazards", "hidden_revealed" },
    checks = {
        { id = "symbol_visible", rule = "icon or shape remains visible at target zoom" },
        { id = "label_upright", rule = "text labels do not rotate with board plane" },
        { id = "logical_tile_stable", rule = "overlay logical tile stays unchanged after camera rotation" },
        { id = "screen_position_distinct", rule = "screen projection changes enough to confirm rotation" },
        { id = "non_color_redundant", rule = "shape or hatch carries meaning without color" },
        { id = "occlusion_clear", rule = "important symbol is not hidden by unit billboard or cover face" },
    },
}

UICatalog.tutorialSequence = {
    { id = "movement", teaches = "movement", board = "two AP path with safe and unsafe route", exitCheck = "player previews AP path then commits move" },
    { id = "cover_flank", teaches = "cover/flank", board = "half cover lane with one flank tile", exitCheck = "player identifies protected and flanked edge" },
    { id = "intent", teaches = "intent", board = "one enemy exact attack footprint", exitCheck = "player prevents declared hit" },
    { id = "forced_movement", teaches = "forced movement", board = "push enemy out of objective lane", exitCheck = "player previews push path and collision" },
    { id = "destructible_terrain", teaches = "destructible terrain", board = "break cover to open LoS", exitCheck = "player previews cover HP and post-break line" },
    { id = "objective_pressure", teaches = "objective pressure", board = "protect machinery under exact intent", exitCheck = "player preserves objective integrity" },
    { id = "redacted_intent", teaches = "redacted intent", board = "partial elite footprint with reveal tool", exitCheck = "player reveals category into exact tiles" },
    { id = "boss_weak_point", teaches = "boss weak point", board = "rotation reveals back-face weak point", exitCheck = "player rotates and counters boss procedure" },
}

UICatalog.screenshotSmokeTarget = {
    id = "tactical_overlay_smoke",
    fixture = "overlay_all_layers",
    viewport = { width = 1280, height = 720 },
    overlays = { "movement", "enemy_intent", "los", "cover", "objectives", "hazards", "hidden_revealed" },
    rotations = { 0, 90, 180, 270 },
    assertions = {
        "non_empty_overlay_layers",
        "icons_visible",
        "non_color_patterns_visible",
        "no_text_overlap",
        "logical_tiles_stable",
    },
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

function UICatalog.tileInspector()
    return UICatalog.tileInspectorTemplate
end

function UICatalog.preview()
    return UICatalog.previewContract
end

function UICatalog.rotationChecks()
    return UICatalog.rotationReadability
end

function UICatalog.tutorials()
    return UICatalog.tutorialSequence
end

function UICatalog.screenshotSmoke()
    return UICatalog.screenshotSmokeTarget
end

return UICatalog
