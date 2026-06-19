local Registry = {}

Registry.tiles = {
    archive_floor = { name = "Archive Floor", walkable = true, color = { 82, 78, 86 } },
    archive_wall = { name = "Archive Wall", walkable = false, color = { 36, 34, 42 } },
    corridor = { name = "Corridor", walkable = true, color = { 64, 62, 70 } },
    salt_floor = { name = "Salt Floor", walkable = true, color = { 72, 90, 92 } },
    salt_wall = { name = "Salt Wall", walkable = false, color = { 34, 48, 54 } },
    salt_causeway = { name = "Salt Causeway", walkable = true, color = { 58, 76, 80 } },
    brine_pool = { name = "Brine Pool", walkable = false, color = { 20, 62, 72 } },
    ember_floor = { name = "Ember Floor", walkable = true, color = { 92, 72, 58 } },
    ember_wall = { name = "Ember Wall", walkable = false, color = { 46, 34, 30 } },
    ember_corridor = { name = "Ember Corridor", walkable = true, color = { 78, 56, 46 } },
    ash_choke = { name = "Ash Choke", walkable = false, color = { 42, 40, 38 } },
    sealed_door = { name = "Sealed Door", walkable = false, color = { 84, 62, 44 } },
    camp_marker = { name = "Cold Camp", walkable = true, curio = "cold_camp", color = { 96, 86, 64 } },
    relic_cache = { name = "Relic Cache", walkable = true, curio = "relic_cache", color = { 146, 116, 58 } },
    whispering_idol = { name = "Whispering Idol", walkable = true, curio = "whispering_idol", color = { 98, 72, 128 } },
    wire_snare = { name = "Wire Snare", walkable = true, curio = "wire_snare", color = { 110, 48, 48 } },
    salt_font = { name = "Salt Font", walkable = true, curio = "salt_font", color = { 96, 132, 136 } },
    brine_lockbox = { name = "Brine Lockbox", walkable = true, curio = "brine_lockbox", color = { 84, 124, 118 } },
    ash_vent = { name = "Ash Vent", walkable = true, curio = "ash_vent", color = { 138, 72, 48 } },
    ember_reliquary = { name = "Ember Reliquary", walkable = true, curio = "ember_reliquary", color = { 168, 96, 40 } },
    boss_sigil = { name = "Regent Sigil", walkable = true, encounter = "regent", color = { 128, 54, 74 } },
    tide_sigil = { name = "Tide Sigil", walkable = true, encounter = "matron", color = { 44, 116, 132 } },
    ember_sigil = { name = "Ember Sigil", walkable = true, encounter = "prioress", color = { 160, 74, 42 } },
    exit_gate = { name = "Exit Gate", walkable = true, exit = true, color = { 60, 106, 116 } },
    black_water = { name = "Black Water", walkable = false, color = { 20, 46, 58 } },
}

Registry.items = {
    torch = { name = "Torch", stack = 12, cost = 5, provision = true },
    ration = { name = "Ration", stack = 16, cost = 3, provision = true },
    bandage = { name = "Bandage", stack = 8, cost = 6, provision = true },
    laudanum = { name = "Laudanum", stack = 8, cost = 7, provision = true },
    skeleton_key = { name = "Skeleton Key", stack = 8, cost = 12, provision = true },
    salve = { name = "Salve", stack = 8, cost = 9, provision = true },
    ward_charm = { name = "Ward Charm", stack = 4, cost = 18, provision = true },
    relic = { name = "Relic", stack = 99 },
    coin = { name = "Coin", stack = 999 },
    heirloom = { name = "Heirloom", stack = 99 },
}

Registry.itemOrder = {
    "torch", "ration", "bandage", "laudanum", "skeleton_key", "salve", "ward_charm", "relic", "coin", "heirloom",
}
Registry.inventoryPanelOrder = Registry.itemOrder

Registry.trinkets = {
    ember_pin = { name = "Ember Pin", stressTaken = -1, speed = -1 },
    cracked_lens = { name = "Cracked Lens", damageBonus = 1, stressTaken = 1 },
    chirurgic_thread = { name = "Chirurgic Thread", healBonus = 2 },
    oath_ring = { name = "Oath Ring", maxHp = 3, speed = -1 },
    quiet_bell = { name = "Quiet Bell", resolve = 8, damageTaken = 1 },
}
Registry.trinketOrder = { "ember_pin", "cracked_lens", "chirurgic_thread", "oath_ring", "quiet_bell" }

