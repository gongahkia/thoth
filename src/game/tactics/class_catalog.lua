local ClassCatalog = {}

ClassCatalog.classes = {
    warden = {
        name = "Warden",
        loadoutSlots = 2,
        boardVerbs = { "brace", "raise_cover", "shove", "redirect_objective_hit" },
        loadouts = {
            { id = "line_guard", boardVerb = "brace_line", tools = { "brace_pavise", "route_hook" }, unlock = { scope = "default", source = "starter_roster", rewardKind = "class_option", rewardId = "warden_line_guard", preview = "brace and hook basics" } },
            { id = "claim_anchor", boardVerb = "hold_claim", tools = { "claim_spike", "oath_tether" }, unlock = { scope = "run", source = "protect_objective_integrity", rewardKind = "class_option", rewardId = "warden_claim_anchor", preview = "hold claim tiles under objective fire" } },
            { id = "breach_shield", boardVerb = "break_cover", tools = { "route_hook", "breach_maul" }, unlock = { scope = "run", source = "break_cover_route", rewardKind = "class_option", rewardId = "warden_breach_shield", preview = "break cover and expose flank lanes" } },
        },
        tools = {
            { id = "brace_pavise", effect = "raise mobile half cover" },
            { id = "route_hook", effect = "pull ally or cargo one tile" },
            { id = "claim_spike", effect = "brace on claim tile without losing LoS" },
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
        loadoutSlots = 2,
        boardVerbs = { "dash", "flank", "swap", "riposte" },
        loadouts = {
            { id = "red_line", boardVerb = "dash_strike", tools = { "razor_dash", "angle_step" }, unlock = { scope = "default", source = "starter_roster", rewardKind = "class_option", rewardId = "duelist_red_line", preview = "dash and strike from a safe lane" } },
            { id = "patron_shadow", boardVerb = "swap_position", tools = { "swap_foil", "riposte_mark" }, unlock = { scope = "run", source = "complete_flank_objective", rewardKind = "class_option", rewardId = "duelist_patron_shadow", preview = "swap positions and mark adjacency" } },
            { id = "debt_blade", boardVerb = "convert_flank", tools = { "cloak_pin", "angle_step" }, unlock = { scope = "run", source = "elite_guard_extract", rewardKind = "class_option", rewardId = "duelist_debt_blade", preview = "convert risky flanks into finishers" } },
        },
        tools = {
            { id = "razor_dash", effect = "dash through a safe lane before attacking" },
            { id = "angle_step", effect = "shift one tile after a flank preview" },
            { id = "swap_foil", effect = "swap with adjacent enemy or ally" },
            { id = "riposte_mark", effect = "mark first enemy entering adjacent tile" },
            { id = "cloak_pin", effect = "ignore first overwatch line while flanking" },
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
        loadoutSlots = 2,
        boardVerbs = { "stabilize", "smoke", "cleanse_hazard", "rescue" },
        loadouts = {
            { id = "field_triage", boardVerb = "stabilize_objective", tools = { "wound_clamp", "salt_draught" }, unlock = { scope = "default", source = "starter_roster", rewardKind = "class_option", rewardId = "mender_field_triage", preview = "stabilize damaged units and objectives" } },
            { id = "smoke_binder", boardVerb = "place_smoke", tools = { "hush_smoke", "salve_flare" }, unlock = { scope = "run", source = "rescue_through_obscurant", rewardKind = "class_option", rewardId = "mender_smoke_binder", preview = "place smoke and reveal safe rescue lanes" } },
            { id = "plague_cutter", boardVerb = "cleanse_hazard", tools = { "salt_draught", "sterilize_hook" }, unlock = { scope = "run", source = "cleanse_hazard_board", rewardKind = "class_option", rewardId = "mender_plague_cutter", preview = "cleanse hazards and pull patients clear" } },
        },
        tools = {
            { id = "wound_clamp", effect = "repair ally or civilian integrity" },
            { id = "salt_draught", effect = "cleanse brine or blight status" },
            { id = "hush_smoke", effect = "place short-lived obscurant" },
            { id = "salve_flare", effect = "reveal safe rescue route through smoke" },
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
        loadoutSlots = 2,
        boardVerbs = { "reveal", "bend_los", "unredact_intent", "pass_seal" },
        loadouts = {
            { id = "seal_reader", boardVerb = "reveal_hidden_mark", tools = { "seal_lantern", "syntax_hook" }, unlock = { scope = "default", source = "archive_progress", rewardKind = "class_option", rewardId = "arcanist_seal_reader", preview = "reveal hidden marks and exact notices" } },
            { id = "line_bender", boardVerb = "bend_los", tools = { "glyph_prism", "syntax_hook" }, unlock = { scope = "run", source = "rotate_los_puzzle", rewardKind = "class_option", rewardId = "arcanist_line_bender", preview = "bend LoS around audited cover" } },
            { id = "intent_breaker", boardVerb = "interrupt_intent", tools = { "hush_formula", "permission_key" }, unlock = { scope = "run", source = "unredact_boss_notice", rewardKind = "class_option", rewardId = "arcanist_intent_breaker", preview = "interrupt category or ritual intent" } },
        },
        tools = {
            { id = "seal_lantern", effect = "reveal class-gated marks and weak points" },
            { id = "syntax_hook", effect = "pull one redacted intent into exact preview" },
            { id = "glyph_prism", effect = "bend one visible LoS ray around cover" },
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
        loadoutSlots = 2,
        boardVerbs = { "sneak", "disarm", "extract", "mark_route" },
        loadouts = {
            { id = "ghost_route", boardVerb = "sneak_route", tools = { "quiet_pick", "route_chalk" }, unlock = { scope = "default", source = "starter_roster", rewardKind = "class_option", rewardId = "harrier_ghost_route", preview = "open quiet routes and mark safe tiles" } },
            { id = "trap_lifter", boardVerb = "disarm_hazard", tools = { "tripwire_spool", "route_chalk" }, unlock = { scope = "run", source = "disarm_trap_route", rewardKind = "class_option", rewardId = "harrier_trap_lifter", preview = "disarm hazard lanes before crossing" } },
            { id = "courier_cut", boardVerb = "extract_cargo", tools = { "false_warrant", "escape_hook" }, unlock = { scope = "run", source = "extract_cargo_clean", rewardKind = "class_option", rewardId = "harrier_courier_cut", preview = "move objective cargo without AP bleed" } },
        },
        tools = {
            { id = "quiet_pick", effect = "open adjacent lock without raising exposure" },
            { id = "tripwire_spool", effect = "mark and disarm one trap lane" },
            { id = "route_chalk", effect = "reveal hidden safe tile on current path" },
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
        loadoutSlots = 2,
        boardVerbs = { "repair", "stabilize_injury", "douse", "preserve_cargo" },
        loadouts = {
            { id = "bone_setter", boardVerb = "stabilize_injury", tools = { "nerve_suture", "mercy_clamp" }, unlock = { scope = "default", source = "archive_boss_recovery", rewardKind = "class_option", rewardId = "chirurgeon_bone_setter", preview = "stabilize injury debt during boards" } },
            { id = "cautery_engineer", boardVerb = "douse_burn", tools = { "cautery_lamp", "machine_splint" }, unlock = { scope = "run", source = "douse_burn_lane", rewardKind = "class_option", rewardId = "chirurgeon_cautery_engineer", preview = "douse burns and repair machinery" } },
            { id = "preservationist", boardVerb = "preserve_body", tools = { "preservation_saw", "mercy_clamp" }, unlock = { scope = "run", source = "recover_body_objective", rewardKind = "class_option", rewardId = "chirurgeon_preservationist", preview = "preserve body cargo and civilians" } },
        },
        tools = {
            { id = "nerve_suture", effect = "convert injury penalty into timed AP cost" },
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
        loadoutSlots = 2,
        boardVerbs = { "break_terrain", "throw", "stand_hazard", "self_risk_ap" },
        loadouts = {
            { id = "faultbreaker", boardVerb = "break_terrain", tools = { "ruin_maul", "fault_step" }, unlock = { scope = "default", source = "cistern_progress", rewardKind = "class_option", rewardId = "exile_faultbreaker", preview = "break cover and cross broken terrain" } },
            { id = "borderless", boardVerb = "hold_hazard", tools = { "hazard_hide", "spite_breath" }, unlock = { scope = "run", source = "hold_hazard_objective", rewardKind = "class_option", rewardId = "exile_borderless", preview = "hold hazard tiles at self-risk" } },
            { id = "thrown_oath", boardVerb = "throw_unit", tools = { "exile_throw", "ruin_maul" }, unlock = { scope = "run", source = "forced_move_elite", rewardKind = "class_option", rewardId = "exile_thrown_oath", preview = "throw units and cargo into new lanes" } },
        },
        tools = {
            { id = "ruin_maul", effect = "destroy adjacent cover or brittle floor" },
            { id = "fault_step", effect = "move through one broken terrain tile" },
            { id = "hazard_hide", effect = "ignore first hazard tick this turn" },
            { id = "spite_breath", effect = "gain AP now and take deterministic self damage" },
            { id = "exile_throw", effect = "throw enemy or cargo one tile" },
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
        loadoutSlots = 2,
        boardVerbs = { "reveal_route", "project_cone", "anchor_beacon", "safe_hazard" },
        loadouts = {
            { id = "beacon_runner", boardVerb = "anchor_beacon", tools = { "route_beacon", "smoke_gel" }, unlock = { scope = "default", source = "cistern_boss_route", rewardKind = "class_option", rewardId = "lamplighter_beacon_runner", preview = "anchor extraction through obscurant" } },
            { id = "cone_keeper", boardVerb = "project_overwatch", tools = { "mirror_lantern", "wick_line" }, unlock = { scope = "run", source = "hold_overwatch_route", rewardKind = "class_option", rewardId = "lamplighter_cone_keeper", preview = "project cones and link lit tiles" } },
            { id = "ash_lamp", boardVerb = "reduce_hidden_intent", tools = { "smoke_gel", "safe_cinder" }, unlock = { scope = "run", source = "warrens_smoke_board", rewardKind = "class_option", rewardId = "lamplighter_ash_lamp", preview = "turn smoke and cinders into safer routes" } },
        },
        tools = {
            { id = "route_beacon", effect = "reveal hidden route tile and extraction edge" },
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
        loadoutSlots = 2,
        boardVerbs = { "convert_risk", "insure_objective", "carry_drone", "appraise_weak_point" },
        loadouts = {
            { id = "debt_broker", boardVerb = "convert_debt_to_ap", tools = { "debt_note", "risk_ledger" }, unlock = { scope = "default", source = "merchant_ledger_event", rewardKind = "class_option", rewardId = "merchant_debt_broker", preview = "convert risk into AP debt" } },
            { id = "salvage_factor", boardVerb = "insure_salvage", tools = { "salvage_drone", "risk_ledger" }, unlock = { scope = "run", source = "extract_salvage_event", rewardKind = "class_option", rewardId = "merchant_salvage_factor", preview = "insure salvage before extraction" } },
            { id = "mercy_accountant", boardVerb = "insure_objective", tools = { "appraisal_lens", "mercy_clause" }, unlock = { scope = "run", source = "protect_civilian_contract", rewardKind = "class_option", rewardId = "merchant_mercy_accountant", preview = "insure objectives and pay later" } },
        },
        tools = {
            { id = "debt_note", effect = "gain AP now and record deterministic debt" },
            { id = "risk_ledger", effect = "convert incoming objective damage into future cost" },
            { id = "salvage_drone", effect = "carry small loot without occupying a unit" },
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

ClassCatalog.starterRoster = {
    { classId = "warden", loadoutIds = { "line_guard", "claim_anchor" }, routeRole = "cover and objective guard", preview = "brace lanes or hold claim pressure", strongBoardFixture = "archive_shelf_protection", awkwardBoardFixture = "archive_proof_extract" },
    { classId = "duelist", loadoutIds = { "red_line", "patron_shadow" }, routeRole = "flank and reposition", preview = "dash through safe lanes or swap adjacency", strongBoardFixture = "archive_entry_audit", awkwardBoardFixture = "archive_shelf_protection" },
    { classId = "mender", loadoutIds = { "field_triage", "smoke_binder" }, routeRole = "repair and rescue support", preview = "stabilize objectives or place smoke", strongBoardFixture = "archive_ledger_repair", awkwardBoardFixture = "archive_elite_claim" },
    { classId = "harrier", loadoutIds = { "ghost_route", "courier_cut" }, routeRole = "route and extraction utility", preview = "open quiet paths or move proof cargo", strongBoardFixture = "archive_proof_extract", awkwardBoardFixture = "archive_sealed_shortcut" },
    { classId = "arcanist", loadoutIds = { "seal_reader", "line_bender" }, routeRole = "seal and intent control", preview = "reveal sealed facts or bend LoS", strongBoardFixture = "archive_sealed_shortcut", awkwardBoardFixture = "archive_proof_extract" },
    { classId = "lamplighter", loadoutIds = { "beacon_runner", "cone_keeper" }, routeRole = "route light and overwatch control", preview = "anchor beacon routes or project cones", strongBoardFixture = "archive_entry_audit", awkwardBoardFixture = "archive_elite_claim" },
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

ClassCatalog.requiredTraitDomains = { "ap", "movement", "los", "cooldown", "cover", "objectiveRepair" }

ClassCatalog.injuryDebts = {
    { id = "cracked_ribs", type = "injury", domain = "movement", constraint = "climb and vault cost +1 AP", noRandomActionLoss = true },
    { id = "salt_cough", type = "injury", domain = "los", constraint = "LoS reveal range is reduced by one tile in mist", noRandomActionLoss = true },
    { id = "burned_hand", type = "injury", domain = "cover", constraint = "first cover interaction each board costs +1 AP", noRandomActionLoss = true },
    { id = "glass_eye", type = "injury", domain = "reveal", constraint = "class reveal actions require LoS to target tile", noRandomActionLoss = true },
    { id = "brine_rot", type = "injury", domain = "objectiveRepair", constraint = "objective repair restores one less integrity", noRandomActionLoss = true },
    { id = "torn_shoulder", type = "injury", domain = "carry", constraint = "carry and drag actions cost +1 AP", noRandomActionLoss = true },
    { id = "ash_tremor", type = "injury", domain = "cooldown", constraint = "first tool cooldown gains one tick", noRandomActionLoss = true },
    { id = "nerve_burn", type = "injury", domain = "movement", constraint = "dash distance is capped at two tiles", noRandomActionLoss = true },
    { id = "paper_lung", type = "injury", domain = "los", constraint = "obscurant entry costs +1 AP", noRandomActionLoss = true },
    { id = "ledger_debt", type = "debt", domain = "ap", constraint = "first AP refund each board is cancelled", noRandomActionLoss = true },
    { id = "oath_lien", type = "debt", domain = "objectiveRepair", constraint = "protect objective failure adds faction loss", noRandomActionLoss = true },
    { id = "marked_warrant", type = "debt", domain = "eventPressure", constraint = "Survey Office events start at +1 pressure", noRandomActionLoss = true },
    { id = "pawned_tool", type = "debt", domain = "cooldown", constraint = "one chosen tool starts on cooldown", noRandomActionLoss = true },
    { id = "witness_guilt", type = "debt", domain = "stress", constraint = "civilian objective damage adds stress debt", noRandomActionLoss = true },
    { id = "lamp_debt", type = "debt", domain = "reveal", constraint = "Lamplighter reveal costs +1 AP until paid", noRandomActionLoss = true },
}

ClassCatalog.requiredInjuryDebtDomains = { "ap", "movement", "los", "cooldown", "cover", "objectiveRepair", "carry", "reveal" }

ClassCatalog.squadScaling = {
    [2] = { apBudget = 6, deploymentSlots = 2, enemyBudgetMultiplier = 0.65, objectivePressure = "single", reinforcementCap = 1, boardScale = "compact", board = { width = 7, height = 6, objectiveAnchors = 1, spawnPockets = 1, retreatRoutes = 1 }, varianceRules = { deploymentPattern = "pair", laneCount = 1, coverFields = 2, hazardBudget = 1 } },
    [3] = { apBudget = 9, deploymentSlots = 3, enemyBudgetMultiplier = 0.85, objectivePressure = "light", reinforcementCap = 1, boardScale = "small", board = { width = 8, height = 7, objectiveAnchors = 1, spawnPockets = 2, retreatRoutes = 1 }, varianceRules = { deploymentPattern = "triangle", laneCount = 1, coverFields = 3, hazardBudget = 2 } },
    [4] = { apBudget = 12, deploymentSlots = 4, enemyBudgetMultiplier = 1.00, objectivePressure = "standard", reinforcementCap = 2, boardScale = "standard", board = { width = 10, height = 8, objectiveAnchors = 2, spawnPockets = 2, retreatRoutes = 2 }, varianceRules = { deploymentPattern = "diamond", laneCount = 2, coverFields = 4, hazardBudget = 3 } },
    [5] = { apBudget = 15, deploymentSlots = 5, enemyBudgetMultiplier = 1.20, objectivePressure = "split", reinforcementCap = 2, boardScale = "wide", board = { width = 12, height = 9, objectiveAnchors = 2, spawnPockets = 3, retreatRoutes = 2 }, varianceRules = { deploymentPattern = "split", laneCount = 2, coverFields = 5, hazardBudget = 4 } },
    [6] = { apBudget = 18, deploymentSlots = 6, enemyBudgetMultiplier = 1.40, objectivePressure = "multi-front", reinforcementCap = 3, boardScale = "large", board = { width = 14, height = 10, objectiveAnchors = 3, spawnPockets = 3, retreatRoutes = 3 }, varianceRules = { deploymentPattern = "two_front", laneCount = 3, coverFields = 6, hazardBudget = 5 } },
}

local function loadoutById(class, loadoutId)
    for _, loadout in ipairs(class and class.loadouts or {}) do
        if loadout.id == loadoutId then
            return loadout
        end
    end
    return nil
end

local function starterRosterEntry(classId)
    for _, entry in ipairs(ClassCatalog.starterRoster) do
        if entry.classId == classId then
            return entry
        end
    end
    return nil
end

local function toolSet(class)
    local result = {}
    for _, tool in ipairs(class and class.tools or {}) do
        result[tool.id] = true
    end
    return result
end

function ClassCatalog.class(id)
    return ClassCatalog.classes[id]
end

function ClassCatalog.loadout(id, loadoutId)
    return loadoutById(ClassCatalog.class(id), loadoutId)
end

function ClassCatalog.loadouts(id)
    local class = ClassCatalog.class(id)
    return class and class.loadouts or {}
end

function ClassCatalog.starterClassIds()
    local result = {}
    for _, entry in ipairs(ClassCatalog.starterRoster) do
        result[#result + 1] = entry.classId
    end
    return result
end

function ClassCatalog.starterLoadouts(classId)
    local entry = starterRosterEntry(classId)
    local class = ClassCatalog.class(classId)
    local result = {}
    for _, loadoutId in ipairs(entry and entry.loadoutIds or {}) do
        local loadout = loadoutById(class, loadoutId)
        if loadout then
            result[#result + 1] = {
                classId = classId,
                className = class.name,
                id = loadout.id,
                boardVerb = loadout.boardVerb,
                tools = loadout.tools,
                unlock = loadout.unlock,
                routeRole = entry.routeRole,
                preview = loadout.unlock and loadout.unlock.preview or entry.preview,
                strongBoardFixture = entry.strongBoardFixture,
                awkwardBoardFixture = entry.awkwardBoardFixture,
                availableAt = "vertical_slice_start",
            }
        end
    end
    return result
end

function ClassCatalog.loadoutSlots(id)
    local class = ClassCatalog.class(id)
    return class and class.loadoutSlots or 0
end

function ClassCatalog.loadoutUnlocks(id)
    local unlocks = {}
    for _, loadout in ipairs(ClassCatalog.loadouts(id)) do
        unlocks[#unlocks + 1] = {
            classId = id,
            loadoutId = loadout.id,
            unlock = loadout.unlock,
        }
    end
    return unlocks
end

function ClassCatalog.boardVerbs(id)
    local class = ClassCatalog.class(id)
    return class and class.boardVerbs or {}
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

function ClassCatalog.requiredTraitDomainList()
    return ClassCatalog.requiredTraitDomains
end

function ClassCatalog.injuryDebtConstraints()
    return ClassCatalog.injuryDebts
end

function ClassCatalog.requiredInjuryDebtDomainList()
    return ClassCatalog.requiredInjuryDebtDomains
end

function ClassCatalog.squadScale(size)
    return ClassCatalog.squadScaling[size]
end

function ClassCatalog.squadScales()
    return ClassCatalog.squadScaling
end

function ClassCatalog.auditSquadScaling()
    local report = { valid = true, missing = {} }
    local previousCells = 0
    local previousEnemyBudget = 0
    local previousReinforcements = 0
    for size = 2, 6 do
        local scale = ClassCatalog.squadScaling[size]
        if not scale then
            report.valid = false
            table.insert(report.missing, "squad." .. tostring(size))
        else
            local board = scale.board or {}
            local variance = scale.varianceRules or {}
            local cells = (board.width or 0) * (board.height or 0)
            if scale.apBudget ~= size * 3 or scale.deploymentSlots ~= size then
                report.valid = false
                table.insert(report.missing, "squad." .. tostring(size) .. ".ap")
            end
            if cells <= previousCells or (scale.enemyBudgetMultiplier or 0) < previousEnemyBudget or (scale.reinforcementCap or 0) < previousReinforcements then
                report.valid = false
                table.insert(report.missing, "squad." .. tostring(size) .. ".monotonic")
            end
            if not scale.objectivePressure or not scale.boardScale or not variance.deploymentPattern then
                report.valid = false
                table.insert(report.missing, "squad." .. tostring(size) .. ".metadata")
            end
            if not board.objectiveAnchors or not board.spawnPockets or not board.retreatRoutes or not variance.laneCount or not variance.coverFields or not variance.hazardBudget then
                report.valid = false
                table.insert(report.missing, "squad." .. tostring(size) .. ".variance")
            end
            previousCells = cells
            previousEnemyBudget = scale.enemyBudgetMultiplier or 0
            previousReinforcements = scale.reinforcementCap or 0
        end
    end
    if ClassCatalog.squadScaling[1] or ClassCatalog.squadScaling[7] then
        report.valid = false
        table.insert(report.missing, "squad.bounds")
    end
    return report
end

function ClassCatalog.auditBoardVerbs()
    local report = { valid = true, missing = {} }
    for classId, class in pairs(ClassCatalog.classes) do
        if not class.boardVerbs or #class.boardVerbs == 0 then
            report.valid = false
            table.insert(report.missing, classId .. ".boardVerbs")
        end
        for _, loadout in ipairs(class.loadouts or {}) do
            if not loadout.boardVerb then
                report.valid = false
                table.insert(report.missing, classId .. "." .. tostring(loadout.id) .. ".boardVerb")
            end
            if loadout.role ~= nil then
                report.valid = false
                table.insert(report.missing, classId .. "." .. tostring(loadout.id) .. ".role")
            end
        end
    end
    return report
end

function ClassCatalog.auditLoadoutShape()
    local report = { valid = true, missing = {} }
    for classId, class in pairs(ClassCatalog.classes) do
        local slots = class.loadoutSlots or 0
        if slots ~= 2 then
            report.valid = false
            table.insert(report.missing, classId .. ".loadoutSlots")
        end
        local tools = class.tools or {}
        if #tools < 3 or #tools > 5 then
            report.valid = false
            table.insert(report.missing, classId .. ".tools")
        end
        if #(class.terrainInteractions or {}) < 1 then
            report.valid = false
            table.insert(report.missing, classId .. ".terrainInteractions")
        end
        local toolIds = {}
        for _, tool in ipairs(tools) do
            if tool.id then
                toolIds[tool.id] = true
            end
        end
        for _, loadout in ipairs(class.loadouts or {}) do
            if #(loadout.tools or {}) ~= slots then
                report.valid = false
                table.insert(report.missing, classId .. "." .. tostring(loadout.id) .. ".tools")
            end
            for _, toolId in ipairs(loadout.tools or {}) do
                if not toolIds[toolId] then
                    report.valid = false
                    table.insert(report.missing, classId .. "." .. tostring(loadout.id) .. "." .. tostring(toolId))
                end
            end
        end
    end
    return report
end

function ClassCatalog.auditLoadoutUnlocks()
    local report = { valid = true, missing = {} }
    for classId, class in pairs(ClassCatalog.classes) do
        local runUnlocks = 0
        for _, loadout in ipairs(class.loadouts or {}) do
            local unlock = loadout.unlock
            local prefix = classId .. "." .. tostring(loadout.id)
            if not unlock then
                report.valid = false
                table.insert(report.missing, prefix .. ".unlock")
            else
                if unlock.rewardKind ~= "class_option" or not unlock.rewardId then
                    report.valid = false
                    table.insert(report.missing, prefix .. ".reward")
                end
                if unlock.stat or unlock.statBonus or unlock.permanentStat then
                    report.valid = false
                    table.insert(report.missing, prefix .. ".statless")
                end
                if unlock.scope == "run" then
                    runUnlocks = runUnlocks + 1
                    if not unlock.source or not unlock.preview then
                        report.valid = false
                        table.insert(report.missing, prefix .. ".run")
                    end
                elseif unlock.scope ~= "default" then
                    report.valid = false
                    table.insert(report.missing, prefix .. ".scope")
                end
            end
        end
        if runUnlocks < 1 then
            report.valid = false
            table.insert(report.missing, classId .. ".runUnlock")
        end
    end
    return report
end

function ClassCatalog.auditStarterRoster()
    local report = { valid = true, missing = {} }
    if #ClassCatalog.starterRoster ~= 6 then
        report.valid = false
        table.insert(report.missing, "starter.count")
    end
    for _, entry in ipairs(ClassCatalog.starterRoster) do
        local class = ClassCatalog.class(entry.classId)
        local prefix = "starter." .. tostring(entry.classId)
        if not class then
            report.valid = false
            table.insert(report.missing, prefix .. ".class")
        end
        if not entry.routeRole or not entry.preview or not entry.strongBoardFixture or not entry.awkwardBoardFixture then
            report.valid = false
            table.insert(report.missing, prefix .. ".preview")
        end
        if #(entry.loadoutIds or {}) ~= 2 then
            report.valid = false
            table.insert(report.missing, prefix .. ".loadoutCount")
        end
        local tools = toolSet(class)
        for _, loadoutId in ipairs(entry.loadoutIds or {}) do
            local loadout = loadoutById(class, loadoutId)
            if not loadout then
                report.valid = false
                table.insert(report.missing, prefix .. "." .. tostring(loadoutId))
            else
                if not loadout.boardVerb or #(loadout.tools or {}) ~= 2 then
                    report.valid = false
                    table.insert(report.missing, prefix .. "." .. tostring(loadoutId) .. ".shape")
                end
                for _, toolId in ipairs(loadout.tools or {}) do
                    if not tools[toolId] then
                        report.valid = false
                        table.insert(report.missing, prefix .. "." .. tostring(loadoutId) .. "." .. tostring(toolId))
                    end
                end
            end
        end
    end
    return report
end

function ClassCatalog.auditTraitDomains()
    local report = { valid = true, missing = {} }
    local domains = {}
    local ids = {}
    for _, trait in ipairs(ClassCatalog.traits) do
        if not trait.id or not trait.domain or not trait.effect then
            report.valid = false
            table.insert(report.missing, tostring(trait.id or "trait") .. ".metadata")
        end
        if trait.id and ids[trait.id] then
            report.valid = false
            table.insert(report.missing, trait.id .. ".duplicate")
        end
        if trait.id then
            ids[trait.id] = true
        end
        if trait.domain then
            domains[trait.domain] = true
        end
    end
    for _, domain in ipairs(ClassCatalog.requiredTraitDomains) do
        if not domains[domain] then
            report.valid = false
            table.insert(report.missing, domain)
        end
    end
    return report
end

function ClassCatalog.auditInjuryDebtConstraints()
    local report = { valid = true, missing = {} }
    local domains = {}
    local ids = {}
    local types = {}
    for _, consequence in ipairs(ClassCatalog.injuryDebts) do
        if not consequence.id or not consequence.type or not consequence.domain or not consequence.constraint then
            report.valid = false
            table.insert(report.missing, tostring(consequence.id or "consequence") .. ".metadata")
        end
        if consequence.id and ids[consequence.id] then
            report.valid = false
            table.insert(report.missing, consequence.id .. ".duplicate")
        end
        if consequence.noRandomActionLoss ~= true or consequence.randomActionLoss or consequence.randomTurnLoss or consequence.skipTurnChance then
            report.valid = false
            table.insert(report.missing, tostring(consequence.id or "consequence") .. ".randomTurnLoss")
        end
        if consequence.id then
            ids[consequence.id] = true
        end
        if consequence.domain then
            domains[consequence.domain] = true
        end
        if consequence.type then
            types[consequence.type] = true
        end
    end
    if not types.injury or not types.debt then
        report.valid = false
        table.insert(report.missing, "injuryDebt.types")
    end
    for _, domain in ipairs(ClassCatalog.requiredInjuryDebtDomains) do
        if not domains[domain] then
            report.valid = false
            table.insert(report.missing, domain)
        end
    end
    return report
end

return ClassCatalog
