local ZoneCatalog = {}

ZoneCatalog.zones = {
    buried_archive = {
        tileMechanics = {
            { id = "archive_shelf_shift", subject = "shelves", verb = "shove", effect = "moves full cover and can crush lanes" },
            { id = "archive_claim_desk", subject = "desks", verb = "claim", effect = "half cover claim tile for hold objectives" },
            { id = "archive_claim_line", subject = "claim lines", verb = "hold", effect = "scores presence while intents escalate" },
            { id = "archive_sealed_door", subject = "sealed doors", verb = "seal_open", effect = "blocks movement and LoS until opened" },
            { id = "archive_witness_drawer", subject = "witness drawers", verb = "reveal", effect = "exposes redacted intent or hidden tile marks" },
            { id = "archive_falling_records", subject = "falling records", verb = "collapse", effect = "delayed fuse creates blocker and damage" },
            { id = "archive_name_lock", subject = "name locks", verb = "disable", effect = "spend AP/tool to open route or objective" },
            { id = "archive_audit_beam", subject = "audit beams", verb = "line", effect = "visible LoS lane pressures movement" },
            { id = "archive_misfile_pit", subject = "misfile pits", verb = "drop", effect = "forced movement hazard changes elevation" },
            { id = "archive_ledger_bridge", subject = "ledger bridges", verb = "toggle", effect = "opens split-squad crossing dependency" },
            { id = "archive_paper_swarm", subject = "paper swarms", verb = "obscure", effect = "visible obscurant with countdown" },
            { id = "archive_back_face_seal", subject = "back-face seals", verb = "rotate_reveal", effect = "rotation mark reveals planning fact only" },
        },
        objects = {
            { id = "rolling_shelf", apCost = 2, hp = 5, losEffect = "blocks until shoved or broken", coverState = "full", rotation = "reverse side marks crush lane" },
            { id = "oath_desk", apCost = 1, hp = 3, losEffect = "low blocker after tipped", coverState = "half", rotation = "reverse side marks claim desk" },
            { id = "sealed_stacks_door", apCost = 2, hp = 4, losEffect = "opaque while sealed, open lane after breach", coverState = "none", rotation = "reverse side marks alternate hinge" },
            { id = "witness_drawer_bank", apCost = 1, hp = 2, losEffect = "no block, reveal action source", coverState = "none", rotation = "reverse side marks hidden witness" },
            { id = "record_crate", apCost = 1, hp = 2, losEffect = "becomes half blocker when spilled", coverState = "half", rotation = "reverse side marks falling record arc" },
            { id = "name_lock_plinth", apCost = 2, hp = 3, losEffect = "blocks route node only", coverState = "none", rotation = "reverse side marks true name socket" },
            { id = "audit_lens_stand", apCost = 1, hp = 2, losEffect = "projects visible straight lane", coverState = "none", rotation = "reverse side marks beam bearing" },
            { id = "ledger_bridge_winch", apCost = 2, hp = 4, losEffect = "no block, toggles crossing", coverState = "none", rotation = "reverse side marks bridge latch" },
        },
    },
}

function ZoneCatalog.zone(id)
    return ZoneCatalog.zones[id]
end

function ZoneCatalog.tileMechanics(zoneId)
    local zone = ZoneCatalog.zone(zoneId)
    return zone and zone.tileMechanics or {}
end

function ZoneCatalog.objects(zoneId)
    local zone = ZoneCatalog.zone(zoneId)
    return zone and zone.objects or {}
end

return ZoneCatalog
