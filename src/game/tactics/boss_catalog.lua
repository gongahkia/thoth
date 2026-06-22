local BossCatalog = {}

BossCatalog.order = { "codex_reeve", "vault_regent" }

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
}

BossCatalog.sliceBossSpecData = {
    bossId = "vault_regent",
    zone = "buried_archive",
    routeNode = "boss_gate",
    boardFixture = "archive_boss_gate",
    preview = "Vault Regent claim beams, collateral, legal cover, and writ pillars",
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

function BossCatalog.sliceBossSpec()
    return BossCatalog.sliceBossSpecData
end

function BossCatalog.sliceBoss()
    return BossCatalog.boss(BossCatalog.sliceBossSpecData.bossId)
end

function BossCatalog.auditSliceBoss()
    local report = { ok = true, missing = {}, invalid = {} }
    local spec = BossCatalog.sliceBossSpecData
    local boss = BossCatalog.sliceBoss()
    if not boss then
        report.missing[#report.missing + 1] = "sliceBoss.boss"
    else
        if not (spec.bossId and spec.zone == boss.zone and spec.routeNode and spec.boardFixture and spec.preview) then
            report.invalid[#report.invalid + 1] = "sliceBoss.spec"
        end
        if not (boss.zone == "buried_archive" and boss.tacticalContract and boss.tacticalContract.exactIntent and boss.tacticalContract.partialIntent) then
            report.invalid[#report.invalid + 1] = "sliceBoss.contract"
        end
        if not (boss.phaseProcedure and #boss.phaseProcedure == 3) then
            report.invalid[#report.invalid + 1] = "sliceBoss.phaseProcedure"
        end
    end
    report.ok = #report.missing == 0 and #report.invalid == 0
    return report
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
