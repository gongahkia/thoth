package.path = "./?.lua;./?/init.lua;./src/?.lua;./src/?/init.lua;" .. package.path

local Serialize = require("src.core.serialize")
local Simulation = require("src.game.simulation")
local Save = require("src.game.save")
local Replay = require("src.game.replay")
local Input = require("src.app.input")
local Render = require("src.app.render")
local Audio = require("src.app.audio")
local Credits = require("src.app.credits")
local Settings = require("src.app.settings")
local Achievements = require("src.app.achievements")
local SpritePipeline = require("src.app.sprite_pipeline")
local ModelPipeline = require("src.app.model_pipeline")
local TileModelMap = require("assets.models.tile_model_map")
local World = require("src.game.world")
local Defs = require("src.game.defs")

local function expect(value, message)
    if not value then
        error(message or "expectation failed", 2)
    end
end

local function sameSnapshot(a, b)
    return Serialize.encode(a:snapshot()) == Serialize.encode(b:snapshot())
end

local function runQueued(sim, command)
    sim:queue(command)
    sim:step()
end

local function placeCampMarker(sim)
    sim.world:setTile(sim.player.x, sim.player.y, sim.player.z or 0, { id = "camp_marker", data = 0 })
end

local function walkSteps(sim, direction, count)
    for _ = 1, count do
        runQueued(sim, Simulation.commands.move(direction))
        if sim.mode == "combat" then
            sim:finishCombat(true)
        end
    end
end

local function contains(list, value)
    for _, entry in ipairs(list or {}) do
        if entry == value then
            return true
        end
    end
    return false
end

local function readFile(path)
    local file = io.open(path, "rb")
    if not file then
        return nil
    end
    local data = file:read("*a")
    file:close()
    return data
end