Registry.quirks = {
    iron_nerves = { name = "Iron Nerves", kind = "positive", stressTaken = -1 },
    quick_reflexes = { name = "Quick Reflexes", kind = "positive", speed = 1 },
    steady_hand = { name = "Steady Hand", kind = "positive", damageBonus = 1 },
    field_reader = { name = "Field Reader", kind = "positive", resolve = 6 },
    gloomy = { name = "Gloomy", kind = "negative", stressTaken = 2 },
    brittle = { name = "Brittle", kind = "negative", damageTaken = 1 },
    faint_pulse = { name = "Faint Pulse", kind = "negative", maxHp = -2 },
    soft_voice = { name = "Soft Voice", kind = "negative", healBonus = -1 },
}
Registry.quirkOrder = {
    "iron_nerves", "quick_reflexes", "steady_hand", "field_reader",
    "gloomy", "brittle", "faint_pulse", "soft_voice",
}

Registry.diseases = {
    salt_cough = { name = "Salt Cough", speed = -1, stressTaken = 1 },
    brine_rot = { name = "Brine Rot", maxHp = -3, healBonus = -1 },
    ember_fever = { name = "Ember Fever", damageTaken = 1, resolve = -5 },
    glass_eye = { name = "Glass Eye", damageBonus = 1, stressTaken = 1 },
}
Registry.diseaseOrder = { "salt_cough", "brine_rot", "ember_fever", "glass_eye" }

Registry.heroClasses = {
    warden = {
        name = "Warden",
        maxHp = 28,
        speed = 3,
        resolve = 62,
        skills = { "shield_crack", "hold_line", "iron_oath" },
    },
    duelist = {
        name = "Duelist",
        maxHp = 20,
        speed = 7,
        resolve = 48,
        skills = { "razor_lunge", "arterial_cut", "shadow_step" },
    },
    mender = {
        name = "Mender",
        maxHp = 22,
        speed = 4,
        resolve = 56,
        skills = { "field_dress", "steady_words", "bone_saw" },
    },
    arcanist = {
        name = "Arcanist",
        maxHp = 18,
        speed = 5,
        resolve = 44,
        skills = { "lantern_bolt", "hush", "ember_veil" },
    },
    harrier = {
        name = "Harrier",
        maxHp = 19,
        speed = 6,
        resolve = 50,
        skills = { "crossbolt", "pinning_shot", "disengage" },
    },
    chirurgeon = {
        name = "Chirurgeon",
        maxHp = 20,
        speed = 4,
        resolve = 52,
        skills = { "acrid_vial", "cauterize", "triage" },
    },
    exile = {
        name = "Exile",
        maxHp = 24,
        speed = 5,
        resolve = 45,
        skills = { "low_sweep", "grit_teeth", "war_cry" },
    },
    lamplighter = {
        name = "Lamplighter",
        maxHp = 18,
        speed = 6,
        resolve = 58,
        skills = { "staff_strike", "kindle", "white_flare" },
    },
}
Registry.heroClassOrder = { "warden", "duelist", "mender", "arcanist", "harrier", "chirurgeon", "exile", "lamplighter" }

