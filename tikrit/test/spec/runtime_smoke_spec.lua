local TestRunner = require("test_runner")
local CONFIG = require("config")

local describe = TestRunner.describe
local it = TestRunner.it

local function buildEditorLayout()
    local rows = {}
    for y = 1, 30 do
        rows[y] = {}
        for x = 1, 30 do
            rows[y][x] = "."
        end
    end

    for x = 1, 30 do
        rows[1][x] = "#"
        rows[30][x] = "#"
    end
    for y = 1, 30 do
        rows[y][1] = "#"
        rows[y][30] = "#"
    end

    for y = 4, 8 do
        for x = 4, 9 do
            rows[y][x] = "C"
        end
    end
    for y = 3, 7 do
        for x = 14, 19 do
            rows[y][x] = "C"
        end
    end
    rows[6][6] = "@"
    rows[9][7] = "H"
    rows[10][10] = "O"
    rows[18][22] = "K"
    rows[22][8] = "R"
    rows[24][22] = "D"
    rows[15][14] = "W"
    rows[16][15] = "W"
    rows[6][8] = "B"
    rows[18][12] = "B"
    rows[12][14] = "I"
    rows[5][12] = "M"
    rows[7][13] = "P"
    rows[9][9] = "Q"

    local lines = {}
    for y = 1, 30 do
        lines[y] = table.concat(rows[y])
    end
    return {lines = lines, filename = "smoke_layout.txt"}
end

