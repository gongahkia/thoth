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

bool validateOreToPlateReplay(
    const thoth::game::Simulation& simulation,
    const thoth::game::ReplayDocument& document,
    std::string* error)
{
    const auto* chest = simulation.machineAt(5, 0);
    if (chest == nullptr || chest->kind != thoth::game::MachineKind::Chest) {
        if (error != nullptr) {
            *error = "ore replay did not place the expected output chest";
        }
        return false;
    }
    if (chest->inventory.count(thoth::game::ItemId::IronPlate) < 1) {
        if (error != nullptr) {
            *error = "ore replay did not produce an iron plate";
        }
        return false;
    }
    if (simulation.tick() != document.finalTick) {
        if (error != nullptr) {
            *error = "ore replay ended on the wrong tick";
        }
        return false;
    }
    return true;
}

bool validateScienceReplay(
    const thoth::game::Simulation& simulation,
    const thoth::game::ReplayDocument& document,
    std::string* error)
{
    const auto* assembler = simulation.machineAt(1, 0);
    const auto* lab = simulation.machineAt(2, 0);
    if (assembler == nullptr || assembler->kind != thoth::game::MachineKind::Assembler ||
        lab == nullptr || lab->kind != thoth::game::MachineKind::Lab) {
        if (error != nullptr) {
            *error = "science replay did not place the expected assembler and lab";
        }
        return false;
    }
    if (!simulation.isTechCompleted("logistics_1") ||
        !simulation.isRecipeUnlocked("fast_belt") ||
        !simulation.isRecipeUnlocked("generator") ||
        !simulation.isRecipeUnlocked("power_pole") ||
        !simulation.isRecipeUnlocked("electric_miner")) {
        if (error != nullptr) {
            *error = "science replay did not complete Logistics 1 unlocks";
        }
        return false;
    }
    if (simulation.tick() != document.finalTick) {
        if (error != nullptr) {
            *error = "science replay ended on the wrong tick";
        }
        return false;
    }
    return true;
}

bool validateFullFlowReplay(
    const thoth::game::Simulation& simulation,
    const thoth::game::ReplayDocument& document,
    std::string* error)
{
    const auto* firstChest = simulation.machineAt(5, 0);
    const auto* assembler = simulation.machineAt(1, 2);
    const auto* lab = simulation.machineAt(2, 2);
    const auto* generator = simulation.machineAt(0, 4);
    const auto* pole = simulation.machineAt(1, 4);
    const auto* electricMiner = simulation.machineAt(2, 4);
    const auto* poweredChest = simulation.machineAt(3, 4);

    if (simulation.world().getTile(1, 1).id != thoth::game::TileId::Grass) {
        if (error != nullptr) {
            *error = "full-flow replay did not mine the starter tree";
        }
        return false;
    }
    if (firstChest == nullptr || firstChest->kind != thoth::game::MachineKind::Chest ||
        firstChest->inventory.count(thoth::game::ItemId::IronPlate) < 1) {
        if (error != nullptr) {
            *error = "full-flow replay did not automate iron plates into the first chest";
        }
        return false;
    }
    if (assembler == nullptr || assembler->kind != thoth::game::MachineKind::Assembler ||
        lab == nullptr || lab->kind != thoth::game::MachineKind::Lab) {
        if (error != nullptr) {
            *error = "full-flow replay did not place the expected science machines";
        }
        return false;
    }
    if (!simulation.isTechCompleted("logistics_1") ||
        !simulation.isRecipeUnlocked("fast_belt") ||
        !simulation.isRecipeUnlocked("generator") ||
        !simulation.isRecipeUnlocked("power_pole") ||
        !simulation.isRecipeUnlocked("electric_miner")) {
        if (error != nullptr) {
            *error = "full-flow replay did not complete Logistics 1 unlocks";
        }
        return false;
    }
    if (generator == nullptr || generator->kind != thoth::game::MachineKind::Generator ||
        pole == nullptr || pole->kind != thoth::game::MachineKind::PowerPole ||
        electricMiner == nullptr || electricMiner->kind != thoth::game::MachineKind::ElectricMiner ||
        poweredChest == nullptr || poweredChest->kind != thoth::game::MachineKind::Chest) {
        if (error != nullptr) {
            *error = "full-flow replay did not place the expected power line";
        }
        return false;
    }

    const auto hasPoweredExtractorNetwork = std::any_of(
        simulation.powerNetworks().begin(),
        simulation.powerNetworks().end(),
        [](const thoth::game::PowerNetwork& network) {
            return network.powered && network.supply >= 1 && network.demand >= 1 &&
                !network.generatorIds.empty() && !network.consumerIds.empty();
        });
    if (!hasPoweredExtractorNetwork) {
        if (error != nullptr) {
            *error = "full-flow replay did not power an electric-miner network";
        }
        return false;
    }
    if (poweredChest->inventory.count(thoth::game::ItemId::IronOre) < 1) {
        if (error != nullptr) {
            *error = "full-flow replay did not extract ore with the powered miner";
        }
        return false;
    }
    if (document.finalTick < 3600 || simulation.tick() != document.finalTick) {
        if (error != nullptr) {
            *error = "full-flow replay did not run the expected 60-second window";
        }
        return false;
    }
    return true;
}

