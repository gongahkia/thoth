local ClassCatalog = {}

ClassCatalog.classes = {
    warden = {
        name = "Warden",
        loadouts = {
            { id = "line_guard", role = "frontline protector", tools = { "brace_pavise", "route_hook" } },
            { id = "claim_anchor", role = "objective holder", tools = { "claim_spike", "oath_tether" } },
            { id = "breach_shield", role = "cover breaker", tools = { "shelf_shove_kit", "breach_maul" } },
        },
        tools = {
            { id = "brace_pavise", effect = "raise mobile half cover" },
            { id = "route_hook", effect = "pull ally or cargo one tile" },
            { id = "claim_spike", effect = "brace on claim tile without losing LoS" },
            { id = "shelf_shove_kit", effect = "shove full cover or blocker one tile" },
            { id = "oath_tether", effect = "redirect first objective hit to Warden guard" },
            { id = "breach_maul", effect = "damage destructible cover and expose flanks" },
        },
        terrainInteractions = {
            { id = "raise_mobile_cover", terrain = "cover", effect = "turn adjacent low object into half cover" },
            { id = "shove_blocker", terrain = "blocker", effect = "move a shelf, barricade, or cart into a lane" },
        },
        weakness = { id = "slow_to_pivot", effect = "after guarding an objective, next move costs +1 AP" },
        replayFixture = "warden_brace_line",
    },
    duelist = {
        name = "Duelist",
        loadouts = {
            { id = "red_line", role = "dash striker", tools = { "razor_dash", "angle_step" } },
            { id = "patron_shadow", role = "position trader", tools = { "swap_foil", "riposte_mark" } },
            { id = "debt_blade", role = "flank finisher", tools = { "cloak_pin", "ledger_stiletto" } },
        },
        tools = {
            { id = "razor_dash", effect = "dash through a safe lane before attacking" },
            { id = "angle_step", effect = "shift one tile after a flank preview" },
            { id = "swap_foil", effect = "swap with adjacent enemy or ally" },
            { id = "riposte_mark", effect = "mark first enemy entering adjacent tile" },
            { id = "cloak_pin", effect = "ignore first overwatch line while flanking" },
            { id = "ledger_stiletto", effect = "bonus damage against isolated objective guards" },
        },
        terrainInteractions = {
            { id = "vault_low_cover", terrain = "half_cover", effect = "vault low cover without ending movement" },
            { id = "cut_hanging_line", terrain = "suspended_object", effect = "drop hanging cover into a flank lane" },
        },
        weakness = { id = "overextends", effect = "after dashing, adjacent enemies add +1 incoming damage" },
        replayFixture = "duelist_flank_dash",
    },
    mender = {
        name = "Apothecary",
        loadouts = {
            { id = "field_triage", role = "objective medic", tools = { "wound_clamp", "salt_draught" } },
            { id = "smoke_binder", role = "LoS controller", tools = { "hush_smoke", "salve_flare" } },
            { id = "plague_cutter", role = "hazard cleanser", tools = { "bitter_vial", "sterilize_hook" } },
        },
        tools = {
            { id = "wound_clamp", effect = "repair ally or civilian integrity" },
            { id = "salt_draught", effect = "cleanse brine or blight status" },
            { id = "hush_smoke", effect = "place short-lived obscurant" },
            { id = "salve_flare", effect = "reveal safe rescue route through smoke" },
            { id = "bitter_vial", effect = "apply deterministic debuff to one enemy" },
            { id = "sterilize_hook", effect = "drag cargo or patient out of hazard" },
        },
        terrainInteractions = {
            { id = "douse_brine_pool", terrain = "hazard", effect = "turn adjacent brine or burn tile inactive" },
            { id = "smoke_claim_line", terrain = "claim_line", effect = "obscure claim tile without changing ownership" },
        },
        weakness = { id = "triage_burden", effect = "after repairing an objective, next carry or drag costs +1 AP" },
        replayFixture = "apothecary_smoke_triage",
    },
    arcanist = {
        name = "Arcanist",
        loadouts = {
            { id = "seal_reader", role = "hidden-info reader", tools = { "seal_lantern", "syntax_hook" } },
            { id = "line_bender", role = "LoS manipulator", tools = { "glyph_prism", "angle_wax" } },
            { id = "intent_breaker", role = "intent disruptor", tools = { "hush_formula", "permission_key" } },
        },
        tools = {
            { id = "seal_lantern", effect = "reveal class-gated marks and weak points" },
            { id = "syntax_hook", effect = "pull one redacted intent into exact preview" },
            { id = "glyph_prism", effect = "bend one visible LoS ray around cover" },
            { id = "angle_wax", effect = "mark a tile as readable from current rotation" },
            { id = "hush_formula", effect = "interrupt one ritual or category intent" },
            { id = "permission_key", effect = "treat one sealed tile as passable for a move" },
        },
        terrainInteractions = {
            { id = "read_back_seal", terrain = "rotation_mark", effect = "reveal planning fact from reverse face" },
            { id = "bend_audit_beam", terrain = "los_lane", effect = "redirect one audit or heat line preview" },
        },
        weakness = { id = "overread", effect = "after revealing hidden info, next incoming stress is +2" },
        replayFixture = "arcanist_seal_read",
    },
    harrier = {
        name = "Thief",
        loadouts = {
            { id = "ghost_route", role = "stealth runner", tools = { "quiet_pick", "route_chalk" } },
            { id = "trap_lifter", role = "hazard disarmer", tools = { "tripwire_spool", "pocket_lantern" } },
            { id = "courier_cut", role = "objective extractor", tools = { "false_warrant", "escape_hook" } },
        },
        tools = {
            { id = "quiet_pick", effect = "open adjacent lock without raising exposure" },
            { id = "tripwire_spool", effect = "mark and disarm one trap lane" },
            { id = "route_chalk", effect = "reveal hidden safe tile on current path" },
            { id = "pocket_lantern", effect = "reveal one nearby hidden pickup" },
            { id = "false_warrant", effect = "carry objective cargo at normal move cost" },
            { id = "escape_hook", effect = "pull self or cargo to extraction edge" },
        },
        terrainInteractions = {
            { id = "disarm_name_lock", terrain = "lock", effect = "disable adjacent lock without breaking cover" },
            { id = "slip_drain_grate", terrain = "low_gap", effect = "move through a low drain or shelf gap" },
        },
        weakness = { id = "thin_loyalty", effect = "while carrying loot, guard effects on allies cost +1 AP" },
        replayFixture = "thief_route_lift",
    },
    chirurgeon = {
        name = "Chirurgeon",
        loadouts = {
            { id = "bone_setter", role = "injury stabilizer", tools = { "nerve_suture", "pain_contract" } },
            { id = "cautery_engineer", role = "burn controller", tools = { "cautery_lamp", "machine_splint" } },
            { id = "preservationist", role = "body-objective repair", tools = { "preservation_saw", "mercy_clamp" } },
        },
        tools = {
            { id = "nerve_suture", effect = "convert injury penalty into timed AP cost" },
            { id = "pain_contract", effect = "brace ally with deterministic stress debt" },
            { id = "cautery_lamp", effect = "douse bleed or burn lane around patient" },
            { id = "machine_splint", effect = "repair machinery objective integrity" },
            { id = "preservation_saw", effect = "extract body cargo without integrity loss" },
            { id = "mercy_clamp", effect = "prevent one civilian objective damage tick" },
        },
        terrainInteractions = {
            { id = "repair_machinery", terrain = "machinery", effect = "restore objective machinery integrity" },
            { id = "cauterize_burn_lane", terrain = "burn_hazard", effect = "turn adjacent burn hazard inactive" },
        },
        weakness = { id = "clinical_delay", effect = "after stabilizing an ally, next attack costs +1 AP" },
        replayFixture = "chirurgeon_stabilize_machine",
    },
    exile = {
        name = "Exile",
        loadouts = {
            { id = "faultbreaker", role = "terrain breaker", tools = { "ruin_maul", "fault_step" } },
            { id = "borderless", role = "hazard brawler", tools = { "hazard_hide", "spite_breath" } },
            { id = "thrown_oath", role = "forced-move bruiser", tools = { "exile_throw", "broken_oath_grip" } },
        },
        tools = {
            { id = "ruin_maul", effect = "destroy adjacent cover or brittle floor" },
            { id = "fault_step", effect = "move through one broken terrain tile" },
            { id = "hazard_hide", effect = "ignore first hazard tick this turn" },
            { id = "spite_breath", effect = "gain AP now and take deterministic self damage" },
            { id = "exile_throw", effect = "throw enemy or cargo one tile" },
            { id = "broken_oath_grip", effect = "pin target against blocker after shove" },
        },
        terrainInteractions = {
            { id = "break_cover", terrain = "cover", effect = "destroy adjacent cover and expose line" },
            { id = "stand_in_hazard", terrain = "hazard", effect = "hold hazard tile without random action loss" },
        },
        weakness = { id = "self_risk_spike", effect = "AP spikes deal 1 deterministic self damage" },
        replayFixture = "exile_break_cover",
    },
    lamplighter = {
        name = "Lamplighter",
        loadouts = {
            { id = "beacon_runner", role = "route revealer", tools = { "route_beacon", "white_flare" } },
            { id = "cone_keeper", role = "overwatch controller", tools = { "mirror_lantern", "wick_line" } },
            { id = "ash_lamp", role = "hidden-intent reducer", tools = { "smoke_gel", "safe_cinder" } },
        },
        tools = {
            { id = "route_beacon", effect = "reveal hidden route tile and extraction edge" },
            { id = "white_flare", effect = "force redacted intent into exact preview" },
            { id = "mirror_lantern", effect = "project overwatch cone around cover" },
            { id = "wick_line", effect = "connect two lit tiles for ally movement" },
            { id = "smoke_gel", effect = "turn smoke into light-blocking obscurant" },
            { id = "safe_cinder", effect = "mark one hazard tile safe for this turn" },
        },
        terrainInteractions = {
            { id = "light_back_seal", terrain = "rotation_mark", effect = "reveal back-face planning fact at range" },
            { id = "anchor_beacon", terrain = "route_node", effect = "make extraction route visible through obscurant" },
        },
        weakness = { id = "bright_target", effect = "after placing a beacon, exact intents against Lamplighter deal +1 damage" },
        replayFixture = "lamplighter_beacon_reveal",
    },
    merchant = {
        name = "Merchant",
        loadouts = {
            { id = "debt_broker", role = "risk converter", tools = { "debt_note", "risk_ledger" } },
            { id = "salvage_factor", role = "loot insurer", tools = { "salvage_drone", "escrow_token" } },
            { id = "mercy_accountant", role = "objective insurer", tools = { "appraisal_lens", "mercy_clause" } },
        },
        tools = {
            { id = "debt_note", effect = "gain AP now and record deterministic debt" },
            { id = "risk_ledger", effect = "convert incoming objective damage into future cost" },
            { id = "salvage_drone", effect = "carry small loot without occupying a unit" },
            { id = "escrow_token", effect = "protect extracted cargo from one damage tick" },
            { id = "appraisal_lens", effect = "mark enemy weak point or objective value" },
            { id = "mercy_clause", effect = "repair ally or civilian now, pay later" },
        },
        terrainInteractions = {
            { id = "appraise_weak_point", terrain = "weak_point", effect = "reveal and mark one weak point for profit" },
            { id = "escrow_objective", terrain = "objective", effect = "insure objective integrity before damage" },
        },
        weakness = { id = "compounding_debt", effect = "each debt tool adds a future AP tax" },
        replayFixture = "merchant_appraise_debt",
    },
}

