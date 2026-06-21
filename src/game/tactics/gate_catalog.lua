local GateCatalog = {}

GateCatalog.gates = {
    {
        id = "mechanic_entry",
        appliesTo = "new mechanic",
        requiredEvidence = { "research_handoff", "preview_ui_spec", "replay_acceptance_test" },
        blocker = "mechanic cannot enter implementation",
    },
}

function GateCatalog.gate(id)
    for _, gate in ipairs(GateCatalog.gates) do
        if gate.id == id then
            return gate
        end
    end
    return nil
end

function GateCatalog.all()
    return GateCatalog.gates
end

return GateCatalog
