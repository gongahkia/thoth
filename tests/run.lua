package.path = "./?.lua;./?/init.lua;./src/?.lua;./src/?/init.lua;" .. package.path

local Serialize = require("src.core.serialize")
local Simulation = require("src.game.simulation")
local Save = require("src.game.save")
local Replay = require("src.game.replay")
local Input = require("src.app.input")
local Render = require("src.app.render")
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

local function contains(list, value)
    for _, entry in ipairs(list or {}) do
        if entry == value then
            return true
        end
    end
    return false
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

local function reachEntryCombat(sim)
    for _ = 1, 5 do
        runQueued(sim, Simulation.commands.move("east"))
    end
    expect(sim.mode == "combat", "entry room should start combat")
end

local tests = {}

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
    local app = { moveCooldown = 0, viewRotation = 1, status = "ready" }
    love = { keyboard = { isDown = function() return false end } }
    Input.keypressed(sim, app, "w")
    Input.update(sim, app, 0.2)
    sim:step()
    expect(sim.player.x == 1 and sim.player.y == 0, "rotated screen up should map east")
    Input.keypressed(sim, app, "]")
    expect(app.viewRotation == 2, "right bracket should rotate view")
    love = oldLove
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
    sim:startCombat("entry", "8:0")
    sim:finishCombat(true)
    expect(not sim.expedition.objectiveComplete, "one cleared encounter should not complete cleanse mission")
    sim:startCombat("stacks", "16:0")
    sim:finishCombat(true)
    expect(sim.expedition.objectiveComplete, "two cleared encounters should complete cleanse mission")
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
    expect(sim.narration ~= "", "boss return should keep narration")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(85)
    sim:endExpedition(true)
    sim.estate.campaign.dread = 4
    runQueued(sim, Simulation.commands.startExpedition("archive_regent"))
    expect(sim:startCombat("regent", "24:0"), "variant boss combat should start")
    expect(sim.combat.encounter == "regent_crowned" and sim.combat.baseEncounter == "regent", "high dread should select boss variant")
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
    expect(sim.estate.campaign.lost and sim.estate.campaign.lossReason == "weeks", "week limit should collapse campaign")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(81)
    sim:endExpedition(true)
    sim.estate.campaign.dreadLimit = 2
    sim.estate.campaign.dread = 2
    sim:evaluateCampaignState()
    expect(sim.estate.campaign.lost and sim.estate.campaign.lossReason == "dread", "dread limit should collapse campaign")
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
    local sim = Simulation.new(56)
    sim:endExpedition(true)
    runQueued(sim, Simulation.commands.startExpedition("archive_gather"))
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
                { x = 60, y = 0, w = 20, h = 20, action = "equipTrinket", heroId = hero.id, trinketKey = "ember_pin", slot = 1 },
                { x = 90, y = 0, w = 20, h = 20, action = "lockQuirk", heroId = hero.id, quirkKey = "iron_nerves" },
                { x = 120, y = 0, w = 20, h = 20, action = "recoverHero", heroId = hero.id, activityKey = "quiet_rest" },
                { x = 150, y = 0, w = 20, h = 20, action = "sellTrinket", trinketKey = "cracked_lens" },
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
        },
    }
    local oldSkills = app.ui.skillButtons
    local oldEnemies = app.ui.enemyButtons
    Render.prepareUi(app)
    expect(app.ui.skillButtons == oldSkills, "prepareUi should reuse hitbox arrays")
    expect(app.ui.enemyButtons == oldEnemies, "prepareUi should reuse enemy hitbox array")
    expect(#app.ui.skillButtons == 0 and #app.ui.heroButtons == 0 and #app.ui.enemyButtons == 0 and #app.ui.itemButtons == 0, "prepareUi should clear combat hitboxes")
    expect(#app.ui.missionButtons == 0 and #app.ui.recruitButtons == 0 and #app.ui.provisionButtons == 0, "prepareUi should clear estate hitboxes")
    expect(#app.ui.estateActionButtons == 0, "prepareUi should clear estate action hitboxes")
    expect(#app.ui.rosterButtons == 0, "prepareUi should clear roster hitboxes")
end

for index, test in ipairs(tests) do
    test()
    io.stdout:write("ok ", index, "\n")
end

io.stdout:write("tests passed: ", #tests, "\n")