Registry.skills = {
    shield_crack = {
        name = "Shield Crack",
        class = "warden",
        userRanks = { 1, 2 },
        target = "enemy",
        targetRanks = { 1, 2 },
        damage = { 4, 7 },
    },
    hold_line = {
        name = "Hold Line",
        class = "warden",
        userRanks = { 1, 2, 3 },
        target = "self",
        guard = 2,
        stressHeal = 3,
    },
    iron_oath = {
        name = "Iron Oath",
        class = "warden",
        userRanks = { 1, 2 },
        target = "ally",
        targetRanks = { 1, 2, 3, 4 },
        heal = { 2, 4 },
        stressHeal = 2,
    },
    razor_lunge = {
        name = "Razor Lunge",
        class = "duelist",
        userRanks = { 2, 3, 4 },
        target = "enemy",
        targetRanks = { 1, 2, 3 },
        damage = { 5, 8 },
        move = -1,
    },
    arterial_cut = {
        name = "Arterial Cut",
        class = "duelist",
        userRanks = { 1, 2 },
        target = "enemy",
        targetRanks = { 1, 2 },
        damage = { 3, 5 },
        status = { kind = "bleed", amount = 1, turns = 3 },
    },
    shadow_step = {
        name = "Shadow Step",
        class = "duelist",
        userRanks = { 1, 2, 3 },
        target = "self",
        move = 1,
        stressHeal = 2,
    },
    field_dress = {
        name = "Field Dress",
        class = "mender",
        userRanks = { 2, 3, 4 },
        target = "ally",
        targetRanks = { 1, 2, 3, 4 },
        heal = { 5, 8 },
    },
    steady_words = {
        name = "Steady Words",
        class = "mender",
        userRanks = { 2, 3, 4 },
        target = "ally",
        targetRanks = { 1, 2, 3, 4 },
        stressHeal = 9,
    },
    bone_saw = {
        name = "Bone Saw",
        class = "mender",
        userRanks = { 1, 2 },
        target = "enemy",
        targetRanks = { 1, 2 },
        damage = { 3, 6 },
    },
    lantern_bolt = {
        name = "Lantern Bolt",
        class = "arcanist",
        userRanks = { 3, 4 },
        target = "enemy",
        targetRanks = { 2, 3, 4 },
        damage = { 4, 7 },
        stressDamage = 2,
    },
    hush = {
        name = "Hush",
        class = "arcanist",
        userRanks = { 3, 4 },
        target = "enemy",
        targetRanks = { 1, 2, 3, 4 },
        stressDamage = 8,
        status = { kind = "daze", amount = 1, turns = 1 },
    },
    ember_veil = {
        name = "Ember Veil",
        class = "arcanist",
        userRanks = { 3, 4 },
        target = "party",
        stressHeal = 3,
        torch = 8,
    },
    crossbolt = {
        name = "Crossbolt",
        class = "harrier",
        userRanks = { 2, 3, 4 },
        target = "enemy",
        targetRanks = { 2, 3, 4 },
        damage = { 4, 7 },
    },
    pinning_shot = {
        name = "Pinning Shot",
        class = "harrier",
        userRanks = { 3, 4 },
        target = "enemy",
        targetRanks = { 2, 3, 4 },
        damage = { 2, 4 },
        status = { kind = "daze", amount = 1, turns = 1 },
    },
    disengage = {
        name = "Disengage",
        class = "harrier",
        userRanks = { 1, 2, 3 },
        target = "self",
        move = 1,
        stressHeal = 3,
    },
    acrid_vial = {
        name = "Acrid Vial",
        class = "chirurgeon",
        userRanks = { 2, 3, 4 },
        target = "enemy",
        targetRanks = { 1, 2, 3 },
        damage = { 2, 4 },
        status = { kind = "blight", amount = 1, turns = 3 },
    },
    cauterize = {
        name = "Cauterize",
        class = "chirurgeon",
        userRanks = { 2, 3, 4 },
        target = "ally",
        targetRanks = { 1, 2, 3, 4 },
        heal = { 4, 6 },
        stressHeal = 1,
    },
    triage = {
        name = "Triage",
        class = "chirurgeon",
        userRanks = { 3, 4 },
        target = "party",
        stressHeal = 2,
    },
    low_sweep = {
        name = "Low Sweep",
        class = "exile",
        userRanks = { 1, 2 },
        target = "enemy",
        targetRanks = { 1, 2 },
        damage = { 4, 7 },
        status = { kind = "daze", amount = 1, turns = 1 },
    },
    grit_teeth = {
        name = "Grit Teeth",
        class = "exile",
        userRanks = { 1, 2, 3 },
        target = "self",
        guard = 1,
        stressHeal = 5,
    },
    war_cry = {
        name = "War Cry",
        class = "exile",
        userRanks = { 1, 2 },
        target = "enemy",
        targetRanks = { 1, 2, 3, 4 },
        stressDamage = 5,
    },
    staff_strike = {
        name = "Staff Strike",
        class = "lamplighter",
        userRanks = { 1, 2 },
        target = "enemy",
        targetRanks = { 1, 2 },
        damage = { 3, 6 },
    },
    kindle = {
        name = "Kindle",
        class = "lamplighter",
        userRanks = { 2, 3, 4 },
        target = "party",
        stressHeal = 2,
        torch = 12,
    },
    white_flare = {
        name = "White Flare",
        class = "lamplighter",
        userRanks = { 3, 4 },
        target = "enemy",
        targetRanks = { 2, 3, 4 },
        damage = { 2, 5 },
        stressDamage = 3,
        status = { kind = "daze", amount = 1, turns = 1 },
    },
}
Registry.skillOrder = {
    "shield_crack", "hold_line", "iron_oath", "razor_lunge", "arterial_cut", "shadow_step",
    "field_dress", "steady_words", "bone_saw", "lantern_bolt", "hush", "ember_veil",
    "crossbolt", "pinning_shot", "disengage", "acrid_vial", "cauterize", "triage",
    "low_sweep", "grit_teeth", "war_cry", "staff_strike", "kindle", "white_flare",
}

