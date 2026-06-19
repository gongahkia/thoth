local Registry = {}

Registry.tiles = {
    archive_floor = { name = "Archive Floor", walkable = true, color = { 82, 78, 86 } },
    archive_wall = { name = "Archive Wall", walkable = false, color = { 36, 34, 42 } },
    corridor = { name = "Corridor", walkable = true, color = { 64, 62, 70 } },
    sealed_door = { name = "Sealed Door", walkable = false, color = { 84, 62, 44 } },
    camp_marker = { name = "Cold Camp", walkable = true, curio = "cold_camp", color = { 96, 86, 64 } },
    relic_cache = { name = "Relic Cache", walkable = true, curio = "relic_cache", color = { 146, 116, 58 } },
    whispering_idol = { name = "Whispering Idol", walkable = true, curio = "whispering_idol", color = { 98, 72, 128 } },
    wire_snare = { name = "Wire Snare", walkable = true, curio = "wire_snare", color = { 110, 48, 48 } },
    boss_sigil = { name = "Regent Sigil", walkable = true, encounter = "regent", color = { 128, 54, 74 } },
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
}
Registry.heroClassOrder = { "warden", "duelist", "mender", "arcanist" }

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
}
Registry.skillOrder = {
    "shield_crack", "hold_line", "iron_oath", "razor_lunge", "arterial_cut", "shadow_step",
    "field_dress", "steady_words", "bone_saw", "lantern_bolt", "hush", "ember_veil",
}

Registry.enemySkills = {
    rusted_chop = { name = "Rusted Chop", target = "hero", targetRanks = { 1, 2 }, damage = { 3, 5 }, stress = 1 },
    ink_splatter = { name = "Ink Splatter", target = "hero", targetRanks = { 3, 4 }, damage = { 1, 3 }, stress = 6, status = { kind = "marked", turns = 2 } },
    needle_dictation = { name = "Needle Dictation", target = "hero", targetRanks = { 2, 3, 4 }, damage = { 2, 4 }, stress = 4, status = { kind = "bleed", amount = 1, turns = 3 } },
    gutter_hook = { name = "Gutter Hook", target = "hero", targetRanks = { 2, 3, 4 }, damage = { 3, 5 }, stress = 2, move = -1 },
    censer_wail = { name = "Censer Wail", target = "party", stress = 4 },
    regent_sentence = { name = "Regent Sentence", target = "hero", targetRanks = { 1, 2, 3, 4 }, damage = { 5, 8 }, stress = 7, markBonus = 2 },
}
Registry.enemySkillOrder = {
    "rusted_chop", "ink_splatter", "needle_dictation", "gutter_hook", "censer_wail", "regent_sentence",
}

Registry.enemies = {
    hollow_guard = { name = "Hollow Guard", maxHp = 16, speed = 2, damage = { 3, 5 }, stress = 1, skills = { "rusted_chop" } },
    ink_wretch = { name = "Ink Wretch", maxHp = 10, speed = 6, damage = { 1, 3 }, stress = 6, skills = { "ink_splatter", "rusted_chop" } },
    bone_scribe = { name = "Bone Scribe", maxHp = 12, speed = 4, damage = { 2, 4 }, stress = 4, skills = { "needle_dictation", "ink_splatter" } },
    gutter_thing = { name = "Gutter Thing", maxHp = 14, speed = 5, damage = { 3, 6 }, stress = 2, skills = { "gutter_hook", "rusted_chop" } },
    pale_censer = { name = "Pale Censer", maxHp = 9, speed = 3, damage = { 1, 2 }, stress = 8, skills = { "censer_wail", "ink_splatter" } },
    vault_regent = { name = "Vault Regent", maxHp = 34, speed = 4, damage = { 5, 8 }, stress = 7, boss = true, skills = { "regent_sentence", "censer_wail" } },
}
Registry.enemyOrder = { "hollow_guard", "ink_wretch", "bone_scribe", "gutter_thing", "pale_censer", "vault_regent" }

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
    cold_camp = { name = "Cold Camp", camp = true },
}
Registry.curioOrder = { "relic_cache", "whispering_idol", "wire_snare", "cold_camp" }

Registry.encounters = {
    entry = { "hollow_guard", "ink_wretch" },
    stacks = { "bone_scribe", "ink_wretch", "pale_censer" },
    undercroft = { "gutter_thing", "hollow_guard", "bone_scribe" },
    regent = { "vault_regent", "pale_censer" },
}
Registry.encounterOrder = { "entry", "stacks", "undercroft", "regent" }

Registry.locations = {
    buried_archive = {
        name = "Buried Archive",
        objectiveRooms = 3,
        start = { x = 0, y = 0, z = 0 },
        bossRoom = "24:0",
        encounters = {
            ["8:0"] = "entry",
            ["16:0"] = "stacks",
            ["16:6"] = "undercroft",
            ["24:0"] = "regent",
        },
    },
}
Registry.locationOrder = { "buried_archive" }

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
}
Registry.missionOrder = { "archive_scout", "archive_cleansing", "archive_regent" }

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
    infirmary = { name = "Infirmary", maxLevel = 3, heirloomCost = 2, recoverCost = 25, quirkTreatmentCost = 35, discountPerLevel = 4 },
}
Registry.estateBuildingOrder = { "stagecoach", "guild", "forge", "infirmary" }

return Registry
