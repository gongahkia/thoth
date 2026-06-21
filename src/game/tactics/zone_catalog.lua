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
    salt_cistern = {
        tileMechanics = {
            { id = "cistern_valve_turn", subject = "valves", verb = "turn", effect = "raises or drains declared water bands" },
            { id = "cistern_sluice_current", subject = "sluice currents", verb = "push", effect = "moves units along previewed arrows after actions" },
            { id = "cistern_flood_lane", subject = "flood lanes", verb = "surge", effect = "delayed line hazard fills marked tiles" },
            { id = "cistern_brine_pool", subject = "brine pools", verb = "wade", effect = "slows movement and threatens blight damage" },
            { id = "cistern_salt_mist", subject = "salt mist", verb = "obscure", effect = "visible obscurant changes LoS and reveal ranges" },
            { id = "cistern_pressure_bell", subject = "pressure bells", verb = "ring", effect = "signals enemy intent escalation on flooded rows" },
            { id = "cistern_pearl_cyst", subject = "pearl cysts", verb = "burst", effect = "creates blocker shards and brine splash" },
            { id = "cistern_pump_bridge", subject = "pump bridges", verb = "pump", effect = "toggles crossing tiles by waterline state" },
            { id = "cistern_undertow_tile", subject = "undertow tiles", verb = "drag", effect = "pulls exposed units toward drains" },
            { id = "cistern_drain_grate", subject = "drain grates", verb = "open", effect = "removes nearby flood lane and creates pit risk" },
            { id = "cistern_floating_cover", subject = "floating cover", verb = "drift", effect = "moves half cover with currents" },
            { id = "cistern_waterline_height", subject = "waterline height", verb = "rise_fall", effect = "changes movement cost and LoS height bands" },
        },
        objects = {
            { id = "tide_valve", apCost = 2, hp = 4, losEffect = "no block", coverState = "none", rotation = "reverse side marks drain order", floodEffect = "drains one flood band", objectiveEffect = "repairs floodgate integrity" },
            { id = "sluice_gate", apCost = 2, hp = 5, losEffect = "opaque while shut", coverState = "full", rotation = "reverse side marks surge lane", floodEffect = "opens delayed flood lane", objectiveEffect = "damages route machinery if broken" },
            { id = "pressure_bell_frame", apCost = 1, hp = 3, losEffect = "no block", coverState = "none", rotation = "reverse side marks bell radius", floodEffect = "calls surge on wet rows", objectiveEffect = "pressures protect nodes" },
            { id = "pearl_cyst_cluster", apCost = 1, hp = 4, losEffect = "low opaque blocker", coverState = "half", rotation = "reverse side marks burst cone", floodEffect = "adds brine splash", objectiveEffect = "damages civilian cells if burst nearby" },
            { id = "pump_bridge_wheel", apCost = 2, hp = 4, losEffect = "no block", coverState = "none", rotation = "reverse side marks bridge lock", floodEffect = "raises bridge while lowering adjacent water", objectiveEffect = "opens extract route" },
            { id = "drain_grate_cap", apCost = 1, hp = 3, losEffect = "pit sight only", coverState = "none", rotation = "reverse side marks undertow pull", floodEffect = "drains adjacent flood tiles", objectiveEffect = "risks repair target integrity" },
            { id = "floating_barricade", apCost = 1, hp = 3, losEffect = "drifting half blocker", coverState = "half", rotation = "reverse side marks current route", floodEffect = "moves with current after drain tick", objectiveEffect = "shields machinery core" },
            { id = "waterline_gauge", apCost = 1, hp = 2, losEffect = "no block", coverState = "none", rotation = "reverse side marks safe height", floodEffect = "previews next rise or drain", objectiveEffect = "prevents objective integrity surprise" },
        },
    },
    ember_warrens = {
        tileMechanics = {
            { id = "warrens_kiln_heat", subject = "kilns", verb = "stoke", effect = "creates declared heat around kiln mouths" },
            { id = "warrens_ash_choke", subject = "ash choke", verb = "clog", effect = "slows movement and obscures low LoS" },
            { id = "warrens_bellows_cone", subject = "bellows cones", verb = "blast", effect = "pushes heat and units through previewed cone" },
            { id = "warrens_glass_floor", subject = "glass floors", verb = "crack", effect = "reveals fragile path and shard hazard" },
            { id = "warrens_vitrified_cover", subject = "vitrified cover", verb = "reflect", effect = "half cover reflects first line effect until shattered" },
            { id = "warrens_heat_lane", subject = "heat lanes", verb = "burn", effect = "delayed line damage on marked rows" },
            { id = "warrens_fuel_store", subject = "fuel stores", verb = "ignite", effect = "creates timed fire burst and smoke" },
            { id = "warrens_ember_oil", subject = "ember oil", verb = "spread", effect = "extends burn tiles until doused" },
            { id = "warrens_furnace_door", subject = "furnace doors", verb = "seal_vent", effect = "toggles blocker and heat vent state" },
            { id = "warrens_cinder_vent", subject = "cinder vents", verb = "vent", effect = "spawns ash choke after heat tick" },
            { id = "warrens_white_coal_pressure", subject = "white-coal pressure", verb = "pressurize", effect = "escalates heat intent unless released" },
            { id = "warrens_meltable_bridge", subject = "meltable bridges", verb = "melt", effect = "turns crossing into hazard after countdown" },
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
