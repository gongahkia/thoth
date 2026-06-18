package.path = "./?.lua;./?/init.lua;./src/?.lua;./src/?/init.lua;" .. package.path

local Serialize = require("src.core.serialize")
local Simulation = require("src.game.simulation")
local Save = require("src.game.save")
local Replay = require("src.game.replay")
local World = require("src.game.world")

local function expect(value, message)
    if not value then
        error(message or "expectation failed", 2)
    end
end

local function sameSnapshot(a, b)
    return Serialize.encode(a:snapshot()) == Serialize.encode(b:snapshot())
end

local function runSteps(sim, count)
    for _ = 1, count do
        sim:step()
    end
end

local bossCosts = {
    marsh_broodheart = { water_barrel = 1, reed_fiber = 3, science_pack = 1 },
    glass_maw = { sand_glass = 3, cactus_fiber = 3, science_pack = 1 },
    badlands_warden = { basalt = 4, iron_plate = 4, advanced_science_pack = 1 },
    frost_nullifier = { ice_shard = 4, circuit_board = 2, advanced_science_pack = 1 },
    rift_signal_tyrant = { beacon_core = 1, crystal = 2, advanced_science_pack = 2 },
}

local function addItems(sim, items)
    for item, count in pairs(items) do
        sim:addItem(item, count)
    end
end

local tests = {}