local function reachableRooms(world, start)
    local seen = { [start] = true }
    local queue = { start }
    local index = 1
    while queue[index] do
        local roomKey = queue[index]
        index = index + 1
        for _, adjacent in ipairs(world:connectedRooms(roomKey)) do
            if not seen[adjacent] then
                seen[adjacent] = true
                queue[#queue + 1] = adjacent
            end
        end
    end
    return seen
end

local function expectReachable(world, start, rooms, label)
    local seen = reachableRooms(world, start)
    for _, roomKey in ipairs(rooms) do
        expect(seen[roomKey], label .. " missing reachable room " .. roomKey)
    end
end

local function reachEntryCombat(sim)
    for _ = 1, 5 do
        runQueued(sim, Simulation.commands.move("east"))
    end
    expect(sim.mode == "combat", "entry room should start combat")
end

local function makeActiveMerchant(sim, rank)
    local hero = sim:heroAtRank(rank)
    hero.class = "merchant"
    hero.name = "Leto"
    hero.skills = { "appraise_weak_point", "brokered_mercy", "settle_accounts" }
    hero.skillLevels = { appraise_weak_point = 1, brokered_mercy = 1, settle_accounts = 1 }
    hero.hp = Defs.heroClass("merchant").maxHp
    hero.stress = 0
    sim.combat.active = { side = "hero", id = hero.id, rank = rank }
    sim.player.selectedHero = rank
    return hero
end

local tests = {}

tests[#tests + 1] = function()
    local function fakeSource()
        return {
            volume = 0,
            plays = 0,
            stops = 0,
            looping = nil,
            setVolume = function(self, volume)
                self.volume = volume
            end,
            setLooping = function(self, looping)
                self.looping = looping
            end,
            play = function(self)
                self.plays = self.plays + 1
            end,
            stop = function(self)
                self.stops = self.stops + 1
            end,
        }
    end
    local estateSource = fakeSource()
    local combatSource = fakeSource()
    local bank = {
        __music = {
            manifest = { fadeSeconds = 2, contexts = { estate = "estate", combat = "combat_normal" } },
            tracks = {
                estate = { key = "estate", source = estateSource, loop = true },
                combat_normal = { key = "combat_normal", source = combatSource, loop = true },
            },
            fadeSeconds = 2,
            fade = 0,
        },
    }
    Audio.applySettings(bank, { masterVolume = 0.5, musicVolume = 0.8, sfxVolume = 1 })
    expect(Audio.setMusicContext(bank, "estate", 0) == "estate", "music should resolve estate context")
    expect(estateSource.plays == 1 and estateSource.looping == true, "music should start first context")
    expect(math.abs(estateSource.volume - 0.4) < 0.001, "music should apply master/music volume")
    Audio.setMusicContext(bank, "combat", 2)
    Audio.updateMusic(bank, 1)
    expect(math.abs(estateSource.volume - 0.2) < 0.001, "music should fade current track down")
    expect(math.abs(combatSource.volume - 0.2) < 0.001, "music should fade next track up")
    Audio.updateMusic(bank, 1)
    expect(estateSource.stops == 1 and math.abs(combatSource.volume - 0.4) < 0.001, "music should finish crossfade")
    Audio.setMusicContext(bank, "estate", 2)
    Audio.setMusicContext(bank, "combat", 2)
    expect(estateSource.stops == 2, "music should stop superseded next track")
    expect(Audio.contextForState({ uiState = "game" }, { mode = "expedition", expedition = { torch = 20 } }) == "expedition_tense", "low torch should select tense music")
    expect(Audio.contextForState({ uiState = "game" }, { mode = "combat", combat = { enemies = { { kind = "vault_regent" } } } }) == "boss", "boss combat should select boss music")
    expect(Audio.contextForState({ uiState = "credits" }, {}) == "credits", "credits should select credits music")
end

tests[#tests + 1] = function()
    local plan = SpritePipeline.plan(128, 80, { frameWidth = 16, frameHeight = 16 })
    expect(plan and plan.frames == 40, "sprite pipeline should count source frames")
    expect(plan.columns == 8 and plan.rows == 5 and plan.atlasWidth == 128 and plan.atlasHeight == 80, "sprite pipeline should preserve atlas grid by default")
    local rect = SpritePipeline.frameRect(plan, 10)
    expect(rect.sourceX == 16 and rect.sourceY == 16 and rect.atlasX == 16 and rect.atlasY == 16, "sprite pipeline should map frame rects")
    local manifest = SpritePipeline.loadManifest(SpritePipeline.manifestText(plan, "assets/sprites/oga_700_sprites.png", "source.png"))
    expect(manifest and manifest.frames == 40 and manifest.image == "assets/sprites/oga_700_sprites.png", "sprite pipeline should write manifest data")
    local bad, err = SpritePipeline.plan(127, 80, { frameWidth = 16, frameHeight = 16 })
    expect(not bad and err:find("divisible", 1, true), "sprite pipeline should reject uneven source sheets")
end

tests[#tests + 1] = function()
    local parsed = ModelPipeline.parseObj(readFile("vendor/g3d/assets/cube.obj"))
    expect(parsed and parsed.format == "obj", "model pipeline should parse obj")
    expect(parsed.vertexCount == 36 and parsed.triangleCount == 12, "model pipeline should triangulate cube")
    expect(parsed.bounds.min[1] < 0 and parsed.bounds.max[1] > 0, "model pipeline should compute bounds")
    local entry = ModelPipeline.manifestEntry(parsed, "vendor/g3d/assets/cube.obj", "assets/models/cube.obj", "cube")
    local manifest = ModelPipeline.loadManifest(ModelPipeline.manifestText({ entry }))
    expect(manifest and manifest.models[1].id == "cube" and manifest.models[1].triangles == 12, "model pipeline should write manifest")
    local bad, err = ModelPipeline.import("asset.gltf", "dist/model.obj", "dist/models.lua")
    expect(not bad and err:find("obj", 1, true), "model pipeline should fail fast for gltf")
end

tests[#tests + 1] = function()
    local seen = {}
    for _, key in ipairs(Defs.tileOrder or {}) do
        expect(Defs.tiles[key], "tile order references missing tile " .. tostring(key))
        expect(not seen[key], "tile order has duplicate " .. tostring(key))
        seen[key] = true
    end
    for key in pairs(Defs.tiles or {}) do
        expect(seen[key], "tile order missing " .. tostring(key))
        local mapped = TileModelMap.tiles[key]
        expect(mapped and mapped.path and mapped.role, "tile model map missing " .. tostring(key))
        expect(mapped.path:find("addons/kaykit_dungeon_remastered/Assets/obj/", 1, true) == 1, "tile model path should use KayKit obj root")
        expect(mapped.path:match("%.obj$"), "tile model path should be obj")
    end
end

tests[#tests + 1] = function()
    expect(World.floorDiv(31, World.chunkSize) == 0, "positive chunk edge failed")
    expect(World.floorDiv(32, World.chunkSize) == 1, "positive chunk boundary failed")
    expect(World.floorDiv(-1, World.chunkSize) == -1, "negative chunk edge failed")
    expect(World.floorMod(-1, World.chunkSize) == 31, "negative chunk mod failed")
    local world = World.new(101)
    expect(world:loadedChunkCount() == 0, "fresh world loaded chunks")
    expect(world:getTile(0, 0, 0).id == "archive_floor", "origin should be archive floor")
    expect(world:getTile(3, 0, 0).id == "corridor", "corridor should pierce room edge")
    expect(world:getTile(-2, 2, 0).id == "exit_gate", "exit gate missing")
    local connected = world:connectedRooms("0:0")
    expect(contains(connected, "8:0") and contains(connected, "0:8"), "room graph should expose corridor links")
    local baseRevision = world:chunkRevision(0, 0, 0)
    world:setTile(4, 0, 0, { id = "archive_floor", data = 0 })
    expect(world:getTile(4, 0, 0).id == "archive_floor", "override did not persist")
    expect(world:chunkRevision(0, 0, 0) == baseRevision + 1, "override should bump chunk revision")
    local loaded = World.fromSnapshot(world:snapshot())
    expect(loaded:getTile(4, 0, 0).id == "archive_floor", "world snapshot lost override")
end

tests[#tests + 1] = function()
    local scout = World.new(101, "buried_archive", { tiles = {}, layoutId = "archive_scout" })
    local cleanse = World.new(101, "buried_archive", { tiles = {}, layoutId = "archive_cleansing" })
    expect(scout:layout().generated and scout:layout().generatedLayoutId == World.fromSnapshot(scout:snapshot()):layout().generatedLayoutId, "archive layout should generate deterministically")
    expect(cleanse:encounterForRoom("16:6") == "undercroft" and scout:encounterForRoom("16:6") == nil, "mission grammar should vary archive encounter anchors")
    local seen = reachableRooms(cleanse, "0:0")
    expect(seen["24:0"] and seen["16:0"] and seen["0:8"] and seen["8:6"], "generated archive required rooms should be reachable")
    expect(contains(cleanse:connectedRooms("8:0"), "16:0") and contains(cleanse:connectedRooms("8:0"), "8:6"), "generated archive should include a loop and optional branch")
    expect(#cleanse:threatsInRect(-999, 999, -999, 999, 0) >= 2, "generated archive should expose visible threats")
end

tests[#tests + 1] = function()
    local map = World.new(102, "buried_archive", { tiles = {}, layoutId = "archive_intake_map" })
    local reeve = World.new(102, "buried_archive", { tiles = {}, layoutId = "archive_silence_reeve" })
    local witness = World.new(102, "buried_archive", { tiles = {}, layoutId = "archive_witness_confession" })
    expect(map:encounterForRoom("24:0") == nil, "intake map should omit boss gate encounter")
    expect(reeve:encounterForRoom("8:6") == "archive_reeve" and reeve:encounterForRoom("24:0") == nil, "reeve mission should route to mini-boss without final boss")
    expect(witness:encounterForRoom("8:6") == "archive_witness" and witness:encounterForRoom("24:6") == "archive_bailiff", "witness mission should place stand-and-survive fights")
    expect(reeve:layout().roomTemplateByRole.entrance == "intake_desk", "archive layout should expose room template roles")
    local roles = {}
    for _, corridor in ipairs(reeve:layout().corridors) do
        roles[corridor.role] = true
    end
    expect(roles.audit_lane and roles.shelf_crawl and roles.writ_run, "archive layout should assign v2 corridor roles")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(11)
    expect(sim.mode == "expedition", "new sim should start playable expedition")
    expect(#sim.estate.roster == 4, "default roster should have four heroes")
    expect(#sim.estate.recruits == 3, "estate should seed recruit candidates")
    expect(sim.estate.trinkets.ember_pin == 1, "estate should seed trinkets")
    expect(sim.expedition.supplies:count("torch") == 4, "default supplies missing torches")
    expect(sim.expedition.roomsScouted == 1, "starting room should be scouted")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(103)
    local torch = sim.expedition.torch
    runQueued(sim, Simulation.commands.move("south"))
    expect(sim.expedition.torch <= torch - 7, "shelf crawl should spend torch on corridor entry")
    local audit = sim.world:corridorAt(9, 0)
    sim.expedition.currentCorridor = nil
    sim:applyCorridorRole(audit)
    local noise = sim.expedition.noise
    sim.expedition.currentCorridor = nil
    sim:applyCorridorRole(audit)
    expect(sim.expedition.noise == noise + 2, "audit lane should add noise on backtracking")
    local stress = sim:heroAtRank(1).stress
    sim.expedition.currentCorridor = nil
    sim:applyCorridorRole(sim.world:corridorAt(9, 6))
    expect(sim:heroAtRank(1).stress > stress, "writ run should cost party stress")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(104)
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.startExpedition("archive_false_index"))
    local dread = sim.estate.campaign.dread
    expect(sim.expedition.supplies:count("false_index_writ") == 1, "false index mission should grant quest writ")
    sim:resolveCurio(8, 2, 0, "false_index")
    expect(sim.expedition.objectiveComplete and sim.estate.campaign.dread == dread + 1, "false index activation should complete with dread tradeoff")
    sim:endExpedition(true)
    sim.estate.campaign.dread = 3
    runQueued(sim, Simulation.commands.startExpedition("archive_names"))
    sim:resolveCurio(0, 10, 0, "sealed_name")
    expect(not sim.expedition.objectiveComplete, "one sealed name should not complete gather mission")
    sim:resolveCurio(16, 1, 0, "sealed_name")
    expect(sim.expedition.objectiveComplete, "two sealed names should complete archive names mission")
    local beforeRepair = sim.estate.campaign.dread
    sim:resolveCurio(0, 9, 0, "name_press")
    expect(sim.estate.campaign.dread == beforeRepair - 1, "name press repair should lower dread when salve is spent")
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.startExpedition("archive_audit_page_bearer"))
    expect(sim.expedition.noise == 3, "audit page-bearer mission should start with noise pressure")
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.startExpedition("archive_misfiled_dead"))
    expect(sim.expedition.packSlots == 10, "misfiled dead mission should apply carry-load pack pressure")
end

tests[#tests + 1] = function()
    local world = World.new(46, "salt_cistern")
    expect(world.location == "salt_cistern", "world should store location key")
    expect(world:getTile(0, 0, 0).id == "salt_floor", "salt cistern origin should use location floor")
    expect(world:getTile(1, 0, 0).id == "salt_causeway", "salt cistern corridor should use location corridor")
    expect(table.concat(world:connectedRooms("0:0"), ",") == "6:4", "salt cistern room graph should use location corridors")
    local loaded = World.fromSnapshot(world:snapshot())
    expect(loaded.location == "salt_cistern" and loaded:getTile(0, 0, 0).id == "salt_floor", "world snapshot should preserve location")
end

tests[#tests + 1] = function()
    local choir = World.new(106, "salt_cistern", { tiles = {}, layoutId = "cistern_silence_choir" })
    local sluice = World.new(106, "salt_cistern", { tiles = {}, layoutId = "cistern_open_deep_sluice" })
    expect(choir:layout().grammar.id == "cistern_grammar_v1" and choir:layout().generatedLayoutId == World.fromSnapshot(choir:snapshot()):layout().generatedLayoutId, "cistern mission layout should snapshot deterministically")
    expect(choir:encounterForRoom("6:10") == "cistern_choir" and choir:encounterForRoom("18:10") == nil, "pearl choir mission should replace boss gate")
    expect(sluice:encounterForRoom("18:10") == "matron" and sluice:encounterForRoom("18:4") == "cistern_bailiff", "deep sluice mission should place bailiff and boss gate")
    expect(choir:layout().roomTemplateByRole.pump_hub == "pump_forest", "cistern layout should expose room template roles")
    expectReachable(choir, "0:0", { "6:4", "12:0", "6:10", "12:10", "18:4", "18:10" }, "cistern grammar")
    expect(#choir:threatsInRect(-999, 999, -999, 999, 0) >= 2, "cistern grammar should expose visible threats")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(107)
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.startExpedition("cistern_low_reservoir"))
    sim.expedition.questActivations = 1
    local noise = sim.expedition.noise
    sim:applyCorridorRole(sim.world:corridorAt(1, 0))
    expect(sim.expedition.noise == noise + 2, "pressure walk should flood after valve use")
    local hero = sim:heroAtRank(1)
    sim.expedition.currentCorridor = nil
    sim:applyCorridorRole(sim.world:corridorAt(6, 6))
    expect(contains(hero.diseases, "brine_rot"), "maintenance siphon should risk brine rot")
    local firstHero = sim.party[1]
    sim.expedition.torch = 0
    sim.expedition.currentCorridor = nil
    sim:applyCorridorRole(sim.world:corridorAt(18, 6))
    expect(sim.party[1] ~= firstHero, "undertow walk should pull front rank at low torch")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(108)
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.startExpedition("cistern_low_reservoir"))
    expect(sim.expedition.supplies:count("valve_key") == 2 and sim.expedition.noise == 2, "low reservoir should grant keys and pressure")
    sim:resolveCurio(6, 5, 0, "tide_valve")
    sim:resolveCurio(18, 5, 0, "tide_valve")
    expect(sim.expedition.objectiveComplete, "low reservoir should complete after two valves")
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.startExpedition("cistern_open_deep_sluice"))
    sim:resolveCurio(6, 11, 0, "deep_sluice_key")
    sim:resolveCurio(18, 9, 0, "deep_sluice_key")
    expect(sim.expedition.objectiveComplete, "deep sluice should complete after key assembly")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(109)
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.startExpedition("cistern_bell"))
    expect(sim:missionIntro("cistern_bell").brief:find("Bell Diver", 1, true), "bell mission intro should be mission-specific")
    expect(sim:missionProgressText():find("bell diver sunk 0/1", 1, true), "bell mission should expose polished progress text")
    expect(sim:objectiveChecklist()[1].items[1].next:find("Defeat the Bell Diver", 1, true), "bell mission should expose next-step copy")
    expect(sim:startCombat("matron", "18:10"), "cistern boss combat should start")
    local diver = sim.combat.enemies[1]
    expect(diver.kind == "bell_diver" and diver.bossPhase == "toll" and diver.nextBossSkill == "drowned_hymn", "bell diver should open in toll phase")
    expect(diver.parts[1].hint:find("Drowned Hymn", 1, true) and diver.parts[2].hint:find("Hook Chain", 1, true), "bell diver weak points should expose skill-lock hints")
    expect(table.concat(sim.log, "\n"):find("Toll Phase", 1, true) and sim.narration:find("water counts", 1, true), "bell diver should announce phase dialogue")
    sim:damageEnemyPart(diver, "bell_lung", 99)
    expect(diver.bossPhase == "chain" and diver.nextBossSkill == "hook_chain", "bell diver should shift phase when a weak point breaks")
    diver.hp = 8
    sim:applyBossPhase(diver, false)
    expect(diver.bossPhase == "undertow", "bell diver should enter low-hp undertow phase")
    local loadedBell = Simulation.fromSnapshot(sim:snapshot())
    expect(loadedBell.combat.enemies[1].bossPhase == "undertow" and loadedBell.combat.enemies[1].parts[1].hint:find("Drowned Hymn", 1, true), "bell diver phase and hints should survive snapshot")
    sim:finishCombat(true)
    sim:endExpedition(true)
    sim.estate.campaign.dread = 4
    runQueued(sim, Simulation.commands.startExpedition("cistern_bell"))
    expect(sim:startCombat("matron", "18:10"), "cistern boss variant combat should start")
    expect(sim.combat.encounter == "matron_toll" and sim.combat.enemies[1].kind == "bell_diver_flood_toll", "high dread should select bell diver flood-toll")
    expect(sim.combat.enemies[1].parts[1].key == "bell_lung", "bell diver variant should expose Bell Lung")
    expect(sim.combat.enemies[1].bossPhase == "flood" and sim.combat.enemies[1].parts[1].hint:find("Flood Toll", 1, true), "flood-toll diver should expose flood phase and weak-point hints")
    sim:finishCombat(true)
    sim:startCombat("cistern_cyst", "cyst_spawn_test")
    local cyst = sim.combat.enemies[1]
    cyst.hp = 0
    sim:afterEnemyDamaged(cyst)
    expect(sim.combat.enemies[#sim.combat.enemies].kind == "cyst_burst", "pearl cyst should spawn cyst burst on death")
    sim:finishCombat(true)
    sim:startCombat("cistern_bailiff", "pilgrim_rise_test")
    local pilgrim = sim.combat.enemies[2]
    pilgrim.hp = 0
    sim:afterEnemyDamaged(pilgrim)
    expect(pilgrim.resurrected and pilgrim.hp > 0, "drowned pilgrim should resurrect once")
end

tests[#tests + 1] = function()
    local cases = {
        { "cistern_survey", "Salt Cistern", "cistern rooms sounded 1/4", "Scout 4 cistern rooms" },
        { "cistern_valves", "tide valves", "tide valves opened 0/2", "Spend 2 Valve Keys" },
        { "cistern_low_reservoir", "low reservoir", "low reservoir bled 0/2", "Bleed 2 low reservoir valves" },
        { "cistern_salt_register", "Salt Register", "salt register recovered 0/1", "Recover the Salt Register" },
        { "cistern_gatekeepers", "gatekeepers", "gatekeepers spared 0/1", "Spend 1 Valve Key to spare" },
        { "cistern_silence_choir", "Pearl Choir", "pearl choir silenced 0/1", "Defeat the Pearl Choir" },
        { "cistern_drain_market", "drowned market", "drowned market drained 0/2", "Open 2 market drains" },
        { "cistern_tov_child", "Tov Child", "Tov child recovered 0/1", "Recover the Tov Child" },
        { "cistern_flood_bailiff", "Bailiff Walk", "bailiff walk flooded 0/1", "Spend 1 Valve Key to flood" },
        { "cistern_open_deep_sluice", "Deep Sluice Keys", "deep sluice keys recovered 0/2", "Recover 2 Deep Sluice Keys" },
    }
    local sim = Simulation.new(134)
    sim:endExpedition(true)
    for _, case in ipairs(cases) do
        local key, introNeedle, progressNeedle, objectiveNeedle = case[1], case[2], case[3], case[4]
        runQueued(sim, Simulation.commands.startExpedition(key))
        expect(sim:missionIntro(key).brief:find(introNeedle, 1, true), key .. " intro should be mission-specific")
        expect(sim:missionProgressText():find(progressNeedle, 1, true), key .. " should expose polished progress text")
        expect(sim:objectiveChecklist()[1].items[1].next:find(objectiveNeedle, 1, true), key .. " should expose next-step copy")
        sim:endExpedition(true)
    end
end

tests[#tests + 1] = function()
    local vicar = World.new(110, "ember_warrens", { tiles = {}, layoutId = "warrens_douse_vicar" })
    local furnace = World.new(110, "ember_warrens", { tiles = {}, layoutId = "warrens_open_furnace" })
    expect(vicar:layout().grammar.id == "ember_grammar_v1" and vicar:layout().generatedLayoutId == World.fromSnapshot(vicar:snapshot()):layout().generatedLayoutId, "ember mission layout should snapshot deterministically")
    expect(vicar:encounterForRoom("8:-8") == "ember_vicar" and vicar:encounterForRoom("20:-8") == nil, "vicar mission should replace boss gate")
    expect(furnace:encounterForRoom("20:4") == "ember_furnace" and furnace:encounterForRoom("20:-8") == "prioress", "white furnace mission should place furnace and boss gate")
    expect(furnace:layout().roomTemplateByRole.kiln_nave == "kiln_nave", "ember layout should expose room template roles")
    expectReachable(furnace, "0:0", { "8:0", "8:-8", "14:-4", "14:4", "20:4", "20:-8" }, "ember grammar")
    expect(#furnace:threatsInRect(-999, 999, -999, 999, 0) >= 2, "ember grammar should expose visible threats")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(111)
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.startExpedition("ember_vow_kilns"))
    local torch = sim.expedition.torch
    sim:applyCorridorRole(sim.world:corridorAt(1, 0))
    expect(sim.expedition.torch == torch - 7, "clinker run should cost torch")
    sim.expedition.currentCorridor = nil
    local bellows = sim.world:corridorAt(9, -8)
    sim:applyCorridorRole(bellows)
    local heat = sim.expedition.heatFatigue
    sim.expedition.currentCorridor = nil
    sim:applyCorridorRole(bellows)
    expect(sim.expedition.heatFatigue == heat + 1, "bellows spine should raise heat on backtrack")
    sim.expedition.currentCorridor = nil
    local noise = sim.expedition.noise
    sim:applyCorridorRole(sim.world:corridorAt(8, -1))
    expect(sim.expedition.noise == noise + 3, "soot creep should amplify ambush noise")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(112)
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.startExpedition("ember_vow_kilns"))
    expect(sim.expedition.supplies:count("ember_oil") == 2, "vow kilns should grant ember oil")
    sim:resolveCurio(14, -3, 0, "ember_ward")
    sim:resolveCurio(20, 3, 0, "ember_ward")
    expect(sim.expedition.objectiveComplete and sim.expedition.supplies:count("ember_oil") == 0, "vow kilns should complete after two wards")
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.startExpedition("ember_ash_names"))
    expect(sim.expedition.packSlots == 10, "ash names should apply pack pressure")
    sim:resolveCurio(8, -1, 0, "ash_name")
    sim:resolveCurio(14, 5, 0, "ash_name")
    expect(sim.expedition.objectiveComplete and sim.expedition.loot:count("ash_name") == 2, "ash names should complete after two names")
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.startExpedition("warrens_open_furnace"))
    sim:resolveCurio(20, 5, 0, "white_furnace_key")
    sim:resolveCurio(20, -7, 0, "white_furnace_key")
    expect(sim.expedition.objectiveComplete, "white furnace should complete after key assembly")
end

tests[#tests + 1] = function()
    local cases = {
        { "ember_cleansing", "Ember Warrens", "ember rooms quenched 0/2", "Win 2 Warrens fights" },
        { "ember_wards", "Ember Wards", "ember wards anointed 0/2", "Spend 2 Ember Oil" },
        { "ember_vow_kilns", "Vow Kilns", "vow kilns doused 0/2", "Spend 2 Ember Oil at vow kilns" },
        { "ember_ash_names", "Ash Names", "ash names carried 0/2", "Carry out 2 Ash Names" },
        { "ember_warm_dead", "Warm Dead", "warm dead spared 0/1", "Spend the False Vow Writ" },
        { "warrens_douse_vicar", "Kiln Vicar", "kiln vicar doused 0/1", "Defeat the Kiln Vicar" },
        { "warrens_burn_false_vow", "False Vow", "false vow burned 0/1", "lower dread" },
        { "warrens_warm_ledger", "Warm Ledger", "warm ledger recovered 0/1", "Recover the Warm Ledger" },
        { "warrens_aron_boy", "Aron Boy", "Aron boy carried 0/1", "Carry out the Aron Boy" },
        { "warrens_open_furnace", "White Furnace Keys", "white furnace keys recovered 0/2", "Recover 2 White Furnace Keys" },
    }
    local sim = Simulation.new(135)
    sim:endExpedition(true)
    for _, case in ipairs(cases) do
        local key, introNeedle, progressNeedle, objectiveNeedle = case[1], case[2], case[3], case[4]
        runQueued(sim, Simulation.commands.startExpedition(key))
        expect(sim:missionIntro(key).brief:find(introNeedle, 1, true), key .. " intro should be mission-specific")
        expect(sim:missionProgressText():find(progressNeedle, 1, true), key .. " should expose polished progress text")
        expect(sim:objectiveChecklist()[1].items[1].next:find(objectiveNeedle, 1, true), key .. " should expose next-step copy")
        sim:endExpedition(true)
    end
end

tests[#tests + 1] = function()
    local sim = Simulation.new(113)
    sim:endExpedition(true)
    sim.estate.campaign.dread = 0
    runQueued(sim, Simulation.commands.startExpedition("warrens_burn_false_vow"))
    sim:resolveCurio(14, -5, 0, "false_vow")
    sim:endExpedition(false)
    expect(sim.estate.campaign.dread == 0, "false vow success should not push dread below zero")
    runQueued(sim, Simulation.commands.startExpedition("warrens_open_furnace"))
    local heat = sim.expedition.heatFatigue
    sim:resolveCurio(20, -9, 0, "halo_vent", { forceNoItem = true })
    expect(sim.expedition.heatFatigue == heat + 1, "halo vent greedy use should raise heat fatigue")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(114)
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.startExpedition("ember_prioress"))
    expect(sim:missionIntro("ember_prioress").brief:find("Cinder Prioress", 1, true), "prioress mission intro should be mission-specific")
    expect(sim:missionProgressText():find("cinder prioress broken 0/1", 1, true), "prioress mission should expose polished progress text")
    expect(sim:objectiveChecklist()[1].items[1].next:find("Defeat the Cinder Prioress", 1, true), "prioress mission should expose next-step copy")
    expect(sim:startCombat("prioress", "20:-8"), "ember boss combat should start")
    local prioress = sim.combat.enemies[1]
    expect(prioress.kind == "cinder_prioress" and prioress.bossPhase == "liturgy" and prioress.nextBossSkill == "kiln_liturgy", "prioress should open in liturgy phase")
    expect(prioress.parts[1].hint:find("Kiln Liturgy", 1, true) and prioress.parts[2].hint:find("Soot Cloud", 1, true), "prioress weak points should expose skill-lock hints")
    expect(table.concat(sim.log, "\n"):find("Liturgy Phase", 1, true) and sim.narration:find("remembers fire", 1, true), "prioress should announce phase dialogue")
    sim:damageEnemyPart(prioress, "cinder_halo", 99)
    expect(prioress.bossPhase == "veil" and prioress.nextBossSkill == "soot_cloud", "prioress should shift phase when a weak point breaks")
    prioress.hp = 12
    sim:applyBossPhase(prioress, false)
    expect(prioress.bossPhase == "cinder", "prioress should enter low-hp cinder phase")
    local loadedPrioress = Simulation.fromSnapshot(sim:snapshot())
    expect(loadedPrioress.combat.enemies[1].bossPhase == "cinder" and loadedPrioress.combat.enemies[1].parts[1].hint:find("Kiln Liturgy", 1, true), "prioress phase and hints should survive snapshot")
    sim:finishCombat(true)
    sim:endExpedition(true)
    sim.estate.campaign.dread = 4
    runQueued(sim, Simulation.commands.startExpedition("ember_prioress"))
    expect(sim:startCombat("prioress", "20:-8"), "ember boss variant combat should start")
    expect(sim.combat.encounter == "prioress_ember" and sim.combat.enemies[1].kind == "cinder_prioress_glass", "high dread should select glass-crowned prioress")
    expect(sim.combat.enemies[1].parts[1].key == "halo_vent", "glass-crowned prioress should expose halo vent")
    expect(sim.combat.enemies[1].bossPhase == "glass" and sim.combat.enemies[1].parts[1].hint:find("Glass Crown Liturgy", 1, true), "glass-crowned prioress should expose glass phase and weak-point hints")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(115)
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.startExpedition("warrens_douse_vicar"))
    sim:startCombat("ember_vicar", "8:-8")
    sim:heroAtRank(1).hp = 20
    sim:heroAtRank(2).hp = 3
    sim:heroAtRank(3).hp = 8
    local target = sim:enemyTargetsForSkill(Defs.enemySkill("halo_vitrify"), false)[1]
    expect(target == sim:heroAtRank(2), "halo vitrify should target the most injured hero")
    sim:finishCombat(true)
    sim:startCombat("ember_furnace", "20:4")
    local heat = sim.expedition.heatFatigue
    sim:enemyTurn(sim.combat.enemies[2])
    expect(sim.expedition.heatFatigue >= heat + 1, "ember heat skills should raise heat fatigue")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(116)
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.startExpedition("ember_cleansing"))
    sim:startCombat("ember_kiln", "8:0")
    local hero = sim:heroAtRank(1)
    hero.quirks = {}
    local hp = hero.hp
    sim:applySkill(hero, 1, "shield_crack", Defs.skill("shield_crack"), { sim.combat.enemies[2] }, "enemy")
    expect(hero.hp == hp - 1, "glass penitent should reflect chip damage")
    sim:finishCombat(true)
    sim:startCombat("ember_glass", "20:4")
    local arcanist = sim:heroAtRank(4)
    arcanist.quirks = {}
    arcanist.stress = 0
    sim:applySkill(arcanist, 4, "hush", Defs.skill("hush"), { sim.combat.enemies[1] }, "enemy")
    expect(arcanist.stress == Defs.skill("hush").stressDamage, "glass choirmaster should reflect stress damage")
    local front = sim:heroAtRank(1)
    front.quirks = {}
    hp = front.hp
    local cinder = sim.combat.enemies[2]
    cinder.hp = 0
    sim:afterEnemyDamaged(cinder)
    expect(front.hp == hp - Defs.enemy("cinder_penitent").deathFrontDamage, "cinder penitent should burn front rank on death")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(47)
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.startExpedition("cistern_survey"))
    expect(sim.expedition.location == "salt_cistern" and sim.world.location == "salt_cistern", "mission should start its location world")
    expect(sim.world:getTile(6, 4, 0).id == "salt_font", "location specials should render in world")
    expect(sim.narration ~= "", "mission start should set narration")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(77)
    sim:endExpedition(true)
    for rank = 1, 4 do
        local hero = sim:heroAtRank(rank)
        hero.level = 3
    end
    sim.estate.provisionCart:add("torch", 1)
    expect(not sim:startExpedition("archive_scout"), "overlevel party should refuse apprentice mission")
    expect(sim.mode == "estate" and sim.estate.provisionCart:count("torch") == 1, "refused mission should not consume provisions")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(78)
    sim:endExpedition(true)
    for rank = 1, 4 do
        local hero = sim:heroAtRank(rank)
        hero.level = 1
        hero.stress = 0
        hero.quirks = {}
    end
    runQueued(sim, Simulation.commands.startExpedition("ember_cleansing"))
    expect(sim.mode == "expedition" and sim.expedition.mission == "ember_cleansing", "underlevel party should still enter high-tier mission")
    expect(sim:heroAtRank(3).stress == 24, "underlevel mission should add deterministic stress pressure")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(84)
    sim:endExpedition(true)
    sim:refreshMissionBoard(true)
    expect(#sim.estate.missionBoard == sim:missionBoardSlots(), "mission board should expose weekly mission slots")
    expect(not contains(sim.estate.missionBoard, "archive_regent"), "boss mission should be gated before location progress")
    sim.estate.campaign.locationProgress.buried_archive = 2
    sim:refreshMissionBoard(true)
    expect(contains(sim.estate.missionBoard, "archive_regent"), "boss mission should appear after location progress")
    local loaded = Simulation.fromSnapshot(sim:snapshot())
    expect(contains(loaded.estate.missionBoard, "archive_regent"), "mission board should survive snapshot")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(48)
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.startExpedition("cistern_bell"))
    sim:startCombat("matron", "18:10")
    sim:finishCombat(true)
    expect(sim.expedition.objectiveComplete and sim.expedition.bossDefeated, "cistern boss should complete boss mission")
    expect(sim.world:getTile(18, 10, 0).id == "salt_floor", "boss special should clear to location floor")
    sim.player.x = -2
    sim.player.y = 1
    sim.player.facing = "south"
    local heirlooms = sim.estate.heirlooms
    runQueued(sim, Simulation.commands.interact())
    expect(sim.mode == "estate" and sim.estate.heirlooms >= heirlooms + 4, "cistern mission should pay boss reward")
end

tests[#tests + 1] = function()
    local a = Simulation.new(12)
    local b = Simulation.new(12)
    local commands = {
        Simulation.commands.move("east"),
        Simulation.commands.move("east"),
        Simulation.commands.useItem("torch"),
        Simulation.commands.selectHero(2),
    }
    for _, command in ipairs(commands) do
        runQueued(a, command)
        runQueued(b, command)
    end
    expect(sameSnapshot(a, b), "same commands should be deterministic")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(13)
    sim.player.y = -2
    runQueued(sim, Simulation.commands.move("north"))
    expect(sim.player.x == 0 and sim.player.y == -2, "wall move should not change position")
    sim.player.y = 0
    runQueued(sim, Simulation.commands.move("east"))
    expect(sim.player.x == 1 and sim.expedition.torch == 74, "valid move should advance and decay light")
end

tests[#tests + 1] = function()
    local oldLove = love
    local sim = Simulation.new(14)
    local app = { moveCooldown = 0, viewRotation = 1, status = "ready", settings = Settings.defaults() }
    love = { keyboard = { isDown = function() return false end } }
    Input.keypressed(sim, app, "w")
    Input.update(sim, app, 0.2)
    sim:step()
    expect(sim.player.x == 1 and sim.player.y == 0, "rotated screen up should map east")
    Input.keypressed(sim, app, "]")
    expect(app.viewRotation == 2, "right bracket should rotate view")
    Settings.bindKey(app.settings, "moveUp", "i")
    Input.keypressed(sim, app, "i")
    expect(app.moveIntent == "up", "remapped move key should queue screen direction")
    Settings.bindKey(app.settings, "interact", "e")
    Input.keypressed(sim, app, "e")
    expect(sim.commandQueue[#sim.commandQueue].type == "interact", "remapped interact key should queue interact")
    love = oldLove
end

tests[#tests + 1] = function()
    local oldLove = love
    local sim = Simulation.new(141)
    sim:endExpedition(true)
    local app = {
        settings = Settings.defaults(),
        ui = {
            missionButtons = { { x = 0, y = 0, w = 80, h = 30, missionKey = "archive_scout" } },
            rosterButtons = { { x = 0, y = 40, w = 80, h = 30, heroId = sim.estate.roster[1].id } },
            partyRankSlots = { { x = 0, y = 80, w = 80, h = 30, rank = 2 } },
        },
    }
    love = { keyboard = { isDown = function() return false end } }
    expect(#Input.focusables(app) == 3, "keyboard focus should expose visible UI hitboxes")
    local first = Input.cycleFocus(app, 1)
    expect(first.group == "missionButtons" and app.keyboardFocus.index == 1, "tab should focus first hitbox")
    Input.keypressed(sim, app, "return")
    expect(sim.commandQueue[#sim.commandQueue].type == "startExpedition", "enter should activate focused hitbox")
    Input.cycleFocus(app, 1)
    Input.activateFocused(sim, app)
    expect(app.estateHeroId == sim.estate.roster[1].id, "keyboard activation should select roster hero")
    Input.cycleFocus(app, 1)
    Input.activateFocused(sim, app)
    expect(sim.commandQueue[#sim.commandQueue].type == "assignParty", "keyboard activation should assign party rank")
    expect(Input.back(sim, app), "escape back should clear keyboard focus")
    expect(app.keyboardFocus == nil, "back should clear focus")
    love = oldLove
end

tests[#tests + 1] = function()
    local conf = assert(io.open("conf.lua", "r"))
    local confText = conf:read("*a")
    conf:close()
    expect(confText:find("t.modules.joystick = true", 1, true) ~= nil, "controller support should enable joystick module")
    expect(Input.gamepadButtonKey("a") == "return" and Input.gamepadButtonKey("b") == "escape", "gamepad buttons should map to select and back")
    expect(Input.gamepadButtonKey("x") == "space" and Input.gamepadButtonKey("y") == "tab", "gamepad buttons should map to interact and focus")
    local axisState = {}
    expect(Input.gamepadAxisKey("leftx", 0.8, axisState) == "right", "left stick should map positive x to right")
    expect(Input.gamepadAxisKey("leftx", 0.9, axisState) == nil, "held stick should not repeat until recentered")
    expect(Input.gamepadAxisKey("leftx", 0.1, axisState) == nil, "recentered stick should clear state")
    expect(Input.gamepadAxisKey("leftx", -0.8, axisState) == "left", "left stick should map negative x to left")
    expect(Input.gamepadAxisKey("lefty", -0.8, axisState) == "up" and Input.gamepadAxisKey("lefty", 0.8, axisState) == "down", "left stick y should map to vertical nav")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(142)
    local app = { achievements = {}, toasts = {} }
    Achievements.update(sim, app)
    expect(app.achievements.first_steps and #app.toasts == 1, "achievement update should unlock expedition toast")
    sim:collectDocument("archive_writ_01", "test")
    Achievements.update(sim, app)
    expect(app.achievements.first_document and #app.toasts == 2, "achievement update should unlock document toast")
    expect(not Achievements.unlock(app, "first_document"), "achievement unlock should be idempotent")
    expect(Render.drawToasts(app) == 2, "toast renderer should report active toast count")
    Achievements.updateToasts(app, 4)
    expect(#app.toasts == 0, "toast timers should expire")
end

tests[#tests + 1] = function()
    local app = { ui = { titleButtons = { { x = 10, y = 20, w = 100, h = 30, action = "new", enabled = true } } } }
    local hitbox, group, index = Render.hitboxAt(app, 20, 25)
    expect(hitbox and group == "titleButtons" and index == 1, "ui hitbox lookup should find button target")
    expect(Render.markUiPulse(app, hitbox, "press"), "ui pulse should mark button interaction")
    app.uiHot = { group = group, index = index }
    expect(Render.drawUiMicroAnimations(app) == 2, "micro animation renderer should report hover and pulse")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(15)
    reachEntryCombat(sim)
    expect(sim.combat.encounter == "entry", "entry encounter key missing")
    expect(sim:activeHero().class == "duelist", "fastest hero should act first")
    expect(sim:livingEnemyCount() == 2, "entry encounter enemy count changed")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(16)
    reachEntryCombat(sim)
    local enemy = sim:enemyAtRank(1)
    local hp = enemy.hp
    runQueued(sim, Simulation.commands.combatSkill("arterial_cut", 1, "enemy"))
    expect(enemy.hp < hp, "combat skill should damage enemy")
    expect(#enemy.statuses == 1 and enemy.statuses[1].kind == "bleed", "arterial cut should apply bleed")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(216)
    reachEntryCombat(sim)
    local merchant = makeActiveMerchant(sim, 4)
    local enemy = sim:enemyAtRank(1)
    sim:applySkill(merchant, 4, "appraise_weak_point", Defs.skill("appraise_weak_point"), { enemy }, "enemy")
    expect(sim:hasStatus(enemy, "marked"), "merchant appraise should mark enemy")
    local hp = enemy.hp
    local duelist = sim:heroAtRank(2)
    sim:applySkill(duelist, 2, "razor_lunge", Defs.skill("razor_lunge"), { enemy }, "enemy")
    expect(enemy.hp < hp and not sim:hasStatus(enemy, "marked"), "marked enemy should take a direct hit and consume mark")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(217)
    reachEntryCombat(sim)
    local merchant = makeActiveMerchant(sim, 4)
    local ally = sim:heroAtRank(1)
    ally.hp = ally.hp - 5
    sim:applySkill(merchant, 4, "brokered_mercy", Defs.skill("brokered_mercy"), { ally }, "ally")
    expect(ally.hp > Defs.heroClass(ally.class).maxHp - 5 and merchant.stress >= 3, "brokered mercy should heal ally and stress merchant")
end

tests[#tests + 1] = function()
    local function settleDamage(enemyHp)
        local sim = Simulation.new(218)
        reachEntryCombat(sim)
        local merchant = makeActiveMerchant(sim, 2)
        local enemy = sim:enemyAtRank(1)
        enemy.kind = "hollow_guard"
        enemy.hp = enemyHp
        sim:applySkill(merchant, 2, "settle_accounts", Defs.skill("settle_accounts"), { enemy }, "enemy")
        return enemyHp - enemy.hp
    end
    expect(settleDamage(12) > settleDamage(16), "settle accounts should scale damage against missing hp")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(17)
    reachEntryCombat(sim)
    local hero = sim:activeHero()
    local stress = hero.stress
    runQueued(sim, Simulation.commands.passTurn())
    expect(hero.stress >= stress + 2, "passing should add stress")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(18)
    reachEntryCombat(sim)
    runQueued(sim, Simulation.commands.retreat())
    expect(sim.mode == "expedition" and sim.combat == nil, "combat retreat should return to exploration")
    expect(sim.expedition.torch == 60, "retreat should cost light after five moves")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(83)
    sim.expedition.torch = 55
    sim:startCombat("entry", "camp", { ambush = true })
    expect(sim.mode == "combat" and sim.combat.ambush and sim.expedition.torch == 0, "camp ambush should start combat at zero light")
    local loaded = Simulation.fromSnapshot(sim:snapshot())
    expect(loaded.combat.ambush, "combat ambush flag should survive snapshot")
    expect(not sim:retreat() and sim.mode == "combat", "camp ambush should block retreat")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(19)
    local hero = sim:heroAtRank(1)
    hero.stress = 99
    sim:addStress(hero, 3)
    expect(hero.affliction or hero.virtue, "stress over threshold should resolve")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(46)
    local hero = sim:heroAtRank(1)
    local ally = sim:heroAtRank(2)
    hero.affliction = "panic"
    ally.stress = 0
    sim:afflictionAct(hero)
    expect(ally.stress > 0 and hero.stress > 0, "panic affliction should stress hero and party")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(47)
    reachEntryCombat(sim)
    local hero = sim:activeHero()
    hero.affliction = "reckless"
    local enemy = sim:enemyAtRank(1)
    local hp = enemy.hp
    sim:afflictionAct(hero)
    expect(enemy.hp == hp - 2, "reckless affliction should lash out in combat")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(20)
    local hero = sim:heroAtRank(1)
    sim:damageHero(hero, hero.hp)
    expect(hero.alive and hero.deathsDoor and hero.hp == 0, "first lethal damage should reach death's door")
    expect(#sim.estate.graveyard == 0, "death's door should not record graveyard yet")
    hero.deathblowResist = 0
    sim:damageHero(hero, 1)
    expect(not hero.alive, "failed deathblow check should kill hero")
    expect(#sim.estate.graveyard == 1, "graveyard should record death")
    expect(sim:heroAtRank(1).id ~= hero.id, "party should compact after death")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(75)
    sim:endExpedition(true)
    local hero = sim:heroAtRank(1)
    runQueued(sim, Simulation.commands.equipTrinket(hero.id, "ember_pin", 1))
    sim:startCombat("entry", "8:0")
    hero.deathsDoor = true
    hero.deathblowResist = 0
    sim:damageHero(hero, hero.hp + 1)
    expect(hero.trinkets[1] == false and sim.combat.fallenTrinkets[1] == "ember_pin", "combat death should move trinket into fallen spoils")
    local loaded = Simulation.fromSnapshot(sim:snapshot())
    expect(loaded.combat.fallenTrinkets[1] == "ember_pin", "fallen trinkets should survive snapshot")
    sim:finishCombat(true)
    expect(sim.estate.trinkets.ember_pin == 1, "combat victory should recover fallen trinket")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(76)
    sim:endExpedition(true)
    local hero = sim:heroAtRank(1)
    runQueued(sim, Simulation.commands.equipTrinket(hero.id, "ember_pin", 1))
    sim:startCombat("entry", "8:0")
    hero.deathsDoor = true
    hero.deathblowResist = 0
    sim:damageHero(hero, hero.hp + 1)
    sim:finishCombat(false)
    expect((sim.estate.trinkets.ember_pin or 0) == 0, "combat loss should not recover fallen trinket")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(77)
    sim:endExpedition(true)
    local hero = sim:heroAtRank(1)
    runQueued(sim, Simulation.commands.equipTrinket(hero.id, "ember_pin", 1))
    sim:startCombat("entry", "8:0")
    hero.deathsDoor = true
    hero.deathblowResist = 0
    sim:damageHero(hero, hero.hp + 1)
    sim.estate.campaign.flags.survivorTrinketDebt = true
    sim.estate.campaign.dread = 0
    sim:finishCombat(false)
    expect(sim.estate.trinkets.ember_pin == 1 and sim.estate.campaign.dread == 1, "survivor debt should recover one trinket and add dread")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(37)
    local rations = sim.expedition.supplies:count("ration")
    for _ = 1, 6 do
        sim:checkHunger()
    end
    expect(sim.expedition.hungerChecks == 1, "six steps should trigger one hunger check")
    expect(sim.expedition.supplies:count("ration") == rations - 4, "hunger should consume one ration per living hero")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(38)
    sim.expedition.supplies:consume("ration", sim.expedition.supplies:count("ration"))
    local hero = sim:heroAtRank(1)
    local hp = hero.hp
    for _ = 1, 6 do
        sim:checkHunger()
    end
    expect(hero.hp < hp and hero.stress > 0, "starvation should damage and stress heroes")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(39)
    local hero = sim:heroAtRank(1)
    local hp = hero.hp
    local bandages = sim.expedition.supplies:count("bandage")
    for _ = 1, 4 do
        runQueued(sim, Simulation.commands.move("east"))
    end
    expect(hero.hp < hp, "stepping onto trap should hurt selected hero")
    expect(sim.expedition.supplies:count("bandage") == bandages, "forced trap should not auto-spend bandage")
    expect(sim.world:getTile(4, 0, 0).id == "archive_floor", "forced trap should clear hazard")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(8)
    sim.expedition.torch = 100
    local ok = sim:scoutFromRoom("0:0")
    expect(ok and sim.expedition.scoutedRooms["8:0"], "high-light scouting should reveal connected room for seed 8")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(35)
    local hero = sim:heroAtRank(1)
    hero.hp = 1
    hero.statuses[#hero.statuses + 1] = { kind = "bleed", amount = 1, turns = 2 }
    sim:applyStatuses(hero, "hero")
    expect(hero.deathsDoor and hero.statuses[1].turns == 1, "hero bleed should tick through death's door rules")
    sim:healHero(hero, 2)
    expect(not hero.deathsDoor and hero.hp > 0, "healing should clear death's door")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(36)
    reachEntryCombat(sim)
    sim.expedition.torch = 20
    local enemy = sim.combat.enemies[2]
    sim:enemyTurn(enemy)
    local marked = false
    for rank = 1, 4 do
        local hero = sim:heroAtRank(rank)
        if hero and sim:hasStatus(hero, "marked") then
            marked = true
        end
    end
    expect(marked, "low-light ink enemy should prefer marked stress skill")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(86)
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.startExpedition("archive_scout"))
    expect(sim:startCombat("archive_branch", "0:8"), "archive branch encounter should start")
    expect(sim.combat.enemies[1].kind == "parchment_swarm" and sim.combat.enemies[2].kind == "folio_bulwark", "archive branch should use archive role enemies")
    sim = Simulation.new(87)
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.startExpedition("cistern_survey"))
    expect(sim:startCombat("cistern_branch", "12:10"), "cistern branch encounter should start")
    expect(sim.combat.enemies[1].kind == "salt_eel", "cistern branch should use new enemy")
    sim = Simulation.new(88)
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.startExpedition("ember_cleansing"))
    expect(sim:startCombat("ember_branch", "8:-8"), "ember branch encounter should start")
    expect(sim.combat.enemies[1].kind == "ember_mote", "ember branch should use new enemy")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(94)
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.startExpedition("archive_scout"))
    sim.player.x = 15
    sim.player.y = 5
    sim.player.facing = "east"
    runQueued(sim, Simulation.commands.interact())
    expect(sim.mode == "combat" and sim.combat.encounter == "archive_elite" and sim.combat.visible, "visible archive threat should start elite combat")
    expect(sim.combat.threatKey == "archive_lectern", "visible archive threat should preserve threat key")
    sim:finishCombat(true)
    expect(sim.expedition.clearedEncounters.archive_lectern, "visible archive threat should clear by threat key")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(94)
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.startExpedition("archive_scout"))
    sim.expedition.torch = 85
    sim.player.x = 15
    sim.player.y = 5
    sim.player.facing = "east"
    runQueued(sim, Simulation.commands.stealthApproach())
    expect(sim.expedition.stealthApproach and sim.expedition.torch == 75, "stealth approach should spend torch and arm approach state")
    runQueued(sim, Simulation.commands.interact())
    expect(sim.mode == "combat" and sim.combat.stealthed and not sim.combat.ambush, "stealth approach should carry into visible threat combat")
    local loaded = Simulation.fromSnapshot(sim:snapshot())
    expect(loaded.combat.stealthed, "stealthed combat should survive snapshot")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(95)
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.startExpedition("archive_scout"))
    sim.expedition.supplies:add("bait_chime", 1)
    local noise = sim.expedition.noise
    runQueued(sim, Simulation.commands.useItem("bait_chime", 1))
    expect(sim.expedition.clearedEncounters.archive_sentinel and sim.expedition.noise > noise, "bait chime should lure one visible threat and raise noise")
    expect(sim.expedition.supplies:count("bait_chime") == 0, "bait chime should be consumed when it lures")
    local objects = sim:objectsInRect(24, 24, 5, 5, 0)
    expect(sim.expedition.alphaMarkers.red_indexer and sim.expedition.alphaMarkers.red_indexer.roomKey == "24:6", "alpha marker should appear when alpha is visible")
    expect(objects[1].tooltip == Defs.scoutTooltip("scout_odds_tooltip").high, "visible threat should expose scout odds tooltip")
    sim.expedition.scoutedRooms["24:6"] = true
    expect(sim:scoutOddsTooltip("24:6") == Defs.scoutTooltip("scout_odds_tooltip").low, "scouted room should expose reduced odds copy")
    local loaded = Simulation.fromSnapshot(sim:snapshot())
    expect(loaded.expedition.alphaMarkers.red_indexer.roomKey == "24:6", "alpha marker should survive snapshot")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(97)
    expect(sim:itemTooltip("bandage"):find("injury", 1, true) ~= nil and sim:itemTooltip("ward_charm"):find("resolve", 1, true) ~= nil, "provision tooltip should expose injury cure copy")
    sim.expedition.noise = 5
    placeCampMarker(sim)
    runQueued(sim, Simulation.commands.camp())
    expect(sim.expedition.noise == 3, "camp should decay noise")
    sim = Simulation.new(98)
    sim.expedition.noise = 5
    sim.expedition.torch = 60
    sim.expedition.supplies:add("torch", 1)
    runQueued(sim, Simulation.commands.useItem("torch", 1))
    expect(sim.expedition.torch >= 75 and sim.expedition.noise == 4, "high torch should decay noise")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(99)
    sim.expedition.noise = 12
    placeCampMarker(sim)
    runQueued(sim, Simulation.commands.camp())
    runQueued(sim, Simulation.commands.finishCamp())
    expect(sim.mode == "combat" and sim.combat.encounter == "archive_ambush" and sim.combat.pressure and sim.combat.ambush, "high noise should trigger camp ambush")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(2)
    local roomKey = sim:currentRoomKey()
    sim.expedition.torch = 0
    sim.expedition.noise = 12
    sim.expedition.threatState[roomKey] = "stalked"
    expect(sim:tryStartPressureEncounter(roomKey), "low light and noise should trigger deterministic archive pressure")
    expect(sim.mode == "combat" and sim.combat.encounter == "archive_ambush" and sim.combat.pressure and sim.combat.ambush, "pressure encounter should start ambush combat")
    local noisy = Simulation.new(7)
    noisy.expedition.torch = 0
    noisy.expedition.noise = 12
    noisy.expedition.threatState.ghost = "stalked"
    expect(noisy:tryStartPressureEncounter("ghost"), "unscouted pressure should be dangerous")
    local scouted = Simulation.new(7)
    scouted.expedition.torch = 0
    scouted.expedition.noise = 12
    scouted.expedition.threatState.ghost = "stalked"
    scouted.expedition.scoutedRooms.ghost = true
    expect(not scouted:tryStartPressureEncounter("ghost"), "scouting should reduce deterministic ambush pressure")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(95)
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.startExpedition("archive_scout"))
    expect(sim:startCombat("archive_elite", "weakpoint_test"), "archive elite should start")
    local enemy = sim:enemyAtRank(1)
    enemy.parts[1].hp = 1
    expect(enemy.parts[1].key == "open_codex", "elite should expose weak point data")
    runQueued(sim, Simulation.commands.combatSkill("razor_lunge", 1, "enemy", "open_codex"))
    expect(enemy.parts[1].disabled and sim:enemySkillLocked(enemy, "lectern_cant"), "weak point hit should disable mapped skill")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(100)
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.startExpedition("archive_scout"))
    expect(sim:startCombat("archive_elite", "weakpoint_chain"), "archive elite should start for chain test")
    local enemy = sim.combat.enemies[1]
    expect(sim:damageEnemyPart(enemy, "open_codex", 99), "first weak point should disable")
    expect(sim.status:find("Lectern Cant", 1, true) ~= nil, "weak point log should name disabled skill")
    expect(sim:damageEnemyPart(enemy, "bone_clasp", 99), "second weak point should disable")
    expect(sim:hasStatus(enemy, "daze") and enemy.weakPointChainTurns == 1, "two broken weak points should chain daze")
    local loaded = Simulation.fromSnapshot(sim:snapshot())
    expect(loaded.combat.enemies[1].weakPointChainTurns == 1, "weak point chain should survive snapshot")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(105)
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.startExpedition("archive_witness_confession"))
    expect(sim:startCombat("archive_witness", "support_test"), "archive witness support combat should start")
    local witness = sim.combat.enemies[1]
    local ally = sim.combat.enemies[2]
    ally.stress = 5
    sim:enemyTurn(witness)
    expect(ally.stress < 5, "pressed witness should restore adjacent enemy stress damage")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(106)
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.startExpedition("archive_scout"))
    expect(sim:startCombat("archive_elite", "support_repair"), "archive elite should start for repair test")
    local enemy = sim.combat.enemies[1]
    local support = sim.combat.enemies[2]
    sim:damageEnemyPart(enemy, "open_codex", 99)
    expect(enemy.parts[1].disabled, "weak point should be disabled before repair")
    sim:enemyTurn(support)
    expect(not enemy.parts[1].disabled and enemy.parts[1].hp > 0 and sim.combat.partRepaired, "support should repair one disabled weak point once")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(107)
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.startExpedition("archive_scout"))
    expect(sim:startCombat("archive_alpha", "shelf_warden", { visible = true, threatKey = "shelf_warden" }), "alpha combat should start")
    sim:finishCombat(true)
    expect(sim.expedition.loot:count("coin") == 80 and sim.expedition.loot:count("heirloom") == 2, "alpha victory should add alpha reward")
    local alphaCoin = sim.expedition.loot:count("coin")
    local alphaHeirloom = sim.expedition.loot:count("heirloom")
    sim = Simulation.new(128)
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.startExpedition("archive_regent"))
    expect(sim:startCombat("regent", "24:0"), "boss combat should start for reward comparison")
    sim:finishCombat(true)
    expect(alphaCoin <= sim.expedition.loot:count("coin") and alphaHeirloom <= sim.expedition.loot:count("heirloom"), "alpha reward should not exceed boss reward")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(96)
    local hero = sim:heroAtRank(1)
    sim:resolveCurio(4, 0, 0, "wire_snare", { forceNoItem = true })
    expect(sim:hasInjury(hero), "trap should apply expedition injury")
    local loaded = Simulation.fromSnapshot(sim:snapshot())
    expect(loaded:hasInjury(loaded:heroById(hero.id)), "injury should survive snapshot")
    sim.expedition.supplies:add("bandage", 1)
    runQueued(sim, Simulation.commands.useItem("bandage", 1))
    expect(not sim:hasInjury(hero), "bandage should clear one injury")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(129)
    local hero = sim:heroAtRank(1)
    for _, injuryKey in ipairs({ "crushed_hand", "salt_bloat", "glass_scarring", "nerve_burn" }) do
        hero.statuses = {}
        expect(sim:addInjury(hero, injuryKey) and sim:hasInjury(hero, injuryKey), "new injury should apply " .. injuryKey)
    end
    hero.statuses = {}
    sim:addInjury(hero, "crushed_hand")
    sim.expedition.supplies:add("salve", 1)
    runQueued(sim, Simulation.commands.useItem("salve", 1))
    expect(not sim:hasInjury(hero, "crushed_hand"), "salve should clear one injury")
    sim:addInjury(hero, "salt_bloat")
    sim.expedition.supplies:add("bandage", 1)
    runQueued(sim, Simulation.commands.useItem("bandage", 1))
    expect(not sim:hasInjury(hero, "salt_bloat"), "bandage should clear one injury")
    sim:addInjury(hero, "glass_scarring")
    placeCampMarker(sim)
    expect(sim:camp() and not sim:hasInjury(hero, "glass_scarring"), "camp should clear one injury")
    sim:endExpedition(true)
    sim:addInjury(hero, "nerve_burn")
    sim.estate.gold = 100
    runQueued(sim, Simulation.commands.recoverHero(hero.id))
    expect(not sim:hasInjury(hero, "nerve_burn"), "estate recovery should clear injuries")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(21)
    sim.player.x = 3
    sim.player.y = 0
    sim.player.facing = "east"
    local bandages = sim.expedition.supplies:count("bandage")
    runQueued(sim, Simulation.commands.interact())
    expect(sim.expedition.curiosUsed["0:4:0"], "trap curio should be marked used")
    expect(sim.expedition.supplies:count("bandage") == bandages - 1, "trap should consume bandage")
    expect(sim.world:getTile(4, 0, 0).id == "archive_floor", "resolved curio should clear tile")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(22)
    sim.player.x = 15
    sim.player.y = 0
    sim.player.facing = "east"
    runQueued(sim, Simulation.commands.interact())
    expect(sim.expedition.loot:count("relic") == 2, "keyed cache should grant relics")
    expect(sim.expedition.loot:count("coin") == 45, "keyed cache should grant coin")
    expect(sim.expedition.supplies:count("skeleton_key") == 0, "cache should consume key")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(122)
    sim.player.x = 15
    sim.player.y = 0
    sim.player.facing = "east"
    runQueued(sim, Simulation.commands.interact())
    expect(sim:hasDocument("archive_writ_01"), "curio document drop should collect first archive writ")
    local journal = sim:journalEntries()
    expect(journal[1].key == "archive_writ_01" and journal[1].abstract ~= "", "journal should list collected document abstracts")
    expect(sim.documentPopup and sim.documentPopup.key == "archive_writ_01", "document popup should track found fragment")
    expect(sim.status:find("clerk", 1, true) ~= nil or sim.status:find("Clerk", 1, true) ~= nil, "document collection should trigger fixture bark")
    local loaded = Simulation.fromSnapshot(sim:snapshot())
    expect(loaded:hasDocument("archive_writ_01") and loaded:journalEntries()[1].key == "archive_writ_01" and loaded.documentPopup.key == "archive_writ_01", "journal should survive snapshot")
    local fresh = Simulation.new(122)
    expect(not fresh:hasDocument("archive_writ_01") and #fresh:journalEntries() == 0, "new campaign should start with empty document journal")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(126)
    expect(sim:missionIntro("archive_scout").brief:find("three rooms", 1, true) and sim:missionIntro("archive_scout").sting ~= "", "mission intro copy should be readable")
    expect(sim:missionIntro("archive_cleansing").brief:find("two hostile", 1, true), "cleanse intro should be mission-specific")
    expect(sim:missionIntro("archive_gather").brief:find("two torn folios", 1, true), "gather intro should be mission-specific")
    expect(sim:curioCopy("relic_cache").observe and sim:curioCopy("relic_cache").result, "curio copy should be readable")
    expect(sim:bestiaryEntry("ossuary_lectern").weakPointHint:find("weak points", 1, true) ~= nil, "bestiary weak-point hint should be readable")
    expect(#sim:glossaryEntries() == 6 and sim:panelCopy("timer_panel_copy").body and sim:endingScreenCopy("estate_seal"), "glossary and panel copy should be readable")
    expect(sim:originBark("warden", "arrival") ~= nil, "origin bark should be readable")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(23)
    local hero = sim:heroAtRank(2)
    hero.hp = hero.hp - 5
    hero.stress = 20
    sim.player.x = 8
    sim.player.y = 5
    sim.player.facing = "south"
    runQueued(sim, Simulation.commands.interact())
    expect(sim.expedition.campUsed, "camp marker interaction should camp")
    expect(sim.expedition.camping and sim.expedition.camping.respite == 4, "camp should enter respite phase")
    expect(hero.hp > 15 and hero.stress < 20, "camp should heal hp and stress")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(40)
    placeCampMarker(sim)
    runQueued(sim, Simulation.commands.camp())
    local x = sim.player.x
    runQueued(sim, Simulation.commands.move("east"))
    expect(sim.player.x == x, "camping should block movement")
    local hero = sim:heroAtRank(2)
    hero.hp = hero.hp - 8
    hero.stress = 20
    hero.statuses[#hero.statuses + 1] = { kind = "bleed", amount = 1, turns = 3 }
    runQueued(sim, Simulation.commands.campSkill("watch_order"))
    expect(sim.expedition.camping.respite == 2 and sim.expedition.camping.ambushPrevented, "watch order should spend respite and prevent ambush")
    runQueued(sim, Simulation.commands.campSkill("bind_wounds", 2))
    expect(not sim.expedition.camping, "spending all respite should finish camp")
    expect(hero.hp > 14 and hero.stress < 20, "bind wounds should restore target")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(41)
    placeCampMarker(sim)
    runQueued(sim, Simulation.commands.camp())
    local hero = sim:heroAtRank(1)
    hero.statuses[#hero.statuses + 1] = { kind = "bleed", amount = 1, turns = 3 }
    runQueued(sim, Simulation.commands.campSkill("bitter_tonic", 1))
    expect(#hero.statuses == 0 and sim.expedition.camping.respite == 3, "bitter tonic should clear bleed and spend one respite")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(24)
    sim.expedition.torch = 40
    runQueued(sim, Simulation.commands.useItem("torch"))
    expect(sim.expedition.torch == 65, "torch should add light")
    expect(sim.expedition.supplies:count("torch") == 3, "torch should consume supply")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(25)
    reachEntryCombat(sim)
    sim:finishCombat(true)
    expect(sim.mode == "expedition", "victory should return to expedition")
    expect(sim.expedition.clearedEncounters["8:0"], "victory should clear room encounter")
    expect(sim.expedition.loot:count("coin") > 0, "victory should grant loot")
    expect(sim:hasDocument("archive_writ_01"), "room loot victory should drop an archive document")
    expect(sim.narration:find("Extraction", 1, true) ~= nil, "normal victory should use extraction result voice")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(123)
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.startExpedition("archive_silence_reeve"))
    expect(sim:startCombat("archive_reeve", "8:6"), "archive warden combat should start")
    expect(Defs.enemy(sim.combat.enemies[1].kind).alpha and Defs.enemy(sim.combat.enemies[1].kind).warden, "archive warden should be visible alpha class")
    expect(sim.narration:find("Reeve", 1, true) ~= nil, "warden start should use warden voice")
    sim:finishCombat(true)
    expect(sim:hasDocument("archive_writ_01"), "archive warden should drop archive document")
    expect(sim.expedition.clearedEncounters["8:6"], "warden defeat should clear zone encounter")
    expect(sim.narration:find("Reeve", 1, true) ~= nil, "warden defeat should use warden voice")
    sim = Simulation.new(124)
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.startExpedition("cistern_silence_choir"))
    expect(sim:startCombat("cistern_choir", "6:10"), "cistern warden combat should start")
    sim:finishCombat(true)
    expect(sim:hasDocument("cistern_valve_01"), "cistern warden should drop valve schematic")
    sim = Simulation.new(125)
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.startExpedition("warrens_douse_vicar"))
    expect(sim:startCombat("ember_vicar", "8:-8"), "warrens warden combat should start")
    sim:finishCombat(true)
    expect(sim:hasDocument("warrens_confession_01"), "warrens warden should drop penitent confession")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(127)
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.startExpedition("archive_scout"))
    expect(sim.narration:find("Archive", 1, true) ~= nil, "location bark should match archive")
    sim.expedition.torch = 0
    sim:checkDarkness()
    expect(sim.narration:find("shelves", 1, true) ~= nil, "low torch voice should match archive")
    placeCampMarker(sim)
    sim:camp()
    expect(sim.narration:find("Rest", 1, true) ~= nil or sim.narration:find("fire", 1, true) ~= nil, "camp should use complicity voice")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(54)
    sim.expedition.packSlots = 1
    expect(sim:addLoot("coin", 10), "first loot stack should fit")
    expect(sim:addLoot("coin", 5), "existing loot stack should ignore slot limit")
    expect(not sim:addLoot("heirloom", 1), "new loot stack should fail when pack is full")
    expect(sim.expedition.loot:count("coin") == 15 and sim.expedition.loot:count("heirloom") == 0, "pack full should preserve loot counts")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(221)
    sim:endExpedition(true)
    sim:heroAtRank(1).class = "merchant"
    sim.estate.campaign.dread = 9
    runQueued(sim, Simulation.commands.startExpedition("archive_scout"))
    expect(sim.expedition.packSlots == 13 and sim.expedition.merchantCutPackApplied, "merchant cut should add pack slot at dread tier two")
    local loaded = Simulation.fromSnapshot(sim:snapshot())
    expect(loaded.expedition.packSlots == 13 and loaded.expedition.merchantCutPackApplied, "merchant pack cut should survive snapshot")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(222)
    sim:endExpedition(true)
    sim:heroAtRank(1).class = "merchant"
    sim.estate.campaign.dreadLimit = 20
    sim.estate.campaign.dread = 20
    runQueued(sim, Simulation.commands.startExpedition("archive_scout"))
    expect(sim:startCombat("entry", "merchant_cut_1"), "merchant cut test combat should start")
    sim:finishCombat(true)
    expect(sim.expedition.loot:count("coin") == 60 and sim.expedition.loot:count("relic") == 1 and sim.expedition.merchantCutLootClaimed, "merchant cut should add one room-loot bonus")
    expect(sim:startCombat("entry", "merchant_cut_2"), "merchant cut repeat combat should start")
    sim:finishCombat(true)
    expect(sim.expedition.loot:count("coin") == 95 and sim.expedition.loot:count("relic") == 1, "merchant cut should only pay once per expedition")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(223)
    sim.estate.graveyard = { { id = 1, name = "Leto", class = "merchant" } }
    local journal = Render.journalSummary(sim)
    expect(journal.epitaphs[1].className == "Merchant" and journal.epitaphs[1].epitaph:find("ledger", 1, true), "merchant graveyard should use class epitaph")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(26)
    sim.expedition.roomsScouted = 3
    sim.expedition.objectiveComplete = true
    sim.expedition.loot:add("coin", 50)
    sim.player.x = -2
    sim.player.y = 1
    sim.player.facing = "south"
    runQueued(sim, Simulation.commands.interact())
    expect(sim.mode == "estate", "exit should end completed expedition")
    expect(sim.estate.gold >= 260, "completed expedition should transfer loot and mission reward after town event")
    expect(sim.estate.heirlooms == 1, "completed expedition should pay mission heirloom reward")
    expect(sim.estate.currentEvent, "expedition return should roll town event")
    expect(sim.estate.campaign.renown == 1 and sim.estate.campaign.completedMissions.archive_scout, "completed mission should advance campaign")
    expect(sim.estate.campaign.locationProgress.buried_archive == 1, "completed mission should advance location progress")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(42)
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.startExpedition("archive_cleansing"))
    expect(sim.expedition.mission == "archive_cleansing", "start expedition should accept mission key")
    expect(not sim.expedition.objectiveComplete, "cleanse mission should start incomplete")
    expect(sim:missionProgressText():find("rooms cleared 0/2", 1, true), "cleanse mission should expose polished progress text")
    expect(sim:objectiveChecklist()[1].items[1].next:find("Win 2 fights", 1, true), "cleanse mission should expose next-step copy")
    sim:startCombat("entry", "8:0")
    sim:finishCombat(true)
    expect(not sim.expedition.objectiveComplete, "one cleared encounter should not complete cleanse mission")
    sim:startCombat("stacks", "16:0")
    sim:finishCombat(true)
    expect(sim.expedition.objectiveComplete, "two cleared encounters should complete cleanse mission")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(132)
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.startExpedition("archive_names"))
    expect(sim:missionIntro("archive_names").brief:find("sealed names", 1, true), "names intro should be mission-specific")
    expect(sim:missionProgressText():find("sealed names recovered 0/2", 1, true), "names mission should expose polished progress text")
    expect(sim:objectiveChecklist()[1].items[1].next:find("Recover 2 sealed names", 1, true), "names mission should expose next-step copy")
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.startExpedition("archive_false_index"))
    expect(sim:missionIntro("archive_false_index").brief:find("false index", 1, true), "false index intro should be mission-specific")
    expect(sim:missionProgressText():find("false index burned 0/1", 1, true), "false index mission should expose polished progress text")
    expect(sim:objectiveChecklist()[1].items[1].next:find("Use the False Index Writ", 1, true), "false index mission should expose next-step copy")
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.startExpedition("archive_page_bearer"))
    expect(sim:missionIntro("archive_page_bearer").brief:find("Page-Bearer", 1, true), "page-bearer intro should be mission-specific")
    expect(sim:missionProgressText():find("page-bearer escorted 0/1", 1, true), "page-bearer mission should expose polished progress text")
    expect(sim:objectiveChecklist()[1].items[1].next:find("Escort the Page%-Bearer", 1, false), "page-bearer mission should expose next-step copy")
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.startExpedition("archive_intake_map"))
    expect(sim:missionIntro("archive_intake_map").brief:find("intake rooms", 1, true), "intake map intro should be mission-specific")
    expect(sim:missionProgressText():find("intake rooms mapped 1/4", 1, true), "intake map mission should expose polished progress text")
    expect(sim:objectiveChecklist()[1].items[1].next:find("Scout 4 intake rooms", 1, true), "intake map mission should expose next-step copy")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(133)
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.startExpedition("archive_audit_page_bearer"))
    expect(sim:missionIntro("archive_audit_page_bearer").brief:find("Page-Bearer", 1, true), "audit page-bearer intro should be mission-specific")
    expect(sim:missionProgressText():find("page-bearer audited 0/1", 1, true), "audit page-bearer mission should expose polished progress text")
    expect(sim:objectiveChecklist()[1].items[1].next:find("audit noise", 1, true), "audit page-bearer mission should expose next-step copy")
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.startExpedition("archive_silence_reeve"))
    expect(sim:missionIntro("archive_silence_reeve").brief:find("Codex Reeve", 1, true), "reeve intro should be mission-specific")
    expect(sim:missionProgressText():find("codex reeve silenced 0/1", 1, true), "reeve mission should expose polished progress text")
    expect(sim:objectiveChecklist()[1].items[1].next:find("Defeat the Codex Reeve", 1, true), "reeve mission should expose next-step copy")
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.startExpedition("archive_witness_confession"))
    expect(sim:missionIntro("archive_witness_confession").brief:find("sealed confession", 1, true), "confession intro should be mission-specific")
    expect(sim:missionProgressText():find("confession witnessed 0/2", 1, true), "confession mission should expose polished progress text")
    expect(sim:objectiveChecklist()[1].items[1].next:find("Survive 2 sealed confession fights", 1, true), "confession mission should expose next-step copy")
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.startExpedition("archive_remand_scribe"))
    expect(sim:missionIntro("archive_remand_scribe").brief:find("Bound Scribe", 1, true), "remand scribe intro should be mission-specific")
    expect(sim:missionProgressText():find("bound scribe remanded 0/1", 1, true), "remand scribe mission should expose polished progress text")
    expect(sim:objectiveChecklist()[1].items[1].next:find("bound scribe's docket", 1, true), "remand scribe mission should expose next-step copy")
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.startExpedition("archive_regent"))
    expect(sim:missionIntro("archive_regent").brief:find("Vault Regent", 1, true), "regent intro should be mission-specific")
    expect(sim:missionProgressText():find("vault regent silenced 0/1", 1, true), "regent mission should expose polished progress text")
    expect(sim:objectiveChecklist()[1].items[1].next:find("Defeat the Vault Regent", 1, true), "regent mission should expose next-step copy")
end

tests[#tests + 1] = function()
    local sim = Simulation.newEstate(1)
    expect(sim.mode == "estate" and not sim.expedition, "playtest should reach estate from initial title handoff")
    expect(sim.estate.recruits[1] ~= nil, "playtest should offer a reserve recruit")
    runQueued(sim, Simulation.commands.recruitHero(1))
    local classes = {}
    for _, hero in ipairs(sim:partyState()) do
        classes[hero.classId] = true
    end
    expect(classes.warden and classes.duelist and classes.mender and classes.harrier and not classes.arcanist, "playtest party should use Warden/Duelist/Apothecary/Thief")
    runQueued(sim, Simulation.commands.startExpedition("archive_scout"))
    expect(sim.expedition.mission == "archive_scout", "playtest should enter first archive mission")
    expect(not sim:camp(), "playtest should reject camping away from a cold camp")
    walkSteps(sim, "east", 8)
    walkSteps(sim, "south", 6)
    runQueued(sim, Simulation.commands.camp())
    expect(sim.expedition.campUsed and sim.expedition.camping, "playtest should camp mid-mission")
    runQueued(sim, Simulation.commands.campSkill("watch_order", 1))
    runQueued(sim, Simulation.commands.finishCamp())
    expect(not sim.expedition.camping and sim.mode == "expedition", "playtest should leave camp without ambush")
    expect(sim.expedition.roomsScouted >= 3 and sim:updateObjective(), "playtest should complete first mission objective by scouting")
    runQueued(sim, Simulation.commands.endExpedition(false))
    expect(sim.mode == "estate" and sim.estate.campaign.completedMissions.archive_scout, "playtest should return after first mission")
    local reserve
    for _, hero in ipairs(sim.estate.roster) do
        if not sim:heroRank(hero.id) then
            reserve = hero
            break
        end
    end
    expect(reserve ~= nil, "playtest should have reserve hero for recovery")
    reserve.stress = 40
    runQueued(sim, Simulation.commands.recoverHero(reserve.id))
    expect(reserve.recovering == 1, "playtest should send reserve to recovery")
    runQueued(sim, Simulation.commands.startExpedition("archive_cleansing"))
    expect(sim.mode == "expedition" and sim.expedition.mission == "archive_cleansing", "playtest should enter second mission")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(43)
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.startExpedition("archive_regent"))
    sim:startCombat("regent", "24:0")
    sim:finishCombat(true)
    expect(sim.expedition.objectiveComplete and sim.expedition.bossDefeated, "boss mission should complete on regent victory")
    sim.player.x = -2
    sim.player.y = 1
    sim.player.facing = "south"
    runQueued(sim, Simulation.commands.interact())
    expect(sim.estate.trinkets.quiet_bell >= 1 and sim.estate.gold >= 320, "boss mission should pay reward")
    expect(sim.estate.campaign.bossKills.buried_archive and sim.estate.campaign.locationProgress.buried_archive == 2, "boss mission should mark location boss progress")
    expect(sim.estate.currentEvent == "merchant_ledger_offer" and sim.estate.campaign.flags.merchant_ledger_accepted, "regent return should trigger merchant ledger event")
    expect(sim:classUnlocked("merchant") and sim.estate.recruits[1].class == "merchant", "merchant ledger should unlock and seed recruit")
    expect(sim.events[#sim.events].event == "merchant_unlock", "merchant ledger should emit cutscene event")
    expect(sim.narration ~= "", "boss return should keep narration")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(84)
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.startExpedition("archive_regent"))
    expect(sim:startCombat("regent", "24:0"), "regent polish combat should start")
    local enemy = sim.combat.enemies[1]
    expect(enemy.bossPhase == "edict" and enemy.nextBossSkill == "regent_sentence", "regent should open in readable edict phase")
    expect(enemy.parts[1].hint:find("Regent Sentence", 1, true) and enemy.parts[2].hint:find("Censer Wail", 1, true), "regent weak points should expose skill-lock hints")
    local startLog = table.concat(sim.log, "\n")
    expect(startLog:find("weak points", 1, true) and startLog:find("Edict Phase", 1, true), "regent start should announce weak points and phase")
    expect(sim.narration:find("crown is the hinge", 1, true), "regent opening should set dialogue")
    sim:damageEnemyPart(enemy, "edict_crown", 99)
    expect(enemy.bossPhase == "choir" and enemy.nextBossSkill == "censer_wail", "regent should shift phase when a weak point breaks")
    expect(sim.narration:find("chain answers", 1, true), "regent weak-point phase should set dialogue")
    enemy.hp = 10
    sim:applyBossPhase(enemy, false)
    expect(enemy.bossPhase == "remand" and enemy.nextBossSkill == "regent_sentence", "regent should enter low-hp remand phase")
    local loaded = Simulation.fromSnapshot(sim:snapshot())
    expect(loaded.combat.enemies[1].bossPhase == "remand" and loaded.combat.enemies[1].parts[1].hint:find("Regent Sentence", 1, true), "regent phase and weak-point hints should survive snapshot")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(85)
    sim:endExpedition(true)
    sim.estate.campaign.dread = 4
    runQueued(sim, Simulation.commands.startExpedition("archive_regent"))
    expect(sim:startCombat("regent", "24:0"), "variant boss combat should start")
    expect(sim.combat.encounter == "regent_crowned" and sim.combat.baseEncounter == "regent", "high dread should select boss variant")
    expect(sim.combat.enemies[1].bossPhase == "red" and sim.combat.enemies[1].parts[1].hint:find("Red Stress Clause", 1, true), "high dread regent should expose red phase and weak-point hints")
    local loaded = Simulation.fromSnapshot(sim:snapshot())
    expect(loaded.combat.encounter == "regent_crowned" and loaded.combat.baseEncounter == "regent", "boss variant should survive snapshot")
    sim:finishCombat(true)
    expect(sim.expedition.objectiveComplete and sim.world:getTile(24, 0, 0).id == "archive_floor", "boss variant should complete and clear base sigil")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(66)
    sim:endExpedition(true)
    local heirlooms = sim.estate.heirlooms
    for _, missionKey in ipairs({ "archive_regent", "cistern_bell", "ember_prioress" }) do
        sim:startExpedition(missionKey)
        sim.expedition.objectiveComplete = true
        sim.expedition.bossDefeated = true
        sim:endExpedition(false)
    end
    expect(sim.estate.campaign.victory and sim.estate.campaign.renown == 6, "all boss wins should complete campaign arc")
    expect(sim.estate.campaign.finalSeal and sim.estate.heirlooms >= heirlooms + 3 and sim.estate.trinkets.scribe_wax >= 1, "campaign victory should grant final seal reward")
    local loaded = Simulation.fromSnapshot(sim:snapshot())
    expect(loaded.estate.campaign.victory and loaded.estate.campaign.finalSeal and loaded.estate.campaign.bossKills.ember_warrens and loaded.narration ~= "", "campaign snapshot should preserve boss wins")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(83)
    placeCampMarker(sim)
    sim:camp()
    local summary = Render.campHudSummary(sim, {})
    expect(summary.active and #summary.skills == 9 and summary.partyCount == 4, "camp hud summary should expose skills and party")
    local app = {
        ui = {
            campSkillButtons = { { x = 0, y = 0, w = 20, h = 20, skillKey = "bind_wounds", target = "ally" } },
            campHeroButtons = { { x = 30, y = 0, w = 20, h = 20, rank = 2 } },
        },
    }
    Input.mousepressed(sim, app, 5, 5, 1)
    expect(app.pendingCampSkillKey == "bind_wounds", "camp skill click should wait for hero target")
    Input.mousepressed(sim, app, 35, 5, 1)
    sim:step()
    expect(app.pendingCampSkillKey == nil and sim.expedition.camping.usedSkills.bind_wounds, "camp hero click should assign pending skill")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(82)
    sim.player.facing = "east"
    sim.world:setTile(sim.player.x + 1, sim.player.y, sim.player.z, { id = "salt_font", data = 0 })
    local modal = Render.curioModalForTarget(sim)
    expect(modal and modal.key == "salt_font" and #modal.choices == 4, "curio modal should expose four choices")
    expect(modal.choices[1].key == "safe_use" and modal.choices[4].key == "leave_alone", "curio modal should order choices")
    local app = { audio = {}, curioModal = modal, ui = { curioButtons = { { x = 0, y = 0, w = 20, h = 20, choice = "greedy_use", enabled = true } } } }
    Input.mousepressed(sim, app, 5, 5, 1)
    sim:step()
    expect(app.curioResult and next(sim.expedition.curiosUsed) ~= nil, "curio choice should resolve and reveal result")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(81)
    reachEntryCombat(sim)
    local summary = Render.combatHudSummary(sim, { pendingSkillKey = "arterial_cut", pendingTargetSide = "enemy" })
    expect(summary.mode == "combat" and #summary.turns == 6, "combat hud summary should expose turn order")
    expect(summary.active:find("R", 1, true), "combat hud summary should expose active rank")
    expect(summary.skill == "arterial_cut" and summary.target == "enemy", "combat hud summary should expose target picker")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(80)
    local summary = Render.expeditionHudSummary(sim)
    expect(summary.torch == sim.expedition.torch, "hud summary should expose torch level")
    expect(summary.currentRoom == sim:currentRoomKey(), "hud summary should expose current room")
    expect(summary.partyCount == 4, "hud summary should expose party count")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(79)
    sim:endExpedition(true)
    sim.estate.campaign.deathLimit = 1
    local hero = sim:heroAtRank(1)
    hero.deathsDoor = true
    hero.deathblowResist = 0
    sim:damageHero(hero, hero.hp + 1)
    expect(sim.estate.campaign.lost and sim.estate.campaign.lossReason == "deaths", "death limit should collapse campaign")
    local loaded = Simulation.fromSnapshot(sim:snapshot())
    expect(loaded.estate.campaign.lost and loaded.estate.campaign.lossReason == "deaths", "campaign loss should survive snapshot")
    expect(not sim:startExpedition("archive_scout"), "collapsed campaign should block new expeditions")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(80)
    sim:endExpedition(true)
    sim.estate.campaign.weekLimit = sim.estate.week
    runQueued(sim, Simulation.commands.advanceWeek())
    expect(sim.estate.campaign.lost and sim.estate.campaign.lossReason == "weeks" and sim.estate.campaign.endingRoute == "quiet_failure", "week limit should collapse campaign to quiet failure")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(81)
    sim:endExpedition(true)
    sim.estate.campaign.dreadLimit = 2
    sim.estate.campaign.dread = 2
    sim:evaluateCampaignState()
    expect(sim.estate.campaign.lost and sim.estate.campaign.lossReason == "dread" and sim.estate.campaign.endingRoute == "extraction_collapse", "dread limit should collapse campaign to extraction collapse")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(82)
    sim:endExpedition(true)
    sim.estate.campaign.victory = true
    sim.estate.campaign.deathLimit = 0
    sim.estate.campaign.weekLimit = 0
    sim.estate.campaign.dreadLimit = 0
    runQueued(sim, Simulation.commands.advanceWeek())
    expect(sim.estate.campaign.victory and not sim.estate.campaign.lost, "victory should disable collapse limits")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(117)
    expect(sim.estate.campaign.weekLimit == 14 and sim.estate.campaign.dreadLimit == 18, "campaign should use twin timer caps")
    expect(sim:factionState("faction_custodians") == "neutral" and sim:factionState("enclave_meter") == "neutral", "campaign should seed faction meters")
    sim:endExpedition(true)
    sim.estate.heirlooms = 3
    sim.estate.campaign.dread = 5
    sim:applyTownEvent("archive_tithe_v2")
    expect(sim.estate.heirlooms == 2 and sim.estate.campaign.dread == 3, "archive tithe should trade heirloom for dread reduction")
    sim:applyTownEvent("pyre_demand")
    expect(contains(sim.estate.missionBoard, "warrens_douse_vicar") and sim:factionState("faction_ember_penitents") == "vigil_called", "pyre demand should open warrens douse and raise faction tension")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(131)
    sim:endExpedition(true)
    sim:adjustFaction("faction_custodians", 2)
    expect(sim:factionState("faction_custodians") == "audit_alert", "custodians should enter audit alert")
    sim:adjustFaction("faction_custodians", 2)
    expect(sim:factionState("faction_custodians") == "hostile", "custodians should enter hostile")
    sim:adjustFaction("faction_cistern_keepers", 2)
    expect(sim:factionState("faction_cistern_keepers") == "flood_held", "cistern keepers should hold flood")
    sim:adjustFaction("faction_cistern_keepers", 2)
    expect(sim:factionState("faction_cistern_keepers") == "embargo", "cistern keepers should embargo")
    sim:adjustFaction("faction_ember_penitents", 2)
    expect(sim:factionState("faction_ember_penitents") == "vigil_called", "ember penitents should call vigil")
    sim:adjustFaction("faction_ember_penitents", 2)
    expect(sim:factionState("faction_ember_penitents") == "pyre_open", "ember penitents should open pyre")
    sim:adjustFaction("faction_lamplighters", -2)
    expect(sim:factionState("faction_lamplighters") == "full_torch", "lamplighters should grant full torch state")
    sim:adjustFaction("faction_lamplighters", 4)
    expect(sim:factionState("faction_lamplighters") == "strike", "lamplighters should strike")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(137)
    sim:endExpedition(true)
    for _, missionKey in ipairs(Defs.missionOrder) do
        local profile = sim:missionPressureProfile(Defs.mission(missionKey), true, false)
        expect(type(profile.dread) == "number" and next(profile.factions) ~= nil, missionKey .. " should expose mission pressure")
    end
    local extract = sim:missionPressureProfile(Defs.mission("archive_names"), true, false)
    expect(extract.factions.faction_custodians == 1 and extract.factions.enclave_meter == -1, "extract mission should pressure local faction and enclave")
    local repair = sim:missionPressureProfile(Defs.mission("archive_false_index"), true, false)
    expect(repair.dread == -1 and repair.factions.faction_custodians == -1 and repair.factions.enclave_meter == 1, "repair mission should reduce dread and local pressure")
    local boss = sim:missionPressureProfile(Defs.mission("archive_regent"), true, false)
    expect(boss.factions.faction_custodians == 2 and boss.factions.faction_lamplighters == -1, "boss mission should seal local pressure and steady lamplighters")
    sim:recordMissionOutcome(Defs.mission("archive_names"), true, false)
    expect((sim.estate.campaign.factions.faction_custodians.value or 0) == 1 and (sim.estate.campaign.factions.enclave_meter.value or 0) == -1, "mission pressure should apply faction deltas")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(138)
    sim:endExpedition(true)
    expect(sim:enclaveLeaderReaction("enclave_cael") == "Your name is still negotiable.", "neutral leader bark should use generic low line")
    sim:adjustFaction("faction_custodians", 2)
    expect(sim:enclaveLeaderReaction("enclave_cael") == "The enclave counts favors faster than weeks.", "tense leader bark should use generic tense line")
    sim:heroAtRank(1).class = "merchant"
    expect(sim:enclaveLeaderReaction("enclave_cael"):find("Merchant", 1, true), "merchant party should trigger faction-broker leader reaction")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(140)
    sim:endExpedition(true)
    local base = sim:endingScreenCopy("estate_seal")
    sim:heroAtRank(1).class = "merchant"
    local shifted = sim:endingScreenCopy("estate_seal")
    expect(shifted ~= base and shifted:find("Merchant", 1, true) and shifted:find("ledger", 1, true), "living merchant should shift ending copy")
    sim:heroAtRank(1).alive = false
    expect(sim:endingScreenCopy("estate_seal") == base, "dead merchant should not shift ending copy")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(118)
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.startExpedition("archive_false_index"))
    sim:resolveCurio(8, 2, 0, "false_index")
    sim:endExpedition(false)
    expect(sim.estate.campaign.flags.repairMissions >= 1 and (sim.estate.campaign.factions.enclave_meter.value or 0) > 0, "repair mission should record repair flag and enclave favor")
    runQueued(sim, Simulation.commands.startExpedition("archive_names"))
    sim:resolveCurio(0, 10, 0, "sealed_name")
    sim:resolveCurio(16, 1, 0, "sealed_name")
    sim:endExpedition(false)
    expect(sim.estate.campaign.flags.extractMissions >= 1 and sim.estate.campaign.flags.greedyExtracts >= 1, "extract mission should record extraction flags")
    local loaded = Simulation.fromSnapshot(sim:snapshot())
    expect(loaded.estate.campaign.flags.extractMissions == sim.estate.campaign.flags.extractMissions and loaded:factionState("faction_custodians") == sim:factionState("faction_custodians"), "campaign flags and factions should survive snapshot")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(119)
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.startExpedition("ember_vow_kilns"))
    sim.estate.campaign.dread = 4
    placeCampMarker(sim)
    expect(sim:camp(), "camp should start for ritual test")
    local torch = sim.expedition.supplies:count("torch")
    local ration = sim.expedition.supplies:count("ration")
    expect(sim:campSkill("camp_witness_vigil"), "witness vigil should run with supplies")
    expect(sim.estate.campaign.dread == 3 and sim.expedition.supplies:count("torch") == torch - 1 and sim.expedition.supplies:count("ration") == ration - 1, "witness vigil should spend supplies and lower dread")
    local hero = sim:heroAtRank(1)
    sim:contractDisease(hero, "brine_rot")
    expect(sim:campSkill("camp_salt_wash", 1) and #hero.diseases == 0, "salt wash should clear one disease")
    sim.expedition.heatFatigue = 3
    expect(sim:campSkill("camp_ember_quench") and sim.expedition.heatFatigue == 0 and not sim.expedition.camping, "ember quench should clear heat and spend final respite")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(219)
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.startExpedition("archive_scout"))
    placeCampMarker(sim)
    expect(sim:camp(), "merchant camp test should enter camp")
    for _, hero in ipairs(sim:livingParty()) do
        hero.stress = 20
    end
    local hero = sim:heroAtRank(1)
    hero.trinkets[1] = "ember_pin"
    sim.estate.trinkets.ember_pin = 0
    expect(sim:campSkill("audit_books"), "audit books should spend trinket")
    expect(hero.trinkets[1] == false and sim:heroAtRank(2).stress == 16, "audit books should consume carried trinket and heal party stress")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(220)
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.startExpedition("archive_scout"))
    placeCampMarker(sim)
    expect(sim:camp(), "cancel debt test should enter camp")
    local hero = sim:heroAtRank(1)
    hero.diseases = { "salt_cough" }
    sim:adjustFaction("enclave_meter", 3)
    expect(sim:campSkill("cancel_debt", 1), "cancel debt should run")
    expect(#hero.diseases == 0 and sim.estate.campaign.factions.enclave_meter.value == 1, "cancel debt should cure disease and spend enclave standing")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(120)
    sim:endExpedition(true)
    local hero = sim:heroAtRank(1)
    runQueued(sim, Simulation.commands.equipTrinket(hero.id, "ember_pin", 1))
    runQueued(sim, Simulation.commands.equipTrinket(hero.id, "cracked_lens", 2))
    expect(sim:heroModifier(hero, "heatResist") == 1 and sim:heroModifier(hero, "injuryVulnerability") == 5, "two-piece cinder set should activate with cost")
    sim.estate.trinkets.cinder_lens = 1
    sim.estate.trinkets.kiln_token = 1
    runQueued(sim, Simulation.commands.equipTrinket(sim:heroAtRank(2).id, "cinder_lens", 1))
    runQueued(sim, Simulation.commands.equipTrinket(sim:heroAtRank(3).id, "kiln_token", 1))
    expect(sim:heroModifier(hero, "burnDamage") == 2 and sim:heroModifier(hero, "heatResist") == 1, "four-piece cinder set should activate")
    sim.estate.gold = 100
    sim:applyTownEvent("salt_rationing")
    runQueued(sim, Simulation.commands.buyProvision("torch", 1))
    expect(sim.estate.gold == 90, "salt rationing should double provision cost")
    sim.estate.gold = 100
    hero.stress = 60
    sim:applyTownEvent("ash_vigil_demand")
    runQueued(sim, Simulation.commands.recoverHero(hero.id))
    expect(sim.estate.gold == 50, "ash vigil demand should double recovery cost")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(121)
    sim:endExpedition(true)
    sim.estate.week = 9
    expect(sim:lateWeekPressure() == 1, "week nine should start late pressure")
    sim.estate.week = 12
    expect(sim:lateWeekPressure() == 4, "late pressure should scale to cap")
    sim:adjustFaction("faction_lamplighters", 3)
    runQueued(sim, Simulation.commands.startExpedition("archive_scout"))
    expect(sim.expedition.torch == 60, "lamplighter strike should delay torch")
    sim:endExpedition(true)
    sim:adjustFaction("faction_ember_penitents", 4)
    runQueued(sim, Simulation.commands.startExpedition("ember_vow_kilns"))
    expect(sim.expedition.heatFatigue == 1, "pyre-open ember faction should add heat fatigue")
    sim:endExpedition(true)
    sim.estate.week = 10
    runQueued(sim, Simulation.commands.startExpedition("archive_scout"))
    expect(sim.expedition.latePressure == 2 and sim.expedition.noise >= 2, "late-week pressure should raise mission noise")
    local triggered = false
    for seed = 1, 40 do
        local pressure = Simulation.new(seed)
        pressure:endExpedition(true)
        pressure.estate.week = 12
        pressure:startExpedition("archive_scout")
        pressure.expedition.torch = 0
        pressure.expedition.threatState["0:0"] = "stalked"
        if pressure:tryStartPressureEncounter("0:0") then
            triggered = pressure.combat and pressure.combat.pressure and pressure.combat.ambush
            break
        end
    end
    expect(triggered, "late-week pressure should support archive ambush pressure")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(122)
    sim:endExpedition(true)
    expect(sim:resolveEndingRoute("victory") == "estate_seal", "default victory should route to estate seal")
    sim.estate.campaign.flags.repairMissions = 3
    expect(sim:resolveEndingRoute("victory") == "repair_compact", "repair-heavy victory should route to repair compact")
    sim.estate.campaign.flags.extractMissions = 4
    expect(sim:resolveEndingRoute("victory") == "estate_seal", "extract majority should keep victory on estate seal")
    sim.estate.campaign.flags.extractMissions = 0
    sim.estate.campaign.bossKills = { buried_archive = true, salt_cistern = true, ember_warrens = true }
    local routes = sim:endingRouteStatus()
    expect(#routes == 4 and routes[1].alias == "seal" and routes[2].alias == "repair", "ending route status should expose four route aliases")
    expect(sim:endingScreenCopy("repair_compact"):find("Repair Compact", 1, true), "repair route copy should be polished")
    sim.estate.campaign.dread = sim.estate.campaign.dreadLimit
    sim:evaluateCampaignState()
    expect(sim.estate.campaign.lost and sim.estate.campaign.endingRoute == "extraction_collapse", "dread cap should route to extraction collapse")
    sim = Simulation.new(130)
    sim:endExpedition(true)
    sim.estate.campaign.deathLimit = 0
    sim:evaluateCampaignState()
    expect(sim.estate.campaign.lost and sim.estate.campaign.endingRoute == "quiet_failure", "death cap should route to quiet failure")
    local summary = Render.gameOverSummary(sim)
    expect(summary.routeAlias == "quiet_failure" and summary.routeCondition:find("weeks", 1, true), "game over summary should expose route condition")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(56)
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.startExpedition("archive_gather"))
    expect(sim:missionProgressText():find("folios recovered 0/2", 1, true), "gather mission should expose polished progress text")
    expect(sim:objectiveChecklist()[1].items[1].next:find("Recover 2 archive pages", 1, true), "gather mission should expose next-step copy")
    sim:resolveCurio(8, 1, 0, "lost_page")
    expect(not sim.expedition.objectiveComplete and sim.expedition.loot:count("archive_page") == 1, "one gathered item should not complete gather mission")
    sim:resolveCurio(16, -1, 0, "lost_page")
    expect(sim.expedition.objectiveComplete and sim.expedition.loot:count("archive_page") == 2, "gather mission should complete after objective items")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(57)
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.startExpedition("cistern_valves"))
    expect(sim.expedition.supplies:count("valve_key") == 2, "activate mission should grant quest provisions")
    sim:resolveCurio(6, 5, 0, "tide_valve")
    expect(not sim.expedition.objectiveComplete and sim.expedition.questActivations == 1, "one activation should not complete activate mission")
    sim:resolveCurio(18, 5, 0, "tide_valve")
    expect(sim.expedition.objectiveComplete and sim.expedition.supplies:count("valve_key") == 0, "activate mission should consume provisions and complete")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(58)
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.startExpedition("ember_wards"))
    sim.expedition.supplies:consume("ember_oil", sim.expedition.supplies:count("ember_oil"))
    expect(not sim:resolveCurio(14, -3, 0, "ember_ward"), "activate curio should fail without quest item")
    expect(not sim.expedition.curiosUsed["0:14:-3"], "failed activation should not mark curio used")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(27)
    sim.expedition.loot:add("coin", 20)
    runQueued(sim, Simulation.commands.endExpedition(true))
    expect(sim.mode == "estate", "retreat end should return to estate")
    expect(sim.estate.gold >= 140, "retreat should transfer half coin after town event")
    expect(sim.estate.currentEvent, "retreat should advance week and roll town event")
    expect(sim.estate.campaign.dread == 1, "retreat should raise campaign dread")
    local stress = sim:heroAtRank(1).stress
    expect(stress > 0, "retreat should stress party")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(67)
    sim:endExpedition(true)
    local hero = sim:heroAtRank(1)
    hero.stress = 0
    sim.estate.campaign.dread = 6
    runQueued(sim, Simulation.commands.advanceWeek())
    expect(hero.stress >= 1, "high dread should add estate pressure stress")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(28)
    sim:endExpedition(true)
    local hero = sim:heroAtRank(1)
    hero.stress = 40
    local gold = sim.estate.gold
    runQueued(sim, Simulation.commands.recoverHero(hero.id))
    expect(hero.stress == 10 and hero.recovering == 1 and sim.estate.gold == gold - 25, "estate recovery should spend gold and start cooldown")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(68)
    sim:endExpedition(true)
    sim.estate.gold = 100
    local hero = sim:heroAtRank(1)
    hero.stress = 70
    runQueued(sim, Simulation.commands.recoverHero(hero.id, "quiet_rest"))
    expect(hero.stress == 48 and hero.recovering == 1 and hero.recoveryActivity == "quiet_rest" and sim.estate.gold == 82, "activity recovery should spend activity cost and mark activity")
    local loaded = Simulation.fromSnapshot(sim:snapshot())
    expect(loaded:heroById(hero.id).recoveryActivity == "quiet_rest", "activity recovery should survive snapshot")
    runQueued(sim, Simulation.commands.advanceWeek())
    expect(hero.recovering == 0 and hero.recoveryActivity == nil, "activity should clear when hero returns")
    expect(not sim:recoverHero(hero.id, "missing_activity"), "invalid activity should fail")
end

tests[#tests + 1] = function()
    local activity = Defs.estateActivities.ash_vigil
    local oldChance = activity.sideEffectChance
    activity.sideEffectChance = 100
    local sim = Simulation.new(69)
    sim:endExpedition(true)
    sim.estate.gold = 100
    local hero = sim:heroAtRank(1)
    hero.quirks = { "iron_nerves", "quick_reflexes" }
    runQueued(sim, Simulation.commands.recoverHero(hero.id, "ash_vigil"))
    runQueued(sim, Simulation.commands.advanceWeek())
    activity.sideEffectChance = oldChance
    expect(#hero.quirks == 3, "activity side effect should resolve on return week")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(55)
    sim:endExpedition(true)
    local week = sim.estate.week
    local hero = sim:heroAtRank(1)
    hero.recovering = 1
    runQueued(sim, Simulation.commands.advanceWeek())
    expect(sim.estate.week == week + 1 and hero.recovering == 0, "advance week should tick recovery")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(60)
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.advanceWeek())
    expect(sim.estate.currentEvent and #sim.estate.eventHistory > 0, "advance week should roll town event")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(61)
    sim:endExpedition(true)
    local gold = sim.estate.gold
    sim:applyTownEvent("clear_roads")
    expect(sim.estate.gold == gold + 30 and sim.estate.currentEvent == "clear_roads", "town event should apply gold effect")
    sim:applyTownEvent("supply_cache")
    expect(sim.estate.provisionCart:count("torch") > 0, "town event should add provisions")
    local heirlooms = sim.estate.heirlooms
    sim:applyTownEvent("archivist_tithe")
    expect(sim.estate.heirlooms == heirlooms + 1, "town event should apply heirloom effect")
    sim:applyTownEvent("old_maps")
    expect(sim.estate.provisionCart:count("ward_charm") == 1, "town event should add rare provisions")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(31)
    sim:endExpedition(true)
    local rosterSize = #sim.estate.roster
    local gold = sim.estate.gold
    runQueued(sim, Simulation.commands.recruitHero(1))
    expect(#sim.estate.roster == rosterSize + 1, "recruitment should add a hero")
    expect(sim.estate.gold == gold - 20, "recruitment should spend stagecoach cost")
    expect(#sim.estate.recruits == sim:recruitSlots(), "recruitment should refill candidates")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(136)
    sim:endExpedition(true)
    local function hasClass(key)
        return contains(sim:unlockedClassKeys(), key)
    end
    expect(hasClass("warden") and hasClass("duelist") and hasClass("mender") and hasClass("harrier"), "starter classes should be unlocked")
    expect(not hasClass("arcanist") and not hasClass("chirurgeon") and not hasClass("exile") and not hasClass("lamplighter") and not hasClass("merchant"), "advanced classes should start locked")
    sim.estate.recruits = { { class = "lamplighter", name = "Locked", quirks = {} } }
    sim:refillRecruits()
    for _, recruit in ipairs(sim.estate.recruits) do
        expect(hasClass(recruit.class), "recruit pool should prune locked classes")
    end
    expect(Render.classUnlockSummary(sim).line:find("Arcanist", 1, true), "class unlock summary should expose next locked class")
    sim.estate.campaign.locationProgress.buried_archive = 1
    expect(hasClass("arcanist") and Render.classUnlockSummary(sim).line:find("Chirurgeon", 1, true), "archive progress should unlock arcanist and show next gate")
    sim.estate.campaign.bossKills.buried_archive = true
    expect(hasClass("chirurgeon"), "archive boss kill should unlock chirurgeon")
    sim.estate.campaign.locationProgress.salt_cistern = 1
    expect(hasClass("exile"), "cistern progress should unlock exile")
    sim.estate.campaign.bossKills.salt_cistern = true
    expect(hasClass("lamplighter"), "cistern boss kill should unlock lamplighter")
    expect(not hasClass("merchant"), "merchant should stay locked until its unlock event")
    sim.estate.campaign.flags.merchant_ledger_accepted = true
    expect(hasClass("merchant"), "merchant ledger flag should unlock merchant")
    local loaded = Simulation.fromSnapshot(sim:snapshot())
    expect(contains(loaded:unlockedClassKeys(), "lamplighter") and contains(loaded:unlockedClassKeys(), "merchant"), "class gates should survive snapshot through campaign state")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(72)
    sim:endExpedition(true)
    for _, hero in ipairs(sim.estate.roster) do
        hero.alive = false
    end
    sim.estate.recruits = {}
    sim:refillRecruits()
    expect(#sim.estate.recruits == 4, "stagecoach should expose enough recruits after catastrophic roster loss")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(70)
    sim:endExpedition(true)
    sim.estate.gold = 200
    runQueued(sim, Simulation.commands.recruitHero(1))
    local hero = sim.estate.roster[#sim.estate.roster]
    runQueued(sim, Simulation.commands.equipTrinket(hero.id, "cracked_lens", 1))
    expect(not sim:dismissHero(sim:heroAtRank(1).id), "dismiss should reject party heroes")
    runQueued(sim, Simulation.commands.dismissHero(hero.id))
    expect(not sim:heroById(hero.id), "dismiss should remove roster hero")
    expect(sim.estate.dismissed[1].id == hero.id and sim.estate.trinkets.cracked_lens >= 1, "dismiss should record history and return trinkets")
    local loaded = Simulation.fromSnapshot(sim:snapshot())
    expect(loaded.estate.dismissed[1].id == hero.id, "dismiss history should survive snapshot")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(44)
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.recruitHero(1))
    local hero = sim.estate.roster[#sim.estate.roster]
    runQueued(sim, Simulation.commands.assignParty(hero.id, 4))
    expect(sim.party[4] == hero.id and sim.player.selectedHero == 4, "assign party should place roster hero in target rank")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(45)
    sim:endExpedition(true)
    local gold = sim.estate.gold
    runQueued(sim, Simulation.commands.buyProvision("torch", 2))
    expect(sim.estate.gold == gold - 10 and sim.estate.provisionCart:count("torch") == 2, "buy provision should spend gold into cart")
    runQueued(sim, Simulation.commands.startExpedition("archive_scout"))
    expect(sim.expedition.supplies:count("torch") == 6, "start expedition should merge provision cart")
    expect(sim.estate.provisionCart:count("torch") == 0, "start expedition should clear provision cart")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(46)
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.startExpedition("cistern_survey"))
    expect(sim.expedition.supplies:count("torch") == 3 and sim.expedition.supplies:count("ration") == 10, "cistern should use location provision kit")
    sim = Simulation.new(47)
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.startExpedition("ember_cleansing"))
    expect(sim.expedition.supplies:count("torch") == 5 and sim.expedition.supplies:count("ward_charm") == 1, "ember should use location provision kit")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(32)
    sim:endExpedition(true)
    local hero = sim:heroAtRank(1)
    hero.stress = 0
    runQueued(sim, Simulation.commands.equipTrinket(hero.id, "ember_pin", 1))
    expect(hero.trinkets[1] == "ember_pin" and sim.estate.trinkets.ember_pin == 0, "equip should move trinket to hero")
    sim:addStress(hero, 10)
    expect(hero.stress == 8, "quirk and trinket stress modifiers should stack")
    runQueued(sim, Simulation.commands.unequipTrinket(hero.id, 1))
    expect(hero.trinkets[1] == false and sim.estate.trinkets.ember_pin == 1, "unequip should return trinket")
    local gold = sim.estate.gold
    runQueued(sim, Simulation.commands.sellTrinket("ember_pin"))
    expect(sim.estate.trinkets.ember_pin == 0 and sim.estate.gold == gold + Defs.trinket("ember_pin").value, "sell should convert unequipped trinket to gold")
    expect(not sim:sellTrinket("ember_pin"), "sell should reject missing trinket")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(73)
    sim:endExpedition(true)
    sim.estate.gold = 1000
    sim:refillTrinketMarket(true)
    local offer = sim.estate.trinketStock[1]
    local count = sim.estate.trinkets[offer.trinket] or 0
    runQueued(sim, Simulation.commands.buyTrinket(1))
    expect(sim.estate.trinkets[offer.trinket] == count + 1 and sim.estate.gold == 1000 - offer.price, "market buy should spend gold and add trinket")
    expect(#sim.estate.trinketStock == sim:trinketMarketSlots() - 1, "market buy should remove offer")
    local loaded = Simulation.fromSnapshot(sim:snapshot())
    expect(#loaded.estate.trinketStock == #sim.estate.trinketStock, "market stock should survive snapshot")
    runQueued(sim, Simulation.commands.advanceWeek())
    expect(#sim.estate.trinketStock == sim:trinketMarketSlots(), "new week should refill market stock")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(33)
    sim:endExpedition(true)
    sim.estate.gold = 200
    local hero = sim:heroAtRank(2)
    runQueued(sim, Simulation.commands.upgradeSkill(hero.id, "razor_lunge"))
    expect(hero.skillLevels.razor_lunge == 2 and sim.estate.gold == 170, "skill upgrade should spend gold and raise level")
    runQueued(sim, Simulation.commands.upgradeGear(hero.id, "weapon"))
    expect(hero.weapon == 1 and sim.estate.gold == 135, "weapon upgrade should spend gold")
    local hp = sim:maxHp(hero)
    runQueued(sim, Simulation.commands.upgradeGear(hero.id, "armor"))
    expect(hero.armor == 1 and sim:maxHp(hero) == hp + 3, "armor upgrade should raise max hp")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(34)
    sim:endExpedition(true)
    sim.estate.gold = 200
    sim.estate.heirlooms = 10
    local hero = sim:heroAtRank(1)
    runQueued(sim, Simulation.commands.upgradeBuilding("stagecoach"))
    expect(sim:buildingLevel("stagecoach") == 1 and sim:rosterLimit() == 8, "stagecoach upgrade should raise roster limit")
    expect(#sim.estate.recruits == 4 and sim.estate.heirlooms == 8, "stagecoach upgrade should refill and spend heirlooms")
    runQueued(sim, Simulation.commands.treatQuirk(hero.id, "brittle"))
    expect(not string.find(table.concat(hero.quirks, ","), "brittle"), "quirk treatment should remove negative quirk")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(63)
    local hero = sim:heroAtRank(1)
    hero.quirks = { "iron_nerves", "quick_reflexes" }
    expect(sim:gainQuirk(hero, "positive"), "gain quirk should add new positive quirk")
    expect(#hero.quirks == 3, "gain quirk should grow quirk list")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(64)
    sim:endExpedition(true)
    sim.estate.gold = 200
    local hero = sim:heroAtRank(1)
    hero.quirks = { "iron_nerves", "quick_reflexes", "steady_hand", "field_reader", "hard_skinned" }
    runQueued(sim, Simulation.commands.lockQuirk(hero.id, "iron_nerves"))
    expect(hero.lockedQuirks.iron_nerves == true and sim.estate.gold == 155, "lock quirk should spend gold and mark positive quirk")
    sim:gainQuirk(hero, "negative")
    expect(contains(hero.quirks, "iron_nerves"), "locked quirk should not be replaced")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(65)
    local hero = sim:heroAtRank(1)
    hero.stress = 99
    hero.class = "warden"
    sim:addStress(hero, 2)
    expect(hero.virtue == nil or Defs.virtue(hero.virtue), "resolve virtue should be from registry")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(49)
    local hero = sim:heroAtRank(1)
    sim:contractDisease(hero, "brine_rot")
    expect(hero.diseases[1] == "brine_rot" and sim:maxHp(hero) < 28, "disease should apply stat modifier")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(50)
    sim:endExpedition(true)
    sim.estate.gold = 100
    local hero = sim:heroAtRank(1)
    sim:contractDisease(hero, "salt_cough")
    runQueued(sim, Simulation.commands.treatDisease(hero.id, "salt_cough"))
    expect(#hero.diseases == 0 and sim.estate.gold == 70, "treat disease should spend infirmary cost and remove disease")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(29)
    runQueued(sim, Simulation.commands.move("east"))
    runQueued(sim, Simulation.commands.useItem("torch"))
    local text = Save.toText(sim)
    expect(text:match("^THOTH_LUA_SAVE 3"), "save writer should use v3 header")
    local loaded = assert(Save.fromText(text))
    expect(sameSnapshot(sim, loaded), "save round trip should preserve snapshot")
    local oldSnapshot = sim:snapshot()
    oldSnapshot.version = 2
    oldSnapshot.expedition.threatState = nil
    oldSnapshot.expedition.noise = nil
    oldSnapshot.expedition.ambushRolls = nil
    oldSnapshot.expedition.generatedLayoutId = nil
    oldSnapshot.world.layoutId = nil
    local oldLoaded = assert(Save.fromText("THOTH_LUA_SAVE 2\n" .. Serialize.encode(oldSnapshot) .. "\n"))
    expect(oldLoaded.expedition.threatState and oldLoaded.expedition.noise == 0 and oldLoaded.world.layoutId == oldLoaded.expedition.mission, "v2 save should load pressure defaults")
    local old, err = Save.fromText("THOTH_LUA_SAVE 1\n{}\n")
    expect(old == nil and tostring(err):find("unsupported save version"), "legacy save should fail explicitly")
end

tests[#tests + 1] = function()
    local frames = {
        { tick = 0, command = Simulation.commands.move("east") },
        { tick = 1, command = Simulation.commands.useItem("torch") },
        { tick = 2, command = Simulation.commands.selectHero(2) },
    }
    local replay = Replay.run(30, frames, 4)
    local direct = Simulation.new(30)
    for tick = 0, 3 do
        for _, frame in ipairs(frames) do
            if frame.tick == tick then
                direct:queue(frame.command)
            end
        end
        direct:step()
    end
    expect(sameSnapshot(replay, direct), "replay should equal direct simulation")
    local text = Replay.toText(30, frames, 4)
    local decoded = assert(Replay.fromText(text))
    expect(decoded.version == 2 and decoded.finalTick == 4, "replay v2 should decode")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(141)
    sim:endExpedition(true)
    expect(sim:unlockMerchantLedger(), "merchant ledger should unlock for save test")
    runQueued(sim, Simulation.commands.recruitHero(1))
    runQueued(sim, Simulation.commands.assignParty(5, 4))
    local loaded = assert(Save.fromText(Save.toText(sim)))
    expect(loaded:classUnlocked("merchant") and loaded:heroById(5).class == "merchant" and loaded.party[4] == 5, "merchant party should survive save load")
    expect(sameSnapshot(sim, loaded), "merchant save round trip should preserve snapshot")
end

tests[#tests + 1] = function()
    local function setupMerchantReplay(sim)
        sim.estate.campaign.completedMissions.archive_regent = true
        sim.estate.campaign.bossKills.buried_archive = true
    end
    local frames = {
        { tick = 0, command = Simulation.commands.endExpedition(true) },
        { tick = 1, command = Simulation.commands.recruitHero(1) },
        { tick = 2, command = Simulation.commands.assignParty(5, 4) },
        { tick = 3, command = Simulation.commands.startExpedition("archive_scout") },
    }
    local replay = Replay.run(142, frames, 5, setupMerchantReplay)
    local direct = Simulation.new(142)
    setupMerchantReplay(direct)
    for tick = 0, 4 do
        for _, frame in ipairs(frames) do
            if frame.tick == tick then
                direct:queue(frame.command)
            end
        end
        direct:step()
    end
    expect(replay:heroById(5).class == "merchant" and replay.party[4] == 5, "merchant replay should recruit and assign merchant")
    expect(sameSnapshot(replay, direct), "merchant replay should equal direct simulation")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(89)
    local before = sim.eventSerial or 0
    sim:pushLog("combat: test", { event = "combat_start" })
    expect(sim.eventSerial == before + 1 and sim.events[#sim.events].message == "combat: test", "pushLog should buffer visual events")
    expect(sim.events[#sim.events].event == "combat_start", "pushLog should keep transient event metadata")
    local loaded = assert(Save.fromText(Save.toText(sim)))
    expect((loaded.eventSerial or 0) == 0 and #(loaded.events or {}) == 0, "visual event buffer should not persist in saves")
    loaded:pushLog("combat won")
    expect(loaded.eventSerial == 1 and loaded.events[1].message == "combat won", "loaded sim should resume visual event ids")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(91)
    reachEntryCombat(sim)
    local startEvent = sim.events[#sim.events]
    expect(startEvent.event == "combat_start" and startEvent.boss == false and startEvent.enemies[1] == "Hollow Guard", "normal combat should emit start metadata")
    sim:finishCombat(true)
    expect(sim.events[#sim.events].event == "combat_win", "normal victory should emit combat_win")
    sim = Simulation.new(92)
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.startExpedition("archive_regent"))
    expect(sim:startCombat("regent", "24:0"), "boss combat should start")
    startEvent = sim.events[#sim.events]
    expect(startEvent.event == "boss_start" and startEvent.boss == true and startEvent.enemies[1] == "Vault Regent", "boss combat should emit boss_start")
    sim:finishCombat(true)
    expect(sim.events[#sim.events].event == "boss_win" and sim.events[#sim.events].boss == true, "boss victory should emit boss_win")
    sim = Simulation.new(93)
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.startExpedition("archive_regent"))
    expect(sim:startCombat("regent", "24:0"), "boss combat should start for loss")
    sim:finishCombat(false)
    expect(sim.events[#sim.events].event == "boss_loss" and sim.events[#sim.events].boss == true, "boss loss should emit boss_loss")
end

tests[#tests + 1] = function()
    local view = {
        centerX = 400,
        centerY = 260,
        halfW = 32,
        halfH = 16,
        originX = 10,
        originY = -4,
        rotation = 0,
    }
    local sx, sy = Render.projectIso(view, 13, -2)
    local wx, wy = Render.screenToWorld(view, sx, sy)
    expect(wx == 13 and wy == -2, "iso projection should round trip")
    view.rotation = 1
    sx, sy = Render.projectIso(view, 10, -1)
    wx, wy = Render.screenToWorld(view, sx, sy)
    expect(wx == 10 and wy == -1, "rotated iso projection should round trip")
    sx, sy = Render.projectIso(view, 10, -1)
    wx, wy = Render.screenToWorld(view, sx, sy)
    expect(wx == 10 and wy == -1, "render3d rotated projection should round trip")
end

tests[#tests + 1] = function()
    local oldLove = love
    love = nil
    local state = Render.load()
    expect(state.headless and state.g3d == nil, "render3d load should support headless mode")
    local sim = Simulation.new(91)
    local app = {
        viewRotation = 3,
        ui = {
            skillButtons = { { stale = true } },
            heroButtons = {},
            enemyButtons = {},
            itemButtons = {},
            missionButtons = {},
            recruitButtons = {},
            provisionButtons = {},
            estateActionButtons = {},
            rosterButtons = {},
        },
    }
    Render.draw(sim, app)
    expect(app.worldView.mode == "render3d-placeholder", "render3d headless draw should leave placeholder worldView")
    expect(app.worldView.rotation == 3, "render3d headless draw should preserve rotation metadata")
    expect(#app.ui.skillButtons == 0, "render3d headless draw should still clear stale hitboxes")
    love = oldLove
end

tests[#tests + 1] = function()
    local sim = Simulation.new(90)
    reachEntryCombat(sim)
    local hero = sim:activeHero()
    local enemy = sim:enemyAtRank(1)
    local heroCutscene = Render.cutsceneForStatus(hero.name .. " used Razor Lunge", sim)
    expect(heroCutscene and heroCutscene.kind == "strike" and heroCutscene.side == "ally", "hero skill should map to ally strike cutscene")
    expect(heroCutscene.beat == "strike" and heroCutscene.focus == "actor" and heroCutscene.caption == "Skill", "legacy hero skill cutscene should carry strike profile metadata")
    local enemyName = Defs.enemy(enemy.kind).name
    local enemyCutscene = Render.cutsceneForStatus(enemyName .. " used Rusted Chop", sim)
    expect(enemyCutscene and enemyCutscene.kind == "strike" and enemyCutscene.side == "enemy", "enemy skill should map to enemy strike cutscene")
    expect(enemyCutscene.camera == "hit" and enemyCutscene.mood == "action", "enemy strike cutscene should carry action camera metadata")
    local bossStartCutscene = Render.cutsceneForEvent({ message = "combat: regent", event = "boss_start", boss = true, enemies = { "Vault Regent" } }, sim)
    expect(bossStartCutscene.kind == "boss_intro", "boss start should map to boss intro")
    expect(bossStartCutscene.caption == "Vault Regent", "boss start cutscene should caption enemy name")
    local bossSkillCutscene = Render.cutsceneForEvent({ message = "Vault Regent used Sentence", event = "boss_skill", actor = "Vault Regent", skill = "Sentence", boss = true }, sim)
    expect(bossSkillCutscene.kind == "boss_strike", "boss skill should map to boss strike")
    expect(bossSkillCutscene.mood == "boss" and bossSkillCutscene.beat == "smite" and bossSkillCutscene.caption == "Sentence", "boss strike should carry boss scene metadata")
    expect(Render.cutsceneForEvent({ message = "combat won", event = "boss_win", boss = true, enemies = { "Vault Regent" } }, sim).kind == "boss_victory", "boss win should map to boss victory")
    expect(Render.cutsceneForEvent({ message = "event: Ledger Offer", event = "merchant_unlock", actor = "Ledger Offer" }, sim).kind == "merchant_unlock", "merchant unlock should map to merchant cutscene")
    expect(Render.cutsceneForEvent({ message = "party lost", event = "boss_loss", boss = true, enemies = { "Vault Regent" } }, sim).kind == "boss_defeat", "boss loss should map to boss defeat")
    expect(Render.cutsceneForEvent({ message = "retreated", event = "retreat" }, sim).kind == "retreat", "retreat should map to retreat cutscene")
    expect(Render.cutsceneForEvent({ message = "ambush blocks retreat", event = "retreat_blocked" }, sim).kind == "blocked", "blocked retreat should map to blocked cutscene")
    expect(Render.cutsceneForEvent({ message = "Mara reached death's door", event = "death_door", actor = "Mara" }, sim).kind == "death_door", "death door should map to death door cutscene")
    expect(Render.cutsceneForEvent({ message = "Mara clung to life", event = "death_save", actor = "Mara" }, sim).kind == "death_save", "death save should map to death save cutscene")
    expect(Render.cutsceneForEvent({ message = "Mara fell", event = "hero_death", actor = "Mara" }, sim).kind == "hero_death", "hero death should map to death cutscene")
    expect(Render.cutsceneForEvent({ message = "Mara steadied", event = "resolve_virtue", actor = "Mara" }, sim).kind == "resolve_virtue", "virtue should map to resolve cutscene")
    expect(Render.cutsceneForEvent({ message = "Mara is Panic", event = "resolve_affliction", actor = "Mara" }, sim).kind == "resolve_affliction", "affliction should map to resolve cutscene")
    expect(Render.cutsceneForEvent({ message = "Mara breaks under the dark", event = "stress_break", actor = "Mara" }, sim).kind == "stress_break", "stress break should map to stress cutscene")
    local idle = Render.idleCombatScene(sim)
    expect(idle and idle.kind == "idle" and idle.title == hero.name .. " acts", "combat should expose persistent idle stage scene")
    expect(idle.mood == "watch" and idle.beat == "idle", "idle combat scene should carry ambient stage metadata")
    expect(Render.cutsceneForStatus("combat: entry", sim).kind == "intro", "combat start should map to intro cutscene")
    expect(Render.cutsceneForStatus("combat won", sim).kind == "victory", "combat win should map to victory cutscene")
    expect(Render.cutsceneForStatus("campaign sealed", sim).beat == "seal", "campaign victory should map to seal beat")
    expect(Render.cutsceneForStatus("Moth fell", sim).kind == "danger", "death event should map to danger cutscene")
    expect(Render.cutsceneForStatus("used Torch", sim) == nil, "provision use should not map to combat cutscene")
    local app = { cutscene = Render.cutsceneForStatus("combat won", sim) }
    Render.advanceCutscene(app, 1)
    expect(app.cutscene == nil, "advanceCutscene should expire completed cutscene")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(91)
    reachEntryCombat(sim)
    local cases = {
        { event = "combat_start", message = "combat: entry", kind = "intro", mood = "threat", beat = "arrival", enemies = { "Cyst Bailiff" } },
        { event = "boss_start", message = "combat: regent", kind = "boss_intro", mood = "boss", beat = "reveal", boss = true, enemies = { "Vault Regent" } },
        { event = "ambush_start", message = "ambush", kind = "ambush", mood = "panic", beat = "snap", enemies = { "Audit Hound" } },
        { event = "hero_skill", message = "Mara used Razor Lunge", kind = "strike", mood = "action", beat = "strike", actor = "Mara", skill = "Razor Lunge" },
        { event = "enemy_skill", message = "Cyst Bailiff used Rusted Chop", kind = "strike", mood = "action", beat = "strike", actor = "Cyst Bailiff", skill = "Rusted Chop" },
        { event = "boss_skill", message = "Vault Regent used Sentence", kind = "boss_strike", mood = "boss", beat = "smite", actor = "Vault Regent", skill = "Sentence", boss = true },
        { event = "combat_win", message = "combat won", kind = "victory", mood = "resolve", beat = "triumph" },
        { event = "boss_win", message = "boss won", kind = "boss_victory", mood = "seal", beat = "triumph", boss = true },
        { event = "merchant_unlock", message = "event: Ledger Offer", kind = "merchant_unlock", mood = "ledger", beat = "arrival", actor = "Ledger Offer" },
        { event = "combat_loss", message = "party lost", kind = "defeat", mood = "doom", beat = "collapse" },
        { event = "boss_loss", message = "boss loss", kind = "boss_defeat", mood = "doom", beat = "collapse", boss = true },
        { event = "retreat", message = "retreated", kind = "retreat", mood = "flight", beat = "exit" },
        { event = "retreat_blocked", message = "ambush blocks retreat", kind = "blocked", mood = "panic", beat = "block" },
        { event = "death_door", message = "Mara reached death's door", kind = "death_door", mood = "threshold", beat = "threshold", actor = "Mara" },
        { event = "death_save", message = "Mara clung to life", kind = "death_save", mood = "resolve", beat = "revive", actor = "Mara" },
        { event = "hero_death", message = "Mara fell", kind = "hero_death", mood = "doom", beat = "fall", actor = "Mara" },
        { event = "resolve_virtue", message = "Mara steadied", kind = "resolve_virtue", mood = "virtue", beat = "resolve", actor = "Mara" },
        { event = "resolve_affliction", message = "Mara is Panic", kind = "resolve_affliction", mood = "affliction", beat = "fracture", actor = "Mara" },
        { event = "stress_break", message = "Mara breaks under the dark", kind = "stress_break", mood = "affliction", beat = "break", actor = "Mara" },
        { event = "affliction_act", message = "Mara lashes out", kind = "affliction_act", mood = "affliction", beat = "lash", actor = "Mara" },
        { event = "falter", message = "Cyst Bailiff faltered", kind = "falter", mood = "dazed", beat = "stagger", actor = "Cyst Bailiff", side = "enemy" },
        { event = "hero_hold", message = "Mara holds", kind = "hero_hold", mood = "guard", beat = "hold", actor = "Mara" },
    }
    for _, case in ipairs(cases) do
        local cutscene = Render.cutsceneForEvent(case, sim)
        expect(cutscene and cutscene.kind == case.kind, "render3d should map " .. case.event .. " to " .. case.kind)
        expect(cutscene.mood == case.mood and cutscene.beat == case.beat, "render3d cutscene should preserve profile for " .. case.event)
    end
    expect(Render.cutsceneForStatus("combat: entry", sim).kind == "intro", "render3d fallback combat text should map to intro")
    expect(Render.cutsceneForStatus("campaign sealed", sim).kind == "campaign_victory", "render3d fallback campaign win should map to campaign victory")
    expect(Render.cutsceneForStatus("Moth fell", sim).kind == "danger", "render3d fallback danger text should map to danger")
    expect(Render.cutsceneForStatus("used Torch", sim) == nil, "render3d should ignore non-combat item use text")
    local idle = Render.idleCombatScene(sim)
    expect(idle and idle.kind == "idle" and idle.beat == "idle", "render3d should expose idle combat scene")
    local app = { cutscene = Render.cutsceneForStatus("combat won", sim) }
    Render.advanceCutscene(app, 1)
    expect(app.cutscene == nil, "render3d advanceCutscene should expire completed cutscene")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(79)
    sim:endExpedition(true)
    sim.estate.trinkets.kiln_token = 1
    local tooltip = table.concat(Render.trinketTooltip(sim, "ember_pin"), "\n")
    expect(tooltip:find("Ember Pin", 1, true), "trinket tooltip should include trinket name")
    expect(tooltip:find("Vow of Cinders", 1, true), "trinket tooltip should include matching set name")
    expect(tooltip:find("2pc", 1, true) and tooltip:find("4pc", 1, true), "trinket tooltip should include set bonus tiers")
    expect(tooltip:find("owned", 1, true) and tooltip:find("equipped", 1, true), "trinket tooltip should include owned and equipped counts")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(52)
    sim:endExpedition(true)
    local app = {
        ui = {
            missionButtons = { { x = 0, y = 0, w = 20, h = 20, missionKey = "ember_cleansing" } },
            recruitButtons = {},
            provisionButtons = {},
        },
    }
    Input.mousepressed(sim, app, 5, 5, 1)
    sim:step()
    expect(sim.expedition.mission == "ember_cleansing" and sim.expedition.location == "ember_warrens", "mission button should start selected mission")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(53)
    sim:endExpedition(true)
    local app = {
        ui = {
            missionButtons = {},
            recruitButtons = { { x = 0, y = 0, w = 20, h = 20, recruitIndex = 1 } },
            provisionButtons = { { x = 30, y = 0, w = 20, h = 20, item = "torch" } },
        },
    }
    Input.mousepressed(sim, app, 5, 5, 1)
    sim:step()
    expect(#sim.estate.roster == 5, "recruit button should queue recruitment")
    local torches = sim.estate.provisionCart:count("torch")
    Input.mousepressed(sim, app, 35, 5, 1)
    sim:step()
    expect(sim.estate.provisionCart:count("torch") == torches + 1, "provision button should buy item")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(59)
    sim:endExpedition(true)
    sim.estate.gold = 200
    sim.estate.heirlooms = 10
    local hero = sim:heroAtRank(1)
    hero.stress = 40
    sim:contractDisease(hero, "salt_cough")
    local app = {
        ui = {
            estateActionButtons = {
                { x = 0, y = 0, w = 20, h = 20, action = "upgradeGear", heroId = hero.id, kind = "weapon" },
                { x = 30, y = 0, w = 20, h = 20, action = "treatDisease", heroId = hero.id, diseaseKey = "salt_cough" },
                { x = 60, y = 0, w = 20, h = 20, action = "equipTrinket", heroId = hero.id, trinketKey = "ember_pin", slot = 1, tooltipKey = "ember_pin" },
                { x = 90, y = 0, w = 20, h = 20, action = "lockQuirk", heroId = hero.id, quirkKey = "iron_nerves" },
                { x = 120, y = 0, w = 20, h = 20, action = "recoverHero", heroId = hero.id, activityKey = "quiet_rest" },
                { x = 150, y = 0, w = 20, h = 20, action = "sellTrinket", trinketKey = "cracked_lens" },
                { x = 180, y = 0, w = 20, h = 20, action = "upgradeBuilding", buildingKey = "stagecoach" },
            },
        },
    }
    Input.mousepressed(sim, app, 5, 5, 1)
    sim:step()
    expect(hero.weapon == 1, "estate gear button should upgrade weapon")
    Input.mousepressed(sim, app, 35, 5, 1)
    sim:step()
    expect(#hero.diseases == 0, "estate disease button should treat disease")
    Input.mousepressed(sim, app, 65, 5, 1)
    sim:step()
    expect(hero.trinkets[1] == "ember_pin", "estate trinket button should equip trinket")
    expect(app.trinketTooltipKey == "ember_pin", "estate trinket click should select tooltip target")
    Input.mousepressed(sim, app, 95, 5, 1)
    sim:step()
    expect(hero.lockedQuirks.iron_nerves == true, "estate lock button should lock positive quirk")
    Input.mousepressed(sim, app, 125, 5, 1)
    sim:step()
    expect(hero.recoveryActivity == "quiet_rest", "estate recover button should pass activity key")
    local gold = sim.estate.gold
    Input.mousepressed(sim, app, 155, 5, 1)
    sim:step()
    expect(sim.estate.trinkets.cracked_lens == 0 and sim.estate.gold == gold + Defs.trinket("cracked_lens").value, "estate sell button should sell exact trinket")
    Input.mousepressed(sim, app, 185, 5, 1)
    sim:step()
    expect(sim:buildingLevel("stagecoach") == 1, "estate building button should upgrade building")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(71)
    sim:endExpedition(true)
    sim.estate.gold = 200
    runQueued(sim, Simulation.commands.recruitHero(1))
    local hero = sim.estate.roster[#sim.estate.roster]
    local app = { ui = { estateActionButtons = { { x = 0, y = 0, w = 20, h = 20, action = "dismissHero", heroId = hero.id } } } }
    Input.mousepressed(sim, app, 5, 5, 1)
    sim:step()
    expect(not sim:heroById(hero.id), "estate dismiss button should dismiss roster hero")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(74)
    sim:endExpedition(true)
    sim.estate.gold = 1000
    local offer = sim.estate.trinketStock[1]
    local count = sim.estate.trinkets[offer.trinket] or 0
    local app = { ui = { estateActionButtons = { { x = 0, y = 0, w = 20, h = 20, action = "buyTrinket", stockIndex = 1 } } } }
    Input.mousepressed(sim, app, 5, 5, 1)
    sim:step()
    expect(sim.estate.trinkets[offer.trinket] == count + 1, "estate market button should buy offered trinket")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(62)
    sim:endExpedition(true)
    local hero = sim:heroAtRank(1)
    sim:equipTrinket(hero.id, "ember_pin", 1)
    local app = {
        ui = {
            rosterButtons = { { x = 0, y = 0, w = 20, h = 20, heroId = hero.id } },
            estateActionButtons = { { x = 30, y = 0, w = 20, h = 20, action = "unequipTrinket", heroId = hero.id, slot = 1 } },
        },
    }
    Input.mousepressed(sim, app, 5, 5, 1)
    expect(app.estateHeroId == hero.id, "roster button should select exact hero")
    Input.mousepressed(sim, app, 35, 5, 1)
    sim:step()
    expect(hero.trinkets[1] == false and sim.estate.trinkets.ember_pin == 1, "unequip button should return exact trinket")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(75)
    sim:endExpedition(true)
    local app = {
        ui = {
            estateActionButtons = {
                { x = 0, y = 0, w = 20, h = 20, action = "rosterFilter", filter = "stressed" },
                { x = 30, y = 0, w = 20, h = 20, action = "rosterSort", sort = "level" },
            },
        },
    }
    Input.mousepressed(sim, app, 5, 5, 1)
    expect(app.rosterFilter == "stressed", "roster filter button should set local filter")
    Input.mousepressed(sim, app, 35, 5, 1)
    expect(app.rosterSort == "level", "roster sort button should set local sort")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(76)
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.recruitHero(1))
    local hero = sim.estate.roster[#sim.estate.roster]
    local app = {
        ui = {
            rosterButtons = { { x = 0, y = 0, w = 20, h = 20, heroId = hero.id } },
            partyRankSlots = { { x = 30, y = 0, w = 20, h = 20, rank = 2 } },
        },
    }
    Input.mousepressed(sim, app, 5, 5, 1)
    expect(app.dragHeroId == hero.id, "roster mouse down should start party drag")
    Input.mousereleased(sim, app, 35, 5, 1)
    sim:step()
    expect(sim:heroRank(hero.id) == 2 and app.dragHeroId == nil, "party rank release should assign dragged hero")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(51)
    reachEntryCombat(sim)
    local enemy = sim:enemyAtRank(2)
    local hp = enemy.hp
    local app = {
        ui = {
            skillButtons = { { x = 0, y = 0, w = 30, h = 30, skillKey = "razor_lunge", targetSide = "enemy" } },
            enemyButtons = { { x = 40, y = 0, w = 30, h = 30, rank = 2, side = "enemy" } },
            heroButtons = {},
        },
    }
    Input.mousepressed(sim, app, 5, 5, 1)
    expect(app.pendingSkillKey == "razor_lunge" and sim.commandQueue[1] == nil, "skill click should wait for target")
    Input.mousepressed(sim, app, 45, 5, 1)
    sim:step()
    expect(enemy.hp < hp and app.pendingSkillKey == nil, "enemy click should dispatch targeted skill")
end

tests[#tests + 1] = function()
    local settings = Settings.defaults()
    expect(settings.masterVolume == 1 and settings.sfxVolume == 1, "settings defaults should expose audio volumes")
    Settings.adjust(settings, "masterVolume", -4)
    expect(settings.masterVolume > 0.59 and settings.masterVolume < 0.61, "settings slider should step and clamp")
    Settings.toggle(settings, "highContrast")
    expect(settings.highContrast == true, "settings toggle should flip accessibility flags")
    Settings.cycle(settings, "colorblindMode", 1)
    expect(settings.colorblindMode == "deuteranopia", "settings cycle should advance colorblind mode")
    settings.fontScale = 1.4
    expect(Render.fontScale(settings) == 1.4, "font scale should clamp through render")
    local shifted = Render.accessibleColor(settings, { 0.9, 0.1, 0.1, 1 })
    expect(shifted[1] ~= 0.9 and shifted[2] ~= 0.1, "colorblind mode should transform cue colors")
    local app = { settings = settings, eventFlash = { cue = "hit_slash", status = "Mara hit" } }
    expect(Render.audioSubtitle(app) == "slash hit: Mara hit", "subtitles should expose audio cue and status")
    settings.subtitles = false
    expect(Render.audioSubtitle(app) == nil, "subtitles should respect setting")
    settings.reducedMotion = true
    expect(not Render.markUiPulse(app, { x = 0, y = 0, w = 10, h = 10 }), "reduced motion should suppress pulse animations")
    local ok = Settings.bindKey(settings, "moveUp", "i")
    expect(ok and Settings.keyForAction(settings, "moveUp") == "i", "settings should bind movement key")
    local duplicate = Settings.bindKey(settings, "moveDown", "i")
    expect(not duplicate, "settings should reject duplicate keybind")
    local reserved = Settings.bindKey(settings, "moveDown", "escape")
    expect(not reserved, "settings should reserve escape during capture")
end

tests[#tests + 1] = function()
    local disabled = Render.titleMenuItems({ canContinue = false })
    expect(#disabled == 5, "title should expose five menu items")
    expect(disabled[1].action == "new" and disabled[1].enabled, "title should expose new game")
    expect(disabled[2].action == "continue" and not disabled[2].enabled, "title continue should disable without save")
    expect(disabled[3].action == "settings" and disabled[4].action == "credits" and disabled[5].action == "quit", "title should expose settings, credits, and quit")
    local enabled = Render.titleMenuItems({ canContinue = true })
    expect(enabled[2].enabled, "title continue should enable with save")
    local app = { canContinue = true, ui = { titleButtons = { { stale = true } } } }
    Render.drawTitle(Simulation.new(76), app)
    expect(#app.ui.titleButtons == 5 and app.ui.titleButtons[2].action == "continue" and app.ui.titleButtons[4].action == "credits", "title draw should populate title hitboxes")
    local pauseItems = Render.pauseMenuItems()
    expect(#pauseItems == 4 and pauseItems[1].action == "resume" and pauseItems[4].action == "quitTitle", "pause should expose resume, save, settings, quit")
    app.paused = true
    app.pauseMenuIndex = 99
    Render.drawPauseMenu(app)
    expect(#app.ui.pauseButtons == 4 and app.ui.pauseButtons[3].action == "settings", "pause draw should populate pause hitboxes")
    expect(app.pauseMenuIndex == 4, "pause draw should clamp focus")
    app.confirmDialog = { title = "Quit", body = "Confirm", confirmAction = "quitTitle" }
    app.confirmMenuIndex = 99
    Render.drawConfirmDialog(app)
    expect(#app.ui.confirmButtons == 2 and app.ui.confirmButtons[2].action == "confirm", "confirm draw should populate confirm hitboxes")
    expect(app.confirmMenuIndex == 2, "confirm draw should clamp focus")
    local ended = Simulation.new(81)
    ended:endExpedition(true)
    ended.estate.campaign.dreadLimit = 2
    ended.estate.campaign.dread = 2
    ended:evaluateCampaignState()
    app.gameOverMenuIndex = 99
    local gameOverSummary = Render.drawGameOver(ended, app)
    expect(gameOverSummary.reason == "dread" and gameOverSummary.route == "extraction_collapse", "game over summary should expose loss route")
    expect(gameOverSummary.dreadTier == 4 and #gameOverSummary.factions == 5, "game over summary should expose dread tier and factions")
    expect(#app.ui.gameOverButtons == 3 and app.ui.gameOverButtons[1].action == "restart", "game over draw should populate restart hitbox")
    expect(app.gameOverMenuIndex == 3, "game over draw should clamp focus")
    local credits = Render.drawCredits(app)
    expect(#credits.assets == 3 and credits.assets[1].license == "CC-BY 3.0", "credits should load asset license rows")
    expect(#credits.libraries == 2 and #app.ui.creditsButtons == 1, "credits should expose libraries and back hitbox")
    expect(credits.text:find("Asset Attributions", 1, true) and credits.text:find("assets/sprites/oga_700_sprites.png", 1, true), "credits should emit generated screen text")
    local parsed = Credits.data("| File | Source | Author | License | Notes |\n|---|---|---|---|---|\n| `asset.png` | `src` | Author | MIT | note |\n")
    expect(parsed.assets[1].file == "asset.png" and parsed.text:find("asset.png / MIT / Author", 1, true), "credits generator should parse markdown license rows")
    ended:collectDocument("archive_writ_01", "test")
    local hero = ended:heroAtRank(1)
    hero.deathsDoor = true
    hero.deathblowResist = 0
    ended:damageHero(hero, hero.hp + 1)
    local journal = Render.drawJournal(ended, app)
    expect(#journal.documents == 1 and journal.documents[1].text ~= "", "journal should expose found document text")
    expect(#journal.epitaphs == 1 and journal.epitaphs[1].epitaph ~= "", "journal should expose graveyard epitaphs")
    expect(#app.ui.journalButtons >= 4, "journal draw should populate journal hitboxes")
    app.tutorial = { active = true, index = 1 }
    local tutorial = Render.drawTutorial(app)
    expect(#tutorial == 3 and tutorial[1].key == "torch" and tutorial[3].key == "rank", "tutorial should expose torch, stress, and rank steps")
    expect(#app.ui.tutorialButtons == 3, "tutorial draw should populate tutorial controls")
    app.settings = Settings.defaults()
    Render.drawSettings(app)
    local hasBack = false
    local hasBind = false
    local hasAdjust = false
    for _, hitbox in ipairs(app.ui.settingsButtons) do
        hasBack = hasBack or hitbox.action == "back"
        hasBind = hasBind or hitbox.action == "bind"
        hasAdjust = hasAdjust or hitbox.action == "slider" or hitbox.action == "adjust"
    end
    expect(hasBack and hasBind and hasAdjust, "settings draw should populate back, bind, and slider hitboxes")
end

tests[#tests + 1] = function()
    local app = {
        ui = {
            skillButtons = { { stale = true } },
            heroButtons = { { stale = true } },
            enemyButtons = { { stale = true } },
            itemButtons = { { stale = true } },
            missionButtons = { { stale = true } },
            recruitButtons = { { stale = true } },
            provisionButtons = { { stale = true } },
            estateActionButtons = { { stale = true } },
            rosterButtons = { { stale = true } },
            partyRankSlots = { { stale = true } },
            curioButtons = { { stale = true } },
            campSkillButtons = { { stale = true } },
            campHeroButtons = { { stale = true } },
            pauseButtons = { { stale = true } },
            confirmButtons = { { stale = true } },
            gameOverButtons = { { stale = true } },
            creditsButtons = { { stale = true } },
            journalButtons = { { stale = true } },
            tutorialButtons = { { stale = true } },
            titleButtons = { { stale = true } },
            settingsButtons = { { stale = true } },
        },
    }
    local oldSkills = app.ui.skillButtons
    local oldEnemies = app.ui.enemyButtons
    local oldTitle = app.ui.titleButtons
    Render.prepareUi(app)
    expect(app.ui.skillButtons == oldSkills, "prepareUi should reuse hitbox arrays")
    expect(app.ui.enemyButtons == oldEnemies, "prepareUi should reuse enemy hitbox array")
    expect(app.ui.titleButtons == oldTitle, "prepareUi should reuse title hitbox array")
    expect(#app.ui.skillButtons == 0 and #app.ui.heroButtons == 0 and #app.ui.enemyButtons == 0 and #app.ui.itemButtons == 0, "prepareUi should clear combat hitboxes")
    expect(#app.ui.missionButtons == 0 and #app.ui.recruitButtons == 0 and #app.ui.provisionButtons == 0, "prepareUi should clear estate hitboxes")
    expect(#app.ui.estateActionButtons == 0, "prepareUi should clear estate action hitboxes")
    expect(#app.ui.rosterButtons == 0, "prepareUi should clear roster hitboxes")
    expect(#app.ui.partyRankSlots == 0, "prepareUi should clear party rank slots")
    expect(#app.ui.curioButtons == 0, "prepareUi should clear curio buttons")
    expect(#app.ui.campSkillButtons == 0 and #app.ui.campHeroButtons == 0, "prepareUi should clear camp buttons")
    expect(#app.ui.pauseButtons == 0 and #app.ui.confirmButtons == 0 and #app.ui.gameOverButtons == 0 and #app.ui.creditsButtons == 0 and #app.ui.journalButtons == 0 and #app.ui.tutorialButtons == 0 and #app.ui.titleButtons == 0 and #app.ui.settingsButtons == 0, "prepareUi should clear system hitboxes")
    app.ui.skillButtons[#app.ui.skillButtons + 1] = { stale = true }
    app.ui.enemyButtons[#app.ui.enemyButtons + 1] = { stale = true }
    Render.prepareUi(app)
    expect(app.ui.skillButtons == oldSkills and app.ui.enemyButtons == oldEnemies, "render3d prepareUi should reuse hitbox arrays")
    expect(#app.ui.skillButtons == 0 and #app.ui.enemyButtons == 0, "render3d prepareUi should clear reused combat hitboxes")
end

for index, test in ipairs(tests) do
    test()
    io.stdout:write("ok ", index, "\n")
end

io.stdout:write("tests passed: ", #tests, "\n")
