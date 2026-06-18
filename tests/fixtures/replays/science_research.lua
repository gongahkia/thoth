return {
    name = "science_research",
    seed = 102,
    finalTick = 80,
    setup = function(sim)
        local lab = sim:addMachine("lab", 0, 0, "south")
        lab.inventory:add("science_pack", 3)
    end,
    validate = function(sim, expect)
        expect(sim:isTechCompleted("logistics_1"), "science_research should complete Logistics 1")
        expect(sim:isRecipeUnlocked("fast_belt"), "science_research should unlock fast belts")
        expect(sim:isAchievementUnlocked("logistics_one"), "science_research should unlock logistics achievement")
    end,
}
