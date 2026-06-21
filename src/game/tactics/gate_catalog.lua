local GateCatalog = {}

GateCatalog.gates = {
    {
        id = "mechanic_entry",
        appliesTo = "new mechanic",
        requiredEvidence = { "research_handoff", "preview_ui_spec", "replay_acceptance_test" },
        blocker = "mechanic cannot enter implementation",
    },
    {
        id = "procedural_board_ship",
        appliesTo = "procedural board type",
        requiredEvidence = { "validator_results", "fixed_seed_batch", "reject_reason_log" },
        minimumSeeds = 25,
        blocker = "board type cannot ship",
    },
    {
        id = "class_loadout_ship",
        appliesTo = "class loadout",
        requiredEvidence = { "strong_board_fixture", "awkward_board_fixture", "preview_ui_spec" },
        blocker = "class loadout cannot ship",
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
