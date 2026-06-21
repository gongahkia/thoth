package.path = "./?.lua;./?/init.lua;./src/?.lua;./src/?/init.lua;" .. package.path

local Serialize = require("src.core.serialize")
local Simulation = require("src.game.simulation")
local Save = require("src.game.save")
local Replay = require("src.game.replay")
local Input = require("src.app.input")
local Render = require("src.app.render")
local ReplayViewer = require("src.app.replay_viewer")
local Audio = require("src.app.audio")
local Accessibility = require("src.app.accessibility")
local Credits = require("src.app.credits")
local Settings = require("src.app.settings")
local I18n = require("src.app.i18n")
local Achievements = require("src.app.achievements")
local SpritePipeline = require("src.app.sprite_pipeline")
local ModelPipeline = require("src.app.model_pipeline")
local TileModelMap = require("assets.models.tile_model_map")
local World = require("src.game.world")
local Defs = require("src.game.defs")
local TacticsState = require("src.game.tactics.state")
local ZoneCatalog = require("src.game.tactics.zone_catalog")
local ClassCatalog = require("src.game.tactics.class_catalog")
local EnemyCatalog = require("src.game.tactics.enemy_catalog")
local BossCatalog = require("src.game.tactics.boss_catalog")
local RunCatalog = require("src.game.tactics.run_catalog")
local UICatalog = require("src.game.tactics.ui_catalog")
local GateCatalog = require("src.game.tactics.gate_catalog")
local TacticsBoard = require("src.game.tactics.board")
local TacticsUnit = require("src.game.tactics.unit")
local TacticsAP = require("src.game.tactics.ap")
local TacticsLoS = require("src.game.tactics.los")
local TacticsCover = require("src.game.tactics.cover")
local TacticsIntent = require("src.game.tactics.intent")
local TacticsResolution = require("src.game.tactics.resolution")
local TacticsProcgen = require("src.game.tactics.procgen")
local TacticsReplay = require("src.game.tactics.replay")
local TacticalRuntime = require("src.game.tactical_runtime")

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
    local function makeState()
        return TacticsState.new({
            board = {
                width = 4,
                height = 3,
                tiles = {
                    ["3:1"] = { kind = "seal_pillar", blocker = true, height = 1, tags = { "archive" } },
                },
            },
            units = {
                { id = "warden", side = "player", x = 1, y = 1, hp = 5, ap = 2 },
                { id = "custodian", side = "enemy", x = 4, y = 3, hp = 3 },
            },
        })
    end
    local a = makeState()
    local b = makeState()
    local stream = {
        TacticsState.commands.move("warden", "east"),
        TacticsState.commands.move("custodian", "north"),
        TacticsState.commands.wait("warden"),
    }
    for _, command in ipairs(stream) do
        a:queue(command)
        b:queue(command)
        expect(a:step() and b:step(), "tactics state should step queued commands")
    end
    expect(Serialize.encode(a:snapshot()) == Serialize.encode(b:snapshot()), "tactics state should replay deterministically")
    local loaded = TacticsState.fromSnapshot(a:snapshot())
    expect(Serialize.encode(loaded:snapshot()) == Serialize.encode(a:snapshot()), "tactics state snapshot should roundtrip")
    local blocked = makeState()
    blocked:queue(TacticsState.commands.move("warden", "east"))
    blocked:step()
    local ok, err = pcall(function()
        blocked:apply(TacticsState.commands.move("warden", "east"))
    end)
    expect(not ok and err:find("blocked_tile", 1, true), "tactics state should reject blocked movement")
end

