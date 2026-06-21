local BossCatalog = {}

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
    },
}

function BossCatalog.boss(id)
    return BossCatalog.bosses[id]
end

function BossCatalog.allBosses()
    local bosses = {}
    for _, id in ipairs({ "codex_reeve", "vault_regent", "pearl_choir", "bell_diver", "kiln_vicar", "cinder_prioress" }) do
        bosses[#bosses + 1] = BossCatalog.boss(id)
    end
    return bosses
end

return BossCatalog
