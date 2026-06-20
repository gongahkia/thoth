local Defs = require("src.game.defs")
local Grid = require("src.core.grid")
local Rng = require("src.core.rng")

local World = {}
World.__index = World
World.chunkSize = 32

local function tile(id, data)
    return { id = id, data = data or 0 }
end

local function cloneTile(value)
    return { id = value.id, data = value.data or 0 }
end

local function deepCopy(value)
    if type(value) ~= "table" then
        return value
    end
    local result = {}
    for key, entry in pairs(value) do
        result[key] = deepCopy(entry)
    end
    return result
end

local function inRoom(x, y, room)
    return math.abs(x - room.x) <= room.w and math.abs(y - room.y) <= room.h
end

local function inCorridor(x, y, corridor)
    if corridor.ay == corridor.by and y == corridor.ay then
        return x >= math.min(corridor.ax, corridor.bx) and x <= math.max(corridor.ax, corridor.bx)
    end
    if corridor.ax == corridor.bx and x == corridor.ax then
        return y >= math.min(corridor.ay, corridor.by) and y <= math.max(corridor.ay, corridor.by)
    end
    if y == corridor.ay and x >= math.min(corridor.ax, corridor.bx) and x <= math.max(corridor.ax, corridor.bx) then
        return true
    end
    if x == corridor.bx and y >= math.min(corridor.ay, corridor.by) and y <= math.max(corridor.ay, corridor.by) then
        return true
    end
    return false
end

local function parseRoomKey(key)
    local x, y = tostring(key or ""):match("^(-?%d+):(-?%d+)$")
    return tonumber(x), tonumber(y)
end

local function rectContains(x, y, rect)
    return x >= rect.x - rect.w and x <= rect.x + rect.w and y >= rect.y - rect.h and y <= rect.y + rect.h
end

local function bridgeContains(x, y, bridge)
    local minX = math.min(bridge.ax, bridge.bx)
    local maxX = math.max(bridge.ax, bridge.bx)
    local minY = math.min(bridge.ay, bridge.by)
    local maxY = math.max(bridge.ay, bridge.by)
    local width = bridge.width or 1
    if bridge.ay == bridge.by then
        return x >= minX and x <= maxX and math.abs(y - bridge.ay) <= width
    end
    if bridge.ax == bridge.bx then
        return y >= minY and y <= maxY and math.abs(x - bridge.ax) <= width
    end
    return false
end