Registry.enemySkills = {
    rusted_chop = { name = "Rusted Chop", target = "hero", targetRanks = { 1, 2 }, damage = { 3, 5 }, stress = 1 },
    ink_splatter = { name = "Ink Splatter", target = "hero", targetRanks = { 3, 4 }, damage = { 1, 3 }, stress = 6, status = { kind = "marked", turns = 2 } },
    needle_dictation = { name = "Needle Dictation", target = "hero", targetRanks = { 2, 3, 4 }, damage = { 2, 4 }, stress = 4, status = { kind = "bleed", amount = 1, turns = 3 } },
    gutter_hook = { name = "Gutter Hook", target = "hero", targetRanks = { 2, 3, 4 }, damage = { 3, 5 }, stress = 2, move = -1 },
    censer_wail = { name = "Censer Wail", target = "party", stress = 4 },
    regent_sentence = { name = "Regent Sentence", target = "hero", targetRanks = { 1, 2, 3, 4 }, damage = { 5, 8 }, stress = 7, markBonus = 2 },
    brine_spit = { name = "Brine Spit", target = "hero", targetRanks = { 2, 3, 4 }, damage = { 2, 4 }, stress = 3, status = { kind = "blight", amount = 1, turns = 3 } },
    hook_chain = { name = "Hook Chain", target = "hero", targetRanks = { 3, 4 }, damage = { 2, 5 }, stress = 2, move = -1 },
    drowned_hymn = { name = "Drowned Hymn", target = "party", stress = 3 },
    kiln_bite = { name = "Kiln Bite", target = "hero", targetRanks = { 1, 2 }, damage = { 4, 6 }, stress = 1 },
    soot_cloud = { name = "Soot Cloud", target = "hero", targetRanks = { 2, 3, 4 }, damage = { 1, 3 }, stress = 5, status = { kind = "daze", amount = 1, turns = 1 } },
    furnace_liturgy = { name = "Furnace Liturgy", target = "party", stress = 5 },
}
Registry.enemySkillOrder = {
    "rusted_chop", "ink_splatter", "needle_dictation", "gutter_hook", "censer_wail", "regent_sentence",
    "brine_spit", "hook_chain", "drowned_hymn", "kiln_bite", "soot_cloud", "furnace_liturgy",
}

Registry.enemies = {
    hollow_guard = { name = "Hollow Guard", maxHp = 16, speed = 2, damage = { 3, 5 }, stress = 1, skills = { "rusted_chop" } },
    ink_wretch = { name = "Ink Wretch", maxHp = 10, speed = 6, damage = { 1, 3 }, stress = 6, skills = { "ink_splatter", "rusted_chop" } },
    bone_scribe = { name = "Bone Scribe", maxHp = 12, speed = 4, damage = { 2, 4 }, stress = 4, skills = { "needle_dictation", "ink_splatter" } },
    gutter_thing = { name = "Gutter Thing", maxHp = 14, speed = 5, damage = { 3, 6 }, stress = 2, skills = { "gutter_hook", "rusted_chop" } },
    pale_censer = { name = "Pale Censer", maxHp = 9, speed = 3, damage = { 1, 2 }, stress = 8, skills = { "censer_wail", "ink_splatter" } },
    vault_regent = { name = "Vault Regent", maxHp = 34, speed = 4, damage = { 5, 8 }, stress = 7, boss = true, skills = { "regent_sentence", "censer_wail" } },
    drowned_acolyte = { name = "Drowned Acolyte", maxHp = 11, speed = 5, damage = { 2, 4 }, stress = 5, skills = { "brine_spit", "drowned_hymn" } },
    brine_stalker = { name = "Brine Stalker", maxHp = 17, speed = 4, damage = { 3, 6 }, stress = 2, skills = { "hook_chain", "brine_spit" } },
    bell_diver = { name = "Bell Diver", maxHp = 28, speed = 2, damage = { 5, 8 }, stress = 6, boss = true, skills = { "hook_chain", "drowned_hymn" } },
    ash_husk = { name = "Ash Husk", maxHp = 13, speed = 4, damage = { 3, 5 }, stress = 3, skills = { "kiln_bite", "soot_cloud" } },
    kiln_imp = { name = "Kiln Imp", maxHp = 9, speed = 7, damage = { 2, 4 }, stress = 5, skills = { "soot_cloud", "kiln_bite" } },
    cinder_prioress = { name = "Cinder Prioress", maxHp = 31, speed = 5, damage = { 4, 7 }, stress = 8, boss = true, skills = { "furnace_liturgy", "soot_cloud" } },
}
Registry.enemyOrder = {
    "hollow_guard", "ink_wretch", "bone_scribe", "gutter_thing", "pale_censer", "vault_regent",
    "drowned_acolyte", "brine_stalker", "bell_diver", "ash_husk", "kiln_imp", "cinder_prioress",
}

