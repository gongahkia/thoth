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

return UICatalog