tests[#tests + 1] = function()
    expect(World.floorDiv(0, World.chunkSize) == 0, "origin chunk div failed")
    expect(World.floorDiv(31, World.chunkSize) == 0, "positive edge chunk div failed")
    expect(World.floorDiv(32, World.chunkSize) == 1, "positive boundary chunk div failed")
    expect(World.floorDiv(-1, World.chunkSize) == -1, "negative edge chunk div failed")
    expect(World.floorMod(-1, World.chunkSize) == 31, "negative edge chunk mod failed")
    local first = World.new(101)
    local second = World.new(101)
    expect(first:loadedChunkCount() == 0, "fresh world should not load chunks")
    local a = first:getTile(31, 0, 0)
    expect(first:loadedChunkCount() == 1, "first tile read should load one chunk")
    expect(second:getTile(31, 0, 0).id == a.id, "same seed should generate same chunk tile")
    first:getTile(32, 0, 0)
    expect(first:loadedChunkCount() == 2, "boundary tile should load adjacent chunk")
    first:setTile(32, 0, 0, { id = "water", data = 0 })
    expect(first:getTile(32, 0, 0).id == "water", "chunk boundary mutation should persist")
    first:clearLoadedChunks()
    expect(first:loadedChunkCount() == 0, "chunk cache should clear")
    expect(first:getTile(32, 0, 0).id == "water", "overrides should survive chunk cache clear")
    local cached = World.new(707)
    local origin = cached:getTile(0, 0, 0)
    cached:getTile(32, 0, 0)
    cached:setTile(33, 0, 0, { id = "water", data = 0 })
    local snapshot = cached:snapshot()
    expect(#snapshot.chunks == 2, "snapshot should preserve loaded chunk keys")
    expect(#snapshot.tiles == 1, "snapshot should include only modified tiles")
    local loaded = World.fromSnapshot(snapshot)
    expect(loaded:loadedChunkCount() == 2, "loaded world should restore cached chunks")
    expect(loaded:getTile(0, 0, 0).id == origin.id, "loaded chunk should preserve deterministic generation")
    expect(loaded:getTile(33, 0, 0).id == "water", "loaded world should preserve modified tile")
end

tests[#tests + 1] = function()
    local world = World.new(808)
    expect(world:getTile(-1, 0, 0).id == "tree", "starter tree missing")
    expect(world:getTile(0, 3, 0).id == "stone", "starter stone missing")
    expect(world:getTile(3, 0, 0).id == "coal_ore" and world:getTile(3, 0, 0).data == 18, "starter coal missing")
    expect(world:getTile(0, -3, 0).id == "iron_ore" and world:getTile(0, -3, 0).data == 22, "starter iron missing")
    expect(world:getTile(3, -3, 0).id == "copper_ore" and world:getTile(3, -3, 0).data == 22, "starter copper missing")
end

tests[#tests + 1] = function()
    local world = World.new(99)
    expect(world:biomeAt(0, 0, 0) == "grassland", "origin should remain grassland")
    expect(world:biomeAt(12, 0, 0) == "desert", "starter desert biome missing")
    expect(world:biomeAt(-12, 0, 0) == "snowfield", "starter snowfield biome missing")
    expect(world:biomeAt(0, 12, 0) == "marsh", "starter marsh biome missing")
    expect(world:biomeAt(36, 20, 0) == "badlands", "starter badlands biome missing")
    expect(world:biomeAt(-36, 20, 0) == "crystal_field", "starter crystal biome missing")
    expect(world:biomeAt(4096, 0, 0) == "rift", "rift band biome missing")
    expect(world:getTile(11, -12, 0).id == "sand", "desert base terrain missing")
    expect(world:getTile(-24, -10, 0).id == "snow", "snowfield base terrain missing")
    expect(world:getTile(-8, 8, 0).id == "mud", "marsh base terrain missing")
    expect(world:getTile(29, 12, 0).id == "basalt", "badlands base terrain missing")
    expect(world:getTile(-43, 12, 0).id == "stone", "crystal field base terrain missing")
    local riftResources = {}
    for x = 4096, 4144 do
        for y = -24, 24 do
            local tile = world:getTile(x, y, 0)
            if tile.id == "iron_ore" or tile.id == "copper_ore" or tile.id == "coal_ore" then
                riftResources[tile.id] = true
                expect(tile.data >= 12, "rift ore should be richer than starter ore")
            end
        end
    end
    expect(riftResources.iron_ore and riftResources.copper_ore and riftResources.coal_ore, "rift band should include rich ore mix")
end

tests[#tests + 1] = function()
    local world = World.new(202)
    local near = world:getTile(-1, -176, 0)
    local far = world:getTile(-2, -755, 0)
    expect(near.id == "iron_ore", "near procedural ore sample changed")
    expect(far.id == "coal_ore", "far procedural ore sample changed")
    expect(far.data > near.data, "far ore should be richer than near ore")
end

tests[#tests + 1] = function()
    local world = World.new(303)
    local lairs = {
        { "marsh_hive", 0, 18 },
        { "glass_spire", 18, -2 },
        { "badlands_foundry", 36, 20 },
        { "frost_vault", -18, 0 },
        { "crystal_vault", -36, 20 },
    }
    for _, lair in ipairs(lairs) do
        local key, x, y = lair[1], lair[2], lair[3]
        expect(world:lairAt(x, y, 0) == key, "authored lair identity missing " .. key)
        expect(world:lairAt(x, y, -1) == key, "authored lair interior identity missing " .. key)
        expect(world:getTile(x, y, 0).id == "stairs_down", "authored lair should expose stairs " .. key)
        expect(world:getTile(x + 5, y, 0).id == "dungeon_wall", "authored lair boundary missing " .. key)
        expect(world:getTile(x + 2, y, 0).id == "lair_hearth", "authored lair hearth missing " .. key)
    end
end

tests[#tests + 1] = function()
    local world = World.new(404)
    expect(world:lairAt(417, -453, 0) == "marsh_hive", "generated lair identity missing")
    expect(world:lairAt(417, -453, -1) == "marsh_hive", "generated lair interior identity missing")
    expect(world:getTile(417, -453, 0).id == "stairs_down", "generated lair should expose stairs")
    expect(world:getTile(422, -453, 0).id == "dungeon_wall", "generated lair boundary missing")
    expect(world:lairAt(60, 60, 0) == nil, "protected starter ring should not contain generated lair")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(37)
    sim.world:setTile(1, 0, 0, { id = "water", data = 0 })
    sim.world:setTile(2, 0, 0, { id = "grass", data = 0 })
    sim:queue(Simulation.commands.move("east"))
    sim:step()
    expect(sim.player.x == 0, "player should not enter water without boat")
    sim:addItem("boat", 1)
    sim:queue(Simulation.commands.move("east"))
    sim:step()
    expect(sim.player.x == 1 and sim.player.inBoat, "boat should allow water traversal")
    local loaded = assert(Save.fromText(Save.toText(sim)))
    expect(loaded.player.inBoat, "boat state should persist")
    loaded:queue(Simulation.commands.move("east"))
    loaded:step()
    expect(loaded.player.x == 2 and not loaded.player.inBoat, "leaving water should exit boat traversal")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(38)
    sim.world:setTile(1, 0, 0, { id = "stairs_down", data = 0 })
    sim.world:setTile(2, 0, -1, { id = "stairs_up", data = 0 })
    sim:queue(Simulation.commands.move("east"))
    sim:step()
    expect(sim.player.x == 1 and sim.player.z == -1, "stairs down should move player to lower layer")
    sim:queue(Simulation.commands.move("east"))
    sim:step()
    expect(sim.player.x == 2 and sim.player.z == 0, "stairs up should move player to upper layer")
    local tutorial = Simulation.new(39, true)
    tutorial.player.x = 4
    tutorial.player.y = 0
    tutorial:queue(Simulation.commands.move("east"))
    tutorial:step()
    expect(tutorial.player.z == 2 and tutorial:tutorialState().active, "tutorial stairs should stay locked before checklist completion")
end

tests[#tests + 1] = function()
    local world = World.new(404)
    expect(world:getTile(0, 0, -1).id == "stairs_up", "generic dungeon should expose return stairs")
    expect(world:getTile(1, 1, -1).id == "dungeon_wall", "generic dungeon should have walls")
    expect(world:getTile(8, 1, -1).id == "dungeon_floor", "generic dungeon should have corridors")
    expect(world:getTile(0, 18, -1).id == "stairs_up", "authored lair interior should expose return stairs")
    expect(world:getTile(5, 18, -1).id == "dungeon_wall", "authored lair interior boundary missing")
    expect(world:getTile(3, 19, -1).id == "reeds", "authored lair interior material missing")
    expect(world:getTile(417, -453, -1).id == "stairs_up", "generated lair interior should expose return stairs")
end

tests[#tests + 1] = function()
    local world = World.new(505)
    expect(world:getTile(24, 2, 0).id == "cactus", "desert material missing")
    expect(world:getTile(2, 9, 0).id == "reeds", "marsh material missing")
    expect(world:getTile(-16, -10, 0).id == "ice", "snowfield material missing")
    expect(world:getTile(28, 12, 0).id == "basalt", "badlands material missing")
    expect(world:getTile(-28, 16, 0).id == "crystal", "crystal field material missing")
    local riftMaterial = world:getTile(3844, -29, 0).id
    expect(riftMaterial == "stone" or riftMaterial == "iron_ore" or riftMaterial == "copper_ore" or riftMaterial == "coal_ore", "rift material missing")
end

tests[#tests + 1] = function()
    local world = World.new(606)
    expect(world:biomeAt(-8, -80, 0) ~= "grassland", "biome cache sample should be in a biome")
    expect(world:getTile(-8, -80, 0).id == "recovery_crate", "biome cache crate missing")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(40)
    sim.player.x = 1
    sim.player.y = 18
    sim:queue(Simulation.commands.mine("east"))
    sim:step()
    expect(sim:itemCount("lair_hearth") == 1, "lair hearth should be claimable")
    expect(sim.world:getTile(2, 18, 0).id == "grass", "claimed lair hearth should clear")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(606)
    sim.player.x = -9
    sim.player.y = -80
    sim:queue(Simulation.commands.mine("east"))
    sim:step()
    expect(sim:itemCount("recovery_crate") == 1, "recovery crate should be claimable")
    expect(sim.world:getTile(-8, -80, 0).id == "grass", "claimed recovery crate should clear")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(607)
    sim.player.z = -1
    sim.world:setTile(1, 0, -1, { id = "recovery_crate", data = 0 })
    sim:queue(Simulation.commands.mine("east"))
    sim:step()
    expect(sim.productionTotals.dungeon_chests_opened == 1, "dungeon recovery crate should count as opened cache")
    expect(sim.world:getTile(1, 0, -1).id == "dungeon_floor", "dungeon cache should clear to dungeon floor")
    local loaded = assert(Save.fromText(Save.toText(sim)))
    expect(loaded.productionTotals.dungeon_chests_opened == 1, "opened dungeon cache counter should persist")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(404)
    sim.player.x = 417
    sim.player.y = -453
    sim.player.z = -1
    expect(sim.world:lairAt(417, -453, -1) == "marsh_hive", "generated lair cache identity missing before save")
    expect(sim.world:getTile(417, -453, -1).id == "stairs_up", "generated lair interior missing before save")
    sim.world:setTile(8, 1, -1, { id = "recovery_crate", data = 0 })
    local loaded = assert(Save.fromText(Save.toText(sim)))
    expect(loaded.player.z == -1, "dungeon player layer should persist")
    expect(loaded.world:lairAt(417, -453, -1) == "marsh_hive", "generated lair cache identity should persist")
    expect(loaded.world:getTile(417, -453, -1).id == "stairs_up", "generated lair interior should persist")
    expect(loaded.world:getTile(8, 1, -1).id == "recovery_crate", "dungeon tile override should persist")
end

tests[#tests + 1] = function()
    local a = Simulation.new(42)
    local b = Simulation.new(42)
    local commands = {
        Simulation.commands.face("west"),
        Simulation.commands.mine("west"),
        Simulation.commands.move("east"),
        Simulation.commands.move("east"),
        Simulation.commands.mine("east"),
    }
    for _, command in ipairs(commands) do
        a:queue(command)
        b:queue(command)
        a:step()
        b:step()
    end
    expect(sameSnapshot(a, b), "same seed and commands diverged")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(43)
    sim:queue(Simulation.commands.damagePlayer(7))
    sim:step()
    expect(sim.player.hp == 13, "player damage should reduce hp")
    sim:queue(Simulation.commands.healPlayer(100))
    sim:step()
    expect(sim.player.hp == 20, "player healing should clamp to max hp")
    sim:queue(Simulation.commands.damagePlayer(25))
    sim:step()
    expect(sim.player.hp == 0, "player damage should clamp at zero")
    local loaded = assert(Save.fromText(Save.toText(sim)))
    expect(loaded.player.hp == 0, "player hp should persist")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(44)
    local entity = sim:addEntity("slime", 1, 0, 0, 2)
    sim:queue(Simulation.commands.attack("east"))
    sim:step()
    expect(entity.hp == 1, "attack should damage entity hp")
    local loaded = assert(Save.fromText(Save.toText(sim)))
    expect(#loaded.entities == 1 and loaded.entities[1].hp == 1, "entity hp should persist")
    loaded:queue(Simulation.commands.attack("east"))
    loaded:step()
    expect(#loaded.entities == 0, "entity should be removed at zero hp")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(45)
    local entity = sim:addEntity("slime", 1, 0, 0, 3)
    sim:step()
    expect(sim.player.hp == 19 and entity.attackCooldown == 30, "adjacent entity should attack and enter cooldown")
    sim:step()
    expect(sim.player.hp == 19 and entity.attackCooldown == 29, "entity cooldown should delay repeat attacks")
    local loaded = assert(Save.fromText(Save.toText(sim)))
    expect(loaded.entities[1].attackCooldown == 29, "entity attack cooldown should persist")
    runSteps(loaded, 29)
    expect(loaded.player.hp == 18, "entity should attack again after cooldown")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(46)
    sim.player.x = 4
    local entity = sim:addEntity("slime", 0, 0, 0, 3)
    sim:step()
    expect(entity.x == 1 and entity.y == 0, "hostile should path toward player")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(47)
    sim.player.x = 10
    sim.world:setTile(-1, 0, 0, { id = "grass", data = 0 })
    sim:addMachine("chest", -4, 0, "south")
    local entity = sim:addEntity("slime", 0, 0, 0, 3)
    sim:step()
    expect(entity.x == -1 and entity.y == 0, "hostile should path toward nearest infrastructure")
end

tests[#tests + 1] = function()
    local safe = Simulation.new(48)
    safe:ensureLocalEntities()
    expect(#safe.entities == 0, "starter grassland should not spawn local hostiles")
    local sim = Simulation.new(49)
    sim.player.x = 0
    sim.player.y = 12
    sim:step()
    expect(#sim.entities > 0, "marsh should spawn local hostiles")
    for _, entity in ipairs(sim.entities) do
        expect(entity.kind == "slime", "marsh should spawn slime hostiles")
        expect(entity.hp == sim:entityMaxHp(entity.kind), "local hostile should use kind hp")
        expect(sim.world:biomeAt(entity.x, entity.y, entity.z) == "marsh", "local hostile should stay in player biome")
    end
end

tests[#tests + 1] = function()
    local sim = Simulation.new(50)
    sim.player.x = 0
    sim.player.y = 16
    local boss = sim:addEntity("marsh_broodheart", 0, 12, 0)
    expect(boss.hp == 14 and sim:isBossKind(boss.kind), "marsh boss stats missing")
    boss.hp = 7
    sim.tick = 90
    sim:updateEntities()
    local spawned = false
    for _, entity in ipairs(sim.entities) do
        if entity.kind == "slime" then
            spawned = true
        end
    end
    expect(spawned, "marsh boss half-health phase should spawn slime")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(51)
    local boss = sim:addEntity("glass_maw", 1, 0, 0)
    expect(boss.hp == 16 and sim:isBossKind(boss.kind), "glass boss stats missing")
    sim:attack("east")
    expect(boss.hp == 15, "glass boss should resist attacks before pressure proof")
    sim.productionTotals.pressure_waves_repelled = 1
    sim:attack("east")
    expect(boss.hp == 13, "glass boss resistance should drop after pressure proof")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(52)
    local boss = sim:addEntity("badlands_warden", 1, 0, 0)
    expect(boss.hp == 18 and sim:isBossKind(boss.kind), "badlands boss stats missing")
    sim:attack("east")
    expect(boss.hp == 16, "badlands boss should take boss-scale player damage")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(53)
    sim.player.y = 5
    local machine = sim:addMachine("assembler", 1, 0, "south")
    machine.progress = 12
    machine.status = "working"
    local boss = sim:addEntity("frost_nullifier", 3, 0, 0)
    expect(boss.hp == 20 and sim:isBossKind(boss.kind), "frost boss stats missing")
    sim.tick = 120
    sim:updateEntities()
    expect(machine.progress == 0 and machine.status == "missing_power", "frost boss pulse should null nearby machines")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(54)
    sim.player.y = 5
    local boss = sim:addEntity("rift_signal_tyrant", 0, 0, 0)
    expect(boss.hp == 24 and sim:isBossKind(boss.kind), "rift boss stats missing")
    sim.tick = 90
    sim:updateEntities()
    local stalkers = 0
    for _, entity in ipairs(sim.entities) do
        if entity.kind == "rift_stalker" then
            stalkers = stalkers + 1
        end
    end
    expect(stalkers == 1, "rift boss should spawn stalker before outpost coverage")
    sim.productionTotals.outposts_activated = 5
    sim.tick = 180
    sim:updateEntities()
    local afterCoverage = 0
    for _, entity in ipairs(sim.entities) do
        if entity.kind == "rift_stalker" then
            afterCoverage = afterCoverage + 1
        end
    end
    expect(afterCoverage == stalkers, "rift boss should stop stalker phase after outpost coverage")
end

tests[#tests + 1] = function()
    local function satisfyBossExam(sim, kind)
        if kind == "marsh_broodheart" then
            sim.productionTotals.water_barrel = 3
        elseif kind == "glass_maw" then
            sim:addItem("sand_glass", 3)
        elseif kind == "badlands_warden" then
            sim.productionTotals.powered_ore = 8
        elseif kind == "frost_nullifier" then
            sim.productionTotals.logistic_deliveries = 3
        elseif kind == "rift_signal_tyrant" then
            sim.productionTotals.archive_signals = 1
            sim.productionTotals.rift_jumps = 1
            sim.productionTotals.outposts_activated = 3
        end
    end
    local cases = {
        { 0, 18, "marsh_hive", "marsh_broodheart" },
        { 18, -2, "glass_spire", "glass_maw" },
        { 36, 20, "badlands_foundry", "badlands_warden" },
        { -18, 0, "frost_vault", "frost_nullifier" },
        { -36, 20, "crystal_vault", "rift_signal_tyrant" },
    }
    for _, case in ipairs(cases) do
        local sim = Simulation.new(55)
        satisfyBossExam(sim, case[4])
        addItems(sim, bossCosts[case[4]])
        expect(sim:trySummonBossAt(case[1], case[2], 0), "boss summon should pass at lair " .. case[3])
        expect(#sim.entities == 1 and sim.entities[1].kind == case[4], "boss summon kind mismatch " .. case[4])
        expect(sim.world:lairAt(sim.entities[1].x, sim.entities[1].y, 0) == case[3], "boss should spawn inside matching lair")
    end
    local blocked = Simulation.new(55)
    expect(not blocked:trySummonBossAt(0, 0, 0), "boss summon should reject non-lair location")
end

tests[#tests + 1] = function()
    local marsh = Simulation.new(56)
    expect(not marsh:trySummonBossAt(0, 18, 0), "marsh boss should require water-barrel exam")
    marsh.productionTotals.water_barrel = 3
    addItems(marsh, bossCosts.marsh_broodheart)
    expect(marsh:trySummonBossAt(0, 18, 0), "marsh boss exam should unlock summon")
    local glass = Simulation.new(57)
    expect(not glass:trySummonBossAt(18, -2, 0), "glass boss should require sand-glass exam")
    addItems(glass, bossCosts.glass_maw)
    expect(glass:trySummonBossAt(18, -2, 0), "glass boss exam should unlock summon")
    local badlands = Simulation.new(58)
    expect(not badlands:trySummonBossAt(36, 20, 0), "badlands boss should require powered-ore exam")
    badlands.productionTotals.powered_ore = 8
    addItems(badlands, bossCosts.badlands_warden)
    expect(badlands:trySummonBossAt(36, 20, 0), "badlands boss exam should unlock summon")
    local frost = Simulation.new(59)
    expect(not frost:trySummonBossAt(-18, 0, 0), "frost boss should require logistics exam")
    frost.productionTotals.logistic_deliveries = 3
    addItems(frost, bossCosts.frost_nullifier)
    expect(frost:trySummonBossAt(-18, 0, 0), "frost boss exam should unlock summon")
    expect(#frost:bossExamProgress() == 5, "boss exam progress should expose all exams")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(60)
    sim.productionTotals.water_barrel = 3
    expect(not sim:trySummonBossAt(0, 18, 0), "boss summon should require item costs")
    addItems(sim, bossCosts.marsh_broodheart)
    expect(sim:trySummonBossAt(0, 18, 0), "boss summon should accept exact item costs")
    expect(sim:itemCount("water_barrel") == 0, "boss summon should consume water cost")
    expect(sim:itemCount("reed_fiber") == 0, "boss summon should consume biome material cost")
    expect(sim:itemCount("science_pack") == 0, "boss summon should consume science cost")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(61)
    addItems(sim, bossCosts.rift_signal_tyrant)
    expect(not sim:trySummonBossAt(-36, 20, 0), "rift boss should require archive and rift progress")
    sim.productionTotals.archive_signals = 1
    sim.productionTotals.rift_jumps = 1
    sim.productionTotals.outposts_activated = 2
    expect(not sim:trySummonBossAt(-36, 20, 0), "rift boss should require three outpost activations")
    sim.productionTotals.outposts_activated = 3
    expect(sim:trySummonBossAt(-36, 20, 0), "rift boss archive/rift gate should unlock summon")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(62)
    local drops = {
        { "marsh_broodheart", "marsh_heart" },
        { "glass_maw", "glass_heart" },
        { "badlands_warden", "warden_core" },
        { "frost_nullifier", "frost_core" },
        { "rift_signal_tyrant", "rift_crown" },
    }
    for index, drop in ipairs(drops) do
        local boss = sim:addEntity(drop[1], index, 0, 0, 1)
        sim:damageEntity(boss, 1)
        expect(sim:itemCount(drop[2]) == 1, "boss should drop relic " .. drop[2])
    end
    expect(#sim.entities == 0, "defeated bosses should be removed")
    expect(sim.productionTotals.boss_relics_claimed == 5, "boss relic counter should track drops")
    local loaded = assert(Save.fromText(Save.toText(sim)))
    expect(loaded:itemCount("rift_crown") == 1 and loaded.productionTotals.boss_relics_claimed == 5, "boss relic drops should persist")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(63)
    local unlocks = {
        { "marsh_broodheart", "repair_pylon" },
        { "glass_maw", "pressure_relay" },
        { "badlands_warden", "guard_tower" },
        { "frost_nullifier", "arc_tower" },
        { "rift_signal_tyrant", "outpost_beacon" },
    }
    for _, unlock in ipairs(unlocks) do
        sim.unlockedRecipes[unlock[2]] = false
        local boss = sim:addEntity(unlock[1], 0, 0, 0, 1)
        sim:damageEntity(boss, 1)
        expect(sim:isRecipeUnlocked(unlock[2]), "boss should unlock support recipe " .. unlock[2])
    end
    local loaded = assert(Save.fromText(Save.toText(sim)))
    expect(loaded:isRecipeUnlocked("arc_tower") and loaded:isRecipeUnlocked("outpost_beacon"), "support unlocks should persist")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(64)
    local pylon = sim:addMachine("repair_pylon", 0, 0, "south")
    local relay = sim:addMachine("pressure_relay", 1, 0, "south")
    sim:addItem("marsh_heart", 1)
    sim:addItem("glass_heart", 1)
    expect(not sim:socketRelic(pylon.id, "glass_heart"), "socketing should reject wrong relic")
    expect(sim:socketRelic(pylon.id, "marsh_heart"), "socketing should accept matching relic")
    expect(sim:itemCount("marsh_heart") == 0 and pylon.socketedRelic == "marsh_heart", "socketing should consume and attach relic")
    sim:queue(Simulation.commands.socketRelic(relay.id, "glass_heart"))
    sim:step()
    expect(relay.socketedRelic == "glass_heart", "socket relic command should attach relic")
    local loaded = assert(Save.fromText(Save.toText(sim)))
    expect(loaded:machineById(pylon.id).socketedRelic == "marsh_heart", "socketed relic should persist")
    expect(loaded:machineById(relay.id).socketedRelic == "glass_heart", "second socketed relic should persist")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(7)
    sim:queue(Simulation.commands.face("west"))
    sim:queue(Simulation.commands.mine("west"))
    sim:step()
    expect(sim:itemCount("wood") == 1, "mining tree should add wood")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(9)
    sim:addItem("wood", 20)
    sim:addItem("stone", 20)
    expect(sim:craft("workbench"), "workbench craft failed")
    sim:queue(Simulation.commands.place("south", "workbench", "south"))
    sim:step()
    expect(sim:machineAt(0, 1, 0).kind == "workbench", "workbench not placed")
    expect(sim:craft("furnace"), "workbench-gated furnace craft failed")
    sim:addItem("scrap", 5)
    expect(sim:craft("salvage_iron_plate"), "scrap iron salvage craft failed")
    expect(sim:craft("salvage_copper_plate"), "scrap copper salvage craft failed")
    expect(sim.productionTotals.scrap_recycled == 5, "scrap salvage should count recycled scrap")
    local loaded = assert(Save.fromText(Save.toText(sim)))
    expect(loaded.productionTotals.scrap_recycled == 5, "scrap recycled counter should persist")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(11)
    sim.world:setTile(0, 0, 0, { id = "iron_ore", data = 20 })
    local miner = sim:addMachine("burner_miner", 0, 0, "east")
    miner.inventory:add("coal", 10)
    sim:addMachine("belt", 1, 0, "east")
    sim:addMachine("inserter", 2, 0, "east")
    local furnace = sim:addMachine("furnace", 3, 0, "east")
    furnace.inventory:add("coal", 10)
    sim:addMachine("inserter", 4, 0, "east")
    local chest = sim:addMachine("chest", 5, 0, "south")
    runSteps(sim, 240)
    expect(chest.inventory:count("iron_plate") > 0, "starter line did not produce iron plate")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(12)
    local lab = sim:addMachine("lab", 0, 0, "south")
    lab.inventory:add("science_pack", 3)
    runSteps(sim, 80)
    expect(sim:isTechCompleted("logistics_1"), "lab did not complete logistics_1")
    expect(sim:isRecipeUnlocked("fast_belt"), "research did not unlock fast_belt")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(13)
    sim:addItem("wood", 3)
    sim:addMachine("chest", 2, 0, "south").inventory:add("stone", 5)
    sim:queue(Simulation.commands.assignHotbar(3, "wood"))
    sim:queue(Simulation.commands.assignHotbar(1, nil))
    runSteps(sim, 3)
    local loaded = assert(Save.fromText(Save.toText(sim)))
    expect(sameSnapshot(sim, loaded), "save/load snapshot mismatch")
    expect(loaded.player.hotbar[3] == "wood", "assigned hotbar slot did not persist")
    expect(loaded.player.hotbar[1] == nil, "cleared hotbar slot did not persist")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(95)
    expect(not sim:isPlanningMode() and sim:gameModeText() == "mode: survival", "simulation should start in survival mode")
    sim:queue(Simulation.commands.togglePlanningMode())
    sim:step()
    expect(sim:isPlanningMode() and sim:gameModeText() == "mode: planning", "planning toggle should enter planning mode")
    local loaded = assert(Save.fromText(Save.toText(sim)))
    expect(loaded:isPlanningMode(), "planning mode should persist")
    loaded:queue(Simulation.commands.togglePlanningMode())
    loaded:step()
    expect(not loaded:isPlanningMode() and loaded:gameModeText() == "mode: survival", "planning toggle should return to survival")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(96)
    sim:queue(Simulation.commands.placeGhost("east", "workbench", "south"))
    sim:step()
    expect(#sim.ghostBuilds == 1, "place ghost command should create ghost build")
    local ghost = sim.ghostBuilds[1]
    expect(ghost.id == 1 and ghost.item == "workbench" and ghost.machine, "machine ghost should record item and type")
    expect(ghost.x == 1 and ghost.y == 0 and ghost.z == 0 and ghost.direction == "south", "machine ghost should record target cell")
    expect(not sim:machineAt(1, 0, 0), "ghost build should not place a machine immediately")
    expect(not sim:placeGhost("east", "chest", "south"), "duplicate ghost target should be rejected")
    local loaded = assert(Save.fromText(Save.toText(sim)))
    expect(#loaded.ghostBuilds == 1 and loaded.nextGhostId == 2, "ghost builds should persist")
    loaded:queue(Simulation.commands.placeGhost("south", "wall", "south"))
    loaded:step()
    expect(#loaded.ghostBuilds == 2 and loaded.ghostBuilds[2].tile == "wall", "tile ghost should record target tile")
    loaded:queue(Simulation.commands.cancelGhost("south"))
    loaded:step()
    expect(#loaded.ghostBuilds == 1 and loaded.ghostBuilds[1].item == "workbench", "cancel ghost should remove target ghost")
    expect(not loaded:cancelGhost("west"), "cancel ghost should reject empty target")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(97)
    sim:addMachine("chest", 1, 0, "south")
    expect(sim:placeGhost("east", "workbench", "south"), "ghost over machine should still be recorded")
    expect(sim.ghostBuilds[1].blockedReason == "machine", "ghost over machine should label machine blockage")
    sim.world:setTile(0, -1, 0, { id = "water", data = 0 })
    expect(sim:placeGhost("north", "wall", "north"), "ghost over terrain should still be recorded")
    expect(sim.ghostBuilds[2].blockedReason == "terrain", "ghost over bad terrain should label terrain blockage")
    local loaded = assert(Save.fromText(Save.toText(sim)))
    expect(loaded.ghostBuilds[1].blockedReason == "machine" and loaded.ghostBuilds[2].blockedReason == "terrain", "ghost blocked reasons should persist")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(98)
    sim:addItem("workbench", 1)
    sim:addItem("scrap", 3)
    sim:togglePlanningMode()
    sim:queue(Simulation.commands.place("east", "workbench", "south"))
    sim:step()
    expect(sim:machineAt(1, 0, 0).kind == "workbench", "planning placement should still place machine")
    expect(sim:itemCount("workbench") == 1, "planning placement should not consume machine item")
    expect(sim:craft("salvage_iron_plate"), "planning craft should allow unlocked recipe")
    expect(sim:itemCount("scrap") == 3, "planning craft should not consume recipe inputs")
    expect((sim.productionTotals.scrap_recycled or 0) == 0, "planning craft should not count recycled scrap")
end

tests[#tests + 1] = function()
    local frames = {
        { tick = 0, command = Simulation.commands.face("west") },
        { tick = 0, command = Simulation.commands.mine("west") },
        { tick = 1, command = Simulation.commands.move("east") },
    }
    local direct = Simulation.new(14)
    direct:queue(frames[1].command)
    direct:queue(frames[2].command)
    direct:step()
    direct:queue(frames[3].command)
    direct:step()
    while direct.tick < 5 do
        direct:step()
    end
    local replayed = Replay.run(14, frames, 5)
    expect(sameSnapshot(direct, replayed), "replay result mismatch")
    local doc = assert(Replay.fromText(Replay.toText(14, frames, 5)))
    expect(doc.finalTick == 5 and #doc.frames == 3, "replay serialization failed")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(15)
    local chest = sim:addMachine("chest", 0, 0, "south")
    sim:addItem("wood", 8)
    sim:queue(Simulation.commands.depositMachine(chest.id, "wood", 5))
    sim:step()
    expect(chest.inventory:count("wood") == 5, "panel deposit failed")
    expect(sim:itemCount("wood") == 3, "panel deposit did not consume player items")
    sim:queue(Simulation.commands.withdrawMachine(chest.id, "wood", "all"))
    sim:step()
    expect(chest.inventory:count("wood") == 0, "panel withdraw failed")
    expect(sim:itemCount("wood") == 8, "panel withdraw did not return items")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(16)
    local furnace = sim:addMachine("furnace", 0, 0, "south")
    local blocked = sim:addMachine("furnace", 1, 0, "south")
    blocked.inventory:add("coal", 1)
    furnace.inventory:add("coal", 1)
    furnace.inventory:add("copper_ore", 1)
    sim:queue(Simulation.commands.setMachineRecipe(furnace.id, "copper_plate"))
    sim:queue(Simulation.commands.setMachineRecipe(blocked.id, "copper_plate"))
    sim:step()
    runSteps(sim, 60)
    expect(furnace.inventory:count("copper_plate") == 1, "furnace recipe selector did not smelt copper")
    expect(blocked.inventory:count("coal") == 1, "furnace consumed fuel without selected ore")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(17)
    local function expectNext(text)
        expect(sim:nextStepText() == text, "next step should show: " .. text)
    end
    expectNext("Mine west trees for workbench wood")
    sim:addItem("wood", 6)
    expectNext("Mine southern stone for furnace and belts")
    sim:addItem("stone", 8)
    sim:addMachine("workbench", 0, 1, "south")
    expectNext("Craft and place a burner miner on ore")
    sim:addMachine("burner_miner", 0, 0, "east")
    expectNext("Fuel miner and furnace, then route ore into smelting")
    sim.productionTotals.iron_plate = 1
    expectNext("Craft and place an assembler near plate supply")
    sim:addMachine("assembler", 1, 0, "east")
    expectNext("Craft and place a lab")
    sim:addMachine("lab", 2, 0, "south")
    expectNext("Feed iron and copper plates into an assembler for science")
    sim.productionTotals.science_pack = 1
    expectNext("Move science packs into a lab for Logistics 1")
    sim.completedTechs.logistics_1 = true
    expectNext("Craft a chest for plate output")
    local checklist = sim:objectiveChecklist()
    expect(checklist[1].title == "First" and checklist[2].title == "Science" and checklist[4].title == "Supply", "objective checklist groups missing")
    expect(#sim:tutorialProgress() == 5, "tutorial checklist should expose onboarding steps")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(18)
    local splitter = sim:addMachine("splitter", 0, 0, "east")
    local left = sim:addMachine("chest", 0, -1, "south")
    local right = sim:addMachine("chest", 0, 1, "south")
    expect(sim:acceptItem(splitter, "iron_ore"), "splitter should accept first item")
    sim:step()
    expect(left.inventory:count("iron_ore") == 1, "splitter did not send first item left")
    expect(sim:acceptItem(splitter, "copper_ore"), "splitter should accept second item")
    sim:step()
    expect(right.inventory:count("copper_ore") == 1, "splitter did not alternate right")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(19)
    local source = sim:addMachine("chest", -1, 0, "south")
    local inserter = sim:addMachine("circuit_inserter", 0, 0, "east")
    local target = sim:addMachine("chest", 1, 0, "south")
    source.inventory:add("iron_ore", 5)
    source.inventory:add("copper_ore", 5)
    sim:queue(Simulation.commands.configureCircuit(inserter.id, "iron_ore", "less_than", 2))
    runSteps(sim, 90)
    expect(target.inventory:count("iron_ore") == 2, "circuit inserter ignored less-than threshold")
    expect(target.inventory:count("copper_ore") == 0, "circuit inserter ignored item filter")
    expect(source.inventory:count("iron_ore") == 3, "circuit inserter moved too many filtered items")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(20)
    local provider = sim:addMachine("provider_chest", 0, 0, "south")
    local requester = sim:addMachine("requester_chest", 1, 0, "south")
    expect(sim:acceptItem(provider, "wood"), "provider chest should accept items")
    expect(sim:extractItem(provider) == "wood", "provider chest should expose stored items")
    expect(sim:acceptItem(requester, "stone"), "requester chest should accept items")
    expect(sim:extractItem(requester) == "stone", "requester chest should expose stored items")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(21)
    local port = sim:addMachine("logistic_port", 0, 0, "south")
    expect(sim:acceptItem(port, "logistic_drone"), "logistic port should accept drones")
    expect(not sim:acceptItem(port, "wood"), "logistic port should reject non-drone items")
    expect(port.inventory:count("logistic_drone") == 1, "logistic port did not retain drone")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(22)
    local stop = sim:addMachine("train_stop", 0, 0, "south")
    expect(sim:acceptItem(stop, "iron_plate"), "train stop should accept freight")
    expect(sim:extractItem(stop) == "iron_plate", "train stop should expose freight")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(23)
    sim.world:setTile(0, -1, 0, { id = "water", data = 0 })
    sim:addMachine("offshore_pump", 0, 0, "east")
    sim:addMachine("pipe", 1, 0, "east")
    local chest = sim:addMachine("chest", 2, 0, "south")
    runSteps(sim, 40)
    expect(chest.inventory:count("water_barrel") == 1, "pump and pipe did not move water barrel")
    expect(sim.productionTotals.water_barrel == 1, "water barrel production was not counted")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(24)
    sim.world:setTile(6, 0, 0, { id = "iron_ore", data = 10 })
    local generator = sim:addMachine("generator", 0, 0, "east")
    generator.inventory:add("coal", 1)
    sim:addMachine("power_pole", 1, 0, "south")
    sim:addMachine("power_pole", 5, 0, "south")
    local miner = sim:addMachine("electric_miner", 6, 0, "east")
    local chest = sim:addMachine("chest", 7, 0, "south")
    runSteps(sim, 10)
    expect(sim:isMachinePowered(miner.id), "electric miner was not powered through pole chain")
    expect(chest.inventory:count("iron_ore") == 1, "powered electric miner did not output ore")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(25)
    local generator = sim:addMachine("generator", 0, 1, "east")
    generator.inventory:add("coal", 1)
    sim:addMachine("power_pole", 0, 0, "south")
    local miners = {
        sim:addMachine("electric_miner", 1, 0, "east"),
        sim:addMachine("electric_miner", -1, 0, "east"),
        sim:addMachine("electric_miner", 0, -1, "east"),
    }
    for index, miner in ipairs(miners) do
        sim.world:setTile(miner.x, miner.y, 0, { id = "iron_ore", data = 10 + index })
    end
    runSteps(sim, 2)
    for _, miner in ipairs(miners) do
        expect(not sim:isMachinePowered(miner.id), "under-supplied network powered a consumer")
        expect(miner.status == "missing_power", "under-supplied electric miner did not stop")
    end
end

tests[#tests + 1] = function()
    local sim = Simulation.new(26)
    local chest = sim:addMachine("chest", 4, -2, "south")
    expect(sim:machineAt(4, -2, 0) == chest, "machineByCell index missed placed machine")
    expect(sim:machineById(chest.id) == chest, "machineById index missed placed machine")
    expect(sim.machineIdsByKind.chest[1] == chest.id, "machine kind index missed placed machine")
    local loaded = assert(Save.fromText(Save.toText(sim)))
    expect(loaded:machineAt(4, -2, 0).kind == "chest", "machineByCell index did not rebuild on load")
    expect(loaded:machineById(chest.id).kind == "chest", "machineById index did not rebuild on load")
    expect(loaded.machineIdsByKind.chest[1] == chest.id, "machine kind index did not rebuild on load")
    expect(loaded:removeMachineById(chest.id), "machine removal failed")
    expect(loaded:machineAt(4, -2, 0) == nil, "machineByCell index did not clear removed machine")
    expect(loaded:machineById(chest.id) == nil, "machineById index did not clear removed machine")
    expect(not loaded.machineIdsByKind.chest, "machine kind index did not clear removed machine")
end

local function addPoweredPortLine(sim)
    local generator = sim:addMachine("generator", 0, 0, "east")
    generator.inventory:add("coal", 5)
    sim:addMachine("power_pole", 1, 0, "south")
    local port = sim:addMachine("logistic_port", 2, 0, "south")
    port.inventory:add("logistic_drone", 1)
    return port
end

tests[#tests + 1] = function()
    local sim = Simulation.new(99)
    addPoweredPortLine(sim)
    sim.world:setTile(0, 1, 0, { id = "grass", data = 0 })
    sim:togglePlanningMode()
    sim:queue(Simulation.commands.placeGhost("south", "chest", "south"))
    sim:step()
    expect(#sim.constructionJobs == 1, "powered port drone should start construction job")
    expect(sim.constructionJobs[1].ghostId == sim.ghostBuilds[1].id, "construction job should target ghost")
    expect(sim.ghostBuilds[1].progress > 0, "construction job should mark ghost progress")
    local loaded = assert(Save.fromText(Save.toText(sim)))
    expect(#loaded.constructionJobs == 1 and loaded.constructionJobs[1].item == "chest", "construction job should persist")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(100)
    addPoweredPortLine(sim)
    sim.world:setTile(0, 1, 0, { id = "grass", data = 0 })
    local provider = sim:addMachine("provider_chest", 3, 0, "south")
    provider.inventory:add("chest", 1)
    sim:queue(Simulation.commands.placeGhost("south", "chest", "south"))
    sim:step()
    expect(#sim.constructionJobs == 1, "provider stock should allow survival construction job")
    expect(sim.constructionJobs[1].sourceId == provider.id, "construction job should record provider source")
    expect(provider.inventory:count("chest") == 0, "construction job should consume provider material")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(101)
    sim.world:setTile(0, 1, 0, { id = "grass", data = 0 })
    local port = sim:addMachine("logistic_port", 2, 0, "south")
    port.inventory:add("logistic_drone", 1)
    local provider = sim:addMachine("provider_chest", 3, 0, "south")
    provider.inventory:add("chest", 1)
    sim:queue(Simulation.commands.placeGhost("south", "chest", "south"))
    sim:step()
    expect(#sim.constructionJobs == 0, "unpowered port should not start construction job")
    expect(provider.inventory:count("chest") == 1, "unpowered port should not consume construction material")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(102)
    addPoweredPortLine(sim)
    sim.world:setTile(0, 1, 0, { id = "grass", data = 0 })
    sim:togglePlanningMode()
    sim:queue(Simulation.commands.placeGhost("south", "chest", "south"))
    sim:step()
    sim:step()
    expect(#sim.constructionJobs == 0, "completed construction job should clear")
    expect(sim.ghostBuilds[1].fulfilled and sim.ghostBuilds[1].progress == 100, "completed construction job should fulfill ghost")
    expect(sim:machineAt(0, 1, 0).kind == "chest", "completed machine ghost should place machine")
    local loaded = assert(Save.fromText(Save.toText(sim)))
    expect(loaded.ghostBuilds[1].fulfilled and loaded:machineAt(0, 1, 0).kind == "chest", "fulfilled ghost state should persist")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(103)
    addPoweredPortLine(sim)
    local firstRequester = sim:addMachine("requester_chest", 0, 0, "south")
    local secondRequester = sim:addMachine("requester_chest", 1, 0, "south")
    sim.logisticJobs = {
        { id = 2, toId = secondRequester.id, item = "stone", count = 1, remaining = 2 },
        { id = 1, toId = firstRequester.id, item = "wood", count = 1, remaining = 2 },
    }
    sim.ghostBuilds = {
        { id = 2, item = "chest", machine = true, x = 4, y = 0, z = 0, direction = "south", fulfilled = false, progress = 0 },
        { id = 1, item = "chest", machine = true, x = 5, y = 0, z = 0, direction = "south", fulfilled = false, progress = 0 },
    }
    sim.constructionJobs = {
        { ghostId = 2, portId = 0, sourceId = 0, item = "chest", remaining = 2, total = 2 },
        { ghostId = 1, portId = 0, sourceId = 0, item = "chest", remaining = 2, total = 2 },
    }
    sim:step()
    expect(sim.logisticJobs[1].id == 1 and sim.logisticJobs[2].id == 2, "logistic jobs should tick in id order")
    expect(sim.constructionJobs[1].ghostId == 1 and sim.constructionJobs[2].ghostId == 2, "construction jobs should tick in ghost id order")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(27)
    addPoweredPortLine(sim)
    local provider = sim:addMachine("provider_chest", 3, 0, "south")
    local requester = sim:addMachine("requester_chest", 4, 0, "south")
    provider.inventory:add("wood", 3)
    sim:queue(Simulation.commands.configureRequest(requester.id, "wood", 2))
    runSteps(sim, 30)
    expect(requester.inventory:count("wood") == 2, "logistic delivery did not satisfy requester threshold")
    expect(provider.inventory:count("wood") == 1, "logistic delivery consumed wrong provider count")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(28)
    addPoweredPortLine(sim)
    local provider = sim:addMachine("provider_chest", 3, 0, "south")
    local requester = sim:addMachine("requester_chest", 4, 0, "south")
    provider.inventory:add("stone", 1)
    sim:queue(Simulation.commands.configureRequest(requester.id, "stone", 1))
    runSteps(sim, 2)
    expect(#sim.logisticJobs == 1, "logistic job was not in flight before save")
    local loaded = assert(Save.fromText(Save.toText(sim)))
    runSteps(loaded, 15)
    expect(loaded:machineById(requester.id).inventory:count("stone") == 1, "in-flight logistic job did not persist")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(29)
    local port = sim:addMachine("logistic_port", 0, 0, "south")
    port.inventory:add("logistic_drone", 1)
    local provider = sim:addMachine("provider_chest", 1, 0, "south")
    local requester = sim:addMachine("requester_chest", 2, 0, "south")
    provider.inventory:add("wood", 1)
    sim:queue(Simulation.commands.configureRequest(requester.id, "wood", 1))
    runSteps(sim, 30)
    expect(requester.inventory:count("wood") == 0, "unpowered logistic port delivered item")
    expect(provider.inventory:count("wood") == 1, "unpowered logistic port consumed provider item")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(30)
    local first = sim:addMachine("train_stop", 0, 0, "south")
    local second = sim:addMachine("train_stop", 5, 0, "south")
    first.inventory:add("iron_plate", 1)
    runSteps(sim, 95)
    expect(first.inventory:count("iron_plate") == 0, "train stop did not consume source cargo")
    expect(second.inventory:count("iron_plate") == 1, "train stop did not receive cargo")
    expect(sim.productionTotals.train_deliveries == 1, "train delivery counter did not increment")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(31)
    sim:addItem("iron_plate", 3)
    sim:queue(Simulation.commands.submitSupplyContract("iron_supply"))
    sim:step()
    local contract = sim:supplyContract("iron_supply")
    expect(contract.delivered == 3, "supply contract did not accept partial delivery")
    expect(not contract.complete, "partial supply contract should stay incomplete")
    expect(sim:itemCount("iron_plate") == 0, "supply contract did not consume player items")
    sim:addItem("iron_plate", 2)
    sim:queue(Simulation.commands.submitSupplyContract("iron_supply"))
    sim:step()
    expect(contract.delivered == 5 and contract.complete, "supply contract did not complete at target")
    sim:addItem("iron_plate", 1)
    expect(not sim:submitSupplyContract("iron_supply"), "completed supply contract accepted extra delivery")
    expect(sim:itemCount("iron_plate") == 1, "completed supply contract consumed extra item")
    local loaded = assert(Save.fromText(Save.toText(sim)))
    local loadedContract = loaded:supplyContract("iron_supply")
    expect(loadedContract.delivered == 5 and loadedContract.complete, "supply contract state did not persist")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(32)
    expect(sim:totalSupplyContracts() == 3, "supply contract count should be explicit")
    expect(sim:completedSupplyContracts() == 0, "fresh simulation should have no completed contracts")
    expect(sim:currentSupplyContractText():find("Iron Plate") ~= nil, "first contract should ask for iron plates")
    sim:addItem("iron_plate", 5)
    sim:addItem("science_pack", 3)
    sim:addItem("logistic_drone", 1)
    for _, contractId in ipairs({ "iron_supply", "science_supply", "drone_supply" }) do
        sim:queue(Simulation.commands.submitSupplyContract(contractId))
        sim:step()
    end
    expect(sim:completedSupplyContracts() == sim:totalSupplyContracts(), "all submitted contracts should complete")
    expect(sim:currentSupplyContractText():find("contract complete") ~= nil, "completed contract text should show completion")
    expect(not sim:mainObjectiveComplete(), "main objective should wait for final tech")
    sim.completedTechs.logistics_1 = true
    sim.completedTechs.automation_control = true
    sim.completedTechs.logistic_network = true
    sim.activeTech = nil
    expect(sim:mainObjectiveComplete(), "completed contracts and tech should complete the main objective")
    expect(sim:nextStepText():find("Main objective complete") == 1, "next step should surface objective completion")
    local loaded = assert(Save.fromText(Save.toText(sim)))
    expect(loaded:mainObjectiveComplete(), "main objective completion did not survive save/load")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(33)
    local rates = sim:productionRatePanels()
    expect(#rates == 5, "production rate panels should expose tracked outputs")
    expect(rates[1].key == "iron_plate" and rates[1].blocked, "iron rate target should start blocked")
    expect(sim:productionRateText():find("rates: Iron/min 0/3") == 1, "production rate text should surface first blocked target")
    sim.productionTotals.iron_plate = 4
    sim.productionTotals.copper_plate = 4
    sim.productionTotals.science_pack = 3
    sim.tick = 3600
    expect(not sim:productionRatePanels()[1].blocked, "met iron rate target should unblock")
    expect(sim:productionRateText() == "rates: tracked production meets current targets", "met rate targets should summarize stable production")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(104)
    local chest = sim:addMachine("chest", 0, 0, "south")
    chest.inventory:add("iron_plate", 50)
    sim.tick = 3600
    expect(sim:productionRatePanels()[1].currentPerMinute == 0, "production rates should not derive from inventory scans")
    sim.productionTotals.iron_plate = 4
    expect(sim:productionRatePanels()[1].currentPerMinute == 4, "production rates should use event counters")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(65)
    expect(sim:factoryPressureLevel() == 0, "empty factory pressure should be zero")
    sim.productionTotals.science_pack = 10
    expect(sim:factoryPressureLevel() == 120, "production pressure should include science output")
    sim:addMachine("lab", 0, 0, "south")
    sim:addMachine("assembler", 1, 0, "south")
    sim:addMachine("chest", 2, 0, "south")
    expect(sim:factoryFootprintPressure() == 14, "factory footprint pressure should weight machines")
    expect(sim:factoryPressureLevel() == 134, "factory pressure should combine production and footprint")
    sim.productionTotals.pressure_waves_repelled = 1
    expect(sim:factoryPressureLevel() == 99, "repelled waves should reduce pressure")
    expect(sim:factoryPressureText():find("pressure: watched") == 1, "pressure text should summarize pressure tier")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(66)
    sim.productionTotals.science_pack = 10
    sim:addMachine("lab", 0, 0, "south")
    sim:addMachine("assembler", 4, 0, "south")
    sim:addMachine("chest", 8, 0, "south")
    local hotspots = sim:pressureHotspots()
    expect(#hotspots == 3, "pressure hotspots should include weighted machines")
    expect(hotspots[1].x == 0 and hotspots[1].pressure >= hotspots[2].pressure, "pressure hotspots should sort strongest first")
    expect(sim:localPressureAt(0, 0, 0) > sim:localPressureAt(20, 20, 0), "local pressure should decay with distance")
    expect(sim:pressureMapText():find("pressure map: hotspot x0 y0") == 1, "pressure map text should surface top hotspot")
end

tests[#tests + 1] = function()
    local quiet = Simulation.new(67)
    expect(quiet:ticksUntilNextPressureWave() == -1, "quiet pressure should not schedule waves")
    expect(quiet:pressureWaveAlertText():find("wave alert: none") == 1, "quiet alert should report none")
    local sim = Simulation.new(67)
    sim.productionTotals.science_pack = 10
    sim.tick = 1
    expect(sim:ticksUntilNextPressureWave() == 299, "pressure wave timer should count down")
    expect(sim:pressureWaveAlertText():find("wave alert: next probe in 299 ticks") == 1, "wave alert should report probe countdown")
    sim.productionTotals.science_pack = 20
    sim.tick = 300
    expect(sim:ticksUntilNextPressureWave() == 0, "wave timer should hit zero on cadence")
    expect(sim:pressureWaveAlertText():find("wave alert: surge incoming now") == 1, "wave alert should report incoming surge")
end

tests[#tests + 1] = function()
    local a = Simulation.new(68)
    local b = Simulation.new(68)
    for _, sim in ipairs({ a, b }) do
        sim.productionTotals.science_pack = 10
        sim.tick = 300
        sim:addMachine("lab", 0, 0, "south")
        expect(sim:ensureFactoryPressureEntity(), "pressure wave should spawn hostile probe")
    end
    expect(#a.entities == 1 and a.entities[1].pressureSpawn, "pressure probe should mark pressure spawn")
    expect(a.entities[1].kind == "slime", "probe pressure should spawn slime")
    expect(a.entities[1].x == b.entities[1].x and a.entities[1].y == b.entities[1].y, "pressure probe spawn should be deterministic")
    local surge = Simulation.new(69)
    surge.productionTotals.science_pack = 20
    surge.tick = 300
    surge:addMachine("lab", 0, 0, "south")
    expect(surge:ensureFactoryPressureEntity(), "pressure surge should spawn hostiles")
    expect(#surge.entities == 2, "surge pressure should spawn two hostiles")
    local loaded = assert(Save.fromText(Save.toText(surge)))
    expect(loaded.entities[1].pressureSpawn, "pressure spawn marker should persist")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(70)
    sim.productionTotals.science_pack = 10
    for index = 1, 3 do
        local entity = sim:addEntity("slime", index, 0, 0, 1)
        entity.pressureSpawn = true
        sim:damageEntity(entity, 1)
    end
    expect(sim.productionTotals.pressure_enemies_defeated == 3, "pressure kills should be counted")
    expect(sim.productionTotals.scrap_recovered == 3 and sim:itemCount("scrap") == 3, "pressure kills should reward scrap")
    expect(sim.productionTotals.pressure_wave_rewards_claimed == 1, "pressure reward counter should increment")
    expect(sim:itemCount("science_pack") == 1, "pressure reward should grant science at probe pressure")
    local loaded = assert(Save.fromText(Save.toText(sim)))
    expect(loaded.productionTotals.pressure_wave_rewards_claimed == 1 and loaded:itemCount("scrap") == 3, "pressure rewards should persist")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(71)
    sim.player.x = 10
    sim.player.y = 10
    local generator = sim:addMachine("generator", 1, 0, "south")
    generator.inventory:add("coal", 10)
    sim:addMachine("power_pole", 0, 0, "south")
    local tower = sim:addMachine("guard_tower", 0, 1, "south")
    sim:addEntity("slime", 0, 3, 0, 1)
    runSteps(sim, 45)
    expect(#sim.entities == 0, "guard tower should target and kill hostile in range")
    expect(tower.status == "working" or tower.status == "idle", "guard tower should process targeting")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(72)
    sim.player.x = 10
    sim.player.y = 10
    local generator = sim:addMachine("generator", 1, 0, "south")
    generator.inventory:add("coal", 10)
    sim:addMachine("power_pole", 0, 0, "south")
    local tower = sim:addMachine("arc_tower", 0, 1, "south")
    sim:addEntity("rift_stalker", 0, 7, 0, 2)
    runSteps(sim, 30)
    expect(#sim.entities == 0, "arc tower should target and kill hostile in longer range")
    expect(tower.status == "working" or tower.status == "idle", "arc tower should process targeting")
end

tests[#tests + 1] = function()
    local guardSim = Simulation.new(73)
    guardSim.player.x = 10
    guardSim.player.y = 10
    local guardGenerator = guardSim:addMachine("generator", 1, 0, "south")
    guardGenerator.inventory:add("coal", 10)
    guardSim:addMachine("power_pole", 0, 0, "south")
    local guard = guardSim:addMachine("guard_tower", 0, 1, "south")
    expect(guardSim:acceptItem(guard, "copper_coil"), "guard tower should accept ammo")
    guardSim:addEntity("skeleton", 0, 3, 0, 4)
    runSteps(guardSim, 45)
    expect(#guardSim.entities == 0 and guard.inventory:count("copper_coil") == 0, "guard ammo should fire stronger shot and consume ammo")
    local arcSim = Simulation.new(74)
    arcSim.player.x = 10
    arcSim.player.y = 10
    local arcGenerator = arcSim:addMachine("generator", 1, 0, "south")
    arcGenerator.inventory:add("coal", 10)
    arcSim:addMachine("power_pole", 0, 0, "south")
    local arc = arcSim:addMachine("arc_tower", 0, 1, "south")
    expect(arcSim:acceptItem(arc, "rift_shell"), "arc tower should accept ammo")
    arcSim:addEntity("rift_stalker", 0, 7, 0, 5)
    runSteps(arcSim, 30)
    expect(#arcSim.entities == 0 and arc.inventory:count("rift_shell") == 0, "arc ammo should fire stronger shot and consume ammo")
end

tests[#tests + 1] = function()
    local machineSim = Simulation.new(75)
    machineSim.player.x = 10
    machineSim.player.y = 10
    local chest = machineSim:addMachine("chest", 1, 0, "south")
    chest.durability = 1
    machineSim:addEntity("slime", 0, 0, 0, 3)
    machineSim:updateEntities()
    expect(machineSim:machineAt(1, 0, 0) == nil, "hostile should damage adjacent machine structure")
    local wallSim = Simulation.new(76)
    wallSim.player.x = 10
    wallSim.player.y = 10
    wallSim.world:setTile(1, 0, 0, { id = "wall", data = 1 })
    wallSim:addEntity("slime", 0, 0, 0, 3)
    wallSim:updateEntities()
    expect(wallSim.world:getTile(1, 0, 0).id == "grass", "hostile should destroy adjacent wall tile")
end

tests[#tests + 1] = function()
    local function poweredPylonSim(seed)
        local sim = Simulation.new(seed)
        sim.player.x = 20
        sim.player.y = 20
        local generator = sim:addMachine("generator", 0, 0, "south")
        generator.inventory:add("coal", 80)
        sim:addMachine("power_pole", 1, 0, "south")
        local pylon = sim:addMachine("repair_pylon", 2, 0, "south")
        sim.world:setTile(2, -1, 0, { id = "wall", data = 0 })
        sim.world:setTile(3, 0, 0, { id = "floor", data = 0 })
        sim.world:setTile(2, 1, 0, { id = "wall", data = 0 })
        return sim, pylon
    end

    local gapSim, gapPylon = poweredPylonSim(77)
    gapPylon.inventory:add("wall", 1)
    runSteps(gapSim, 60)
    expect(gapSim.world:getTile(3, 0, 0).id == "wall", "repair pylon should rebuild adjacent wall gap")
    expect(gapPylon.inventory:count("wall") == 0, "wall gap repair should consume wall item")

    local wallSim, wallPylon = poweredPylonSim(78)
    wallPylon.inventory:add("wall", 1)
    wallSim.world:setTile(2, -1, 0, { id = "wall", data = 1 })
    runSteps(wallSim, 60)
    expect(wallSim.world:getTile(2, -1, 0).data > 1, "repair pylon should restore damaged wall durability")
    expect(wallSim.world:getTile(3, 0, 0).id == "floor", "repair pylon should prioritize damaged wall over wall gap")
    expect(wallPylon.inventory:count("wall") == 0, "wall repair should consume wall item")

    local machineSim, machinePylon = poweredPylonSim(79)
    local chest = machineSim:addMachine("chest", 3, 0, "south")
    chest.durability = 1
    machinePylon.inventory:add("iron_plate", 1)
    runSteps(machineSim, 60)
    expect(chest.durability > 1, "repair pylon should restore damaged machine durability")
    expect(machinePylon.inventory:count("iron_plate") == 0, "machine repair should consume iron plate")
end

tests[#tests + 1] = function()
    local function poweredRelaySim(seed)
        local sim = Simulation.new(seed)
        sim.player.x = 20
        sim.player.y = 20
        local generator = sim:addMachine("generator", 0, 0, "south")
        generator.inventory:add("coal", 140)
        sim:addMachine("power_pole", 1, 0, "south")
        local relay = sim:addMachine("pressure_relay", 2, 0, "south")
        relay.inventory:add("advanced_science_pack", 1)
        sim.productionTotals.science_pack = 10
        return sim, relay
    end

    local sim, relay = poweredRelaySim(80)
    expect(sim:factoryPressureLevel() >= 120, "pressure relay test should start above raid pressure")
    runSteps(sim, 120)
    expect(sim.productionTotals.pressure_waves_repelled == 1, "pressure relay cycle should increment pressure mitigation")
    expect(relay.inventory:count("advanced_science_pack") == 0, "pressure relay should consume advanced science input")
    expect(sim:factoryPressureLevel() < 120, "pressure relay mitigation should lower pressure below raid threshold")

    local glassSim, glassRelay = poweredRelaySim(81)
    glassRelay.socketedRelic = "glass_heart"
    runSteps(glassSim, 90)
    expect(glassSim.productionTotals.pressure_waves_repelled == 2, "Glass Heart should double pressure relay mitigation")

    local baseline = Simulation.new(82)
    local baselineGenerator = baseline:addMachine("generator", 0, 0, "south")
    baselineGenerator.inventory:add("coal", 1)
    baseline:addMachine("power_pole", 1, 0, "south")
    baseline.productionTotals.science_pack = 10
    local relaySim = poweredRelaySim(83)
    expect(relaySim:localPressureAt(0, 0, 0) < baseline:localPressureAt(0, 0, 0), "nearby relay should mitigate local pressure")
end

tests[#tests + 1] = function()
    local unpowered = Simulation.new(84)
    local unpoweredBeacon = unpowered:addMachine("outpost_beacon", 12, 0, "south")
    runSteps(unpowered, 1)
    expect(unpoweredBeacon.status == "missing_power", "outpost beacon should require power")
    expect((unpowered.productionTotals.outposts_activated or 0) == 0, "unpowered outpost should not activate")

    local sim = Simulation.new(85)
    sim.player.x = 20
    sim.player.y = 20
    local generator = sim:addMachine("generator", 10, 0, "south")
    generator.inventory:add("coal", 800)
    sim:addMachine("power_pole", 11, 0, "south")
    local beacon = sim:addMachine("outpost_beacon", 12, 0, "south")
    expect(sim.world:biomeAt(12, 0, 0) == "desert", "outpost test should be in desert biome")
    runSteps(sim, 1)
    expect(beacon.status == "missing_input", "powered outpost should require biome input")
    beacon.inventory:add("sand_glass", 1)
    runSteps(sim, 80)
    expect(beacon.progress == 80 and beacon.status == "idle", "powered outpost beacon should finish activation")
    expect(beacon.inventory:count("sand_glass") == 0, "desert outpost activation should consume sand glass")
    expect(sim.productionTotals.outposts_activated == 1, "outpost activation should increment production total")
    expect(sim:hasActivatedOutpostBiome("desert"), "outpost activation should track biome coverage")
    expect(sim:activatedOutpostBiomeCount() == 1 and #sim:activatedOutpostBiomes() == 1, "unique outpost biome coverage should be exposed")
    expect(sim:currentOutpostDeliveryText():find("desert") ~= nil, "outpost delivery guidance should target activated biome")
    beacon.inventory:add("sand_glass", 1)
    runSteps(sim, 100)
    expect(beacon.progress == 80 and beacon.inventory:count("sand_glass") == 0, "outpost delivery should consume biome input and reset")
    expect(sim.productionTotals.outpost_deliveries == 1, "outpost delivery should increment production total")
    expect(sim:hasCompletedOutpostDeliveryBiome("desert") and sim:outpostDeliveryBiomeCount() == 1, "outpost delivery should track biome")
    local route = sim:outpostRouteByBiome("desert")
    expect(route and route.deliveredInWindow == 1 and route.requiredPerWindow == 2, "outpost delivery should start sustained route window")
    for _ = 1, 5 do
        beacon.inventory:add("sand_glass", 1)
        runSteps(sim, 100)
    end
    expect(sim:stableOutpostRouteCount() == 1, "repeated outpost deliveries should stabilize one route")
    expect(sim:outpostRouteStability("desert") == 3, "desert route should reach max stability")
    expect(sim:outpostRouteText():find("stable") ~= nil, "outpost route text should summarize stability")
    local loaded = assert(Save.fromText(Save.toText(sim)))
    expect(loaded:machineById(beacon.id).progress == 80, "activated outpost should persist")
    expect(loaded:hasActivatedOutpostBiome("desert"), "outpost biome coverage should persist")
    expect(loaded.productionTotals.outpost_deliveries == 6 and loaded:stableOutpostRouteCount() == 1, "stable outpost route should persist")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(86)
    local generator = sim:addMachine("generator", 12, 1, "south")
    generator.inventory:add("coal", 3)
    sim:addMachine("power_pole", 13, 1, "south")
    local port = sim:addMachine("logistic_port", 14, 1, "south")
    port.inventory:add("logistic_drone", 1)
    port.inventory:add("science_pack", 1)
    expect(sim.world:biomeAt(14, 1, 0) == "desert", "scout test port should be in desert biome")
    sim:markActivatedOutpostBiome("desert")
    sim:outpostRouteForBiome("desert").stability = 3
    sim:step()
    expect(port.carriedItem == "cactus_fiber" and port.progress > 0, "local-biome scout should target desert first")
    expect(port.inventory:count("science_pack") == 0, "scout dispatch should consume science")
    expect(sim:scoutAutomationText():find("desert") ~= nil, "scout text should name local target")
    local loaded = assert(Save.fromText(Save.toText(sim)))
    expect(loaded:machineById(port.id).carriedItem == "cactus_fiber", "in-flight scout should persist")
    runSteps(loaded, 120)
    local loadedPort = loaded:machineById(port.id)
    expect(loadedPort.inventory:count("cactus_fiber") >= 5, "completed scout should return route-bonus biome material")
    expect(loadedPort.inventory:count("desert_fragment") == 1, "completed scout should return biome fragment")
    expect(loaded.productionTotals.scout_dispatches == 1, "scout dispatch total should increment")
    expect(loaded.productionTotals.scout_materials_recovered == 5, "scout material recovery should include route bonuses")
    expect(loaded:hasScoutedBiome("desert") and loaded:scoutedBiomeCount() == 1, "completed scout should mark biome")
end

tests[#tests + 1] = function()
    local locked = Simulation.new(93)
    expect(not locked:postVictoryExpeditionBoard()[1].unlocked, "post-victory board should start locked")
    expect(locked:postVictoryExpeditionText():find("locked") ~= nil, "locked post-victory board should explain gate")
    local sim = Simulation.new(94)
    for _, contract in ipairs(sim.supplyContracts) do
        contract.delivered = contract.target
        contract.complete = true
    end
    sim.completedTechs.logistic_network = true
    local board = sim:postVictoryExpeditionBoard()
    expect(#board == 9 and board[1].key == "cartography", "post-victory board should expose scouting entry")
    expect(board[2].key == "relic_set" and board[2].required == 5, "post-victory board should expose boss relic entry")
    expect(board[3].key == "storm_veteran" and board[3].required == 3, "post-victory board should expose rift storm entry")
    expect(board[4].key == "outpost_network" and board[4].required == 5, "post-victory board should expose outpost route entry")
    expect(board[5].key == "pressure_harvest" and board[5].required == 5, "post-victory board should expose pressure reward entry")
    expect(board[6].key == "lair_caches" and board[6].required == 5, "post-victory board should expose lair cache entry")
    expect(board[7].key == "rift_freight" and board[7].required == 20, "post-victory board should expose train freight entry")
    expect(board[8].key == "scrap_economy" and board[8].required == 10, "post-victory board should expose scrap recycling entry")
    expect(board[9].key == "powered_industry" and board[9].required == 50, "post-victory board should expose powered mining entry")
    expect(board[1].unlocked and not board[1].complete, "scouting entry should unlock incomplete after main objective")
    expect(sim:postVictoryExpeditionText():find("expedition 1/9") ~= nil, "post-victory text should show scouting progress")
    for _, biome in ipairs({ "marsh", "desert", "badlands", "snowfield", "crystal_field", "rift" }) do
        sim:markScoutedBiome(biome)
    end
    expect(sim:completedPostVictoryExpeditions() == 1, "completed scouting entry should count")
    expect(sim:postVictoryExpeditionText():find("five%-relic") ~= nil, "post-victory text should advance to boss relics")
    sim.productionTotals.boss_relics_claimed = 5
    expect(sim:completedPostVictoryExpeditions() == 2, "completed boss relic entry should count")
    expect(sim:postVictoryExpeditionText():find("rift storms") ~= nil, "post-victory text should advance to rift storms")
    sim.productionTotals.rift_storms_survived = 3
    expect(sim:completedPostVictoryExpeditions() == 3, "completed rift storm entry should count")
    expect(sim:postVictoryExpeditionText():find("outpost delivery routes") ~= nil, "post-victory text should advance to outpost routes")
    for _, biome in ipairs({ "marsh", "desert", "badlands", "snowfield", "crystal_field" }) do
        sim:outpostRouteForBiome(biome).stability = 3
    end
    expect(sim:completedPostVictoryExpeditions() == 4, "completed outpost route entry should count")
    expect(sim:postVictoryExpeditionText():find("pressure wave rewards") ~= nil, "post-victory text should advance to pressure rewards")
    sim.productionTotals.pressure_wave_rewards_claimed = 5
    expect(sim:completedPostVictoryExpeditions() == 5, "completed pressure reward entry should count")
    expect(sim:postVictoryExpeditionText():find("dungeon or lair caches") ~= nil, "post-victory text should advance to lair caches")
    sim.productionTotals.dungeon_chests_opened = 5
    expect(sim:completedPostVictoryExpeditions() == 6, "completed lair cache entry should count")
    expect(sim:postVictoryExpeditionText():find("remote freight") ~= nil, "post-victory text should advance to train freight")
    sim.productionTotals.train_deliveries = 20
    expect(sim:completedPostVictoryExpeditions() == 7, "completed train freight entry should count")
    expect(sim:postVictoryExpeditionText():find("Recycle ten scrap") ~= nil, "post-victory text should advance to scrap recycling")
    sim.productionTotals.scrap_recycled = 10
    expect(sim:completedPostVictoryExpeditions() == 8, "completed scrap recycling entry should count")
    expect(sim:postVictoryExpeditionText():find("electric miners") ~= nil, "post-victory text should advance to powered mining")
    sim.productionTotals.powered_ore = 50
    expect(sim:completedPostVictoryExpeditions() == 9, "completed powered mining entry should count")
    expect(sim:postVictoryExpeditionText():find("complete") ~= nil, "complete post-victory board should summarize completion")
    local loaded = assert(Save.fromText(Save.toText(sim)))
    expect(loaded:completedPostVictoryExpeditions() == 9, "post-victory expedition board should persist")
end

tests[#tests + 1] = function()
    local unpowered = Simulation.new(87)
    local unpoweredTerminal = unpowered:addMachine("archive_terminal", 1, 0, "south")
    runSteps(unpowered, 1)
    expect(unpoweredTerminal.status == "missing_power", "archive terminal should require power")
    local sim = Simulation.new(88)
    local generator = sim:addMachine("generator", 0, 1, "south")
    generator.inventory:add("coal", 4)
    sim:addMachine("power_pole", 1, 1, "south")
    local terminal = sim:addMachine("archive_terminal", 1, 0, "south")
    runSteps(sim, 1)
    expect(terminal.status == "missing_input", "powered archive terminal should require beacon core")
    terminal.inventory:add("beacon_core", 1)
    runSteps(sim, 360)
    expect(sim.productionTotals.archive_signals == 1, "powered archive terminal should charge one signal")
    expect(terminal.inventory:count("beacon_core") == 0, "archive terminal should consume beacon core")
    expect(terminal.progress == 0 and terminal.status == "idle", "charged archive terminal should reset progress")
    local loaded = assert(Save.fromText(Save.toText(sim)))
    expect(loaded.productionTotals.archive_signals == 1, "archive signal should persist")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(89)
    local generator = sim:addMachine("generator", 0, 1, "south")
    generator.inventory:add("coal", 1)
    sim:addMachine("power_pole", 1, 1, "south")
    local terminal = sim:addMachine("archive_terminal", 1, 0, "south")
    terminal.inventory:add("desert_fragment", 1)
    terminal.inventory:add("science_pack", 1)
    expect(not sim:isRecipeUnlocked("dry_copper_plate"), "archive alternate should start locked")
    local choices = sim:archiveChoices(terminal.id)
    expect(#choices == 5 and choices[2].recipeKey == "dry_copper_plate" and choices[2].available, "archive choices should expose available alternates")
    sim:queue(Simulation.commands.selectArchiveChoice(terminal.id, 1))
    sim:step()
    expect(sim:isRecipeUnlocked("dry_copper_plate"), "archive fragment should unlock alternate recipe")
    expect(terminal.inventory:count("desert_fragment") == 0 and terminal.inventory:count("science_pack") == 0, "archive unlock should consume fragment and science")
    expect(terminal.progress == 0 and terminal.status == "idle", "archive unlock should not start beacon charge")
    local loaded = assert(Save.fromText(Save.toText(sim)))
    expect(loaded:isRecipeUnlocked("dry_copper_plate"), "archive recipe unlock should persist")
    local loadedChoices = loaded:archiveChoices(loaded:machineById(terminal.id).id)
    expect(loadedChoices[2].unlocked, "archive choice data should expose unlocked recipe")
end

tests[#tests + 1] = function()
    local unpowered = Simulation.new(90)
    local unpoweredGate = unpowered:addMachine("rift_gate", 1, 0, "south")
    runSteps(unpowered, 1)
    expect(unpoweredGate.status == "missing_power", "rift gate should require power")
    local sim = Simulation.new(91)
    local generator = sim:addMachine("generator", 0, 1, "south")
    generator.inventory:add("coal", 2)
    sim:addMachine("power_pole", 1, 1, "south")
    local gate = sim:addMachine("rift_gate", 1, 0, "south")
    runSteps(sim, 1)
    expect(gate.status == "missing_input", "powered rift gate should require beacon core")
    gate.inventory:add("beacon_core", 1)
    runSteps(sim, 180)
    expect(gate.progress == 0 and gate.status == "idle", "rift gate should reset after jump")
    expect(gate.inventory:count("beacon_core") == 0, "rift gate should consume beacon core")
    expect(sim.productionTotals.rift_jumps == 1, "rift gate should increment jump total")
    expect(sim.player.x >= 4096 and sim.world:biomeAt(sim.player.x, sim.player.y, sim.player.z) == "rift", "rift gate should move player to outer band")
    expect(sim.productionTotals.rift_storms_triggered == 1 and sim:riftStormActive(), "rift jump should trigger active storm")
    expect(sim:riftStormText():find("active") ~= nil, "rift storm text should expose active state")
    local loaded = assert(Save.fromText(Save.toText(sim)))
    expect(loaded.productionTotals.rift_jumps == 1 and loaded.player.x >= 4096 and loaded:riftStormActive(), "rift jump storm state should persist")

    local storm = Simulation.new(92)
    storm.player.x = 4096
    local stormGenerator = storm:addMachine("generator", 4096, 1, "south")
    stormGenerator.inventory:add("coal", 2)
    storm:addMachine("power_pole", 4097, 1, "south")
    local stormGate = storm:addMachine("rift_gate", 4097, 0, "south")
    stormGate.progress = 40
    storm.riftStorm = { severity = 3, ticksRemaining = 90, cooldownTicks = 100 }
    storm.tick = 60
    storm:step()
    expect(stormGate.progress < 40 and stormGate.status == "output_blocked", "rift storm should jolt unanchored gate charge")
    storm.riftStorm = { severity = 2, ticksRemaining = 1, cooldownTicks = 100 }
    storm:step()
    expect(not storm:riftStormActive() and storm.productionTotals.rift_storms_survived == 1, "expired rift storm should count as survived")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(34)
    local function findPanel(panels, key)
        for _, panel in ipairs(panels) do
            if panel.key == key then
                return panel
            end
        end
        return nil
    end
    local panels = sim:factoryDashboard()
    expect(findPanel(panels, "power") ~= nil, "dashboard should include power panel")
    expect(findPanel(panels, "progression") ~= nil, "dashboard should include progression panel")
    expect(findPanel(panels, "rates") ~= nil, "dashboard should include rates panel")
    expect(sim:factoryDashboardText():find("dashboard: next Progression") == 1, "dashboard should surface first incomplete panel")
    sim.world:setTile(1, 0, 0, { id = "iron_ore", data = 10 })
    sim:addMachine("power_pole", 0, 0, "south")
    sim:addMachine("electric_miner", 1, 0, "east")
    sim:step()
    local power = findPanel(sim:factoryDashboard(), "power")
    expect(power.urgent and power.status == "underpowered", "dashboard should flag underpowered networks")
    expect(sim:factoryDashboardText():find("dashboard: urgent Power") == 1, "dashboard should prioritize urgent power panel")
    local loaded = assert(Save.fromText(Save.toText(sim)))
    loaded:step()
    local loadedPower = findPanel(loaded:factoryDashboard(), "power")
    expect(loadedPower.urgent and loadedPower.status == "underpowered", "dashboard state should survive save/load")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(35)
    sim.productionTotals.iron_plate = 1
    sim.productionTotals.copper_plate = 1
    sim.productionTotals.science_pack = 1
    sim.completedTechs.logistics_1 = true
    sim.supplyContracts[1].complete = true
    local progress = sim:achievementProgress()
    expect(#progress == 6, "achievement progress should expose all definitions")
    expect(progress[1].current >= progress[1].required, "achievement progress should derive from totals")
    expect(sim:unlockedAchievementCount() == 0, "achievements should not unlock before a step")
    sim:step()
    expect(sim:unlockedAchievementCount() == 5, "seeded achievements should unlock after a step")
    expect(sim:isAchievementUnlocked("first_iron_plate"), "first plate achievement should unlock")
    sim:step()
    expect(sim:unlockedAchievementCount() == 5, "achievement updates should not duplicate unlocks")
    local loaded = assert(Save.fromText(Save.toText(sim)))
    expect(loaded:unlockedAchievementCount() == 5, "unlocked achievements should persist")
    expect(loaded:isAchievementUnlocked("first_supply_contract"), "supply achievement should persist")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(36, true)
    local function stepComplete(state, key)
        for _, step in ipairs(state:tutorialProgress()) do
            if step.key == key then
                return step.complete
            end
        end
        return false
    end
    expect(sim.world:getTile(0, 0, 2).id == "floor", "tutorial spawn should be floor")
    expect(sim.world:getTile(-3, 0, 2).id == "tree", "tutorial room should contain a tree")
    expect(sim.world:getTile(-2, 2, 2).id == "stone", "tutorial room should contain stone")
    expect(sim.world:getTile(5, 0, 2).id == "stairs_down", "tutorial room should contain an exit")
    expect(sim.world:getTile(6, 0, 2).id == "dungeon_wall", "tutorial room should be isolated")
    expect(sim:tutorialState().active and not sim:tutorialState().completed, "tutorial start state should be active")
    expect(sim.player.z == 2 and sim:machineAt(3, 0, 2) ~= nil, "tutorial should spawn player and chest on tutorial layer")
    sim.world:setTile(0, -1, 2, { id = "grass", data = 0 })
    sim:queue(Simulation.commands.mine("north"))
    sim:step()
    expect(not stepComplete(sim, "mine"), "failed mine should not complete tutorial mine step")
    sim:queue(Simulation.commands.move("east"))
    sim:step()
    expect(stepComplete(sim, "move"), "successful move should complete tutorial move step")
    sim.player.x = -2
    sim.player.y = 0
    sim:queue(Simulation.commands.mine("west"))
    sim:step()
    expect(stepComplete(sim, "mine"), "successful mine should complete tutorial mine step")
    sim:addItem("wood", 5)
    sim:addItem("stone", 2)
    sim:queue(Simulation.commands.craft("workbench"))
    sim:step()
    expect(stepComplete(sim, "craft"), "successful craft should complete tutorial craft step")
    sim.player.x = 0
    sim.player.y = 0
    sim:queue(Simulation.commands.place("south", "workbench", "south"))
    sim:step()
    expect(stepComplete(sim, "place"), "successful place should complete tutorial place step")
    sim.player.x = 2
    sim.player.y = 0
    sim:addItem("wood", 1)
    sim:queue(Simulation.commands.deposit("east", "wood"))
    sim:step()
    expect(stepComplete(sim, "deposit"), "successful deposit should complete tutorial deposit step")
    expect(sim:tutorialExitReady(), "tutorial exit should unlock after checklist completion")
    local loaded = assert(Save.fromText(Save.toText(sim)))
    expect(loaded:tutorialExitReady(), "tutorial checklist should persist")
    loaded.player.x = 4
    loaded.player.y = 0
    loaded:queue(Simulation.commands.move("east"))
    loaded:step()
    expect(not loaded:tutorialState().active and loaded:tutorialState().completed, "tutorial exit should complete tutorial")
    expect(loaded.player.z == 0, "tutorial exit should return to real layer")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(31)
    local lab = sim:addMachine("lab", 0, 0, "south")
    lab.inventory:add("science_pack", 7)
    runSteps(sim, 180)
    expect(sim:isTechCompleted("logistics_1"), "logistics_1 was not completed")
    expect(sim:isTechCompleted("automation_control"), "automation_control was not completed")
    expect(sim.activeTech == "logistic_network", "active tech did not advance to logistic_network")
    for _, recipe in ipairs({ "fast_belt", "generator", "power_pole", "electric_miner", "splitter", "pipe" }) do
        expect(sim:isRecipeUnlocked(recipe), "logistics_1 unlock path missing " .. recipe)
    end
    for _, recipe in ipairs({ "circuit_board", "advanced_science_pack", "crystal_lens", "circuit_inserter", "offshore_pump", "guard_tower", "repair_pylon" }) do
        expect(sim:isRecipeUnlocked(recipe), "automation_control unlock path missing " .. recipe)
    end
    lab.inventory:add("advanced_science_pack", 5)
    runSteps(sim, 120)
    expect(sim:isTechCompleted("logistic_network"), "logistic_network was not completed")
    for _, recipe in ipairs({
        "provider_chest", "requester_chest", "logistic_port", "logistic_drone", "beacon_core", "archive_terminal",
        "train_stop", "rift_gate", "outpost_beacon", "pressure_relay", "arc_tower",
    }) do
        expect(sim:isRecipeUnlocked(recipe), "logistic_network unlock path missing " .. recipe)
    end
    local loaded = assert(Save.fromText(Save.toText(sim)))
    expect(loaded.activeTech == nil, "completed tech chain should stay complete after load")
    expect(loaded:isRecipeUnlocked("rift_gate"), "final tech unlocks did not persist")
end

for index, test in ipairs(tests) do
    local ok, err = pcall(test)
    if not ok then
        io.stderr:write("not ok ", index, " - ", tostring(err), "\n")
        os.exit(1)
    end
    io.stdout:write("ok ", index, "\n")
end

io.stdout:write("tests passed: ", #tests, "\n")
