local BossCatalog = {}

BossCatalog.order = { "codex_reeve", "vault_regent", "pearl_choir", "bell_diver", "kiln_vicar", "cinder_prioress" }

BossCatalog.bosses = {
    codex_reeve = {
        name = "Codex Reeve",
        zone = "buried_archive",
        board = {
            auditLines = {
                { id = "north_south_register", pattern = "straight", effect = "tiles in line disable 1 AP until the Open Register is broken" },
                { id = "witness_diagonal", pattern = "diagonal", effect = "marked witness tiles disable interact actions until line is blocked" },
            },
            apDisableTiles = {
                { id = "audit_tile_a", x = 3, y = 2, apPenalty = 1 },
                { id = "audit_tile_b", x = 5, y = 4, apPenalty = 1 },
                { id = "audit_tile_c", x = 7, y = 2, apPenalty = 2 },
            },
            weakPoints = {
                { id = "open_register", reveal = "front desk", counter = "break to clear active AP disable tiles" },
            },
            rotationBackSeals = {
                { id = "north_back_seal", rotation = 0, reveals = "next audit line origin" },
                { id = "east_back_seal", rotation = 1, reveals = "Open Register flank lane" },
                { id = "south_back_seal", rotation = 2, reveals = "safe claim desk" },
                { id = "west_back_seal", rotation = 3, reveals = "inactive witness diagonal" },
            },
        },
        variants = {
            { id = "redacted_register", arenaModifier = "paper swarm obscures one audit line", addFamily = "archive clerks", weakPointLocation = "rear open register", objectivePressure = "witness objective loses integrity on failed audit" },
            { id = "sealed_index", arenaModifier = "sealed doors split the board", addFamily = "ledger hounds", weakPointLocation = "east back seal", objectivePressure = "route machine AP tax rises every two turns" },
        },
        tacticalContract = {
            exactIntent = { mode = "exact", id = "audit_sentence", target = "audit line tiles" },
            partialIntent = { mode = "category", category = "seal", hint = "one back seal hides footprint until rotated" },
            terrainMutation = { id = "paper_swarm_rise", effect = "spawns obscuring paper swarm on spent audit tile" },
            objectiveThreat = { id = "register_confiscation", effect = "Open Register damages witness objective if unanswered" },
            nonDamageCounter = { id = "file_objection", damage = 0, effect = "spend interact on witness drawer to cancel AP disable" },
        },
    },
    vault_regent = {
        name = "Vault Regent",
        zone = "buried_archive",
        board = {
            claimBeams = {
                { id = "primary_claim_beam", pattern = "orthogonal", effect = "claims two cover lanes and threatens route machinery" },
                { id = "cross_claim_beam", pattern = "cross", effect = "turns unbraced units into named collateral" },
            },
            nameCollateral = {
                { id = "witness_name_tile", target = "civilian", consequence = "objective integrity loss if claim beam resolves" },
                { id = "debt_name_tile", target = "cargo", consequence = "cargo becomes legal cover for the Regent" },
            },
            legalCover = {
                { id = "sealed_brief_wall", cover = "full", rule = "blocks direct attacks until adjacent writ pillar is destroyed" },
                { id = "custody_bench", cover = "half", rule = "protects named collateral but counts as flanked from rear seal" },
            },
            writPillars = {
                { id = "north_writ_pillar", hp = 4, destruction = "removes sealed brief wall cover" },
                { id = "south_writ_pillar", hp = 4, destruction = "breaks cross claim beam for one turn" },
                { id = "east_writ_pillar", hp = 3, destruction = "reveals Regent weak point lane" },
            },
        },
        variants = {
            { id = "crowned_claim", arenaModifier = "claim beams start one tile wider", addFamily = "writ bailiffs", weakPointLocation = "east writ pillar lane", objectivePressure = "named collateral starts under legal cover" },
            { id = "remand_chamber", arenaModifier = "custody benches rotate cover edges", addFamily = "contract guards", weakPointLocation = "south writ pillar", objectivePressure = "cargo collateral becomes claimable after turn three" },
        },
        tacticalContract = {
            exactIntent = { mode = "exact", id = "claim_beam", target = "visible beam footprint" },
            partialIntent = { mode = "category", category = "debuff", hint = "named collateral type shown before target tile" },
            terrainMutation = { id = "writ_wall_raise", effect = "legal cover becomes full cover until writ pillar breaks" },
            objectiveThreat = { id = "collateral_notice", effect = "named witness or cargo loses integrity if beam resolves" },
            nonDamageCounter = { id = "contest_claim", damage = 0, effect = "brace collateral tile to void the claim beam" },
        },
    },
    pearl_choir = {
        name = "Pearl Choir",
        zone = "salt_cistern",
        board = {
            refloodingLanes = {
                { id = "west_reflood_lane", pattern = "row", countdown = 1, effect = "drained lane becomes flood hazard after chorus" },
                { id = "east_reflood_lane", pattern = "column", countdown = 2, effect = "low cover floats one tile when reflooded" },
            },
            choirThroats = {
                { id = "low_throat", waterline = "low", counter = "silence to stop next reflood" },
                { id = "high_throat", waterline = "high", counter = "silence to expose Pearl Choir core" },
            },
            movingWaterline = {
                states = { "drained", "ankle", "waist", "overflow" },
                rule = "waterline advances one state after unresolved chorus",
                lowGroundPunishment = "overflow turns low ground hostile",
            },
            pressureBellAdds = {
                { id = "bell_acolyte_pair", spawn = "two pressure acolytes", trigger = "unsilenced throat" },
                { id = "bell_cyst_cluster", spawn = "one pearl cyst cluster", trigger = "overflow waterline" },
            },
        },
        variants = {
            { id = "black_pearl_chorus", arenaModifier = "reflood lanes begin staggered", addFamily = "pearl cysts", weakPointLocation = "high choir throat", objectivePressure = "drain machinery floods if chorus resolves twice" },
            { id = "brine_canticle", arenaModifier = "moving waterline skips ankle state", addFamily = "salt choir", weakPointLocation = "low choir throat", objectivePressure = "civilian cells become low ground on overflow" },
        },
        tacticalContract = {
            exactIntent = { mode = "exact", id = "reflood_lane", target = "marked drained lane" },
            partialIntent = { mode = "category", category = "summon", hint = "pressure bell add family shown before spawn tile" },
            terrainMutation = { id = "waterline_rise", effect = "waterline advances and converts drained lanes to flood" },
            objectiveThreat = { id = "drowned_cell", effect = "civilian or drain machinery integrity falls on overflow" },
            nonDamageCounter = { id = "silence_throat", damage = 0, effect = "interact with choir throat to pause reflood" },
        },
    },
    bell_diver = {
        name = "Bell Diver",
        zone = "salt_cistern",
        board = {
            hookLanes = {
                { id = "chain_hook_lane", pattern = "line", pull = 3, effect = "pulls first unit toward bell mouth" },
                { id = "reed_hook_lane", pattern = "fork", pull = 2, effect = "pulls cargo or objective carrier into low ground" },
            },
            weakPoints = {
                { id = "bell_lung", reveal = "after hook lane is blocked", counter = "break to pause flood toll countdown" },
            },
            floodTollCountdown = {
                start = 3,
                tick = "after enemy intent resolution",
                failure = "all low-ground tiles become hostile flood lanes",
            },
            lowGroundPunishment = {
                { id = "drowned_step", trigger = "standing below waterline", effect = "movement costs +1 AP and next hook pull gains +1" },
                { id = "undertow_claim", trigger = "flood toll reaches zero", effect = "objective carriers on low ground lose integrity" },
            },
        },
        variants = {
            { id = "flood_toll", arenaModifier = "flood-toll countdown starts at two", addFamily = "reed-mouth divers", weakPointLocation = "bell lung behind chain lane", objectivePressure = "route machinery starts on low ground" },
            { id = "undertow_hook", arenaModifier = "hook lanes fork through drain grates", addFamily = "brine stalkers", weakPointLocation = "bell lung behind reed lane", objectivePressure = "cargo is pulled before units when exposed" },
        },
        tacticalContract = {
            exactIntent = { mode = "exact", id = "chain_hook", target = "first unit in hook lane" },
            partialIntent = { mode = "category", category = "move", hint = "hook family shown before exact pull path" },
            terrainMutation = { id = "flood_toll_break", effect = "low ground becomes hostile when countdown expires" },
            objectiveThreat = { id = "undertow_cargo", effect = "objective carrier loses integrity when pulled into low ground" },
            nonDamageCounter = { id = "block_hook_lane", damage = 0, effect = "place cover or body in lane to exhaust hook" },
        },
    },
    kiln_vicar = {
        name = "Kiln Vicar",
        zone = "ember_warrens",
        board = {
            vitrifyTarget = {
                selector = "most exposed unit or objective",
                effect = "turns target tile into glass hazard unless LoS is broken or vent is doused",
                preview = "marks target and reflection path before commit",
            },
            haloVents = {
                { id = "north_halo_vent", hp = 3, douse = "removes north heat lane" },
                { id = "south_halo_vent", hp = 3, douse = "removes south heat lane" },
                { id = "east_halo_vent", hp = 2, douse = "breaks vitrify reflection path" },
            },
            douseRoutes = {
                { id = "ash_bucket_route", apCost = 1, effect = "safe path to douse one adjacent vent" },
                { id = "cistern_cut_route", apCost = 2, effect = "open drain spill that douses two heat tiles" },
            },
            ashChokeCover = {
                { id = "low_ash_choke", cover = "half", tradeoff = "blocks LoS but costs +1 movement" },
                { id = "dense_ash_choke", cover = "full", tradeoff = "blocks vitrify but hides objective preview" },
            },
        },
        variants = {
            { id = "white_halo", arenaModifier = "halo vents begin overpressured", addFamily = "halo deacons", weakPointLocation = "east halo vent", objectivePressure = "most exposed objective is preferred vitrify target" },
            { id = "ash_confessional", arenaModifier = "ash choke starts dense around center", addFamily = "ash husks", weakPointLocation = "rear ash-covered vent", objectivePressure = "douse route crosses one objective tile" },
        },
        tacticalContract = {
            exactIntent = { mode = "exact", id = "vitrify_line", target = "most exposed unit or objective" },
            partialIntent = { mode = "category", category = "destroy", hint = "target type shown before exact tile if obscured" },
            terrainMutation = { id = "glass_hazard", effect = "vitrified tile becomes glass hazard and reflector" },
            objectiveThreat = { id = "objective_vitrify", effect = "exposed objective is legal vitrify target" },
            nonDamageCounter = { id = "douse_halo_vent", damage = 0, effect = "douse vent to cancel vitrify line" },
        },
    },
    cinder_prioress = {
        name = "Cinder Prioress",
        zone = "ember_warrens",
        board = {
            furnacePhases = {
                { id = "liturgy", threshold = "opening", mutation = "lights two furnace mouths" },
                { id = "veil", threshold = "first weak point broken", mutation = "adds ash-choke cover and smoke lines" },
                { id = "cinder", threshold = "low HP", mutation = "fuel stores count down toward burn lanes" },
            },
            glassCrownReflectors = {
                { id = "north_crown_reflector", angle = "north", effect = "reflects first line intent into side lane" },
                { id = "south_crown_reflector", angle = "south", effect = "reflects douse route into safe floor" },
                { id = "rear_crown_reflector", angle = "rear", effect = "reveals Prioress weak point by rotation" },
            },
            fuelObjectiveTradeoffs = {
                { id = "sacrifice_fuel_cart", choice = "destroy fuel", benefit = "prevents furnace phase escalation", cost = "objective cargo integrity -1" },
                { id = "protect_fuel_store", choice = "guard fuel", benefit = "keeps repair reward intact", cost = "adds heat lane next turn" },
            },
        },
        variants = {
            { id = "glass_crown", arenaModifier = "rear crown reflector starts active", addFamily = "glass cantors", weakPointLocation = "rear crown reflector", objectivePressure = "fuel stores protect final reward but widen heat lanes" },
            { id = "cinder_liturgy", arenaModifier = "furnace phase advances after every fuel hit", addFamily = "cinder penitents", weakPointLocation = "north crown reflector", objectivePressure = "destroying fuel pauses phase but damages cargo" },
        },
        tacticalContract = {
            exactIntent = { mode = "exact", id = "furnace_liturgy", target = "active furnace lane" },
            partialIntent = { mode = "category", category = "buff", hint = "next furnace phase shown without final lane" },
            terrainMutation = { id = "crown_reflection", effect = "glass crown reflector bends line intent into side lane" },
            objectiveThreat = { id = "fuel_bargain", effect = "fuel choice changes reward integrity or heat pressure" },
            nonDamageCounter = { id = "douse_fuel_line", damage = 0, effect = "douse fuel line to pause phase escalation" },
        },
    },
}

