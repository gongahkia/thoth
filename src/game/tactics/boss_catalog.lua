local BossCatalog = {}

BossCatalog.order = { "codex_reeve", "vault_regent" }

local function copyValue(value)
    if type(value) ~= "table" then
        return value
    end
    local result = {}
    for key, nested in pairs(value) do
        result[key] = copyValue(nested)
    end
    return result
end

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
        phaseChart = {
            { turn = 1, phase = "claim_opening", stage = 1, clock = 2, mask = "claim_beam_front", revealRotation = 1, weakPoint = "east_writ_pillar", objective = "named_witness", counterplay = "brace witness collateral or expose east pillar lane" },
            { turn = 2, phase = "collateral_cross", stage = 2, clock = 2, mask = "collateral_cross_seal", revealRotation = 2, weakPoint = "south_writ_pillar", objective = "cargo", counterplay = "destroy south pillar or move cargo out of claim cross" },
            { turn = 3, phase = "remand_order", stage = 3, clock = 1, mask = "remand_wall_seal", revealRotation = 0, weakPoint = "north_writ_pillar", objective = "route_machine", counterplay = "rotate north and contest claim before legal cover closes" },
        },
        arenaDiagram = {
            width = 9,
            height = 7,
            entry = { x = 1, y = 4 },
            boss = { x = 8, y = 4 },
            objectives = {
                { id = "named_witness", x = 6, y = 3 },
                { id = "cargo", x = 6, y = 5 },
                { id = "route_machine", x = 8, y = 2 },
            },
            writPillars = {
                { id = "east_writ_pillar", x = 7, y = 4, hp = 3, revealRotation = 1 },
                { id = "south_writ_pillar", x = 5, y = 6, hp = 4, revealRotation = 2 },
                { id = "north_writ_pillar", x = 5, y = 2, hp = 4, revealRotation = 0 },
            },
            legalCoverTiles = {
                { id = "sealed_brief_wall", x = 7, y = 3, cover = "full" },
                { id = "custody_bench", x = 6, y = 4, cover = "half" },
            },
            claimBeamTiles = {
                { x = 6, y = 3 },
                { x = 7, y = 3 },
                { x = 6, y = 4 },
                { x = 6, y = 5 },
            },
        },
        stagedIntentMasks = {
            { phase = "claim_opening", turn = 1, stage = 1, stageCount = 3, mask = "claim_beam_front", category = "debuff", targetTiles = { { x = 6, y = 3 }, { x = 7, y = 3 } }, revealRotation = 1, weakPoint = "east_writ_pillar", revealedTiles = { { x = 7, y = 4 }, { x = 8, y = 4 } } },
            { phase = "collateral_cross", turn = 2, stage = 2, stageCount = 3, mask = "collateral_cross_seal", category = "destroy", targetTiles = { { x = 6, y = 3 }, { x = 6, y = 4 }, { x = 6, y = 5 } }, revealRotation = 2, weakPoint = "south_writ_pillar", revealedTiles = { { x = 5, y = 6 }, { x = 6, y = 5 } } },
            { phase = "remand_order", turn = 3, stage = 3, stageCount = 3, mask = "remand_wall_seal", category = "guard", targetTiles = { { x = 7, y = 3 }, { x = 7, y = 4 }, { x = 7, y = 5 } }, revealRotation = 0, weakPoint = "north_writ_pillar", revealedTiles = { { x = 5, y = 2 }, { x = 8, y = 2 } } },
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

function BossCatalog.auditVaultRegentShipData()
    local report = { ok = true, missing = {}, invalid = {} }
    local boss = BossCatalog.boss("vault_regent")
    if not boss then
        report.missing[#report.missing + 1] = "vault_regent"
        report.ok = false
        return report
    end
    if not (boss.phaseChart and #boss.phaseChart == 3) then
        report.missing[#report.missing + 1] = "phaseChart"
    end
    if not (boss.arenaDiagram and boss.arenaDiagram.width and boss.arenaDiagram.height and boss.arenaDiagram.boss and boss.arenaDiagram.entry and #(boss.arenaDiagram.writPillars or {}) == 3) then
        report.missing[#report.missing + 1] = "arenaDiagram"
    end
    if not (boss.stagedIntentMasks and #boss.stagedIntentMasks == 3) then
        report.missing[#report.missing + 1] = "stagedIntentMasks"
    end
    local phases = {}
    for _, phase in ipairs(boss.phaseProcedure or {}) do
        phases[phase.id] = phase
    end
    local chartByPhase = {}
    for _, entry in ipairs(boss.phaseChart or {}) do
        chartByPhase[entry.phase] = entry
        if not phases[entry.phase] then
            report.invalid[#report.invalid + 1] = tostring(entry.phase) .. ".phaseProcedure"
        end
        if not (entry.turn and entry.stage and entry.clock and entry.mask and entry.revealRotation ~= nil and entry.weakPoint and entry.objective and entry.counterplay) then
            report.invalid[#report.invalid + 1] = tostring(entry.phase) .. ".phaseChart"
        end
    end
    for _, mask in ipairs(boss.stagedIntentMasks or {}) do
        local chart = chartByPhase[mask.phase]
        if not chart then
            report.invalid[#report.invalid + 1] = tostring(mask.phase) .. ".maskPhase"
        elseif not (mask.turn == chart.turn and mask.stage == chart.stage and mask.mask == chart.mask and mask.revealRotation == chart.revealRotation and mask.weakPoint == chart.weakPoint) then
            report.invalid[#report.invalid + 1] = tostring(mask.phase) .. ".maskChartMismatch"
        end
        if not (mask.stageCount == 3 and mask.category and #(mask.targetTiles or {}) > 0 and #(mask.revealedTiles or {}) > 0) then
            report.invalid[#report.invalid + 1] = tostring(mask.phase) .. ".maskFootprint"
        end
    end
    report.ok = #report.missing == 0 and #report.invalid == 0
    return report
end

function BossCatalog.bossStageIntent(bossId)
    local boss = BossCatalog.boss(bossId)
    if not boss or not boss.stagedIntentMasks or not boss.stagedIntentMasks[1] then
        return nil
    end
    local masks = {}
    for _, stage in ipairs(boss.stagedIntentMasks) do
        masks[#masks + 1] = {
            phase = stage.phase,
            turn = stage.turn,
            mask = stage.mask,
            stage = stage.stage,
            stageCount = stage.stageCount,
            targetTiles = copyValue(stage.targetTiles),
        }
        masks[#masks + 1] = {
            revealRotation = stage.revealRotation,
            weakPoint = stage.weakPoint,
            revealed = true,
            stage = stage.stage,
            stageCount = stage.stageCount,
            targetTiles = copyValue(stage.revealedTiles),
        }
    end
    local first = boss.stagedIntentMasks[1]
    return {
        mode = "bossStage",
        category = first.category or "debuff",
        stage = first.stage,
        stageCount = first.stageCount,
        mask = first.mask,
        targetTiles = copyValue(first.targetTiles),
        masks = masks,
    }
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
        if spec.bossId == "vault_regent" and not BossCatalog.auditVaultRegentShipData().ok then
            report.invalid[#report.invalid + 1] = "sliceBoss.shipData"
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