local function append(list, value)
    list[#list + 1] = value
    return value
end

local function buildMegastructureLayout(base, seed, layoutId)
    local rng = Rng.new(seed + #tostring(layoutId or "") * 97 + 17031)
    local platforms = {}
    local bridges = {}
    local overlooks = {}
    local monuments = {}
    local hidden = {}
    for _, room in ipairs(base.rooms or {}) do
        local wide = rng:range(0, 2)
        append(platforms, { x = room.x, y = room.y, w = room.w + 2 + wide, h = room.h + 1 + rng:range(0, 2), tile = base.floorTile })
        if rng:range(1, 100) <= 70 then
            local side = rng:range(0, 3)
            local dx = side == 0 and room.w + 5 or (side == 1 and -(room.w + 5) or 0)
            local dy = side == 2 and room.h + 4 or (side == 3 and -(room.h + 4) or 0)
            local overlook = append(overlooks, { x = room.x + dx, y = room.y + dy, w = 2 + rng:range(0, 1), h = 2 + rng:range(0, 1), tile = base.floorTile, roomKey = room.key })
            append(bridges, { ax = room.x, ay = room.y, bx = overlook.x, by = overlook.y, width = 1, tile = base.corridorTile or base.floorTile, role = "overlook" })
        end
        if rng:range(1, 100) <= 55 then
            local side = rng:range(0, 3)
            local sx = rng:range(0, 1) == 0 and -1 or 1
            local sy = rng:range(0, 1) == 0 and -1 or 1
            local mx = room.x + (side == 0 and room.w + 2 or (side == 1 and -(room.w + 2) or sx * (room.w + 1)))
            local my = room.y + (side == 2 and room.h + 2 or (side == 3 and -(room.h + 2) or sy * (room.h + 1)))
            append(monuments, { x = mx, y = my, tile = base.occluderTile or base.wallTile, roomKey = room.key })
        end
    end
    for _, corridor in ipairs(base.corridors or {}) do
        append(bridges, { ax = corridor.ax, ay = corridor.ay, bx = corridor.bx, by = corridor.by, width = rng:range(1, 2), tile = base.corridorTile or base.floorTile, role = corridor.role })
        if rng:range(1, 100) <= 45 then
            local mx = math.floor((corridor.ax + corridor.bx) / 2 + 0.5)
            local my = math.floor((corridor.ay + corridor.by) / 2 + 0.5)
            local side = rng:range(0, 1) == 0 and -1 or 1
            if corridor.ay == corridor.by then
                my = my + side * rng:range(3, 5)
            else
                mx = mx + side * rng:range(3, 5)
            end
            append(platforms, { x = mx, y = my, w = 2, h = 2, tile = base.floorTile })
            append(bridges, { ax = math.floor((corridor.ax + corridor.bx) / 2 + 0.5), ay = math.floor((corridor.ay + corridor.by) / 2 + 0.5), bx = mx, by = my, width = 1, tile = base.corridorTile or base.floorTile, role = "side_span" })
        end
    end
    local cacheTile = base.rotationCacheTile or base.rewardTile
    if cacheTile then
        local rooms = base.rooms or {}
        local room = rooms[#rooms > 0 and rng:range(1, #rooms) or 1]
        if room then
            local x = room.x + room.w + 3
            local y = room.y + rng:range(-room.h, room.h)
            append(hidden, { x = x, y = y, z = 0, tile = cacheTile, hiddenBehind = true, revealRotations = { rng:range(0, 3) } })
            append(monuments, { x = x + 1, y = y - 1, tile = base.occluderTile or base.wallTile, roomKey = room.key })
            append(platforms, { x = x, y = y, w = 1, h = 1, tile = base.floorTile })
        end
    end
    return { platforms = platforms, bridges = bridges, overlooks = overlooks, monuments = monuments, hidden = hidden }
end

function World.new(seed, locationKey, overrides)
    if type(locationKey) == "table" and overrides == nil then
        overrides = locationKey
        locationKey = "buried_archive"
    end
    local layoutId = nil
    if type(overrides) == "table" and (overrides.layoutId or overrides.tiles) then
        layoutId = overrides.layoutId
        overrides = overrides.tiles or {}
    end
    return setmetatable({ seed = seed or 1, location = locationKey or "buried_archive", layoutId = layoutId, overrides = overrides or {}, chunks = {}, chunkRevisions = {}, generatedLayout = nil }, World)
end

function World.floorDiv(value, divisor)
    return math.floor(value / divisor)
end

function World.floorMod(value, divisor)
    return value - World.floorDiv(value, divisor) * divisor
end

function World.chunkKey(cx, cy, z)
    return tostring(z or 0) .. ":" .. tostring(cx) .. ":" .. tostring(cy)
end

function World:layout()
    local location = Defs.locations[self.location] or Defs.locations.buried_archive
    local layout = location.layout
    if layout and layout.generator == "mission_grammar" then
        return self:missionGrammarLayout(location)
    end
    if layout and layout.grammar and self.layoutId then
        return self:staticMissionLayout(location)
    end
    return layout
end

function World:staticMissionLayout(location)
    if self.generatedLayout then
        return self.generatedLayout
    end
    local base = deepCopy(location.layout)
    local layoutId = self.layoutId or ""
    base.generated = true
    base.generatedLayoutId = (base.grammar and base.grammar.id or "static_layout") .. ":" .. layoutId
    base.roomTemplateByRole = {}
    for templateKey, template in pairs(base.roomTemplates or {}) do
        if template.role then
            base.roomTemplateByRole[template.role] = templateKey
        end
    end
    base.encounters = deepCopy(location.encounters or {})
    if layoutId == "cistern_silence_choir" then
        base.encounters["6:10"] = "cistern_choir"
        base.encounters["18:10"] = nil
    elseif layoutId == "cistern_drain_market" then
        base.encounters["12:10"] = "cistern_market"
        base.encounters["6:10"] = "cistern_cyst"
    elseif layoutId == "cistern_flood_bailiff" then
        base.encounters["18:4"] = "cistern_bailiff"
    elseif layoutId == "cistern_open_deep_sluice" then
        base.encounters["18:4"] = "cistern_bailiff"
        base.encounters["18:10"] = "matron"
    elseif layoutId == "warrens_douse_vicar" then
        base.encounters["8:-8"] = "ember_vicar"
        base.encounters["20:-8"] = nil
    elseif layoutId == "warrens_open_furnace" then
        base.encounters["20:4"] = "ember_furnace"
        base.encounters["20:-8"] = "prioress"
    elseif layoutId == "warrens_burn_false_vow" then
        base.encounters["14:-4"] = "ember_swarm"
    elseif layoutId == "ember_vow_kilns" then
        base.encounters["8:0"] = "ember_kiln"
    elseif layoutId == "ember_ash_names" or layoutId == "warrens_warm_ledger" then
        base.encounters["14:4"] = "ember_clinker"
    elseif layoutId == "warrens_aron_boy" then
        base.encounters["8:-8"] = "ember_branch"
    end
    for _, corridor in ipairs(base.corridors or {}) do
        local a = tostring(corridor.ax) .. ":" .. tostring(corridor.ay)
        local b = tostring(corridor.bx) .. ":" .. tostring(corridor.by)
        corridor.key = a < b and (a .. ">" .. b) or (b .. ">" .. a)
    end
    base.occluderTile = base.occluderTile or (base.wallTile == "archive_wall" and "archive_monolith" or base.wallTile)
    base.rotationCacheTile = base.rotationCacheTile or (base.wallTile == "archive_wall" and "rotation_cache" or (base.wallTile == "salt_wall" and "brine_reliquary" or "ember_reliquary"))
    base.megastructure = buildMegastructureLayout(base, self.seed or 1, layoutId)
    base.specials = deepCopy(base.specials or {})
    for _, monument in ipairs(base.megastructure.monuments or {}) do
        base.specials[#base.specials + 1] = { x = monument.x, y = monument.y, z = 0, tile = monument.tile, roomKey = monument.roomKey }
    end
    for _, hidden in ipairs(base.megastructure.hidden or {}) do
        base.specials[#base.specials + 1] = hidden
    end
    self.generatedLayout = base
    return base
end

function World:missionGrammarLayout(location)
    if self.generatedLayout then
        return self.generatedLayout
    end
    local base = deepCopy(location.layout)
    local roles = base.roles or {}
    local layoutId = self.layoutId or "archive_scout"
    local mission = Defs.mission(layoutId) or {}
    local variant = Rng.hash(self.seed + 4201, #layoutId, 0, 0) % 3
    base.generated = true
    base.generatedLayoutId = (base.grammar and base.grammar.id or "mission_grammar") .. ":" .. layoutId .. ":" .. tostring(variant)
    base.occluderTile = base.occluderTile or (base.wallTile == "archive_wall" and "archive_monolith" or base.wallTile)
    base.rotationCacheTile = base.rotationCacheTile or (base.wallTile == "archive_wall" and "rotation_cache" or (base.wallTile == "salt_wall" and "brine_reliquary" or "ember_reliquary"))
    base.roomTemplateByRole = {}
    for templateKey, template in pairs(base.roomTemplates or {}) do
        if template.role then
            base.roomTemplateByRole[template.role] = templateKey
        end
    end
    base.encounters = {
        [roles.lock_gate or "8:0"] = "entry",
        [roles.scout_branch or "0:8"] = "archive_branch",
        [roles.reward_dead_end or "16:0"] = "stacks",
        [roles.boss_gate or location.bossRoom or "24:0"] = "regent",
    }
    if mission.noBossGate then
        base.encounters[roles.boss_gate or location.bossRoom or "24:0"] = nil
    end
    if layoutId == "archive_cleansing" then
        base.encounters[roles.risky_shortcut or "16:6"] = "undercroft"
    elseif layoutId == "archive_false_index" then
        base.encounters[roles.lock_gate or "8:0"] = "archive_snare"
    elseif layoutId == "archive_silence_reeve" then
        base.encounters[roles.camp_fallback or "8:6"] = "archive_reeve"
        base.encounters[roles.boss_gate or location.bossRoom or "24:0"] = nil
    elseif layoutId == "archive_witness_confession" then
        base.encounters[roles.camp_fallback or "8:6"] = "archive_witness"
        base.encounters[roles.alpha_roost or "24:6"] = "archive_bailiff"
    elseif layoutId == "archive_remand_scribe" then
        base.encounters[roles.lock_gate or "8:0"] = "archive_bailiff"
    elseif layoutId == "archive_misfiled_dead" then
        base.encounters[roles.risky_shortcut or "16:6"] = "archive_elite"
    elseif layoutId == "archive_audit_page_bearer" then
        base.encounters[roles.alpha_roost or "24:6"] = "archive_hounds"
    end
    local function sameEdge(a, b, roleA, roleB)
        return (a == (roles[roleA] or "") and b == (roles[roleB] or ""))
            or (b == (roles[roleA] or "") and a == (roles[roleB] or ""))
    end
    for _, corridor in ipairs(base.corridors or {}) do
        local a = tostring(corridor.ax) .. ":" .. tostring(corridor.ay)
        local b = tostring(corridor.bx) .. ":" .. tostring(corridor.by)
        corridor.key = a < b and (a .. ">" .. b) or (b .. ">" .. a)
        if sameEdge(a, b, "entrance", "scout_branch") then
            corridor.role = "shelf_crawl"
        elseif sameEdge(a, b, "lock_gate", "reward_dead_end") or sameEdge(a, b, "reward_dead_end", "boss_gate") then
            corridor.role = "audit_lane"
        elseif sameEdge(a, b, "camp_fallback", "risky_shortcut") or sameEdge(a, b, "risky_shortcut", "alpha_roost") then
            corridor.role = "writ_run"
        elseif b == (roles.boss_gate or "24:0") or a == (roles.boss_gate or "24:0") then
            corridor.role = "boss_gate"
        else
            corridor.role = corridor.role or "path"
        end
    end
    local threats = {}
    for _, threat in ipairs(base.threats or {}) do
        local roomKey = roles[threat.roomRole or ""] or threat.roomKey
        local include = not threat.rare or (Rng.hash(self.seed + 4301, #layoutId, threat.x or 0, threat.y or 0) % 100) < 45
        if roomKey and include then
            local entry = deepCopy(threat)
            entry.roomKey = roomKey
            entry.z = entry.z or 0
            threats[#threats + 1] = entry
        end
    end
    base.threats = threats
    base.megastructure = buildMegastructureLayout(base, self.seed or 1, layoutId)
    base.specials = deepCopy(base.specials or {})
    for _, monument in ipairs(base.megastructure.monuments or {}) do
        base.specials[#base.specials + 1] = { x = monument.x, y = monument.y, z = 0, tile = monument.tile, roomKey = monument.roomKey }
    end
    for _, hidden in ipairs(base.megastructure.hidden or {}) do
        base.specials[#base.specials + 1] = hidden
    end
    self.generatedLayout = base
    return base
end

function World:floorTile()
    return self:layout().floorTile or "archive_floor"
end

function World:wallTile()
    return self:layout().wallTile or "archive_wall"
end

function World:roomAt(x, y)
    for _, room in ipairs(self:layout().rooms or {}) do
        if inRoom(x, y, room) then
            return room.key, room
        end
    end
    return nil, nil
end

function World:roomCenters()
    local result = {}
    for _, room in ipairs(self:layout().rooms or {}) do
        result[#result + 1] = { key = room.key, x = room.x, y = room.y }
    end
    return result
end

function World:connectedRooms(roomKey)
    local result = {}
    local seen = {}
    for _, corridor in ipairs(self:layout().corridors or {}) do
        local a = tostring(corridor.ax) .. ":" .. tostring(corridor.ay)
        local b = tostring(corridor.bx) .. ":" .. tostring(corridor.by)
        local other = nil
        if a == roomKey then
            other = b
        elseif b == roomKey then
            other = a
        end
        if other and not seen[other] then
            seen[other] = true
            result[#result + 1] = other
        end
    end
    table.sort(result)
    return result
end

function World:corridorAt(x, y)
    for _, corridor in ipairs(self:layout().corridors or {}) do
        if inCorridor(x, y, corridor) then
            return corridor
        end
    end
    return nil
end

function World:encounterForRoom(roomKey)
    if not roomKey then
        return nil
    end
    local layout = self:layout()
    if layout.encounters then
        return layout.encounters[roomKey]
    end
    local location = Defs.locations[self.location] or Defs.locations.buried_archive
    return location.encounters and location.encounters[roomKey] or nil
end

function World:specialAt(x, y, z)
    for _, special in ipairs(self:layout().specials or {}) do
        if special.x == x and special.y == y and (special.z or 0) == (z or 0) then
            return special
        end
    end
    return nil
end

function World:specialsInRect(minX, maxX, minY, maxY, z)
    local result = {}
    for _, special in ipairs(self:layout().specials or {}) do
        if special.x >= minX and special.x <= maxX and special.y >= minY and special.y <= maxY and (special.z or 0) == (z or 0) then
            result[#result + 1] = {
                x = special.x,
                y = special.y,
                z = special.z or 0,
                tile = special.tile,
                roomKey = special.roomKey,
                hiddenBehind = special.hiddenBehind == true,
                revealRotation = special.revealRotation,
                revealRotations = special.revealRotations,
            }
        end
    end
    return result
end

function World:threatAt(x, y, z)
    for _, threat in ipairs(self:layout().threats or {}) do
        if threat.x == x and threat.y == y and (threat.z or 0) == (z or 0) then
            return threat
        end
    end
    return nil
end

function World:threatsInRect(minX, maxX, minY, maxY, z)
    local result = {}
    for _, threat in ipairs(self:layout().threats or {}) do
        if threat.x >= minX and threat.x <= maxX and threat.y >= minY and threat.y <= maxY and (threat.z or 0) == (z or 0) then
            result[#result + 1] = {
                key = threat.key,
                x = threat.x,
                y = threat.y,
                z = threat.z or 0,
                roomKey = threat.roomKey,
                encounter = threat.encounter,
                rare = threat.rare == true,
            }
        end
    end
    return result
end

function World:generateChunk(cx, cy, z)
    local chunk = { cx = cx, cy = cy, z = z or 0, tiles = {} }
    for localY = 0, World.chunkSize - 1 do
        for localX = 0, World.chunkSize - 1 do
            local worldX = cx * World.chunkSize + localX
            local worldY = cy * World.chunkSize + localY
            chunk.tiles[localY * World.chunkSize + localX + 1] = self:generatedTile(worldX, worldY, z or 0)
        end
    end
    return chunk
end

function World:chunkForTile(x, y, z)
    local cx = World.floorDiv(x, World.chunkSize)
    local cy = World.floorDiv(y, World.chunkSize)
    local key = World.chunkKey(cx, cy, z or 0)
    if not self.chunks[key] then
        self.chunks[key] = self:generateChunk(cx, cy, z or 0)
    end
    return self.chunks[key]
end

function World:loadedChunkCount()
    local count = 0
    for _ in pairs(self.chunks) do
        count = count + 1
    end
    return count
end

function World:clearLoadedChunks()
    self.chunks = {}
end

function World:megastructureTile(x, y, z)
    if (z or 0) ~= 0 then
        return nil
    end
    local layout = self:layout()
    local mega = layout and layout.megastructure
    if not mega then
        return nil
    end
    for _, bridge in ipairs(mega.bridges or {}) do
        if bridgeContains(x, y, bridge) then
            return bridge.tile or layout.corridorTile or layout.floorTile
        end
    end
    for _, platform in ipairs(mega.platforms or {}) do
        if rectContains(x, y, platform) then
            return platform.tile or layout.floorTile
        end
    end
    for _, overlook in ipairs(mega.overlooks or {}) do
        if rectContains(x, y, overlook) then
            return overlook.tile or layout.floorTile
        end
    end
    return nil
end

function World:generatedTile(x, y, z)
    if (z or 0) ~= 0 then
        return tile(self:wallTile())
    end
    local special = self:specialAt(x, y, z)
    if special then
        return tile(special.tile)
    end
    local layout = self:layout()
    for _, corridor in ipairs(layout.corridors or {}) do
        if inCorridor(x, y, corridor) then
            return tile(layout.corridorTile or "corridor")
        end
    end
    local megaTile = self:megastructureTile(x, y, z)
    if megaTile then
        return tile(megaTile)
    end
    for _, room in ipairs(layout.rooms or {}) do
        if inRoom(x, y, room) then
            if math.abs(x - room.x) == room.w or math.abs(y - room.y) == room.h then
                return tile(layout.wallTile or "archive_wall")
            end
            if layout.obstacleTile and layout.obstacleModulo and Rng.hash(self.seed + 11017, x, y, z) % layout.obstacleModulo == 0 then
                return tile(layout.obstacleTile)
            end
            return tile(layout.floorTile or "archive_floor")
        end
    end
    return tile(layout.wallTile or "archive_wall")
end

function World:getTile(x, y, z)
    return cloneTile(self:peekTile(x, y, z))
end

function World:peekTile(x, y, z)
    local key = Grid.key(x, y, z or 0)
    local override = self.overrides[key]
    if override then
        return override
    end
    local chunk = self:chunkForTile(x, y, z or 0)
    local localX = World.floorMod(x, World.chunkSize)
    local localY = World.floorMod(y, World.chunkSize)
    return chunk.tiles[localY * World.chunkSize + localX + 1]
end

function World:setTile(x, y, z, value)
    z = z or 0
    self.overrides[Grid.key(x, y, z)] = cloneTile(value)
    local cx = World.floorDiv(x, World.chunkSize)
    local cy = World.floorDiv(y, World.chunkSize)
    local key = World.chunkKey(cx, cy, z)
    self.chunkRevisions[key] = (self.chunkRevisions[key] or 0) + 1
end

function World:chunkRevision(cx, cy, z)
    return self.chunkRevisions[World.chunkKey(cx, cy, z or 0)] or 0
end

function World:isWalkable(x, y, z)
    return Defs.tile(self:getTile(x, y, z).id).walkable == true
end

function World:snapshot()
    local tiles = {}
    for key, value in pairs(self.overrides) do
        tiles[#tiles + 1] = { key = key, id = value.id, data = value.data or 0 }
    end
    table.sort(tiles, function(a, b)
        return a.key < b.key
    end)
    local chunks = {}
    for key, chunk in pairs(self.chunks) do
        chunks[#chunks + 1] = { key = key, cx = chunk.cx, cy = chunk.cy, z = chunk.z }
    end
    table.sort(chunks, function(a, b)
        return a.key < b.key
    end)
    return { seed = self.seed, location = self.location, layoutId = self.layoutId, chunks = chunks, tiles = tiles }
end

function World.fromSnapshot(snapshot)
    local overrides = {}
    for _, value in ipairs(snapshot.tiles or {}) do
        overrides[value.key] = tile(value.id, value.data)
    end
    local world = World.new(snapshot.seed, snapshot.location or "buried_archive", { tiles = overrides, layoutId = snapshot.layoutId })
    for _, chunk in ipairs(snapshot.chunks or {}) do
        local key = chunk.key or World.chunkKey(chunk.cx, chunk.cy, chunk.z or 0)
        world.chunks[key] = world:generateChunk(chunk.cx, chunk.cy, chunk.z or 0)
    end
    return world
end

return World
