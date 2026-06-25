package.path = "./?.lua;./?/init.lua;./src/?.lua;./src/?/init.lua;" .. package.path

local Serialize = require("src.core.serialize")
local Save = require("src.game.save")
local Replay = require("src.game.replay")
local Input = require("src.app.input")
local Render = require("src.app.render")
local Topology = require("src.core.topology")
local Noise = require("src.core.noise")
local TileAtlas = require("src.app.tile_atlas")
local ReplayViewer = require("src.app.replay_viewer")
local Audio = require("src.app.audio")
local Accessibility = require("src.app.accessibility")
local Credits = require("src.app.credits")
local Settings = require("src.app.settings")
local Achievements = require("src.app.achievements")
local SpritePipeline = require("src.app.sprite_pipeline")
local ModelPipeline = require("src.app.model_pipeline")
local TileModelMap = require("assets.models.tile_model_map")
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
local EnemyAI = require("src.game.tactics.enemy_ai")
local TacticsProcgen = require("src.game.tactics.procgen")
local ProcgenValidator = require("tools.validator")
local ArchivedTactics = require("src.game.tactics.archive.future_zones")
local TacticsReplay = require("src.game.tactics.replay")
local TacticalRuntime = require("src.game.tactical_runtime")
local SquadLoadout = require("src.game.tactics.squad_loadout")

local function expect(value, message)
    if not value then
        error(message or "expectation failed", 2)
    end
end

local function sameSnapshot(a, b)
    return Serialize.encode(a:snapshot()) == Serialize.encode(b:snapshot())
end

local function makeTacticalSim(seed)
    return {
        seed = seed,
        mode = "tactical",
        status = "tactical",
        tick = 0,
        player = { x = 0, y = 0, z = 0 },
        world = {
            setTile = function() end,
        },
    }
end

local function contains(list, value)
    for _, entry in ipairs(list or {}) do
        if entry == value then
            return true
        end
    end
    return false
end

local function firstEnemy(runtime)
    return (runtime.state:unitsForSide("enemy"))[1]
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

local tests = {}

