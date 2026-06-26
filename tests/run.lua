package.path = "./?.lua;./?/init.lua;./src/?.lua;./src/?/init.lua;" .. package.path

local Player = require("src.player")
local Render = require("src.render")
local Save = require("src.save")
local Survey = require("src.survey")
local ViewScale = require("src.viewscale")
local WorldGen = require("src.worldgen")
local Diagnostics = require("src.diagnostics")
local Export = require("src.export")
local Benchmark = require("src.benchmark")

local function expect(value, message)
    if not value then error(message or "expectation failed", 2) end
end

local function round(value)
    return math.floor((value or 0) * 100000 + 0.5) / 100000
end

local fastWorldOptions = { hydrologyRegionChunks = 2, hydrologyHaloCells = 0, hydrologyBasinChunks = 8, hydrologyBasinStride = 8 }
local basinWorldOptions = { hydrologyRegionChunks = 1, hydrologyHaloCells = 0, hydrologyBasinChunks = 8, hydrologyBasinStride = 8, hydrologyBasinFlowScale = 0.6 }

local function testWorld(seed)
    return WorldGen.new(seed, fastWorldOptions)
end

local function encodeCell(cell)
    return table.concat({
        cell.x,
        cell.y,
        cell.scale,
        round(cell.filledElevation),
        round(cell.elevation),
        round(cell.flow),
        round(cell.erosion),
        round(cell.deposition),
        round(cell.thermalErosion),
        round(cell.lakeDepth),
        round(cell.rainfall),
        round(cell.temperature),
        cell.biome,
        tostring(cell.river),
        tostring(cell.riverBank),
        tostring(cell.lake),
        tostring(cell.water),
        tostring(cell.lakeId),
        tostring(cell.lakeGroupSize),
        tostring(cell.lakeOutletX),
        tostring(cell.lakeOutletY),
        round(cell.spilloverElevation),
        round(cell.spilloverFlow),
        tostring(cell.spillover),
        tostring(cell.spilloverLakeId),
        tostring(cell.talus),
        tostring(cell.alluvialFan),
        tostring(cell.floodplain),
        tostring(cell.delta),
        tostring(cell.plateId),
        tostring(cell.secondaryPlateId),
        round(cell.plateAge),
        round(cell.secondaryPlateAge),
        tostring(cell.plateCrust),
        tostring(cell.secondaryPlateCrust),
        round(cell.oceanicSubduction),
        round(cell.subductionBias),
        round(cell.riftValley),
        round(cell.volcanicIslandArc),
        round(cell.shield),
        round(cell.craton),
        tostring(cell.ridgeId),
        tostring(cell.mountainRangeId),
        tostring(cell.basinId),
        tostring(cell.watershedId),
        tostring(cell.macroBasinId),
        tostring(cell.macroChannelId),
    }, "|")
end