Registry.afflictions = {
    panic = { name = "Panic", stressTaken = 2, accuracy = -1 },
    spite = { name = "Spite", stressTaken = 1, damageTaken = 1 },
    numb = { name = "Numb", healPenalty = 1 },
    reckless = { name = "Reckless", damageBonus = 1, stressTaken = 2 },
}
Registry.afflictionOrder = { "panic", "spite", "numb", "reckless" }
Registry.virtues = {
    focused = { name = "Focused", stressTaken = -2, damageBonus = 1 },
}
Registry.virtueOrder = { "focused" }

Registry.curios = {
    relic_cache = { name = "Relic Cache", item = "skeleton_key", loot = { relic = 2, coin = 45 }, stress = -3 },
    whispering_idol = { name = "Whispering Idol", loot = { heirloom = 1 }, stress = 8 },
    wire_snare = { name = "Wire Snare", item = "bandage", damage = 4, stress = 5 },
    salt_font = { name = "Salt Font", item = "laudanum", stress = -8, loot = { coin = 20 } },
    brine_lockbox = { name = "Brine Lockbox", item = "skeleton_key", loot = { coin = 65, heirloom = 1 }, stress = 2 },
    ash_vent = { name = "Ash Vent", item = "salve", damage = 5, stress = 4 },
    ember_reliquary = { name = "Ember Reliquary", item = "ward_charm", loot = { relic = 1, coin = 55 }, stress = -4 },
    cold_camp = { name = "Cold Camp", camp = true },
}
Registry.curioOrder = {
    "relic_cache", "whispering_idol", "wire_snare", "salt_font", "brine_lockbox", "ash_vent", "ember_reliquary", "cold_camp",
}

Registry.encounters = {
    entry = { "hollow_guard", "ink_wretch" },
    stacks = { "bone_scribe", "ink_wretch", "pale_censer" },
    undercroft = { "gutter_thing", "hollow_guard", "bone_scribe" },
    regent = { "vault_regent", "pale_censer" },
    cistern_entry = { "drowned_acolyte", "brine_stalker" },
    cistern_depths = { "brine_stalker", "drowned_acolyte", "pale_censer" },
    matron = { "bell_diver", "drowned_acolyte" },
    ember_entry = { "ash_husk", "kiln_imp" },
    ember_altar = { "kiln_imp", "ash_husk", "pale_censer" },
    prioress = { "cinder_prioress", "kiln_imp" },
}
Registry.encounterOrder = {
    "entry", "stacks", "undercroft", "regent",
    "cistern_entry", "cistern_depths", "matron", "ember_entry", "ember_altar", "prioress",
}

