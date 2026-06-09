#pragma once

#include "thoth/game/simulation.hpp"

#include <filesystem>
#include <optional>
#include <string>

namespace thoth::game {

[[nodiscard]] bool saveSimulation(const Simulation& simulation, const std::filesystem::path& path, std::string* error = nullptr);
[[nodiscard]] std::optional<SimulationSnapshot> loadSimulationSnapshot(const std::filesystem::path& path, std::string* error = nullptr);
[[nodiscard]] std::optional<Simulation> loadSimulation(const std::filesystem::path& path, std::string* error = nullptr);

} // namespace thoth::game