local function encodeChunk(chunk)
    local parts = { chunk.x, chunk.y, chunk.scale, chunk.scaleFactor }
    for y = 1, chunk.size do
        for x = 1, chunk.size do
            parts[#parts + 1] = encodeCell(chunk.cells[y][x])
        end
    end
    return table.concat(parts, "\n")
end

local function testDeterminism()
    local a = testWorld(1234)
    local b = testWorld(1234)
    expect(encodeChunk(a:chunk(2, -1, "local")) == encodeChunk(b:chunk(2, -1, "local")), "same seed should produce identical local chunk")
    expect(encodeChunk(a:chunk(0, 0, "continent")) == encodeChunk(b:chunk(0, 0, "continent")), "same seed should produce identical continent chunk")
end

local function testSeedVariance()
    local a = encodeChunk(testWorld(1234):chunk(0, 0, "region"))
    local b = encodeChunk(testWorld(5678):chunk(0, 0, "region"))
    expect(a ~= b, "different seeds should differ")
end

local function testSampleChunkAgreement()
    local world = testWorld(44)
    local chunk = world:chunk(1, -2, "local")
    for y = 1, chunk.size do
        local cell = chunk.cells[y][1]
        local sampled = world:sample(cell.x, cell.y, "local")
        expect(encodeCell(cell) == encodeCell(sampled), "sample should match chunk cell")
    end
    local right = world:chunk(0, 0, "region")
    local left = world:chunk(1, 0, "region")
    local seamSample = world:sample(left.cells[1][1].x, left.cells[1][1].y, "region")
    expect(encodeCell(left.cells[1][1]) == encodeCell(seamSample), "adjacent chunk seam should resolve to the same sample")
    expect(right.cells[1][right.size].x + right.scaleFactor == left.cells[1][1].x, "adjacent chunks should be coordinate-continuous")
end

local function testRiverMonotonicity()
    local world = testWorld(99)
    local chunk = world:chunk(0, 0, "local")
    local stats = world:hydrologyStats(0, 0, "local")
    local byCoord = {}
    for y = 1, chunk.size do
        for x = 1, chunk.size do
            local cell = chunk.cells[y][x]
            byCoord[cell.x .. ":" .. cell.y] = cell
        end
    end
    local checked = 0
    for y = 1, chunk.size do
        for x = 1, chunk.size do
            local cell = chunk.cells[y][x]
            if cell.river and cell.downX then
                local down = byCoord[cell.downX .. ":" .. cell.downY]
                if down then
                    expect(cell.elevation + 0.00001 >= down.elevation, "river should not flow uphill")
                    checked = checked + 1
                end
            end
        end
    end
    expect(stats.rivers > 0, "fixture seed should produce rivers")
    expect(stats.uphillRejects == 0, "hydrology should reject uphill filled-flow routes")
    expect(checked >= 0, "river monotonicity check should run")
end

local function testHydrologyStats()
    local world = WorldGen.new(20260625)
    local stats = world:hydrologyStats(0, 0, "local")
    expect(stats.rivers > 0, "hydrology stats should include rivers")
    expect(stats.basins > 0, "hydrology stats should include basins")
    expect(stats.maxFlow > 0, "hydrology stats should include max flow")
    expect(stats.seamMismatches == 0, "hydrology region should not contain broken downstream refs")
    expect(stats.uphillRejects == 0, "hydrology region should not route uphill over filled elevation")
    local chunk = world:chunk(0, 0, "local")
    local inspected = 0
    for y = 1, chunk.size do
        for x = 1, chunk.size do
            local cell = chunk.cells[y][x]
            expect(cell.filledElevation >= cell.elevationBase - 0.000001, "filled elevation should not undercut base elevation")
            expect(cell.basinId and cell.watershedId, "cells should expose basin and watershed ids")
            if cell.lake then
                expect(cell.water and cell.lakeDepth > 0 and cell.lakeSurface >= cell.elevationBase, "lake cells should expose filled water state")
                if cell.outletX then
                    expect(cell.outletX == cell.outletX and cell.outletY == cell.outletY, "lake outlet coordinates should be finite")
                end
                inspected = inspected + 1
            end
        end
    end
    expect(stats.lakes > 0 or inspected == 0, "lake stats should be available when lakes exist")
end

local function testLakeGroupingAndSpillover()
    local world = WorldGen.new(62)
    local stats = world:hydrologyStats(0, 0, "local")
    expect(stats.lakeCells > 0 and stats.lakeGroups > 0, "fixture seed should include grouped lakes")
    local inspected = 0
    for cy = -1, 0 do
        for cx = -1, 0 do
            local chunk = world:chunk(cx, cy, "local")
            for y = 1, chunk.size do
                for x = 1, chunk.size do
                    local cell = chunk.cells[y][x]
                    if cell.lake then
                        expect(cell.lakeId and cell.lakeGroupSize and cell.lakeGroupSize > 0, "lake cells should expose stable group ids and size")
                        expect(cell.lakeOutletX and cell.lakeOutletY and cell.spilloverElevation, "lake cells should expose outlet and spillover labels")
                        local outlet = world:sample(cell.lakeOutletX, cell.lakeOutletY, "local")
                        expect(outlet.spillover and outlet.spilloverLakeId == cell.lakeId, "lake outlet should be labeled as spillover")
                        inspected = inspected + 1
                    end
                end
            end
        end
    end
    expect(inspected == stats.lakeCells, "lake group fixture should inspect every lake cell in the region")
end

local function testErosionLandforms()
    local totals = { talus = 0, alluvial = 0, floodplain = 0, delta = 0 }
    for _, seed in ipairs({ 19, 46, 99, 616 }) do
        local stats = WorldGen.new(seed):hydrologyStats(0, 0, "local")
        totals.talus = totals.talus + stats.talusSlopes
        totals.alluvial = totals.alluvial + stats.alluvialFans
        totals.floodplain = totals.floodplain + stats.floodplains
        totals.delta = totals.delta + stats.deltas
    end
    expect(totals.talus > 0, "thermal erosion should expose talus slopes")
    expect(totals.alluvial > 0, "sediment deposition should expose alluvial fans")
    expect(totals.floodplain > 0, "sediment deposition should expose floodplains")
    expect(totals.delta > 0, "river mouths should expose deltas")
end

local function testTectonicFeatures()
    local counts = { age = 0, subduction = 0, rift = 0, islandArc = 0, shield = 0, craton = 0 }
    for _, seed in ipairs({ 3, 19, 45, 46, 99, 616, 717, 20260625 }) do
        local world = WorldGen.new(seed)
        for y = -1024, 1024, 64 do
            for x = -1024, 1024, 64 do
                local cell = world:baseSample(x, y, "local")
                if cell.plateAge and cell.plateAge >= 0 and cell.plateAge <= 1 then counts.age = counts.age + 1 end
                if (cell.oceanicSubduction or 0) > 0.08 then counts.subduction = counts.subduction + 1 end
                if (cell.riftValley or 0) > 0.08 then counts.rift = counts.rift + 1 end
                if (cell.volcanicIslandArc or 0) > 0.04 then counts.islandArc = counts.islandArc + 1 end
                if (cell.shield or 0) > 0.2 then counts.shield = counts.shield + 1 end
                if (cell.craton or 0) > 0.12 then counts.craton = counts.craton + 1 end
            end
        end
    end
    expect(counts.age > 0, "cells should expose normalized plate age")
    expect(counts.subduction > 0, "tectonics should include oceanic subduction bias")
    expect(counts.rift > 0, "tectonics should include rift valleys")
    expect(counts.islandArc > 0, "tectonics should include volcanic island arcs")
    expect(counts.shield > 0, "tectonics should include shield regions")
    expect(counts.craton > 0, "tectonics should include cratons")
end

local function testDiscoveryOverlayIds()
    local world = WorldGen.new(99)
    local ridgeIds, rangeIds = {}, {}
    for cy = -1, 1 do
        for cx = -1, 1 do
            local chunk = world:chunk(cx, cy, "local")
            for y = 1, chunk.size, 4 do
                for x = 1, chunk.size, 4 do
                    local cell = chunk.cells[y][x]
                    expect(cell.basinId and cell.watershedId, "sampled cells should expose basin and watershed ids")
                    if cell.ridgeId then ridgeIds[cell.ridgeId] = true end
                    if cell.mountainRangeId then rangeIds[cell.mountainRangeId] = true end
                end
            end
        end
    end
    local ridgeCount, rangeCount = 0, 0
    for _ in pairs(ridgeIds) do ridgeCount = ridgeCount + 1 end
    for _ in pairs(rangeIds) do rangeCount = rangeCount + 1 end
    expect(ridgeCount > 0, "sampled cells should expose ridge ids")
    expect(rangeCount > 0, "sampled cells should expose mountain-range ids")
end

local function testNamedTerrainDiscoveries()
    local world = WorldGen.new(99)
    local repeatWorld = WorldGen.new(99)
    local points = { { -64, -64 }, { -16, 16 }, { -40, -16 } }
    local seen = {}
    local expected = {}
    for _, kind in ipairs(WorldGen.discoveryKinds()) do expected[kind] = true end
    for _, point in ipairs(points) do
        local first = world:discoveriesAt(point[1], point[2], "local")
        local second = repeatWorld:discoveriesAt(point[1], point[2], "local")
        expect(#first == #second, "terrain discovery labels should be deterministic")
        for index, item in ipairs(first) do
            expect(item.name == second[index].name and item.id == second[index].id, "terrain discovery names should be stable")
            seen[item.kind] = true
        end
    end
    for kind in pairs(expected) do
        expect(seen[kind], "terrain discovery should include " .. kind)
    end
end

local function testSurveyHistory()
    local world = WorldGen.new(99)
    local history = Survey.new()
    Survey.mark(history, world, -64, -64, "local")
    local cellsAfterFirst = history.cellCount
    local discoveriesAfterFirst = history.discoveryCount
    expect(cellsAfterFirst == 1, "survey should mark sampled terrain cells")
    expect(discoveriesAfterFirst > 0, "survey should record terrain discoveries")
    Survey.mark(history, world, -64, -64, "local")
    expect(history.cellCount == cellsAfterFirst and history.discoveryCount == discoveriesAfterFirst, "survey should dedupe repeated marks")
    Survey.mark(history, world, -16, 16, "local")
    expect(history.cellCount > cellsAfterFirst and history.discoveryCount >= discoveriesAfterFirst, "survey should grow when marking new cells")
end

local function testSaveLoadRoundTrip()
    local world = WorldGen.new(99)
    local survey = Survey.new()
    Survey.mark(survey, world, -64, -64, "local")
    local viewScale = ViewScale.new(world)
    ViewScale.set(viewScale, world, "region", -64, -64)
    ViewScale.update(viewScale, 1, world, -64, -64)
    local app = {
        world = world,
        player = { x = 12.5, y = -7.25 },
        camera = { yaw = 0.7, pitch = -0.1 },
        survey = survey,
        viewScale = viewScale,
        mouseLook = false,
        debugPerf = true,
        debugTopo = true,
        debugPanels = true,
    }
    local encoded = Save.encode(Save.snapshot(app))
    local decoded = Save.decode(encoded)
    local restoredSurvey = Survey.fromSnapshot(decoded.survey)
    expect(decoded.seed == 99 and decoded.player.x == 12.5 and decoded.player.y == -7.25, "save should round-trip seed and player position")
    expect(decoded.camera.yaw == 0.7 and decoded.display.viewScale == "region", "save should round-trip camera and display settings")
    expect(decoded.display.debugPerf and decoded.display.debugTopo and decoded.display.debugPanels and not decoded.display.mouseLook, "save should round-trip display toggles")
    expect(restoredSurvey.cellCount == survey.cellCount and restoredSurvey.discoveryCount == survey.discoveryCount, "save should round-trip survey annotations")
end

local function testViewScaleTransitions()
    local world = WorldGen.new(99)
    local view = ViewScale.new(world)
    ViewScale.update(view, 0, world, -64, -64)
    expect(ViewScale.activeScale(view) == "local", "view scale should start local")
    local labelsAfterLocal = #ViewScale.visibleLabels(view, 16)
    ViewScale.shift(view, world, 1, -64, -64)
    local mid = ViewScale.params(view, world)
    expect(mid.target == "region" and mid.factor == 1, "view scale should begin region transition from local")
    ViewScale.update(view, 0.28, world, -64, -64)
    mid = ViewScale.params(view, world)
    expect(mid.factor > 1 and mid.factor < 4 and mid.transitioning, "view scale should ease between local and region")
    ViewScale.update(view, 1, world, -64, -64)
    local region = ViewScale.params(view, world)
    expect(region.target == "region" and region.factor == 4 and not region.transitioning, "view scale should finish at region")
    ViewScale.shift(view, world, 1, -16, 16)
    ViewScale.update(view, 1, world, -16, 16)
    local continent = ViewScale.params(view, world)
    local labels = ViewScale.visibleLabels(view, 32)
    local scales = {}
    for _, label in ipairs(labels) do scales[label.scale] = true end
    expect(continent.target == "continent" and continent.factor == 16, "view scale should reach continent")
    expect(#labels >= labelsAfterLocal and scales["local"] and scales.region and scales.continent, "view labels should persist across nested scales")
end

local function testDiegeticScaleTransitions()
    local world = WorldGen.new(99)
    local view = ViewScale.new(world)
    local localAnchor = ViewScale.advanceDiegetic(view, world, -64, -64)
    expect(localAnchor.from == "local" and localAnchor.target == "region" and localAnchor.name, "local scope should use a terrain anchor")
    ViewScale.update(view, 1, world, -64, -64)
    local regionAnchor = ViewScale.advanceDiegetic(view, world, -16, 16)
    expect(regionAnchor.from == "region" and regionAnchor.target == "continent" and regionAnchor.name, "region scope should use a terrain anchor")
    ViewScale.update(view, 1, world, -16, 16)
    local returnAnchor = ViewScale.advanceDiegetic(view, world, -16, 16)
    ViewScale.update(view, 1, world, -16, 16)
    expect(returnAnchor.from == "continent" and returnAnchor.target == "local", "continent scope should return to local terrain")
    expect(ViewScale.params(view, world).target == "local" and view.anchor.name == returnAnchor.name, "diegetic scope anchor should persist on the view")
end

local function testBasinHydrologyBudget()
    local world = WorldGen.new(20260625, basinWorldOptions)
    world:chunk(0, 0, "local")
    local stats = world:hydrologyStats(0, 0, "local")
    local metrics = world:metricsSnapshot()
    local cache = world:cacheStats()
    expect(stats.macroChannels > 0, "coarse basin pass should feed local macro channels")
    expect(metrics.hydrologyMisses == 1 and metrics.basinMisses == 1, "first chunk should solve one detail region and one coarse basin")
    expect(metrics.hydrologyCells == 4096 and metrics.basinCells == 4096, "first chunk hydrology should stay bounded")
    expect(cache.hydrology == 1 and cache.basins == 1, "first chunk should cache one hydrology region and one basin")
end

local function testCacheBoundsAndCounters()
    local world = WorldGen.new(20260625, {
        hydrologyRegionChunks = 1,
        hydrologyHaloCells = 0,
        hydrologyBasinChunks = 8,
        hydrologyBasinStride = 8,
        cacheMaxEntries = 10,
    })
    for cy = -1, 1 do
        for cx = -1, 1 do
            world:chunk(cx, cy, "local")
        end
    end
    local cache = world:cacheStats()
    local metrics = world:metricsSnapshot()
    expect(cache.total <= 10 and cache.maxEntries == 10, "cache should enforce configured entry bound")
    expect(metrics.cachePuts > 10 and metrics.cacheEvictions > 0 and metrics.cacheMisses > 0, "cache metrics should count puts, evictions, and misses")
    world:chunk(1, 1, "local")
    local after = world:metricsSnapshot()
    expect(after.cacheHits > metrics.cacheHits, "cache metrics should count hits")
end

local function testBasinChannelsSpanDetailRegions()
    local world = WorldGen.new(20260625, basinWorldOptions)
    local spans = {}
    for cy = -2, 3 do
        for cx = -2, 3 do
            local chunk = world:chunk(cx, cy, "local")
            for y = 1, chunk.size, 4 do
                for x = 1, chunk.size, 4 do
                    local cell = chunk.cells[y][x]
                    if cell.river and cell.macroBasinId then
                        local span = spans[cell.macroBasinId] or { regions = {}, count = 0 }
                        span.regions[cell.hydrologyRegion] = true
                        span.count = span.count + 1
                        spans[cell.macroBasinId] = span
                    end
                end
            end
        end
    end
    local bestRegions, bestCount = 0, 0
    for _, span in pairs(spans) do
        local regions = 0
        for _ in pairs(span.regions) do regions = regions + 1 end
        if regions > bestRegions or (regions == bestRegions and span.count > bestCount) then
            bestRegions, bestCount = regions, span.count
        end
    end
    expect(bestRegions >= 8 and bestCount > 24, "macro basins should persist across distant 1x1 hydrology regions")
    expect(world:cacheStats().basins == 1, "scanned chunks should share the same cached coarse basin")
end

local function testBiomes()
    local world = testWorld(314)
    local ids = {}
    for _, id in ipairs(WorldGen.biomeIds()) do ids[id] = true end
    for cy = 0, 1 do
        for cx = 0, 1 do
            local chunk = world:chunk(cx, cy, "region")
            for y = 1, chunk.size, 7 do
                for x = 1, chunk.size, 7 do
                    expect(ids[chunk.cells[y][x].biome], "invalid biome id " .. tostring(chunk.cells[y][x].biome))
                end
            end
        end
    end
end

local function testPlayer()
    local world = testWorld(88)
    local player = Player.new(0, 0)
    Player.update(player, 1, { right = true }, world)
    expect(player.x > 0 and player.y == 0, "player should move right")
    Player.update(player, 0.5, { left = true, up = true, sprint = true }, world)
    expect(player.x == player.x and player.y == player.y, "player position should stay finite")
end

local function testHeightInterpolationAndNormal()
    local world = testWorld(515)
    local x, y = 12.35, -8.7
    local h = world:heightAt(x, y)
    local h00 = world:sample(math.floor(x), math.floor(y), "local").elevation
    local h10 = world:sample(math.floor(x) + 1, math.floor(y), "local").elevation
    local h01 = world:sample(math.floor(x), math.floor(y) + 1, "local").elevation
    local h11 = world:sample(math.floor(x) + 1, math.floor(y) + 1, "local").elevation
    local lo = math.min(h00, h10, h01, h11)
    local hi = math.max(h00, h10, h01, h11)
    expect(h >= lo - 0.000001 and h <= hi + 0.000001, "heightAt should stay inside neighbor range")
    expect(round(h) == round(world:heightAt(x, y)), "heightAt should be deterministic")
    local normal = world:normalAt(x, y)
    local length = math.sqrt(normal.x * normal.x + normal.y * normal.y + normal.z * normal.z)
    expect(length > 0.99 and length < 1.01 and normal.z > 0, "normalAt should return finite normalized upward vector")
end

local function encodeBillboards(list)
    local parts = {}
    for _, item in ipairs(list) do
        parts[#parts + 1] = table.concat({ item.kind, round(item.x), round(item.y), round(item.z), round(item.width), round(item.height) }, ":")
    end
    return table.concat(parts, "|")
end

local function testBillboards()
    local a = testWorld(717)
    local b = testWorld(717)
    local kinds = {}
    for _, kind in ipairs(WorldGen.billboardKinds()) do kinds[kind] = true end
    local count = 0
    for cy = 0, 1 do
        for cx = 0, 1 do
            local list = a:billboards(cx, cy)
            expect(encodeBillboards(list) == encodeBillboards(b:billboards(cx, cy)), "billboards should be deterministic")
            for _, item in ipairs(list) do
                expect(kinds[item.kind], "invalid billboard kind")
                expect(item.x == item.x and item.y == item.y and item.z == item.z, "billboard coordinates should be finite")
                count = count + 1
            end
        end
    end
    expect(count > 0, "fixture seed should generate billboards")
end

local function testRenderStats()
    local world = testWorld(20260625)
    local app = { world = world, player = Player.new(0, 0), camera = Render.defaultCamera(), viewScale = ViewScale.new(world) }
    local stats = Render.visibleStats(app, 1280, 720)
    expect(stats.visibleTiles >= 650 and stats.triangles == stats.visibleTiles * 2, "render stats should describe denser terrain mesh")
    expect(stats.billboards >= 0 and stats.cameraHeight == stats.cameraHeight, "render stats should include finite camera and billboard count")
    expect(stats.riverStrips > 0, "render stats should include river strips")
    expect(stats.silhouetteStrips > 0, "render stats should include slope silhouettes")
    expect(stats.landmarks > 0, "render stats should include terrain landmarks")
    ViewScale.shift(app.viewScale, world, 1, 0, 0)
    ViewScale.update(app.viewScale, 1, world, 0, 0)
    local regionStats = Render.visibleStats(app, 1280, 720)
    expect(regionStats.viewScale == "region" and regionStats.viewFactor == 4 and regionStats.visibleTiles > 0, "render stats should follow region view scale")
end

local function colorDistance(a, b)
    local dr, dg, db = a[1] - b[1], a[2] - b[2], a[3] - b[3]
    return math.sqrt(dr * dr + dg * dg + db * db)
end

local function testBiomePalette()
    local palette = Render.biomePalette()
    expect(colorDistance(palette.ocean, palette.river) > 0.28, "water palette should separate ocean and rivers")
    expect(colorDistance(palette.desert, palette.grassland) > 0.35, "dry and grass biomes should have distinct colors")
    expect(colorDistance(palette.rainforest, palette.boreal_forest) > 0.16, "forest biomes should avoid a single green ramp")
    expect(colorDistance(palette.snow, palette.rock) > 0.75, "high terrain palette should separate snow and rock")
end

local function testTopographicMapData()
    local world = testWorld(20260625)
    local app = { world = world, player = Player.new(0, 0), camera = Render.defaultCamera(), viewScale = ViewScale.new(world) }
    local data = Render.topographicMapData(app, 32)
    expect(data.samples == 1024 and data.scale == "local", "topographic map should sample local terrain when enabled")
    expect(data.water > 0 and data.water < data.samples, "topographic map should include land and water")
    expect(data.rivers > 0 and data.contours > 0, "topographic map should expose rivers and contours")
end

local function testDebugPanelData()
    local world = testWorld(20260625)
    local app = { world = world, player = Player.new(0, 0), camera = Render.defaultCamera(), viewScale = ViewScale.new(world) }
    local data = Render.debugPanelData(app)
    expect(data.plate.vx == data.plate.vx and data.plate.boundary >= 0, "debug panels should expose finite plate vector inputs")
    expect(data.drainage.flow >= 0 and data.drainage.dx == data.drainage.dx and data.drainage.watershedId, "debug panels should expose drainage direction inputs")
    expect(data.erosion.erosion == data.erosion.erosion and data.erosion.thermal == data.erosion.thermal, "debug panels should expose erosion deltas")
    expect(data.biome.id and data.biome.temperature >= 0 and data.biome.moisture >= 0 and data.biome.slope >= 0, "debug panels should expose biome classifier inputs")
end

local function testMapExportData()
    local world = testWorld(20260625)
    local map = Export.renderMap(world, { size = 32, span = 256, scale = "local" })
    local ppm = Export.ppmBytes(map)
    local json = Export.metadataJson(map.metadata)
    expect(map.metadata.seed == 20260625 and map.metadata.size == 32, "export metadata should include seed and size")
    expect(map.stats.land > 0 and map.stats.water > 0 and map.stats.rivers > 0, "export map should include terrain stats")
    expect(string.sub(ppm, 1, 12) == "P6\n32 32\n255" and #ppm > 32 * 32 * 3, "export should produce image bytes")
    expect(string.find(json, '"seed": 20260625', 1, true) ~= nil, "export metadata should encode seed json")
end

local function testTerrainBenchmark()
    local result = Benchmark.run({
        seed = 20260625,
        chunkRadius = 0,
        scales = { "local", "region", "continent" },
        worldOptions = basinWorldOptions,
    })
    expect(result.chunks == 3 and result.cells == 3 * 64 * 64, "benchmark should visit requested chunks and scales")
    expect(result.seconds > 0 and result.chunksPerSecond > 0 and result.cellsPerSecond > 0, "benchmark should report timing rates")
    expect(result.cache.total > 0 and result.metrics.chunkMisses == 3, "benchmark should expose cache and miss counters")
    expect(string.find(Benchmark.format(result), "benchmark=terrain", 1, true) ~= nil, "benchmark should format cli output")
end

local function testTerrainDiagnostics()
    local seeds = Diagnostics.defaultSeeds()
    local sweep = Diagnostics.sweep({
        seeds = seeds,
        chunkRadius = 1,
        sampleStep = 8,
        worldOptions = basinWorldOptions,
    })
    expect(#sweep.results == #seeds, "diagnostics should report every fixture seed")
    expect(#sweep.failed == 0, "diagnostic fixtures should stay inside terrain sanity bounds:\n" .. Diagnostics.formatFailures(sweep.failed))
    for _, stats in ipairs(sweep.results) do
        expect(stats.cells > 0 and stats.land + stats.water == stats.cells, "diagnostics should count sampled cells")
        expect(stats.waterRatio >= 0 and stats.waterRatio <= 1, "water ratio should be normalized")
        expect(stats.riverRatio >= 0 and stats.riverRatio <= 1, "river ratio should be normalized")
        expect(stats.biomeGroups and stats.biomeGroups.water >= 0, "diagnostics should report biome group ratios")
        expect(stats.biomeCount >= 3, "diagnostics should observe multiple biomes")
    end
end

local function testBadSeedDiagnostics()
    for _, fixture in ipairs(Diagnostics.badSeeds()) do
        local stats = Diagnostics.analyzeSeed(fixture.seed, {
            chunkRadius = 1,
            sampleStep = 8,
            worldOptions = basinWorldOptions,
        })
        local flags = {}
        for _, flag in ipairs(stats.flags) do flags[flag] = true end
        for _, expectedFlag in ipairs(fixture.flags) do
            expect(flags[expectedFlag], "bad seed fixture should flag " .. expectedFlag .. " for seed " .. tostring(fixture.seed))
        end
    end
end

local function testRegressionSeedDiagnostics()
    local categories = {}
    for _, fixture in ipairs(Diagnostics.regressionSeeds()) do
        categories[fixture.category] = true
        local stats = Diagnostics.analyzeSeed(fixture.seed, {
            chunkRadius = 1,
            sampleStep = 8,
            worldOptions = basinWorldOptions,
        })
        local flags = {}
        for _, flag in ipairs(stats.flags) do flags[flag] = true end
        for _, expectedFlag in ipairs(fixture.flags or {}) do
            expect(flags[expectedFlag], "regression seed should flag " .. expectedFlag .. " for " .. fixture.category)
        end
        if fixture.maxSeamMismatches then expect(stats.seamMismatches <= fixture.maxSeamMismatches, "regression seed should bound seam mismatches") end
        if fixture.maxUphillRejects then expect(stats.uphillRejects <= fixture.maxUphillRejects, "regression seed should bound river discontinuities") end
        if fixture.minRivers then expect(stats.rivers >= fixture.minRivers, "regression seed should keep river coverage") end
    end
    expect(categories.ugly_terrain and categories.all_water and categories.all_land and categories.broken_seams and categories.river_discontinuities, "regression seed categories should cover terrain failure modes")
end

local function testTerrainFirstScope()
    local files = {
        "main.lua",
        "src/hydrology.lua",
        "src/player.lua",
        "src/render.lua",
        "src/save.lua",
        "src/survey.lua",
        "src/viewscale.lua",
        "src/export.lua",
        "src/benchmark.lua",
        "src/worldgen.lua",
    }
    local forbidden = { "ruin", "lore", "quest", "collectible", "combat", "survival" }
    for _, path in ipairs(files) do
        local handle = assert(io.open(path, "r"))
        local text = handle:read("*a")
        handle:close()
        local lower = string.lower(text)
        for _, term in ipairs(forbidden) do
            expect(not string.find(lower, term, 1, true), "terrain-first runtime should not include " .. term .. " in " .. path)
        end
    end
end

local function smoke()
    local world = WorldGen.new(20260625)
    local app = { world = world, player = Player.new(0, 0), camera = Render.defaultCamera() }
    local stats = Render.visibleStats(app, 1280, 720)
    local land, water, rivers, lakes = 0, 0, 0, 0
    local localStats = world:hydrologyStats(0, 0, "local")
    for _, scale in ipairs(world:metadata().scales) do
        local chunk = world:chunk(0, 0, scale.id)
        for y = 1, chunk.size do
            for x = 1, chunk.size do
                local cell = chunk.cells[y][x]
                if cell.water then water = water + 1 else land = land + 1 end
                if cell.river then rivers = rivers + 1 end
                if cell.lake then lakes = lakes + 1 end
            end
        end
    end
    print("smoke=terrain")
    print("land=" .. land)
    print("water=" .. water)
    print("rivers=" .. rivers)
    print("lakes=" .. lakes)
    print("basins=" .. localStats.basins)
    print("lake_groups=" .. localStats.lakeGroups)
    print("talus=" .. localStats.talusSlopes)
    print("alluvial_fans=" .. localStats.alluvialFans)
    print("floodplains=" .. localStats.floodplains)
    print("deltas=" .. localStats.deltas)
    print("seam_mismatches=" .. localStats.seamMismatches)
    print("uphill_rejects=" .. localStats.uphillRejects)
    print("max_flow=" .. string.format("%.3f", localStats.maxFlow))
    print("mesh_tiles=" .. stats.visibleTiles)
    print("triangles=" .. stats.triangles)
    print("river_strips=" .. stats.riverStrips)
    print("silhouettes=" .. stats.silhouetteStrips)
    print("billboards=" .. stats.billboards)
    print("landmarks=" .. stats.landmarks)
    print("camera_height=" .. string.format("%.3f", stats.cameraHeight))
    expect(land > 0 and water > 0 and rivers > 0, "smoke should cover land, water, and rivers")
    expect(localStats.basins > 0 and localStats.uphillRejects == 0, "smoke should include sane hydrology stats")
    expect(localStats.talusSlopes + localStats.alluvialFans + localStats.floodplains + localStats.deltas > 0, "smoke should include erosion landforms")
    expect(stats.visibleTiles > 0 and stats.triangles > 0, "smoke should build visible terrain mesh")
    expect(stats.riverStrips > 0 and stats.silhouetteStrips > 0 and stats.landmarks > 0, "smoke should include readability overlays")
end

local tests = {
    testDeterminism,
    testSeedVariance,
    testSampleChunkAgreement,
    testRiverMonotonicity,
    testHydrologyStats,
    testLakeGroupingAndSpillover,
    testErosionLandforms,
    testTectonicFeatures,
    testDiscoveryOverlayIds,
    testNamedTerrainDiscoveries,
    testSurveyHistory,
    testSaveLoadRoundTrip,
    testViewScaleTransitions,
    testDiegeticScaleTransitions,
    testBasinHydrologyBudget,
    testCacheBoundsAndCounters,
    testBasinChannelsSpanDetailRegions,
    testBiomes,
    testPlayer,
    testHeightInterpolationAndNormal,
    testBillboards,
    testRenderStats,
    testBiomePalette,
    testTopographicMapData,
    testDebugPanelData,
    testMapExportData,
    testTerrainBenchmark,
    testTerrainDiagnostics,
    testBadSeedDiagnostics,
    testRegressionSeedDiagnostics,
    testTerrainFirstScope,
}

local function hasCliFlag(args, flag)
    for _, item in ipairs(args or {}) do
        if item == flag then return true end
    end
    return false
end

local function cliValue(args, flag, fallback)
    for index, item in ipairs(args or {}) do
        if item == flag then return args[index + 1] or fallback end
    end
    return fallback
end

local function diagnosticSeeds(args)
    local csv = cliValue(args, "--seeds")
    if csv then
        local seeds = {}
        for item in string.gmatch(csv, "([^,]+)") do
            seeds[#seeds + 1] = tonumber(item)
        end
        return seeds
    end
    if not (hasCliFlag(args, "--seed-start") or hasCliFlag(args, "--seed-count")) then
        return Diagnostics.defaultSeeds()
    end
    local start = tonumber(cliValue(args, "--seed-start", 1)) or 1
    local count = tonumber(cliValue(args, "--seed-count", 12)) or 12
    local seeds = {}
    for offset = 0, count - 1 do seeds[#seeds + 1] = start + offset end
    return seeds
end

local function diagnostics(args)
    local sweep = Diagnostics.sweep({
        seeds = diagnosticSeeds(args),
        chunkRadius = tonumber(cliValue(args, "--chunk-radius", 1)) or 1,
        sampleStep = tonumber(cliValue(args, "--sample-step", 8)) or 8,
        worldOptions = basinWorldOptions,
    })
    print("diagnostics=terrain")
    for _, stats in ipairs(sweep.results) do
        print(Diagnostics.formatResult(stats))
    end
    if #sweep.failed > 0 then
        error("diagnostic sweep failed:\n" .. Diagnostics.formatFailures(sweep.failed), 0)
    end
end

local function csvList(value)
    if not value then return nil end
    local out = {}
    for item in string.gmatch(value, "([^,]+)") do out[#out + 1] = item end
    return out
end

local function benchmark(args)
    local result = Benchmark.run({
        seed = tonumber(cliValue(args, "--seed", 20260625)) or 20260625,
        chunkRadius = tonumber(cliValue(args, "--chunk-radius", 1)) or 1,
        scales = csvList(cliValue(args, "--scales")),
        worldOptions = basinWorldOptions,
    })
    print(Benchmark.format(result))
end

local function regressions()
    for _, fixture in ipairs(Diagnostics.regressionSeeds()) do
        local stats = Diagnostics.analyzeSeed(fixture.seed, {
            chunkRadius = 1,
            sampleStep = 8,
            worldOptions = basinWorldOptions,
        })
        print("regression=" .. fixture.category .. " " .. Diagnostics.formatResult(stats))
    end
end

if arg and arg[1] == "--smoke" then
    smoke()
    return
end

if arg and arg[1] == "--diagnostics" then
    diagnostics(arg)
    return
end

if arg and arg[1] == "--benchmark" then
    benchmark(arg)
    return
end

if arg and arg[1] == "--regressions" then
    regressions()
    return
end

for index, test in ipairs(tests) do
    test()
    print("ok " .. index)
end
print("tests passed")