tests[#tests + 1] = function()
    local tacticalSim = Simulation.new(9001)
    local runtime = TacticalRuntime.new(tacticalSim)
    local summary = runtime:summary()
    expect(tacticalSim.mode == "tactical" and summary.mode == "tactical", "runtime should put the game in tactical mode")
    expect(#summary.players == 2 and #summary.enemies == 2, "runtime should expose tactical squad and enemies")
    expect(#runtime.overlays.intents == 2 and runtime.state:intentPreview("claim_lens").targetTiles[1].x == 5, "runtime should show exact enemy intents")
    runtime:handleKey("right")
    runtime:handleKey("return")
    expect(runtime.state:unit("warden").x == 3 and runtime.state:unit("warden").ap == 2, "runtime should spend AP to move selected unit")
    runtime:handleKey("e")
    expect(runtime.state:objective("route_machine").integrity == 3, "enemy intent should damage declared objective deterministically")
    expect(runtime.state:unit("warden").hp == 6, "moving off declared tile should avoid old enemy target")
    expect(runtime.state.phase == "player" and runtime.state:unit("warden").ap == 3, "runtime should return to player phase with AP refreshed")
end

tests[#tests + 1] = function()
    local tacticalSim = Simulation.new(9002)
    local runtime = TacticalRuntime.new(tacticalSim)
    local app = {
        tacticalMode = true,
        tactics = runtime,
        tacticalOverlays = runtime.overlays,
        worldView = {
            centerX = 400,
            centerY = 260,
            halfW = 32,
            halfH = 16,
            originX = tacticalSim.player.x,
            originY = tacticalSim.player.y,
            rotation = 0,
        },
    }
    local sx, sy = Render.projectIso(app.worldView, runtime.originX + 3.5, runtime.originY + 6.5)
    local tileX, tileY = Render.tacticalTileAt(app, sx, sy)
    expect(tileX == 3 and tileY == 6, "tactical mouse projection should map screen point to board tile")
    expect(runtime:handleMouseTile(tileX, tileY, 1), "left click should handle reachable board tile")
    expect(runtime.state:unit("warden").x == 3 and runtime.state:unit("warden").ap == 2, "left click should move selected unit to reachable tile")
    expect(runtime:handleMouseTile(2, 7, 1), "left click should select player unit")
    expect(runtime.selectedUnitId == "lamplighter", "left click should select clicked squad unit")
    expect(runtime:handleMouseTile(5, 6, 2), "right click should place cursor")
    expect(runtime.cursor.x == 5 and runtime.cursor.y == 6, "right click should move cursor without action")
    expect(Render.adjustTacticalZoom(app, 3) > 1, "wheel up should zoom in")
    expect(Render.adjustTacticalZoom(app, -20) == 0.65, "wheel down should clamp zoom out")
end

tests[#tests + 1] = function()
    local state = TacticsState.new({
        board = {
            width = 3,
            height = 3,
            tiles = {
                ["2:2"] = {
                    kind = "valve_block",
                    material = "salt",
                    height = 2,
                    coverEdges = { north = "half", east = "full" },
                    blocker = false,
                    losBlocker = true,
                    destructibleHp = 4,
                    hazard = { kind = "brine", damage = 1, countdown = 2 },
                    objective = { id = "pump_heart", kind = "protect", integrity = 5 },
                    revealed = false,
                    rotationMarks = { east = "rear_valve_label", south = "pressure_crack" },
                    tags = { "cistern", "interactable" },
                },
            },
        },
        units = {
            { id = "thief", side = "player", x = 1, y = 2, hp = 4 },
        },
    })
    local tile = state:tileAt(2, 2)
    expect(tile.kind == "valve_block" and tile.material == "salt" and tile.height == 2, "tile schema should keep identity, material, and height")
    expect(tile.coverEdges.north == "half" and tile.coverEdges.east == "full" and tile.coverEdges.south == "none", "tile schema should normalize cover edges")
    expect(tile.losBlocker == true and tile.blocker == false, "tile schema should separate LoS blockers from movement blockers")
    expect(tile.destructibleHp == 4 and tile.hazard.kind == "brine" and tile.objective.integrity == 5, "tile schema should keep destructible, hazard, and objective data")
    expect(tile.revealed == false and tile.rotationMarks.east == "rear_valve_label", "tile schema should keep reveal state and rotation marks")
    state:apply(TacticsState.commands.move("thief", "east"))
    expect(state:unit("thief").x == 2 and state:unit("thief").y == 2, "LoS blocker alone should not block movement")
    local loaded = TacticsState.fromSnapshot(state:snapshot())
    local loadedTile = loaded:tileAt(2, 2)
    expect(loadedTile.hazard.countdown == 2 and loadedTile.objective.id == "pump_heart", "tile schema should roundtrip nested board data")
end

tests[#tests + 1] = function()
    local state = TacticsState.new({
        board = {
            width = 3,
            height = 3,
            tiles = {
                ["2:2"] = { coverEdges = { west = "half", east = "full" } },
            },
        },
    })
    local half = state:coverFromAttack(1, 2, 2, 2)
    expect(half.direction == "west" and half.cover == "half" and half.damageReduction == 1 and not half.blocked, "half cover should reduce deterministic damage from covered edge")
    local full = state:coverFromAttack(3, 2, 2, 2)
    expect(full.direction == "east" and full.cover == "full" and full.blocked, "full cover should block deterministic direct attack from covered edge")
    local open = state:coverFromAttack(2, 1, 2, 2)
    expect(open.direction == "north" and open.cover == "none" and open.damageReduction == 0 and not open.blocked, "uncovered edge should not reduce damage")
end

tests[#tests + 1] = function()
    local state = TacticsState.new({
        board = {
            width = 3,
            height = 3,
            tiles = {
                ["2:2"] = { coverEdges = { west = "half", north = "full" } },
            },
        },
    })
    local protected = state:flankFromAttack(1, 2, 2, 2)
    expect(not protected.flanked and protected.cover == "half", "covered attack vector should not flank")
    local flanked = state:flankFromAttack(2, 3, 2, 2)
    expect(flanked.flanked and flanked.direction == "south" and #flanked.invalidated == 2, "uncovered attack vector should deterministically invalidate other cover")
end

tests[#tests + 1] = function()
    local state = TacticsState.new({
        board = {
            width = 2,
            height = 2,
            tiles = {
                ["1:1"] = { rotationMarks = { east = "rear_seal", south = "audit_scratch" } },
                ["2:1"] = { rotationMarks = { east = "witness_mark" } },
            },
        },
    })
    expect(not state:rotationMarkAt(1, 1, 0).visible, "hidden back-face mark should stay hidden at wrong rotation")
    local east = state:rotationMarkAt(1, 1, 1)
    expect(east.visible and east.direction == "east" and east.mark == "rear_seal", "matching rotation should reveal back-face mark")
    local marks = state:visibleRotationMarks(1)
    expect(#marks == 2 and marks[1].mark == "rear_seal" and marks[2].mark == "witness_mark", "visible rotation marks should include only matching direction")
end

tests[#tests + 1] = function()
    local state = TacticsState.new({
        board = {
            width = 4,
            height = 3,
            tiles = {
                ["1:1"] = { revealed = false, revealClasses = { "lamplighter" }, weakPoint = "rear_seal" },
            },
        },
        units = {
            { id = "lamp", class = "lamplighter", side = "player", x = 1, y = 3, ap = 2 },
            { id = "redactor", side = "enemy", x = 3, y = 2 },
            { id = "boss", side = "enemy", x = 4, y = 2 },
        },
    })
    state:apply(TacticsState.commands.intent("redactor", {
        mode = "hiddenFootprint",
        category = "redacted",
        targetTiles = { { x = 2, y = 2 } },
        revealClasses = { "lamplighter" },
    }))
    state:apply(TacticsState.commands.intent("boss", {
        mode = "bossStage",
        category = "destroy",
        mask = "rear_mask",
        targetTiles = { { x = 4, y = 3 } },
        revealClasses = { "lamplighter" },
    }))
    state:apply(TacticsState.commands.classReveal("lamp", { revealAction = "flare" }, 0))
    expect(state:tileAt(1, 1).revealed and state:tileAt(1, 1).weakPointRevealed, "class reveal should expose hidden tile weak point")
    expect(state:intentPreview("redactor").targetTiles[1].x == 2 and state:intentPreview("redactor").revealed, "class reveal should expose redacted intent")
    expect(state:intentPreview("boss").targetTiles[1].y == 3 and state:intentPreview("boss").mask == nil, "class reveal should expose boss weak point intent")
end

tests[#tests + 1] = function()
    local state = TacticsState.new({
        defaultAp = 3,
        board = {
            width = 4,
            height = 2,
            tiles = {
                ["2:1"] = { losBlocker = true, height = 1 },
            },
        },
        units = {
            { id = "scout", side = "player", x = 1, y = 2, ap = 3 },
            { id = "target", side = "enemy", x = 4, y = 1 },
        },
    })
    local preview = state:movementLosPreview("scout", { targets = { { id = "target" } } })
    local blocked
    local visible
    for _, destination in ipairs(preview.destinations) do
        if destination.x == 1 and destination.y == 1 then
            blocked = destination.targets[1]
        elseif destination.x == 3 and destination.y == 2 then
            visible = destination.targets[1]
        end
    end
    expect(blocked and not blocked.visible and blocked.blockedBy.x == 2, "movement LoS preview should show blocked destination sightline")
    expect(visible and visible.visible, "movement LoS preview should show visible destination sightline")
    expect(state:unit("scout").x == 1 and state:unit("scout").y == 2, "movement LoS preview should not move unit")
end

tests[#tests + 1] = function()
    local state = TacticsState.new({
        board = {
            width = 4,
            height = 1,
            tiles = {
                ["1:1"] = { blockerKind = "hard" },
                ["2:1"] = { blockerKind = "low" },
                ["3:1"] = { blockerKind = "transparent" },
                ["4:1"] = { blockerKind = "destructible", destructibleHp = 2 },
            },
        },
    })
    local hard = state:blockerAt(1, 1)
    expect(hard.kind == "hard" and hard.movement and hard.los, "hard blocker should stop movement and LoS")
    local low = state:blockerAt(2, 1)
    expect(low.kind == "low" and low.movement and not low.los and low.low, "low blocker should stop movement without LoS")
    local transparent = state:blockerAt(3, 1)
    expect(transparent.kind == "transparent" and transparent.movement and not transparent.los and transparent.transparent, "transparent blocker should stop movement without LoS")
    local destructible = state:blockerAt(4, 1)
    expect(destructible.kind == "destructible" and destructible.movement and destructible.los and destructible.destructible and destructible.hp == 2, "destructible blocker should expose HP and block until broken")
    state:damageTile(4, 1, 2)
    local broken = state:blockerAt(4, 1)
    expect(broken.kind == "none" and not broken.movement and not broken.los and state:tileAt(4, 1).destroyed, "destroyed blocker should clear movement and LoS")
end

tests[#tests + 1] = function()
    local high = TacticsState.new({
        board = {
            width = 4,
            height = 1,
            tiles = {
                ["1:1"] = { height = 2 },
                ["2:1"] = { losBlocker = true, height = 0 },
                ["4:1"] = { height = 0, coverEdges = { west = "half" } },
            },
        },
    })
    expect(high:lineOfSight(1, 1, 4, 1).visible, "high ground should see over lower LoS blocker")
    local profile = high:attackProfile(1, 1, 4, 1)
    expect(profile.cover == "half" and profile.effectiveCover == "none" and profile.coverIgnoredByHeight, "high ground should ignore half cover without hit chance")
    local blocked = TacticsState.new({
        board = {
            width = 4,
            height = 1,
            tiles = {
                ["1:1"] = { height = 0 },
                ["2:1"] = { losBlocker = true, height = 2 },
                ["4:1"] = { height = 0 },
            },
        },
    })
    local los = blocked:lineOfSight(1, 1, 4, 1)
    expect(not los.visible and los.blockedBy.x == 2, "higher LoS blocker should block low-ground sight")
    local uphill = high:attackProfile(4, 1, 1, 1)
    expect(uphill.lowGround and uphill.damageReduction == 1, "shooting uphill should add deterministic damage reduction")
end

tests[#tests + 1] = function()
    local state = TacticsState.new({
        board = { width = 5, height = 1 },
        units = {
            { id = "apothecary", side = "player", x = 1, y = 1, ap = 3 },
        },
    })
    state:apply(TacticsState.commands.obscurant("apothecary", 2, 1, "smoke", 2, 0))
    state:addObscurant(3, 1, "salt_mist", 1)
    state:addObscurant(4, 1, "ash_cloud", 1)
    local los = state:lineOfSight(1, 1, 5, 1)
    expect(los.visible and los.obscured and #los.modifiers == 3 and los.modifiers[1].kind == "smoke", "obscurants should be visible LoS modifiers")
    state:apply(TacticsState.commands.tickObscurants())
    expect(state:tileAt(2, 1).hazard.countdown == 1 and not state:tileAt(3, 1).hazard.active and not state:tileAt(4, 1).hazard.active, "obscurant countdown should tick and expire")
    state:apply(TacticsState.commands.tickObscurants())
    expect(not state:lineOfSight(1, 1, 5, 1).obscured and not state:tileAt(2, 1).hazard.active, "expired obscurants should clear LoS modifiers")
end

tests[#tests + 1] = function()
    local state = TacticsState.new({
        board = {
            width = 4,
            height = 4,
            tiles = {
                ["2:2"] = {
                    kind = "claim_desk",
                    coverEdges = { north = "half", west = "full" },
                    hazard = { kind = "ink_spread", damage = 1 },
                },
            },
        },
        units = {
            { id = "lamplighter", x = 1, y = 1 },
        },
    })
    local overlays = {
        movement = { { x = 1, y = 2 }, { x = 2, y = 1 } },
        los = { ["3:1"] = true },
        flanks = { { x = 3, y = 2 } },
        intents = { { x = 4, y = 2, label = "audit_line" } },
        hazards = { { x = 1, y = 4, label = "falling_shelf" } },
    }
    local entries, counts = Render.tacticalOverlayEntries(state, overlays)
    expect(counts.movement == 2, "tactical overlays should include movement range tiles")
    expect(counts.los == 1, "tactical overlays should include LoS tiles")
    expect(counts.cover == 1, "tactical overlays should include cover tiles")
    expect(counts.flank == 1, "tactical overlays should include flank tiles")
    expect(counts.intent == 1, "tactical overlays should include intent tiles")
    expect(counts.hazard == 2, "tactical overlays should include board and explicit hazard tiles")
    expect(#entries == 8, "tactical overlay entry count should match all required overlay classes")
    local summary = Render.tacticalOverlaySummary(state, overlays)
    expect(summary.total == 8 and summary.intent == 1, "tactical overlay summary should expose render-smoke counts")
    local audit = Render.tacticalOverlayAccessibilityAudit(state, overlays)
    expect(#audit == 4, "tactical overlay accessibility audit should cover four rotations")
    for _, rotation in ipairs(audit) do
        local hasLos
        local hasCover
        for _, entry in ipairs(rotation.entries) do
            if entry.kind == "los" and entry.icon == "eye" and entry.pattern == "ray" then
                hasLos = true
            elseif entry.kind == "cover" and entry.icon == "shield" and entry.pattern == "edge-hatch" then
                hasCover = true
            end
        end
        expect(hasLos and hasCover, "LoS and cover overlays should have non-color symbols in every rotation")
    end
end

tests[#tests + 1] = function()
    local three = TacticsState.new({
        defaultAp = 2,
        board = { width = 5, height = 2 },
        units = {
            { id = "warden", side = "player", x = 1, y = 1 },
            { id = "duelist", side = "player", x = 2, y = 1 },
            { id = "lamplighter", side = "player", x = 3, y = 1 },
            { id = "custodian", side = "enemy", x = 5, y = 2, ap = 1, maxAp = 1 },
        },
    })
    expect(#three:unitsForSide("player") == 3, "tactics AP should support 3-unit squads")
    three:apply(TacticsState.commands.select("duelist"))
    three:apply(TacticsState.commands.spend("duelist", 1, "brace"))
    expect(three.selectedUnitId == "duelist" and three:unit("duelist").ap == 1, "AP spend should affect selected unit only")
    local ok, err = pcall(function()
        three:apply(TacticsState.commands.spend("duelist", 2, "overdraw"))
    end)
    expect(not ok and err:find("insufficient_ap", 1, true), "AP spend should fail fast when unit lacks AP")
    three:startTurn("player")
    expect(three:unit("warden").ap == 2 and three:unit("duelist").ap == 2 and three:unit("custodian").ap == 1, "player AP reset should not refill enemy AP")
    local five = TacticsState.new({
        defaultAp = 2,
        board = { width = 7, height = 2 },
        units = {
            { id = "u1", side = "player", x = 1, y = 1 },
            { id = "u2", side = "player", x = 2, y = 1 },
            { id = "u3", side = "player", x = 3, y = 1 },
            { id = "u4", side = "player", x = 4, y = 1 },
            { id = "u5", side = "player", x = 5, y = 1 },
        },
    })
    expect(#five:unitsForSide("player") == 5, "tactics AP should support 5-unit squads")
    five:apply(TacticsState.commands.move("u5", "east"))
    expect(five:unit("u5").x == 6 and five:unit("u5").ap == 1, "movement command should spend AP")
    five:apply(TacticsState.commands.endTurn("enemy"))
    expect(five.phase == "enemy" and five:unit("u5").ap == 1, "ending turn should switch phase without refilling inactive side")
end

tests[#tests + 1] = function()
    local state = TacticsState.new({
        defaultAp = 12,
        board = {
            width = 5,
            height = 4,
            tiles = {
                ["3:2"] = {
                    kind = "ledger_stack",
                    blocker = true,
                    losBlocker = true,
                    destructibleHp = 2,
                    coverEdges = { west = "full" },
                },
            },
        },
        units = {
            { id = "warden", side = "player", x = 1, y = 2, hp = 8 },
            { id = "custodian", side = "enemy", x = 2, y = 2, hp = 5 },
            { id = "bailiff", side = "enemy", x = 4, y = 2, hp = 4 },
        },
    })
    state:apply(TacticsState.commands.attack("warden", "custodian", 2))
    expect(state:unit("custodian").hp == 3, "direct attack should deal deterministic damage")
    state:apply(TacticsState.commands.shove("warden", "custodian", "east", 1, 1))
    expect(state:unit("custodian").x == 2 and state:unit("custodian").hp == 2, "shove into blocker should deal collision damage without moving target")
    state:apply(TacticsState.commands.damageTile("warden", 3, 2, 2))
    local broken = state:tileAt(3, 2)
    expect(broken.destroyed and not broken.blocker and not broken.losBlocker and broken.coverEdges.west == "none", "terrain destruction should clear blocker, LoS, and cover")
    state:apply(TacticsState.commands.shove("warden", "custodian", "east", 1, 1))
    expect(state:unit("custodian").x == 3 and state:unit("custodian").y == 2, "shove should move target through cleared terrain")
    state:apply(TacticsState.commands.pull("warden", "custodian", 1, 1))
    expect(state:unit("custodian").x == 2 and state:unit("custodian").y == 2, "pull should move target toward actor")
    state:apply(TacticsState.commands.aoe("warden", { { x = 2, y = 2 }, { x = 4, y = 2 } }, 1))
    expect(state:unit("custodian").hp == 1 and state:unit("bailiff").hp == 3, "AoE should damage every unit on affected tiles")
    state:apply(TacticsState.commands.overwatch("bailiff", { { x = 1, y = 1 } }, 2, 1))
    state:apply(TacticsState.commands.move("warden", "north"))
    expect(state:unit("warden").x == 1 and state:unit("warden").y == 1 and state:unit("warden").hp == 6, "overwatch threat zone should trigger on enemy movement")
    expect(#state.threatZones == 0, "overwatch threat zone should expire after trigger limit")
    local loaded = TacticsState.fromSnapshot(state:snapshot())
    expect(Serialize.encode(loaded:snapshot()) == Serialize.encode(state:snapshot()), "P0.6 tactical verbs should snapshot deterministically")
end

tests[#tests + 1] = function()
    local state = TacticsState.new({
        defaultAp = 4,
        board = { width = 6, height = 4 },
        units = {
            { id = "lamplighter", side = "player", x = 2, y = 2 },
            { id = "hound", side = "enemy", x = 4, y = 1, hp = 3 },
            { id = "reeve", side = "enemy", x = 5, y = 1, hp = 3 },
        },
    })
    local line = state:threatZoneTiles("lamplighter", "line", { direction = "east", length = 3 })
    local cone = state:threatZoneTiles("lamplighter", "cone", { direction = "east", length = 3, width = 1 })
    local arc = state:threatZoneTiles("lamplighter", "arc", { direction = "north", length = 1 })
    local function tileHas(list, x, y)
        for _, tile in ipairs(list) do
            if tile.x == x and tile.y == y then
                return true
            end
        end
        return false
    end
    expect(#line == 3 and tileHas(line, 3, 2) and tileHas(line, 5, 2), "line threat zone should project forward")
    expect(#cone == 7 and tileHas(cone, 4, 1) and tileHas(cone, 5, 3), "cone threat zone should widen predictably")
    expect(#arc == 3 and tileHas(arc, 2, 1) and tileHas(arc, 1, 2) and tileHas(arc, 3, 2), "arc threat zone should cover forward and side lanes")
    state:apply(TacticsState.commands.threatZone("lamplighter", "line", "east", 3, nil, 1, 1))
    expect(#state.threatZones == 1 and #state.threatZones[1].tiles == 3, "shape command should create a threat zone from geometry")
    state:apply(TacticsState.commands.move("hound", "south"))
    expect(state:unit("hound").hp == 2 and #state.threatZones == 0, "threat zone should trigger once and expire at limit")
    state:apply(TacticsState.commands.move("reeve", "south"))
    expect(state:unit("reeve").hp == 3, "expired threat zone should not trigger again")
end

tests[#tests + 1] = function()
    local state = TacticsState.new({
        defaultAp = 6,
        board = { width = 5, height = 3 },
        units = {
            { id = "warden", side = "player", x = 1, y = 2, hp = 8 },
            { id = "custodian", side = "enemy", x = 2, y = 2, hp = 5 },
            { id = "bailiff", side = "enemy", x = 4, y = 2, hp = 4 },
        },
        objectives = {
            { id = "route_machine", x = 3, y = 2, integrity = 2, evacuateAt = { x = 5, y = 2 } },
        },
    })
    state:apply(TacticsState.commands.shove("warden", "custodian", "east", 1, 1))
    expect(state:unit("custodian").x == 3 and state:objective("route_machine").integrity == 1, "forced movement into objective should damage objective integrity")
    state:apply(TacticsState.commands.shove("warden", "custodian", "east", 1, 2))
    expect(state:unit("custodian").x == 3 and state:unit("custodian").hp == 3 and state:unit("bailiff").hp == 2, "blocked forced movement into unit should deal friendly-fire collision damage")
    state:apply(TacticsState.commands.swap("warden", "custodian"))
    expect(state:unit("warden").x == 3 and state:unit("custodian").x == 1, "swap should exchange unit positions deterministically")
end

tests[#tests + 1] = function()
    local rules = TacticsState.collisionRules()
    expect(rules.blockedTile.result == "stop" and rules.blockedTile.movedUnitDamage and rules.blockedTile.deterministic, "blocked-tile collision rule should damage moved unit deterministically")
    expect(rules.occupiedTile.friendlyFire and rules.occupiedTile.occupantDamage and rules.occupiedTile.deterministic, "occupied-tile collision rule should allow deterministic friendly fire")
    expect(rules.objectiveTile.result == "enter" and rules.objectiveTile.objectiveDamage and rules.objectiveTile.deterministic, "objective collision rule should damage objective after entry")
    expect(rules.threatZoneAfterStep.triggerThreatZone and rules.threatZoneAfterStep.deterministic, "forced movement should trigger threat zones after a successful step")
end

tests[#tests + 1] = function()
    local state = TacticsState.new({
        defaultAp = 8,
        board = {
            width = 6,
            height = 2,
            tiles = {
                ["1:1"] = { coverEdges = { east = "half" } },
                ["3:1"] = { height = 1, losBlocker = true },
                ["4:1"] = { height = 0 },
            },
        },
        units = {
            { id = "duelist", side = "player", x = 1, y = 1 },
        },
    })
    state:apply(TacticsState.commands.vault("duelist", "east"))
    expect(state:unit("duelist").x == 2 and state:unit("duelist").ap == 7, "vault should cross half cover and spend AP")
    state:apply(TacticsState.commands.climb("duelist", "east", 1))
    expect(state:unit("duelist").x == 3 and state:tileAt(3, 1).losBlocker == true, "climb should use height without changing LoS blockers")
    state:apply(TacticsState.commands.drop("duelist", "east", 2))
    expect(state:unit("duelist").x == 4 and state:tileAt(3, 1).losBlocker == true, "drop should use height without hidden LoS exceptions")
    state:apply(TacticsState.commands.dash("duelist", "east", 2))
    expect(state:unit("duelist").x == 6 and state:unit("duelist").ap == 4, "dash should move multiple tiles for explicit AP cost")
    local blocked = TacticsState.new({
        board = {
            width = 2,
            height = 1,
            tiles = {
                ["1:1"] = { coverEdges = { east = "full" } },
            },
        },
        units = {
            { id = "warden", x = 1, y = 1, ap = 2 },
        },
    })
    local ok, err = pcall(function()
        blocked:apply(TacticsState.commands.vault("warden", "east"))
    end)
    expect(not ok and err:find("vault requires half cover edge", 1, true) and blocked:unit("warden").ap == 2, "full cover should block vault without spending AP")
end

tests[#tests + 1] = function()
    local state = TacticsState.new({
        board = { width = 6, height = 4 },
        units = {
            { id = "hound", side = "enemy", x = 2, y = 2 },
            { id = "scribe", side = "enemy", x = 3, y = 2 },
            { id = "reeve", side = "enemy", x = 4, y = 2 },
            { id = "regent", side = "enemy", x = 5, y = 2 },
        },
    })
    state:apply(TacticsState.commands.intent("hound", {
        mode = "exact",
        category = "attack",
        path = { { x = 2, y = 2 }, { x = 1, y = 2 } },
        targetTiles = { { x = 1, y = 2 } },
        damage = 2,
        effect = "filed",
        collision = { push = "west", damage = 1 },
        objectiveImpact = "route_machine",
    }))
    state:apply(TacticsState.commands.intent("scribe", {
        mode = "category",
        category = "repair",
        effect = "restore_cover",
    }))
    state:apply(TacticsState.commands.intent("reeve", {
        mode = "hiddenFootprint",
        category = "redacted",
        targetTiles = { { x = 1, y = 1 }, { x = 1, y = 2 } },
        damage = 1,
        revealRotations = { 1 },
        revealActions = { "unseal_intent" },
        revealClasses = { "lamplighter" },
    }))
    state:apply(TacticsState.commands.intent("regent", {
        mode = "bossStage",
        category = "destroy",
        stage = 2,
        stageCount = 3,
        mask = "back_seal",
        targetTiles = { { x = 2, y = 4 } },
        objectiveImpact = "open_register",
    }))
    local exact = state:intentPreview("hound")
    expect(exact.category == "attack" and exact.targetTiles[1].x == 1 and exact.damage == 2, "exact intent should preview target footprint and effect")
    expect(exact.sourceTile.x == 2 and exact.sourceTile.y == 2 and exact.path[2].x == 1, "exact intent should preview source tile and path")
    expect(exact.collision.push == "west" and exact.objectiveImpact == "route_machine", "exact intent should preview collision and objective impact")
    local category = state:intentPreview("scribe")
    expect(category.categoryOnly and category.category == "repair" and category.targetTiles == nil, "category intent should hide footprint")
    for _, categoryName in ipairs({ "attack", "move", "guard", "summon", "repair", "destroy", "buff", "debuff", "flee", "redacted" }) do
        state:apply(TacticsState.commands.intent("scribe", {
            mode = "category",
            category = categoryName,
            targetTiles = { { x = 1, y = 1 } },
            effect = categoryName,
        }))
        local preview = state:intentPreview("scribe")
        expect(preview.categoryOnly and preview.category == categoryName and preview.targetTiles == nil, "category intent should accept " .. categoryName)
    end
    local hidden = state:intentPreview("reeve")
    expect(hidden.footprintHidden and hidden.category == "redacted" and hidden.targetTiles == nil, "hidden footprint intent should withhold target tiles")
    local stillHidden = state:intentPreview("reeve", { rotation = 0 })
    expect(stillHidden.footprintHidden and stillHidden.targetTiles == nil, "nonmatching rotation should keep redacted footprint hidden")
    local rotationRevealed = state:intentPreview("reeve", { rotation = 1 })
    expect(rotationRevealed.targetTiles[1].x == 1 and not rotationRevealed.footprintHidden, "matching rotation should reveal hidden footprint")
    local revealed = state:intentPreview("reeve", { reveal = true })
    expect(revealed.targetTiles[2].y == 2 and not revealed.footprintHidden, "revealed hidden intent should expose private footprint")
    local classRevealed = state:intentPreview("reeve", { revealClass = "lamplighter", revealAction = "unseal_intent" })
    expect(classRevealed.targetTiles[2].y == 2 and not classRevealed.footprintHidden, "class action should reveal hidden footprint")
    local boss = state:intentPreview("regent")
    expect(boss.mode == "bossStage" and boss.stage == 2 and boss.stageCount == 3 and boss.footprintHidden and boss.mask == "back_seal", "boss-stage intent should expose stage and mask while hiding footprint")
    local loaded = TacticsState.fromSnapshot(state:snapshot())
    expect(Serialize.encode(loaded:snapshot()) == Serialize.encode(state:snapshot()), "mixed intents should snapshot deterministically")
end

tests[#tests + 1] = function()
    local state = TacticsState.new({
        board = { width = 4, height = 3 },
        units = {
            { id = "warden", side = "player", x = 2, y = 2, hp = 5 },
            { id = "fusekeeper", side = "enemy", x = 4, y = 2 },
            { id = "bailiff", side = "enemy", x = 3, y = 1 },
        },
        objectives = {
            { id = "route_machine", x = 1, y = 1, integrity = 3, maxIntegrity = 3, evacuateAt = { x = 4, y = 3 } },
        },
    })
    state:apply(TacticsState.commands.intent("fusekeeper", {
        mode = "fuse",
        category = "attack",
        countdown = 2,
        anchor = { kind = "tile", x = 2, y = 2 },
        targetTiles = { { x = 2, y = 2 } },
        trigger = { kind = "damage", damage = 2 },
    }))
    local tileFuse = state:intentPreview("fusekeeper")
    expect(tileFuse.countdown == 2 and tileFuse.anchor.kind == "tile" and tileFuse.targetTiles[1].x == 2, "tile fuse should preview countdown anchor and target")
    state:apply(TacticsState.commands.tickIntentFuse("fusekeeper"))
    expect(state:intentPreview("fusekeeper").countdown == 1 and state:unit("warden").hp == 5, "fuse tick should decrement before trigger")
    state:apply(TacticsState.commands.tickIntentFuse("fusekeeper"))
    expect(state:intentPreview("fusekeeper") == nil and state:unit("warden").hp == 3, "fuse should trigger deterministic tile damage at zero")
    state:apply(TacticsState.commands.intent("bailiff", {
        mode = "fuse",
        category = "destroy",
        countdown = 1,
        anchor = { kind = "object", id = "route_machine" },
        trigger = { kind = "damageObjective", objective = "route_machine", damage = 1 },
    }))
    local objectFuse = state:intentPreview("bailiff")
    expect(objectFuse.anchor.kind == "object" and objectFuse.anchor.id == "route_machine" and objectFuse.countdown == 1, "object fuse should preview object countdown")
    state:apply(TacticsState.commands.tickIntentFuse("bailiff"))
    expect(state:objective("route_machine").integrity == 2, "object fuse should trigger objective damage")
    state:apply(TacticsState.commands.intent("fusekeeper", {
        mode = "fuse",
        category = "debuff",
        countdown = 1,
        anchor = { kind = "enemy", id = "fusekeeper" },
        trigger = { kind = "status", target = "warden", status = "marked", turns = 2, amount = 1 },
    }))
    local enemyFuse = state:intentPreview("fusekeeper")
    expect(enemyFuse.anchor.kind == "enemy" and enemyFuse.anchor.id == "fusekeeper", "enemy fuse should preview enemy countdown anchor")
    state:apply(TacticsState.commands.tickIntentFuse("fusekeeper"))
    expect(state:hasStatus("warden", "marked"), "enemy fuse should trigger deterministic status")
    local loaded = TacticsState.fromSnapshot(state:snapshot())
    expect(Serialize.encode(loaded:snapshot()) == Serialize.encode(state:snapshot()), "fuse intents should snapshot deterministically")
end

tests[#tests + 1] = function()
    local state = TacticsState.new({
        defaultAp = 3,
        board = { width = 4, height = 3 },
        units = {
            { id = "warden", side = "player", x = 2, y = 2, hp = 5 },
            { id = "oracle", side = "enemy", x = 4, y = 2 },
        },
        objectives = {
            { id = "seal", x = 1, y = 1, integrity = 1, maxIntegrity = 3, evacuateAt = { x = 4, y = 3 } },
        },
    })
    local function declareConditional()
        state:apply(TacticsState.commands.intent("oracle", {
            mode = "conditional",
            category = "attack",
            branches = {
                {
                    condition = { kind = "targetMoved", target = "warden" },
                    intent = { mode = "exact", category = "attack", targetTiles = { { x = 2, y = 3 } }, damage = 2, effect = "fire_cone" },
                    trigger = { kind = "damage", target = "warden", damage = 2 },
                },
                {
                    condition = "otherwise",
                    intent = { mode = "exact", category = "repair", targetTiles = { { x = 1, y = 1 } }, effect = "repair_seal" },
                    trigger = { kind = "repairObjective", objective = "seal", amount = 1 },
                },
            },
        }))
    end
    declareConditional()
    local preview = state:intentPreview("oracle")
    expect(preview.mode == "conditional" and #preview.branches == 2 and preview.branches[1].condition.from.x == 2, "conditional intent should preview declared branches and source condition")
    state:apply(TacticsState.commands.resolveConditionalIntent("oracle"))
    expect(state:objective("seal").integrity == 2 and state:unit("warden").hp == 5, "conditional otherwise branch should repair seal")
    declareConditional()
    state:apply(TacticsState.commands.move("warden", "south"))
    state:apply(TacticsState.commands.resolveConditionalIntent("oracle"))
    expect(state:unit("warden").hp == 3 and state:intentPreview("oracle") == nil, "conditional targetMoved branch should fire after movement")
    local loaded = TacticsState.fromSnapshot(state:snapshot())
    expect(Serialize.encode(loaded:snapshot()) == Serialize.encode(state:snapshot()), "conditional intents should snapshot deterministically")
end

tests[#tests + 1] = function()
    local state = TacticsState.new({
        board = {
            width = 8,
            height = 4,
            tiles = {
                ["1:1"] = { hazard = { kind = "burn", active = true, damage = 1 } },
                ["1:2"] = { hazard = { kind = "flood", active = true, damage = 1 } },
            },
        },
        units = {
            { id = "stunner", side = "enemy", x = 2, y = 2 },
            { id = "shoved", side = "enemy", x = 3, y = 2 },
            { id = "los", side = "enemy", x = 4, y = 2 },
            { id = "cover", side = "enemy", x = 5, y = 2 },
            { id = "sealed", side = "enemy", x = 6, y = 2 },
            { id = "hacked", side = "enemy", x = 7, y = 2 },
            { id = "doused", side = "enemy", x = 8, y = 2 },
            { id = "drained", side = "enemy", x = 2, y = 3 },
            { id = "boss", side = "enemy", x = 3, y = 3 },
        },
    })
    local function exactIntent(unitId)
        state:apply(TacticsState.commands.intent(unitId, { mode = "exact", category = "attack", targetTiles = { { x = 1, y = 4 } }, damage = 1 }))
    end
    exactIntent("stunner")
    state:apply(TacticsState.commands.interruptIntent("stunner", "stun", { turns = 1 }))
    expect(state:intentPreview("stunner") == nil and state:hasStatus("stunner", "stunned"), "stun interrupt should prevent intent and apply stun")
    exactIntent("shoved")
    state:apply(TacticsState.commands.interruptIntent("shoved", "shove", { direction = "north", distance = 1 }))
    expect(state:intentPreview("shoved") == nil and state:unit("shoved").y == 1, "shove interrupt should move source and prevent intent")
    exactIntent("los")
    state:apply(TacticsState.commands.interruptIntent("los", "losBreak"))
    expect(state:intentPreview("los") == nil, "LoS break interrupt should prevent intent")
    exactIntent("cover")
    state:apply(TacticsState.commands.interruptIntent("cover", "coverRaise", { x = 1, y = 3 }))
    expect(state:intentPreview("cover") == nil and state:tileAt(1, 3).coverEdges.north == "half", "cover raise interrupt should raise cover and prevent intent")
    exactIntent("sealed")
    state:apply(TacticsState.commands.interruptIntent("sealed", "seal", { turns = 1 }))
    expect(state:intentPreview("sealed") == nil and state:hasStatus("sealed", "sealed"), "seal interrupt should prevent intent and apply sealed")
    exactIntent("hacked")
    state:apply(TacticsState.commands.interruptIntent("hacked", "hack"))
    expect(state:intentPreview("hacked") == nil, "hack interrupt should prevent intent")
    exactIntent("doused")
    state:apply(TacticsState.commands.interruptIntent("doused", "douse", { x = 1, y = 1 }))
    expect(state:intentPreview("doused") == nil and state:tileAt(1, 1).state == "doused" and not state:tileAt(1, 1).hazard.active, "douse interrupt should clear hazard and prevent intent")
    exactIntent("drained")
    state:apply(TacticsState.commands.interruptIntent("drained", "drain", { x = 1, y = 2 }))
    expect(state:intentPreview("drained") == nil and state:tileAt(1, 2).state == "drained", "drain interrupt should drain tile and prevent intent")
    state:apply(TacticsState.commands.intent("boss", {
        mode = "bossStage",
        category = "destroy",
        stage = 1,
        stageCount = 2,
        mask = "rear_weak_point",
        targetTiles = { { x = 2, y = 4 } },
    }))
    expect(state:intentPreview("boss").footprintHidden, "masked boss intent should hide footprint before weak point exposure")
    state:apply(TacticsState.commands.interruptIntent("boss", "exposeWeakPoint"))
    local exposed = state:intentPreview("boss")
    expect(exposed.revealed and exposed.targetTiles[1].x == 2 and exposed.mask == nil, "expose weak point should reveal masked intent without cancelling it")
    local loaded = TacticsState.fromSnapshot(state:snapshot())
    expect(Serialize.encode(loaded:snapshot()) == Serialize.encode(state:snapshot()), "interrupt state should snapshot deterministically")
end

tests[#tests + 1] = function()
    local state = TacticsState.new({
        board = { width = 5, height = 3 },
        units = {
            { id = "edict", side = "enemy", x = 2, y = 2 },
            { id = "fuse", side = "enemy", x = 3, y = 2 },
            { id = "haze", side = "enemy", x = 4, y = 2 },
        },
    })
    state:apply(TacticsState.commands.intent("edict", {
        mode = "exact",
        category = "attack",
        targetTiles = { { x = 1, y = 2 } },
        damage = 1,
        escalation = { after = 1, damageDelta = 2, category = "destroy", effect = "edict_escalated" },
    }))
    state:apply(TacticsState.commands.advanceIntentPressure("edict", "ignored"))
    local escalated = state:intentPreview("edict")
    expect(escalated.ignoredTurns == 1 and escalated.damage == 3 and escalated.category == "destroy" and escalated.effect == "edict_escalated", "ignored exact intent should escalate damage category and effect")
    state:apply(TacticsState.commands.intent("fuse", {
        mode = "fuse",
        category = "attack",
        countdown = 3,
        targetTiles = { { x = 1, y = 3 } },
        trigger = { kind = "damage", damage = 1 },
        escalation = { after = 1, countdownDelta = -1 },
    }))
    state:apply(TacticsState.commands.advanceIntentPressure("fuse", "ignored"))
    expect(state:intentPreview("fuse").countdown == 2, "ignored fuse intent should escalate countdown pressure")
    state:apply(TacticsState.commands.intent("haze", {
        mode = "exact",
        category = "debuff",
        targetTiles = { { x = 5, y = 2 } },
        damage = 2,
        decay = { damageDelta = -1, removeAtZeroDamage = true },
    }))
    state:apply(TacticsState.commands.advanceIntentPressure("haze", "decay"))
    expect(state:intentPreview("haze").damage == 1 and state:intentPreview("haze").ignoredTurns == 0, "decay should lower stale intent pressure")
    state:apply(TacticsState.commands.advanceIntentPressure("haze", "decay"))
    expect(state:intentPreview("haze") == nil, "decay should remove zero-pressure intent")
    local loaded = TacticsState.fromSnapshot(state:snapshot())
    expect(Serialize.encode(loaded:snapshot()) == Serialize.encode(state:snapshot()), "intent pressure should snapshot deterministically")
end

tests[#tests + 1] = function()
    local state = TacticsState.new({
        board = { width = 4, height = 3 },
        units = {
            { id = "mimic", side = "enemy", x = 3, y = 2 },
            { id = "liar", side = "enemy", x = 4, y = 2 },
        },
    })
    state:apply(TacticsState.commands.intent("mimic", {
        mode = "decoy",
        decoy = { mode = "exact", category = "attack", targetTiles = { { x = 1, y = 2 } }, damage = 3, effect = "slash" },
        actual = { mode = "exact", category = "guard", targetTiles = { { x = 2, y = 2 } }, damage = 0, effect = "brace" },
        revealActions = { "inspect_intent" },
        counterplay = { "inspect_intent" },
    }))
    local hidden = state:intentPreview("mimic")
    expect(hidden.decoy and hidden.category == "attack" and hidden.targetTiles[1].x == 1 and hidden.counterplay[1] == "inspect_intent", "decoy intent should preview gated false intent and counterplay")
    local revealed = state:intentPreview("mimic", { revealAction = "inspect_intent" })
    expect(revealed.decoyRevealed and revealed.category == "guard" and revealed.targetTiles[1].x == 2, "decoy intent should reveal actual payload through reveal action")
    state:apply(TacticsState.commands.interruptIntent("mimic", "exposeWeakPoint"))
    expect(state:intentPreview("mimic").decoyRevealed, "decoy counterplay should reveal actual intent without cancelling it")
    local ok, err = pcall(function()
        state:apply(TacticsState.commands.intent("liar", {
            mode = "decoy",
            decoy = { mode = "exact", category = "attack", targetTiles = { { x = 1, y = 1 } }, damage = 9 },
            actual = { mode = "exact", category = "flee", targetTiles = { { x = 4, y = 3 } }, damage = 0 },
        }))
    end)
    expect(not ok and err:find("decoy intent needs reveal or counterplay", 1, true), "decoy intent should reject arbitrary lies without reveal or counterplay")
    local loaded = TacticsState.fromSnapshot(state:snapshot())
    expect(Serialize.encode(loaded:snapshot()) == Serialize.encode(state:snapshot()), "decoy intent should snapshot deterministically")
end

tests[#tests + 1] = function()
    local state = TacticsState.new({
        board = { width = 4, height = 4 },
        units = {
            { id = "regent", side = "enemy", x = 3, y = 3 },
        },
    })
    state:apply(TacticsState.commands.intent("regent", {
        mode = "bossStage",
        category = "destroy",
        stage = 1,
        stageCount = 3,
        mask = "front_seal",
        targetTiles = { { x = 1, y = 1 } },
        masks = {
            { phase = "edict", turn = 1, mask = "front_seal", stage = 1, targetTiles = { { x = 1, y = 1 } } },
            { phase = "choir", turn = 2, mask = "choir_seal", stage = 2, targetTiles = { { x = 2, y = 2 } } },
            { revealRotation = 1, weakPoint = "rear_seal", revealed = true, stage = 3, targetTiles = { { x = 4, y = 4 } } },
        },
    }))
    state:apply(TacticsState.commands.advanceBossIntentMask("regent", { phase = "edict", turn = 1 }))
    local edict = state:intentPreview("regent")
    expect(edict.mask == "front_seal" and edict.stage == 1 and edict.footprintHidden, "boss phase mask should hide phase footprint")
    state:apply(TacticsState.commands.advanceBossIntentMask("regent", { phase = "choir", turn = 2 }))
    local choir = state:intentPreview("regent")
    expect(choir.mask == "choir_seal" and choir.stage == 2 and choir.footprintHidden, "boss turn mask should rotate by turn")
    state:apply(TacticsState.commands.advanceBossIntentMask("regent", { rotation = 1, weakPoint = "rear_seal" }))
    local revealed = state:intentPreview("regent")
    expect(revealed.revealed and revealed.mask == nil and revealed.stage == 3 and revealed.targetTiles[1].x == 4, "camera weak-point mask should reveal boss footprint")
    local loaded = TacticsState.fromSnapshot(state:snapshot())
    expect(Serialize.encode(loaded:snapshot()) == Serialize.encode(state:snapshot()), "boss mask state should snapshot deterministically")
end

tests[#tests + 1] = function()
    local kinds = {
        "protect_route_machine",
        "protect_enclave_shelter",
        "protect_archive_shelf",
        "protect_civilian_cell",
        "protect_pressure_node",
    }
    local objectives = {}
    for index, kind in ipairs(kinds) do
        objectives[#objectives + 1] = { id = kind, kind = kind, x = index, y = 1, integrity = 2, evacuateAt = { x = 5, y = 2 } }
    end
    local state = TacticsState.new({
        board = { width = 5, height = 2 },
        units = { { id = "warden", side = "player", x = 1, y = 2 } },
        objectives = objectives,
    })
    for _, kind in ipairs(kinds) do
        expect(state:objective(kind).family == "protect" and state:objectiveStatus(kind) == "active", "protect objective kind should be accepted: " .. kind)
    end
    state:apply(TacticsState.commands.damageObjective("warden", "protect_pressure_node", 2, 0))
    expect(state:objectiveStatus("protect_pressure_node") == "failed", "protect objective should fail on zero integrity")
end

tests[#tests + 1] = function()
    local cargoKinds = { "record", "civilian", "body", "machine_core", "ledger", "fuel", "medicine", "witness" }
    local cargo = {}
    for index, kind in ipairs(cargoKinds) do
        cargo[#cargo + 1] = { id = kind, kind = kind, x = index, y = 1, integrity = 1 }
    end
    local state = TacticsState.new({
        board = { width = 8, height = 2 },
        units = { { id = "runner", side = "player", x = 1, y = 2 } },
        cargo = cargo,
        objectives = {
            { id = "ledger_extract", kind = "extract_ledger", x = 8, y = 2, integrity = 1, evacuateAt = { x = 8, y = 2 } },
        },
    })
    for _, kind in ipairs(cargoKinds) do
        expect(state:cargoItem(kind).kind == kind, "extract cargo kind should be accepted: " .. kind)
    end
    expect(state:objective("ledger_extract").family == "extract", "extract objective should use extract family")
    state:apply(TacticsState.commands.extractObjective("runner", "ledger_extract", 0))
    expect(state:objectiveStatus("ledger_extract") == "complete", "extract objective should complete deterministically")
end

tests[#tests + 1] = function()
    local kinds = { "disable_seal", "disable_bell", "disable_valve", "disable_kiln", "disable_audit_lens" }
    local objectives = {}
    for index, kind in ipairs(kinds) do
        objectives[#objectives + 1] = { id = kind, kind = kind, x = index, y = 1, integrity = 1, evacuateAt = { x = 5, y = 2 } }
    end
    local state = TacticsState.new({
        board = { width = 5, height = 2 },
        units = { { id = "saboteur", side = "player", x = 1, y = 2 } },
        objectives = objectives,
    })
    for _, kind in ipairs(kinds) do
        expect(state:objective(kind).family == "disable", "disable objective kind should be accepted: " .. kind)
    end
    state:apply(TacticsState.commands.disableObjective("saboteur", "disable_audit_lens", "collapsed_lens", 0))
    local result = state:objectiveResult("disable_audit_lens")
    expect(result.status == "complete" and result.disabled, "disable objective should complete deterministically")
end

tests[#tests + 1] = function()
    local audit = TacticsState.auditObjectiveTypes()
    local objectiveTypes = {}
    expect(audit.valid, "vertical slice objective types should audit")
    for _, objectiveType in ipairs(TacticsState.objectiveTypes()) do
        objectiveTypes[objectiveType.id] = objectiveType
        expect(TacticsState.commands[objectiveType.command], "objective type should name supported command: " .. objectiveType.id)
        expect(objectiveType.preview and objectiveType.counterplay and objectiveType.success and objectiveType.failure, "objective type should expose preview metadata: " .. objectiveType.id)
        local spec = TacticsProcgen.generateArchiveRouteBoard(objectiveType.boardFixture, 3600)
        local state = TacticsState.new(spec)
        expect(spec.objectives[1].kind == objectiveType.kind, "objective type fixture should generate matching kind: " .. objectiveType.id)
        expect(state:objective(spec.objectives[1].id).family == objectiveType.id, "objective type fixture should instantiate family: " .. objectiveType.id)
    end
    expect(objectiveTypes.protect and objectiveTypes.extract and objectiveTypes.disable and #TacticsState.objectiveTypes() == 3, "vertical slice should expose protect extract disable objective types")
    local state = TacticsState.new({
        board = { width = 3, height = 2 },
        units = { { id = "warden", side = "player", x = 1, y = 2 }, { id = "thief", side = "player", x = 2, y = 2 }, { id = "saboteur", side = "player", x = 3, y = 2 } },
        objectives = {
            { id = "shelf", kind = objectiveTypes.protect.kind, x = 1, y = 1, integrity = 2, evacuateAt = { x = 1, y = 2 } },
            { id = "record", kind = objectiveTypes.extract.kind, x = 2, y = 1, integrity = 1, evacuateAt = { x = 2, y = 2 } },
            { id = "lens", kind = objectiveTypes.disable.kind, x = 3, y = 1, integrity = 1, evacuateAt = { x = 3, y = 2 } },
        },
        cargo = { { id = "proof", kind = objectiveTypes.extract.cargoKind, x = 2, y = 1, integrity = 1 } },
    })
    state:apply(TacticsState.commands.damageObjective("warden", "shelf", 1, 0))
    state:apply(TacticsState.commands.extractObjective("thief", "record", 0))
    state:apply(TacticsState.commands.disableObjective("saboteur", "lens", "lens_blinded", 0))
    expect(state:objectiveStatus("shelf") == "active", "protect objective should stay active above zero integrity")
    expect(state:objectiveStatus("record") == "complete" and state:objectiveResult("record").extracted, "extract objective should complete with extracted result")
    expect(state:objectiveStatus("lens") == "complete" and state:objectiveResult("lens").disabled, "disable objective should complete with disabled result")
end

tests[#tests + 1] = function()
    local kinds = { "repair_cover", "repair_machinery", "repair_floodgate", "repair_bridge", "repair_ward" }
    local objectives = {}
    for index, kind in ipairs(kinds) do
        objectives[#objectives + 1] = { id = kind, kind = kind, x = index, y = 1, integrity = 1, maxIntegrity = 3, evacuateAt = { x = 5, y = 2 } }
    end
    local state = TacticsState.new({
        board = { width = 5, height = 2 },
        units = { { id = "mender", side = "player", x = 1, y = 2, ap = 4 } },
        objectives = objectives,
    })
    for _, kind in ipairs(kinds) do
        expect(state:objective(kind).family == "repair", "repair objective kind should be accepted: " .. kind)
    end
    state:apply(TacticsState.commands.repairObjective("mender", "repair_floodgate", 5, 1))
    expect(state:objective("repair_floodgate").integrity == 3 and state:unit("mender").ap == 3, "repair objective should spend AP and restore up to max")
end

tests[#tests + 1] = function()
    local state = TacticsState.new({
        board = { width = 3, height = 2 },
        units = {
            { id = "warden", side = "player", x = 2, y = 1 },
            { id = "bailiff", side = "enemy", x = 3, y = 2 },
        },
        objectives = {
            { id = "claim", kind = "hold_claim", x = 2, y = 1, integrity = 1, requiredTurns = 2, escalateIntents = true, evacuateAt = { x = 1, y = 2 } },
        },
    })
    state:apply(TacticsState.commands.intent("bailiff", { mode = "exact", category = "attack", targetTiles = { { x = 2, y = 1 } }, damage = 1, escalation = { after = 1, damageDelta = 1 } }))
    state:apply(TacticsState.commands.tickHoldObjective("claim"))
    expect(state:objective("claim").heldTurns == 1 and state:intentPreview("bailiff").damage == 2, "hold objective should tick presence and escalate intents")
    state:apply(TacticsState.commands.tickHoldObjective("claim"))
    expect(state:objectiveStatus("claim") == "complete", "hold objective should complete after required turns")
end

tests[#tests + 1] = function()
    local state = TacticsState.new({
        board = { width = 3, height = 2 },
        units = {
            { id = "warden", side = "player", x = 3, y = 2 },
            { id = "scout", side = "player", x = 2, y = 2 },
        },
        objectives = {
            { id = "evac", kind = "evacuate_board", x = 3, y = 2, integrity = 1, minUnits = 2, minObjectives = 0, boardCollapseIn = 2, evacuateAt = { x = 3, y = 2 } },
        },
    })
    state:apply(TacticsState.commands.evacuate("warden", "evac", 0))
    expect(state:evacuationProgress("evac").units == 1 and state:objectiveStatus("evac") == "active", "evacuation should track minimum units")
    state:apply(TacticsState.commands.move("scout", "east"))
    state:apply(TacticsState.commands.evacuate("scout", "evac", 0))
    expect(state:objectiveStatus("evac") == "complete", "evacuation should complete at minimum units")
    local collapse = TacticsState.new({
        board = { width = 2, height = 1 },
        units = { { id = "late", side = "player", x = 1, y = 1 } },
        objectives = {
            { id = "evac", kind = "evacuate_board", x = 2, y = 1, integrity = 1, minUnits = 1, boardCollapseIn = 1, evacuateAt = { x = 2, y = 1 } },
        },
    })
    collapse:apply(TacticsState.commands.tickEvacuationObjective("evac"))
    expect(collapse:objectiveStatus("evac") == "failed" and collapse:objectiveResult("evac").failureCarryover.reason == "board_collapse", "evacuation should fail when board collapse timer expires")
end

tests[#tests + 1] = function()
    local state = TacticsState.new({
        board = { width = 4, height = 2 },
        units = {
            { id = "left", side = "player", x = 1, y = 1, ap = 2 },
            { id = "right", side = "player", x = 4, y = 1, ap = 2 },
        },
        objectives = {
            {
                id = "split",
                kind = "split_switch",
                x = 1,
                y = 1,
                integrity = 1,
                evacuateAt = { x = 4, y = 2 },
                switches = {
                    { id = "left_switch", x = 1, y = 1, dependency = "right_switch" },
                    { id = "right_switch", x = 4, y = 1, dependency = "left_switch", revealRotation = 1 },
                },
            },
        },
    })
    expect(state:splitObjectivePreview("split", { rotation = 0 }).switches[2].hidden, "split dependency should hide until matching rotation")
    expect(not state:splitObjectivePreview("split", { rotation = 1 }).switches[2].hidden, "split dependency should reveal at matching rotation")
    state:apply(TacticsState.commands.activateSplitObjective("left", "split", "left_switch", 0))
    expect(state:objectiveStatus("split") == "active", "one split switch should not complete objective")
    state:apply(TacticsState.commands.activateSplitObjective("right", "split", "right_switch", 0))
    expect(state:objectiveStatus("split") == "complete", "all split switches should complete objective")
end

tests[#tests + 1] = function()
    local state = TacticsState.new({
        board = { width = 2, height = 1 },
        units = { { id = "thief", side = "player", x = 2, y = 1, ap = 3 } },
        objectives = {
            { id = "ledger", kind = "stealth_read", x = 1, y = 1, integrity = 1, requiredReads = 2, exposureCap = 1, minUnits = 1, evacuateAt = { x = 2, y = 1 } },
        },
    })
    state:apply(TacticsState.commands.stealthReadObjective("thief", "ledger", 2, 0))
    expect(state:objectiveStatus("ledger") == "active" and state:objective("ledger").readCount == 2, "stealth read should gather info before evacuation")
    state:apply(TacticsState.commands.evacuate("thief", "ledger", 0))
    expect(state:objectiveStatus("ledger") == "complete", "stealth read should complete after read and evacuation")
    local exposed = TacticsState.new({
        board = { width = 1, height = 1 },
        exposure = 2,
        units = { { id = "thief", side = "player", x = 1, y = 1 } },
        objectives = {
            { id = "ledger", kind = "stealth_read", x = 1, y = 1, integrity = 1, requiredReads = 1, exposureCap = 1, evacuateAt = { x = 1, y = 1 } },
        },
    })
    exposed:apply(TacticsState.commands.stealthReadObjective("thief", "ledger", 1, 0))
    expect(exposed:objectiveStatus("ledger") == "failed" and exposed:objectiveResult("ledger").failureCarryover.reason == "exposure_cap", "stealth read should fail when exposure cap is exceeded")
end

tests[#tests + 1] = function()
    local state = TacticsState.new({
        board = { width = 2, height = 1 },
        units = {
            { id = "warden", side = "player", x = 1, y = 1, hp = 4 },
            { id = "thief", side = "player", x = 2, y = 1, hp = 3 },
        },
        objectives = {
            {
                id = "choice",
                kind = "sacrifice_choice",
                x = 1,
                y = 1,
                integrity = 2,
                evacuateAt = { x = 2, y = 1 },
                choices = {
                    { id = "save_squad", objectiveDamage = 1, lootLost = "sealed_ledger" },
                    { id = "save_objective", squadDamage = 1, factionStandingDelta = -1 },
                },
            },
        },
    })
    state:apply(TacticsState.commands.chooseSacrificeObjective("choice", "save_objective"))
    local result = state:objectiveResult("choice")
    expect(result.status == "complete" and result.choice == "save_objective" and result.factionStandingDelta == -1, "sacrifice choice should record chosen tradeoff")
    expect(state:unit("warden").hp == 3 and state:unit("thief").hp == 2, "sacrifice choice should apply deterministic squad damage")
end

tests[#tests + 1] = function()
    local state = TacticsState.new({
        board = {
            width = 3,
            height = 1,
            tiles = {
                ["2:1"] = { state = "drained" },
            },
        },
        units = { { id = "warden", side = "player", x = 1, y = 1 } },
        objectives = {
            {
                id = "ritual",
                kind = "boss_procedure",
                x = 3,
                y = 1,
                integrity = 1,
                evacuateAt = { x = 1, y = 1 },
                ritualSteps = {
                    { id = "open_register", weakPoint = "rear_seal" },
                    { id = "drain_lens", terrain = { x = 2, y = 1, state = "drained" } },
                },
            },
        },
    })
    state:apply(TacticsState.commands.counterBossProcedureObjective("ritual", "open_register", { weakPoint = "rear_seal" }))
    expect(state:objectiveStatus("ritual") == "active", "one boss procedure counter should not complete ritual")
    state:apply(TacticsState.commands.counterBossProcedureObjective("ritual", "drain_lens"))
    expect(state:objectiveStatus("ritual") == "complete", "all boss procedure counters should complete ritual")
end

tests[#tests + 1] = function()
    local mechanics = ZoneCatalog.tileMechanics("buried_archive")
    expect(#mechanics == 12, "Buried Archive should define 12 tile mechanics")
    local seen = {}
    for _, mechanic in ipairs(mechanics) do
        seen[mechanic.id] = mechanic
        expect(mechanic.subject and mechanic.verb and mechanic.effect, "archive tile mechanic should include subject verb effect")
    end
    for _, id in ipairs({
        "archive_shelf_shift",
        "archive_claim_desk",
        "archive_claim_line",
        "archive_sealed_door",
        "archive_witness_drawer",
        "archive_falling_records",
        "archive_name_lock",
        "archive_audit_beam",
        "archive_misfile_pit",
        "archive_ledger_bridge",
        "archive_paper_swarm",
        "archive_back_face_seal",
    }) do
        expect(seen[id], "missing archive tile mechanic " .. id)
    end
end

tests[#tests + 1] = function()
    local objects = ZoneCatalog.objects("buried_archive")
    expect(#objects == 8, "Buried Archive should define 8 objects")
    local seen = {}
    for _, object in ipairs(objects) do
        seen[object.id] = object
        expect(object.apCost and object.apCost > 0, "archive object should include AP cost")
        expect(object.hp and object.hp > 0, "archive object should include HP")
        expect(object.losEffect and object.coverState and object.rotation, "archive object should include LoS cover rotation")
    end
    for _, id in ipairs({
        "rolling_shelf",
        "oath_desk",
        "sealed_stacks_door",
        "witness_drawer_bank",
        "record_crate",
        "name_lock_plinth",
        "audit_lens_stand",
        "ledger_bridge_winch",
    }) do
        expect(seen[id], "missing archive object " .. id)
    end
end

tests[#tests + 1] = function()
    local mechanics = ZoneCatalog.tileMechanics("salt_cistern")
    expect(#mechanics == 12, "Salt Cistern should define 12 tile mechanics")
    local seen = {}
    for _, mechanic in ipairs(mechanics) do
        seen[mechanic.id] = mechanic
        expect(mechanic.subject and mechanic.verb and mechanic.effect, "cistern tile mechanic should include subject verb effect")
    end
    for _, id in ipairs({
        "cistern_valve_turn",
        "cistern_sluice_current",
        "cistern_flood_lane",
        "cistern_brine_pool",
        "cistern_salt_mist",
        "cistern_pressure_bell",
        "cistern_pearl_cyst",
        "cistern_pump_bridge",
        "cistern_undertow_tile",
        "cistern_drain_grate",
        "cistern_floating_cover",
        "cistern_waterline_height",
    }) do
        expect(seen[id], "missing cistern tile mechanic " .. id)
    end
end

tests[#tests + 1] = function()
    local objects = ZoneCatalog.objects("salt_cistern")
    expect(#objects == 8, "Salt Cistern should define 8 objects")
    local seen = {}
    for _, object in ipairs(objects) do
        seen[object.id] = object
        expect(object.apCost and object.apCost > 0, "cistern object should include AP cost")
        expect(object.hp and object.hp > 0, "cistern object should include HP")
        expect(object.losEffect and object.coverState and object.rotation, "cistern object should include LoS cover rotation")
        expect(object.floodEffect and object.objectiveEffect, "cistern object should include flood and objective effects")
    end
    for _, id in ipairs({
        "tide_valve",
        "sluice_gate",
        "pressure_bell_frame",
        "pearl_cyst_cluster",
        "pump_bridge_wheel",
        "drain_grate_cap",
        "floating_barricade",
        "waterline_gauge",
    }) do
        expect(seen[id], "missing cistern object " .. id)
    end
end

tests[#tests + 1] = function()
    local mechanics = ZoneCatalog.tileMechanics("ember_warrens")
    expect(#mechanics == 12, "Ember Warrens should define 12 tile mechanics")
    local seen = {}
    for _, mechanic in ipairs(mechanics) do
        seen[mechanic.id] = mechanic
        expect(mechanic.subject and mechanic.verb and mechanic.effect, "warrens tile mechanic should include subject verb effect")
    end
    for _, id in ipairs({
        "warrens_kiln_heat",
        "warrens_ash_choke",
        "warrens_bellows_cone",
        "warrens_glass_floor",
        "warrens_vitrified_cover",
        "warrens_heat_lane",
        "warrens_fuel_store",
        "warrens_ember_oil",
        "warrens_furnace_door",
        "warrens_cinder_vent",
        "warrens_white_coal_pressure",
        "warrens_meltable_bridge",
    }) do
        expect(seen[id], "missing warrens tile mechanic " .. id)
    end
end

tests[#tests + 1] = function()
    local objects = ZoneCatalog.objects("ember_warrens")
    expect(#objects == 8, "Ember Warrens should define 8 objects")
    local seen = {}
    for _, object in ipairs(objects) do
        seen[object.id] = object
        expect(object.apCost and object.apCost > 0, "warrens object should include AP cost")
        expect(object.hp and object.hp > 0, "warrens object should include HP")
        expect(object.losEffect and object.coverState and object.rotation, "warrens object should include LoS cover rotation")
        expect(object.burnEffect and object.douseEffect and object.glassifyEffect, "warrens object should include burn douse glassify")
    end
    for _, id in ipairs({
        "kiln_mouth",
        "ash_heap",
        "bellows_spine",
        "glass_screen",
        "fuel_cart",
        "ember_oil_cask",
        "furnace_door_chain",
        "white_coal_cradle",
    }) do
        expect(seen[id], "missing warrens object " .. id)
    end
end

tests[#tests + 1] = function()
    local audit = ZoneCatalog.auditDestructibleLocations()
    expect(audit.ok, "destructible location audit should pass")
    local rules = ZoneCatalog.destructibleRules()
    for _, kind in ipairs(ZoneCatalog.requiredDestructibleKinds) do
        local rule = rules[kind]
        expect(rule and audit.coverage[kind] == rule.objectId, "destructible rule should cover kind: " .. kind)
        expect(rule.hp > 0 and rule.apCost > 0 and rule.breakEffect and rule.repairCounterplay and rule.preview, "destructible rule should include gameplay metadata: " .. kind)
        expect(rule.deterministic == true, "destructible rule should be deterministic: " .. kind)
    end
end

tests[#tests + 1] = function()
    for _, zoneId in ipairs({ "buried_archive", "salt_cistern", "ember_warrens" }) do
        local facts = ZoneCatalog.rotationFacts(zoneId)
        expect(#facts >= 4, zoneId .. " should define at least 4 rotation facts")
        for _, fact in ipairs(facts) do
            expect(fact.id and fact.fact and fact.planningImpact, zoneId .. " rotation fact should include metadata")
            expect(fact.changesState == false, zoneId .. " rotation fact should not alter logical state")
        end
    end
end

tests[#tests + 1] = function()
    for _, zoneId in ipairs({ "buried_archive", "salt_cistern", "ember_warrens" }) do
        local count = 0
        for _, mechanic in ipairs(ZoneCatalog.tileMechanics(zoneId)) do
            if mechanic.helpsEitherSide then
                count = count + 1
            end
        end
        expect(count >= 3, zoneId .. " should define at least 3 double-edged terrain mechanics")
    end
end

tests[#tests + 1] = function()
    local warden = ClassCatalog.class("warden")
    expect(warden and warden.name == "Warden", "Warden catalog entry should exist")
    expect(#ClassCatalog.loadouts("warden") == 3, "Warden should define 3 loadouts")
    expect(ClassCatalog.loadoutSlots("warden") == 2, "Warden should define 2 loadout slots")
    expect(#ClassCatalog.tools("warden") == 5, "Warden should define 5 tools")
    expect(#ClassCatalog.terrainInteractions("warden") == 2, "Warden should define 2 terrain interactions")
    expect(warden.weakness and warden.weakness.id == "slow_to_pivot", "Warden should define weakness")
    expect(warden.replayFixture == "warden_brace_line", "Warden should define replay fixture")
end

tests[#tests + 1] = function()
    local duelist = ClassCatalog.class("duelist")
    expect(duelist and duelist.name == "Duelist", "Duelist catalog entry should exist")
    expect(#ClassCatalog.loadouts("duelist") == 3, "Duelist should define 3 loadouts")
    expect(ClassCatalog.loadoutSlots("duelist") == 2, "Duelist should define 2 loadout slots")
    expect(#ClassCatalog.tools("duelist") == 5, "Duelist should define 5 tools")
    expect(#ClassCatalog.terrainInteractions("duelist") == 2, "Duelist should define 2 terrain interactions")
    expect(duelist.weakness and duelist.weakness.id == "overextends", "Duelist should define weakness")
    expect(duelist.replayFixture == "duelist_flank_dash", "Duelist should define replay fixture")
end

tests[#tests + 1] = function()
    local apothecary = ClassCatalog.class("mender")
    expect(apothecary and apothecary.name == "Apothecary", "Apothecary catalog entry should exist")
    expect(#ClassCatalog.loadouts("mender") == 3, "Apothecary should define 3 loadouts")
    expect(ClassCatalog.loadoutSlots("mender") == 2, "Apothecary should define 2 loadout slots")
    expect(#ClassCatalog.tools("mender") == 5, "Apothecary should define 5 tools")
    expect(#ClassCatalog.terrainInteractions("mender") == 2, "Apothecary should define 2 terrain interactions")
    expect(apothecary.weakness and apothecary.weakness.id == "triage_burden", "Apothecary should define weakness")
    expect(apothecary.replayFixture == "apothecary_smoke_triage", "Apothecary should define replay fixture")
end

tests[#tests + 1] = function()
    local arcanist = ClassCatalog.class("arcanist")
    expect(arcanist and arcanist.name == "Arcanist", "Arcanist catalog entry should exist")
    expect(#ClassCatalog.loadouts("arcanist") == 3, "Arcanist should define 3 loadouts")
    expect(ClassCatalog.loadoutSlots("arcanist") == 2, "Arcanist should define 2 loadout slots")
    expect(#ClassCatalog.tools("arcanist") == 5, "Arcanist should define 5 tools")
    expect(#ClassCatalog.terrainInteractions("arcanist") == 2, "Arcanist should define 2 terrain interactions")
    expect(arcanist.weakness and arcanist.weakness.id == "overread", "Arcanist should define weakness")
    expect(arcanist.replayFixture == "arcanist_seal_read", "Arcanist should define replay fixture")
end

tests[#tests + 1] = function()
    local thief = ClassCatalog.class("harrier")
    expect(thief and thief.name == "Thief", "Thief catalog entry should exist")
    expect(#ClassCatalog.loadouts("harrier") == 3, "Thief should define 3 loadouts")
    expect(ClassCatalog.loadoutSlots("harrier") == 2, "Thief should define 2 loadout slots")
    expect(#ClassCatalog.tools("harrier") == 5, "Thief should define 5 tools")
    expect(#ClassCatalog.terrainInteractions("harrier") == 2, "Thief should define 2 terrain interactions")
    expect(thief.weakness and thief.weakness.id == "thin_loyalty", "Thief should define weakness")
    expect(thief.replayFixture == "thief_route_lift", "Thief should define replay fixture")
end

tests[#tests + 1] = function()
    local chirurgeon = ClassCatalog.class("chirurgeon")
    expect(chirurgeon and chirurgeon.name == "Chirurgeon", "Chirurgeon catalog entry should exist")
    expect(#ClassCatalog.loadouts("chirurgeon") == 3, "Chirurgeon should define 3 loadouts")
    expect(ClassCatalog.loadoutSlots("chirurgeon") == 2, "Chirurgeon should define 2 loadout slots")
    expect(#ClassCatalog.tools("chirurgeon") == 5, "Chirurgeon should define 5 tools")
    expect(#ClassCatalog.terrainInteractions("chirurgeon") == 2, "Chirurgeon should define 2 terrain interactions")
    expect(chirurgeon.weakness and chirurgeon.weakness.id == "clinical_delay", "Chirurgeon should define weakness")
    expect(chirurgeon.replayFixture == "chirurgeon_stabilize_machine", "Chirurgeon should define replay fixture")
end

tests[#tests + 1] = function()
    local exile = ClassCatalog.class("exile")
    expect(exile and exile.name == "Exile", "Exile catalog entry should exist")
    expect(#ClassCatalog.loadouts("exile") == 3, "Exile should define 3 loadouts")
    expect(ClassCatalog.loadoutSlots("exile") == 2, "Exile should define 2 loadout slots")
    expect(#ClassCatalog.tools("exile") == 5, "Exile should define 5 tools")
    expect(#ClassCatalog.terrainInteractions("exile") == 2, "Exile should define 2 terrain interactions")
    expect(exile.weakness and exile.weakness.id == "self_risk_spike", "Exile should define weakness")
    expect(exile.replayFixture == "exile_break_cover", "Exile should define replay fixture")
end

tests[#tests + 1] = function()
    local lamplighter = ClassCatalog.class("lamplighter")
    expect(lamplighter and lamplighter.name == "Lamplighter", "Lamplighter catalog entry should exist")
    expect(#ClassCatalog.loadouts("lamplighter") == 3, "Lamplighter should define 3 loadouts")
    expect(ClassCatalog.loadoutSlots("lamplighter") == 2, "Lamplighter should define 2 loadout slots")
    expect(#ClassCatalog.tools("lamplighter") == 5, "Lamplighter should define 5 tools")
    expect(#ClassCatalog.terrainInteractions("lamplighter") == 2, "Lamplighter should define 2 terrain interactions")
    expect(lamplighter.weakness and lamplighter.weakness.id == "bright_target", "Lamplighter should define weakness")
    expect(lamplighter.replayFixture == "lamplighter_beacon_reveal", "Lamplighter should define replay fixture")
end

tests[#tests + 1] = function()
    local merchant = ClassCatalog.class("merchant")
    expect(merchant and merchant.name == "Merchant", "Merchant catalog entry should exist")
    expect(#ClassCatalog.loadouts("merchant") == 3, "Merchant should define 3 loadouts")
    expect(ClassCatalog.loadoutSlots("merchant") == 2, "Merchant should define 2 loadout slots")
    expect(#ClassCatalog.tools("merchant") == 5, "Merchant should define 5 tools")
    expect(#ClassCatalog.terrainInteractions("merchant") == 2, "Merchant should define 2 terrain interactions")
    expect(merchant.weakness and merchant.weakness.id == "compounding_debt", "Merchant should define weakness")
    expect(merchant.replayFixture == "merchant_appraise_debt", "Merchant should define replay fixture")
end

tests[#tests + 1] = function()
    local audit = ClassCatalog.auditBoardVerbs()
    expect(audit.valid, "class catalog should use board verbs instead of RPG roles")
    local ids = { "warden", "duelist", "mender", "arcanist", "harrier", "chirurgeon", "exile", "lamplighter", "merchant" }
    local seen = {}
    for _, classId in ipairs(ids) do
        local verbs = ClassCatalog.boardVerbs(classId)
        expect(#verbs >= 3, classId .. " should define board verbs")
        for _, loadout in ipairs(ClassCatalog.loadouts(classId)) do
            expect(loadout.boardVerb and loadout.role == nil, classId .. " loadout should define board verb")
            seen[loadout.boardVerb] = true
        end
    end
    expect(seen.brace_line and seen.dash_strike and seen.cleanse_hazard and seen.break_terrain, "class loadouts should cover board verbs")
end

tests[#tests + 1] = function()
    local audit = ClassCatalog.auditLoadoutShape()
    expect(audit.valid, "class catalog should define 2 slots, 3-5 tools, and terrain interactions")
    for _, classId in ipairs({ "warden", "duelist", "mender", "arcanist", "harrier", "chirurgeon", "exile", "lamplighter", "merchant" }) do
        local tools = ClassCatalog.tools(classId)
        expect(ClassCatalog.loadoutSlots(classId) == 2, classId .. " should define 2 loadout slots")
        expect(#tools >= 3 and #tools <= 5, classId .. " should define 3-5 tools")
        expect(#ClassCatalog.terrainInteractions(classId) >= 1, classId .. " should define a terrain interaction")
    end
end

tests[#tests + 1] = function()
    local audit = ClassCatalog.auditLoadoutUnlocks()
    expect(audit.valid, "class catalog should unlock loadouts through run class options")
    for _, classId in ipairs({ "warden", "duelist", "mender", "arcanist", "harrier", "chirurgeon", "exile", "lamplighter", "merchant" }) do
        local runUnlocks = 0
        for _, entry in ipairs(ClassCatalog.loadoutUnlocks(classId)) do
            local unlock = entry.unlock
            expect(unlock and unlock.rewardKind == "class_option" and unlock.rewardId, classId .. " loadout should define class option unlock")
            expect(not unlock.stat and not unlock.statBonus and not unlock.permanentStat, classId .. " loadout unlock should not be a stat reward")
            if unlock.scope == "run" then
                runUnlocks = runUnlocks + 1
            end
        end
        expect(runUnlocks >= 1, classId .. " should include run-sourced loadout unlock")
    end
end

tests[#tests + 1] = function()
    local planned = { "warden", "duelist", "mender", "arcanist", "harrier", "chirurgeon", "exile", "lamplighter", "merchant" }
    local plannedSet = {}
    local classCount = 0
    for _, classId in ipairs(planned) do
        plannedSet[classId] = true
    end
    for classId in pairs(ClassCatalog.classes) do
        classCount = classCount + 1
        expect(plannedSet[classId], "class catalog should only expose planned full-scope classes: " .. classId)
    end
    expect(classCount == 9, "class catalog should expose exactly 9 full-scope classes")
    for _, classId in ipairs(planned) do
        local class = ClassCatalog.class(classId)
        local seenLoadouts = {}
        local runChoices = 0
        expect(class and #ClassCatalog.loadouts(classId) == 3, classId .. " should define 3 loadout choices")
        expect(ClassCatalog.loadoutSlots(classId) == 2, classId .. " should keep two loadout slots")
        for _, loadout in ipairs(ClassCatalog.loadouts(classId)) do
            local unlock = loadout.unlock or {}
            expect(not seenLoadouts[loadout.id], classId .. " loadout ids should be unique")
            seenLoadouts[loadout.id] = true
            expect(loadout.boardVerb and #(loadout.tools or {}) == 2, classId .. " loadout should expose board verb and two tools")
            expect(unlock.rewardKind == "class_option" and unlock.rewardId and not unlock.stat and not unlock.statBonus and not unlock.permanentStat, classId .. " unlock should be class option, not stat power")
            if unlock.scope == "run" then
                runChoices = runChoices + 1
                expect(unlock.source and unlock.preview, classId .. " run unlock should expose source and preview")
            end
        end
        expect(runChoices >= 2, classId .. " should expose at least two run-level loadout choices")
    end
end

tests[#tests + 1] = function()
    local audit = ClassCatalog.auditStarterRoster()
    local ids = ClassCatalog.starterClassIds()
    local expected = { "warden", "duelist", "mender", "harrier" }
    expect(audit.valid, "starter roster should expose four classes with two loadouts each")
    expect(#ids == 4, "starter roster should define exactly four classes")
    for index, classId in ipairs(expected) do
        expect(ids[index] == classId, "starter roster should preserve starter class order")
        local loadouts = ClassCatalog.starterLoadouts(classId)
        expect(#loadouts == 2, classId .. " starter class should expose two loadouts")
        for _, loadout in ipairs(loadouts) do
            expect(loadout.classId == classId and loadout.availableAt == "vertical_slice_start", classId .. " starter loadout should mark slice availability")
            expect(loadout.boardVerb and #(loadout.tools or {}) == 2 and loadout.preview, classId .. " starter loadout should expose board verb tools preview")
            expect(loadout.strongBoardFixture and loadout.awkwardBoardFixture, classId .. " starter loadout should define strong and awkward board fixtures")
            expect(ClassCatalog.loadout(classId, loadout.id), classId .. " starter loadout should reference class catalog loadout")
        end
    end
    expect(#ClassCatalog.starterLoadouts("arcanist") == 0 and #ClassCatalog.starterLoadouts("merchant") == 0, "advanced classes should not enter starter roster")
end

tests[#tests + 1] = function()
    local audit = ClassCatalog.auditTraitDomains()
    expect(audit.valid, "class catalog should cover required trait domains")
    local traits = ClassCatalog.characterTraits()
    expect(#traits == 20, "class catalog should define 20 character traits")
    local domains = {}
    local ids = {}
    for _, trait in ipairs(traits) do
        expect(trait.id and trait.domain and trait.effect, "character trait should include id domain effect")
        expect(not ids[trait.id], "character trait ids should be unique")
        ids[trait.id] = true
        domains[trait.domain] = true
    end
    for _, domain in ipairs({ "ap", "movement", "los", "cover", "carry", "reveal", "cooldown", "objectiveRepair", "eventOutcome" }) do
        expect(domains[domain], "character traits should cover domain " .. domain)
    end
    for _, domain in ipairs(ClassCatalog.requiredTraitDomainList()) do
        expect(domains[domain], "required trait domain missing " .. domain)
    end
end

tests[#tests + 1] = function()
    local audit = ClassCatalog.auditInjuryDebtConstraints()
    expect(audit.valid, "class catalog should define deterministic injury/debt tactical domains")
    local constraints = ClassCatalog.injuryDebtConstraints()
    expect(#constraints == 15, "class catalog should define 15 injury/debt constraints")
    local types = {}
    local ids = {}
    local domains = {}
    for _, constraint in ipairs(constraints) do
        expect(constraint.id and constraint.type and constraint.domain and constraint.constraint, "injury/debt should include id type domain constraint")
        expect(constraint.noRandomActionLoss == true, "injury/debt should not cause random action loss")
        expect(not ids[constraint.id], "injury/debt ids should be unique")
        ids[constraint.id] = true
        types[constraint.type] = true
        domains[constraint.domain] = true
    end
    expect(types.injury and types.debt, "injury/debt constraints should include both types")
    for _, domain in ipairs(ClassCatalog.requiredInjuryDebtDomainList()) do
        expect(domains[domain], "injury/debt constraints should cover domain " .. domain)
    end
end

tests[#tests + 1] = function()
    local audit = ClassCatalog.auditSquadScaling()
    expect(audit.valid, "squad scaling should define monotonic board variance rules")
    local previousCells = 0
    local previousEnemyBudget = 0
    for _, size in ipairs({ 2, 3, 4, 5, 6 }) do
        local scale = ClassCatalog.squadScale(size)
        local board = scale.board
        local variance = scale.varianceRules
        expect(scale, "squad scaling should include size " .. size)
        expect(scale.apBudget == size * 3, "squad scaling should set AP budget for size " .. size)
        expect(scale.deploymentSlots == size, "squad scaling should set deployment slots for size " .. size)
        expect(scale.enemyBudgetMultiplier and scale.objectivePressure and scale.reinforcementCap and scale.boardScale, "squad scaling should include budget metadata")
        expect(board and board.width and board.height and board.objectiveAnchors and board.spawnPockets and board.retreatRoutes, "squad scaling should include board dimensions for size " .. size)
        expect(variance and variance.deploymentPattern and variance.laneCount and variance.coverFields and variance.hazardBudget, "squad scaling should include variance rules for size " .. size)
        expect(board.width * board.height > previousCells, "squad scaling should grow board cells for size " .. size)
        expect(scale.enemyBudgetMultiplier >= previousEnemyBudget, "squad scaling should not lower enemy budget for size " .. size)
        previousCells = board.width * board.height
        previousEnemyBudget = scale.enemyBudgetMultiplier
    end
    expect(ClassCatalog.squadScale(1) == nil and ClassCatalog.squadScale(7) == nil, "squad scaling should only cover 2 through 6")
end

tests[#tests + 1] = function()
    local enemies = EnemyCatalog.common("archive")
    expect(#enemies == 10, "Archive should define 10 common enemies")
    local ids = {}
    for _, enemy in ipairs(enemies) do
        expect(enemy.id and enemy.name and enemy.boardVerb, "archive common enemy should include id name board verb")
        expect(enemy.exactIntent and enemy.exactIntent.mode == "exact", "archive common enemy should include exact intent")
        expect(not ids[enemy.id], "archive common enemy ids should be unique")
        ids[enemy.id] = true
    end
end

tests[#tests + 1] = function()
    local audit = EnemyCatalog.auditArchetypes()
    expect(audit.ok, "enemy archetype audit should pass")
    for _, archetypeId in ipairs(EnemyCatalog.requiredArchetypes) do
        local archetype = EnemyCatalog.archetype(archetypeId)
        expect(archetype and archetype.intent and archetype.boardVerb and archetype.counterplay and archetype.preview, "enemy archetype should include tactical metadata: " .. archetypeId)
        expect(audit.coverage[archetypeId] and audit.coverage[archetypeId] > 0, "enemy archetype should be represented by a common enemy: " .. archetypeId)
    end
    for _, familyId in ipairs({ "archive", "cistern", "warrens" }) do
        for _, enemy in ipairs(EnemyCatalog.common(familyId)) do
            expect(enemy.archetype and EnemyCatalog.archetype(enemy.archetype), "common enemy should reference known archetype: " .. enemy.id)
        end
    end
end

tests[#tests + 1] = function()
    local audit = EnemyCatalog.auditExactBasicIntents()
    expect(audit.ok, "basic enemy exact-intent audit should pass")
    for _, familyId in ipairs({ "archive", "cistern", "warrens" }) do
        expect(audit.coverage[familyId] == #EnemyCatalog.common(familyId), "exact-intent audit should cover all common enemies in " .. familyId)
        for _, enemy in ipairs(EnemyCatalog.common(familyId)) do
            local intent = enemy.exactIntent
            expect(intent.source == "self" and intent.mode == "exact" and intent.deterministic == true, "common enemy exact intent should be deterministic: " .. enemy.id)
            expect(intent.targetPattern and intent.pathPattern and intent.preview, "common enemy exact intent should include preview blueprint: " .. enemy.id)
            expect(intent.counterplay and #intent.counterplay > 0 and intent.objectiveImpact ~= nil, "common enemy exact intent should include counterplay and objective impact: " .. enemy.id)
        end
    end
end

tests[#tests + 1] = function()
    local audit = EnemyCatalog.auditEliteMaskedIntents()
    expect(audit.ok, "elite masked-intent audit should pass")
    for _, familyId in ipairs({ "archive", "cistern", "warrens" }) do
        expect(audit.coverage[familyId] == #EnemyCatalog.elites(familyId), "masked-intent audit should cover all elites in " .. familyId)
        for _, enemy in ipairs(EnemyCatalog.elites(familyId)) do
            local masked = enemy.maskedIntent
            expect(enemy.partialIntent and enemy.partialIntent.mode == "category", "elite should keep category partial intent: " .. enemy.id)
            expect(masked and masked.mode == "hiddenFootprint" and masked.category == enemy.partialIntent.category, "elite should define masked footprint intent: " .. enemy.id)
            expect(masked.revealGate and masked.revealGate.weakPoint == enemy.weakPoints[1], "elite masked intent should reveal through weak point: " .. enemy.id)
            expect(masked.counterplay and #masked.counterplay >= 2 and masked.footprintHidden == true, "elite masked intent should include counterplay and hidden footprint: " .. enemy.id)
        end
    end
end

tests[#tests + 1] = function()
    local elites = EnemyCatalog.elites("archive")
    expect(#elites == 3, "Archive should define 3 elites")
    local ids = {}
    for _, enemy in ipairs(elites) do
        expect(enemy.id and enemy.name and enemy.terrainInteraction, "archive elite should include id name terrain interaction")
        expect(enemy.partialIntent and enemy.partialIntent.mode == "category", "archive elite should include partial intent")
        expect(enemy.weakPoints and #enemy.weakPoints > 0, "archive elite should include weak points")
        expect(not ids[enemy.id], "archive elite ids should be unique")
        ids[enemy.id] = true
    end
end

tests[#tests + 1] = function()
    local alpha = EnemyCatalog.alpha("archive")
    expect(alpha and alpha.id == "shelf_warden", "Archive should define Shelf Warden alpha")
    expect(alpha.visiblePreBoard == true, "Archive alpha should be visible before board")
    expect(alpha.preBoardThreat and alpha.routeChoiceChange and alpha.boardGenerationChange, "Archive alpha should alter route and board generation")
end

tests[#tests + 1] = function()
    local eliteAudit = EnemyCatalog.auditSliceElite()
    local bossAudit = BossCatalog.auditSliceBoss()
    local eliteSpec = EnemyCatalog.sliceEliteSpec()
    local elite = EnemyCatalog.sliceElite()
    local bossSpec = BossCatalog.sliceBossSpec()
    local boss = BossCatalog.sliceBoss()
    local routeSpec = TacticsProcgen.generateArchiveRouteBoard(eliteSpec.boardFixture, 3700)
    local foundElite = false
    expect(eliteAudit.ok and elite and elite.id == "shelf_knight", "slice should select one Archive elite")
    expect(elite.maskedIntent and elite.maskedIntent.mode == "hiddenFootprint" and elite.weakPoints[1] == "rear_binding", "slice elite should expose masked intent and weak point")
    for _, enemy in ipairs(routeSpec.encounterDirector.enemyMix) do
        if enemy.id == elite.id and enemy.role == eliteSpec.role then
            foundElite = true
        end
    end
    expect(foundElite, "archive elite route should include selected slice elite")
    expect(bossAudit.ok and boss and bossSpec.bossId == "vault_regent", "slice should select one Archive boss")
    expect(boss.zone == "buried_archive" and boss.tacticalContract.exactIntent and boss.tacticalContract.nonDamageCounter.damage == 0, "slice boss should expose tactical contract")
    expect(#boss.phaseProcedure == 3 and boss.phaseProcedure[1].clock.visible, "slice boss should expose visible phase procedure")
end

tests[#tests + 1] = function()
    local enemies = EnemyCatalog.common("cistern")
    expect(#enemies == 10, "Cistern should define 10 common enemies")
    local ids = {}
    for _, enemy in ipairs(enemies) do
        expect(enemy.id and enemy.name and enemy.waterPressureVerb, "cistern common enemy should include id name water/pressure verb")
        expect(enemy.exactIntent and enemy.exactIntent.mode == "exact", "cistern common enemy should include exact intent")
        expect(not ids[enemy.id], "cistern common enemy ids should be unique")
        ids[enemy.id] = true
    end
end

tests[#tests + 1] = function()
    local elites = EnemyCatalog.elites("cistern")
    expect(#elites == 3, "Cistern should define 3 elites")
    local ids = {}
    for _, enemy in ipairs(elites) do
        expect(enemy.id and enemy.name and enemy.floodDrainCounterplay, "cistern elite should include id name flood/drain counterplay")
        expect(enemy.partialIntent and enemy.partialIntent.mode == "category", "cistern elite should include partial intent")
        expect(enemy.weakPoints and #enemy.weakPoints > 0, "cistern elite should include weak points")
        expect(not ids[enemy.id], "cistern elite ids should be unique")
        ids[enemy.id] = true
    end
end

tests[#tests + 1] = function()
    local alpha = EnemyCatalog.alpha("cistern")
    expect(alpha and alpha.id == "depth_bailiff", "Cistern should define Depth Bailiff alpha")
    expect(alpha.visiblePreBoard == true, "Cistern alpha should be visible before board")
    expect(alpha.preBoardThreat and alpha.routeChoiceChange and alpha.boardGenerationChange, "Cistern alpha should alter route and board generation")
end

tests[#tests + 1] = function()
    local enemies = EnemyCatalog.common("warrens")
    expect(#enemies == 10, "Warrens should define 10 common enemies")
    local ids = {}
    for _, enemy in ipairs(enemies) do
        expect(enemy.id and enemy.name and enemy.heatAshGlassVerb, "warrens common enemy should include id name heat/ash/glass verb")
        expect(enemy.exactIntent and enemy.exactIntent.mode == "exact", "warrens common enemy should include exact intent")
        expect(not ids[enemy.id], "warrens common enemy ids should be unique")
        ids[enemy.id] = true
    end
end

tests[#tests + 1] = function()
    local elites = EnemyCatalog.elites("warrens")
    expect(#elites == 3, "Warrens should define 3 elites")
    local ids = {}
    for _, enemy in ipairs(elites) do
        expect(enemy.id and enemy.name and enemy.burnDouseGlassCounterplay, "warrens elite should include id name burn/douse/glass counterplay")
        expect(enemy.partialIntent and enemy.partialIntent.mode == "category", "warrens elite should include partial intent")
        expect(enemy.weakPoints and #enemy.weakPoints > 0, "warrens elite should include weak points")
        expect(not ids[enemy.id], "warrens elite ids should be unique")
        ids[enemy.id] = true
    end
end

tests[#tests + 1] = function()
    local alpha = EnemyCatalog.alpha("warrens")
    expect(alpha and alpha.id == "white_furnace", "Warrens should define White Furnace alpha")
    expect(alpha.visiblePreBoard == true, "Warrens alpha should be visible before board")
    expect(alpha.preBoardThreat and alpha.routeChoiceChange and alpha.boardGenerationChange, "Warrens alpha should alter route and board generation")
end

tests[#tests + 1] = function()
    local specs = {
        buried_archive = { family = "archive", prefix = "archive_", verbField = "boardVerb", eliteField = "terrainInteraction", required = { "archive_audit_beam", "archive_shelf_shift", "archive_back_face_seal" } },
        salt_cistern = { family = "cistern", prefix = "cistern_", verbField = "waterPressureVerb", eliteField = "floodDrainCounterplay", required = { "cistern_flood_lane", "cistern_valve_turn", "cistern_waterline_height" } },
        ember_warrens = { family = "warrens", prefix = "warrens_", verbField = "heatAshGlassVerb", eliteField = "burnDouseGlassCounterplay", required = { "warrens_heat_lane", "warrens_kiln_heat", "warrens_vitrified_cover" } },
    }
    for zoneId, spec in pairs(specs) do
        local mechanics = ZoneCatalog.tileMechanics(zoneId)
        local objects = ZoneCatalog.objects(zoneId)
        local facts = ZoneCatalog.rotationFacts(zoneId)
        local seen = {}
        expect(#mechanics == 12 and #objects == 8 and #facts >= 4, zoneId .. " should expose full-scope terrain grammar")
        for _, mechanic in ipairs(mechanics) do
            expect(mechanic.id:find(spec.prefix, 1, true) == 1, zoneId .. " mechanic should keep zone-local prefix: " .. mechanic.id)
            seen[mechanic.id] = true
        end
        for _, id in ipairs(spec.required) do
            expect(seen[id], zoneId .. " should expose signature terrain mechanic " .. id)
        end
        expect(#EnemyCatalog.common(spec.family) == 10 and #EnemyCatalog.elites(spec.family) == 3, spec.family .. " should expose full enemy family")
        for _, enemy in ipairs(EnemyCatalog.common(spec.family)) do
            expect(enemy[spec.verbField], spec.family .. " common enemy should expose local verb: " .. enemy.id)
        end
        for _, enemy in ipairs(EnemyCatalog.elites(spec.family)) do
            expect(enemy[spec.eliteField], spec.family .. " elite should expose local counterplay: " .. enemy.id)
        end
    end
end

tests[#tests + 1] = function()
    local enemies = EnemyCatalog.globalEnemies()
    expect(#enemies == 8, "global pressure should define 8 enemies")
    local factions = {}
    local ids = {}
    for _, enemy in ipairs(enemies) do
        expect(enemy.id and enemy.name and enemy.faction and enemy.rareEvent and enemy.pressureEffect, "global enemy should include pressure metadata")
        expect(not ids[enemy.id], "global enemy ids should be unique")
        ids[enemy.id] = true
        factions[enemy.faction] = true
    end
    expect(factions.survey_office and factions.lamplighter and factions.merchant, "global enemies should cover Survey Office, Lamplighter, and Merchant")
end

tests[#tests + 1] = function()
    for _, enemy in ipairs(EnemyCatalog.allEnemies()) do
        expect(enemy.utilityBehavior and enemy.utilityBehavior.effect, "enemy should include no-damage utility behavior: " .. enemy.id)
        expect(enemy.utilityBehavior.damage == 0, "enemy utility behavior should deal no damage: " .. enemy.id)
    end
end

tests[#tests + 1] = function()
    local boss = BossCatalog.boss("codex_reeve")
    expect(boss and boss.name == "Codex Reeve" and boss.zone == "buried_archive", "Codex Reeve boss catalog entry should exist")
    expect(#boss.board.auditLines == 2, "Codex Reeve should define audit lines")
    expect(#boss.board.apDisableTiles == 3, "Codex Reeve should define AP disable tiles")
    expect(boss.board.weakPoints[1].id == "open_register", "Codex Reeve should define Open Register weak point")
    expect(#boss.board.rotationBackSeals == 4, "Codex Reeve should define rotation-revealed back seals")
end

tests[#tests + 1] = function()
    local boss = BossCatalog.boss("vault_regent")
    expect(boss and boss.name == "Vault Regent" and boss.zone == "buried_archive", "Vault Regent boss catalog entry should exist")
    expect(#boss.board.claimBeams == 2, "Vault Regent should define claim beams")
    expect(#boss.board.nameCollateral == 2, "Vault Regent should define name collateral")
    expect(#boss.board.legalCover == 2, "Vault Regent should define legal cover")
    expect(#boss.board.writPillars == 3 and boss.board.writPillars[1].hp > 0, "Vault Regent should define destructible writ pillars")
end

tests[#tests + 1] = function()
    local boss = BossCatalog.boss("pearl_choir")
    expect(boss and boss.name == "Pearl Choir" and boss.zone == "salt_cistern", "Pearl Choir boss catalog entry should exist")
    expect(#boss.board.refloodingLanes == 2, "Pearl Choir should define reflooding lanes")
    expect(#boss.board.choirThroats == 2, "Pearl Choir should define choir throats")
    expect(#boss.board.movingWaterline.states == 4 and boss.board.movingWaterline.rule, "Pearl Choir should define moving waterline")
    expect(#boss.board.pressureBellAdds == 2, "Pearl Choir should define pressure bell adds")
end

tests[#tests + 1] = function()
    local boss = BossCatalog.boss("bell_diver")
    expect(boss and boss.name == "Bell Diver" and boss.zone == "salt_cistern", "Bell Diver boss catalog entry should exist")
    expect(#boss.board.hookLanes == 2, "Bell Diver should define hook lanes")
    expect(boss.board.weakPoints[1].id == "bell_lung", "Bell Diver should define Bell Lung weak point")
    expect(boss.board.floodTollCountdown.start == 3 and boss.board.floodTollCountdown.failure, "Bell Diver should define flood-toll countdown")
    expect(#boss.board.lowGroundPunishment == 2, "Bell Diver should define low-ground punishment")
end

tests[#tests + 1] = function()
    local boss = BossCatalog.boss("kiln_vicar")
    expect(boss and boss.name == "Kiln Vicar" and boss.zone == "ember_warrens", "Kiln Vicar boss catalog entry should exist")
    expect(boss.board.vitrifyTarget.selector == "most exposed unit or objective", "Kiln Vicar should define vitrify target")
    expect(#boss.board.haloVents == 3, "Kiln Vicar should define halo vents")
    expect(#boss.board.douseRoutes == 2, "Kiln Vicar should define douse routes")
    expect(#boss.board.ashChokeCover == 2, "Kiln Vicar should define ash-choke cover")
end

tests[#tests + 1] = function()
    local boss = BossCatalog.boss("cinder_prioress")
    expect(boss and boss.name == "Cinder Prioress" and boss.zone == "ember_warrens", "Cinder Prioress boss catalog entry should exist")
    expect(#boss.board.furnacePhases == 3, "Cinder Prioress should define furnace phases")
    expect(#boss.board.glassCrownReflectors == 3, "Cinder Prioress should define glass crown reflectors")
    expect(#boss.board.fuelObjectiveTradeoffs == 2, "Cinder Prioress should define fuel-objective tradeoffs")
end

tests[#tests + 1] = function()
    for _, boss in ipairs(BossCatalog.allBosses()) do
        expect(#boss.variants == 2, "boss should define 2 variants: " .. boss.name)
        for _, variant in ipairs(boss.variants) do
            expect(variant.arenaModifier and variant.addFamily and variant.weakPointLocation and variant.objectivePressure, "boss variant should define all swap axes: " .. variant.id)
        end
    end
end

tests[#tests + 1] = function()
    for _, boss in ipairs(BossCatalog.allBosses()) do
        local contract = boss.tacticalContract
        expect(contract and contract.exactIntent and contract.exactIntent.mode == "exact", "boss should define exact intent: " .. boss.name)
        expect(contract.partialIntent and contract.partialIntent.mode == "category", "boss should define partial intent: " .. boss.name)
        expect(contract.terrainMutation and contract.terrainMutation.effect, "boss should define terrain mutation: " .. boss.name)
        expect(contract.objectiveThreat and contract.objectiveThreat.effect, "boss should define objective threat: " .. boss.name)
        expect(contract.nonDamageCounter and contract.nonDamageCounter.damage == 0, "boss should define non-damage counter: " .. boss.name)
    end
end

tests[#tests + 1] = function()
    local audit = BossCatalog.auditPhaseProcedures()
    expect(audit.ok, "boss phase-procedure audit should pass")
    for _, bossId in ipairs(BossCatalog.allBossIds()) do
        local boss = BossCatalog.boss(bossId)
        expect(audit.coverage[bossId] == 3, "boss should define 3 phase procedures: " .. boss.name)
        for _, phase in ipairs(boss.phaseProcedure) do
            expect(phase.tilePattern and phase.rotatingWeakPoint and phase.rotatingWeakPoint.rotation ~= nil, "boss phase should define tile pattern and rotating weak point: " .. boss.name)
            expect(phase.terrainConversion and phase.terrainConversion.to and phase.objectivePressure and phase.objectivePressure.effect, "boss phase should define terrain conversion and objective pressure: " .. boss.name)
            expect(phase.clock and phase.clock.visible == true and phase.counterplay and phase.preview, "boss phase should define visible clock, counterplay, and preview: " .. boss.name)
        end
    end
end

tests[#tests + 1] = function()
    local ids = {}
    for _, template in ipairs(RunCatalog.templates()) do
        ids[template.id] = template
        expect(template.objective and template.layout and template.pressure and template.validationFocus, "board template should include objective layout pressure validation: " .. template.id)
    end
    for _, id in ipairs({ "kill_light", "protect_heavy", "extraction", "repair", "stealth", "split_squad", "holdout", "boss_route" }) do
        expect(ids[id] and RunCatalog.boardTemplate(id) == ids[id], "missing board template " .. id)
    end
end

tests[#tests + 1] = function()
    local ids = {}
    for _, check in ipairs(RunCatalog.validators()) do
        ids[check.id] = check
        expect(check.input and check.reject, "board validator should define input and reject reason: " .. check.id)
    end
    for _, id in ipairs({ "reachability", "los_sanity", "cover_density", "objective_feasibility", "enemy_intent_density", "exit_access" }) do
        expect(ids[id], "missing board validator " .. id)
    end
end

tests[#tests + 1] = function()
    local weights = RunCatalog.weights()
    for _, id in ipairs({ "enemies", "objectives", "hazards", "cover", "reinforcements", "redactedIntent", "bossModifiers" }) do
        expect(type(weights[id]) == "number", "missing difficulty budget weight " .. id)
    end
    expect(weights.enemies > 0 and weights.cover < 0 and weights.bossModifiers > weights.hazards, "difficulty weights should price pressure and offset cover")
end

tests[#tests + 1] = function()
    local ids = {}
    for _, node in ipairs(RunCatalog.routeNodes()) do
        ids[node.id] = node
        expect(node.risk and node.reward and node.preview, "route node should define risk reward preview: " .. node.id)
    end
    for _, id in ipairs({ "combat", "repair", "enclave", "market", "event", "elite", "boss", "rest", "cursed_shortcut", "high_reward_extraction" }) do
        expect(ids[id], "missing route node type " .. id)
    end
end

tests[#tests + 1] = function()
    local map = RunCatalog.generateMap(2404, { zone = "salt_cistern" })
    local report = RunCatalog.validateMap(map)
    expect(map.zone == "salt_cistern" and report.valid, "run map should generate valid zone graph")
    expect(#map.choices == 2 and map.nodeById[map.choices[1]].preview.risk and map.nodeById[map.choices[1]].preview.reward, "run map should expose route choices with previews")
    expect(map.nodeById.enclave_request.request.enclave and map.nodeById.enclave_request.request.reward, "run map should include enclave request")
    expect(map.nodeById.event_node.kind == "event" and map.nodeById.event_node.eventId, "run map should include event node")
    expect(map.nodeById.boss_gate.gate.boss and map.nodeById.boss_gate.gate.requires[1], "run map should include boss gate")
    expect(Serialize.encode(map) == Serialize.encode(RunCatalog.generateMap(2404, { zone = "salt_cistern" })), "run map should be deterministic per seed")
end

tests[#tests + 1] = function()
    local map = RunCatalog.generateArchiveSliceMap(3905)
    local report = RunCatalog.validateArchiveSliceMap(map)
    local nodeKinds = {}
    local variants = {}
    expect(map.id == "buried_archive_slice_map" and map.zone == "buried_archive" and report.valid, "archive slice map should validate")
    expect(#map.choices == 2 and map.bossGate == "boss_gate", "archive slice map should expose choices and boss gate")
    for _, node in ipairs(map.nodes) do
        nodeKinds[node.kind] = true
        if node.kind ~= "start" then
            expect(node.reward and node.complication and node.preview and node.preview.visible, "archive slice map node should expose reward complication preview: " .. node.id)
        end
        if node.boardVariant then
            variants[node.boardVariant] = true
            expect(TacticsProcgen.archiveRouteVariant(node.boardVariant), "archive slice map should reference known board variant: " .. node.boardVariant)
            expect(node.boardSeed, "archive slice map board node should include board seed: " .. node.id)
        end
    end
    for _, kind in ipairs({ "combat", "enclave", "event", "repair", "elite", "boss", "cursed_shortcut", "high_reward_extraction" }) do
        expect(nodeKinds[kind], "archive slice map missing route kind " .. kind)
    end
    for _, variantId in ipairs({ "archive_entry_audit", "archive_shelf_protection", "archive_proof_extract", "archive_ledger_repair", "archive_sealed_shortcut", "archive_elite_claim" }) do
        expect(variants[variantId], "archive slice map missing board variant " .. variantId)
    end
    expect(map.nodeById.elite_claim.complication.id == "partial_intent_elite" and map.nodeById.boss_gate.bossId == BossCatalog.sliceBossSpec().bossId, "archive slice map should bind elite complication and boss")
    expect(report.counts.rewards >= 6 and report.counts.complications >= 6, "archive slice map should count route rewards and complications")
    expect(Serialize.encode(map) == Serialize.encode(RunCatalog.generateArchiveSliceMap(3905)), "archive slice map should serialize deterministically")
end

tests[#tests + 1] = function()
    local timings = {}
    for _, rule in ipairs(RunCatalog.eventRules()) do
        expect(rule.roll and rule.effect, "event RNG rule should define roll and effect: " .. rule.id)
        expect(rule.timing == "pre_board" or rule.timing == "post_board", "event RNG should not run during tactical resolution: " .. rule.id)
        timings[rule.timing] = true
    end
    expect(timings.pre_board and timings.post_board, "event RNG rules should cover pre-board and post-board timing")
end

tests[#tests + 1] = function()
    local layer = RunCatalog.rollEventLayer(2505, {
        preBoard = { alters = "board_modifier" },
        postBoard = { alters = "objective_reward" },
    })
    local report = RunCatalog.validateEventLayer(layer)
    expect(report.valid, "event layer should validate")
    expect(layer.preBoard.timing == "pre_board" and layer.preBoard.alters == "board_modifier", "event layer should roll pre-board complication")
    expect(layer.postBoard.timing == "post_board" and layer.postBoard.alters == "objective_reward", "event layer should roll post-board complication")
    expect(layer.tacticalResolutionRng == false and layer.boardStartLocksRng == true, "event layer should lock tactical RNG after board start")
    expect(Serialize.encode(layer) == Serialize.encode(RunCatalog.rollEventLayer(2505, { preBoard = { alters = "board_modifier" }, postBoard = { alters = "objective_reward" } })), "event layer should be deterministic per seed")
end

tests[#tests + 1] = function()
    local export = RunCatalog.seededExport()
    local fields = {}
    expect(export.version == 1, "seeded run export should define version")
    for _, field in ipairs(export.fields) do
        fields[field.id] = field
        expect(field.type and field.source, "seeded export field should define type and source: " .. field.id)
    end
    for _, id in ipairs({ "runSeed", "boardSeeds", "routeChoices", "squadLoadout", "eventRolls", "replayHashes" }) do
        expect(fields[id], "missing seeded export field " .. id)
    end
end

tests[#tests + 1] = function()
    local export = RunCatalog.exportSeededRun(2707, { routeChoices = { "combat_route", "event_node", "boss_gate" } })
    local report = RunCatalog.validateSeededRunExport(export)
    expect(report.valid, "seeded run export should validate")
    expect(#export.boardSeeds == 3 and #export.replayHashes == 3 and export.exportHash, "seeded run export should include seeds and replay hashes")
    expect(export.eventRolls[1].timing == "pre_board" and export.eventRolls[2].timing == "post_board", "seeded run export should include event rolls")
    expect(Serialize.encode(export) == Serialize.encode(RunCatalog.exportSeededRun(2707, { routeChoices = { "combat_route", "event_node", "boss_gate" } })), "seeded run export should be deterministic")
    local alternate = RunCatalog.exportSeededRun(2707, { routeChoices = { "enclave_request", "repair_route", "boss_gate" } })
    expect(export.exportHash ~= alternate.exportHash, "seeded run export should change when route choices change")
end

tests[#tests + 1] = function()
    local events = RunCatalog.events()
    local alters = {}
    local ids = {}
    expect(#events == 50, "run catalog should define 50 event prompts")
    for _, event in ipairs(events) do
        expect(event.id and event.prompt and event.alters, "event prompt should define id prompt alters")
        expect(not ids[event.id], "event prompt ids should be unique")
        ids[event.id] = true
        alters[event.alters] = true
    end
    for _, field in ipairs({ "route_choice", "board_modifier", "squad_state", "objective_reward", "faction_standing" }) do
        expect(alters[field], "event prompts should alter " .. field)
    end
end

tests[#tests + 1] = function()
    local icons = {}
    for _, icon in ipairs(UICatalog.iconLanguage()) do
        icons[icon.id] = icon
        expect(icon.icon and icon.shape and icon.colorRole and icon.pattern and icon.label, "UI icon should define redundant language: " .. icon.id)
    end
    for _, id in ipairs({ "ap", "move", "cover", "flanked", "los", "exact_intent", "partial_intent", "hazard", "objective", "destructible_hp", "weak_point", "extraction" }) do
        expect(icons[id] and UICatalog.icon(id) == icons[id], "missing UI icon " .. id)
    end
end

tests[#tests + 1] = function()
    local filters = {}
    for _, filter in ipairs(UICatalog.overlays()) do
        filters[filter.id] = filter
        expect(filter.icon and filter.shows and filter.hides, "overlay filter should define icon shows hides: " .. filter.id)
    end
    for _, id in ipairs({ "movement", "enemy_intent", "los", "cover", "objectives", "hazards", "hidden_revealed" }) do
        expect(filters[id], "missing overlay filter " .. id)
    end
end

tests[#tests + 1] = function()
    local function colorDistance(a, b)
        local dr = (a[1] or 0) - (b[1] or 0)
        local dg = (a[2] or 0) - (b[2] or 0)
        local db = (a[3] or 0) - (b[3] or 0)
        return math.sqrt(dr * dr + dg * dg + db * db)
    end
    local function sameColor(a, b)
        return math.abs((a[1] or 0) - (b[1] or 0)) < 0.001
            and math.abs((a[2] or 0) - (b[2] or 0)) < 0.001
            and math.abs((a[3] or 0) - (b[3] or 0)) < 0.001
            and math.abs((a[4] or 1) - (b[4] or 1)) < 0.001
    end
    local palette = UICatalog.accessiblePalette()
    expect(palette.id == "intent_cover_hazard" and #palette.modes == 4 and #palette.checks >= 4, "accessible overlay palette should define modes and checks")
    for _, id in ipairs({ "intent", "cover", "hazard" }) do
        local role = palette.roles[id]
        expect(role and role.hex and role.color and role.icon and role.pattern and role.shape and role.visible == true, "accessible overlay palette missing role metadata: " .. id)
    end
    for _, mode in ipairs({ "off", "deuteranopia", "protanopia", "tritanopia" }) do
        local settings = { colorblindMode = mode }
        local intent = Render.accessibleColor(settings, palette.roles.intent.color)
        local cover = Render.accessibleColor(settings, palette.roles.cover.color)
        local hazard = Render.accessibleColor(settings, palette.roles.hazard.color)
        expect(colorDistance(intent, cover) > 0.25, "intent and cover colors should stay separated in " .. mode)
        expect(colorDistance(intent, hazard) > 0.25, "intent and hazard colors should stay separated in " .. mode)
        expect(colorDistance(cover, hazard) > 0.25, "cover and hazard colors should stay separated in " .. mode)
    end
    local state = TacticsState.new({
        board = {
            width = 3,
            height = 1,
            tiles = {
                ["1:1"] = { coverEdges = { east = "half" } },
                ["2:1"] = { hazard = { kind = "brine", active = true } },
            },
        },
    })
    local entries = Render.tacticalOverlayEntries(state, { intents = { { x = 3, y = 1 } } })
    local byKind = {}
    for _, entry in ipairs(entries) do
        byKind[entry.kind] = byKind[entry.kind] or entry
    end
    for _, id in ipairs({ "intent", "cover", "hazard" }) do
        local entry = byKind[id]
        local role = palette.roles[id]
        expect(entry and sameColor(entry.color, role.color) and entry.icon == role.icon and entry.pattern == role.pattern, "render overlay should use accessible palette role: " .. id)
    end
end

tests[#tests + 1] = function()
    local template = UICatalog.tileInspector()
    expect(template.mechanicsLine and template.loreLine, "tile inspector should define mechanics and lore lines")
    expect(template.maxMechanicsLines == 1 and template.maxLoreLines == 1, "tile inspector should cap mechanics and lore at one line each")
    local tokens = {}
    for _, token in ipairs(template.requiredTokens) do
        tokens[token] = true
    end
    for _, token in ipairs({ "icon", "state", "verb", "effect", "apCost", "counterplay", "zoneTone", "oneSentenceLore" }) do
        expect(tokens[token], "tile inspector missing token " .. token)
    end
    local facts = {}
    for _, fact in ipairs(template.requiredFacts) do
        facts[fact.id] = fact
        expect(fact.source and fact.visible == true, "tile inspector fact should define source and visibility: " .. fact.id)
    end
    for _, id in ipairs({ "terrain", "cover", "los", "hazards", "destructible_hp", "hidden_info", "intent_traces" }) do
        expect(facts[id], "tile inspector missing fact " .. id)
    end
end

tests[#tests + 1] = function()
    local state = TacticsState.new({
        board = {
            width = 4,
            height = 3,
            tiles = {
                ["2:2"] = {
                    kind = "valve_block",
                    material = "salt",
                    height = 1,
                    coverEdges = { west = "half" },
                    blocker = true,
                    losBlocker = true,
                    destructibleHp = 4,
                    hazard = { kind = "brine", active = true, damage = 1, countdown = 2 },
                    revealed = false,
                    rotationMarks = { east = "rear_valve_label" },
                    revealClasses = { "arcanist" },
                    revealActions = { "inspect" },
                    tags = { "cistern" },
                },
            },
        },
        selectedUnitId = "warden",
        units = {
            { id = "warden", side = "player", x = 1, y = 2, ap = 2 },
            { id = "bailiff", side = "enemy", x = 4, y = 2, ap = 1 },
        },
        intents = {
            bailiff = { mode = "exact", category = "attack", targetTiles = { { x = 2, y = 2 } }, path = { { x = 3, y = 2 }, { x = 2, y = 2 } }, damage = 1, effect = "crack" },
        },
    })
    local summary = UICatalog.tileInspectorSummary(state, 2, 2, { rotation = 1 })
    expect(summary.terrain.kind == "valve_block" and summary.terrain.material == "salt" and summary.terrain.height == 1, "tile inspector should expose terrain")
    expect(summary.cover[1].direction == "west" and summary.cover[1].cover == "half", "tile inspector should expose cover")
    expect(summary.los.visible and summary.los.from.unit == "warden", "tile inspector should expose LoS from selected unit")
    expect(summary.hazards.kind == "brine" and summary.hazards.active == true, "tile inspector should expose hazards")
    expect(summary.destructibleHp.hp == 4 and summary.destructibleHp.destructible, "tile inspector should expose destructible HP")
    expect(summary.hiddenInfo.hidden and summary.hiddenInfo.currentRotationMark.mark == "rear_valve_label", "tile inspector should expose hidden info without revealing all states")
    expect(summary.intentTraces[1].unit == "bailiff" and summary.intentTraces[1].role == "target" and summary.intentTraces[1].category == "attack", "tile inspector should expose current intent traces")
end

tests[#tests + 1] = function()
    local preview = UICatalog.preview()
    local fields = {}
    expect(preview.commitGate == "before_commit", "preview contract should apply before commit")
    for _, field in ipairs(preview.fields) do
        fields[field.id] = field
        expect(field.source and field.visible == true, "preview field should define source and visibility: " .. field.id)
    end
    for _, id in ipairs({ "ap_cost", "movement_path", "damage", "push_path", "collision", "cover_change", "objective_change", "hazard_result" }) do
        expect(fields[id], "missing preview contract field " .. id)
    end
end

tests[#tests + 1] = function()
    local hud = UICatalog.tacticalHud()
    local fields = {}
    for _, field in ipairs(hud.requiredFields) do
        fields[field.id] = field
        expect(field.source and field.visible == true, "tactical HUD field should define source and visibility: " .. field.id)
    end
    for _, id in ipairs({ "selected_unit_ap", "move_preview", "action_preview", "enemy_intents", "objective_risk", "turn_order" }) do
        expect(fields[id], "missing tactical HUD field " .. id)
    end
    local state = TacticsState.new({
        board = { width = 3, height = 1 },
        selectedUnitId = "warden",
        units = {
            { id = "warden", side = "player", x = 1, y = 1, ap = 2, maxAp = 3 },
            { id = "bailiff", side = "enemy", x = 3, y = 1, ap = 1 },
        },
        objectives = {
            { id = "machine", kind = "protect_route_machinery", x = 2, y = 1, integrity = 2, evacuateAt = { x = 1, y = 1 } },
        },
        intents = {
            bailiff = { mode = "exact", category = "attack", targetTiles = { { x = 1, y = 1 } }, damage = 1 },
        },
    })
    local summary = UICatalog.tacticalHudSummary(state, { move = { apCost = 1 }, action = { damage = 1 } })
    expect(summary.selectedUnitAp.unit == "warden" and summary.selectedUnitAp.ap == 2, "tactical HUD should expose selected unit AP")
    expect(summary.movePreview.apCost == 1 and summary.actionPreview.damage == 1, "tactical HUD should expose move and action preview")
    expect(summary.enemyIntents[1].unit == "bailiff" and summary.enemyIntents[1].category == "attack", "tactical HUD should expose enemy intents")
    expect(summary.objectiveRisk[1].id == "machine" and summary.objectiveRisk[1].integrity == 2, "tactical HUD should expose objective risk")
    expect(#summary.turnOrder == 2 and summary.turnOrder[1].unit == "bailiff", "tactical HUD should expose deterministic turn order")
end

tests[#tests + 1] = function()
    local path = UICatalog.controllerPath()
    expect(path.id == "tactical_controller_path" and #path.principles == 4, "controller path should define principles")
    local map = Input.tacticalGamepadMap()
    expect(path.bindings.select == map.select.button and path.bindings.back == map.back.button, "controller path should align select/back bindings")
    expect(path.bindings.inspect == map.inspect.button and path.bindings.focus == map.focus.button, "controller path should align inspect/focus bindings")
    expect(path.bindings.rotateLeft == map.rotateLeft.button and path.bindings.rotateRight == map.rotateRight.button, "controller path should align rotation bindings")
    local stages = {}
    for _, stage in ipairs(path.stages) do
        stages[stage.id] = stage
        expect(stage.input and stage.output and stage.preview, "controller path stage should expose input output preview: " .. stage.id)
    end
    for _, id in ipairs({ "select_unit", "select_tile", "select_action", "select_target", "confirm_preview" }) do
        expect(stages[id], "controller path missing stage " .. id)
    end
    expect(stages.confirm_preview.input:find("back cancel", 1, true), "controller path should support cancel before commit")
end

tests[#tests + 1] = function()
    local readability = UICatalog.rotationChecks()
    local applies = {}
    expect(#readability.rotations == 4, "rotation readability should check four rotations")
    for _, id in ipairs(readability.appliesTo) do
        applies[id] = true
    end
    for _, filter in ipairs(UICatalog.overlays()) do
        expect(applies[filter.id], "rotation readability should apply to overlay " .. filter.id)
    end
    for _, check in ipairs(readability.checks) do
        expect(check.id and check.rule, "rotation readability check should include rule")
    end
end

tests[#tests + 1] = function()
    local tutorials = {}
    for _, step in ipairs(UICatalog.tutorials()) do
        tutorials[step.id] = step
        expect(step.teaches and step.board and step.exitCheck, "tutorial step should define teaches board exit check: " .. step.id)
    end
    for _, id in ipairs({ "movement", "cover_flank", "intent", "forced_movement", "destructible_terrain", "objective_pressure", "redacted_intent", "boss_weak_point" }) do
        expect(tutorials[id], "missing tutorial step " .. id)
    end
end

tests[#tests + 1] = function()
    local specs = {}
    for _, spec in ipairs(UICatalog.tutorialBoards()) do
        specs[spec.id] = spec
        expect(spec.teaches and spec.board and spec.units and spec.actions and spec.overlays and spec.exitCheck, "tutorial board should define full fixture metadata: " .. spec.id)
        local state = TacticsState.new({
            board = spec.board,
            units = spec.units,
            objectives = spec.objectives,
            intents = spec.intents,
        })
        expect(state.board.width == spec.board.width and state.board.height == spec.board.height, "tutorial board should instantiate: " .. spec.id)
    end
    for _, id in ipairs({ "movement", "cover_flank", "intent", "push_pull", "destruction", "objectives" }) do
        expect(specs[id] and UICatalog.tutorialBoard(id) == specs[id], "missing tutorial board " .. id)
    end
    expect(specs.movement.actions[1].preview == "movementPreview" and specs.movement.board.tiles["3:2"].hazard, "movement tutorial should include safe/unsafe preview")
    expect(specs.cover_flank.board.tiles["2:2"].coverEdges.west == "half" and specs.cover_flank.actions[2].kind == "flank", "cover tutorial should include flank preview")
    expect(specs.intent.intents.bailiff.mode == "exact" and specs.intent.actions[1].preview == "intentPreview", "intent tutorial should include exact intent preview")
    expect(specs.push_pull.actions[1].kind == "push" and specs.push_pull.actions[2].kind == "pull", "push/pull tutorial should include both forced movement verbs")
    expect(specs.destruction.board.tiles["2:1"].destructibleHp == 2 and specs.destruction.actions[1].preview == "coverBreak", "destruction tutorial should include breakable cover")
    expect(specs.objectives.objectives[1].integrity == 2 and specs.objectives.intents.bailiff.objectiveImpact == "machine", "objectives tutorial should include objective pressure")
end

tests[#tests + 1] = function()
    local smoke = UICatalog.screenshotSmoke()
    local overlays = {}
    expect(smoke.id == "tactical_overlay_smoke" and smoke.fixture and smoke.viewport.width > 0 and smoke.viewport.height > 0, "screenshot smoke target should define fixture and viewport")
    expect(#smoke.rotations == 4 and #smoke.assertions >= 5, "screenshot smoke target should define rotations and assertions")
    for _, id in ipairs(smoke.overlays) do
        overlays[id] = true
    end
    for _, filter in ipairs(UICatalog.overlays()) do
        expect(overlays[filter.id], "screenshot smoke should include overlay " .. filter.id)
    end
end

tests[#tests + 1] = function()
    local gate = GateCatalog.gate("mechanic_entry")
    local evidence = {}
    expect(gate and gate.appliesTo == "new mechanic" and gate.blocker, "mechanic entry gate should exist")
    for _, item in ipairs(gate.requiredEvidence) do
        evidence[item] = true
    end
    for _, item in ipairs({ "research_handoff", "preview_ui_spec", "replay_acceptance_test" }) do
        expect(evidence[item], "mechanic entry gate missing evidence " .. item)
    end
end

tests[#tests + 1] = function()
    local gate = GateCatalog.gate("procedural_board_ship")
    local evidence = {}
    expect(gate and gate.appliesTo == "procedural board type" and gate.minimumSeeds == 25, "procedural board ship gate should require 25 fixed seeds")
    for _, item in ipairs(gate.requiredEvidence) do
        evidence[item] = true
    end
    for _, item in ipairs({ "validator_results", "fixed_seed_batch", "reject_reason_log" }) do
        expect(evidence[item], "procedural board gate missing evidence " .. item)
    end
end

tests[#tests + 1] = function()
    local gate = GateCatalog.gate("class_loadout_ship")
    local evidence = {}
    expect(gate and gate.appliesTo == "class loadout" and gate.blocker, "class loadout gate should exist")
    for _, item in ipairs(gate.requiredEvidence) do
        evidence[item] = true
    end
    expect(evidence.strong_board_fixture and evidence.awkward_board_fixture and evidence.preview_ui_spec, "class loadout gate should require strong and awkward board evidence")
end

tests[#tests + 1] = function()
    local gate = GateCatalog.gate("enemy_ship")
    local evidence = {}
    expect(gate and gate.appliesTo == "enemy" and gate.blocker, "enemy ship gate should exist")
    for _, item in ipairs(gate.requiredEvidence) do
        evidence[item] = true
    end
    expect(evidence.intent_preview and evidence.counterplay_path and evidence.no_damage_utility_behavior, "enemy ship gate should require intent, counterplay, and utility")
end

tests[#tests + 1] = function()
    local gate = GateCatalog.gate("boss_ship")
    local evidence = {}
    expect(gate and gate.appliesTo == "boss" and gate.blocker, "boss ship gate should exist")
    for _, item in ipairs(gate.requiredEvidence) do
        evidence[item] = true
    end
    for _, item in ipairs({ "phase_chart", "arena_diagram", "objective_pressure", "replay_proof" }) do
        expect(evidence[item], "boss ship gate missing evidence " .. item)
    end
end

tests[#tests + 1] = function()
    local gate = GateCatalog.gate("borrowed_pattern_ship")
    local evidence = {}
    local index = readFile("docs/tactical-research-index.md") or ""
    expect(gate and gate.appliesTo == "borrowed pattern" and gate.sourceDocument == "docs/tactical-research-index.md", "borrowed pattern gate should point to research index")
    for _, item in ipairs(gate.requiredEvidence) do
        evidence[item] = true
    end
    expect(evidence.source_id and evidence.documented_thoth_transformation and evidence.research_index_entry, "borrowed pattern gate should require transformation evidence")
    expect(index:find("Thoth transformation", 1, true) ~= nil, "research index should document Thoth transformation")
end

tests[#tests + 1] = function()
    local manifest = readFile("docs/phase6-alpha-package.md") or ""
    local page = readFile("docs/itch-alpha-page.md") or ""
    local form = readFile(".github/ISSUE_TEMPLATE/alpha_feedback.yml") or ""
    expect(manifest:find("dist/thoth.love", 1, true) and manifest:find("phase6-alpha", 1, true), "phase 6 package manifest should identify artifact and channel")
    expect(manifest:find(".github/ISSUE_TEMPLATE/alpha_feedback.yml", 1, true) and manifest:find("make package-build", 1, true), "phase 6 package manifest should identify form and build command")
    expect(page:find("Phase 6", 1, true) and page:find("Six procedural tactical board variants", 1, true), "alpha page should describe phase 6 boards")
    expect(page:find("Shelf Knight", 1, true) and page:find("Vault Regent", 1, true), "alpha page should name selected elite and boss")
    expect(page:find("Alpha feedback", 1, true), "alpha page should point to feedback form")
    expect(form:find("Phase 6", 1, true) and form:find("Tactical readability", 1, true), "alpha feedback form should identify tactical alpha category")
    expect(form:find("Route map or loadout", 1, true) and form:find("tactical_context", 1, true), "alpha feedback form should collect tactical context")
end

tests[#tests + 1] = function()
    local state = TacticsBoard.new({
        defaultAp = 3,
        board = {
            width = 3,
            height = 3,
            tiles = {
                ["2:2"] = { coverEdges = { west = "half" }, rotationMarks = { east = "seal" } },
            },
        },
        units = {
            { id = "unit", side = "player", x = 1, y = 2, hp = 4 },
            { id = "enemy", side = "enemy", x = 3, y = 2, hp = 4 },
        },
    })
    expect(TacticsBoard.tileAt(state, 2, 2).coverEdges.west == "half", "board module should expose tile data")
    expect(TacticsUnit.select(state, "unit").id == "unit", "unit module should select units")
    expect(TacticsAP.remaining(state, "unit") == 3 and TacticsAP.spend(state, "unit", 1) == 2, "AP module should spend AP")
    expect(TacticsLoS.line(state, 1, 2, 3, 2).visible, "LoS module should expose line checks")
    expect(TacticsCover.fromAttack(state, 1, 2, 2, 2).cover == "half", "cover module should expose cover checks")
    TacticsIntent.declare(state, "enemy", { mode = "exact", category = "attack", targetTiles = { { x = 1, y = 2 } }, damage = 1 })
    expect(TacticsIntent.preview(state, "enemy").targetTiles[1].x == 1, "intent module should expose previews")
    TacticsResolution.apply(state, TacticsState.commands.wait("unit"))
    expect(TacticsProcgen.templates()[1].id == "kill_light", "procgen module should expose templates")
    local replayed = TacticsReplay.fromSnapshot(TacticsReplay.snapshot(state))
    expect(sameSnapshot(replayed, state), "tactical replay module should roundtrip snapshots")
end

tests[#tests + 1] = function()
    local spec = TacticsProcgen.generateBoard(2101)
    local report = TacticsProcgen.validateGrammarBoard(spec)
    expect(TacticsProcgen.grammar().id == "board_grammar_v1", "procgen grammar should expose board grammar id")
    expect(report.valid, "generated board grammar should validate")
    for _, part in ipairs(TacticsProcgen.requiredGrammarParts()) do
        expect(report.counts[part] and report.counts[part] > 0, "board grammar missing " .. part)
    end
    local objective = spec.grammar.components.objectiveAnchors[1]
    local state = TacticsProcgen.state(2101)
    expect(state:tileAt(objective.x, objective.y).objective.id == objective.id, "generated grammar should mark objective anchor tiles")
    expect(state:blockerAt(spec.grammar.components.sightBreaks[1].x, spec.grammar.components.sightBreaks[1].y).destructible, "generated grammar should mark sight breaks")
    expect(Serialize.encode(spec) == Serialize.encode(TacticsProcgen.generateBoard(2101)), "board grammar generation should be deterministic per seed")
end

tests[#tests + 1] = function()
    local expected = {
        buried_archive = { material = "archive", hazardKind = "audit_static", objectiveKind = "protect_archive_shelf" },
        salt_cistern = { material = "salt", hazardKind = "flood", objectiveKind = "repair_floodgate" },
        ember_warrens = { material = "ember", hazardKind = "burn", objectiveKind = "disable_kiln" },
    }
    expect(#TacticsProcgen.zoneGenerators() == 3, "procgen should expose three zone generators")
    for zoneId, expectation in pairs(expected) do
        local generator = TacticsProcgen.zoneGenerator(zoneId)
        local spec = TacticsProcgen.generateZoneBoard(zoneId, 2202)
        expect(generator and generator.zone == zoneId, zoneId .. " generator should exist")
        expect(spec.zone == zoneId and spec.generator.id == generator.id, zoneId .. " board should record generator")
        expect(spec.generator.material == expectation.material and spec.generator.hazardKind == expectation.hazardKind, zoneId .. " generator should apply terrain dressing")
        expect(spec.objectives[1].kind == expectation.objectiveKind, zoneId .. " generator should apply objective kind")
        expect(TacticsProcgen.validateGrammarBoard(spec).valid, zoneId .. " generated board should validate")
        expect(TacticsProcgen.zoneState(zoneId, 2202):tileAt(spec.objectives[1].x, spec.objectives[1].y).material == expectation.material, zoneId .. " generated state should keep material")
        expect(Serialize.encode(spec) == Serialize.encode(TacticsProcgen.generateZoneBoard(zoneId, 2202)), zoneId .. " generator should be deterministic per seed")
    end
end

tests[#tests + 1] = function()
    for _, zoneId in ipairs({ "buried_archive", "salt_cistern", "ember_warrens" }) do
        local spec = TacticsProcgen.generateDirectedZoneBoard(zoneId, 2303, { includeElite = true })
        local director = spec.encounterDirector
        expect(director.zone == zoneId and #director.enemyMix == 3, zoneId .. " director should create enemy mix")
        expect(director.intentDensity.exact == 2 and director.intentDensity.partial == 1 and director.intentDensity.cap >= director.intentDensity.threatenedTiles, zoneId .. " director should define intent density")
        expect(director.objectivePressure.objectiveKind == spec.objectives[1].kind and director.objectivePressure.visible, zoneId .. " director should bind objective pressure")
        expect(director.reinforcementTiming[1].turn >= 3 and director.reinforcementTiming[1].visibleWarningTurn == 1 and director.reinforcementTiming[1].blockable, zoneId .. " director should schedule visible blockable reinforcements")
        expect(director.spawnBlockRules[1].visible and director.spawnBlockRules[1].spawnPocket == director.reinforcementTiming[1].spawnPocket, zoneId .. " director should define visible spawn blocking")
        expect(TacticsProcgen.auditReinforcementRules(spec).ok, zoneId .. " reinforcement audit should pass")
        expect(#director.retreatRoutes[1].tiles > 0 and director.retreatRoutes[1].to.x == spec.objectives[1].evacuateAt.x, zoneId .. " director should define retreat route")
        expect(Serialize.encode(spec) == Serialize.encode(TacticsProcgen.generateDirectedZoneBoard(zoneId, 2303, { includeElite = true })), zoneId .. " director should be deterministic per seed")
    end
end

tests[#tests + 1] = function()
    local route = TacticsProcgen.archiveRoute()
    local variants = TacticsProcgen.archiveRouteVariants()
    local ids = {}
    local templates = {}
    local nodeKinds = {}
    expect(route.id == "buried_archive_vertical_slice" and route.zone == "buried_archive", "archive route should define Buried Archive route metadata")
    expect(#variants >= 5 and #variants <= 7 and route.boardCount == #variants, "archive route should expose 5-7 board variants")
    for index, variant in ipairs(variants) do
        ids[variant.id] = true
        templates[variant.template] = true
        nodeKinds[variant.nodeKind] = true
        expect(route.variantOrder[index] == variant.id and variant.zone == "buried_archive", "archive route should keep ordered archive variants")
        expect(RunCatalog.boardTemplate(variant.template), "archive route variant should use known template: " .. variant.id)
        expect(variant.reward and variant.complication and variant.preview, "archive route variant should expose reward complication preview: " .. variant.id)
        local seed = 3000 + index
        local spec = TacticsProcgen.generateArchiveRouteBoard(variant.id, seed)
        local state = TacticsProcgen.archiveRouteState(variant.id, seed)
        expect(spec.zone == "buried_archive" and spec.archiveRoute.variantId == variant.id, "archive route board should bind variant metadata: " .. variant.id)
        expect(spec.generator.variantId == variant.id and spec.generator.template == variant.template and spec.generator.routeId == route.id, "archive route board should bind generator metadata: " .. variant.id)
        expect(spec.validation.valid and TacticsProcgen.validateGrammarBoard(spec).valid, "archive route board should validate grammar: " .. variant.id)
        expect(TacticsProcgen.auditReinforcementRules(spec).ok, "archive route board should pass reinforcement audit: " .. variant.id)
        expect(TacticsProcgen.difficultyBudget(spec).accepted and spec.budget.accepted, "archive route board should pass difficulty budget: " .. variant.id)
        expect(state:tileAt(spec.objectives[1].x, spec.objectives[1].y).objective.id == spec.objectives[1].id, "archive route state should instantiate objective tile: " .. variant.id)
        expect(Serialize.encode(spec) == Serialize.encode(TacticsProcgen.generateArchiveRouteBoard(variant.id, seed)), "archive route board should be deterministic: " .. variant.id)
    end
    for _, id in ipairs(route.variantOrder) do
        expect(ids[id], "archive route order should reference existing variant " .. id)
    end
    expect(templates.kill_light and templates.protect_heavy and templates.extraction and templates.repair and templates.stealth and templates.holdout, "archive route should cover six tactical templates")
    expect(nodeKinds.combat and nodeKinds.repair and nodeKinds.elite and nodeKinds.high_reward_extraction and nodeKinds.cursed_shortcut, "archive route should cover route node pressure")
end

tests[#tests + 1] = function()
    local spec = TacticsProcgen.generateDirectedZoneBoard("buried_archive", 2606, { includeElite = true })
    local accepted = TacticsProcgen.difficultyBudget(spec)
    expect(accepted.accepted and accepted.total <= accepted.max, "difficulty budget should accept readable generated board")
    local overloaded = TacticsProcgen.difficultyBudget(spec, { max = 1 })
    expect(not overloaded.accepted and contains(overloaded.rejectReasons, "budget_exceeded"), "difficulty budget should reject over-budget boards")
    spec.encounterDirector.intentDensity.threatenedTiles = spec.encounterDirector.intentDensity.cap + 1
    local unreadable = TacticsProcgen.difficultyBudget(spec)
    expect(not unreadable.accepted and contains(unreadable.rejectReasons, "intent_density_exceeded"), "difficulty budget should reject unreadable intent density")
    spec.encounterDirector.intentDensity.threatenedTiles = 1
    spec.encounterDirector.spawnBlockRules = {}
    local unblocked = TacticsProcgen.difficultyBudget(spec)
    expect(not unblocked.accepted and contains(unblocked.rejectReasons, "spawn_block_rule_missing"), "difficulty budget should reject missing spawn block rules")
end

tests[#tests + 1] = function()
    local state = TacticsState.new({
        board = {
            width = 4,
            height = 3,
            tiles = {
                ["1:2"] = { height = 2 },
                ["2:2"] = { height = 1, losBlocker = true },
                ["3:2"] = { height = 2, losBlocker = true },
                ["4:2"] = { coverEdges = { west = "half" } },
            },
        },
    })
    local lowBlocker = TacticsLoS.line(state, 1, 2, 4, 2)
    expect(not lowBlocker.visible and lowBlocker.blockedBy.x == 3, "LoS should use height-aware blockers")
    state.board.tiles["3:2"].losBlocker = false
    local open = TacticsLoS.rotationInvariant(state, 1, 2, 4, 2)
    for _, result in ipairs(open.rotations) do
        expect(result.visible == open.base.visible and result.heightDelta == open.base.heightDelta, "LoS should be rotation independent")
    end
    local profile = TacticsLoS.attackProfile(state, 1, 2, 4, 2)
    expect(profile.cover == "half" and profile.coverIgnoredByHeight, "LoS attack profile should include cover edge and height")
end

tests[#tests + 1] = function()
    for _, id in ipairs({ "none", "half", "full", "hard", "destructible", "mobile" }) do
        expect(TacticsCover.class(id), "missing cover class " .. id)
    end
    local state = TacticsState.new({
        board = {
            width = 3,
            height = 1,
            tiles = {
                ["1:1"] = { blockerKind = "hard" },
                ["2:1"] = { blocker = true, losBlocker = true, destructibleHp = 3 },
                ["3:1"] = { blockerKind = "mobile" },
            },
        },
    })
    expect(state:blockerAt(1, 1).kind == "hard" and state:blockerAt(1, 1).los, "hard blocker should block LoS")
    expect(state:blockerAt(2, 1).destructible and state:blockerAt(2, 1).hp == 3, "destructible cover should expose HP")
    expect(state:blockerAt(3, 1).mobile and not state:blockerAt(3, 1).los, "mobile cover should block movement without blocking LoS")
end

tests[#tests + 1] = function()
    local state = TacticsState.new({
        board = {
            width = 3,
            height = 3,
            tiles = {
                ["2:2"] = { coverEdges = { west = "half" } },
            },
        },
        units = {
            { id = "target", side = "enemy", x = 2, y = 2, hp = 4 },
        },
    })
    local preview = TacticsCover.flankPreview(state, {
        { x = 1, y = 2 },
        { x = 3, y = 2 },
    }, "target")
    expect(not preview[1].flanked and preview[1].cover == "half", "flank preview should show protected candidate tile")
    expect(preview[2].flanked and preview[2].invalidated[1] == "west:half", "flank preview should show flanking candidate tile")
end

tests[#tests + 1] = function()
    local state = TacticsState.new({
        defaultAp = 9,
        board = { width = 1, height = 1 },
        units = { { id = "unit", side = "player", x = 1, y = 1 } },
    })
    local total = 0
    for _, action in ipairs({ "move", "dash", "attack", "interact", "brace", "overwatch", "reload", "cooldown", "class_special" }) do
        local cost = TacticsAP.cost(action)
        expect(cost and cost > 0, "missing AP cost for " .. action)
        total = total + cost
    end
    expect(TacticsAP.spend(state, "unit", TacticsAP.cost("brace")) == 8, "AP module should spend action costs")
    expect(total == 9, "default AP cost table should cover nine one-AP actions")
end

tests[#tests + 1] = function()
    local state = TacticsState.new({
        board = {
            width = 4,
            height = 2,
            tiles = {
                ["2:1"] = { blocker = true, losBlocker = true, destructibleHp = 2, coverEdges = { west = "half" } },
                ["3:1"] = { hazard = { kind = "burn", active = true, damage = 1 } },
            },
        },
        units = {
            { id = "warden", side = "player", x = 1, y = 1, hp = 4 },
            { id = "enemy", side = "enemy", x = 2, y = 2, hp = 4 },
        },
        objectives = {
            { id = "machine", x = 3, y = 2, integrity = 3, evacuateAt = { x = 4, y = 2 } },
        },
    })
    local shove = TacticsResolution.actionPreview(state, TacticsState.commands.shove("warden", "enemy", "east", 1, 1))
    expect(shove.pushedPath[1].x == 3 and shove.objectiveDamage[1].id == "machine", "action preview should show push path and objective damage")
    local blocked = TacticsResolution.actionPreview(state, TacticsState.commands.shove("warden", "warden", "east", 1, 1))
    expect(blocked.collision and blocked.collision.reason == "blocked_tile", "action preview should show collision")
    local breakCover = TacticsResolution.actionPreview(state, TacticsState.commands.damageTile("warden", 2, 1, 2, 1))
    expect(breakCover.coverBreak[1].breaks, "action preview should show cover break")
    local hazard = TacticsResolution.actionPreview(state, TacticsState.commands.move("warden", "east"))
    expect(hazard.affectedTiles[1].x == 2, "action preview should show affected movement tile")
    local converted = TacticsResolution.actionPreview(state, TacticsState.commands.convertTile("warden", 3, 1, "burn", 1))
    expect(converted.hazardChain[1].conversion == "burn", "action preview should show hazard chain")
end

tests[#tests + 1] = function()
    local state = TacticsState.new({
        defaultAp = 2,
        board = { width = 3, height = 1 },
        units = {
            { id = "hero", side = "player", x = 1, y = 1, hp = 5 },
            { id = "enemy", side = "enemy", x = 3, y = 1, hp = 4, ap = 0 },
        },
    })
    local enemies = TacticsIntent.activateEnemies(state)
    expect(enemies[1].id == "enemy" and enemies[1].ap == 2, "enemy activation should refresh enemy AP")
    TacticsIntent.select(state, "enemy", {
        { mode = "exact", category = "attack", targetTiles = { { x = 1, y = 1 } }, damage = 2 },
    })
    expect(TacticsIntent.preview(state, "enemy").damage == 2, "enemy intent selection should expose preview")
    local resolved = TacticsIntent.resolve(state, "enemy")
    expect(resolved.units[1] == "hero" and state:unit("hero").hp == 3, "enemy intent resolution should damage target")
    TacticsIntent.declareNextTurn(state, "enemy", { mode = "category", category = "move", effect = "reposition" })
    expect(TacticsIntent.preview(state, "enemy").categoryOnly, "enemy next turn declaration should expose next preview")
end

tests[#tests + 1] = function()
    local state = TacticsState.new({
        defaultAp = 2,
        board = { width = 3, height = 1 },
        units = { { id = "unit", side = "player", x = 1, y = 1, hp = 4 } },
    })
    local recording = TacticsReplay.record(state)
    TacticsReplay.apply(recording, TacticsState.commands.move("unit", "east"))
    TacticsReplay.apply(recording, TacticsState.commands.move("unit", "east"))
    expect(recording.debugOnly == true and TacticsReplay.debugOnly == true, "tactical rewind should be marked debug-only")
    expect(TacticsReplay.rewind(recording, 0):unit("unit").x == 1, "rewind should restore initial board")
    expect(TacticsReplay.rewind(recording, 1):unit("unit").x == 2, "rewind should restore intermediate board")
    expect(TacticsReplay.rewind(recording, 2):unit("unit").x == 3, "rewind should restore final board")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(30)
    expect(sim:startCombat("entry", "legacy_quarantine"), "legacy combat should still start")
    expect(sim.combat.combatSystem == "legacy_rank_combat" and sim.combat.quarantined == true, "legacy rank combat should be quarantined")
    expect(sim.combat.replacement == "tactical_board", "legacy rank combat should point at tactical replacement")
    local quarantine = sim:legacyRankCombatQuarantine()
    expect(quarantine.system == "legacy_rank_combat" and quarantine.quarantined == true, "legacy rank quarantine metadata should be inspectable")
end

tests[#tests + 1] = function()
    local state = TacticsState.new({
        defaultAp = 3,
        board = { width = 5, height = 3 },
        units = {
            { id = "warden", side = "player", x = 5, y = 2 },
            { id = "arcanist", side = "player", x = 1, y = 2 },
        },
        objectives = {
            {
                id = "route_machine",
                kind = "protect_route_machinery",
                x = 3,
                y = 2,
                integrity = 3,
                evacuateAt = { x = 5, y = 2 },
                evacuationsRequired = 1,
            },
        },
    })
    expect(state:objectiveStatus("route_machine") == "active", "route machinery objective should start active")
    state:apply(TacticsState.commands.damageObjective("arcanist", "route_machine", 1, 0))
    expect(state:objective("route_machine").integrity == 2 and state:objectiveStatus("route_machine") == "active", "protected machinery should survive partial damage")
    state:apply(TacticsState.commands.evacuate("warden", "route_machine", 1))
    expect(state:objectiveStatus("route_machine") == "complete" and state:unit("warden").evacuated, "objective should complete after machinery survives and one unit evacuates")
    expect(#state:unitsForSide("player") == 1 and not state:unitAt(5, 2), "evacuated unit should leave active board state")
    local loaded = TacticsState.fromSnapshot(state:snapshot())
    expect(Serialize.encode(loaded:snapshot()) == Serialize.encode(state:snapshot()), "objective state should snapshot deterministically")
    local failed = TacticsState.new({
        board = { width = 3, height = 3 },
        units = {
            { id = "thief", side = "player", x = 1, y = 1 },
        },
        objectives = {
            { id = "pump", x = 2, y = 2, integrity = 1, evacuateAt = { x = 3, y = 3 } },
        },
    })
    failed:apply(TacticsState.commands.damageObjective("thief", "pump", 1, 0))
    expect(failed:objectiveStatus("pump") == "failed", "objective should fail when route machinery integrity reaches zero")
end

tests[#tests + 1] = function()
    local state = TacticsState.new({
        defaultAp = 8,
        board = {
            width = 4,
            height = 3,
            tiles = {
                ["4:3"] = { blocker = true },
            },
        },
        units = {
            { id = "chirurgeon", side = "player", x = 1, y = 1 },
        },
        objectives = {
            { id = "machine", x = 2, y = 2, integrity = 2, maxIntegrity = 4, allowPartial = true, evacuateAt = { x = 4, y = 2 } },
            { id = "ledger", x = 1, y = 2, integrity = 1, maxIntegrity = 1, evacuateAt = { x = 4, y = 2 } },
            { id = "seal", x = 1, y = 3, integrity = 1, maxIntegrity = 1, evacuateAt = { x = 4, y = 2 } },
        },
    })
    state:apply(TacticsState.commands.damageObjective("chirurgeon", "machine", 1, 0))
    expect(state:objective("machine").integrity == 1, "objective damage should lower integrity")
    state:apply(TacticsState.commands.repairObjective("chirurgeon", "machine", 2, 0))
    expect(state:objective("machine").integrity == 3, "objective repair should restore integrity up to max")
    state:apply(TacticsState.commands.relocateObjective("chirurgeon", "machine", 3, 2, 0))
    expect(state:objective("machine").x == 3 and state:objective("machine").relocated, "objective relocation should move objective")
    local result = state:objectiveResult("machine")
    expect(result.partialSuccess and result.integrityRatio == 0.75 and result.relocated, "objective result should report partial success and relocation")
    local ok, err = pcall(function()
        state:apply(TacticsState.commands.relocateObjective("chirurgeon", "machine", 4, 3, 0))
    end)
    expect(not ok and err:find("objective relocation blocked", 1, true), "objective relocation should reject blocked tiles")
    state:apply(TacticsState.commands.extractObjective("chirurgeon", "ledger", 0))
    expect(state:objectiveStatus("ledger") == "complete" and state:objectiveResult("ledger").extracted, "objective extraction should complete objective")
    state:apply(TacticsState.commands.sacrificeObjective("chirurgeon", "seal", "route_trade", 0))
    local sacrificed = state:objectiveResult("seal")
    expect(sacrificed.status == "failed" and sacrificed.sacrificed and sacrificed.failureCarryover.reason == "route_trade", "objective sacrifice should record failure carryover")
    local failed = TacticsState.new({
        board = { width = 2, height = 2 },
        units = { { id = "warden", x = 1, y = 1 } },
        objectives = { { id = "pump", x = 1, y = 2, integrity = 1, evacuateAt = { x = 2, y = 2 } } },
    })
    failed:apply(TacticsState.commands.damageObjective("warden", "pump", 1, 0))
    expect(failed:objectiveResult("pump").failureCarryover.reason == "integrity_zero", "objective integrity failure should carry over reason")
end

tests[#tests + 1] = function()
    local state = TacticsState.new({ board = { width = 2, height = 2 } })
    state:apply(TacticsState.commands.reward({ kind = "tool_unlock", id = "lamp_cone", option = "Lamplighter cone" }))
    state:apply(TacticsState.commands.reward({ kind = "class_option", id = "warden_claim_anchor", option = "Warden claim anchor", source = "protect_objective_integrity" }))
    state:apply(TacticsState.commands.reward({ kind = "route_option", id = "repair_route", source = "route_machine" }))
    expect(state.unlocks.tool_unlock.lamp_cone.option == "Lamplighter cone", "tactical rewards should unlock tool options")
    expect(state.unlocks.class_option.warden_claim_anchor.source == "protect_objective_integrity", "tactical rewards should unlock class loadout options")
    expect(state.unlocks.route_option.repair_route.source == "route_machine", "tactical rewards should unlock route options")
    local ok, err = pcall(function()
        state:apply(TacticsState.commands.reward({ kind = "stat_bonus", id = "plus_damage", stat = "damage" }))
    end)
    expect(not ok and err:find("unsupported tactical reward", 1, true), "tactical rewards should reject raw stat dominance")
    local classOk, classErr = pcall(function()
        state:apply(TacticsState.commands.reward({ kind = "class_option", id = "plus_damage", statBonus = "damage" }))
    end)
    expect(not classOk and classErr:find("raw stat rewards", 1, true), "class loadout rewards should reject raw stat payloads")
    local loaded = TacticsState.fromSnapshot(state:snapshot())
    expect(Serialize.encode(loaded:snapshot()) == Serialize.encode(state:snapshot()), "tactical reward unlocks should snapshot deterministically")
end

tests[#tests + 1] = function()
    local state = TacticsState.new({
        defaultAp = 2,
        board = {
            width = 4,
            height = 3,
            tiles = {
                ["1:2"] = { coverEdges = { west = "half" } },
                ["2:1"] = { coverEdges = { north = "half" } },
                ["2:2"] = { hazard = { kind = "brine", damage = 1, carryDamage = 2 } },
                ["3:2"] = { blocker = true },
            },
        },
        units = {
            { id = "thief", side = "player", x = 1, y = 2, carryingObjective = "route_machine" },
            { id = "custodian", side = "enemy", x = 1, y = 3 },
        },
    })
    local preview = state:movementPreview("thief")
    local function reachableAt(x, y)
        for _, tile in ipairs(preview.reachable) do
            if tile.x == x and tile.y == y then
                return tile
            end
        end
        return nil
    end
    local function collisionAt(x, y, result)
        for _, collision in ipairs(preview.collisions) do
            if collision.x == x and collision.y == y and collision.result == result then
                return collision
            end
        end
        return nil
    end
    local brine = reachableAt(2, 2)
    expect(brine and brine.apCost == 1 and brine.hazardCost == 1, "movement preview should include AP and hazard cost")
    expect(brine.objectiveCarryEffect and brine.objectiveCarryEffect.integrityDelta == -2, "movement preview should include objective carry impact")
    expect(contains(brine.coverLost, "west:half"), "movement preview should include cover lost")
    local cover = reachableAt(2, 1)
    expect(cover and cover.apCost == 2 and contains(cover.coverGained, "north:half"), "movement preview should include reachable cover gained")
    expect(collisionAt(3, 2, "blocked_tile"), "movement preview should report blocker collision")
    expect(collisionAt(1, 3, "occupied"), "movement preview should report occupied collision")
end

tests[#tests + 1] = function()
    local state = TacticsState.new({
        defaultAp = 6,
        board = {
            width = 6,
            height = 3,
            tiles = {
                ["3:1"] = { hazard = { kind = "brine", carryDamage = 1, dragDamage = 2 } },
            },
        },
        units = {
            { id = "warden", side = "player", x = 1, y = 1 },
            { id = "thief", side = "player", x = 4, y = 2 },
        },
        cargo = {
            { id = "civilian", kind = "civilian", x = 2, y = 1, integrity = 2 },
            { id = "body", kind = "body", x = 2, y = 2 },
            { id = "core", kind = "machinery_core", x = 5, y = 2, integrity = 4 },
            { id = "crate", kind = "loot_crate", x = 5, y = 3 },
            { id = "wounded", kind = "wounded_hero", x = 6, y = 2, integrity = 3 },
        },
    })
    state:apply(TacticsState.commands.carryCargo("warden", "civilian"))
    expect(state:unit("warden").carryingCargo == "civilian" and state:cargoItem("civilian").carriedBy == "warden", "carry should attach civilian cargo")
    local preview = state:movementPreview("warden")
    local hazard
    for _, tile in ipairs(preview.reachable) do
        if tile.x == 3 and tile.y == 1 then
            hazard = tile
        end
    end
    expect(hazard and hazard.objectiveCarryEffect and hazard.objectiveCarryEffect.cargo == "civilian" and hazard.objectiveCarryEffect.integrityDelta == -1, "movement preview should show cargo carry damage")
    state:apply(TacticsState.commands.dash("warden", "east", 2))
    expect(state:cargoItem("civilian").x == 3 and state:cargoItem("civilian").integrity == 1, "carried cargo should follow unit and take carry hazard damage")
    state:apply(TacticsState.commands.dropCargo("warden", "south"))
    expect(not state:unit("warden").carryingCargo and state:cargoItem("civilian").x == 3 and state:cargoItem("civilian").y == 2, "drop should detach carried cargo")
    state:apply(TacticsState.commands.dragCargo("thief", "core", "west"))
    expect(state:cargoItem("core").x == 4 and state:cargoItem("core").integrity == 4, "drag should move machinery cores")
    state:apply(TacticsState.commands.move("thief", "east"))
    state:apply(TacticsState.commands.dragCargo("thief", "wounded", "west"))
    expect(state:cargoItem("wounded").x == 5 and state:cargoItem("wounded").integrity == 3, "drag should move wounded heroes")
    expect(state:cargoItem("body").kind == "body" and state:cargoItem("crate").kind == "loot_crate", "cargo schema should include bodies and loot crates")
    local loaded = TacticsState.fromSnapshot(state:snapshot())
    expect(Serialize.encode(loaded:snapshot()) == Serialize.encode(state:snapshot()), "cargo state should snapshot deterministically")
end

tests[#tests + 1] = function()
    local function interact(kind, tile)
        local state = TacticsState.new({
            board = {
                width = 2,
                height = 2,
                tiles = {
                    ["1:1"] = tile or { kind = kind, interact = { kind = kind } },
                    ["2:2"] = { revealed = false },
                },
            },
            units = {
                { id = "warden", side = "player", x = 1, y = 1, ap = 9 },
            },
        })
        state:apply(TacticsState.commands.interactTile("warden", 1, 1, 0))
        return state, state:tileAt(1, 1)
    end
    local _, valve = interact("valve")
    expect(valve.state == "open" and valve.hazard.kind == "flood" and valve.hazard.active == true, "valve interaction should toggle flood hazard")
    local _, door = interact("door", { kind = "door", interact = { kind = "door" }, blocker = true, losBlocker = true })
    expect(door.state == "open" and not door.blocker and not door.losBlocker, "door interaction should open blockers")
    local _, seal = interact("seal")
    expect(seal.state == "sealed" and seal.blocker and seal.losBlocker, "seal interaction should close movement and LoS")
    local _, shelf = interact("shelf")
    expect(shelf.state == "braced" and shelf.coverEdges.north == "full" and shelf.losBlocker, "shelf interaction should create cover")
    local _, furnace = interact("furnace")
    expect(furnace.state == "lit" and furnace.hazard.kind == "heat" and furnace.hazard.active, "furnace interaction should toggle heat")
    local _, bridge = interact("bridge", { kind = "bridge", interact = { kind = "bridge" }, blocker = true, losBlocker = true })
    expect(bridge.state == "lowered" and not bridge.blocker and contains(bridge.tags, "bridge_lowered"), "bridge interaction should lower route")
    local terminalState = interact("terminal")
    expect(terminalState:tileAt(2, 2).revealed == true, "terminal interaction should reveal hidden board tiles")
    local bellState, bell = interact("bell", { kind = "bell", interact = { kind = "bell", exposure = 2 } })
    expect(bell.state == "rung" and bellState.exposure == 2, "bell interaction should raise exposure")
    local extraction = TacticsState.new({
        board = { width = 1, height = 1, tiles = { ["1:1"] = { kind = "extraction", interact = { kind = "extraction" } } } },
        units = { { id = "thief", side = "player", x = 1, y = 1, ap = 2 } },
        cargo = { { id = "crate", kind = "loot_crate", x = 1, y = 1, carriedBy = "thief" } },
    })
    extraction:apply(TacticsState.commands.interactTile("thief", 1, 1, 0))
    expect(extraction:cargoItem("crate").extracted and not extraction:unit("thief").carryingCargo, "extraction interaction should extract carried cargo")
    extraction:apply(TacticsState.commands.interactTile("thief", 1, 1, 0))
    expect(extraction:unit("thief").evacuated, "extraction interaction should evacuate unit with no cargo")
end

tests[#tests + 1] = function()
    local state = TacticsState.new({
        defaultAp = 20,
        board = { width = 10, height = 1 },
        units = {
            { id = "arcanist", side = "player", x = 1, y = 1 },
        },
    })
    local conversions = {
        "flood",
        "drain",
        "burn",
        "ash_choke",
        "glassify",
        "collapse",
        "raise_cover",
        "lower_cover",
        "seal_tile",
        "open_tile",
    }
    for index, conversion in ipairs(conversions) do
        state:apply(TacticsState.commands.convertTile("arcanist", index, 1, conversion, 0))
    end
    expect(state:tileAt(1, 1).state == "flooded" and state:tileAt(1, 1).hazard.active, "flood conversion should activate flood hazard")
    expect(state:tileAt(2, 1).state == "drained" and not state:tileAt(2, 1).hazard.active, "drain conversion should deactivate flood hazard")
    expect(state:tileAt(3, 1).state == "burning" and state:tileAt(3, 1).hazard.kind == "burn", "burn conversion should activate burn hazard")
    expect(state:tileAt(4, 1).state == "ash_choke" and state:tileAt(4, 1).losBlocker, "ash choke conversion should block LoS")
    expect(state:tileAt(5, 1).state == "glassified" and state:tileAt(5, 1).material == "glass", "glassify conversion should change material")
    expect(state:tileAt(6, 1).state == "collapsed" and state:tileAt(6, 1).blocker and state:tileAt(6, 1).height == 1, "collapse conversion should block and raise height")
    expect(state:tileAt(7, 1).state == "cover_raised" and state:tileAt(7, 1).coverEdges.north == "half", "raise cover conversion should add cover")
    expect(state:tileAt(8, 1).state == "cover_lowered" and state:tileAt(8, 1).coverEdges.north == "none", "lower cover conversion should clear cover")
    expect(state:tileAt(9, 1).state == "sealed" and state:tileAt(9, 1).blocker and state:tileAt(9, 1).losBlocker, "seal tile conversion should close movement and LoS")
    expect(state:tileAt(10, 1).state == "open" and not state:tileAt(10, 1).blocker and not state:tileAt(10, 1).losBlocker, "open tile conversion should clear blockers")
end

tests[#tests + 1] = function()
    local state = TacticsState.new({
        defaultAp = 12,
        board = {
            width = 4,
            height = 2,
            tiles = {
                ["4:1"] = { blocker = true },
            },
        },
        units = {
            { id = "warden", side = "player", x = 1, y = 1, hp = 8 },
            { id = "target", side = "enemy", x = 2, y = 1, hp = 10 },
            { id = "braced", side = "enemy", x = 3, y = 1, hp = 5, statuses = { braced = { amount = 1 } } },
        },
    })
    state:apply(TacticsState.commands.status("warden", "target", "marked", 2, 1, 0))
    state:apply(TacticsState.commands.status("warden", "target", "exposed", 2, 1, 0))
    state:apply(TacticsState.commands.attack("warden", "target", 1, 0))
    expect(state:unit("target").hp == 7, "marked and exposed should add deterministic incoming damage")
    state:apply(TacticsState.commands.status("warden", "warden", "pinned", 1, nil, 0))
    local ok, err = pcall(function()
        state:apply(TacticsState.commands.move("warden", "south"))
    end)
    expect(not ok and err:find("unit movement blocked", 1, true), "pinned should block voluntary movement")
    state:removeStatus("warden", "pinned")
    state:apply(TacticsState.commands.status("warden", "warden", "blinded", 1, nil, 0))
    ok, err = pcall(function()
        state:apply(TacticsState.commands.threatZone("warden", "line", "east", 2, nil, 1, 1))
    end)
    expect(not ok and err:find("unit is blinded", 1, true), "blinded should block threat-zone creation")
    state:apply(TacticsState.commands.status("warden", "target", "burning", 1, 1, 0))
    state:apply(TacticsState.commands.status("warden", "target", "flooded", 1, 1, 0))
    state:apply(TacticsState.commands.status("warden", "target", "corroded", 1, 1, 0))
    state:apply(TacticsState.commands.tickStatuses("target"))
    expect(state:unit("target").hp == 4 and not state:hasStatus("target", "burning"), "damage statuses should tick and expire deterministically")
    state:apply(TacticsState.commands.shove("warden", "braced", "east", 1, 2, 0))
    expect(state:unit("braced").hp == 4, "braced should reduce collision damage")
    state:apply(TacticsState.commands.status("warden", "warden", "bound", 1, nil, 0))
    state:apply(TacticsState.commands.status("warden", "target", "filed", 1, nil, 0))
    state:apply(TacticsState.commands.status("warden", "target", "redacted", 1, nil, 0))
    state:apply(TacticsState.commands.status("warden", "target", "sealed", 1, nil, 0))
    expect(state:hasStatus("warden", "bound") and state:hasStatus("target", "filed") and state:hasStatus("target", "redacted") and state:hasStatus("target", "sealed"), "all tactical status kinds should be accepted")
end

tests[#tests + 1] = function()
    expect(I18n.t("New Game") == "New Game", "i18n should load English strings")
    expect(I18n.t("missing {value}", { value = "fallback" }) == "missing fallback", "i18n should interpolate fallback strings")
    local source = readFile("src/app/render.lua")
    expect(source, "render source should be readable for i18n coverage")
    for key in source:gmatch('i18n%.t%(%s*"([^"]+)"%s*%)') do
        expect(I18n.has(key), "missing render i18n key " .. key)
    end
    for _, control in ipairs(Settings.controls()) do
        expect(I18n.has(control.label), "missing settings i18n key " .. control.label)
    end
end

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
    local ambientSource = fakeSource()
    local bank = {
        __music = {
            manifest = {
                fadeSeconds = 2,
                contexts = { estate = "estate", combat = "combat_normal" },
                ambient = { combat = { track = "expedition_tense", volume = 0.25 } },
            },
            tracks = {
                estate = { key = "estate", source = estateSource, loop = true },
                combat_normal = { key = "combat_normal", source = combatSource, loop = true },
            },
            ambientTracks = {
                expedition_tense = { key = "expedition_tense", source = ambientSource, loop = true },
            },
            fadeSeconds = 2,
            ambientFadeSeconds = 2,
            fade = 0,
            ambientFade = 0,
        },
    }
    Audio.applySettings(bank, { masterVolume = 0.5, musicVolume = 0.8, ambientVolume = 0.6, sfxVolume = 1 })
    expect(Audio.setMusicContext(bank, "estate", 0) == "estate", "music should resolve estate context")
    expect(estateSource.plays == 1 and estateSource.looping == true, "music should start first context")
    expect(math.abs(estateSource.volume - 0.4) < 0.001, "music should apply master/music volume")
    Audio.setMusicContext(bank, "combat", 2)
    expect(ambientSource.plays == 1 and math.abs(ambientSource.volume - 0.075) < 0.001, "ambient layer should start at context mix volume")
    Audio.updateMusic(bank, 1)
    expect(math.abs(estateSource.volume - 0.2) < 0.001, "music should fade current track down")
    expect(math.abs(combatSource.volume - 0.2) < 0.001, "music should fade next track up")
    Audio.updateMusic(bank, 1)
    expect(estateSource.stops == 1 and math.abs(combatSource.volume - 0.4) < 0.001, "music should finish crossfade")
    expect(math.abs(ambientSource.volume - 0.075) < 0.001, "ambient layer should stay below music volume")
    expect(Audio.duckForEvent(bank, { crit = true }), "critical events should trigger music ducking")
    expect(math.abs(combatSource.volume - 0.22) < 0.001 and math.abs(ambientSource.volume - 0.04125) < 0.001, "ducking should lower music and ambient layers")
    Audio.updateMusic(bank, 0.45)
    expect(math.abs(combatSource.volume - 0.4) < 0.001 and math.abs(ambientSource.volume - 0.075) < 0.001, "ducking should release after its timer")
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
    expect(#(cleanse:layout().megastructure.platforms or {}) >= #(cleanse:layout().rooms or {}), "generated archive should add megastructure platforms around rooms")
    expect(#(cleanse:layout().megastructure.bridges or {}) > #(cleanse:layout().corridors or {}), "generated archive should add side spans beyond graph corridors")
    expect(Defs.tile(cleanse:getTile(4, 4, 0).id).walkable == true, "megastructure platform should create explorable space outside rectangular rooms")
    expect(#(cleanse:layout().megastructure.hidden or {}) >= 1, "generated archive should add rotation-hidden megastructure rewards")
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
    local tacticalMap = Input.tacticalGamepadMap()
    expect(tacticalMap.select.button == "a" and tacticalMap.select.key == "return", "tactical gamepad map should expose select")
    expect(tacticalMap.back.button == "b" and tacticalMap.inspect.button == "x" and tacticalMap.focus.button == "y", "tactical gamepad map should expose back inspect focus")
    expect(tacticalMap.rotateLeft.button == "leftshoulder" and tacticalMap.rotateRight.button == "rightshoulder", "tactical gamepad map should expose rotation shoulders")
    expect(tacticalMap.cursor.axes[1] == "leftx" and tacticalMap.cursor.digital[1] == "dpup", "tactical gamepad map should expose analog and digital cursor")
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
    expect(Render.markUiFeedback(app, "success") and app.uiPulse.kind == "success" and app.uiPulse.duration == 0.32, "ui feedback should promote pulse to success state")
    app.uiPulse = nil
    expect(Render.markUiFeedback(app, "error") and app.uiPulse.kind == "error", "ui feedback should target hotbox for error state")
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
    local sim = Simulation.new(310)
    local hero = sim:heroAtRank(1)
    expect(not hero.filed, "hero starts unfiled")
    local gx, gy, gz = sim.player.x + 1, sim.player.y, sim.player.z or 0
    sim.world:setTile(gx, gy, gz, { id = "record_door", data = 0 })
    local beforeHeirloom = sim.expedition.loot:count("heirloom")
    runQueued(sim, Simulation.commands.curioChoice(gx, gy, gz, "record_door", "pay_name", 1))
    expect(hero.filed == true, "pay_name should file the hero")
    expect(sim.expedition.loot:count("heirloom") == beforeHeirloom + 1, "name gate should grant heirloom")
    expect(sim.world:getTile(gx, gy, gz).id ~= "record_door", "name gate tile should clear")
    expect(sim.expedition.curiosUsed[tostring(gz) .. ":" .. tostring(gx) .. ":" .. tostring(gy)], "name gate should be marked used")
    local loaded = Simulation.fromSnapshot(sim:snapshot())
    expect(loaded:heroAtRank(1).filed == true, "filed should survive snapshot")
end

tests[#tests + 1] = function()
    local sim = Simulation.newEstate(311)
    local campaign = sim:ensureCampaignState()
    expect(not sim:isPartyFiled(), "fresh campaign should be unfiled")
    expect(contains(sim:eligibleMissionKeys(), "archive_misfiled_dead"), "filedSeal mission should be eligible while unfiled")
    campaign.flags.greedyExtracts = sim:filedThreshold()
    sim:evaluateFiledState()
    expect(sim:isPartyFiled(), "threshold of greedy extracts should file the party")
    expect(campaign.flags.partyFiled == true, "evaluateFiledState should persist flag")
    expect(not contains(sim:eligibleMissionKeys(), "archive_misfiled_dead"), "filedSeal mission should drop from board once filed")
    campaign.flags.repairMissions = campaign.flags.greedyExtracts
    sim:evaluateFiledState()
    expect(not sim:isPartyFiled(), "repair work should unfile the party")
    expect(contains(sim:eligibleMissionKeys(), "archive_misfiled_dead"), "filedSeal mission should return once unfiled")
end

tests[#tests + 1] = function()
    local sim = Simulation.newEstate(312)
    local campaign = sim:ensureCampaignState()
    expect(not contains(sim:eligibleMissionKeys(), "archive_audit_review"), "audit review should be hidden until route walked")
    campaign.locationProgress = campaign.locationProgress or {}
    campaign.locationProgress.buried_archive = 1
    expect(contains(sim:eligibleMissionKeys(), "archive_audit_review"), "audit review should appear after one Archive mission")
    sim:applyTownEvent("audit_review_notice")
    expect(contains(sim.estate.missionBoard, "archive_audit_review"), "audit review notice should place mission on board")
    sim:startExpedition("archive_audit_review")
    expect(sim.expedition and sim.expedition.noise == 4, "audit review should start with elevated noise")
end

tests[#tests + 1] = function()
    local sim = Simulation.newEstate(313)
    local campaign = sim:ensureCampaignState()
    campaign.flags.enclaveCompactSigned = true
    sim:adjustFaction("enclave_meter", 5)
    expect(sim:shouldSourCompact(), "high enclave meter with signed compact should mark for souring")
    sim:sourCompact()
    expect(campaign.flags.enclaveCompactSoured == true, "souring should flip the compact")
    expect(campaign.flags.enclaveCompactSigned == false, "signed flag should clear when soured")
    expect(campaign.flags.souredFixture == "fixture_surveyor", "souring should name the Surveyor")
    expect(campaign.factions.enclave_meter.value <= -2, "souring should drop the enclave meter")
    expect(sim:silenceFixture("fixture_vault_keeper") == false, "silencing the wrong fixture should fail")
    campaign.dread = 5
    expect(sim:silenceFixture("fixture_surveyor"), "silencing the soured fixture should succeed")
    expect(campaign.flags.enclaveCompactSoured == false, "silenced fixture should clear soured flag")
    expect(campaign.flags.enclaveCompactSigned == true, "silenced fixture should restore compact")
    expect(campaign.flags.souredFixture == nil, "silenced fixture should clear name")
    expect(campaign.dread == 2, "silencing should drop dread by 3")
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
    expect(text:match("^THOTH_LUA_SAVE 4"), "save writer should use v4 header")
    local loaded = assert(Save.fromText(text))
    expect(sameSnapshot(sim, loaded), "save round trip should preserve snapshot")
    local v3Snapshot = sim:snapshot()
    v3Snapshot.version = 3
    local v3Loaded = assert(Save.fromText("THOTH_LUA_SAVE 3\n" .. Serialize.encode(v3Snapshot) .. "\n"))
    expect(v3Loaded:snapshot().version == 4 and sameSnapshot(sim, v3Loaded), "v3 save should migrate to v4")
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
    local path = "test-replay.thoth.tmp"
    os.remove(path)
    expect(Replay.write(path, decoded), "replay should write file")
    local readBack = assert(Replay.read(path))
    os.remove(path)
    expect(readBack.seed == 30 and readBack.finalTick == 4, "replay should read file")
    local viewer = ReplayViewer.fromData(decoded)
    expect(viewer.sim.tick == 4 and viewer.status:find("replay seed 30", 1, true), "replay viewer should load final sim")
    local combatFrames = {}
    for tick = 0, 4 do
        combatFrames[#combatFrames + 1] = { tick = tick, command = Simulation.commands.move("east") }
    end
    local combatReplay = assert(Replay.fromText(Replay.toText(102, combatFrames, 7)))
    local combatViewer = ReplayViewer.fromData(combatReplay)
    expect(#combatViewer.cutscenes > 0 and combatViewer.cutscenes[1].kind == "intro", "replay viewer should queue cutscene events")
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
    local tactics = TacticsState.new({
        board = {
            width = 4,
            height = 4,
            tiles = {
                ["2:2"] = { coverEdges = { north = "half" } },
            },
        },
        units = {
            { id = "arcanist", x = 1, y = 1 },
        },
    })
    local overlays = {
        los = { ["3:1"] = true },
        movement = { { x = 2, y = 1 } },
        intents = { { x = 4, y = 3 } },
    }
    local entries = Render.tacticalOverlayEntries(tactics, overlays)
    local view = {
        centerX = 400,
        centerY = 260,
        halfW = 32,
        halfH = 16,
        originX = 1,
        originY = 1,
    }
    local changedScreenPosition = false
    for _, entry in ipairs(entries) do
        view.rotation = 0
        local sx0, sy0 = Render.projectIso(view, entry.x, entry.y)
        view.rotation = 1
        local sx1, sy1 = Render.projectIso(view, entry.x, entry.y)
        if math.abs(sx0 - sx1) > 0.001 or math.abs(sy0 - sy1) > 0.001 then
            changedScreenPosition = true
        end
        for rotation = 0, 3 do
            view.rotation = rotation
            local sx, sy = Render.projectIso(view, entry.x, entry.y)
            local wx, wy = Render.screenToWorld(view, sx, sy)
            expect(wx == entry.x and wy == entry.y, "rotation should not change tactical overlay logical coordinates")
        end
    end
    expect(changedScreenPosition, "rotation should change tactical overlay screen readability")
    local audit = Render.tacticalOverlayRotationAudit(tactics, overlays, view)
    local movementPositions = {}
    expect(#audit == 4, "rotation-aware overlay audit should cover four camera snaps")
    for _, rotation in ipairs(audit) do
        expect(#rotation.entries == #entries, "rotation-aware overlay audit should preserve entry count")
        for _, entry in ipairs(rotation.entries) do
            expect(entry.logicalStable, "rotation-aware overlay audit should preserve logical tile")
            expect(entry.labelOrientation == "upright", "rotation-aware overlay audit should keep labels upright")
            expect(entry.readable and entry.icon and entry.pattern, "rotation-aware overlay audit should keep icon and pattern readable")
            expect(entry.screenX and entry.screenY and #entry.occlusionOffsets > 0, "rotation-aware overlay audit should expose screen and occlusion metadata")
            if entry.key == "movement:2:1" then
                movementPositions[#movementPositions + 1] = tostring(entry.screenX) .. ":" .. tostring(entry.screenY)
            end
        end
    end
    expect(#movementPositions == 4 and movementPositions[1] ~= movementPositions[2], "rotation-aware overlay audit should project distinct screen positions")
end

tests[#tests + 1] = function()
    local sim = Simulation.new(101)
    sim.world:setTile(1, -1, 0, { id = "archive_monolith", data = 0 })
    local app = { viewRotation = 0 }
    local hidden = Render.objectRevealState(sim, app, { x = 0, y = 0, z = 0, tile = "lost_page", hiddenBehind = true })
    expect(hidden.hidden and hidden.architectureHidden and hidden.occluder.tile == "archive_monolith", "architecture occluder should hide objects from matching view angle")
    app.viewRotation = 1
    local revealed = Render.objectRevealState(sim, app, { x = 0, y = 0, z = 0, tile = "lost_page", hiddenBehind = true })
    expect(revealed.visible, "rotating view should reveal objects no longer behind occluders")
    local puzzleHidden = Render.objectRevealState(sim, { viewRotation = 0 }, { x = 0, y = 0, z = 0, tile = "rotation_cache" })
    local puzzleShown = Render.objectRevealState(sim, { viewRotation = 1 }, { x = 0, y = 0, z = 0, tile = "rotation_cache" })
    expect(puzzleHidden.hidden and puzzleHidden.puzzleHidden and puzzleHidden.rotationPuzzle, "rotation puzzle object should hide at wrong view angle")
    expect(puzzleShown.visible and puzzleShown.rotationPuzzle, "rotation puzzle object should reveal at matching view angle")
    expect(Render.isOccluderTile(Defs.tile("archive_monolith")) and Render.tileHeight(Defs.tile("archive_monolith")) > 2, "tile metadata should expose tall occluding architecture")
    sim.world:setTile(1, -1, 0, { id = "archive_floor", data = 0 })
    sim.player.facing = "east"
    sim.world:setTile(1, 0, 0, { id = "rotation_cache", data = 0 })
    local inputApp = { viewRotation = 0, settings = Settings.defaults(), audio = {}, ui = {} }
    Input.keypressed(sim, inputApp, "space")
    expect(inputApp.status == "rotate view to reveal" and inputApp.curioModal == nil and #sim.commandQueue == 0, "hidden rotation curio should block interaction until revealed")
    inputApp.viewRotation = 1
    Input.keypressed(sim, inputApp, "space")
    expect(inputApp.curioModal and inputApp.curioModal.key == "relic_cache", "revealed rotation curio should open interaction modal")
    local turnApp = { viewRotation = 0, viewRotationVisual = 0, settings = Settings.defaults(), audio = {}, ui = {} }
    Input.keypressed(sim, turnApp, "]")
    expect(turnApp.viewRotation == 1 and turnApp.viewTurn and turnApp.viewTurn.to == 1, "bracket rotation should schedule smooth turn tween")
    local reducedTurnApp = { viewRotation = 0, viewRotationVisual = 0, settings = Settings.defaults(), audio = {}, ui = {} }
    reducedTurnApp.settings.reducedMotion = true
    Input.keypressed(sim, reducedTurnApp, "]")
    expect(reducedTurnApp.viewRotation == 1 and reducedTurnApp.viewRotationVisual == 1 and reducedTurnApp.viewTurn == nil, "reduced motion should snap rotation without tween")
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
    local sim = Simulation.new(92)
    reachEntryCombat(sim)
    local hero = sim:activeHero()
    local enemy = sim:enemyAtRank(1)
    enemy.statuses = enemy.statuses or {}
    enemy.statuses[#enemy.statuses + 1] = { kind = "marked", turns = 2 }
    local skillKey = hero.skills[1]
    sim:applySkill(hero, sim:heroRank(hero.id), skillKey, Defs.skill(skillKey), { enemy }, "enemy")
    local event = sim.events[#sim.events]
    expect(event.event == "hero_skill" and type(event.impacts) == "table" and #event.impacts > 0, "hero skill should emit structured impact metadata")
    expect(event.impacts[1].side == "enemy" and event.impacts[1].rank == enemy.rank and event.impacts[1].amount > 0, "impact metadata should locate enemy damage")
    expect(event.crit == true and event.impacts[1].crit == true, "marked direct hit should emit crit feedback metadata")
    local scene = Render.cutsceneForEvent(event, sim)
    expect(scene and scene.crit == true and scene.damage == event.impacts[1].amount, "combat cutscene should carry crit damage feedback")
    expect(Render.damageNumberLabel(event.impacts[1]):find("CRIT", 1, true), "damage number label should expose crit text")
    expect(Render.drawDamageNumbers(sim, { damageNumbers = event.impacts }) == #event.impacts, "damage numbers should render headless summary count")
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
    expect(settings.masterVolume == 1 and settings.sfxVolume == 1 and settings.ambientVolume == 0.7, "settings defaults should expose audio volumes")
    expect(settings.screenShake == true, "settings defaults should enable screen shake")
    Settings.adjust(settings, "masterVolume", -4)
    expect(settings.masterVolume > 0.59 and settings.masterVolume < 0.61, "settings slider should step and clamp")
    Settings.toggle(settings, "highContrast")
    expect(settings.highContrast == true, "settings toggle should flip accessibility flags")
    Settings.toggle(settings, "screenShake")
    expect(settings.screenShake == false and not Render.screenShakeEnabled(settings), "screen shake toggle should disable shake")
    Settings.cycle(settings, "colorblindMode", 1)
    expect(settings.colorblindMode == "deuteranopia", "settings cycle should advance colorblind mode")
    settings.fontScale = 1.4
    expect(Render.fontScale(settings) == 1.4, "font scale should clamp through render")
    local shifted = Render.accessibleColor(settings, { 0.9, 0.1, 0.1, 1 })
    expect(shifted[1] ~= 0.9 and shifted[2] ~= 0.1, "colorblind mode should transform cue colors")
    local app = { settings = settings, eventFlash = { cue = "hit_slash", status = "Mara hit" } }
    expect(Render.audioSubtitle(app) == "slash hit: Mara hit", "subtitles should expose audio cue and status")
    local export = Accessibility.text(Simulation.new(84), app)
    expect(export:find("Thoth accessibility export", 1, true) and export:find("high_contrast=true", 1, true) and export:find("ambient_volume=0.7", 1, true) and export:find("screen_shake=false", 1, true), "accessibility export should expose screen-reader text")
    expect(export:find("party:", 1, true) and export:find("controls:", 1, true), "accessibility export should expose party and controls")
    settings.subtitles = false
    expect(Render.audioSubtitle(app) == nil, "subtitles should respect setting")
    settings.reducedMotion = true
    expect(not Render.markUiPulse(app, { x = 0, y = 0, w = 10, h = 10 }), "reduced motion should suppress pulse animations")
    local equivalents = Render.reducedMotionEquivalents()
    for _, effect in ipairs({ "rotation", "destruction", "knockback", "explosion" }) do
        expect(equivalents[effect] and equivalents[effect].animated and equivalents[effect].reduced and equivalents[effect].cue and equivalents[effect].preserves, "reduced motion should define equivalent for " .. effect)
        local reducedPlan = Render.motionPlan(settings, effect, { source = "a", target = "b", tiles = { { x = 1, y = 1 } } })
        expect(reducedPlan.mode == "reduced" and reducedPlan.animation == "none" and reducedPlan.equivalent == equivalents[effect].reduced and reducedPlan.tiles[1].x == 1, "reduced motion plan should replace animation for " .. effect)
        local animatedPlan = Render.motionPlan({ reducedMotion = false }, effect)
        expect(animatedPlan.mode == "animated" and animatedPlan.animation == equivalents[effect].animated and animatedPlan.equivalent == nil, "motion plan should keep animation when reduced motion is off for " .. effect)
    end
    local ok = Settings.bindKey(settings, "moveUp", "i")
    expect(ok and Settings.keyForAction(settings, "moveUp") == "i", "settings should bind movement key")
    local duplicate = Settings.bindKey(settings, "moveDown", "i")
    expect(not duplicate, "settings should reject duplicate keybind")
    local reserved = Settings.bindKey(settings, "moveDown", "escape")
    expect(not reserved, "settings should reserve escape during capture")
    local settingsText = Settings.toText(settings)
    expect(settingsText:match("^THOTH_LUA_SETTINGS 1"), "settings should write separate v1 header")
    local loadedSettings = assert(Settings.fromText(settingsText))
    expect(loadedSettings.masterVolume == settings.masterVolume and loadedSettings.ambientVolume == 0.7 and loadedSettings.highContrast and loadedSettings.colorblindMode == "deuteranopia" and loadedSettings.screenShake == false, "settings text round trip should preserve values")
    expect(Settings.keyForAction(loadedSettings, "moveUp") == "i", "settings text round trip should preserve keybinds")
    local clampedSettings = assert(Settings.fromText("THOTH_LUA_SETTINGS 1\n{[\"fontScale\"]=9,[\"masterVolume\"]=-4,[\"colorblindMode\"]=\"bad\",[\"keybinds\"]={[\"moveUp\"]=\"escape\",[\"moveDown\"]=\"j\"}}\n"))
    expect(clampedSettings.fontScale == 1.4 and clampedSettings.masterVolume == 0 and clampedSettings.colorblindMode == "off", "settings loader should clamp values")
    expect(Settings.keyForAction(clampedSettings, "moveUp") == "w" and Settings.keyForAction(clampedSettings, "moveDown") == "j", "settings loader should reject reserved keybinds")
    local tempSettingsPath = "test-settings.thoth.tmp"
    os.remove(tempSettingsPath)
    expect(Settings.write(settings, tempSettingsPath), "settings should write to separate file")
    local fileSettings = assert(Settings.read(tempSettingsPath))
    os.remove(tempSettingsPath)
    expect(fileSettings.masterVolume == settings.masterVolume and Settings.keyForAction(fileSettings, "moveUp") == "i", "settings file round trip should preserve values")
end

tests[#tests + 1] = function()
    local disabled = Render.titleMenuItems({ canContinue = false })
    expect(#disabled == 6, "title should expose six menu items")
    expect(disabled[1].action == "new" and disabled[1].enabled, "title should expose new game")
    expect(disabled[2].action == "continue" and not disabled[2].enabled, "title continue should disable without save")
    expect(disabled[3].action == "replay" and not disabled[3].enabled, "title replay should disable without replay")
    expect(disabled[4].action == "settings" and disabled[5].action == "credits" and disabled[6].action == "quit", "title should expose settings, credits, and quit")
    local enabled = Render.titleMenuItems({ canContinue = true, canReplay = true })
    expect(enabled[2].enabled and enabled[3].enabled, "title continue and replay should enable with files")
    local app = { canContinue = true, canReplay = true, ui = { titleButtons = { { stale = true } } } }
    Render.drawTitle(Simulation.new(76), app)
    expect(#app.ui.titleButtons == 6 and app.ui.titleButtons[2].action == "continue" and app.ui.titleButtons[3].action == "replay" and app.ui.titleButtons[5].action == "credits", "title draw should populate title hitboxes")
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
    expect(#credits.assets >= 12 and credits.assets[1].license == "CC-BY 3.0", "credits should load asset license rows")
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