ClassCatalog.traits = {
    { id = "quick_account", domain = "ap", effect = "+1 AP on first objective interaction" },
    { id = "slow_oath", domain = "ap", effect = "first attack each board costs +1 AP" },
    { id = "sure_stride", domain = "movement", effect = "ignore first rough-terrain move cost" },
    { id = "salt_limp", domain = "movement", effect = "water or brine movement costs +1 AP" },
    { id = "beam_reader", domain = "los", effect = "preview audit and heat lanes one tile farther" },
    { id = "smoke_shy", domain = "los", effect = "cannot reveal through obscurant" },
    { id = "cover_drilled", domain = "cover", effect = "first claimed cover improves by one step" },
    { id = "flank_careless", domain = "cover", effect = "flanked damage against this unit is +1" },
    { id = "porter_arms", domain = "carry", effect = "first cargo carry costs 0 AP" },
    { id = "fragile_grip", domain = "carry", effect = "dragging cargo through hazard deals +1 cargo damage" },
    { id = "seal_literate", domain = "reveal", effect = "rotation marks reveal at adjacent range" },
    { id = "mark_blind", domain = "reveal", effect = "class reveal actions cost +1 AP" },
    { id = "short_fuse", domain = "cooldown", effect = "first tool cooldown is reduced by one tick" },
    { id = "long_recovery", domain = "cooldown", effect = "after a tool use, next cooldown gains one tick" },
    { id = "repair_hands", domain = "objectiveRepair", effect = "first objective repair restores +1 integrity" },
    { id = "clumsy_patch", domain = "objectiveRepair", effect = "repairing destructible cover costs +1 AP" },
    { id = "enclave_favor", domain = "eventOutcome", effect = "enclave events start one step friendlier" },
    { id = "debt_shadow", domain = "eventOutcome", effect = "Merchant debt events add one pressure" },
    { id = "ledger_memory", domain = "eventOutcome", effect = "audit events reveal one extra route clause" },
    { id = "cold_focus", domain = "ap", effect = "ignore first AP tax from stress debt" },
}