bool validateReplay(
    const std::filesystem::path& path,
    std::string_view label,
    bool (*validate)(const thoth::game::Simulation&, const thoth::game::ReplayDocument&, std::string*),
    std::string* error)
{
    std::string localError;
    auto document = thoth::game::loadReplayDocument(path, &localError);
    if (!document) {
        if (error != nullptr) {
            *error = std::string(label) + " replay failed to load: " + localError;
        }
        return false;
    }

    auto simulation = thoth::game::runReplayDocument(*document);
    if (!validate(simulation, *document, &localError)) {
        if (error != nullptr) {
            *error = std::string(label) + " replay failed validation: " + localError;
        }
        return false;
    }

    std::cout << "validated replay " << path.generic_string()
              << " tick=" << simulation.tick()
              << " machines=" << simulation.machines().size() << '\n';
    return true;
}

bool validatePackagedReplays(std::string* error)
{
    return validateReplay(kDemoReplayPath, "ore-to-plate", validateOreToPlateReplay, error) &&
        validateReplay(kScienceReplayPath, "science/research", validateScienceReplay, error) &&
        validateReplay(kFullFlowReplayPath, "full-flow", validateFullFlowReplay, error);
}

bool savePlaytestTelemetry(const std::filesystem::path& path, std::string* error)
{
    std::string localError;
    auto document = thoth::game::loadReplayDocument(kFullFlowReplayPath, &localError);
    if (!document) {
        if (error != nullptr) {
            *error = "failed to load full-flow replay: " + localError;
        }
        return false;
    }

    auto simulation = thoth::game::runReplayDocument(*document);
    const auto parent = path.parent_path();
    if (!parent.empty()) {
        std::error_code createError;
        std::filesystem::create_directories(parent, createError);
        if (createError) {
            if (error != nullptr) {
                *error = "failed to create telemetry directory: " + createError.message();
            }
            return false;
        }
    }

    std::ofstream output(path);
    if (!output) {
        if (error != nullptr) {
            *error = "failed to open telemetry file for writing";
        }
        return false;
    }
    output << simulation.playtestTelemetryText();
    if (!output) {
        if (error != nullptr) {
            *error = "failed to write telemetry file";
        }
        return false;
    }
    return true;
}

bool saveMediaPreview(const std::filesystem::path& path, std::string* error);
bool saveWindowSmokeScreenshot(const std::filesystem::path& path, std::string* error);

void printCommandLineUsage(const char* executable)
{
    std::cout
        << "Usage: " << executable << " [--export-atlas [path]] [--export-authored-atlas [path]] [--export-audio [dir]] [--export-authored-audio [dir]] [--export-media-preview [path]] [--export-playtest-telemetry [path]] [--window-smoke [path]] [--validate-assets] [--validate-replays]\n"
        << "\n"
        << "Options:\n"
        << "  --export-atlas [path]  Export the generated sprite atlas without opening a window.\n"
        << "                         Defaults to " << kGeneratedSpriteAtlasPath.generic_string() << ".\n"
        << "  --export-authored-atlas [path]\n"
        << "                         Export the authored text atlas source without opening a window.\n"
        << "                         Defaults to assets/sprites/thoth_atlas.png.\n"
        << "  --export-audio [dir]   Export generated WAV cue fallbacks without opening a window.\n"
        << "                         Defaults to " << kGeneratedAudioAssetDir.generic_string() << ".\n"
        << "  --export-authored-audio [dir]\n"
        << "                         Export the authored WAV cue pack without opening a window.\n"
        << "                         Defaults to " << kAudioAssetDir.generic_string() << ".\n"
        << "  --export-media-preview [path]\n"
        << "                         Export a deterministic full-flow visual preview PNG without opening a window.\n"
        << "                         Defaults to " << kMediaPreviewPath.generic_string() << ".\n"
        << "  --export-playtest-telemetry [path]\n"
        << "                         Export deterministic full-flow playtest telemetry JSON without opening a window.\n"
        << "                         Defaults to " << kPlaytestTelemetryPath.generic_string() << ".\n"
        << "  --window-smoke [path]  Open the raylib window, load visuals/audio, render the full-flow replay, save a screenshot, and exit.\n"
        << "                         Defaults to " << kWindowSmokePath.generic_string() << ".\n"
        << "  --validate-assets     Validate authored sprite/audio sources and exported runtime assets.\n"
        << "  --validate-replays     Validate packaged deterministic replay demos without opening a window.\n"
        << "  -h, --help             Show this help.\n";
}