BossCatalog.phaseBlueprints = {
    codex_reeve = {
        { id = "audit_opening", tilePattern = "north_south_register line", rotatingWeakPoint = { id = "open_register", rotation = 0, reveal = "front desk" }, terrainConversion = { from = "spent audit tile", to = "paper swarm", effect = "obscures LoS after audit resolves" }, objectivePressure = { objective = "witness", effect = "integrity loss on failed audit" }, clock = { turns = 2, visible = true }, counterplay = "break register or block audit line", preview = "audit line, AP loss, register weak point" },
        { id = "seal_rotation", tilePattern = "witness diagonal", rotatingWeakPoint = { id = "east_back_seal", rotation = 1, reveal = "flank lane" }, terrainConversion = { from = "sealed desk", to = "claim blocker", effect = "desk becomes blocker until seal breaks" }, objectivePressure = { objective = "route_machine", effect = "AP tax if seal remains" }, clock = { turns = 2, visible = true }, counterplay = "rotate and break back seal", preview = "diagonal, seal, route tax" },
        { id = "register_sentence", tilePattern = "cross audit lines", rotatingWeakPoint = { id = "west_back_seal", rotation = 3, reveal = "inactive line" }, terrainConversion = { from = "paper swarm", to = "redacted cover", effect = "cover hides next footprint" }, objectivePressure = { objective = "open_register", effect = "claim objective loses integrity" }, clock = { turns = 1, visible = true }, counterplay = "file objection at witness drawer", preview = "cross lines, redacted cover, objection prompt" },
    },
    vault_regent = {
        { id = "claim_opening", tilePattern = "orthogonal claim beam", rotatingWeakPoint = { id = "east_writ_pillar", rotation = 1, reveal = "weak point lane" }, terrainConversion = { from = "brief wall", to = "legal cover", effect = "full cover blocks direct attacks" }, objectivePressure = { objective = "named_witness", effect = "collateral integrity loss" }, clock = { turns = 2, visible = true }, counterplay = "brace collateral tile", preview = "claim beam, collateral, writ pillar" },
        { id = "collateral_cross", tilePattern = "cross claim beam", rotatingWeakPoint = { id = "south_writ_pillar", rotation = 2, reveal = "beam breaker" }, terrainConversion = { from = "custody bench", to = "rotated cover", effect = "cover edge changes by rotation" }, objectivePressure = { objective = "cargo", effect = "cargo becomes legal cover" }, clock = { turns = 2, visible = true }, counterplay = "destroy south pillar", preview = "cross beam, cargo claim, cover edge" },
        { id = "remand_order", tilePattern = "split claim lanes", rotatingWeakPoint = { id = "north_writ_pillar", rotation = 0, reveal = "wall removal" }, terrainConversion = { from = "sealed brief wall", to = "open lane", effect = "pillar break opens attack lane" }, objectivePressure = { objective = "route_machine", effect = "legal claim escalates every turn" }, clock = { turns = 1, visible = true }, counterplay = "contest claim before clock resolves", preview = "split lanes, pillar hp, claim clock" },
    },
    pearl_choir = {
        { id = "low_chorus", tilePattern = "west reflood row", rotatingWeakPoint = { id = "low_throat", rotation = 0, reveal = "low waterline throat" }, terrainConversion = { from = "drained lane", to = "ankle flood", effect = "lane becomes flood hazard" }, objectivePressure = { objective = "drain_machinery", effect = "integrity loss if reflood resolves" }, clock = { turns = 2, visible = true }, counterplay = "silence low throat", preview = "row reflood, throat, waterline" },
        { id = "high_chorus", tilePattern = "east reflood column", rotatingWeakPoint = { id = "high_throat", rotation = 1, reveal = "core exposure" }, terrainConversion = { from = "ankle flood", to = "waist flood", effect = "low cover floats one tile" }, objectivePressure = { objective = "civilian_cells", effect = "cells become low ground" }, clock = { turns = 2, visible = true }, counterplay = "lower waterline before chorus", preview = "column reflood, high throat, cell risk" },
        { id = "overflow_refrain", tilePattern = "overflow cross", rotatingWeakPoint = { id = "choir_core", rotation = 2, reveal = "silenced core" }, terrainConversion = { from = "waist flood", to = "overflow", effect = "low ground turns hostile" }, objectivePressure = { objective = "route_exit", effect = "exit route floods" }, clock = { turns = 1, visible = true }, counterplay = "block pressure bell spawns", preview = "overflow cross, add spawn, exit risk" },
    },
    bell_diver = {
        { id = "toll_opening", tilePattern = "chain hook line", rotatingWeakPoint = { id = "bell_lung", rotation = 0, reveal = "behind chain lane" }, terrainConversion = { from = "low ground", to = "undertow", effect = "pull distance increases" }, objectivePressure = { objective = "route_machinery", effect = "carrier pulled toward low ground" }, clock = { turns = 3, visible = true }, counterplay = "block hook lane", preview = "hook line, toll clock, bell lung" },
        { id = "reed_fork", tilePattern = "forked reed hook", rotatingWeakPoint = { id = "reed_lung", rotation = 1, reveal = "drain grate side" }, terrainConversion = { from = "drain grate", to = "open undertow", effect = "fork path redirects cargo" }, objectivePressure = { objective = "cargo", effect = "cargo is pulled before units" }, clock = { turns = 2, visible = true }, counterplay = "open drain grate", preview = "fork hook, cargo priority, drain" },
        { id = "undertow_bell", tilePattern = "low-ground ring", rotatingWeakPoint = { id = "deep_bell", rotation = 2, reveal = "rear toll crack" }, terrainConversion = { from = "undertow", to = "hostile flood", effect = "all low ground becomes hostile" }, objectivePressure = { objective = "objective_carrier", effect = "carrier loses integrity on low ground" }, clock = { turns = 1, visible = true }, counterplay = "break bell lung before toll zero", preview = "ring, hostile flood, carrier risk" },
    },
    kiln_vicar = {
        { id = "vitrify_mark", tilePattern = "vitrify reflection line", rotatingWeakPoint = { id = "east_halo_vent", rotation = 1, reveal = "reflection break" }, terrainConversion = { from = "floor", to = "glass hazard", effect = "target tile becomes reflector hazard" }, objectivePressure = { objective = "exposed_objective", effect = "objective can be selected as target" }, clock = { turns = 2, visible = true }, counterplay = "douse halo vent", preview = "vitrify line, vent, glass result" },
        { id = "halo_overpressure", tilePattern = "north south heat lanes", rotatingWeakPoint = { id = "north_halo_vent", rotation = 0, reveal = "north heat source" }, terrainConversion = { from = "heat tile", to = "burning glass", effect = "heat lane blocks safe route" }, objectivePressure = { objective = "douse_route", effect = "route crosses objective tile" }, clock = { turns = 2, visible = true }, counterplay = "route water through heat lane", preview = "heat lanes, vent hp, route cost" },
        { id = "ash_confession", tilePattern = "ash choke fan", rotatingWeakPoint = { id = "south_halo_vent", rotation = 2, reveal = "south douse lane" }, terrainConversion = { from = "ash choke", to = "dense ash cover", effect = "blocks LoS but hides objective preview" }, objectivePressure = { objective = "most_exposed", effect = "objective preferred if unshielded" }, clock = { turns = 1, visible = true }, counterplay = "break LoS with ash choke", preview = "ash fan, target selector, dense cover" },
    },
    cinder_prioress = {
        { id = "liturgy_phase", tilePattern = "active furnace lane", rotatingWeakPoint = { id = "north_crown_reflector", rotation = 0, reveal = "first reflection angle" }, terrainConversion = { from = "furnace mouth", to = "heat lane", effect = "lights two furnace mouths" }, objectivePressure = { objective = "fuel_store", effect = "fuel heats next lane" }, clock = { turns = 2, visible = true }, counterplay = "douse fuel line", preview = "furnace lane, reflector, fuel pressure" },
        { id = "veil_phase", tilePattern = "reflected side lane", rotatingWeakPoint = { id = "south_crown_reflector", rotation = 2, reveal = "safe douse route" }, terrainConversion = { from = "floor", to = "ash choke", effect = "adds smoke lines and cover" }, objectivePressure = { objective = "repair_reward", effect = "guard fuel to keep reward intact" }, clock = { turns = 2, visible = true }, counterplay = "use reflector to bend douse route", preview = "side lane, ash choke, reward risk" },
        { id = "cinder_phase", tilePattern = "fuel-store burn cross", rotatingWeakPoint = { id = "rear_crown_reflector", rotation = 3, reveal = "Prioress weak point" }, terrainConversion = { from = "fuel cart", to = "burn lane", effect = "fuel stores count down into heat lanes" }, objectivePressure = { objective = "objective_cargo", effect = "destroying fuel costs cargo integrity" }, clock = { turns = 1, visible = true }, counterplay = "sacrifice or protect fuel before clock", preview = "burn cross, rear reflector, fuel bargain" },
    },
}

