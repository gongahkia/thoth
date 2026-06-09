#pragma once

#include "thoth/game/simulation.hpp"

#include <cstdint>
#include <filesystem>
#include <optional>
#include <string>
#include <vector>

namespace thoth::game {

struct ReplayFrame {
    std::uint64_t tick = 0;
    Command command;
};

using Replay = std::vector<ReplayFrame>;

struct ReplayDocument {
    std::uint64_t seed = 0;
    std::uint64_t finalTick = 0;
    int playerX = 0;
    int playerY = 0;
    Direction playerFacing = Direction::South;
    int selectedHotbar = 0;
    std::vector<ItemStack> playerInventory;
    std::vector<TileSnapshot> tiles;
    Replay replay;
};

void applyReplay(Simulation& simulation, const Replay& replay, std::uint64_t finalTick);
[[nodiscard]] Simulation simulationFromReplayDocument(const ReplayDocument& document);
[[nodiscard]] Simulation runReplayDocument(const ReplayDocument& document);
[[nodiscard]] bool saveReplayDocument(const ReplayDocument& document, const std::filesystem::path& path, std::string* error = nullptr);
[[nodiscard]] std::optional<ReplayDocument> loadReplayDocument(const std::filesystem::path& path, std::string* error = nullptr);

} // namespace thoth::game
