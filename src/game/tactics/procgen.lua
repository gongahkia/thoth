local RunCatalog = require("src.game.tactics.run_catalog")

local Procgen = {}

function Procgen.templates()
    return RunCatalog.templates()
end

function Procgen.validators()
    return RunCatalog.validators()
end

function Procgen.weights()
    return RunCatalog.weights()
end

return Procgen