tests[#tests + 1] = function()
    local function sharedVertices(a, b)
        local count = 0
        for _, ap in ipairs(a) do
            for _, bp in ipairs(b) do
                if math.abs(ap[1] - bp[1]) < 0.000001 and math.abs(ap[2] - bp[2]) < 0.000001 then
                    count = count + 1
                end
            end
        end
        return count
    end
    expect(Topology.edgeCount("triangle") == 3, "triangle topology should expose three edges")
    expect(Topology.edgeCount("square") == 4, "square topology should expose four edges")
    expect(Topology.edgeCount("hex") == 6, "hex topology should expose six edges")
    expect(Render.rotationSteps("triangle") == 3 and Render.rotationSteps("square") == 4 and Render.rotationSteps("hex") == 6, "view rotation steps should follow edge count")
    expect(Render.rotationCompass(1, 3).degrees == 120 and Render.rotationCompass(1, 6).degrees == 60, "view rotation degrees should follow topology edge count")
    expect(sharedVertices(Topology.vertices("triangle", 2, 2), Topology.vertices("triangle", 3, 2)) == 2, "adjacent triangles should share a complete edge")
    expect(sharedVertices(Topology.vertices("hex", 2, 2), Topology.vertices("hex", 3, 2)) == 2, "adjacent hexes should share a complete edge")
    for _, kind in ipairs({ "triangle", "hex" }) do
        for _, neighbor in ipairs(Topology.neighbors(kind, 3, 3)) do
            expect(sharedVertices(Topology.vertices(kind, 3, 3), Topology.vertices(kind, neighbor.x, neighbor.y)) == 2, kind .. " neighbor should share exactly one edge")
        end
    end
    local tcx, tcy = Topology.center("triangle", 2, 2)
    local hitX, hitY = Topology.cellAtPoint("triangle", tcx, tcy)
    expect(hitX == 2 and hitY == 2, "triangle hit testing should resolve tile centers")
    local hcx, hcy = Topology.center("hex", 2, 2)
    hitX, hitY = Topology.cellAtPoint("hex", hcx, hcy)
    expect(hitX == 2 and hitY == 2, "hex hit testing should resolve tile centers")
    local triangle = TacticsState.new({
        board = { width = 4, height = 4, topology = "triangle", shape = "square" },
        units = { { id = "scout", side = "player", x = 2, y = 2, hp = 3, ap = 2, visionRadius = 4 } },
    })
    expect(#triangle:neighbors(2, 2) == 3, "triangle state movement should use three neighbors")
    expect(triangle:snapshot().board.topology == "triangle", "tactical snapshot should persist topology")
    local hex = TacticsState.new({
        board = { width = 5, height = 5, topology = "hex" },
        units = { { id = "scout", side = "player", x = 3, y = 3, hp = 3, ap = 2, visionRadius = 4 } },
    })
    expect(#hex:neighbors(3, 3) == 6, "hex state movement should use six neighbors")
    hex:apply(TacticsState.commands.move("scout", "east"))
    expect(hex:unit("scout").x == 4 and hex:unit("scout").y == 3, "hex east move should update unit coordinates")
    local function shapeCount(kind, width, height)
        local count = 0
        for y = 1, height do
            for x = 1, width do
                if Topology.inShape(kind, width, height, x, y) then
                    count = count + 1
                end
            end
        end
        return count
    end
    expect(shapeCount("triangle", 6, 6) == 21 and Topology.inShape("triangle", 6, 6, 3, 1) and not Topology.inShape("triangle", 6, 6, 1, 1), "triangle topology board mask should form a triangle")
    expect(shapeCount("hex", 6, 6) == 30 and Topology.inShape("hex", 6, 6, 2, 1) and not Topology.inShape("hex", 6, 6, 1, 1) and not Topology.inShape("hex", 6, 6, 6, 2), "hex topology board mask should form a hexagon")
    expect(shapeCount("square", 6, 6) == 36, "square topology board mask should remain rectangular")
    local shaped = TacticsState.new({
        board = { width = 6, height = 6, topology = "triangle" },
        units = { { id = "warden", side = "player", x = 1, y = 3, hp = 6, ap = 3 } },
    })
    expect(shaped:inBounds(shaped:unit("warden").x, shaped:unit("warden").y) and not shaped:inBounds(1, 1), "topology-shaped boards should relocate fixture units into the mask")
    local sim = {
        player = { x = 0, y = 0, z = 0 },
        world = {
            tiles = {},
            setTile = function(self, x, y, z, tile)
                self.tiles[tostring(x) .. ":" .. tostring(y)] = tile
            end,
        },
    }
    TacticalRuntime.syncWorld(sim, { state = shaped, selectedUnitId = "warden", cursor = { x = 1, y = 1 }, originX = 0, originY = 0 })
    local warden = shaped:unit("warden")
    expect(sim.world.tiles["1:1"].shapeVoid == true and sim.world.tiles[tostring(warden.x) .. ":" .. tostring(warden.y)].shapeVoid ~= true, "topology-shaped world sync should mark clipped cells as shape void")
    local runtime = TacticalRuntime.new(makeTacticalSim(9100))
    local before = runtime.topology
    expect(runtime:handleKey("="), "runtime should expose topology increase")
    expect(runtime.topology ~= before and runtime.state.board.topology == runtime.topology, "topology cycle should regenerate board state")
    expect(runtime:handleKey("-"), "runtime should expose topology decrease")
    expect(runtime.topology == before and runtime.state.board.topology == runtime.topology, "topology decrease should return to previous edge count")
    local tutorialRuntime = TacticalRuntime.new(makeTacticalSim(9101), { tutorial = true })
    expect(tutorialRuntime:handleKey("="), "tutorial runtime should expose topology increase")
    expect(tutorialRuntime.route.tutorial == true and tutorialRuntime.state.board.topology == tutorialRuntime.topology, "tutorial topology cycle should preserve tutorial route")
end

tests[#tests + 1] = function()
    local a = Noise.sample("fractal", 17, 3, 5, { source = "perlin", frequency = 0.2, octaves = 3 })
    local b = Noise.sample("fractal", 17, 3, 5, { source = "perlin", frequency = 0.2, octaves = 3 })
    expect(a == b and a >= 0 and a <= 1, "fractal noise should be deterministic and normalized")
    expect(Noise.sample("simplex", 17, 3, 5) == Noise.sample("simplex", 17, 3, 5), "simplex noise should be deterministic")
    expect(TileAtlas.entryFor({ terrainType = "brine_pool" }).id == "brine_pool", "tile atlas should map terrain type entries")
    expect(TileAtlas.entryFor({ terrainType = "sunken_water" }).id == "brine_pool", "tile atlas should map terrain aliases")
    local rect = TileAtlas.uvRect(TileAtlas.entryFor({ terrainType = "heat_vent" }), 64, 48)
    expect(rect.u0 < rect.u1 and rect.v0 < rect.v1 and rect.entry == "heat_vent", "tile atlas should expose uv rects")
    local fakeImage = {
        newImageData = function(width, height)
            return {
                width = width,
                height = height,
                pixels = 0,
                setPixel = function(self)
                    self.pixels = self.pixels + 1
                end,
            }
        end,
    }
    local data, columns, rows = TileAtlas.makeImageData(fakeImage)
    local entryCount = #TileAtlas.entries()
    expect(data.width == 64 and data.height == 48 and columns == 4 and rows == 3 and data.pixels == entryCount * 16 * 16, "tile atlas should generate a 4x3 16px fallback atlas")
end

tests[#tests + 1] = function()
    local state = TacticsState.new({
        board = { width = 6, height = 3, topology = "square" },
        units = {
            { id = "lead", side = "player", x = 1, y = 2, hp = 5, ap = 3, visionRadius = 4 },
            { id = "second", side = "player", x = 1, y = 1, hp = 5, ap = 3, visionRadius = 4 },
            { id = "third", side = "player", x = 1, y = 3, hp = 5, ap = 3, visionRadius = 4 },
        },
        objectives = {
            { id = "exit", x = 6, y = 3, integrity = 3, maxIntegrity = 3, evacuateAt = { x = 6, y = 1 } },
        },
    })
    local runtime = {
        state = state,
        selectedUnitId = "lead",
        cursor = { x = 1, y = 2 },
        turn = 1,
        lastSeenEnemies = {},
        cache = {},
        partyMovementEnabled = true,
        explorationMode = true,
        status = "",
    }
    TacticalRuntime.refreshOverlays(runtime)
    expect(TacticalRuntime.movePartyTo(runtime, 4, 2), "party auto-path should move toward reachable target")
    expect(state:unit("lead").x == 4 and state:unit("lead").y == 2, "party leader should reach clicked tile")
    expect(state:unit("second").x == 3 and state:unit("second").y == 2, "second party member should follow the previous lead tile")
    expect(state:unit("third").x == 2 and state:unit("third").y == 2, "third party member should remain in row formation")
    expect(runtime.explorationMode == true, "party movement without contact should stay in exploration mode")
end

tests[#tests + 1] = function()
    local state = TacticsState.new({
        board = { width = 5, height = 3 },
        units = {
            { id = "warden", side = "player", x = 1, y = 2, hp = 5, ap = 4 },
            { id = "bailiff", side = "enemy", x = 4, y = 2, hp = 2 },
        },
    })
    expect(state:unitAt(4, 2).id == "bailiff", "unit index should resolve initial occupant")
    state:moveUnitTo(state:unit("warden"), 2, 2)
    expect(state:unitAt(1, 2) == nil and state:unitAt(2, 2).id == "warden", "unit index should update after moveUnitTo")
    state:unit("bailiff").x = 5
    expect(state:unitAt(4, 2) == nil and state:unitAt(5, 2).id == "bailiff", "unit index should recover from direct coordinate mutation")
    state:damageUnit("bailiff", 99)
    expect(state:unitAt(5, 2) == nil, "unit index should drop dead units")
    local preview = state:movementPreview("warden", { includePaths = false })
    expect(preview.reachable[1].path == nil, "movement preview should support no-path overlay mode")
end

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
    local tacticalSim = makeTacticalSim(9001)
    local runtime = TacticalRuntime.new(tacticalSim)
    local summary = runtime:summary()
    expect(tacticalSim.mode == "tactical" and summary.mode == "tactical", "runtime should put the game in tactical mode")
    expect(summary.route and summary.route.variantId == "archive_entry_audit", "runtime should load tactical board from archive route procgen")
    expect(#summary.players == 6 and #summary.enemies == 2, "runtime should expose procgen tactical squad and catalog enemies")
    local liveClasses = {
        { id = "warden", classId = "warden" },
        { id = "duelist", classId = "duelist" },
        { id = "apothecary", classId = "mender" },
        { id = "thief", classId = "harrier" },
        { id = "arcanist", classId = "arcanist" },
        { id = "lamplighter", classId = "lamplighter" },
    }
    for _, entry in ipairs(liveClasses) do
        local unit = runtime.state:unit(entry.id)
        expect(unit and unit.class == entry.classId and #unit.boardVerbs == #ClassCatalog.boardVerbs(entry.classId) and #unit.loadouts == 2, entry.id .. " should instantiate from class catalog loadouts")
    end
    local enemy = firstEnemy(runtime)
    local claimantIntent = runtime.state:intentPreview(enemy.id)
    local claimantTarget = claimantIntent and claimantIntent.targetTiles and claimantIntent.targetTiles[1]
    local claimantTargetUnit = claimantTarget and runtime.state:unitAt(claimantTarget.x, claimantTarget.y)
    local claimantTargetObjective = claimantTarget and runtime.state:objectiveAt(claimantTarget.x, claimantTarget.y)
    expect(#runtime.overlays.intents == 2 and claimantIntent.intentType and (claimantTargetUnit or claimantTargetObjective), "runtime should show exact catalog enemy intents")
    runtime:handleKey("right")
    runtime:handleKey("return")
    expect(runtime.state:unit("warden").x == 2 and runtime.state:unit("warden").ap == 2, "runtime should spend AP to move selected unit")
    local hpBefore = 0
    for _, unit in ipairs(runtime.state:unitsForSide("player")) do
        hpBefore = hpBefore + unit.hp
    end
    runtime:handleKey("e")
    local hpAfter = 0
    for _, unit in ipairs(runtime.state:unitsForSide("player")) do
        hpAfter = hpAfter + unit.hp
    end
    expect(runtime.state:objective("entry_shelf").integrity == 3, "enemy intent should leave untargeted objective intact")
    expect(hpAfter <= hpBefore, "catalog enemy intents should resolve without healing player targets")
    expect(runtime.state.phase == "player" and runtime.state:unit("warden").ap == 3, "runtime should return to player phase with AP refreshed")
end

tests[#tests + 1] = function()
    local runtime = TacticalRuntime.new(makeTacticalSim(9021), { squadLoadout = SquadLoadout.runtimeLoadout(SquadLoadout.tutorialSelection()) })
    local warden = runtime.state:unit("warden")
    local enemy = firstEnemy(runtime)
    enemy.x = warden.x
    enemy.y = warden.y + 1
    enemy.hp = 2
    runtime:setCursor(enemy.x, enemy.y)
    expect(runtime:handleKey("a"), "player attack should resolve")
    local events = runtime:drainHitEvents()
    expect(#events == 1 and events[1].source == "warden" and events[1].target == enemy.id and events[1].targetSide == "enemy" and events[1].amount > 0, "player attack should queue tactical hit feedback")
    expect(#runtime:drainHitEvents() == 0, "tactical hit feedback should drain once")
    expect(Render.damageNumberLabel({ kind = "blocked", amount = 0 }) == "BLOCK", "blocked tactical hits should render a readable label")
end

tests[#tests + 1] = function()
    local state = TacticsState.new({
        board = { width = 5, height = 1 },
        units = {
            { id = "warden", side = "player", x = 1, y = 1, hp = 6, visionRadius = 6 },
            { id = "page_scout", side = "enemy", kind = "page_scout", x = 4, y = 1, hp = 4, ap = 3, maxAp = 3 },
        },
    })
    local runtime = { state = state, selectedUnitId = "warden", cursor = { x = 1, y = 1 }, turn = 1, lastSeenEnemies = {}, sim = makeTacticalSim(9022), hitEvents = {}, drainHitEvents = TacticalRuntime.drainHitEvents }
    TacticalRuntime.declareEnemyIntents(runtime)
    TacticalRuntime.endPlayerTurn(runtime)
    local events = runtime:drainHitEvents()
    expect(#events >= 1 and events[1].source == "page_scout" and events[1].target == "warden" and events[1].targetSide == "player" and events[1].amount > 0, "enemy attack should queue tactical hit feedback")
end

tests[#tests + 1] = function()
    local state = TacticsState.new({
        defaultAp = 4,
        board = { width = 5, height = 1 },
        units = {
            { id = "duelist", side = "player", class = "duelist", x = 1, y = 1, hp = 5, visionRadius = 6 },
            { id = "page_scout", side = "enemy", kind = "page_scout", x = 3, y = 1, hp = 4 },
        },
    })
    local runtime = { state = state, selectedUnitId = "duelist", cursor = { x = 3, y = 1 }, turn = 1, lastSeenEnemies = {}, sim = makeTacticalSim(9023), hitEvents = {}, drainHitEvents = TacticalRuntime.drainHitEvents }
    expect(TacticalRuntime.activateClassVerb(runtime, 2), "dash_strike should resolve")
    local events = runtime:drainHitEvents()
    expect(#events == 1 and events[1].source == "duelist" and events[1].target == "page_scout" and events[1].amount > 0, "sequenced class attack should queue tactical hit feedback")
end

tests[#tests + 1] = function()
    local selection = SquadLoadout.defaultSelection()
    local summary = SquadLoadout.summary(selection)
    local expected = { "warden", "duelist", "mender", "harrier", "arcanist", "lamplighter" }
    expect(summary.selected == 6 and summary.required == 6 and summary.ready and summary.allowDuplicateClasses == false, "squad loadout should default to six distinct slice classes")
    for index, classId in ipairs(expected) do
        local entry = selection.classes[index]
        expect(entry and entry.classId == classId and entry.selected and #entry.loadoutIds == 2, "squad loadout should expose starter loadouts for " .. classId)
    end
    local payload = SquadLoadout.runtimeLoadout(selection)
    expect(payload and #payload.units == 6 and payload.allowDuplicateClasses == false, "squad loadout should export runtime payload")
    SquadLoadout.toggle(selection, 1)
    local ok, err = SquadLoadout.validate(selection)
    expect(not ok and err == "select six distinct classes", "squad loadout should reject squads below six distinct classes")
    local app = { squadSelect = selection, ui = { squadLoadoutButtons = { { stale = true } } } }
    local renderSummary = Render.drawSquadLoadout(nil, app)
    expect(renderSummary.selected == 5 and #app.ui.squadLoadoutButtons == 8 and app.ui.squadLoadoutButtons[#app.ui.squadLoadoutButtons].enabled == false, "squad loadout screen should expose class rows plus disabled start")
    SquadLoadout.toggle(selection, 1)
    local readyPayload = SquadLoadout.runtimeLoadout(selection)
    local runtime = TacticalRuntime.new(makeTacticalSim(9018), { squadLoadout = readyPayload })
    local players = runtime:summary().players
    expect(#players == 6 and players[6].class == "lamplighter" and #players[6].loadouts == 2, "runtime should instantiate selected squad loadout")
    local tutorialSelection = SquadLoadout.tutorialSelection()
    local tutorialSummary = SquadLoadout.summary(tutorialSelection)
    expect(tutorialSummary.missionId == "tutorial" and tutorialSummary.selected == 1 and tutorialSummary.required == 1 and tutorialSummary.ready, "tutorial loadout should require one class")
    local tutorialPayload = SquadLoadout.runtimeLoadout(tutorialSelection)
    expect(tutorialPayload and tutorialPayload.missionId == "tutorial" and #tutorialPayload.units == 1 and tutorialPayload.units[1].classId == "warden", "tutorial loadout should export one Warden")
    app = { squadSelect = tutorialSelection, ui = { squadLoadoutButtons = { { stale = true } } } }
    renderSummary = Render.drawSquadLoadout(nil, app)
    expect(renderSummary.missionLabel == "mission 0" and #app.ui.squadLoadoutButtons == 3 and app.ui.squadLoadoutButtons[#app.ui.squadLoadoutButtons].enabled, "tutorial loadout screen should expose one class plus enabled start")
    local tutorialRuntime = TacticalRuntime.new(makeTacticalSim(9017), { squadLoadout = tutorialPayload })
    local tutorialPlayers = tutorialRuntime:summary().players
    expect(tutorialRuntime.route.variantId == "tutorial_onboarding" and tutorialRuntime:summary().routeCount == 1 and #tutorialPlayers == 1 and tutorialPlayers[1].class == "warden", "runtime should instantiate mission 0 with one Warden")
    local bailiff = tutorialRuntime.state:unit("bailiff")
    bailiff.x = 1
    bailiff.y = 4
    bailiff.hp = 1
    tutorialRuntime:setCursor(1, 4)
    tutorialRuntime:handleKey("a")
    expect(tutorialRuntime.routeComplete, "tutorial runtime should complete after the tutorial enemy is cleared")
end

tests[#tests + 1] = function()
    local runtime = TacticalRuntime.new(makeTacticalSim(9020), { aiDebug = true })
    expect(runtime.aiDebug and runtime.aiDebugPlans and next(runtime.aiDebugPlans) ~= nil and #runtime.overlays.aiDebug > 0, "AI debug runtime should expose visible plan overlays")
    local summary = runtime:summary()
    expect(summary.aiDebug and summary.enemies[1] and summary.enemies[1].aiDebug and summary.enemies[1].aiDebug.chosen, "AI debug summary should expose chosen enemy plan")
    expect(summary.aiDoctrine and summary.enemies[1].aiDebug.doctrine and summary.enemies[1].aiDebug.inputs.doctrine == summary.aiDoctrine.id, "AI debug summary should expose squad doctrine")
    runtime:setAiDebug(false)
    expect(not runtime.aiDebug and #runtime.overlays.aiDebug == 0, "AI debug toggle should hide debug overlays")
end

tests[#tests + 1] = function()
    local runtime = TacticalRuntime.new(makeTacticalSim(9006))
    local enemy = firstEnemy(runtime)
    for _, other in ipairs(runtime.state:unitsForSide("enemy")) do
        if other.id ~= enemy.id then
            other.alive = false
        end
    end
    enemy.x = 2
    enemy.y = 4
    enemy.hp = 1
    runtime:setCursor(2, 4)
    runtime:handleKey("a")
    expect(runtime.route.variantId == "archive_shelf_protection" and runtime.routeIndex == 2 and not runtime.complete, "cleared board should advance to next archive route variant")
    TacticalRuntime.loadRouteVariant(runtime, runtime.routeOrder[#runtime.routeOrder])
    enemy = firstEnemy(runtime)
    for _, other in ipairs(runtime.state:unitsForSide("enemy")) do
        if other.id ~= enemy.id then
            other.alive = false
        end
    end
    enemy.x = 2
    enemy.y = 4
    enemy.hp = 1
    runtime:setCursor(2, 4)
    runtime:handleKey("a")
    expect(runtime.complete and runtime.routeComplete and runtime.route.variantId == runtime.routeOrder[#runtime.routeOrder], "last cleared board should complete tactical route")
end

tests[#tests + 1] = function()
    local runtime = TacticalRuntime.new(makeTacticalSim(9019))
    expect(runtime.state.board.width == 48 and runtime.state.board.height == 36 and runtime.state.board.expanse == true, "runtime should use one large semi-open catacomb hub")
    local metrics = runtime.state.board.metrics or {}
    expect(#(runtime.state.board.districts or {}) >= 5 and #(runtime.state.board.softGates or {}) >= 2 and #(runtime.state.board.landmarks or {}) >= 8, "expanse should expose districts, soft gates, and landmarks")
    expect((metrics.optionalOpenRatio or 0) >= 0.45 and (metrics.optionalOpenRatio or 0) <= 0.55, "semi-open hub should keep about half of open space optional")
    local dormant = nil
    for _, id in ipairs(runtime.state.unitOrder or {}) do
        local unit = runtime.state:unit(id)
        if unit and unit.side == "enemy" and tostring(unit.id):find("__archive_shelf_protection", 1, true) then
            dormant = unit
            break
        end
    end
    expect(dormant and dormant.alive == false, "future region enemies should start dormant")
    local app = { tactics = runtime }
    local enemyRows = Render.tacticalEnemyHudRows(app)
    expect(#enemyRows >= 2 and enemyRows[1].intentIcon ~= "-" and enemyRows[1].targetTiles[1], "enemy HUD rows should expose visible intent cards")
    local sameState = runtime.state
    for _, enemy in ipairs(runtime.state:unitsForSide("enemy")) do
        enemy.alive = false
    end
    TacticalRuntime.evaluate(runtime)
    expect(runtime.state == sameState and runtime.route.variantId == "archive_shelf_protection" and runtime.state:unit(dormant.id).alive, "route advance should wake next region without replacing state")
    local bridge = runtime.state:tileAt(9, 4)
    expect(bridge.destructibleHp == 3 and bridge.height == 1, "expanse should include destructible elevated bridge")
    runtime.state:damageTile(9, 4, 3)
    local collapsed = runtime.state:tileAt(9, 4)
    expect(collapsed.destroyed and collapsed.height == 0 and collapsed.kind == "rubble", "destroyed bridge should collapse into lower rubble")
    local verticalRoutes = runtime.state.board.verticalRoutes or {}
    local sawAscent, sawDescent = false, false
    for _, route in ipairs(verticalRoutes) do
        sawAscent = sawAscent or route.kind == "ascend"
        sawDescent = sawDescent or route.kind == "descend"
    end
    expect(#verticalRoutes >= 2 and sawAscent and sawDescent, "expanse should define explicit ascent and descent routes")
    expect(#(runtime.state.board.sightlines or {}) >= 2 and #(runtime.state.board.coverFields or {}) >= 3, "expanse should define sightlines and XCOM-style cover fields")
    expect(#(runtime.state.board.terrainTypes or {}) >= 8 and #(runtime.state.board.generationTechniques or {}) >= 5, "expanse should define varied terrain types and generation techniques")
    expect(runtime.state:tileAt(12, 9).terrainType == "brine_pool" and runtime.state:tileAt(16, 10).terrainType == "index_miasma", "expanse should mix water and obscurant terrain types")
    local highSight = runtime.state:sightlineProfile(24, 12, 20, 12)
    expect(highSight.visible and highSight.vantage == "high_ground", "expanse spire should create high-ground sightlines")
    local blockedSight = runtime.state:sightlineProfile(20, 16, 28, 16)
    expect(not blockedSight.visible and blockedSight.blockedBy.x == 22, "breakable tall columns should block low-ground sightlines")
    runtime.state:damageTile(22, 16, 2)
    local openedSight = runtime.state:sightlineProfile(20, 16, 28, 16)
    expect(openedSight.visible and runtime.state:tileAt(22, 16).height == 0, "destroyed sight columns should open LoS and collapse")
end

tests[#tests + 1] = function()
    local state = TacticsState.new({
        defaultAp = 3,
        board = {
            width = 3,
            height = 1,
            tiles = {
                ["1:1"] = { height = 0, tags = { "height_band" } },
                ["2:1"] = { height = 3, tags = { "height_band" } },
                ["3:1"] = { height = 3, tags = { "height_band", "stair" } },
            },
        },
        units = {
            { id = "warden", side = "player", x = 1, y = 1, hp = 6 },
        },
    })
    local ok, reason = state:canEnter(2, 1, "warden", 1, 1)
    expect(not ok and reason == "climb_blocked", "height-band movement should reject unclimbable ledges")
    ok, reason = state:canEnter(1, 1, "warden", 2, 1)
    expect(not ok and reason == "drop_blocked", "height-band movement should reject unsafe descents")
    state.board.tiles["2:1"].tags[#state.board.tiles["2:1"].tags + 1] = "stair"
    ok = state:canEnter(2, 1, "warden", 1, 1)
    expect(ok == true, "stairs should permit steep height movement")
    local preview = state:movementPreview("warden")
    local climb
    for _, tile in ipairs(preview.reachable) do
        if tile.x == 2 and tile.y == 1 then
            climb = tile
        end
    end
    expect(climb and climb.height == 3 and climb.heightDelta == 3 and climb.vertical == "ascend", "movement preview should expose climb height deltas")
end

tests[#tests + 1] = function()
    local state = TacticsState.new({
        defaultAp = 3,
        board = {
            width = 3,
            height = 1,
            tiles = {
                ["2:1"] = { terrainType = "archive_rubble", moveCost = 1, tags = { "rough_terrain" } },
            },
        },
        units = {
            { id = "warden", side = "player", x = 1, y = 1, hp = 6, ap = 3 },
        },
    })
    local preview = state:movementPreview("warden")
    local rubble
    for _, tile in ipairs(preview.reachable) do
        if tile.x == 2 and tile.y == 1 then
            rubble = tile
        end
    end
    expect(rubble and rubble.apCost == 2 and rubble.terrainCost == 1 and rubble.moveCost == 2 and rubble.terrainType == "archive_rubble", "rough terrain should add movement AP cost")
end

tests[#tests + 1] = function()
    local tacticalSim = makeTacticalSim(9003)
    local runtime = TacticalRuntime.new(tacticalSim)
    local enemy = firstEnemy(runtime)
    enemy.x = 4
    enemy.y = 4
    runtime.state:unit("lamplighter").alive = false
    enemy.intent = { mode = "exact", intentType = "test_attack", category = "attack", target = "nearest_player", damage = 1 }
    TacticalRuntime.declareEnemyIntents(runtime)
    local posted = runtime.state:intentPreview(enemy.id).targetTiles[1]
    local postedUnit = runtime.state:unitAt(posted.x, posted.y)
    expect(postedUnit and postedUnit.side == "player" and not (posted.x == 2 and posted.y == 4), "enemy intent should start on the posted pre-move target")
    runtime:setCursor(2, 4)
    expect(runtime:moveSelectedToCursor(), "visible tactical move should apply")
    local adjusted = runtime.state:intentPreview(enemy.id)
    expect(adjusted.targetTiles[1].x == 2 and adjusted.targetTiles[1].y == 4, "visible movement should update enemy intent to the new tile")
    expect(runtime.message:find("enemies adjusted", 1, true), "visible movement should report enemy intent adjustment")
end

tests[#tests + 1] = function()
    local state = TacticsState.new({
        board = { width = 5, height = 1 },
        units = {
            { id = "scout", side = "player", x = 1, y = 1, ap = 2, visionRadius = 1 },
            { id = "near", side = "enemy", x = 2, y = 1, hp = 2 },
            { id = "far", side = "enemy", x = 5, y = 1, hp = 2 },
        },
        objectives = {
            { id = "machine", kind = "protect_archive_shelf", x = 1, y = 1, integrity = 3, maxIntegrity = 3, evacuateAt = { x = 1, y = 1 } },
        },
    })
    state:declareIntent("near", { mode = "exact", category = "attack", source = "near", sourceTile = { x = 2, y = 1 }, targetTiles = { { x = 1, y = 1 } }, damage = 1, label = "near hit" })
    state:declareIntent("far", { mode = "exact", category = "attack", source = "far", sourceTile = { x = 5, y = 1 }, targetTiles = { { x = 1, y = 1 } }, damage = 1, label = "far hit" })
    local runtime = { state = state, selectedUnitId = "scout", cursor = { x = 1, y = 1 }, turn = 1, lastSeenEnemies = {} }
    TacticalRuntime.refreshOverlays(runtime)
    expect(runtime.overlays.fog.fog["5:1"] and #runtime.overlays.intents == 1 and runtime.overlays.intents[1].label == "near hit", "fog overlay should hide out-of-vision enemy intents")
    local summary = TacticalRuntime.summary(runtime)
    expect(#summary.enemies == 1 and summary.enemies[1].id == "near" and #summary.lastSeenEnemies == 0, "tactical summary should show only visible enemies")
    local fogSummary = Render.tacticalFogSummary(runtime)
    expect(fogSummary.visibleTiles == 2 and fogSummary.fogTiles == 3 and fogSummary.visibleEnemies == 1 and fogSummary.hiddenEnemies == 1, "render fog summary should count visible and dimmed tiles")
    state.units.near.x = 4
    state.units.near.y = 1
    TacticalRuntime.refreshOverlays(runtime)
    summary = TacticalRuntime.summary(runtime)
    expect(#runtime.overlays.intents == 0 and #summary.enemies == 0, "enemy leaving vision should hide unit and intent overlays")
    expect(#summary.lastSeenEnemies == 1 and summary.lastSeenEnemies[1].id == "near" and summary.lastSeenEnemies[1].x == 2, "enemy leaving vision should persist last-seen marker")
    expect(TacticalRuntime.actionAtTile(runtime, 4, 1).kind == "cursor", "hidden enemy tile should not expose attack action")
    runtime.cursor.x = 4
    runtime.cursor.y = 1
    expect(not TacticalRuntime.attackCursor(runtime), "hidden enemy should not be attackable by cursor")
    expect(Render.tacticalFogSummary(runtime).ghostEnemies == 1, "render fog summary should count last-seen ghost markers")
end

tests[#tests + 1] = function()
    local syncs = 0
    local sim = makeTacticalSim(9401)
    sim.world.setTile = function()
        syncs = syncs + 1
    end
    local runtime = TacticalRuntime.new(sim)
    local initialSyncs = syncs
    runtime:handleKey("right")
    TacticalRuntime.syncWorld(sim, runtime)
    expect(syncs == initialSyncs, "cursor movement should not resync the full tactical world")
end

tests[#tests + 1] = function()
    local profile = EnemyCatalog.aiProfile({ id = "page_scout", kind = "page_scout", archetype = "mover" })
    expect(profile.role == "recon" and profile.weights.flank == 40 and profile.weights.distance == -5, "enemy AI profile should merge defaults, archetype, and enemy override")
    local tuned = EnemyCatalog.aiProfile({ id = "page_scout", kind = "page_scout", archetype = "mover", ai = { weights = { cover = 0 } } })
    expect(tuned.weights.cover == 0 and tuned.weights.flank == 40, "enemy AI profile should allow per-unit data overrides")
end

tests[#tests + 1] = function()
    local reconState = TacticsState.new({
        board = { width = 5, height = 5, tiles = { ["3:3"] = { blocker = true, losBlocker = true } } },
        units = {
            { id = "warden", side = "player", x = 1, y = 1, hp = 6 },
            { id = "page_scout", side = "enemy", kind = "page_scout", x = 5, y = 5, hp = 4 },
        },
    })
    expect(EnemyAI.analyzeDoctrine(reconState).id == "recon", "enemy doctrine should switch to recon when no player is visible")
    local pincerState = TacticsState.new({
        board = { width = 5, height = 5 },
        units = {
            { id = "warden", side = "player", x = 3, y = 3, hp = 6 },
            { id = "duelist", side = "player", x = 3, y = 4, hp = 5 },
            { id = "left_scout", side = "enemy", kind = "page_scout", x = 1, y = 3, hp = 4 },
            { id = "right_scout", side = "enemy", kind = "page_scout", x = 5, y = 3, hp = 4 },
        },
    })
    expect(EnemyAI.analyzeDoctrine(pincerState).id == "pincer", "enemy doctrine should prefer pincer when multiple supported players are visible")
    local sabotageState = TacticsState.new({
        board = { width = 5, height = 5 },
        units = {
            { id = "warden", side = "player", x = 1, y = 1, hp = 6 },
            { id = "writ_bailiff", side = "enemy", kind = "writ_bailiff", x = 5, y = 5, hp = 4 },
        },
        objectives = {
            { id = "route_machine", x = 5, y = 4, integrity = 1, maxIntegrity = 4, evacuateAt = { x = 1, y = 5 } },
        },
    })
    expect(EnemyAI.analyzeDoctrine(sabotageState).id == "sabotage", "enemy doctrine should prioritize sabotage when objective integrity is critical")
end

tests[#tests + 1] = function()
    local state = TacticsState.new({
        board = {
            width = 5,
            height = 5,
            tiles = {
                ["4:3"] = { coverEdges = { west = "full" } },
            },
        },
        units = {
            { id = "warden", side = "player", x = 1, y = 3, hp = 6 },
            { id = "page_scout", side = "enemy", kind = "page_scout", x = 5, y = 3, hp = 4, ap = 2, maxAp = 2 },
        },
    })
    local plan = EnemyAI.planEnemy(state, state:unit("page_scout"), { maxMoveAp = 2 })
    expect(plan.destination.x == 4 and plan.destination.y == 3, "enemy AI should prefer reachable firing cover")
    state:unit("page_scout").ai = { weights = { cover = 0 } }
    local tuned = EnemyAI.planEnemy(state, state:unit("page_scout"), { maxMoveAp = 2 })
    expect(tuned.destination.x == 3 and tuned.destination.y == 3, "enemy AI weight override should deterministically change destination")
    expect(plan.debug and plan.debug.chosen and #plan.debug.scoreBreakdown > 0 and #plan.debug.topCandidates > 0, "enemy AI debug should expose chosen score and top candidates")
end

tests[#tests + 1] = function()
    local state = TacticsState.new({
        board = {
            width = 5,
            height = 5,
            tiles = {
                ["4:3"] = { coverEdges = { west = "full" } },
            },
        },
        units = {
            { id = "warden", side = "player", x = 1, y = 3, hp = 6 },
            { id = "page_scout", side = "enemy", kind = "page_scout", x = 5, y = 3, hp = 4, ap = 2, maxAp = 2 },
        },
    })
    local plan = EnemyAI.planEnemy(state, state:unit("page_scout"), {
        maxMoveAp = 2,
        ai = { memory = { repeatDestination = -80 } },
        memory = { units = { page_scout = { lastDestination = { x = 4, y = 3 } } }, targets = {} },
    })
    expect(plan.destination.x ~= 4 or plan.destination.y ~= 3, "enemy AI memory should avoid repeating a heavily penalized destination")
    local targetState = TacticsState.new({
        board = { width = 5, height = 3 },
        units = {
            { id = "duelist", side = "player", x = 2, y = 1, hp = 5 },
            { id = "warden", side = "player", x = 2, y = 3, hp = 6 },
            { id = "page_scout", side = "enemy", kind = "page_scout", x = 5, y = 2, hp = 4, ap = 2, maxAp = 2 },
        },
    })
    local focused = EnemyAI.planEnemy(targetState, targetState:unit("page_scout"), {
        maxMoveAp = 2,
        memory = { units = {}, targets = { warden = { damage = 2 } } },
    })
    expect(focused.target.id == "warden", "enemy AI memory should focus damaged pressure targets")
    local hasMemoryTerm = false
    for _, term in ipairs(focused.debug.scoreBreakdown or {}) do
        if term.name == "memoryPressure" then
            hasMemoryTerm = true
        end
    end
    expect(hasMemoryTerm, "enemy AI debug should expose memory pressure terms")
end

tests[#tests + 1] = function()
    local state = TacticsState.new({
        board = {
            width = 5,
            height = 5,
            tiles = {
                ["3:3"] = { coverEdges = { west = "full" } },
            },
        },
        units = {
            { id = "warden", side = "player", x = 3, y = 3, hp = 6 },
            { id = "page_scout", side = "enemy", kind = "page_scout", x = 5, y = 3, hp = 4, ap = 3, maxAp = 3 },
        },
    })
    local plan = EnemyAI.planEnemy(state, state:unit("page_scout"), { maxMoveAp = 3 })
    expect(plan.tactic == "flank" and plan.attack.flanked, "enemy AI should recognize reachable flank attacks")
    local debugPlan = EnemyAI.planEnemy(state, state:unit("page_scout"), { maxMoveAp = 3, ai = { debugName = "audit" } })
    expect(debugPlan.destination.x == plan.destination.x and debugPlan.tactic == plan.tactic and debugPlan.debug.debugName == "audit", "enemy AI debug metadata should not change decisions")
end

tests[#tests + 1] = function()
    local state = TacticsState.new({
        board = { width = 5, height = 5 },
        units = {
            { id = "warden", side = "player", x = 3, y = 3, hp = 6 },
            { id = "left_scout", side = "enemy", kind = "page_scout", x = 1, y = 3, hp = 4, ap = 2, maxAp = 2 },
            { id = "right_scout", side = "enemy", kind = "page_scout", x = 5, y = 3, hp = 4, ap = 2, maxAp = 2 },
        },
    })
    local report = EnemyAI.planTurn(state, { maxMoveAp = 2 })
    local pincers = 0
    for _, plan in ipairs(report.plans) do
        if plan.tactic == "pincer" then
            pincers = pincers + 1
        end
    end
    expect(pincers >= 1 and report.plans[1].destination.x ~= report.plans[2].destination.x, "enemy AI should reserve distinct pincer positions")
end

tests[#tests + 1] = function()
    local runtime = {
        state = TacticsState.new({
            board = { width = 4, height = 1 },
            units = {
                { id = "warden", side = "player", x = 1, y = 1, hp = 6 },
                { id = "binding_indexer", side = "enemy", kind = "binding_indexer", archetype = "controller", x = 4, y = 1, hp = 4, intent = EnemyCatalog.enemy("binding_indexer").exactIntent },
            },
        }),
        selectedUnitId = "warden",
        cursor = { x = 1, y = 1 },
        turn = 1,
        lastSeenEnemies = {},
        sim = makeTacticalSim(9403),
    }
    TacticalRuntime.declareEnemyIntents(runtime)
    local intent = runtime.state:intentPreview("binding_indexer")
    expect(intent.category == "debuff" and intent.statusEffect.status == "pinned" and not (intent.destination and intent.destination.x), "status exact intents should remain authoritative without AI reposition")
end

tests[#tests + 1] = function()
    local state = TacticsState.new({
        board = {
            width = 5,
            height = 5,
            tiles = {
                ["3:3"] = { blocker = true, losBlocker = true, height = 2 },
            },
        },
        units = {
            { id = "warden", side = "player", x = 1, y = 1, hp = 6 },
            { id = "page_scout", side = "enemy", kind = "page_scout", x = 5, y = 5, hp = 4, ap = 2, maxAp = 2 },
        },
    })
    local plan = EnemyAI.planEnemy(state, state:unit("page_scout"), { maxMoveAp = 2 })
    expect(plan.tactic == "recon" and plan.destination.x <= 5 and plan.destination.y <= 5, "enemy AI should use recon movement when no target is visible")
end

tests[#tests + 1] = function()
    local state = TacticsState.new({
        board = { width = 5, height = 1 },
        units = {
            { id = "warden", side = "player", x = 1, y = 1, hp = 6 },
            { id = "page_scout", side = "enemy", kind = "page_scout", x = 5, y = 1, hp = 4, ap = 3, maxAp = 3 },
        },
    })
    local runtime = { state = state, selectedUnitId = "warden", cursor = { x = 1, y = 1 }, turn = 1, lastSeenEnemies = {}, sim = makeTacticalSim(9402) }
    TacticalRuntime.declareEnemyIntents(runtime)
    TacticalRuntime.endPlayerTurn(runtime)
    expect(state:unit("page_scout").x < 5 and state:unit("warden").hp < 6, "enemy turn should move and attack with pathfinding")
    expect(runtime.aiMemory and runtime.aiMemory.units.page_scout and runtime.aiMemory.units.page_scout.lastTarget == "warden" and (runtime.aiMemory.targets.warden.damage or 0) > 0, "enemy turn should record adaptive AI memory")
end

tests[#tests + 1] = function()
    local state = TacticsState.new({
        board = { width = 4, height = 1 },
        units = {
            { id = "scout", side = "player", x = 1, y = 1, visionRadius = 1 },
            { id = "lurker", side = "enemy", x = 4, y = 1, hp = 2 },
        },
    })
    state:declareIntent("lurker", { mode = "exact", category = "attack", targetTiles = { { x = 1, y = 1 } }, damage = 1, label = "knife" })
    local hidden = TacticsIntent.preview(state, "lurker", { side = "player" })
    expect(hidden.hiddenByVision and hidden.categoryOnly and hidden.targetTiles == nil and not state.intents.lurker.revealed, "hidden enemy intent should hide footprint before first LoS")
    state.units.lurker.x = 2
    local revealed = TacticsIntent.preview(state, "lurker", { side = "player" })
    expect(revealed.targetTiles[1].x == 1 and state.intents.lurker.revealed, "hidden enemy intent should reveal on first LoS")
end

tests[#tests + 1] = function()
    local runtime = TacticalRuntime.new(makeTacticalSim(9007))
    local enemy = firstEnemy(runtime)
    runtime.state:objective("entry_shelf").integrity = 1
    TacticalRuntime.declareEnemyIntents(runtime)
    local finisher = runtime.state:intentPreview(enemy.id)
    expect(finisher.category == "destroy" and finisher.objectiveImpact == "entry_shelf" and finisher.targetTiles[1].x == 7, "critical objective should make enemy choose deterministic finisher intent")
    runtime.state:objective("entry_shelf").integrity = 3
    enemy.hp = 1
    TacticalRuntime.declareEnemyIntents(runtime)
    local guard = runtime.state:intentPreview(enemy.id)
    expect(guard.category == "guard" and guard.damage == 0 and guard.targetTiles[1].x == enemy.x, "wounded enemy should choose deterministic guard intent")
end

tests[#tests + 1] = function()
    local tacticalSim = makeTacticalSim(9004)
    local runtime = TacticalRuntime.new(tacticalSim)
    local enemy = firstEnemy(runtime)
    enemy.x = 4
    enemy.y = 4
    TacticalRuntime.declareEnemyIntents(runtime)
    local posted = runtime.state:intentPreview(enemy.id).targetTiles[1]
    runtime.state:addObscurant(2, 4, "smoke", 2)
    runtime:setCursor(2, 4)
    expect(runtime:moveSelectedToCursor(), "smoke-covered tactical move should apply")
    local held = runtime.state:intentPreview(enemy.id)
    expect(held.targetTiles[1].x == posted.x and held.targetTiles[1].y == posted.y, "obscured movement should keep the old enemy intent")
end

tests[#tests + 1] = function()
    local tacticalSim = makeTacticalSim(9002)
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
    expect(Input.updateTacticalHover(app, sx, sy) and app.tacticalHover.x == 3 and app.tacticalHover.y == 6, "tactical hover should track projected board tile")
    expect(app.tacticalInspector and app.tacticalInspector.terrain.x == 3 and app.tacticalInspector.source == "hover", "tactical hover should populate tile inspector summary")
    app.worldView.tacticalCamera = {
        eyeX = runtime.originX + 3.5 + 10,
        eyeY = runtime.originY + 6.5 - 10,
        eyeZ = 8,
        targetX = runtime.originX + 3.5,
        targetY = runtime.originY + 6.5,
        targetZ = 0,
        boardZ = 0,
        orthoSize = 10,
        screenWidth = 800,
        screenHeight = 600,
    }
    tileX, tileY = Render.tacticalTileAt(app, 400, 300)
    expect(tileX == 3 and tileY == 6, "g3d tactical mouse projection should map screen center to target tile")
    tileX, tileY = Render.tacticalTileAt(app, 450, 300)
    expect(tileX == 4 and tileY == 7, "g3d tactical mouse projection should follow camera right axis")
    tileX, tileY = Render.tacticalTileAt(app, 350, 300)
    expect(tileX == 2 and tileY == 5, "g3d tactical mouse projection should follow camera left axis")
    local oldTargetX = app.worldView.tacticalCamera.targetX
    local oldTargetY = app.worldView.tacticalCamera.targetY
    local dragDx, dragDy = Render.tacticalDragWorldDelta(app, 400, 300, 450, 300)
    expect(dragDx < 0 and dragDy < 0, "tactical drag delta should move camera opposite the pointer")
    Render.panTacticalCamera(app, dragDx, dragDy)
    expect(app.tacticalCameraUserMoved and app.tacticalCameraCenterX < oldTargetX and app.tacticalCameraCenterY < oldTargetY, "tactical drag should pan the camera center")
    expect(app.worldView.tacticalCamera.targetX == app.tacticalCameraCenterX and app.worldView.originX == app.tacticalCameraCenterX, "tactical drag should keep projection metadata in sync")
    Render.setTacticalCameraCenter(app, -999, -999)
    expect(app.tacticalCameraCenterX == runtime.originX + 1.5 and app.tacticalCameraCenterY == runtime.originY + 1.5, "tactical camera pan should clamp to board bounds")
    app.worldView.tacticalCamera = nil
    local duelist = runtime.state:unit("duelist")
    local selectAction = runtime:actionAtTile(duelist.x, duelist.y)
    expect(selectAction.kind == "select" and selectAction.enabled, "tactical click action should select squad units")
    local moveAction = runtime:actionAtTile(2, 4)
    expect(moveAction.kind == "move" and moveAction.enabled and moveAction.detail == "1 AP", "tactical click action should preview reachable moves")
    local actionBar = runtime:actionBar({ x = 2, y = 4 })
    expect(#actionBar == 15 and actionBar[1].label == "Move" and actionBar[1].key == "LMB" and actionBar[2].key == "WASD", "tactical action bar should expose contextual mouse controls")
    local expectedVerbs = {
        { id = "warden", verbs = { "line_guard", "brace", "shove" } },
        { id = "duelist", verbs = { "red_line", "dash_strike", "position_swap" } },
        { id = "apothecary", verbs = { "field_triage", "stabilize", "smoke_binder" } },
        { id = "thief", verbs = { "ghost_route", "courier_cut" } },
        { id = "arcanist", verbs = { "seal_reader", "line_bender", "intent_breaker" } },
        { id = "lamplighter", verbs = { "beacon_runner", "cone_keeper", "ash_lamp" } },
    }
    for _, entry in ipairs(expectedVerbs) do
        runtime.selectedUnitId = entry.id
        local bar = runtime:actionBar()
        for index, verb in ipairs(entry.verbs) do
            local action = bar[4 + index]
            local contextSensitive = entry.id == "warden" or entry.id == "duelist" or entry.id == "apothecary" or entry.id == "thief" or entry.id == "arcanist" or entry.id == "lamplighter"
            local enabledOk = action and (action.enabled or contextSensitive)
            expect(action and action.id == "class:" .. verb and action.key == tostring(index) and enabledOk, entry.id .. " class verb should be callable from input bar")
            if not contextSensitive then
                runtime:handleKey(tostring(index))
                expect(runtime.status == entry.id .. " ready " .. verb, entry.id .. " class verb key should activate")
            end
        end
    end
    runtime.selectedUnitId = "warden"
    local enemy = firstEnemy(runtime)
    enemy.x = 2
    enemy.y = 4
    runtime.state:tileAt(2, 4).coverEdges = { east = "half" }
    TacticalRuntime.refreshOverlays(runtime)
    local attackAction = runtime:actionAtTile(2, 4)
    expect(attackAction.kind == "attack" and attackAction.enabled and attackAction.detail:find("dmg2 flank", 1, true), "tactical click action should preview in-range flanking attacks")
    expect(runtime:handleMouseTile(2, 4, 1), "left click should attack in-range enemy")
    expect(runtime.state:unit(enemy.id).hp == 2 and runtime.state:unit("warden").ap == 2 and runtime.status == "warden hit " .. enemy.id .. " for 2", "left click attack should spend AP and apply flanking damage")
    tileX, tileY = 1, 3
    expect(runtime:handleMouseTile(tileX, tileY, 1), "left click should handle reachable board tile")
    expect(runtime.state:unit("warden").x == 1 and runtime.state:unit("warden").y == 3 and runtime.state:unit("warden").ap == 1, "left click should move selected unit to reachable tile")
    expect(runtime:handleMouseTile(duelist.x, duelist.y, 1), "left click should select player unit")
    expect(runtime.selectedUnitId == "duelist", "left click should select clicked squad unit")
    expect(runtime:handleMouseTile(3, 4, 2), "right click should place cursor")
    expect(runtime.cursor.x == 3 and runtime.cursor.y == 4, "right click should move cursor without action")
    expect(Render.adjustTacticalZoom(app, 3) > 1, "wheel up should zoom in")
    expect(Render.adjustTacticalZoom(app, -20) == 0.65, "wheel down should clamp zoom out")
end

tests[#tests + 1] = function()
    local function runWarden()
        local runtime = TacticalRuntime.new(makeTacticalSim(9010))
        runtime.selectedUnitId = "warden"
        runtime.state.units.warden.ap = 3
        runtime.state.units.warden.maxAp = 3
        runtime.cursor.x = 4
        runtime.cursor.y = 4
        local lineAction = runtime:actionBar()[5]
        expect(lineAction.classVerb == "line_guard" and #lineAction.preview.affectedTiles == 3, "Warden line_guard should preview guarded line")
        expect(runtime:handleKey("1"), "Warden line_guard should activate from input bar")
        expect(runtime.state.threatZones[1].label == "line_guard" and runtime.state.threatZones[1].triggerPhase == "enemy" and runtime.state:unit("warden").ap == 2, "Warden line_guard should spend AP and create deterministic line guard")
        expect(runtime:handleKey("2"), "Warden brace should activate from input bar")
        expect(runtime.state:hasStatus("warden", "braced") and runtime.state:unit("warden").ap == 1, "Warden brace should spend AP and apply braced")
        local enemy = firstEnemy(runtime)
        runtime.state:unit("lamplighter").alive = false
        enemy.x = 2
        enemy.y = 4
        runtime.cursor.x = 2
        runtime.cursor.y = 4
        local shoveAction = runtime:actionBar()[7]
        expect(shoveAction.classVerb == "shove" and shoveAction.preview.pushedPath[1].x == 3, "Warden shove should preview pushed path")
        expect(runtime:handleKey("3"), "Warden shove should activate from input bar")
        expect(runtime.state:unit(enemy.id).x == 3 and runtime.state:unit(enemy.id).y == 4 and runtime.state:unit("warden").ap == 0, "Warden shove should spend AP and push cursor target")
        return runtime.state
    end
    local first = runWarden()
    local second = runWarden()
    expect(Serialize.encode(first:snapshot()) == Serialize.encode(second:snapshot()), "Warden line_guard brace shove sequence should replay deterministically")
end

tests[#tests + 1] = function()
    local function runDuelist()
        local state = TacticsState.new({
            defaultAp = 4,
            board = { width = 5, height = 3 },
            units = {
                { id = "duelist", side = "player", class = "duelist", x = 1, y = 2, hp = 6, ap = 4, maxAp = 4, visionRadius = 8 },
                { id = "bailiff", side = "enemy", x = 5, y = 2, hp = 6, ap = 1 },
            },
            objectives = {
                { id = "dummy", x = 1, y = 1, integrity = 3, maxIntegrity = 3, evacuateAt = { x = 5, y = 3 } },
            },
        })
        local runtime = { state = state, selectedUnitId = "duelist", cursor = { x = 3, y = 2 }, turn = 1, lastSeenEnemies = {} }
        TacticalRuntime.refreshOverlays(runtime)
        local redLine = TacticalRuntime.actionBar(runtime)[5]
        expect(redLine.classVerb == "red_line" and redLine.enabled and redLine.preview.apCost == 1 and #redLine.preview.dashPath == 2, "Duelist red_line should preview dash lane")
        expect(TacticalRuntime.handleKey(runtime, "1"), "Duelist red_line should activate from input bar")
        expect(state:unit("duelist").x == 3 and state:unit("duelist").ap == 3, "Duelist red_line should spend AP and dash to cursor")
        runtime.cursor.x = 5
        runtime.cursor.y = 2
        local dashStrike = TacticalRuntime.actionBar(runtime)[6]
        expect(dashStrike.classVerb == "dash_strike" and dashStrike.enabled and dashStrike.preview.apCost == 2 and dashStrike.preview.damage == 2 and #dashStrike.preview.dashPath == 1, "Duelist dash_strike should preview dash plus deterministic damage")
        expect(TacticalRuntime.handleKey(runtime, "2"), "Duelist dash_strike should activate from input bar")
        expect(state:unit("duelist").x == 4 and state:unit("bailiff").hp == 4 and state:unit("duelist").ap == 1, "Duelist dash_strike should dash, strike, and spend AP")
        local swap = TacticalRuntime.actionBar(runtime)[7]
        expect(swap.classVerb == "position_swap" and swap.enabled and swap.preview.apCost == 1 and swap.preview.swap.target == "bailiff", "Duelist position_swap should preview adjacent exchange")
        expect(TacticalRuntime.handleKey(runtime, "3"), "Duelist position_swap should activate from input bar")
        expect(state:unit("duelist").x == 5 and state:unit("bailiff").x == 4 and state:unit("duelist").ap == 0, "Duelist position_swap should exchange positions and spend AP")
        return state
    end
    local first = runDuelist()
    local second = runDuelist()
    expect(Serialize.encode(first:snapshot()) == Serialize.encode(second:snapshot()), "Duelist red_line dash_strike position_swap sequence should replay deterministically")
end

tests[#tests + 1] = function()
    local function runApothecary()
        local state = TacticsState.new({
            defaultAp = 4,
            board = { width = 5, height = 3 },
            units = {
                { id = "mender", side = "player", class = "mender", x = 1, y = 2, hp = 4, ap = 4, maxAp = 4, visionRadius = 8 },
                { id = "ally", side = "player", x = 2, y = 2, hp = 2, maxHp = 5, ap = 0 },
                { id = "bailiff", side = "enemy", x = 5, y = 2, hp = 6, ap = 1 },
            },
            objectives = {
                { id = "patient", x = 1, y = 1, integrity = 1, maxIntegrity = 3, evacuateAt = { x = 5, y = 3 } },
            },
        })
        local runtime = { state = state, selectedUnitId = "mender", cursor = { x = 2, y = 2 }, turn = 1, lastSeenEnemies = {} }
        TacticalRuntime.refreshOverlays(runtime)
        local triage = TacticalRuntime.actionBar(runtime)[5]
        expect(triage.classVerb == "field_triage" and triage.enabled and triage.preview.apCost == 1 and triage.preview.healing.hpAfter == 4, "Apothecary field_triage should preview ally healing")
        expect(TacticalRuntime.handleKey(runtime, "1"), "Apothecary field_triage should activate from input bar")
        expect(state:unit("ally").hp == 4 and state:hasStatus("ally", "stabilized") and state:unit("mender").ap == 3, "Apothecary field_triage should heal, stabilize, and spend AP")
        runtime.cursor.x = 1
        runtime.cursor.y = 1
        local stabilize = TacticalRuntime.actionBar(runtime)[6]
        expect(stabilize.classVerb == "stabilize" and stabilize.enabled and stabilize.preview.objectiveRepair.integrityAfter == 2, "Apothecary stabilize should preview objective repair")
        expect(TacticalRuntime.handleKey(runtime, "2"), "Apothecary stabilize should activate from input bar")
        expect(state:objective("patient").integrity == 2 and state:unit("mender").ap == 2, "Apothecary stabilize should repair objective and spend AP")
        runtime.cursor.x = 3
        runtime.cursor.y = 2
        local smoke = TacticalRuntime.actionBar(runtime)[7]
        expect(smoke.classVerb == "smoke_binder" and smoke.enabled and smoke.preview.apCost == 1 and #smoke.preview.affectedTiles == 5 and #smoke.preview.obscurants == 5, "Apothecary smoke_binder should preview area smoke")
        expect(TacticalRuntime.handleKey(runtime, "3"), "Apothecary smoke_binder should activate from input bar")
        local los = state:lineOfSight(1, 2, 5, 2)
        expect(los.visible and los.obscured and state:tileAt(3, 2).hazard.kind == "smoke" and state:unit("mender").ap == 1, "Apothecary smoke_binder should place LoS-modifying smoke and spend AP once")
        return state
    end
    local first = runApothecary()
    local second = runApothecary()
    expect(Serialize.encode(first:snapshot()) == Serialize.encode(second:snapshot()), "Apothecary field_triage stabilize smoke_binder sequence should replay deterministically")
end

tests[#tests + 1] = function()
    local function runThief()
        local state = TacticsState.new({
            defaultAp = 4,
            board = { width = 5, height = 3 },
            units = {
                { id = "harrier", side = "player", class = "harrier", x = 1, y = 2, hp = 4, ap = 4, maxAp = 4, visionRadius = 8 },
                { id = "watcher", side = "enemy", x = 5, y = 1, hp = 4, ap = 1, visionRadius = 8 },
            },
            cargo = {
                { id = "ledger", kind = "ledger", x = 3, y = 2, integrity = 1 },
            },
            objectives = {
                { id = "ledger_extract", kind = "extract_ledger", x = 5, y = 2, integrity = 1, evacuateAt = { x = 5, y = 2 } },
            },
        })
        local runtime = { state = state, selectedUnitId = "harrier", cursor = { x = 3, y = 2 }, turn = 1, lastSeenEnemies = {} }
        TacticalRuntime.refreshOverlays(runtime)
        expect(state:fogGrid("enemy").units.harrier == true, "enemy fog should see unstealthed Thief unit on visible tile")
        local ghost = TacticalRuntime.actionBar(runtime)[5]
        expect(ghost.classVerb == "ghost_route" and ghost.enabled and ghost.preview.apCost == 1 and ghost.preview.status.kind == "ghosted", "Thief ghost_route should preview stealth lane")
        expect(TacticalRuntime.handleKey(runtime, "1"), "Thief ghost_route should activate from input bar")
        local enemyFog = state:fogGrid("enemy")
        expect(state:unit("harrier").x == 3 and state:hasStatus("harrier", "ghosted") and state:unit("harrier").ap == 3, "Thief ghost_route should move, stealth, and spend AP once")
        expect(enemyFog.visible["3:2"] and enemyFog.units.harrier == false and enemyFog.hiddenUnits.harrier == true, "ghost_route should hide Thief unit from enemy fog while tile stays visible")
        local pickup = TacticalRuntime.actionBar(runtime)[6]
        expect(pickup.classVerb == "courier_cut" and pickup.enabled and pickup.preview.cargo.id == "ledger", "Thief courier_cut should preview cargo pickup")
        expect(TacticalRuntime.handleKey(runtime, "2"), "Thief courier_cut should pick up cargo")
        expect(state:unit("harrier").carryingCargo == "ledger" and state:cargoItem("ledger").carriedBy == "harrier" and state:unit("harrier").ap == 2, "Thief courier_cut should carry cargo and spend AP")
        runtime.cursor.x = 5
        runtime.cursor.y = 2
        expect(TacticalRuntime.handleKey(runtime, "1"), "Thief ghost_route should move carried cargo along stealth lane")
        expect(state:unit("harrier").x == 5 and state:cargoItem("ledger").x == 5 and state:unit("harrier").ap == 1, "Thief ghost_route should move carried cargo to extraction")
        local extract = TacticalRuntime.actionBar(runtime)[6]
        expect(extract.classVerb == "courier_cut" and extract.enabled and extract.preview.objectiveExtract.id == "ledger_extract", "Thief courier_cut should preview cargo extraction")
        expect(TacticalRuntime.handleKey(runtime, "2"), "Thief courier_cut should extract carried cargo")
        expect(state:cargoItem("ledger").extracted and state:unit("harrier").carryingCargo == nil and state:objectiveStatus("ledger_extract") == "complete" and state:unit("harrier").ap == 0, "Thief courier_cut should extract cargo, complete objective, and spend AP")
        return state
    end
    local first = runThief()
    local second = runThief()
    expect(Serialize.encode(first:snapshot()) == Serialize.encode(second:snapshot()), "Thief ghost_route courier_cut sequence should replay deterministically")
end

tests[#tests + 1] = function()
    local function runArcanist()
        local state = TacticsState.new({
            defaultAp = 3,
            board = {
                width = 5,
                height = 3,
                tiles = {
                    ["3:2"] = { kind = "seal_wall", blocker = true, losBlocker = true, height = 1, revealed = false, revealClasses = { "arcanist" }, weakPoint = "seal_glyph" },
                },
            },
            units = {
                { id = "arcanist", side = "player", class = "arcanist", x = 1, y = 2, hp = 4, ap = 3, maxAp = 3, visionRadius = 8 },
                { id = "redactor", side = "enemy", x = 5, y = 2, hp = 4, ap = 1, visionRadius = 8 },
            },
            objectives = {
                { id = "dummy", x = 1, y = 1, integrity = 3, maxIntegrity = 3, evacuateAt = { x = 5, y = 3 } },
            },
        })
        state:declareIntent("redactor", {
            mode = "hiddenFootprint",
            category = "redacted",
            targetTiles = { { x = 1, y = 2 } },
            damage = 2,
            revealClasses = { "arcanist" },
        })
        local runtime = { state = state, selectedUnitId = "arcanist", cursor = { x = 1, y = 1 }, turn = 1, lastSeenEnemies = {} }
        TacticalRuntime.refreshOverlays(runtime)
        local seal = TacticalRuntime.actionBar(runtime)[5]
        expect(seal.classVerb == "seal_reader" and seal.enabled and seal.preview.reveal.tiles[1].weakPoint == "seal_glyph", "Arcanist seal_reader should preview class-gated reveals")
        expect(TacticalRuntime.handleKey(runtime, "1"), "Arcanist seal_reader should activate from input bar")
        expect(state:tileAt(3, 2).weakPointRevealed and state:intentPreview("redactor").revealed and state:unit("arcanist").ap == 2, "Arcanist seal_reader should reveal seal and intent")
        runtime.cursor.x = 3
        runtime.cursor.y = 2
        expect(not state:lineOfSight(1, 2, 5, 2).visible, "sealed wall should block LoS before line_bender")
        local bend = TacticalRuntime.actionBar(runtime)[6]
        expect(bend.classVerb == "line_bender" and bend.enabled and bend.preview.hazardChain[1].conversion == "bend_los", "Arcanist line_bender should preview LoS bend conversion")
        expect(TacticalRuntime.handleKey(runtime, "2"), "Arcanist line_bender should activate from input bar")
        expect(state:tileAt(3, 2).losBent and state:tileAt(3, 2).blocker and not state:tileAt(3, 2).losBlocker and state:lineOfSight(1, 2, 5, 2).visible and state:unit("arcanist").ap == 1, "Arcanist line_bender should bend LoS without opening movement")
        runtime.cursor.x = 5
        runtime.cursor.y = 2
        local breaker = TacticalRuntime.actionBar(runtime)[7]
        expect(breaker.classVerb == "intent_breaker" and breaker.enabled and breaker.preview.intentInterrupt.target == "redactor", "Arcanist intent_breaker should preview source interrupt")
        expect(TacticalRuntime.handleKey(runtime, "3"), "Arcanist intent_breaker should activate from input bar")
        expect(state:intentPreview("redactor") == nil and state:unit("arcanist").ap == 0, "Arcanist intent_breaker should spend AP and prevent intent")
        return state
    end
    local first = runArcanist()
    local second = runArcanist()
    expect(Serialize.encode(first:snapshot()) == Serialize.encode(second:snapshot()), "Arcanist seal_reader line_bender intent_breaker sequence should replay deterministically")
end

tests[#tests + 1] = function()
    local function runLamplighter()
        local state = TacticsState.new({
            defaultAp = 3,
            board = {
                width = 5,
                height = 3,
                tiles = {
                    ["2:1"] = { kind = "lantern_hook", revealed = false, revealClasses = { "lamplighter" }, weakPoint = "beacon_hook" },
                },
            },
            units = {
                { id = "lamplighter", side = "player", class = "lamplighter", x = 1, y = 2, hp = 4, ap = 3, maxAp = 3, visionRadius = 8 },
                { id = "hound", side = "enemy", x = 4, y = 2, hp = 4, ap = 1, visionRadius = 8 },
            },
            objectives = {
                { id = "dummy", x = 1, y = 1, integrity = 3, maxIntegrity = 3, evacuateAt = { x = 5, y = 3 } },
            },
        })
        state:declareIntent("hound", {
            mode = "hiddenFootprint",
            category = "attack",
            targetTiles = { { x = 1, y = 2 } },
            damage = 3,
            revealClasses = { "lamplighter" },
        })
        local runtime = { state = state, selectedUnitId = "lamplighter", cursor = { x = 2, y = 1 }, turn = 1, lastSeenEnemies = {} }
        TacticalRuntime.refreshOverlays(runtime)
        local beacon = TacticalRuntime.actionBar(runtime)[5]
        expect(beacon.classVerb == "beacon_runner" and beacon.enabled and beacon.preview.reveal.tiles[1].weakPoint == "beacon_hook", "Lamplighter beacon_runner should preview beacon reveal")
        expect(TacticalRuntime.handleKey(runtime, "1"), "Lamplighter beacon_runner should activate from input bar")
        expect(state:tileAt(2, 1).weakPointRevealed and state:intentPreview("hound").revealed and state:unit("lamplighter").ap == 2, "Lamplighter beacon_runner should reveal route data and spend AP")
        runtime.cursor.x = 5
        runtime.cursor.y = 2
        local cone = TacticalRuntime.actionBar(runtime)[6]
        expect(cone.classVerb == "cone_keeper" and cone.enabled and cone.preview.overwatch.reaction == "mark" and #cone.preview.affectedTiles > 4, "Lamplighter cone_keeper should preview upgraded overwatch cone")
        expect(TacticalRuntime.handleKey(runtime, "2"), "Lamplighter cone_keeper should activate from input bar")
        expect(state.threatZones[1].label == "cone_keeper" and state.threatZones[1].reaction.kind == "mark" and state:unit("lamplighter").ap == 1, "Lamplighter cone_keeper should spend AP and create mark overwatch")
        runtime.cursor.x = 4
        runtime.cursor.y = 2
        local ash = TacticalRuntime.actionBar(runtime)[7]
        expect(ash.classVerb == "ash_lamp" and ash.enabled and ash.preview.intentReduction.damageAfter == 2, "Lamplighter ash_lamp should preview intent damage reduction")
        expect(TacticalRuntime.handleKey(runtime, "3"), "Lamplighter ash_lamp should activate from input bar")
        expect(state:intentPreview("hound", { reveal = true }).damage == 2 and state:unit("lamplighter").ap == 0, "Lamplighter ash_lamp should reduce enemy intent and spend AP")
        state:startTurn("enemy")
        state:apply(TacticsState.commands.move("hound", "north"))
        expect(state:hasStatus("hound", "marked") and state.lastOverwatchTrigger.reaction == "mark", "Lamplighter cone_keeper should mark enemy movement through overwatch")
        return state
    end
    local first = runLamplighter()
    local second = runLamplighter()
    expect(Serialize.encode(first:snapshot()) == Serialize.encode(second:snapshot()), "Lamplighter beacon_runner cone_keeper ash_lamp sequence should replay deterministically")
end

tests[#tests + 1] = function()
    local diagonal = Render.tacticalGridArrowSegments({ x = 2, y = 2 }, { x = 5, y = 4 }, 0, 0)
    expect(#diagonal == 2, "diagonal tactical intent should route as two grid segments")
    for _, segment in ipairs(diagonal) do
        expect(segment.x1 == segment.x2 or segment.y1 == segment.y2, "tactical intent arrow segment should not be diagonal")
    end
    expect(diagonal[1].y1 == diagonal[1].y2 and diagonal[2].x1 == diagonal[2].x2, "dominant x tactical intent should turn once on the grid")
    local straight = Render.tacticalGridArrowSegments({ x = 2, y = 2 }, { x = 2, y = 6 }, 0, 0)
    expect(#straight == 1 and straight[1].x1 == straight[1].x2 and straight[1].uy == 1, "straight tactical intent should stay one grid segment")
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
    local flanked = TacticsState.new({
        board = { width = 3, height = 3, tiles = { ["2:2"] = { coverEdges = { west = "half" } } } },
        units = {
            { id = "warden", side = "player", x = 3, y = 2, hp = 6 },
            { id = "target", side = "enemy", x = 2, y = 2, hp = 6 },
        },
    })
    local preview = TacticsResolution.actionPreview(flanked, TacticsState.commands.attack("warden", "target", 2, 0))
    expect(preview.flanked and preview.damage == 3 and preview.flankingBonus == 1 and preview.effectiveCover == "none", "flanking preview should expose default damage bonus")
    flanked:apply(TacticsState.commands.attack("warden", "target", 2, 0))
    expect(flanked:unit("target").hp == 3, "flanking attack should apply deterministic damage bonus")

    local protected = TacticsState.new({
        board = { width = 3, height = 3, tiles = { ["2:2"] = { coverEdges = { west = "half" } } } },
        units = {
            { id = "warden", side = "player", x = 1, y = 2, hp = 6 },
            { id = "target", side = "enemy", x = 2, y = 2, hp = 6 },
        },
    })
    preview = TacticsResolution.actionPreview(protected, TacticsState.commands.attack("warden", "target", 2, 0))
    expect(not preview.flanked and preview.damage == 1 and preview.damageReductionApplied == 1, "protected cover edge should reduce attack damage")

    local invalidationOnly = TacticsState.new({
        rules = { flanking = { mode = "removeCover" } },
        board = { width = 3, height = 3, tiles = { ["2:2"] = { coverEdges = { west = "half" } } } },
        units = {
            { id = "warden", side = "player", x = 3, y = 2, hp = 6 },
            { id = "target", side = "enemy", x = 2, y = 2, hp = 6 },
        },
    })
    preview = TacticsResolution.actionPreview(invalidationOnly, TacticsState.commands.attack("warden", "target", 2, 0))
    expect(preview.flanked and preview.damage == 2 and preview.flankingBonus == 0 and preview.flankingRule.mode == "removeCover", "flanking mode should support cover invalidation without bonus damage")
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
            width = 5,
            height = 3,
            tiles = {
                ["3:2"] = { losBlocker = true, height = 1 },
            },
        },
        units = {
            { id = "scout", side = "player", x = 1, y = 2 },
            { id = "spotter", side = "player", x = 5, y = 3, visionRadius = 1 },
            { id = "warden", side = "enemy", x = 5, y = 1, visionRadius = 2 },
        },
    })
    expect(state:unit("scout").visionRadius == 8 and state:unit("spotter").visionRadius == 1, "units should normalize vision radius")
    local spotterVisible = state:computeVisibleTiles("spotter")
    expect(spotterVisible["5:3"] and spotterVisible["5:2"] and spotterVisible["4:3"], "unit visibility should include tiles within radius")
    expect(not spotterVisible["4:2"] and not spotterVisible["3:3"], "unit visibility should exclude tiles beyond radius")
    local scoutVisible = TacticsLoS.computeVisibleTiles(state, state:unit("scout"))
    expect(scoutVisible["3:2"] and not scoutVisible["4:2"], "unit visibility should respect LoS blockers")
    expect(not spotterVisible["5:1"] and not spotterVisible["3:3"], "vision computation should stay within deterministic radius")
    local fog = state:fogGrid("player")
    expect(fog.width == 5 and fog.height == 3 and fog.visible["1:2"] and fog.visible["5:3"], "fog grid should aggregate squad visibility")
    expect(fog.fog["4:2"] and fog.tiles["4:2"].fog and not fog.fog["5:2"] and fog.tiles["5:2"].visible, "fog grid should mark unseen and visible tiles")
    local enemyFog = TacticsLoS.fogGrid(state, "enemy")
    expect(enemyFog.visible["5:1"] and not enemyFog.visible["1:2"], "fog grid should be side scoped")
    expect(TacticsState.fromSnapshot(state:snapshot()):unit("spotter").visionRadius == 1, "vision radius should snapshot deterministically")
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
    local sightline = high:sightlineProfile(1, 1, 4, 1)
    expect(sightline.vantage == "high_ground" and sightline.effectiveCover == "none", "sightline profile should summarize high ground and effective cover")
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
        overwatch = { { x = 4, y = 1, label = "shoot" } },
        hazards = { { x = 1, y = 4, label = "falling_shelf" } },
    }
    local entries, counts = Render.tacticalOverlayEntries(state, overlays)
    expect(counts.movement == 2, "tactical overlays should include movement range tiles")
    expect(counts.los == 1, "tactical overlays should include LoS tiles")
    expect(counts.cover == 1, "tactical overlays should include cover tiles")
    expect(counts.flank == 1, "tactical overlays should include flank tiles")
    expect(counts.intent == 1, "tactical overlays should include intent tiles")
    expect(counts.overwatch == 1, "tactical overlays should include overwatch tiles")
    expect(counts.hazard == 2, "tactical overlays should include board and explicit hazard tiles")
    expect(#entries == 9, "tactical overlay entry count should match all required overlay classes")
    local summary = Render.tacticalOverlaySummary(state, overlays)
    expect(summary.total == 9 and summary.intent == 1 and summary.overwatch == 1, "tactical overlay summary should expose render-smoke counts")
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
        defaultAp = 2,
        board = { width = 6, height = 5 },
        units = {
            { id = "warden", side = "player", x = 2, y = 3, ap = 2 },
            { id = "runner", side = "enemy", x = 4, y = 2, hp = 3, ap = 2 },
            { id = "bailiff", side = "enemy", x = 5, y = 4, hp = 3, ap = 2 },
        },
    })
    state:apply(TacticsState.commands.overwatchCone("warden", "east", 3, 1, { kind = "shoot", damage = 2 }, 1))
    local zone = state.threatZones[1]
    expect(state:unit("warden").ap == 1 and zone.kind == "overwatch" and zone.origin.x == 2 and zone.facing == "east" and zone.range == 3 and zone.arc == 1, "overwatch cone should spend AP and store cone metadata")
    state:apply(TacticsState.commands.move("runner", "south"))
    expect(state:unit("runner").hp == 3 and #state.threatZones == 1, "overwatch cone should not trigger outside enemy phase")
    state:startTurn("enemy")
    state:apply(TacticsState.commands.move("bailiff", "north"))
    expect(state:unit("bailiff").hp == 1 and state.lastOverwatchTrigger.reaction == "shoot", "overwatch cone should shoot first enemy entering during enemy phase")
    local pulse = Render.tacticalOverwatchAnimation(state.lastOverwatchTrigger, 0.25)
    expect(pulse.x == state.lastOverwatchTrigger.x and pulse.y == state.lastOverwatchTrigger.y and pulse.reaction == "shoot", "overwatch trigger animation should retain trigger tile and reaction")
    expect(pulse.alpha > 0 and pulse.alpha <= 1 and pulse.scale >= 1, "overwatch trigger animation should expose bounded pulse values")
    expect(#state.threatZones == 0, "overwatch cone should expire after first trigger")

    local ordered = TacticsState.new({
        defaultAp = 1,
        board = { width = 3, height = 1 },
        units = {
            { id = "warden", side = "player", x = 1, y = 1, hp = 5, ap = 1 },
            { id = "hound", side = "enemy", x = 3, y = 1, hp = 1, ap = 1 },
        },
    })
    ordered:apply(TacticsState.commands.overwatch("warden", { { x = 2, y = 1 } }, 1, 1, 0))
    ordered:declareIntent("hound", { mode = "exact", category = "attack", targetTiles = { { x = 1, y = 1 } }, damage = 2 })
    ordered:startTurn("enemy")
    ordered:apply(TacticsState.commands.move("hound", "west"))
    local resolved = TacticsIntent.resolve(ordered, "hound")
    expect(not ordered:unit("hound").alive and ordered.lastOverwatchTrigger.target == "hound", "overwatch should trigger before enemy intent resolution")
    expect(resolved.triggered == false and resolved.blocked == "source_inactive" and ordered:unit("warden").hp == 5, "dead overwatched enemy should not resolve its intent")

    local stun = TacticsState.new({
        board = { width = 4, height = 3 },
        units = {
            { id = "lamp", side = "player", x = 1, y = 2 },
            { id = "hound", side = "enemy", x = 3, y = 1, hp = 3 },
        },
    })
    stun:apply(TacticsState.commands.overwatchCone("lamp", "east", 3, 1, { kind = "stun", turns = 1 }, 0))
    stun:startTurn("enemy")
    stun:apply(TacticsState.commands.move("hound", "south"))
    expect(stun:hasStatus("hound", "stunned") and stun.lastOverwatchTrigger.reaction == "stun", "overwatch cone should support stun reaction")

    local mark = TacticsState.new({
        board = { width = 4, height = 3 },
        units = {
            { id = "lamp", side = "player", x = 1, y = 2 },
            { id = "hound", side = "enemy", x = 3, y = 1, hp = 3 },
        },
    })
    mark:apply(TacticsState.commands.overwatchCone("lamp", "east", 3, 1, { kind = "mark", turns = 2, amount = 2 }, 0))
    mark:startTurn("enemy")
    mark:apply(TacticsState.commands.move("hound", "south"))
    expect(mark:status("hound", "marked").amount == 2 and mark.lastOverwatchTrigger.reaction == "mark", "overwatch cone should support mark reaction")
end

tests[#tests + 1] = function()
    local state = TacticsState.new({
        defaultAp = 2,
        board = { width = 6, height = 5 },
        units = {
            { id = "warden", side = "player", x = 2, y = 3, ap = 2, visionRadius = 8 },
            { id = "runner", side = "enemy", x = 5, y = 3, hp = 3 },
        },
    })
    local runtime = { state = state, selectedUnitId = "warden", cursor = { x = 2, y = 3 }, turn = 1 }
    state:apply(TacticsState.commands.overwatchCone("warden", "east", 3, 1, { kind = "shoot", damage = 2 }, 0))
    TacticalRuntime.refreshOverlays(runtime)
    expect(#runtime.overlays.overwatch == 7, "runtime overlays should expose committed overwatch cone tiles")
    local preview = TacticalRuntime.setOverwatchPreview(runtime, "north", 2, 1)
    expect(#preview.tiles == 4, "runtime should preview cone tiles before declaration")
    expect(#runtime.overlays.overwatch == 11, "runtime overlays should merge committed and preview overwatch tiles")
    TacticalRuntime.clearOverwatchPreview(runtime)
    expect(runtime.overwatchSelection == nil and #runtime.overlays.overwatch == 7, "runtime should clear overwatch preview tiles")
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
    expect(#ArchivedTactics.zoneOrder == 2, "future zones should be archived outside live catalogs")
    expect(ZoneCatalog.zone("salt_cistern") == nil and ZoneCatalog.zone("ember_warrens") == nil, "future zones should not be live")
    for _, zoneId in ipairs(ArchivedTactics.zoneOrder) do
        local archived = ArchivedTactics.zoneCatalog[zoneId]
        expect(archived and #archived.mechanics == 12 and #archived.objects == 8, "archived future zone should preserve mechanic/object ids: " .. zoneId)
        expect(ArchivedTactics.runMapZones[zoneId] and ArchivedTactics.procgen[zoneId], "archived future zone should preserve run/procgen entries: " .. zoneId)
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
    for _, zoneId in ipairs({ "buried_archive" }) do
        local facts = ZoneCatalog.rotationFacts(zoneId)
        expect(#facts >= 4, zoneId .. " should define at least 4 rotation facts")
        for _, fact in ipairs(facts) do
            expect(fact.id and fact.fact and fact.planningImpact, zoneId .. " rotation fact should include metadata")
            expect(fact.changesState == false, zoneId .. " rotation fact should not alter logical state")
        end
    end
end

tests[#tests + 1] = function()
    for _, zoneId in ipairs({ "buried_archive" }) do
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
    local expected = { "warden", "duelist", "mender", "harrier", "arcanist", "lamplighter" }
    expect(audit.valid, "starter roster should expose six classes with two loadouts each")
    expect(#ids == 6, "starter roster should define exactly six classes")
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
    expect(#ClassCatalog.starterLoadouts("merchant") == 0 and #ClassCatalog.starterLoadouts("chirurgeon") == 0 and #ClassCatalog.starterLoadouts("exile") == 0, "non-slice classes should not enter starter roster")
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
    expect(#enemies == 16, "Archive should define 16 common enemies")
    local ids = {}
    local intentTypes = {}
    for _, enemy in ipairs(enemies) do
        expect(enemy.id and enemy.name and enemy.boardVerb, "archive common enemy should include id name board verb")
        expect(enemy.exactIntent and enemy.exactIntent.mode == "exact" and enemy.exactIntent.intentType, "archive common enemy should include exact intent type")
        expect(not ids[enemy.id], "archive common enemy ids should be unique")
        expect(not intentTypes[enemy.exactIntent.intentType], "archive common enemy intent types should be unique")
        ids[enemy.id] = true
        intentTypes[enemy.exactIntent.intentType] = true
    end
    expect(EnemyCatalog.auditArchiveCommonIntentTypes().ok, "Archive common enemy intent-type audit should pass")
end

tests[#tests + 1] = function()
    local audit = EnemyCatalog.auditArchetypes()
    expect(audit.ok, "enemy archetype audit should pass")
    for _, archetypeId in ipairs(EnemyCatalog.requiredArchetypes) do
        local archetype = EnemyCatalog.archetype(archetypeId)
        expect(archetype and archetype.intent and archetype.boardVerb and archetype.counterplay and archetype.preview, "enemy archetype should include tactical metadata: " .. archetypeId)
        expect(audit.coverage[archetypeId] and audit.coverage[archetypeId] > 0, "enemy archetype should be represented by a common enemy: " .. archetypeId)
    end
    for _, familyId in ipairs({ "archive" }) do
        for _, enemy in ipairs(EnemyCatalog.common(familyId)) do
            expect(enemy.archetype and EnemyCatalog.archetype(enemy.archetype), "common enemy should reference known archetype: " .. enemy.id)
        end
    end
end

tests[#tests + 1] = function()
    local audit = EnemyCatalog.auditExactBasicIntents()
    expect(audit.ok, "basic enemy exact-intent audit should pass")
    for _, familyId in ipairs({ "archive" }) do
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
    for _, familyId in ipairs({ "archive" }) do
        expect(audit.coverage[familyId] == #EnemyCatalog.elites(familyId), "masked-intent audit should cover all elites in " .. familyId)
        for _, enemy in ipairs(EnemyCatalog.elites(familyId)) do
            local masked = enemy.maskedIntent
            expect(enemy.partialIntent and enemy.partialIntent.mode == "category", "elite should keep category partial intent: " .. enemy.id)
            expect(masked and masked.mode == "hiddenFootprint" and masked.category == enemy.partialIntent.category, "elite should define masked footprint intent: " .. enemy.id)
            expect(masked.intentType and masked.revealRotations and #masked.revealRotations > 0, "elite masked intent should define distinct footprint type and rotation reveal: " .. enemy.id)
            expect(masked.revealClasses[1] == masked.revealGate.class and masked.revealActions[1] == masked.revealGate.action, "elite masked intent should expose class/action gates: " .. enemy.id)
            expect(masked.revealGate and masked.revealGate.weakPoint == enemy.weakPoints[1], "elite masked intent should reveal through weak point: " .. enemy.id)
            expect(masked.counterplay and #masked.counterplay >= 2 and masked.footprintHidden == true, "elite masked intent should include counterplay and hidden footprint: " .. enemy.id)
        end
    end
end

tests[#tests + 1] = function()
    local elites = EnemyCatalog.elites("archive")
    expect(#elites == 4, "Archive should define 4 elites")
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
    expect(alpha.archetype == "terrain-breaker" and alpha.exactIntent and alpha.exactIntent.intentType == "shelf_warden_shelf_shift", "Archive alpha should define terrain-breaker intent")
    expect(alpha.midRunSpawn and alpha.midRunSpawn.turn > 1 and alpha.terrainInteraction and alpha.terrainMutation and alpha.terrainMutation.deterministic, "Archive alpha should define deterministic mid-run terrain spawn")
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
    for _, familyId in ipairs({ "cistern", "warrens" }) do
        local family = ArchivedTactics.enemies[familyId]
        expect(family and #family.common == 10 and #family.elites == 3 and family.alpha, "future enemy family should be archived: " .. familyId)
        expect(EnemyCatalog.common(familyId)[1] == nil and EnemyCatalog.elites(familyId)[1] == nil and EnemyCatalog.alpha(familyId) == nil, "future enemy family should not be live: " .. familyId)
    end
end

tests[#tests + 1] = function()
    local specs = {
        buried_archive = { family = "archive", prefix = "archive_", verbField = "boardVerb", eliteField = "terrainInteraction", required = { "archive_audit_beam", "archive_shelf_shift", "archive_back_face_seal" } },
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
        expect(#EnemyCatalog.common(spec.family) == 16 and #EnemyCatalog.elites(spec.family) == 4, spec.family .. " should expose full enemy family")
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
    expect(#boss.phaseChart == 3 and boss.arenaDiagram.width == 9 and #boss.stagedIntentMasks == 3, "Vault Regent should define phase chart arena and staged masks")
end

tests[#tests + 1] = function()
    for _, bossId in ipairs({ "pearl_choir", "bell_diver", "kiln_vicar", "cinder_prioress" }) do
        local boss = ArchivedTactics.bosses[bossId]
        expect(boss and boss.zone and #boss.phases == 3, "future boss should be archived: " .. bossId)
        expect(BossCatalog.boss(bossId) == nil, "future boss should not be live: " .. bossId)
    end
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
    local audit = BossCatalog.auditVaultRegentShipData()
    local boss = BossCatalog.boss("vault_regent")
    local intent = BossCatalog.bossStageIntent("vault_regent")
    expect(audit.ok, "Vault Regent boss ship data audit should pass")
    expect(intent and intent.mode == "bossStage" and #intent.masks == 6, "Vault Regent should export staged boss intent masks")
    local state = TacticsState.new({
        board = { width = boss.arenaDiagram.width, height = boss.arenaDiagram.height },
        units = {
            { id = "vault_regent", side = "enemy", x = boss.arenaDiagram.boss.x, y = boss.arenaDiagram.boss.y },
        },
    })
    state:apply(TacticsState.commands.intent("vault_regent", intent))
    for _, stage in ipairs(boss.stagedIntentMasks) do
        state:apply(TacticsState.commands.advanceBossIntentMask("vault_regent", { phase = stage.phase, turn = stage.turn }))
        local hidden = state:intentPreview("vault_regent")
        expect(hidden.stage == stage.stage and hidden.mask == stage.mask and hidden.footprintHidden and not hidden.targetTiles, "Vault Regent stage should hide masked footprint: " .. stage.phase)
        local ok = pcall(function()
            state:apply(TacticsState.commands.advanceBossIntentMask("vault_regent", { rotation = (stage.revealRotation + 1) % 4, weakPoint = stage.weakPoint }))
        end)
        expect(not ok, "Vault Regent weak point should not reveal from wrong rotation: " .. stage.phase)
        state:apply(TacticsState.commands.advanceBossIntentMask("vault_regent", { rotation = stage.revealRotation, weakPoint = stage.weakPoint }))
        local revealed = state:intentPreview("vault_regent")
        expect(revealed.revealed and revealed.mask == nil and revealed.stage == stage.stage and revealed.targetTiles[1].x == stage.revealedTiles[1].x, "Vault Regent weak point should reveal from matching rotation: " .. stage.phase)
    end
    local loaded = TacticsState.fromSnapshot(state:snapshot())
    expect(Serialize.encode(loaded:snapshot()) == Serialize.encode(state:snapshot()), "Vault Regent staged mask state should snapshot deterministically")
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
    expect(map.zone == "buried_archive" and report.valid, "future zone request should fall back to live archive graph")
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
    for _, variantId in ipairs({ "archive_entry_audit", "archive_shelf_protection", "archive_proof_extract", "archive_ledger_repair", "archive_sealed_shortcut", "archive_vault_regent_final", "archive_elite_claim" }) do
        expect(variants[variantId], "archive slice map missing board variant " .. variantId)
    end
    expect(map.nodeById.elite_claim.complication.id == "partial_intent_elite" and map.nodeById.boss_gate.bossId == BossCatalog.sliceBossSpec().bossId and map.nodeById.boss_gate.boardVariant == "archive_vault_regent_final", "archive slice map should bind elite complication and boss")
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
    local tacticalSettings = { coverEdgePalette = "colorblind", intentIconScale = 1.6, intentText = true }
    local tacticalEntries = Render.tacticalOverlayEntries(state, { intents = { { x = 3, y = 1, label = "strike" } } }, tacticalSettings)
    local tacticalByKind = {}
    for _, entry in ipairs(tacticalEntries) do
        tacticalByKind[entry.kind] = tacticalByKind[entry.kind] or entry
    end
    expect(tacticalByKind.intent.iconScale == 1.6 and tacticalByKind.intent.text == "strike", "intent accessibility settings should scale icons and duplicate text")
    expect(tacticalByKind.cover.palette == "colorblind" and sameColor(tacticalByKind.cover.color, palette.roles.cover.color), "cover palette setting should select colorblind-safe cover edges")
    local standardCover = Render.tacticalOverlayEntries(state, {}, { coverEdgePalette = "standard" })[1]
    expect(standardCover.palette == "standard" and not sameColor(standardCover.color, palette.roles.cover.color), "cover palette setting should expose standard fallback")
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
    for _, id in ipairs({ "terrain", "cover", "los", "hazards", "destructible_hp", "hidden_info", "vision_sources", "intent_traces" }) do
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
            { id = "warden", side = "player", x = 1, y = 2, ap = 2, visionRadius = 3 },
            { id = "spotter", side = "player", x = 2, y = 1, ap = 2, visionRadius = 3 },
            { id = "bailiff", side = "enemy", x = 4, y = 2, ap = 1 },
        },
        intents = {
            bailiff = { mode = "exact", category = "attack", targetTiles = { { x = 2, y = 2 } }, path = { { x = 3, y = 2 }, { x = 2, y = 2 } }, damage = 1, effect = "crack" },
        },
    })
    local summary = UICatalog.tileInspectorSummary(state, 2, 2, { rotation = 1 })
    expect(summary.terrain.kind == "valve_block" and summary.terrain.material == "salt" and summary.terrain.height == 1, "tile inspector should expose terrain")
    expect(summary.cover[1].direction == "west" and summary.cover[1].cover == "half", "tile inspector should expose cover")
    expect(summary.los.visible and summary.los.from.unit == "warden" and summary.los.effectiveCover == "half", "tile inspector should expose LoS and effective cover from selected unit")
    expect(summary.hazards.kind == "brine" and summary.hazards.active == true, "tile inspector should expose hazards")
    expect(summary.destructibleHp.hp == 4 and summary.destructibleHp.destructible, "tile inspector should expose destructible HP")
    expect(summary.hiddenInfo.hidden and summary.hiddenInfo.currentRotationMark.mark == "rear_valve_label", "tile inspector should expose hidden info without revealing all states")
    expect(#summary.visionSources == 2 and summary.visionSources[1].unit == "warden" and summary.visionSources[2].unit == "spotter", "tile inspector should expose vision sources")
    expect(summary.intentTraces[1].unit == "bailiff" and summary.intentTraces[1].role == "target" and summary.intentTraces[1].category == "attack", "tile inspector should expose current intent traces")
    local lines = table.concat(Render.tacticalTileInspectorLines(summary), "\n")
    expect(lines:find("tags cistern", 1, true) and lines:find("cover west half", 1, true), "render tile inspector lines should show tags and cover edges")
    expect(lines:find("hazard brine active true dmg 1 timer 2", 1, true) and lines:find("terrain HP 4", 1, true), "render tile inspector lines should show hazard timers and terrain HP")
    expect(lines:find("LoS warden visible h-1 below cover half", 1, true), "render tile inspector lines should show elevation-aware LoS cover")
    expect(lines:find("vision warden@1,2 spotter@2,1", 1, true) and lines:find("intent bailiff target attack dmg 1", 1, true), "render tile inspector lines should show vision sources and intent footprints")
    local legendApp = { tactics = { state = state, selectedUnitId = "warden", cursor = { x = 1, y = 1 } }, ui = { tacticalIntentButtons = {} } }
    local legend = Render.tacticalIntentLegendEntries(legendApp)
    expect(#legend == 1 and legend[1].unit == "bailiff" and legend[1].targetTiles[1].x == 2 and legend[1].sourceTile.x == 4, "intent legend should expose declared enemy intent source and targets")
    legendApp.ui.tacticalIntentButtons[1] = { x = 8, y = 8, w = 120, h = 24, intentUnit = legend[1].unit, sourceTile = legend[1].sourceTile, targetTiles = legend[1].targetTiles }
    expect(Input.updateTacticalIntentHover(legendApp, 12, 12), "intent legend hover should activate hitbox")
    expect(legendApp.tacticalIntentHover.unit == "bailiff" and legendApp.tacticalHover.x == 2 and legendApp.tacticalHover.y == 2, "intent legend hover should highlight target tiles")
    expect(legendApp.tacticalInspector and legendApp.tacticalInspector.intentTraces[1].unit == "bailiff", "intent legend hover should refresh tile inspector")
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
    local runtime = TacticalRuntime.new(makeTacticalSim(2842))
    local runtimeSummary = runtime:summary()
    local rows = Render.tacticalSquadHudRows(runtimeSummary, 6)
    local selectedRows = 0
    for _, row in ipairs(rows) do
        if row.selected then
            selectedRows = selectedRows + 1
        end
    end
    expect(#rows == 6 and rows[1].id == "warden" and rows[6].id == "lamplighter", "render HUD rows should expose all six squad portraits")
    expect(rows[1].ap == 3 and rows[1].maxAp == 3 and rows[6].maxAp == 3, "render HUD rows should expose six AP pools")
    expect(selectedRows == 1 and rows[1].selected, "render HUD rows should expose selection state")
    local layoutAudit = Render.tacticalHudLayoutAudit(1920, 1080, 6)
    expect(layoutAudit.ok and layoutAudit.visiblePortraits == 6 and layoutAudit.apPools == 6, "1080p tactical HUD layout should fit six portraits and AP pools")
    expect(layoutAudit.layout.board.x + layoutAudit.layout.board.w < layoutAudit.layout.squad.x and layoutAudit.layout.board.y + layoutAudit.layout.board.h < layoutAudit.layout.action.y, "1080p tactical HUD should not overlap the board view")
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
    local runtime = TacticalRuntime.new(makeTacticalSim(2448))
    runtime:handleKey(Input.gamepadButtonKey("dpright"))
    expect(runtime.cursor.x == 2 and runtime.cursor.y == 4, "controller D-pad should move tactical cursor")
    local axisState = {}
    runtime:handleKey(Input.gamepadAxisKey("lefty", -0.8, axisState))
    expect(runtime.cursor.x == 2 and runtime.cursor.y == 3, "controller left stick should move tactical cursor")
    expect(Input.gamepadAxisKey("lefty", -0.8, axisState) == nil, "controller held axis should debounce repeated tactical cursor input")
    runtime:handleKey(Input.gamepadButtonKey("x"))
    expect(runtime.state:unit("warden").x == 1 and runtime.state:unit("warden").ap == 3 and runtime.message:find("Move", 1, true), "controller inspect should preview without committing")
    runtime:handleKey(Input.gamepadButtonKey("a"))
    expect(runtime.state:unit("warden").x == 2 and runtime.state:unit("warden").y == 3 and runtime.state:unit("warden").ap == 1, "controller A should activate contextual tactical move")
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
    local compass = Render.rotationCompass(1)
    expect(compass.rotation == 1 and compass.degrees == 90 and compass.top == "W" and compass.right == "N", "rotation compass should map world directions at 90 degrees")
    local state = TacticsState.new({
        board = { width = 4, height = 4 },
        units = {
            { id = "warden", side = "player", x = 1, y = 1, ap = 2 },
            { id = "bailiff", side = "enemy", x = 4, y = 4, ap = 1 },
        },
        objectives = {
            { id = "machine", kind = "protect_route_machinery", x = 2, y = 2, integrity = 2, evacuateAt = { x = 1, y = 1 } },
        },
        intents = {
            bailiff = { mode = "exact", category = "attack", targetTiles = { { x = 1, y = 1 } }, damage = 1 },
        },
    })
    local app = {
        tactics = { state = state, selectedUnitId = "warden", cursor = { x = 3, y = 3 } },
        viewRotation = 1,
        previousViewRotation = 0,
        viewTurn = { from = 0, to = 1, t = 0, duration = 0.24 },
        worldView = { centerX = 400, centerY = 300, halfW = 32, halfH = 16, originX = 0, originY = 0, rotation = 1 },
    }
    expect(#Render.tacticalGhostArrowEntries(app) == 0, "ghost arrows should stay hidden during active rotation")
    app.viewTurn = nil
    expect(#Render.tacticalGhostArrowEntries(app) == 0, "ghost arrows should hide outside active rotation")
    app.viewTurn = { from = 1, to = 2, t = 0, duration = 0.24 }
    app.previousViewRotation = nil
    expect(#Render.tacticalGhostArrowEntries(app) == 0, "ghost arrows should not invent a previous rotation")
end

tests[#tests + 1] = function()
    local tutorials = {}
    for _, step in ipairs(UICatalog.tutorials()) do
        tutorials[step.id] = step
        expect(step.teaches and step.board and step.exitCheck, "tutorial step should define teaches board exit check: " .. step.id)
    end
    for _, id in ipairs({ "tactical_onboarding", "movement", "cover_flank", "intent", "forced_movement", "destructible_terrain", "objective_pressure", "redacted_intent", "boss_weak_point" }) do
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
    for _, id in ipairs({ "tactical_onboarding", "movement", "cover_flank", "intent", "push_pull", "destruction", "objectives" }) do
        expect(specs[id] and UICatalog.tutorialBoard(id) == specs[id], "missing tutorial board " .. id)
    end
    local onboarding = specs.tactical_onboarding
    expect(onboarding.singleScreen and onboarding.scripted and onboarding.noTextWalls, "onboarding board should be single-screen scripted and cue-driven")
    expect(onboarding.board.width == 6 and onboarding.board.height == 6 and #onboarding.actions == 6, "onboarding board should be 6x6 with six tutorial actions")
    expect(#onboarding.units == 2 and onboarding.units[1].side == "player" and onboarding.units[1].class == "warden", "onboarding board should teach with one Warden plus one enemy")
    local expectedActions = { "select_unit", "move", "rotate_camera", "declare_overwatch", "end_turn", "react_revealed_intent" }
    for index, actionId in ipairs(expectedActions) do
        local action = onboarding.actions[index]
        local words = 0
        for _ in tostring(action.cue or ""):gmatch("%S+") do
            words = words + 1
        end
        expect(action.id == actionId and action.kind and action.preview, "onboarding action should preserve scripted order: " .. actionId)
        expect(action.cue and not action.body and words <= onboarding.maxCueWords, "onboarding action should use short cue text: " .. actionId)
    end
    local onboardingState = TacticsState.new({
        board = onboarding.board,
        units = onboarding.units,
        intents = onboarding.intents,
    })
    local hidden = onboardingState:intentPreview("bailiff", { rotation = 0 })
    local revealed = onboardingState:intentPreview("bailiff", { rotation = 1 })
    expect(hidden.footprintHidden and hidden.targetTiles == nil and revealed.targetTiles[1].x == 2 and revealed.damage == 2, "onboarding board should script hidden intent reveal by rotation")
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
    expect(#TacticsProcgen.terrainTypes() >= 10 and #TacticsProcgen.generationTechniques() >= 8 and #TacticsProcgen.hazardKinds() == 3, "procgen should expose terrain type, technique, and hazard catalogs")
    expect(#spec.grammar.components.terrainTypes >= 6 and #spec.grammar.components.generationTechniques >= 6, "generated grammar should record used terrain types and techniques")
    expect(state:tileAt(3, spec.grammar.components.rooms[1].y).terrainType == "archive_chasm", "generated grammar should stamp chasm terrain")
    expect(state:tileAt(3, spec.grammar.components.rooms[1].y + spec.grammar.components.rooms[1].height - 1).moveCost == 1, "generated grammar should stamp rough terrain movement cost")
    expect(Serialize.encode(spec) == Serialize.encode(TacticsProcgen.generateBoard(2101)), "board grammar generation should be deterministic per seed")
end

tests[#tests + 1] = function()
    local function reachable(spec, from, to)
        local queue = { from }
        local seen = { [tostring(from.x) .. ":" .. tostring(from.y)] = true }
        local index = 1
        while queue[index] do
            local node = queue[index]
            index = index + 1
            if node.x == to.x and node.y == to.y then
                return true
            end
            for _, offset in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
                local nx, ny = node.x + offset[1], node.y + offset[2]
                local key = tostring(nx) .. ":" .. tostring(ny)
                local tile = spec.board.tiles[key]
                if tile and not seen[key] and tile.blocker ~= true then
                    seen[key] = true
                    queue[#queue + 1] = { x = nx, y = ny }
                end
            end
        end
        return false
    end
    local profiles = { "spires", "sprawl", "open_wilds", "rooms_mines", "mixed_archive" }
    expect(#TacticsProcgen.hybridProfiles() == #profiles, "hybrid procgen should expose five terrain profiles")
    for index, profile in ipairs(profiles) do
        local spec = TacticsProcgen.generateHybridBoard(9100 + index, { profile = profile, width = 24, height = 18 })
        local components = spec.grammar.components
        local spawn = components.spawnPockets[1].tiles[1]
        local objective = spec.objectives[1]
        expect(spec.validation.valid and TacticsProcgen.validateGrammarBoard(spec).valid, "hybrid profile should validate: " .. profile)
        expect(spec.generator.profile == profile and spec.generator.pipeline[1] == "macro_graph", "hybrid profile should record generator pipeline: " .. profile)
        expect(#components.noiseFields > 0, "hybrid profile should record noise fields: " .. profile)
        expect(#components.wfcTiles > 0 and #components.coverFields > 0 and #components.sightBreaks > 0 and #components.hazardLanes > 0, "hybrid profile should record tactical motifs: " .. profile)
        expect(#spec.board.terrainTypes >= 7 and #spec.board.generationTechniques >= 5, "hybrid profile should record varied terrain and techniques: " .. profile)
        expect(reachable(spec, spawn, objective), "hybrid profile should keep spawn objective reachable: " .. profile)
        expect(Serialize.encode(spec) == Serialize.encode(TacticsProcgen.generateHybridBoard(9100 + index, { profile = profile, width = 24, height = 18 })), "hybrid profile should be deterministic: " .. profile)
    end
    local a = Serialize.encode(TacticsProcgen.generateHybridBoard(9191, { profile = "mixed_archive", width = 24, height = 18 }))
    local b = Serialize.encode(TacticsProcgen.generateHybridBoard(9192, { profile = "mixed_archive", width = 24, height = 18 }))
    expect(a ~= b, "hybrid profile should vary by seed")
    local zone = TacticsProcgen.generateZoneBoard("buried_archive", 9193, { profile = "spires", width = 16, height = 16 })
    expect(zone.generator.id == "archive_generator_v1_hybrid_v1" and zone.generator.profile == "spires", "zone generator should opt into hybrid profile")
end

tests[#tests + 1] = function()
    local expected = {
        buried_archive = { material = "archive", hazardKind = "audit_static", objectiveKind = "protect_archive_shelf" },
    }
    expect(#TacticsProcgen.zoneGenerators() == 1, "procgen should expose one live zone generator")
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
    for _, zoneId in ipairs(ArchivedTactics.zoneOrder) do
        expect(TacticsProcgen.zoneGenerator(zoneId) == nil and ArchivedTactics.procgen[zoneId], "future generator should be archived: " .. zoneId)
    end
end

tests[#tests + 1] = function()
    for _, zoneId in ipairs({ "buried_archive" }) do
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
    local alpha = EnemyCatalog.alpha("archive")
    local spec = TacticsProcgen.generateArchiveRouteBoard("archive_ledger_repair", 4204)
    local state = TacticsState.new(spec)
    local director = spec.encounterDirector
    local alphaReinforcement = nil
    for _, reinforcement in ipairs(director.reinforcementTiming or {}) do
        if reinforcement.enemy == "shelf_warden" then
            alphaReinforcement = reinforcement
        end
    end
    expect(not state:unit("shelf_warden"), "Shelf Warden alpha should not deploy as an opening unit")
    expect(director.alphaSpawn and director.alphaSpawn.enemy == "shelf_warden" and director.alphaSpawn.tier == "alpha", "director should expose Shelf Warden alpha spawn")
    expect(alphaReinforcement and alphaReinforcement.turn == 4 and alphaReinforcement.visibleWarningTurn < alphaReinforcement.turn and alphaReinforcement.role == "alpha_mid_run_elite", "Shelf Warden should be scheduled as a mid-run elite spawn")
    expect(alphaReinforcement.terrainInteraction == alpha.terrainInteraction and alphaReinforcement.terrainMutation.deterministic, "Shelf Warden reinforcement should carry deterministic terrain interaction")
    expect(spec.alphaTerrain and #spec.alphaTerrain.blockers == 2 and #spec.alphaTerrain.hazardLane.tiles > 0, "Shelf Warden should stamp deterministic alpha terrain")
    for _, blocker in ipairs(spec.alphaTerrain.blockers) do
        local tile = state:tileAt(blocker.x, blocker.y)
        expect(tile.blocker and tile.blockerKind == "mobile" and tile.terrainInteraction == alpha.terrainInteraction and contains(tile.tags, "shelf_warden"), "Shelf Warden blocker should be inspectable terrain")
    end
    for _, tileRef in ipairs(spec.alphaTerrain.hazardLane.tiles) do
        local tile = state:tileAt(tileRef.x, tileRef.y)
        expect(tile.hazard.kind == "warden_audit_beam" and contains(tile.tags, "alpha_audit_beam"), "Shelf Warden audit beam should be deterministic terrain")
    end
    expect(Serialize.encode(spec) == Serialize.encode(TacticsProcgen.generateArchiveRouteBoard("archive_ledger_repair", 4204)), "Shelf Warden alpha board should serialize deterministically")
end

tests[#tests + 1] = function()
    for index, eliteId in ipairs({ "codex_advocate", "shelf_knight", "writ_cantor", "null_censor" }) do
        local elite = EnemyCatalog.elite("archive", eliteId)
        local spec = TacticsProcgen.generateDirectedZoneBoard("buried_archive", 4100 + index, { includeElite = true, eliteId = eliteId })
        local state = TacticsState.new(spec)
        local unit = state:unit(eliteId)
        local objective = state:objective(spec.objectives[1].id)
        local foundEntry = false
        for _, entry in ipairs(spec.encounterDirector.enemyMix) do
            if entry.id == eliteId then
                foundEntry = true
                expect(entry.intent and entry.intent.mode == "hiddenFootprint" and entry.intent.intentType == elite.maskedIntent.intentType, "elite procgen entry should carry masked footprint: " .. eliteId)
                expect(entry.partialIntent and entry.partialIntent.category == elite.partialIntent.category, "elite procgen entry should keep category partial intent: " .. eliteId)
            end
        end
        expect(foundEntry and unit and unit.intent and unit.intent.mode == "hiddenFootprint", "procgen should deploy elite with hidden footprint intent: " .. eliteId)
        expect(unit.intent.weakPoint == elite.weakPoints[1] and unit.terrainInteraction == elite.terrainInteraction, "elite unit should keep weak point and terrain interaction: " .. eliteId)
        state:declareIntent(unit.id, {
            mode = unit.intent.mode,
            intentType = unit.intent.intentType,
            category = unit.intent.category,
            source = unit.id,
            sourceTile = { x = unit.x, y = unit.y },
            targetTiles = { { x = objective.x, y = objective.y } },
            revealRotations = unit.intent.revealRotations,
            revealClasses = unit.intent.revealClasses,
            revealActions = unit.intent.revealActions,
            mask = unit.intent.mask,
            weakPoint = unit.intent.weakPoint,
            counterplay = unit.intent.counterplay,
        })
        local hidden = state:intentPreview(unit.id)
        local rotated = state:intentPreview(unit.id, { rotation = unit.intent.revealRotations[1] })
        local classed = state:intentPreview(unit.id, { revealClass = "arcanist" })
        local actioned = state:intentPreview(unit.id, { revealAction = "unseal_intent" })
        expect(hidden.mode == "hiddenFootprint" and hidden.category == elite.partialIntent.category and hidden.footprintHidden and not hidden.targetTiles, "elite hidden preview should show category only before reveal: " .. eliteId)
        expect(rotated.targetTiles[1].x == objective.x and classed.targetTiles[1].y == objective.y and actioned.weakPoint == elite.weakPoints[1], "elite footprint should reveal by rotation, class, or action gate: " .. eliteId)
    end
    local runtime = TacticalRuntime.new(makeTacticalSim(4109), { variantId = "archive_elite_claim" })
    local hidden = runtime.state:intentPreview("shelf_knight")
    local revealed = runtime.state:intentPreview("shelf_knight", { revealClass = "arcanist" })
    expect(hidden and hidden.mode == "hiddenFootprint" and hidden.footprintHidden and revealed.targetTiles[1], "runtime should keep route elite intent masked until class reveal")
end

tests[#tests + 1] = function()
    local expected = {}
    for _, enemy in ipairs(EnemyCatalog.common("archive")) do
        expected[enemy.id] = false
    end
    for _, variant in ipairs(TacticsProcgen.archiveRouteVariants()) do
        local spec = TacticsProcgen.generateArchiveRouteBoard(variant.id)
        local enemyUnits = {}
        for _, unit in ipairs(spec.units) do
            if unit.side == "enemy" then
                enemyUnits[#enemyUnits + 1] = unit
                if expected[unit.id] ~= nil then
                    expected[unit.id] = true
                    expect(unit.intent and unit.intent.intentType == unit.intentType and unit.boardVerb, "archive procgen enemy unit should carry catalog intent metadata: " .. unit.id)
                end
            end
        end
        expect(#enemyUnits == (variant.directorOptions and variant.directorOptions.includeElite and 3 or 2), "archive route board should deploy directed enemy mix: " .. variant.id)
        for _, entry in ipairs(spec.encounterDirector.enemyMix) do
            if expected[entry.id] ~= nil then
                expected[entry.id] = true
                expect(entry.intent and entry.intent.intentType == entry.intentType, "archive enemy mix should carry distinct intent type: " .. entry.id)
            end
        end
        for _, reinforcement in ipairs(spec.encounterDirector.reinforcementTiming or {}) do
            if expected[reinforcement.enemy] ~= nil then
                expected[reinforcement.enemy] = true
            end
        end
    end
    for enemyId, seen in pairs(expected) do
        expect(seen, "archive route spawn pool should cover common enemy " .. enemyId)
    end
end

tests[#tests + 1] = function()
    local route = TacticsProcgen.archiveRoute()
    local variants = TacticsProcgen.archiveRouteVariants()
    local ids = {}
    local templates = {}
    local nodeKinds = {}
    local objectiveFamilies = {}
    local terrainProfiles = {}
    local expectedOrder = { "archive_entry_audit", "archive_shelf_protection", "archive_proof_extract", "archive_ledger_repair", "archive_sealed_shortcut", "archive_vault_regent_final" }
    expect(route.id == "buried_archive_vertical_slice" and route.zone == "buried_archive", "archive route should define Buried Archive route metadata")
    expect(#variants == 6 and route.boardCount == #variants, "archive route should expose exactly 6 mission variants")
    for index, variant in ipairs(variants) do
        ids[variant.id] = true
        templates[variant.template] = true
        nodeKinds[variant.nodeKind] = true
        expect(route.variantOrder[index] == variant.id and variant.id == expectedOrder[index] and variant.zone == "buried_archive", "archive route should keep ordered archive variants")
        expect(RunCatalog.boardTemplate(variant.template), "archive route variant should use known template: " .. variant.id)
        expect(variant.reward and variant.complication and variant.preview, "archive route variant should expose reward complication preview: " .. variant.id)
        local seed = 3000 + index
        local spec = TacticsProcgen.generateArchiveRouteBoard(variant.id, seed)
        local state = TacticsProcgen.archiveRouteState(variant.id, seed)
        local family = state:objective(spec.objectives[1].id).family
        terrainProfiles[variant.generatorOptions.profile] = true
        expect(not objectiveFamilies[family], "archive route objective family should be distinct: " .. family)
        objectiveFamilies[family] = variant.id
        expect(spec.zone == "buried_archive" and spec.archiveRoute.variantId == variant.id, "archive route board should bind variant metadata: " .. variant.id)
        expect(spec.generator.variantId == variant.id and spec.generator.template == variant.template and spec.generator.routeId == route.id, "archive route board should bind generator metadata: " .. variant.id)
        expect(spec.generator.profile == variant.generatorOptions.profile, "archive route board should bind terrain profile: " .. variant.id)
        expect(spec.validation.valid and TacticsProcgen.validateGrammarBoard(spec).valid, "archive route board should validate grammar: " .. variant.id)
        expect(TacticsProcgen.auditReinforcementRules(spec).ok, "archive route board should pass reinforcement audit: " .. variant.id)
        expect(TacticsProcgen.difficultyBudget(spec).accepted and spec.budget.accepted, "archive route board should pass difficulty budget: " .. variant.id)
        expect(state:tileAt(spec.objectives[1].x, spec.objectives[1].y).objective.id == spec.objectives[1].id, "archive route state should instantiate objective tile: " .. variant.id)
        expect(Serialize.encode(spec) == Serialize.encode(TacticsProcgen.generateArchiveRouteBoard(variant.id, seed)), "archive route board should be deterministic: " .. variant.id)
    end
    for _, id in ipairs(route.variantOrder) do
        expect(ids[id], "archive route order should reference existing variant " .. id)
    end
    for _, family in ipairs({ "stealth", "protect", "extract", "repair", "disable", "boss" }) do
        expect(objectiveFamilies[family], "archive route missing objective family " .. family)
    end
    for _, profile in ipairs({ "spires", "sprawl", "open_wilds", "rooms_mines", "mixed_archive" }) do
        expect(terrainProfiles[profile], "archive route missing terrain profile " .. profile)
    end
    expect(templates.kill_light and templates.protect_heavy and templates.extraction and templates.repair and templates.stealth and templates.boss_route, "archive route should cover six tactical templates")
    expect(nodeKinds.combat and nodeKinds.repair and nodeKinds.boss and nodeKinds.high_reward_extraction and nodeKinds.cursed_shortcut, "archive route should cover route node pressure")
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
    local path = "dist/validator-test-report.json"
    os.remove(path)
    expect(#ProcgenValidator.fixedSeeds == 25, "procgen validator should define 25 fixed seeds")
    local report = ProcgenValidator.run({ outputPath = path, seeds = { 7101, 7102, 7103 } })
    expect(report.validator == "procgen_validator_v1" and report.seedCount == 3 and report.rejectCount == 0 and report.accepted, "procgen validator should accept fixed archive seeds")
    expect(report.results[1].summary.board and report.results[1].summary.players > 0 and report.results[1].summary.enemies > 0, "procgen validator should report board/unit summary")
    local encoded = ProcgenValidator.encodeJson(report)
    expect(encoded:find('"rejectCount":0', 1, true) and encoded:find('"validator":"procgen_validator_v1"', 1, true), "procgen validator should encode JSON report")
    local file = io.open(path, "r")
    local body = file and file:read("*a") or ""
    if file then
        file:close()
    end
    os.remove(path)
    expect(body:find('"seedCount":3', 1, true) and body:find('"rejects":%[', 1, false), "procgen validator should write reject log JSON")
end

tests[#tests + 1] = function()
    local route = TacticsProcgen.archiveRoute()
    local variants = route.variantOrder
    local firstBatch = {}
    local secondBatch = {}
    local seen = {}
    for index, seed in ipairs(ProcgenValidator.fixedSeeds) do
        local variantId = variants[((index - 1) % #variants) + 1]
        seen[variantId] = true
        local spec = TacticsProcgen.generateArchiveRouteBoard(variantId, seed)
        local validation = ProcgenValidator.validateSpec(spec, { seed = seed, variantId = variantId })
        local stateA = TacticsProcgen.archiveRouteState(variantId, seed)
        local stateB = TacticsProcgen.archiveRouteState(variantId, seed)
        local replayA = TacticsReplay.fromSnapshot(TacticsReplay.snapshot(stateA))
        local replayB = TacticsReplay.fromSnapshot(TacticsReplay.snapshot(stateB))
        expect(validation.accepted, "validator fixture seed should pass invariant checks: " .. variantId .. ":" .. tostring(seed))
        expect(sameSnapshot(replayA, stateA), "validator fixture seed should roundtrip replay snapshot: " .. variantId .. ":" .. tostring(seed))
        expect(sameSnapshot(replayA, replayB), "validator fixture seed should replay deterministically: " .. variantId .. ":" .. tostring(seed))
        firstBatch[#firstBatch + 1] = { seed = seed, variantId = variantId, snapshot = TacticsReplay.snapshot(replayA) }
        secondBatch[#secondBatch + 1] = { seed = seed, variantId = variantId, snapshot = TacticsReplay.snapshot(replayB) }
    end
    expect(Serialize.encode(firstBatch) == Serialize.encode(secondBatch), "validator fixed seed batch should replay deterministically")
    for _, variantId in ipairs(variants) do
        expect(seen[variantId], "validator fixed seed batch should cover route variant " .. variantId)
    end
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
    local six = TacticsState.new({
        board = { width = 6, height = 1 },
        units = {
            { id = "u1", side = "player", x = 1, y = 1, maxAp = TacticsAP.defaultUnitApForSquad(6) },
            { id = "u2", side = "player", x = 2, y = 1, maxAp = TacticsAP.defaultUnitApForSquad(6) },
            { id = "u3", side = "player", x = 3, y = 1, maxAp = TacticsAP.defaultUnitApForSquad(6) },
            { id = "u4", side = "player", x = 4, y = 1, maxAp = TacticsAP.defaultUnitApForSquad(6) },
            { id = "u5", side = "player", x = 5, y = 1, maxAp = TacticsAP.defaultUnitApForSquad(6) },
            { id = "u6", side = "player", x = 6, y = 1, maxAp = TacticsAP.defaultUnitApForSquad(6) },
        },
    })
    local audit = TacticsAP.auditTurnBudget(six, "player")
    expect(audit.ok and audit.total == 18 and audit.min == 18 and audit.max == 24, "6-unit AP economy should fit 18-24 AP total")
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
        board = { width = 5, height = 1 },
        units = {
            { id = "hero", side = "player", x = 1, y = 1, visionRadius = 1 },
            { id = "enemy", side = "enemy", x = 5, y = 1, hp = 4 },
        },
    })
    TacticsIntent.declare(state, "enemy", { mode = "exact", category = "attack", targetTiles = { { x = 1, y = 1 } }, damage = 2, label = "strike" })
    local hidden = TacticsIntent.preview(state, "enemy")
    expect(hidden.categoryOnly and hidden.hiddenByVision and hidden.category == "attack" and hidden.targetTiles == nil and hidden.damage == nil, "out-of-vision enemy intent should expose category only")
    expect(state:intentPreview("enemy").targetTiles[1].x == 1, "vision gating should not alter committed intent footprint")
    state:unit("enemy").x = 2
    local revealed = TacticsIntent.preview(state, "enemy")
    expect(revealed.revealed and revealed.targetTiles[1].x == 1 and revealed.damage == 2, "enemy entering vision should reveal full committed footprint")
    state:unit("enemy").x = 5
    local remembered = TacticsIntent.preview(state, "enemy")
    expect(remembered.revealed and remembered.targetTiles[1].x == 1, "revealed current-turn intent should stay readable after leaving vision")
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
    local state = TacticsState.new({
        defaultAp = 4,
        board = { width = 4, height = 2 },
        units = {
            { id = "warden", side = "player", x = 1, y = 1, hp = 8 },
            { id = "target", side = "enemy", x = 2, y = 1, hp = 6 },
        },
    })
    state:apply(TacticsState.commands.status("warden", "target", "guarded", 2, 1, 0))
    state:apply(TacticsState.commands.attack("warden", "target", 2, 0))
    expect(state:unit("target").hp == 5, "guarded should reduce incoming damage")
    state:apply(TacticsState.commands.status("warden", "target", "shredded", 2, 1, 0))
    state:apply(TacticsState.commands.attack("warden", "target", 2, 0))
    expect(state:unit("target").hp == 3, "shredded should cancel guarded reduction")
    state:apply(TacticsState.commands.status("warden", "target", "anchored", 1, nil, 0))
    local moved, reason = state:displaceUnit("target", 1, 0, 1, 1)
    expect(not moved and reason == "anchored" and state:unit("target").x == 2, "anchored should block forced displacement")
    state:apply(TacticsState.commands.status("warden", "warden", "jammed", 1, nil, 0))
    local ok, err = pcall(function()
        state:apply(TacticsState.commands.threatZone("warden", "line", "east", 2, nil, 1, 1))
    end)
    expect(not ok and err:find("unit is jammed", 1, true), "jammed should block threat-zone creation")
end

tests[#tests + 1] = function()
    local commons = EnemyCatalog.common("archive")
    local state = TacticsState.new({
        board = { width = 5, height = 1 },
        units = {
            { id = "warden", side = "player", x = 1, y = 1, hp = 6, visionRadius = 6 },
            { id = "binding_indexer", side = "enemy", x = 3, y = 1, hp = 3, intent = commons[11].exactIntent },
            { id = "margin_lumen", side = "enemy", x = 4, y = 1, hp = 3, intent = commons[12].exactIntent },
        },
    })
    local runtime = { state = state, selectedUnitId = "warden", cursor = { x = 1, y = 1 }, turn = 1, lastSeenEnemies = {} }
    TacticalRuntime.declareEnemyIntents(runtime)
    expect(state:intentPreview("binding_indexer").statusEffect.status == "pinned", "controller enemy intent should expose pinned status")
    expect(state:intentPreview("margin_lumen").target == "margin_lumen", "support enemy intent should target self")
    TacticalRuntime.endPlayerTurn(runtime)
    expect(state:hasStatus("warden", "pinned") and state:hasStatus("margin_lumen", "guarded"), "enemy status intents should apply on enemy turn")
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
    local settings = Settings.defaults()
    expect(settings.masterVolume == 1 and settings.sfxVolume == 1 and settings.ambientVolume == 0.7, "settings defaults should expose audio volumes")
    expect(settings.screenShake == true, "settings defaults should enable screen shake")
    expect(settings.highContrastTiles == false and settings.coverEdgePalette == "colorblind" and settings.intentIconScale == 1 and settings.intentText == false, "settings defaults should expose tactical accessibility controls")
    Settings.adjust(settings, "masterVolume", -4)
    expect(settings.masterVolume > 0.59 and settings.masterVolume < 0.61, "settings slider should step and clamp")
    Settings.toggle(settings, "highContrast")
    expect(settings.highContrast == true, "settings toggle should flip accessibility flags")
    Settings.toggle(settings, "highContrastTiles")
    Settings.toggle(settings, "intentText")
    Settings.adjust(settings, "intentIconScale", 3)
    Settings.cycle(settings, "coverEdgePalette", 1)
    expect(settings.highContrastTiles and settings.intentText and settings.intentIconScale == 1.3 and settings.coverEdgePalette == "standard", "settings controls should update tactical accessibility flags")
    expect(#Settings.accessibilityControls() >= 10, "settings should expose an accessibility control group")
    Settings.toggle(settings, "screenShake")
    expect(settings.screenShake == false and not Render.screenShakeEnabled(settings), "screen shake toggle should disable shake")
    Settings.cycle(settings, "colorblindMode", 1)
    expect(settings.colorblindMode == "deuteranopia", "settings cycle should advance colorblind mode")
    settings.fontScale = 1.4
    expect(Render.fontScale(settings) == 1.4, "font scale should clamp through render")
    local shifted = Render.accessibleColor(settings, { 0.9, 0.1, 0.1, 1 })
    expect(shifted[1] ~= 0.9 and shifted[2] ~= 0.1, "colorblind mode should transform cue colors")
    local tileNormal = Render.tileAccessibleColor({ highContrastTiles = false }, { 0.45, 0.48, 0.5, 1 })
    local tileContrast = Render.tileAccessibleColor({ highContrastTiles = true }, { 0.45, 0.48, 0.5, 1 })
    expect(tileNormal[1] ~= tileContrast[1] and Render.tacticalAccessibility(settings).intentText, "tactical accessibility helpers should transform tile contrast and expose intent text")
    local app = { settings = settings, eventFlash = { cue = "hit_slash", status = "Mara hit" } }
    expect(Render.audioSubtitle(app) == "slash hit: Mara hit", "subtitles should expose audio cue and status")
    local export = Accessibility.text(makeTacticalSim(84), app)
    expect(export:find("Thoth accessibility export", 1, true) and export:find("high_contrast=true", 1, true) and export:find("high_contrast_tiles=true", 1, true) and export:find("cover_edge_palette=standard", 1, true) and export:find("intent_text=true", 1, true) and export:find("ambient_volume=0.7", 1, true) and export:find("screen_shake=false", 1, true), "accessibility export should expose screen-reader text")
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
    expect(loadedSettings.masterVolume == settings.masterVolume and loadedSettings.ambientVolume == 0.7 and loadedSettings.highContrast and loadedSettings.highContrastTiles and loadedSettings.intentText and loadedSettings.intentIconScale == 1.3 and loadedSettings.coverEdgePalette == "standard" and loadedSettings.colorblindMode == "deuteranopia" and loadedSettings.screenShake == false, "settings text round trip should preserve values")
    expect(Settings.keyForAction(loadedSettings, "moveUp") == "i", "settings text round trip should preserve keybinds")
    local clampedSettings = assert(Settings.fromText("THOTH_LUA_SETTINGS 1\n{[\"fontScale\"]=9,[\"masterVolume\"]=-4,[\"intentIconScale\"]=9,[\"coverEdgePalette\"]=\"bad\",[\"colorblindMode\"]=\"bad\",[\"keybinds\"]={[\"moveUp\"]=\"escape\",[\"moveDown\"]=\"j\"}}\n"))
    expect(clampedSettings.fontScale == 1.4 and clampedSettings.masterVolume == 0 and clampedSettings.intentIconScale == 1.75 and clampedSettings.coverEdgePalette == "colorblind" and clampedSettings.colorblindMode == "off", "settings loader should clamp values")
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
    Render.drawTitle(makeTacticalSim(76), app)
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
    local ended = {
        estate = {
            campaign = {
                lost = true,
                lossReason = "dread",
                endingRoute = "extraction_collapse",
                dreadLimit = 2,
                dread = 2,
                factions = {},
            },
            roster = {
                { id = 1, name = "Mara", class = "warden", level = 1, stress = 0, alive = true },
            },
            graveyard = {
                { id = 1, name = "Mara", class = "warden", location = "archive" },
            },
        },
        endingScreenCopy = function()
            return "collapsed"
        end,
        endingRouteStatus = function()
            return {}
        end,
        journalEntries = function()
            return {
                { key = "archive_writ_01", title = "Archive Writ", typeName = "document", location = "test", abstract = "test" },
            }
        end,
    }
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
    local journal = Render.drawJournal(ended, app)
    expect(#journal.documents == 1 and journal.documents[1].text ~= "", "journal should expose found document text")
    expect(#journal.epitaphs == 1 and journal.epitaphs[1].epitaph ~= "", "journal should expose graveyard epitaphs")
    expect(#app.ui.journalButtons >= 4, "journal draw should populate journal hitboxes")
    app.tutorial = { active = true, index = 1 }
    local tutorial = Render.drawTutorial(app)
    expect(#tutorial == 7 and tutorial[1].key == "tactical_onboarding" and tutorial[2].key == "ap_cursor" and tutorial[7].key == "rotation", "tutorial should expose tactical onboarding steps")
    expect(tutorial[1].board.board.width == 6 and tutorial[2].board and tutorial[4].board and tutorial[6].board.objectives, "tutorial should link tactical board fixtures")
    expect(#app.ui.tutorialButtons == 3, "tutorial draw should populate tutorial controls")
    app.settings = Settings.defaults()
    Render.drawSettings(app)
    local hasBack = false
    local hasBind = false
    local hasAdjust = false
    local tacticalControls = {}
    for _, hitbox in ipairs(app.ui.settingsButtons) do
        hasBack = hasBack or hitbox.action == "back"
        hasBind = hasBind or hitbox.action == "bind"
        hasAdjust = hasAdjust or hitbox.action == "slider" or hitbox.action == "adjust"
        if hitbox.setting then
            tacticalControls[hitbox.setting] = true
        end
    end
    expect(hasBack and hasBind and hasAdjust, "settings draw should populate back, bind, and slider hitboxes")
    for _, setting in ipairs({ "highContrastTiles", "intentIconScale", "coverEdgePalette", "intentText" }) do
        expect(tacticalControls[setting], "settings draw should expose tactical accessibility control " .. setting)
    end
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
            squadLoadoutButtons = { { stale = true } },
            tacticalIntentButtons = { { stale = true } },
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
    expect(#app.ui.pauseButtons == 0 and #app.ui.confirmButtons == 0 and #app.ui.gameOverButtons == 0 and #app.ui.creditsButtons == 0 and #app.ui.journalButtons == 0 and #app.ui.tutorialButtons == 0 and #app.ui.squadLoadoutButtons == 0 and #app.ui.tacticalIntentButtons == 0 and #app.ui.titleButtons == 0 and #app.ui.settingsButtons == 0, "prepareUi should clear system hitboxes")
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
