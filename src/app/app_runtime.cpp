#include "app_internal.hpp"

#include "thoth/core/deterministic_random.hpp"
#include "thoth/game/save.hpp"

#include <algorithm>
#include <array>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <fstream>
#include <filesystem>
#include <iostream>
#include <optional>
#include <sstream>
#include <string>
#include <string_view>
#include <system_error>
#include <utility>
#include <vector>

namespace thoth::app {

void stepSimulationTimed(thoth::game::Simulation& sim, AppState& state)
{
    const auto startedAt = std::chrono::steady_clock::now();
    sim.step();
    const auto finishedAt = std::chrono::steady_clock::now();
    const auto elapsedUs = std::chrono::duration<double, std::micro>(finishedAt - startedAt).count();
    state.lastTickUs = elapsedUs;
    state.averageTickUs = state.averageTickUs <= 0.0 ? elapsedUs : (state.averageTickUs * 0.9) + (elapsedUs * 0.1);
    ++state.simStepsLastFrame;
}

void setFeedback(AppState& state, std::string text, Color color)
{
    state.feedbackText = std::move(text);
    state.feedbackColor = color;
    state.feedbackTicks = 20;
}

void loadAppProfile(AppState& state)
{
    state.tutorialSeenProfile = false;
    std::ifstream input(kProfilePath);
    if (input) {
        std::string header;
        int version = 0;
        std::string key;
        int tutorialSeen = 0;
        if (input >> header >> version >> key >> tutorialSeen &&
            header == "THOTH_PROFILE" &&
            version >= 2 &&
            key == "tutorial_seen") {
            state.tutorialSeenProfile = tutorialSeen != 0;
        }
    }
    state.tutorialVisible = !state.tutorialSeenProfile;
    state.tutorialManualOpen = false;
    state.tutorialWasActive = false;
}

void markTutorialSeen(AppState& state)
{
    if (!state.tutorialSeenProfile) {
        std::ofstream output(kProfilePath);
        if (output) {
            output << "THOTH_PROFILE 2\n";
            output << "tutorial_seen 1\n";
        }
    }
    state.tutorialSeenProfile = true;
}

void syncTutorialCompletion(const thoth::game::Simulation& sim, AppState& state)
{
    const bool active = sim.tutorialState().active;
    if (state.tutorialWasActive && !active && sim.tutorialState().completed && !state.tutorialSeenProfile) {
        markTutorialSeen(state);
        state.tutorialVisible = false;
        state.tutorialManualOpen = false;
        state.status = "tutorial complete";
        setFeedback(state, "tutorial complete", Color{103, 214, 132, 220});
    }
    state.tutorialWasActive = active;
}

int runInteractiveApp()
{
    InitWindow(kScreenWidth, kScreenHeight, "Thoth - C++ raylib automation sandbox");
    SetTargetFPS(60);

    AppState state;
    loadAppProfile(state);
    auto sim = thoth::game::Simulation::newGame(1337, !state.tutorialSeenProfile);
    state.tutorialWasActive = sim.tutorialState().active;
    auto visuals = loadVisualAtlas();
    gVisualAtlas = &visuals;
    auto audio = loadAudioBank();
    state.audioSource = audio.source;
    syncProductionCounters(sim, state);
    syncMachineIssueCounters(sim, state);
    syncAchievementCounters(sim, state);
    Camera2D camera{};
    camera.offset = Vector2{kScreenWidth * 0.5f, kScreenHeight * 0.5f};
    camera.zoom = 1.0f;

    double accumulator = 0.0;

    while (!WindowShouldClose()) {
        state.simStepsLastFrame = 0;
        queueInput(sim, state, audio);
        accumulator = std::min(accumulator + static_cast<double>(GetFrameTime()), 0.25);
        const int maxSteps = IsKeyDown(KEY_LEFT_SHIFT) || IsKeyDown(KEY_RIGHT_SHIFT) ? 4 : 1;
        int steps = 0;
        while (!state.paused && accumulator >= kFixedDelta && steps < maxSteps) {
            stepSimulationTimed(sim, state);
            accumulator -= kFixedDelta;
            ++steps;
        }
        if (steps > 0) {
            updateProductionFeedback(sim, state, audio);
            updateMachineIssueFeedback(sim, state, audio);
            updateAchievementFeedback(sim, state, audio);
            syncTutorialCompletion(sim, state);
        }
        if (state.paused) {
            accumulator = 0.0;
        }
        if (state.feedbackTicks > 0) {
            --state.feedbackTicks;
        }
        if (state.productionCueCooldown > 0) {
            --state.productionCueCooldown;
        }
        if (state.machineIssueCueCooldown > 0) {
            --state.machineIssueCueCooldown;
        }

        updatePlayerVisual(sim, state);
        camera.target = Vector2{
            (state.renderPlayerX * static_cast<float>(kTilePixels)) + (static_cast<float>(kTilePixels) * 0.5f),
            (state.renderPlayerY * static_cast<float>(kTilePixels)) + (static_cast<float>(kTilePixels) * 0.5f)};

        BeginDrawing();
        ClearBackground(Color{16, 18, 18, 255});
        BeginMode2D(camera);
        drawWorld(sim, state);
        EndMode2D();
        drawHud(sim, state);
        EndDrawing();
    }

    gVisualAtlas = nullptr;
    unloadVisualAtlas(visuals);
    unloadAudioBank(audio);
    CloseWindow();
    return 0;
}

} // namespace thoth::app