ClassCatalog.injuryDebts = {
    { id = "cracked_ribs", type = "injury", constraint = "climb and vault cost +1 AP", noRandomActionLoss = true },
    { id = "salt_cough", type = "injury", constraint = "LoS reveal range is reduced by one tile in mist", noRandomActionLoss = true },
    { id = "burned_hand", type = "injury", constraint = "first cover interaction each board costs +1 AP", noRandomActionLoss = true },
    { id = "glass_eye", type = "injury", constraint = "class reveal actions require LoS to target tile", noRandomActionLoss = true },
    { id = "brine_rot", type = "injury", constraint = "objective repair restores one less integrity", noRandomActionLoss = true },
    { id = "torn_shoulder", type = "injury", constraint = "carry and drag actions cost +1 AP", noRandomActionLoss = true },
    { id = "ash_tremor", type = "injury", constraint = "first tool cooldown gains one tick", noRandomActionLoss = true },
    { id = "nerve_burn", type = "injury", constraint = "dash distance is capped at two tiles", noRandomActionLoss = true },
    { id = "paper_lung", type = "injury", constraint = "obscurant entry costs +1 AP", noRandomActionLoss = true },
    { id = "ledger_debt", type = "debt", constraint = "first AP refund each board is cancelled", noRandomActionLoss = true },
    { id = "oath_lien", type = "debt", constraint = "protect objective failure adds faction loss", noRandomActionLoss = true },
    { id = "marked_warrant", type = "debt", constraint = "Survey Office events start at +1 pressure", noRandomActionLoss = true },
    { id = "pawned_tool", type = "debt", constraint = "one chosen tool starts on cooldown", noRandomActionLoss = true },
    { id = "witness_guilt", type = "debt", constraint = "civilian objective damage adds stress debt", noRandomActionLoss = true },
    { id = "lamp_debt", type = "debt", constraint = "Lamplighter reveal costs +1 AP until paid", noRandomActionLoss = true },
}

function ClassCatalog.class(id)
    return ClassCatalog.classes[id]
end

function ClassCatalog.loadouts(id)
    local class = ClassCatalog.class(id)
    return class and class.loadouts or {}
end

function ClassCatalog.tools(id)
    local class = ClassCatalog.class(id)
    return class and class.tools or {}
end

function ClassCatalog.terrainInteractions(id)
    local class = ClassCatalog.class(id)
    return class and class.terrainInteractions or {}
end

function ClassCatalog.characterTraits()
    return ClassCatalog.traits
end

function ClassCatalog.injuryDebtConstraints()
    return ClassCatalog.injuryDebts
end

return ClassCatalog
