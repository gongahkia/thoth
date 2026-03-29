local serialize = require("thoth.core.serialize")
local terrain = require("thoth.game.terrain")

local addon = {}

local function buildHandle(runtime, options)
    local handle = {
        runtime = runtime,
        options = options or {},
        id = nil,
        metadata = nil,
        grid = nil,
        simulation = nil,
        evolution = nil,
    }

    function handle:list()
        return terrain.list()
    end

    function handle:describe(id)
        return terrain.describe(id)
    end

    function handle:getGrid()
        return self.grid and terrain.grid.clone(self.grid) or nil
    end

    function handle:generate(id, width, height, generateOptions)
        local map, metadata = terrain.generate(id, width, height, generateOptions)
        self.id = id
        self.grid = terrain.grid.clone(map)
        self.metadata = metadata
        self.simulation = nil
        return self:getGrid(), serialize.deepCopy(metadata)
    end

    function handle:startSimulation(options)
        if not self.id or not self.grid then
            return nil, "No terrain grid available"
        end
        self.simulation = terrain.simulation.init(self.id, self.grid, options)
        if not self.simulation then
            return nil, "No simulation ruleset for " .. self.id
        end
        return self.simulation
    end

    function handle:stepSimulation(steps)
        if not self.simulation then
            return nil, "No simulation session"
        end
        terrain.simulation.step(self.simulation, steps)
        self.grid = terrain.grid.clone(self.simulation.grid)
        return self:getGrid()
    end

    function handle:updateSimulation(dt)
        if not self.simulation then
            return nil, "No simulation session"
        end
        terrain.simulation.update(self.simulation, dt)
        self.grid = terrain.grid.clone(self.simulation.grid)
        return self:getGrid()
    end

    function handle:startEvolution(options)
        if not self.id or not self.grid then
            return nil, "No terrain grid available"
        end
        self.evolution = terrain.evolution.init(self.id, #self.grid[1], #self.grid, options)
        return self.evolution
    end

    function handle:stepEvolution()
        if not self.evolution then
            return nil, "No evolution session"
        end
        terrain.evolution.step(self.evolution)
        return self.evolution
    end

    function handle:applyBestGenome(seed)
        if not self.evolution or not self.evolution.best_genome then
            return nil, "No evolved genome available"
        end
        local map, metadata = terrain.generate(self.id, self.evolution.width, self.evolution.height, {
            seed = seed,
            params = terrain.evolution.genomeToParams(self.id, self.evolution.best_genome),
        })
        self.grid = terrain.grid.clone(map)
        self.metadata = metadata
        if self.simulation then
            self.simulation = terrain.simulation.init(self.id, self.grid, {
                seed = seed or 1,
                tick_rate = self.simulation.tick_rate,
                paused = self.simulation.paused,
            })
        end
        return self:getGrid(), serialize.deepCopy(metadata)
    end

    return handle
end

function addon.install(runtime, options)
    local handle = buildHandle(runtime, options)

    runtime:registerSystem({
        name = options and options.systemName or "terrain",
        priority = options and options.priority or 45,
        fixedUpdate = function(_runtime, dt)
            if handle.simulation and not handle.simulation.paused and (options == nil or options.auto_simulate ~= false) then
                handle:updateSimulation(dt)
            end
            if handle.evolution and not handle.evolution.done and options and options.auto_evolve then
                handle:stepEvolution()
            end
        end,
    })

    if options and options.id then
        handle:generate(options.id, options.width or 32, options.height or 32, options.generate)
        if options.simulation then
            handle:startSimulation(options.simulation)
        end
        if options.evolution then
            handle:startEvolution(options.evolution)
        end
    end

    return handle
end

function addon.snapshot(handle)
    return {
        id = handle.id,
        metadata = serialize.deepCopy(handle.metadata),
        grid = handle.grid and terrain.grid.clone(handle.grid) or nil,
        simulation = handle.simulation and terrain.simulation.snapshot(handle.simulation) or nil,
        evolution = handle.evolution and terrain.evolution.snapshot(handle.evolution) or nil,
    }
end

function addon.restore(handle, _runtime, snapshot)
    handle.id = snapshot.id
    handle.metadata = serialize.deepCopy(snapshot.metadata)
    handle.grid = snapshot.grid and terrain.grid.clone(snapshot.grid) or nil
    handle.simulation = snapshot.simulation and terrain.simulation.restore(snapshot.simulation) or nil
    handle.evolution = snapshot.evolution and terrain.evolution.restore(snapshot.evolution) or nil
end

return addon