describe("Runtime Smoke", function()
    it("starts an editor playtest, triggers door audio, visual alerts, and screen shake gating", function()
        local originalLove = _G.love
        local ok, err = pcall(function()
            local files = {}
            local directories = {}
            local sources = {}
            local printed = {}
            local currentTime = 0
            local currentFont = nil
            local rectangleCalls = 0
            local windowMode
            local run

            local function countEvent(events, target)
                local total = 0
                for _, eventId in ipairs(events or {}) do
                    if eventId == target then
                        total = total + 1
                    end
                end
                return total
            end

            local function countKeys(map)
                local total = 0
                for _ in pairs(map or {}) do
                    total = total + 1
                end
                return total
            end

            local function tileAt(coord)
                local gx = math.floor(coord[1] / 20) + 1
                local gy = math.floor(coord[2] / 20) + 1
                return ((run.world.grid[gy] or {})[gx])
            end

            local function makeSource(path)
                local source = {
                    path = path,
                    playing = false,
                    plays = 0,
                    setVolume = function() end,
                    setLooping = function() end,
                    isPlaying = function(self)
                        return self.playing
                    end,
                }
                sources[path] = source
                return source
            end

            _G.love = {
                window = {
                    setTitle = function() end,
                    setMode = function(width, height, options)
                        windowMode = {
                            width = width,
                            height = height,
                            options = options or {},
                        }
                    end,
                },
                filesystem = {
                    createDirectory = function(path)
                        directories[path] = true
                    end,
                    getDirectoryItems = function(path)
                        local items = {}
                        for filePath in pairs(files) do
                            local item = filePath:match("^" .. path .. "/(.+)$")
                            if item then
                                table.insert(items, item)
                            end
                        end
                        table.sort(items)
                        return items
                    end,
                    read = function(path)
                        return files[path]
                    end,
                    write = function(path, contents)
                        files[path] = contents
                        return true
                    end,
                    getInfo = function(path)
                        if directories[path] or files[path] then
                            return {type = directories[path] and "directory" or "file"}
                        end
                        return nil
                    end,
                },
                graphics = {
                    newFont = function(pathOrSize, size)
                        if size == nil then
                            size = pathOrSize
                        end
                        return {
                            size = size,
                            getWidth = function(_, text)
                                return #tostring(text) * math.max(8, math.floor(size / 3))
                            end,
                        }
                    end,
                    setFont = function(font)
                        currentFont = font
                    end,
                    getFont = function()
                        return currentFont
                    end,
                    getDimensions = function()
                        return 1600, 900
                    end,
                    newImage = function(path)
                        return {
                            path = path,
                            getWidth = function() return 20 end,
                            getHeight = function() return 20 end,
                        }
                    end,
                    setColor = function() end,
                    print = function(text)
                        table.insert(printed, tostring(text))
                    end,
                    rectangle = function()
                        rectangleCalls = rectangleCalls + 1
                    end,
                    circle = function() end,
                    draw = function() end,
                    push = function() end,
                    pop = function() end,
                    translate = function() end,
                    scale = function() end,
                    clear = function() end,
                    line = function() end,
                    polygon = function() end,
                },
                audio = {
                    newSource = function(path)
                        return makeSource(path)
                    end,
                    play = function(source)
                        if source then
                            source.playing = true
                            source.plays = source.plays + 1
                        end
                    end,
                    stop = function(source)
                        if source then
                            source.playing = false
                        end
                    end,
                },
                timer = {
                    getTime = function()
                        return currentTime
                    end,
                },
                keyboard = {
                    isDown = function()
                        return false
                    end,
                },
                mouse = {
                    getPosition = function()
                        return 0, 0
                    end,
                    isDown = function()
                        return false
                    end,
                },
                event = {
                    quit = function() end,
                },
            }

            package.loaded["main"] = nil
            package.loaded["modules/editor"] = nil
            package.loaded["modules/effects"] = nil
            require("main")
            local Editor = require("modules/editor")
            local Effects = require("modules/effects")
            local Items = require("modules/items")
            local Furniture = require("modules/furniture")
            local SoundEvents = require("modules/sound_events")
            local SpriteRegistry = require("modules/sprite_registry")
            local Wildlife = require("modules/wildlife")
            local World = require("modules/world")
            local Replay = require("modules/replay")
            local stationDraws = 0
            local wildlifeDraws = 0
            local markerDraws = 0
            local originalDrawStation = SpriteRegistry.drawStation
            local originalDrawWildlife = SpriteRegistry.drawWildlife
            local originalDrawWorldMarker = SpriteRegistry.drawWorldMarker
            SpriteRegistry.drawStation = function(...)
                stationDraws = stationDraws + 1
                return originalDrawStation(...)
            end
            SpriteRegistry.drawWildlife = function(...)
                wildlifeDraws = wildlifeDraws + 1
                return originalDrawWildlife(...)
            end
            SpriteRegistry.drawWorldMarker = function(...)
                markerDraws = markerDraws + 1
                return originalDrawWorldMarker(...)
            end
            love.load()
            TestRunner.assertTrue(windowMode ~= nil)
            TestRunner.assertTrue(windowMode.options.fullscreen)
            TestRunner.assertEqual(windowMode.options.fullscreentype, "desktop")

            love.keypressed("f5")
            Editor.setLayout(buildEditorLayout())
            love.keypressed("f6")

            local state = love._tikritDebug.getGameState()
            run = state.run
            TestRunner.assertType(run, "table")
            TestRunner.assertEqual(run.world.source, "editor")
            TestRunner.assertEqual(countKeys(run.world.discoveredPOIs), 1)
            TestRunner.assertTrue(run.runtime.currentPOI == "Editor Cabin 1" or run.runtime.currentPOI == "Editor Cabin 2")
            local startPOI = run.runtime.currentPOI
            local remotePOI = startPOI == "Editor Cabin 1" and "Editor Cabin 2" or "Editor Cabin 1"
            local standaloneStation
            for _, station in ipairs(run.runtime.stations or {}) do
                if tileAt(station.coord) ~= "cabin_workbench" then
                    standaloneStation = station
                    break
                end
            end
            TestRunner.assertType(standaloneStation, "table")

            printed = {}
            love.draw()
            local initialDraw = table.concat(printed, " | ")
            TestRunner.assertTrue(initialDraw:find(startPOI, 1, true) ~= nil)
            TestRunner.assertTrue(initialDraw:find(remotePOI, 1, true) == nil)
            TestRunner.assertTrue(stationDraws > 0)
            TestRunner.assertTrue(markerDraws > 0)
            local initialPoiEvents = countEvent(SoundEvents.getEventLog(), "poi_discovery")
            currentTime = currentTime + 0.1
            love.update(0.1)
            TestRunner.assertEqual(countEvent(SoundEvents.getEventLog(), "poi_discovery"), initialPoiEvents)

            run.player.coord = {(run.world.structures[1].door.x - 1) * 20, (run.world.structures[1].door.y - 1) * 20}
            currentTime = currentTime + 0.1
            love.update(0.1)
            TestRunner.assertTrue((sources["sound/door-open.mp3"] or {}).plays > 0)

            run.player.coord = {220, 220}
            run.player.lastSafeCoord = {220, 220}
            run.player.warmth = 12
            run.world.weather.current = "blizzard"
            currentTime = currentTime + 0.1
            love.update(0.1)
            TestRunner.assertTrue(run.runtime.alerts.blizzard > 0 or run.runtime.alerts.fireRisk > 0)

            state.settings.gameplay.screenShake = false
            Effects.init()
            love.keypressed("f")
            TestRunner.assertFalse(Effects.screenShake.active)

            state.settings.gameplay.screenShake = true
            love.keypressed("f")
            TestRunner.assertTrue(Effects.screenShake.active)

            run.player.coord = {standaloneStation.coord[1], standaloneStation.coord[2]}
            currentTime = currentTime + 0.1
            love.update(0.1)
            TestRunner.assertEqual(run.runtime.currentStation.label, "Workbench / Curing Rack")
            TestRunner.assertEqual(run.runtime.currentStation.state, "idle")
            TestRunner.assertTrue(run.runtime.interactionHint:find("C craft at the Workbench / Curing Rack", 1, true) ~= nil)
            TestRunner.assertTrue(run.runtime.interactionHint:find("X hang fresh hides or gut to cure", 1, true) ~= nil)

            local cacheNode = {
                type = "cache",
                coord = {standaloneStation.coord[1] + (CONFIG.TILE_SIZE * 4), standaloneStation.coord[2]},
                opened = false,
                hidden = false,
                revealed = true,
                loot = {Items.create("matches", 1)},
            }
            local resourceNodes = World.activeCollection(run, "resourceNodes")
            table.insert(resourceNodes, cacheNode)
            World.attachRun(run)
            cacheNode.hidden = false
            cacheNode.revealed = true
            run.player.coord = {cacheNode.coord[1] - CONFIG.TILE_SIZE, cacheNode.coord[2]}
            run.player.lastMoveX = 1
            run.player.lastMoveY = 0
            love.keypressed("e")
            TestRunner.assertTrue(cacheNode.opened)

            run.player.coord = {100, 100}
            run.player.lastMoveX = 1
            run.player.lastMoveY = 0
            run.player.equippedWeapon = nil
            run.player.equippedTool = "hatchet"
            local torchBefore = Items.count(run.player.inventory, "torch")
            Furniture.spawn(World.currentLevel(run), "lantern", {120, 100})
            love.keypressed("space")
            TestRunner.assertTrue(Items.count(run.player.inventory, "torch") > torchBefore)
            TestRunner.assertEqual(World.facingEntity(run), nil)

            local treeGridX = math.floor(120 / CONFIG.TILE_SIZE) + 1
            local treeGridY = math.floor(100 / CONFIG.TILE_SIZE) + 1
            local grid = World.activeGrid(run)
            grid[treeGridY][treeGridX] = "tree"
            local sticksBefore = Items.count(run.player.inventory, "sticks")
            love.keypressed("space")
            love.keypressed("space")
            TestRunner.assertEqual(grid[treeGridY][treeGridX], "snow")
            TestRunner.assertTrue(Items.count(run.player.inventory, "sticks") > sticksBefore)

            local workbenches = World.readActiveCollection(run, "workbenches")
            run.player.coord = {workbenches[1].coord[1], workbenches[1].coord[2]}
            Items.add(run.player.inventory, "cloth", 1)
            Items.add(run.player.inventory, "cured_gut", 2)
            Items.add(run.player.inventory, "sticks", 1)
            Items.add(run.player.inventory, "feather", 2)
            local bandagesBefore = Items.count(run.player.inventory, "bandage")
            love.keypressed("c")
            love.keypressed("return")
            TestRunner.assertTrue(Items.count(run.player.inventory, "bandage") > bandagesBefore)
            TestRunner.assertTrue(countEvent(SoundEvents.getEventLog(), "craft") > 0)
            love.keypressed("c")

            run.player.afflictions.infectionRiskHours = 6
            Items.add(run.player.inventory, "antiseptic", 1)
            love.keypressed("t")
            TestRunner.assertEqual(run.player.afflictions.infectionRiskHours, 0)
            TestRunner.assertTrue(countEvent(SoundEvents.getEventLog(), "treat") > 0)

            run.player.coord = {140, 440}
            Items.add(run.player.inventory, "snare", 1)
            love.keypressed("x")
            local traps = World.activeCollection(run, "traps")
            TestRunner.assertEqual(#traps, 1)
            TestRunner.assertTrue(countEvent(SoundEvents.getEventLog(), "snare_set") > 0)
            traps[1].state = "caught"
            local meatBefore = Items.count(run.player.inventory, "raw_meat")
            love.keypressed("e")
            love.keypressed("e")
            TestRunner.assertTrue(Items.count(run.player.inventory, "raw_meat") > meatBefore)
            TestRunner.assertTrue(countEvent(SoundEvents.getEventLog(), "snare_catch") > 0)

            local mapNodes = World.readActiveCollection(run, "mapNodes")
            run.player.coord = {mapNodes[1].coord[1], mapNodes[1].coord[2]}
            Items.add(run.player.inventory, "charcoal", 1)
            local discoveredBeforeMap = countKeys(run.world.discoveredPOIs)
            love.keypressed("m")
            TestRunner.assertTrue(next(run.world.mappedTiles) ~= nil)
            TestRunner.assertTrue(countEvent(SoundEvents.getEventLog(), "map_reveal") > 0)
            TestRunner.assertTrue(countKeys(run.world.discoveredPOIs) >= discoveredBeforeMap)

            printed = {}
            love.draw()
            local mappedDraw = table.concat(printed, " | ")
            TestRunner.assertTrue(mappedDraw:find(remotePOI, 1, true) ~= nil)

            run.player.coord = {run.world.structures[1].bed.x * 20 - 20, run.world.structures[1].bed.y * 20 - 20}
            run.world.timeOfDay = 23.5
            love.keypressed("r")
            TestRunner.assertTrue(run.world.dayCount >= 2)

            run.player.coord = {standaloneStation.coord[1], standaloneStation.coord[2]}
            Items.add(run.player.inventory, "rabbit_pelt", 1)
            currentTime = currentTime + 0.1
            love.update(0.1)
            love.keypressed("x")
            currentTime = currentTime + 0.1
            love.update(0.1)
            TestRunner.assertEqual(run.runtime.currentStation.state, "curing")
            TestRunner.assertTrue(run.runtime.interactionHint:find("X hang fresh hides or gut to cure", 1, true) ~= nil)
            local curingItems = World.activeCollection(run, "curing")
            for _, curing in ipairs(curingItems) do
                curing.hoursRemaining = 0.05
            end
            currentTime = currentTime + 1.0
            love.update(1.0)
            TestRunner.assertEqual(run.runtime.currentStation.state, "ready")
            TestRunner.assertTrue(run.runtime.interactionHint:find("E collect cured items", 1, true) ~= nil)
            love.keypressed("e")
            currentTime = currentTime + 0.1
            love.update(0.1)
            TestRunner.assertEqual(run.runtime.currentStation.state, "idle")
            TestRunner.assertEqual(#curingItems, 0)

            run.player.coord = {100, 100}
            run.player.lastMoveX = 1
            run.player.lastMoveY = 0
            local wildlife = World.activeWildlife(run)
            table.insert(wildlife.rabbits, {coord = {160, 100}, kind = "rabbit"})
            table.insert(wildlife.wolves, {
                coord = {120, 100},
                kind = "wolf",
                territory = {x = 4, y = 4, width = 4, height = 4},
                territoryCenter = {120, 100},
                state = "roam",
            })
            Wildlife.mirrorLevel(World.currentLevel(run))
            wildlifeDraws = 0
            love.draw()
            TestRunner.assertTrue(wildlifeDraws > 0)
            Items.add(run.player.inventory, "bow", 1)
            Items.add(run.player.inventory, "arrow", 1)
            love.keypressed("b")
            love.keypressed("space")
            currentTime = currentTime + 0.3
            love.update(0.3)
            TestRunner.assertTrue(countEvent(SoundEvents.getEventLog(), "bow_ready") > 0)
            TestRunner.assertTrue(countEvent(SoundEvents.getEventLog(), "bow_fire") > 0)
            TestRunner.assertTrue(countEvent(SoundEvents.getEventLog(), "arrow_hit") > 0)

            run.world.weather.current = "clear"
            run.player.warmth = 90
            currentTime = currentTime + 2.6
            love.update(2.6)
            TestRunner.assertEqual(run.runtime.discoveryToast, "")

            rectangleCalls = 0
            love.draw()
            TestRunner.assertTrue(rectangleCalls > 0)

            state.screen = "title"
            state.titleIndex = 1
            love.keypressed("return")
            run = state.run
            local newRunGrid = World.activeGrid(run)
            TestRunner.assertEqual(#newRunGrid, CONFIG.WORLD_GRID_HEIGHT)
            TestRunner.assertEqual(#newRunGrid[1], CONFIG.WORLD_GRID_WIDTH)

            run.player.coord = {1200, 1200}
            run.player.lastSafeCoord = {1200, 1200}
            love.draw()
            TestRunner.assertTrue(run.runtime.camera.x > 0)
            TestRunner.assertTrue(run.runtime.camera.y > 0)

            run.player.coord = {0, 0}
            love.draw()
            TestRunner.assertEqual(run.runtime.camera.x, 0)
            TestRunner.assertEqual(run.runtime.camera.y, 0)

            run.player.coord = {(CONFIG.WORLD_GRID_WIDTH - 1) * CONFIG.TILE_SIZE, (CONFIG.WORLD_GRID_HEIGHT - 1) * CONFIG.TILE_SIZE}
            love.draw()
            TestRunner.assertEqual(run.runtime.camera.x, math.max(0, (CONFIG.WORLD_GRID_WIDTH * CONFIG.TILE_SIZE) - CONFIG.WINDOW_WIDTH))
            TestRunner.assertEqual(run.runtime.camera.y, math.max(0, (CONFIG.WORLD_GRID_HEIGHT * CONFIG.TILE_SIZE) - CONFIG.WINDOW_HEIGHT))

            World.changeDepth(run, -1, {40, 40})
            local savedEntityCount = #(World.currentLevel(run).entities or {})
            TestRunner.assertTrue(love._tikritDebug.saveCurrentGame())
            TestRunner.assertType(files["saves/autosave.lua"], "string")
            state.screen = "title"
            local loadedRun = love._tikritDebug.loadSaveSlot("autosave")
            TestRunner.assertType(loadedRun, "table")
            TestRunner.assertEqual(loadedRun.world.currentDepth, -1)
            TestRunner.assertEqual(loadedRun.player.depth, -1)
            TestRunner.assertTrue(loadedRun.world.grid == loadedRun.world.levels[-1].grid)
            TestRunner.assertEqual(loadedRun.runtime.message, "Game loaded.")
            local loadedEntityCount = #(World.currentLevel(loadedRun).entities or {})
            World.attachRun(loadedRun)
            World.attachRun(loadedRun)
            TestRunner.assertEqual(#(World.currentLevel(loadedRun).entities or {}), loadedEntityCount)
            TestRunner.assertTrue(#(World.currentLevel(loadedRun).entities or {}) >= savedEntityCount)

            Replay.startRecording(909, "stalker", {
                mode = "survival",
                currentDepth = -1,
                player = {depth = -1},
                runtimeObjects = {
                    fires = 99,
                    traps = 88,
                    carcasses = 77,
                    fishingSpots = 66,
                    climbNodes = 55,
                    mapNodes = 44,
                },
                tileSimulation = {
                    snowCoverTiles = 7,
                    iceStateTiles = 6,
                    shelterWearTiles = 5,
                    warmthPocketTiles = 4,
                    thermalWarmthTiles = 3,
                },
            })
            Replay.recordKeyState("e", true, 0.1)
            Replay.stopRecording()
            TestRunner.assertTrue(Replay.save("smoke_depth_restore"))
            TestRunner.assertTrue(Replay.load("smoke_depth_restore"))
            local depthReplay = Replay.inspect("smoke_depth_restore")
            local depthRun = love._tikritDebug.startReplayContext(depthReplay.context, depthReplay.seed, depthReplay.difficulty)
            TestRunner.assertTrue(Replay.startPlayback())
            TestRunner.assertEqual(depthRun.world.currentDepth, -1)
            TestRunner.assertEqual(depthRun.player.depth, -1)
            TestRunner.assertTrue(depthRun.world.grid == depthRun.world.levels[-1].grid)
            TestRunner.assertEqual(depthRun.runtime.replayAudit.runtimeObjects.fires, 99)
            TestRunner.assertEqual(depthRun.runtime.replayAudit.tileSimulation.snowCoverTiles, 7)
            TestRunner.assertEqual(depthRun.runtime.replayAudit.tileSimulation.thermalWarmthTiles, 3)
            TestRunner.assertTrue(#depthRun.world.fires < 99)
            local entityCount = #(World.currentLevel(depthRun).entities or {})
            World.attachRun(depthRun)
            World.attachRun(depthRun)
            TestRunner.assertEqual(#(World.currentLevel(depthRun).entities or {}), entityCount)

            local legacyDepthRun = love._tikritDebug.startReplayContext({
                mode = "survival",
                player = {},
                unknown_field = "ignored",
            }, 908, "voyageur")
            TestRunner.assertEqual(legacyDepthRun.world.currentDepth, 0)
            TestRunner.assertEqual(legacyDepthRun.player.depth, 0)

            local endgameRun = love._tikritDebug.startReplayContext({
                mode = "survival",
                currentDepth = 1,
                endgameActivated = true,
                weatherStation = {
                    activated = true,
                    depth = 1,
                },
                player = {depth = 1},
                runtimeObjects = {
                    fires = 42,
                },
            }, 910, "stalker")
            TestRunner.assertEqual(endgameRun.world.currentDepth, 1)
            TestRunner.assertTrue(endgameRun.runtime.endgameActivated)
            TestRunner.assertTrue(endgameRun.runtime.success)
            TestRunner.assertTrue(endgameRun.stats.weatherStationActivated)
            local completedGoal = false
            for _, goal in ipairs(endgameRun.world.goals or {}) do
                if goal.id == "activate_ridge_weather_station" then
                    completedGoal = goal.completed == true
                end
            end
            TestRunner.assertTrue(completedGoal)
            currentTime = currentTime + 0.1
            love.update(0.1)
            TestRunner.assertTrue(endgameRun.finished)
            TestRunner.assertTrue(endgameRun.player.alive)
        end)
        _G.love = originalLove
        if not ok then
            error(err, 0)
        end
    end)
end)