for bossId, phases in pairs(BossCatalog.phaseBlueprints) do
    if BossCatalog.bosses[bossId] then
        BossCatalog.bosses[bossId].phaseProcedure = phases
    end
end

function BossCatalog.auditPhaseProcedures()
    local report = { ok = true, missing = {}, invalid = {}, coverage = {} }
    for bossId, boss in pairs(BossCatalog.bosses) do
        local phases = boss.phaseProcedure or {}
        report.coverage[bossId] = #phases
        if #phases < 3 then
            table.insert(report.missing, bossId .. ".phaseProcedure")
        end
        local rotations = {}
        for _, phase in ipairs(phases) do
            if not (phase.id and phase.tilePattern and phase.counterplay and phase.preview) then
                table.insert(report.invalid, bossId .. "." .. tostring(phase.id) .. ".metadata")
            end
            local weak = phase.rotatingWeakPoint
            if not (weak and weak.id and weak.rotation ~= nil and weak.reveal) then
                table.insert(report.invalid, bossId .. "." .. tostring(phase.id) .. ".rotatingWeakPoint")
            else
                rotations[weak.rotation] = true
            end
            local terrain = phase.terrainConversion
            if not (terrain and terrain.from and terrain.to and terrain.effect) then
                table.insert(report.invalid, bossId .. "." .. tostring(phase.id) .. ".terrainConversion")
            end
            local objective = phase.objectivePressure
            if not (objective and objective.objective and objective.effect) then
                table.insert(report.invalid, bossId .. "." .. tostring(phase.id) .. ".objectivePressure")
            end
            if not (phase.clock and phase.clock.visible == true and phase.clock.turns and phase.clock.turns >= 1) then
                table.insert(report.invalid, bossId .. "." .. tostring(phase.id) .. ".clock")
            end
        end
        local rotationCount = 0
        for _ in pairs(rotations) do
            rotationCount = rotationCount + 1
        end
        if rotationCount < 2 then
            table.insert(report.invalid, bossId .. ".rotatingWeakPointCoverage")
        end
    end
    report.ok = #report.missing == 0 and #report.invalid == 0
    return report
end

function BossCatalog.boss(id)
    return BossCatalog.bosses[id]
end

function BossCatalog.allBosses()
    local bosses = {}
    for _, id in ipairs(BossCatalog.order) do
        bosses[#bosses + 1] = BossCatalog.boss(id)
    end
    return bosses
end

function BossCatalog.allBossIds()
    return BossCatalog.order
end

return BossCatalog
