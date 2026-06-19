package.path = "./?.lua;./?/init.lua;./src/?.lua;./src/?/init.lua;" .. package.path

local Serialize = require("src.core.serialize")
local Simulation = require("src.game.simulation")
local Save = require("src.game.save")
local Replay = require("src.game.replay")
local Input = require("src.app.input")
local Render = require("src.app.render")
local World = require("src.game.world")

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
    local connected = table.concat(world:connectedRooms("0:0"), ",")
    expect(connected == "8:0", "room graph should expose corridor links")
    local baseRevision = world:chunkRevision(0, 0, 0)
    world:setTile(4, 0, 0, { id = "archive_floor", data = 0 })
    expect(world:getTile(4, 0, 0).id == "archive_floor", "override did not persist")
    expect(world:chunkRevision(0, 0, 0) == baseRevision + 1, "override should bump chunk revision")
    local loaded = World.fromSnapshot(world:snapshot())
    expect(loaded:getTile(4, 0, 0).id == "archive_floor", "world snapshot lost override")
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
    local sim = Simulation.new(19)
    local hero = sim:heroAtRank(1)
    hero.stress = 99
    sim:addStress(hero, 3)
    expect(hero.affliction or hero.virtue, "stress over threshold should resolve")
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
    local sim = Simulation.new(26)
    sim.expedition.roomsScouted = 3
    sim.expedition.objectiveComplete = true
    sim.expedition.loot:add("coin", 50)
    sim.player.x = -2
    sim.player.y = 1
    sim.player.facing = "south"
    runQueued(sim, Simulation.commands.interact())
    expect(sim.mode == "estate", "exit should end completed expedition")
    expect(sim.estate.gold == 280, "completed expedition should transfer loot and mission reward")
    expect(sim.estate.heirlooms == 1, "completed expedition should pay mission heirloom reward")
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
end

tests[#tests + 1] = function()
    local sim = Simulation.new(27)
    sim.expedition.loot:add("coin", 20)
    runQueued(sim, Simulation.commands.endExpedition(true))
    expect(sim.mode == "estate", "retreat end should return to estate")
    expect(sim.estate.gold == 160, "retreat should transfer half coin")
    local stress = sim:heroAtRank(1).stress
    expect(stress > 0, "retreat should stress party")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(28)
    sim:endExpedition(true)
    local hero = sim:heroAtRank(1)
    hero.stress = 40
    local gold = sim.estate.gold
    runQueued(sim, Simulation.commands.recoverHero(hero.id))
    expect(hero.stress == 10 and sim.estate.gold == gold - 25, "estate recovery should spend gold and reduce stress")
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
    local sim = Simulation.new(29)
    runQueued(sim, Simulation.commands.move("east"))
    runQueued(sim, Simulation.commands.useItem("torch"))
    local text = Save.toText(sim)
    local loaded = assert(Save.fromText(text))
    expect(sameSnapshot(sim, loaded), "save round trip should preserve snapshot")
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
    local app = {
        ui = {
            skillButtons = { { stale = true } },
            heroButtons = { { stale = true } },
            itemButtons = { { stale = true } },
        },
    }
    local oldSkills = app.ui.skillButtons
    Render.prepareUi(app)
    expect(app.ui.skillButtons == oldSkills, "prepareUi should reuse hitbox arrays")
    expect(#app.ui.skillButtons == 0 and #app.ui.heroButtons == 0 and #app.ui.itemButtons == 0, "prepareUi should clear hitboxes")
end

for index, test in ipairs(tests) do
    test()
    io.stdout:write("ok ", index, "\n")
end

io.stdout:write("tests passed: ", #tests, "\n")