Registry.locations = {
    buried_archive = {
        name = "Buried Archive",
        objectiveRooms = 3,
        start = { x = 0, y = 0, z = 0 },
        bossRoom = "24:0",
        layout = {
            floorTile = "archive_floor",
            wallTile = "archive_wall",
            corridorTile = "corridor",
            obstacleTile = "black_water",
            obstacleModulo = 71,
            rooms = {
                { key = "0:0", x = 0, y = 0, w = 3, h = 3 },
                { key = "8:0", x = 8, y = 0, w = 3, h = 3 },
                { key = "16:0", x = 16, y = 0, w = 3, h = 3 },
                { key = "24:0", x = 24, y = 0, w = 3, h = 3 },
                { key = "8:6", x = 8, y = 6, w = 3, h = 3 },
                { key = "16:6", x = 16, y = 6, w = 3, h = 3 },
                { key = "24:6", x = 24, y = 6, w = 3, h = 3 },
            },
            corridors = {
                { ax = 0, ay = 0, bx = 8, by = 0 },
                { ax = 8, ay = 0, bx = 16, by = 0 },
                { ax = 16, ay = 0, bx = 24, by = 0 },
                { ax = 8, ay = 0, bx = 8, by = 6 },
                { ax = 8, ay = 6, bx = 16, by = 6 },
                { ax = 16, ay = 6, bx = 24, by = 6 },
                { ax = 24, ay = 0, bx = 24, by = 6 },
            },
            specials = {
                { x = 0, y = 0, z = 0, tile = "archive_floor" },
                { x = -2, y = 2, z = 0, tile = "exit_gate" },
                { x = 4, y = 0, z = 0, tile = "wire_snare" },
                { x = 8, y = 6, z = 0, tile = "camp_marker" },
                { x = 16, y = 0, z = 0, tile = "relic_cache" },
                { x = 16, y = 6, z = 0, tile = "whispering_idol" },
                { x = 24, y = 0, z = 0, tile = "boss_sigil" },
            },
        },
        encounters = {
            ["8:0"] = "entry",
            ["16:0"] = "stacks",
            ["16:6"] = "undercroft",
            ["24:0"] = "regent",
        },
    },
    salt_cistern = {
        name = "Salt Cistern",
        objectiveRooms = 4,
        start = { x = 0, y = 0, z = 0 },
        bossRoom = "18:10",
        layout = {
            floorTile = "salt_floor",
            wallTile = "salt_wall",
            corridorTile = "salt_causeway",
            obstacleTile = "brine_pool",
            obstacleModulo = 59,
            rooms = {
                { key = "0:0", x = 0, y = 0, w = 3, h = 3 },
                { key = "6:4", x = 6, y = 4, w = 3, h = 3 },
                { key = "12:0", x = 12, y = 0, w = 3, h = 3 },
                { key = "18:4", x = 18, y = 4, w = 3, h = 3 },
                { key = "18:10", x = 18, y = 10, w = 3, h = 3 },
                { key = "6:10", x = 6, y = 10, w = 3, h = 3 },
            },
            corridors = {
                { ax = 0, ay = 0, bx = 6, by = 4 },
                { ax = 6, ay = 4, bx = 12, by = 0 },
                { ax = 12, ay = 0, bx = 18, by = 4 },
                { ax = 18, ay = 4, bx = 18, by = 10 },
                { ax = 6, ay = 4, bx = 6, by = 10 },
                { ax = 6, ay = 10, bx = 18, by = 10 },
            },
            specials = {
                { x = 0, y = 0, z = 0, tile = "salt_floor" },
                { x = -2, y = 2, z = 0, tile = "exit_gate" },
                { x = 6, y = 4, z = 0, tile = "salt_font" },
                { x = 12, y = 0, z = 0, tile = "brine_lockbox" },
                { x = 6, y = 10, z = 0, tile = "camp_marker" },
                { x = 18, y = 10, z = 0, tile = "tide_sigil" },
            },
        },
        encounters = {
            ["6:4"] = "cistern_entry",
            ["18:4"] = "cistern_depths",
            ["18:10"] = "matron",
        },
    },
    ember_warrens = {
        name = "Ember Warrens",
        objectiveRooms = 4,
        start = { x = 0, y = 0, z = 0 },
        bossRoom = "20:-8",
        layout = {
            floorTile = "ember_floor",
            wallTile = "ember_wall",
            corridorTile = "ember_corridor",
            obstacleTile = "ash_choke",
            obstacleModulo = 67,
            rooms = {
                { key = "0:0", x = 0, y = 0, w = 3, h = 3 },
                { key = "8:0", x = 8, y = 0, w = 3, h = 3 },
                { key = "14:-4", x = 14, y = -4, w = 3, h = 3 },
                { key = "20:-8", x = 20, y = -8, w = 3, h = 3 },
                { key = "14:4", x = 14, y = 4, w = 3, h = 3 },
                { key = "20:4", x = 20, y = 4, w = 3, h = 3 },
            },
            corridors = {
                { ax = 0, ay = 0, bx = 8, by = 0 },
                { ax = 8, ay = 0, bx = 14, by = -4 },
                { ax = 14, ay = -4, bx = 20, by = -8 },
                { ax = 8, ay = 0, bx = 14, by = 4 },
                { ax = 14, ay = 4, bx = 20, by = 4 },
            },
            specials = {
                { x = 0, y = 0, z = 0, tile = "ember_floor" },
                { x = -2, y = 2, z = 0, tile = "exit_gate" },
                { x = 8, y = 0, z = 0, tile = "ash_vent" },
                { x = 14, y = 4, z = 0, tile = "ember_reliquary" },
                { x = 20, y = 4, z = 0, tile = "camp_marker" },
                { x = 20, y = -8, z = 0, tile = "ember_sigil" },
            },
        },
        encounters = {
            ["8:0"] = "ember_entry",
            ["14:4"] = "ember_altar",
            ["20:-8"] = "prioress",
        },
    },
}
Registry.locationOrder = { "buried_archive", "salt_cistern", "ember_warrens" }