int runCommandLineMode(int argc, char** argv)
{
    for (int i = 1; i < argc; ++i) {
        const std::string_view arg(argv[i]);
        if (arg == "-h" || arg == "--help") {
            printCommandLineUsage(argv[0]);
            return 0;
        }
        if (arg == "--export-atlas") {
            std::filesystem::path output = kGeneratedSpriteAtlasPath;
            if (i + 1 < argc && std::string_view(argv[i + 1]).rfind("-", 0) != 0) {
                output = argv[i + 1];
            }

            std::string error;
            if (!saveGeneratedAtlas(output, &error)) {
                std::cerr << "atlas export failed: " << error << '\n';
                return 1;
            }
            std::cout << "exported generated atlas: " << output.generic_string() << '\n';
            return 0;
        }
        if (arg == "--export-authored-atlas") {
            std::filesystem::path output = kSpriteAtlasPath;
            if (i + 1 < argc && std::string_view(argv[i + 1]).rfind("-", 0) != 0) {
                output = argv[i + 1];
            }

            std::string error;
            if (!saveAuthoredAtlas(output, &error)) {
                std::cerr << "authored atlas export failed: " << error << '\n';
                return 1;
            }
            std::cout << "exported authored atlas: " << output.generic_string() << '\n';
            return 0;
        }
        if (arg == "--export-audio") {
            std::filesystem::path output = kGeneratedAudioAssetDir;
            if (i + 1 < argc && std::string_view(argv[i + 1]).rfind("-", 0) != 0) {
                output = argv[i + 1];
            }

            std::string error;
            if (!saveGeneratedAudioCues(output, &error)) {
                std::cerr << "audio export failed: " << error << '\n';
                return 1;
            }
            std::cout << "exported generated audio cues: " << output.generic_string() << '\n';
            return 0;
        }
        if (arg == "--export-authored-audio") {
            std::filesystem::path output = kAudioAssetDir;
            if (i + 1 < argc && std::string_view(argv[i + 1]).rfind("-", 0) != 0) {
                output = argv[i + 1];
            }

            std::string error;
            if (!saveAuthoredAudioCues(output, &error)) {
                std::cerr << "authored audio export failed: " << error << '\n';
                return 1;
            }
            std::cout << "exported authored audio cues: " << output.generic_string() << '\n';
            return 0;
        }
        if (arg == "--export-media-preview") {
            std::filesystem::path output = kMediaPreviewPath;
            if (i + 1 < argc && std::string_view(argv[i + 1]).rfind("-", 0) != 0) {
                output = argv[i + 1];
            }

            std::string error;
            if (!saveMediaPreview(output, &error)) {
                std::cerr << "media preview export failed: " << error << '\n';
                return 1;
            }
            std::cout << "exported media preview: " << output.generic_string() << '\n';
            return 0;
        }
        if (arg == "--export-playtest-telemetry") {
            std::filesystem::path output = kPlaytestTelemetryPath;
            if (i + 1 < argc && std::string_view(argv[i + 1]).rfind("-", 0) != 0) {
                output = argv[i + 1];
            }

            std::string error;
            if (!savePlaytestTelemetry(output, &error)) {
                std::cerr << "playtest telemetry export failed: " << error << '\n';
                return 1;
            }
            std::cout << "exported playtest telemetry: " << output.generic_string() << '\n';
            return 0;
        }
        if (arg == "--window-smoke") {
            std::filesystem::path output = kWindowSmokePath;
            if (i + 1 < argc && std::string_view(argv[i + 1]).rfind("-", 0) != 0) {
                output = argv[i + 1];
            }

            std::string error;
            if (!saveWindowSmokeScreenshot(output, &error)) {
                std::cerr << "window smoke failed: " << error << '\n';
                return 1;
            }
            std::cout << "saved window smoke screenshot: " << output.generic_string() << '\n';
            return 0;
        }
        if (arg == "--validate-assets") {
            std::string error;
            if (!validateBundledAssets(&error)) {
                std::cerr << "asset validation failed: " << error << '\n';
                return 1;
            }
            std::cout << "validated bundled assets\n";
            return 0;
        }
        if (arg == "--validate-replays") {
            std::string error;
            if (!validatePackagedReplays(&error)) {
                std::cerr << "replay validation failed: " << error << '\n';
                return 1;
            }
            std::cout << "validated packaged replay demos\n";
            return 0;
        }

        std::cerr << "unknown option: " << arg << '\n';
        printCommandLineUsage(argv[0]);
        return 2;
    }
    return -1;
}

} // namespace thoth::app
