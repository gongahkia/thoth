local FutureZones = {}

FutureZones.zoneOrder = { "salt_cistern", "ember_warrens" }

FutureZones.runMapZones = {
    salt_cistern = { boss = "pearl_choir", enclave = "drowned pump ward", hazard = "flood lane" },
    ember_warrens = { boss = "cinder_prioress", enclave = "ash shelter", hazard = "burn lane" },
}

FutureZones.procgen = {
    salt_cistern = {
        id = "cistern_generator_v1",
        zone = "salt_cistern",
        material = "salt",
        hazardKind = "flood",
        objectiveId = "floodgate",
        objectiveKind = "repair_floodgate",
        sightBreakKind = "sluice_gate",
        width = 9,
        height = 7,
        family = "cistern",
    },
    ember_warrens = {
        id = "warrens_generator_v1",
        zone = "ember_warrens",
        material = "ember",
        hazardKind = "burn",
        objectiveId = "kiln_chain",
        objectiveKind = "disable_kiln",
        sightBreakKind = "kiln_mouth",
        width = 8,
        height = 7,
        family = "warrens",
    },
}

FutureZones.enemies = {
    cistern = {
        common = { "drowned_acolyte", "brine_stalker", "valve_thrall", "brine_midwife", "sluice_eel", "salt_choir", "pearl_cyst", "halocline_tender", "drowned_pilgrim", "reed_mouth_diver" },
        elites = { "depth_bailiff", "pearl_choir", "undertow_notary" },
        alpha = "depth_bailiff",
    },
    warrens = {
        common = { "ash_husk", "kiln_imp", "kiln_nurse", "glass_penitent", "clinker_butcher", "white_furnace", "glass_choirmaster", "cinder_penitent", "ember_mote", "coal_monk" },
        elites = { "halo_deacon", "glass_cantor", "coal_prioress" },
        alpha = "white_furnace",
    },
}

FutureZones.bosses = {
    pearl_choir = { zone = "salt_cistern", phases = { "low_chorus", "high_chorus", "overflow_refrain" } },
    bell_diver = { zone = "salt_cistern", phases = { "toll_opening", "reed_fork", "undertow_bell" } },
    kiln_vicar = { zone = "ember_warrens", phases = { "vitrify_mark", "halo_overpressure", "ash_confession" } },
    cinder_prioress = { zone = "ember_warrens", phases = { "liturgy_phase", "veil_phase", "cinder_phase" } },
}

FutureZones.zoneCatalog = {
    salt_cistern = {
        mechanics = { "cistern_valve_turn", "cistern_sluice_current", "cistern_flood_lane", "cistern_brine_pool", "cistern_salt_mist", "cistern_pressure_bell", "cistern_pearl_cyst", "cistern_pump_bridge", "cistern_undertow_tile", "cistern_drain_grate", "cistern_floating_cover", "cistern_waterline_height" },
        objects = { "tide_valve", "sluice_gate", "pressure_bell_frame", "pearl_cyst_cluster", "pump_bridge_wheel", "drain_grate_cap", "floating_barricade", "waterline_gauge" },
        destructibles = { "valve", "machinery" },
    },
    ember_warrens = {
        mechanics = { "warrens_kiln_heat", "warrens_ash_choke", "warrens_bellows_cone", "warrens_glass_floor", "warrens_vitrified_cover", "warrens_heat_lane", "warrens_fuel_store", "warrens_ember_oil", "warrens_furnace_door", "warrens_cinder_vent", "warrens_white_coal_pressure", "warrens_meltable_bridge" },
        objects = { "kiln_mouth", "ash_heap", "bellows_spine", "glass_screen", "fuel_cart", "ember_oil_cask", "furnace_door_chain", "white_coal_cradle" },
        destructibles = { "kiln", "floor" },
    },
}

return FutureZones