Registry.missions = {
    archive_scout = {
        name = "Scout the Buried Archive",
        location = "buried_archive",
        kind = "scout",
        objectiveRooms = 3,
        reward = { gold = 80, heirlooms = 1 },
    },
    archive_cleansing = {
        name = "Cull the Index Dead",
        location = "buried_archive",
        kind = "cleanse",
        objectiveEncounters = 2,
        reward = { gold = 110, heirlooms = 2 },
    },
    archive_regent = {
        name = "Silence the Vault Regent",
        location = "buried_archive",
        kind = "boss",
        reward = { gold = 170, heirlooms = 4, trinket = "quiet_bell" },
    },
    cistern_survey = {
        name = "Sound the Salt Cistern",
        location = "salt_cistern",
        kind = "scout",
        objectiveRooms = 4,
        reward = { gold = 95, heirlooms = 2 },
    },
    cistern_bell = {
        name = "Sink the Bell Diver",
        location = "salt_cistern",
        kind = "boss",
        reward = { gold = 185, heirlooms = 4, trinket = "oath_ring" },
    },
    ember_cleansing = {
        name = "Quench the Ember Warrens",
        location = "ember_warrens",
        kind = "cleanse",
        objectiveEncounters = 2,
        reward = { gold = 125, heirlooms = 3 },
    },
    ember_prioress = {
        name = "Break the Cinder Prioress",
        location = "ember_warrens",
        kind = "boss",
        reward = { gold = 195, heirlooms = 5, trinket = "ember_pin" },
    },
}
Registry.missionOrder = {
    "archive_scout", "archive_cleansing", "archive_regent",
    "cistern_survey", "cistern_bell", "ember_cleansing", "ember_prioress",
}

Registry.campSkills = {
    bind_wounds = { name = "Bind Wounds", cost = 2, target = "ally", heal = 5, stressHeal = 3 },
    watch_order = { name = "Watch Order", cost = 2, target = "party", torch = 20, stressHeal = 2, preventAmbush = true },
    bitter_tonic = { name = "Bitter Tonic", cost = 1, target = "ally", clearStatuses = { "bleed", "blight" }, stressHeal = 1 },
    last_rites = { name = "Last Rites", cost = 3, target = "party", stressHeal = 5 },
}
Registry.campSkillOrder = { "bind_wounds", "watch_order", "bitter_tonic", "last_rites" }

Registry.estateBuildings = {
    stagecoach = { name = "Stagecoach", maxLevel = 3, heirloomCost = 2, rosterLimit = 6, rosterPerLevel = 2, recruitSlots = 3, slotsPerLevel = 1, recruitCost = 20, discountPerLevel = 3 },
    guild = { name = "Guild", maxLevel = 3, heirloomCost = 3, maxSkillLevel = 2, skillMaxPerLevel = 1, skillUpgradeCost = 30 },
    forge = { name = "Forge", maxLevel = 3, heirloomCost = 3, maxGearLevel = 1, gearMaxPerLevel = 1, gearUpgradeCost = 35 },
    infirmary = { name = "Infirmary", maxLevel = 3, heirloomCost = 2, recoverCost = 25, quirkTreatmentCost = 35, diseaseTreatmentCost = 30, discountPerLevel = 4 },
}
Registry.estateBuildingOrder = { "stagecoach", "guild", "forge", "infirmary" }

return Registry
