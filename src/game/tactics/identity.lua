-- per-unit identity generation: name, portrait id, quirks. deterministic via seed.
local Rng = require("src.core.rng")

local Identity = {}

Identity.firstNames = {
    "Aulin", "Beren", "Calix", "Devra", "Esme", "Fenra", "Gaius", "Hesper",
    "Iven", "Joren", "Kestrel", "Liora", "Marek", "Nira", "Oran", "Petra",
    "Quill", "Rovan", "Salka", "Tovi", "Ulen", "Vesna", "Wren", "Xara",
    "Yarrow", "Zelka", "Brina", "Cole", "Dema", "Ezra", "Faye", "Gren",
}

Identity.lastNames = {
    "Ashford", "Brand", "Cole", "Dross", "Ember", "Furrow", "Glass", "Hale",
    "Ink", "Jolt", "Kress", "Lattice", "Marrow", "Nettle", "Ochre", "Plinth",
    "Quill", "Rook", "Salt", "Tindle", "Umbra", "Vellum", "Warden", "Yore",
}

Identity.quirks = {
    -- positive
    { id = "iron_lungs",     polarity = "positive", effect = "hazard_damage_reduction_1", label = "iron lungs" },
    { id = "swift_step",     polarity = "positive", effect = "first_move_ap_refund",      label = "swift step" },
    { id = "keen_eye",       polarity = "positive", effect = "vision_radius_plus_1",      label = "keen eye" },
    { id = "steady_hand",    polarity = "positive", effect = "first_attack_flank",        label = "steady hand" },
    { id = "fast_recovery",  polarity = "positive", effect = "heal_amount_plus_1",        label = "fast recovery" },
    { id = "thick_hide",     polarity = "positive", effect = "max_hp_plus_1",             label = "thick hide" },
    -- negative
    { id = "shaky_nerves",   polarity = "negative", effect = "first_attack_minus_1",      label = "shaky nerves" },
    { id = "weak_lungs",     polarity = "negative", effect = "hazard_damage_plus_1",      label = "weak lungs" },
    { id = "slow_to_act",    polarity = "negative", effect = "max_ap_minus_1",            label = "slow to act" },
    { id = "fragile_record", polarity = "negative", effect = "carry_drops_at_half_hp",    label = "fragile record" },
    { id = "grim_disposition", polarity = "negative", effect = "stress_gain_plus_1",      label = "grim disposition" },
    { id = "haunted",        polarity = "negative", effect = "vision_radius_minus_1",     label = "haunted" },
}

local function pick(list, rng)
    if #list == 0 then return nil end
    return list[rng:range(1, #list)]
end

function Identity.generate(seed, classId)
    local rng = Rng.new(Rng.hash(seed or 1, classId and #classId or 0, 1, 1))
    local first = pick(Identity.firstNames, rng)
    local last = pick(Identity.lastNames, rng)
    local portraitIndex = rng:range(1, 16) -- portrait pool slot
    -- 1-2 quirks per unit: usually 1 positive + 1 negative
    local quirks = {}
    local positives, negatives = {}, {}
    for _, q in ipairs(Identity.quirks) do
        if q.polarity == "positive" then positives[#positives + 1] = q
        else negatives[#negatives + 1] = q end
    end
    quirks[#quirks + 1] = pick(positives, rng).id
    quirks[#quirks + 1] = pick(negatives, rng).id
    return {
        name = first .. " " .. last,
        portrait = string.format("portrait_%02d", portraitIndex),
        quirks = quirks,
    }
end

function Identity.quirkById(id)
    for _, q in ipairs(Identity.quirks) do
        if q.id == id then return q end
    end
    return nil
end

function Identity.quirkEffectApplied(quirks, effect)
    for _, id in ipairs(quirks or {}) do
        local q = Identity.quirkById(id)
        if q and q.effect == effect then return true end
    end
    return false
end

return Identity
