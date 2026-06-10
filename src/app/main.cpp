#include "thoth/core/deterministic_random.hpp"
#include "thoth/game/registry.hpp"
#include "thoth/game/replay.hpp"
#include "thoth/game/save.hpp"
#include "thoth/game/simulation.hpp"
#include "thoth/game/world.hpp"

#include "raylib.h"

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

namespace {

constexpr int kScreenWidth = 1280;
constexpr int kScreenHeight = 720;
constexpr int kTilePixels = 32;
constexpr int kMoveRepeatFrames = 10;
constexpr float kPlayerVisualLerp = 0.24f;
constexpr int kAudioSampleRate = 22050;
constexpr double kFixedDelta = 1.0 / 60.0;
constexpr double kPi = 3.14159265358979323846;
constexpr int kCraftMenuX = 12;
constexpr int kCraftMenuY = 488;
constexpr int kCraftMenuWidth = 1256;
constexpr int kCraftMenuColumns = 6;
constexpr int kCraftCardHeight = 38;
constexpr int kCraftCardGap = 6;
constexpr int kMachinePanelX = 462;
constexpr int kMachinePanelY = 190;
constexpr int kMachinePanelWidth = 364;
constexpr int kInventoryPanelX = 12;
constexpr int kInventoryPanelY = 190;
constexpr int kInventoryPanelWidth = 430;
constexpr int kInventorySlotSize = 58;
constexpr int kInventorySlotGap = 8;
const std::filesystem::path kSavePath = "thoth_save.txt";
const std::filesystem::path kDemoReplayPath = "assets/replays/ore_to_plate.thothreplay";
const std::filesystem::path kScienceReplayPath = "assets/replays/science_research.thothreplay";
const std::filesystem::path kFullFlowReplayPath = "assets/replays/full_flow.thothreplay";
const std::filesystem::path kAuthoredSpriteAtlasPath = "assets/sprites/thoth_atlas.art";
const std::filesystem::path kSpriteAtlasPath = "assets/sprites/thoth_atlas.png";
const std::filesystem::path kGeneratedSpriteAtlasPath = "assets/sprites/thoth_generated_atlas.png";
const std::filesystem::path kAuthoredAudioCuePath = "assets/audio/thoth_cues.sfx";
const std::filesystem::path kAudioAssetDir = "assets/audio";
const std::filesystem::path kGeneratedAudioAssetDir = "assets/audio/generated";
const std::filesystem::path kMediaPreviewPath = "assets/previews/thoth_full_flow_preview.png";
const std::filesystem::path kWindowSmokePath = "assets/previews/thoth_window_smoke.png";

struct AppState {
    std::string status = "ready";
    thoth::game::Direction buildDirection = thoth::game::Direction::South;
    bool paused = false;
    bool debug = false;
    bool craftMenuOpen = false;
    bool inventoryOpen = false;
    int craftSelection = 0;
    int machineTransferAmount = 1;
    int audioAuditionIndex = 0;
    int feedbackTicks = 0;
    int productionCueCooldown = 0;
    int machineIssueCueCooldown = 0;
    int lastFactoryIronPlates = -1;
    int lastFactoryCopperPlates = -1;
    int lastFactorySciencePacks = -1;
    int lastFuelIssues = -1;
    int lastPowerIssues = -1;
    int lastBlockedIssues = -1;
    int simStepsLastFrame = 0;
    int movementCooldownFrames = 0;
    float renderPlayerX = 0.0f;
    float renderPlayerY = 0.0f;
    bool renderPlayerReady = false;
    double lastTickUs = 0.0;
    double averageTickUs = 0.0;
    Color feedbackColor = Color{255, 255, 255, 0};
    std::string feedbackText;
    std::string audioSource = "none";
};

struct CraftMenuEntry {
    std::string_view recipeKey;
    std::string_view hotkey;
};

struct MachinePanelButton {
    Rectangle rect{};
    thoth::game::ItemId item = thoth::game::ItemId::None;
    bool deposit = true;
};

struct RecipePanelButton {
    Rectangle rect{};
    std::string_view recipeKey;
};

enum class MachineConfigAction {
    Circuit,
    Request,
};

struct MachineConfigButton {
    Rectangle rect{};
    MachineConfigAction action = MachineConfigAction::Circuit;
    thoth::game::ItemId item = thoth::game::ItemId::None;
    thoth::game::CircuitComparator comparator = thoth::game::CircuitComparator::Always;
    int threshold = 0;
    std::string_view label;
};

struct TransferAmountButton {
    Rectangle rect{};
    int amount = 1;
};

struct InventoryButton {
    Rectangle rect{};
    thoth::game::ItemId item = thoth::game::ItemId::None;
    int hotbarIndex = -1;
    bool hotbar = false;
};

struct FirstLinePartGuide {
    thoth::game::ItemId item = thoth::game::ItemId::None;
    thoth::game::MachineKind machine = thoth::game::MachineKind::Chest;
    std::string_view recipeKey;
    std::string_view label;
    std::string_view hotkey;
};

struct AudioBank {
    bool ready = false;
    int externalSounds = 0;
    std::string source = "none";
    Sound mine{};
    Sound place{};
    Sound craft{};
    Sound invalid{};
    Sound save{};
    Sound load{};
    Sound tick{};
    Sound produce{};
};

struct ToneSpec {
    const char* filename = "";
    float frequency = 0.0f;
    float endFrequency = 0.0f;
    float seconds = 0.0f;
    float volume = 0.0f;
};

struct AudioCueSpec {
    std::string filename;
    float frequency = 0.0f;
    float endFrequency = 0.0f;
    float seconds = 0.0f;
    float volume = 0.0f;
};

std::string directionText(thoth::game::Direction direction);
thoth::game::ItemId furnaceOreInput(const thoth::game::RecipeDef& recipe);

constexpr std::array<ToneSpec, 8> kToneSpecs = {
    ToneSpec{"mine.wav", 178.0f, 74.0f, 0.09f, 0.16f},
    ToneSpec{"place.wav", 320.0f, 230.0f, 0.064f, 0.13f},
    ToneSpec{"craft.wav", 500.0f, 780.0f, 0.105f, 0.12f},
    ToneSpec{"invalid.wav", 132.0f, 62.0f, 0.135f, 0.13f},
    ToneSpec{"save.wav", 560.0f, 920.0f, 0.145f, 0.10f},
    ToneSpec{"load.wav", 360.0f, 620.0f, 0.13f, 0.10f},
    ToneSpec{"tick.wav", 900.0f, 900.0f, 0.032f, 0.055f},
    ToneSpec{"produce.wav", 470.0f, 880.0f, 0.12f, 0.11f},
};

constexpr int kSpritePixels = 16;
constexpr int kSpriteAtlasColumns = 8;

enum class SpriteId : int {
    TileGrass,
    TileDirt,
    TileSand,
    TileSnow,
    TileMud,
    TileWater,
    TileTree,
    TileStone,
    TileIronOre,
    TileCopperOre,
    TileCoalOre,
    TileFloor,
    ItemWood,
    ItemStone,
    ItemCoal,
    ItemIronOre,
    ItemIronPlate,
    ItemCopperOre,
    ItemCopperPlate,
    ItemSciencePack,
    MachineBelt,
    MachineFastBelt,
    MachineInserter,
    MachineBurnerMiner,
    MachineFurnace,
    MachineChest,
    MachineWorkbench,
    MachineAssembler,
    MachineLab,
    MachineGenerator,
    MachinePowerPole,
    MachineElectricMiner,
    Player,
    Count,
};

constexpr int kSpriteAtlasRows =
    (static_cast<int>(SpriteId::Count) + kSpriteAtlasColumns - 1) / kSpriteAtlasColumns;

struct VisualAtlas {
    Texture2D texture{};
    bool ready = false;
    bool generated = true;
    std::string source = "none";
};

struct SpriteDrawOptions {
    bool flipX = false;
    bool flipY = false;
    Color tint = WHITE;
};

const VisualAtlas* gVisualAtlas = nullptr;

std::optional<std::filesystem::path> findBundledPath(const std::filesystem::path& relativePath)
{
    const std::array<std::filesystem::path, 4> candidates = {
        relativePath,
        std::filesystem::path("..") / relativePath,
        std::filesystem::path("..") / ".." / relativePath,
        std::filesystem::path("..") / ".." / ".." / relativePath,
    };

    for (const auto& candidate : candidates) {
        if (std::filesystem::exists(candidate)) {
            return candidate;
        }
    }
    return std::nullopt;
}

Color toColor(thoth::game::Rgb rgb)
{
    return Color{rgb.r, rgb.g, rgb.b, 255};
}

int spriteIndex(SpriteId id)
{
    return static_cast<int>(id);
}

int spriteOriginX(SpriteId id)
{
    return (spriteIndex(id) % kSpriteAtlasColumns) * kSpritePixels;
}

int spriteOriginY(SpriteId id)
{
    return (spriteIndex(id) / kSpriteAtlasColumns) * kSpritePixels;
}

Rectangle spriteSource(SpriteId id)
{
    return Rectangle{
        static_cast<float>(spriteOriginX(id)),
        static_cast<float>(spriteOriginY(id)),
        static_cast<float>(kSpritePixels),
        static_cast<float>(kSpritePixels),
    };
}

Rectangle transformedSpriteSource(SpriteId id, const SpriteDrawOptions& options)
{
    auto source = spriteSource(id);
    if (options.flipX) {
        source.x += source.width;
        source.width = -source.width;
    }
    if (options.flipY) {
        source.y += source.height;
        source.height = -source.height;
    }
    return source;
}

unsigned char tintChannel(int base, int delta)
{
    return static_cast<unsigned char>(std::clamp(base + delta, 0, 255));
}

Color multiplyTint(Color color, Color tint)
{
    return Color{
        static_cast<unsigned char>((static_cast<int>(color.r) * static_cast<int>(tint.r)) / 255),
        static_cast<unsigned char>((static_cast<int>(color.g) * static_cast<int>(tint.g)) / 255),
        static_cast<unsigned char>((static_cast<int>(color.b) * static_cast<int>(tint.b)) / 255),
        static_cast<unsigned char>((static_cast<int>(color.a) * static_cast<int>(tint.a)) / 255),
    };
}

Color tileVariantTint(thoth::game::TileId id, std::uint64_t hash)
{
    const int delta = static_cast<int>((hash >> 8U) & 15U) - 7;
    using thoth::game::TileId;
    switch (id) {
    case TileId::Grass:
        return Color{tintChannel(244, delta), tintChannel(252, delta), tintChannel(238, delta), 255};
    case TileId::Dirt:
        return Color{tintChannel(250, delta), tintChannel(242, delta), tintChannel(232, delta), 255};
    case TileId::Sand:
        return Color{tintChannel(255, delta), tintChannel(250, delta), tintChannel(226, delta), 255};
    case TileId::Snow:
        return Color{tintChannel(246, delta), tintChannel(252, delta), tintChannel(255, delta), 255};
    case TileId::Mud:
        return Color{tintChannel(238, delta), tintChannel(236, delta), tintChannel(224, delta), 255};
    case TileId::Water:
        return Color{tintChannel(228, delta), tintChannel(242, delta), tintChannel(255, delta), 255};
    case TileId::Stone:
        return Color{tintChannel(244, delta), tintChannel(246, delta), tintChannel(244, delta), 255};
    case TileId::IronOre:
        return Color{tintChannel(252, delta), tintChannel(244, delta), tintChannel(236, delta), 255};
    case TileId::CopperOre:
        return Color{tintChannel(255, delta), tintChannel(238, delta), tintChannel(228, delta), 255};
    case TileId::CoalOre:
        return Color{tintChannel(238, delta), tintChannel(238, delta), tintChannel(236, delta), 255};
    case TileId::Floor:
        return Color{tintChannel(248, delta), tintChannel(244, delta), tintChannel(234, delta), 255};
    case TileId::Tree:
        return WHITE;
    default:
        return Color{tintChannel(245, delta), tintChannel(245, delta), tintChannel(238, delta), 255};
    }
}

SpriteDrawOptions tileSpriteOptions(thoth::game::TileId id, int x, int y)
{
    const auto hash = thoth::core::hashCoordinates(0x743707a11a5bULL ^ static_cast<std::uint64_t>(id), x, y);
    using thoth::game::TileId;
    switch (id) {
    case TileId::Grass:
    case TileId::Dirt:
    case TileId::Sand:
    case TileId::Snow:
    case TileId::Mud:
    case TileId::Water:
    case TileId::Stone:
    case TileId::IronOre:
    case TileId::CopperOre:
    case TileId::CoalOre:
    case TileId::Floor:
    case TileId::Beach:
    case TileId::Ice:
    case TileId::Basalt:
    case TileId::DungeonFloor:
        return SpriteDrawOptions{
            (hash & 1U) != 0,
            ((hash >> 1U) & 1U) != 0,
            tileVariantTint(id, hash),
        };
    case TileId::Tree:
    case TileId::Reeds:
    case TileId::Cactus:
    case TileId::Crystal:
    case TileId::DeepWater:
    case TileId::Coral:
    case TileId::Wall:
    case TileId::PlankWall:
    case TileId::Door:
    case TileId::StairsUp:
    case TileId::StairsDown:
    case TileId::Bed:
    case TileId::DungeonWall:
        return SpriteDrawOptions{};
    }
    return SpriteDrawOptions{};
}

void atlasRect(Image& image, SpriteId id, int x, int y, int width, int height, Color color)
{
    ImageDrawRectangle(&image, spriteOriginX(id) + x, spriteOriginY(id) + y, width, height, color);
}

void atlasLine(Image& image, SpriteId id, int x1, int y1, int x2, int y2, Color color)
{
    ImageDrawLine(&image, spriteOriginX(id) + x1, spriteOriginY(id) + y1, spriteOriginX(id) + x2, spriteOriginY(id) + y2, color);
}

void atlasPixel(Image& image, SpriteId id, int x, int y, Color color)
{
    ImageDrawPixel(&image, spriteOriginX(id) + x, spriteOriginY(id) + y, color);
}

void atlasBase(Image& image, SpriteId id, Color base, Color light, Color shadow)
{
    atlasRect(image, id, 0, 0, kSpritePixels, kSpritePixels, base);
    atlasRect(image, id, 0, 0, kSpritePixels, 1, light);
    atlasRect(image, id, 0, 0, 1, kSpritePixels, light);
    atlasRect(image, id, 0, kSpritePixels - 1, kSpritePixels, 1, shadow);
    atlasRect(image, id, kSpritePixels - 1, 0, 1, kSpritePixels, shadow);
}

void drawAtlasSprites(Image& image)
{
    atlasBase(image, SpriteId::TileGrass, Color{72, 154, 73, 255}, Color{112, 190, 88, 255}, Color{46, 116, 58, 255});
    atlasPixel(image, SpriteId::TileGrass, 4, 5, Color{134, 202, 96, 255});
    atlasPixel(image, SpriteId::TileGrass, 11, 8, Color{50, 128, 61, 255});
    atlasPixel(image, SpriteId::TileGrass, 7, 12, Color{120, 192, 86, 255});

    atlasBase(image, SpriteId::TileDirt, Color{126, 88, 54, 255}, Color{184, 126, 72, 255}, Color{84, 58, 40, 255});
    atlasPixel(image, SpriteId::TileDirt, 5, 6, Color{198, 140, 82, 255});
    atlasPixel(image, SpriteId::TileDirt, 10, 10, Color{96, 66, 44, 255});

    atlasBase(image, SpriteId::TileSand, Color{190, 168, 96, 255}, Color{230, 210, 132, 255}, Color{132, 112, 64, 255});
    atlasPixel(image, SpriteId::TileSand, 3, 5, Color{240, 220, 142, 255});
    atlasPixel(image, SpriteId::TileSand, 11, 8, Color{154, 132, 76, 255});
    atlasPixel(image, SpriteId::TileSand, 7, 12, Color{226, 202, 122, 255});

    atlasBase(image, SpriteId::TileSnow, Color{202, 218, 220, 255}, Color{240, 250, 250, 255}, Color{138, 160, 168, 255});
    atlasPixel(image, SpriteId::TileSnow, 4, 5, Color{246, 252, 252, 255});
    atlasPixel(image, SpriteId::TileSnow, 11, 9, Color{166, 188, 196, 255});
    atlasPixel(image, SpriteId::TileSnow, 7, 12, Color{230, 240, 242, 255});

    atlasBase(image, SpriteId::TileMud, Color{82, 76, 48, 255}, Color{128, 118, 74, 255}, Color{48, 42, 30, 255});
    atlasPixel(image, SpriteId::TileMud, 5, 6, Color{142, 126, 76, 255});
    atlasPixel(image, SpriteId::TileMud, 10, 10, Color{58, 50, 34, 255});
    atlasPixel(image, SpriteId::TileMud, 12, 4, Color{100, 92, 58, 255});

    atlasBase(image, SpriteId::TileWater, Color{48, 128, 182, 255}, Color{118, 204, 232, 255}, Color{26, 78, 128, 255});
    atlasLine(image, SpriteId::TileWater, 2, 5, 7, 4, Color{148, 226, 244, 255});
    atlasLine(image, SpriteId::TileWater, 9, 11, 14, 10, Color{132, 216, 240, 255});

    atlasBase(image, SpriteId::TileTree, Color{48, 93, 50, 255}, Color{73, 124, 65, 255}, Color{30, 64, 37, 255});
    atlasRect(image, SpriteId::TileTree, 7, 8, 3, 7, Color{88, 56, 36, 255});
    atlasRect(image, SpriteId::TileTree, 4, 3, 8, 6, Color{37, 103, 50, 255});
    atlasRect(image, SpriteId::TileTree, 2, 6, 12, 4, Color{45, 118, 55, 255});

    atlasBase(image, SpriteId::TileStone, Color{78, 156, 78, 255}, Color{116, 190, 90, 255}, Color{50, 116, 58, 255});
    atlasRect(image, SpriteId::TileStone, 4, 5, 8, 6, Color{132, 139, 136, 255});
    atlasRect(image, SpriteId::TileStone, 7, 3, 5, 3, Color{158, 162, 156, 255});

    atlasBase(image, SpriteId::TileIronOre, Color{78, 156, 78, 255}, Color{116, 190, 90, 255}, Color{50, 116, 58, 255});
    atlasRect(image, SpriteId::TileIronOre, 4, 4, 4, 3, Color{198, 139, 94, 255});
    atlasRect(image, SpriteId::TileIronOre, 9, 9, 4, 3, Color{224, 170, 118, 255});
    atlasRect(image, SpriteId::TileIronOre, 6, 12, 3, 2, Color{134, 94, 72, 255});

    atlasBase(image, SpriteId::TileCopperOre, Color{78, 156, 78, 255}, Color{116, 190, 90, 255}, Color{50, 116, 58, 255});
    atlasRect(image, SpriteId::TileCopperOre, 4, 4, 4, 3, Color{212, 116, 66, 255});
    atlasRect(image, SpriteId::TileCopperOre, 9, 9, 4, 3, Color{236, 150, 84, 255});
    atlasRect(image, SpriteId::TileCopperOre, 6, 12, 3, 2, Color{130, 76, 55, 255});

    atlasBase(image, SpriteId::TileCoalOre, Color{78, 156, 78, 255}, Color{116, 190, 90, 255}, Color{50, 116, 58, 255});
    atlasRect(image, SpriteId::TileCoalOre, 4, 4, 5, 4, Color{22, 24, 26, 255});
    atlasRect(image, SpriteId::TileCoalOre, 9, 9, 4, 4, Color{35, 37, 41, 255});
    atlasRect(image, SpriteId::TileCoalOre, 5, 12, 3, 2, Color{80, 82, 84, 255});

    atlasBase(image, SpriteId::TileFloor, Color{114, 96, 66, 255}, Color{155, 138, 96, 255}, Color{72, 60, 44, 255});
    atlasLine(image, SpriteId::TileFloor, 1, 5, 14, 5, Color{82, 68, 50, 255});
    atlasLine(image, SpriteId::TileFloor, 1, 10, 14, 10, Color{145, 126, 88, 255});

    atlasBase(image, SpriteId::ItemWood, Color{124, 82, 44, 255}, Color{178, 126, 72, 255}, Color{78, 48, 30, 255});
    atlasRect(image, SpriteId::ItemWood, 3, 6, 10, 4, Color{162, 104, 56, 255});
    atlasPixel(image, SpriteId::ItemWood, 5, 8, Color{76, 47, 28, 255});
    atlasPixel(image, SpriteId::ItemWood, 11, 8, Color{76, 47, 28, 255});

    atlasBase(image, SpriteId::ItemStone, Color{92, 98, 98, 255}, Color{150, 154, 150, 255}, Color{55, 60, 62, 255});
    atlasRect(image, SpriteId::ItemStone, 5, 4, 7, 7, Color{130, 136, 134, 255});

    atlasBase(image, SpriteId::ItemCoal, Color{34, 36, 40, 255}, Color{84, 86, 88, 255}, Color{14, 16, 18, 255});
    atlasRect(image, SpriteId::ItemCoal, 4, 4, 8, 8, Color{20, 22, 25, 255});

    atlasBase(image, SpriteId::ItemIronOre, Color{126, 82, 58, 255}, Color{206, 140, 92, 255}, Color{77, 49, 38, 255});
    atlasRect(image, SpriteId::ItemIronOre, 5, 4, 7, 8, Color{196, 139, 94, 255});

    atlasBase(image, SpriteId::ItemIronPlate, Color{136, 146, 144, 255}, Color{214, 222, 214, 255}, Color{78, 86, 86, 255});
    atlasRect(image, SpriteId::ItemIronPlate, 3, 5, 10, 6, Color{198, 205, 196, 255});

    atlasBase(image, SpriteId::ItemCopperOre, Color{128, 70, 48, 255}, Color{224, 126, 74, 255}, Color{76, 42, 34, 255});
    atlasRect(image, SpriteId::ItemCopperOre, 5, 4, 7, 8, Color{218, 120, 72, 255});

    atlasBase(image, SpriteId::ItemCopperPlate, Color{158, 82, 46, 255}, Color{238, 144, 82, 255}, Color{94, 48, 34, 255});
    atlasRect(image, SpriteId::ItemCopperPlate, 3, 5, 10, 6, Color{218, 135, 76, 255});

    atlasBase(image, SpriteId::ItemSciencePack, Color{42, 82, 106, 255}, Color{122, 216, 255, 255}, Color{22, 44, 60, 255});
    atlasRect(image, SpriteId::ItemSciencePack, 6, 3, 4, 9, Color{118, 210, 255, 255});
    atlasRect(image, SpriteId::ItemSciencePack, 5, 11, 6, 2, Color{208, 240, 255, 255});

    atlasBase(image, SpriteId::MachineBelt, Color{190, 142, 42, 255}, Color{236, 194, 72, 255}, Color{86, 61, 30, 255});
    atlasRect(image, SpriteId::MachineBelt, 2, 6, 12, 4, Color{72, 54, 30, 255});
    atlasLine(image, SpriteId::MachineBelt, 6, 4, 11, 8, Color{24, 24, 22, 255});
    atlasLine(image, SpriteId::MachineBelt, 11, 8, 6, 12, Color{24, 24, 22, 255});

    atlasBase(image, SpriteId::MachineFastBelt, Color{225, 176, 44, 255}, Color{255, 224, 92, 255}, Color{114, 76, 22, 255});
    atlasRect(image, SpriteId::MachineFastBelt, 2, 6, 12, 4, Color{72, 54, 30, 255});
    atlasLine(image, SpriteId::MachineFastBelt, 4, 4, 9, 8, Color{246, 246, 230, 255});
    atlasLine(image, SpriteId::MachineFastBelt, 9, 8, 4, 12, Color{246, 246, 230, 255});

    atlasBase(image, SpriteId::MachineInserter, Color{52, 128, 130, 255}, Color{98, 182, 174, 255}, Color{24, 62, 66, 255});
    atlasRect(image, SpriteId::MachineInserter, 6, 6, 4, 4, Color{22, 34, 36, 255});
    atlasLine(image, SpriteId::MachineInserter, 8, 8, 13, 4, Color{218, 232, 226, 255});

    atlasBase(image, SpriteId::MachineBurnerMiner, Color{104, 75, 59, 255}, Color{158, 118, 82, 255}, Color{58, 42, 34, 255});
    atlasRect(image, SpriteId::MachineBurnerMiner, 4, 4, 8, 7, Color{54, 54, 54, 255});
    atlasRect(image, SpriteId::MachineBurnerMiner, 7, 10, 3, 4, Color{255, 164, 86, 255});

    atlasBase(image, SpriteId::MachineFurnace, Color{82, 86, 92, 255}, Color{142, 148, 150, 255}, Color{42, 44, 48, 255});
    atlasRect(image, SpriteId::MachineFurnace, 4, 4, 8, 9, Color{42, 44, 46, 255});
    atlasRect(image, SpriteId::MachineFurnace, 6, 8, 4, 4, Color{240, 104, 44, 255});

    atlasBase(image, SpriteId::MachineChest, Color{146, 84, 42, 255}, Color{226, 154, 78, 255}, Color{76, 44, 26, 255});
    atlasRect(image, SpriteId::MachineChest, 3, 5, 10, 7, Color{116, 66, 36, 255});
    atlasLine(image, SpriteId::MachineChest, 3, 8, 13, 8, Color{238, 178, 92, 255});

    atlasBase(image, SpriteId::MachineWorkbench, Color{124, 78, 44, 255}, Color{198, 130, 70, 255}, Color{76, 44, 26, 255});
    atlasRect(image, SpriteId::MachineWorkbench, 3, 5, 10, 4, Color{178, 119, 66, 255});
    atlasRect(image, SpriteId::MachineWorkbench, 5, 9, 2, 5, Color{76, 49, 32, 255});
    atlasRect(image, SpriteId::MachineWorkbench, 11, 9, 2, 5, Color{76, 49, 32, 255});

    atlasBase(image, SpriteId::MachineAssembler, Color{50, 98, 144, 255}, Color{100, 162, 214, 255}, Color{24, 54, 84, 255});
    atlasRect(image, SpriteId::MachineAssembler, 4, 4, 8, 8, Color{28, 42, 54, 255});
    atlasLine(image, SpriteId::MachineAssembler, 3, 8, 13, 8, Color{218, 234, 240, 255});
    atlasLine(image, SpriteId::MachineAssembler, 8, 3, 8, 13, Color{218, 234, 240, 255});

    atlasBase(image, SpriteId::MachineLab, Color{98, 70, 142, 255}, Color{158, 122, 220, 255}, Color{50, 36, 72, 255});
    atlasRect(image, SpriteId::MachineLab, 6, 3, 4, 9, Color{216, 210, 238, 255});
    atlasRect(image, SpriteId::MachineLab, 5, 11, 6, 2, Color{118, 210, 255, 255});

    atlasBase(image, SpriteId::MachineGenerator, Color{166, 88, 40, 255}, Color{230, 142, 72, 255}, Color{82, 45, 28, 255});
    atlasRect(image, SpriteId::MachineGenerator, 4, 4, 8, 8, Color{64, 42, 30, 255});
    atlasLine(image, SpriteId::MachineGenerator, 5, 5, 11, 11, Color{255, 218, 92, 255});
    atlasLine(image, SpriteId::MachineGenerator, 11, 5, 5, 11, Color{255, 218, 92, 255});

    atlasBase(image, SpriteId::MachinePowerPole, Color{142, 116, 76, 255}, Color{206, 184, 124, 255}, Color{76, 56, 36, 255});
    atlasRect(image, SpriteId::MachinePowerPole, 7, 3, 2, 11, Color{86, 62, 39, 255});
    atlasRect(image, SpriteId::MachinePowerPole, 3, 5, 10, 2, Color{64, 48, 34, 255});
    atlasPixel(image, SpriteId::MachinePowerPole, 8, 4, Color{118, 210, 255, 255});

    atlasBase(image, SpriteId::MachineElectricMiner, Color{58, 88, 160, 255}, Color{108, 148, 220, 255}, Color{28, 42, 88, 255});
    atlasRect(image, SpriteId::MachineElectricMiner, 4, 4, 8, 7, Color{38, 48, 72, 255});
    atlasRect(image, SpriteId::MachineElectricMiner, 7, 10, 3, 4, Color{120, 214, 255, 255});

    atlasBase(image, SpriteId::Player, Color{218, 220, 204, 255}, Color{246, 248, 232, 255}, Color{118, 126, 116, 255});
    atlasRect(image, SpriteId::Player, 6, 3, 4, 5, Color{240, 232, 198, 255});
    atlasRect(image, SpriteId::Player, 5, 8, 6, 5, Color{86, 122, 122, 255});
    atlasPixel(image, SpriteId::Player, 6, 5, Color{22, 28, 28, 255});
    atlasPixel(image, SpriteId::Player, 9, 5, Color{22, 28, 28, 255});
}

Image makeGeneratedAtlasImage()
{
    Image image = GenImageColor(kSpriteAtlasColumns * kSpritePixels, kSpriteAtlasRows * kSpritePixels, BLANK);
    drawAtlasSprites(image);
    return image;
}

std::string trimAscii(std::string text)
{
    while (!text.empty() && (text.back() == ' ' || text.back() == '\t' || text.back() == '\r')) {
        text.pop_back();
    }
    std::size_t start = 0;
    while (start < text.size() && (text[start] == ' ' || text[start] == '\t')) {
        ++start;
    }
    return text.substr(start);
}

const std::array<std::pair<std::string_view, SpriteId>, static_cast<std::size_t>(SpriteId::Count)>& spriteNameMap()
{
    static const std::array<std::pair<std::string_view, SpriteId>, static_cast<std::size_t>(SpriteId::Count)> names = {{
        {"TileGrass", SpriteId::TileGrass},
        {"TileDirt", SpriteId::TileDirt},
        {"TileSand", SpriteId::TileSand},
        {"TileSnow", SpriteId::TileSnow},
        {"TileMud", SpriteId::TileMud},
        {"TileWater", SpriteId::TileWater},
        {"TileTree", SpriteId::TileTree},
        {"TileStone", SpriteId::TileStone},
        {"TileIronOre", SpriteId::TileIronOre},
        {"TileCopperOre", SpriteId::TileCopperOre},
        {"TileCoalOre", SpriteId::TileCoalOre},
        {"TileFloor", SpriteId::TileFloor},
        {"ItemWood", SpriteId::ItemWood},
        {"ItemStone", SpriteId::ItemStone},
        {"ItemCoal", SpriteId::ItemCoal},
        {"ItemIronOre", SpriteId::ItemIronOre},
        {"ItemIronPlate", SpriteId::ItemIronPlate},
        {"ItemCopperOre", SpriteId::ItemCopperOre},
        {"ItemCopperPlate", SpriteId::ItemCopperPlate},
        {"ItemSciencePack", SpriteId::ItemSciencePack},
        {"MachineBelt", SpriteId::MachineBelt},
        {"MachineFastBelt", SpriteId::MachineFastBelt},
        {"MachineInserter", SpriteId::MachineInserter},
        {"MachineBurnerMiner", SpriteId::MachineBurnerMiner},
        {"MachineFurnace", SpriteId::MachineFurnace},
        {"MachineChest", SpriteId::MachineChest},
        {"MachineWorkbench", SpriteId::MachineWorkbench},
        {"MachineAssembler", SpriteId::MachineAssembler},
        {"MachineLab", SpriteId::MachineLab},
        {"MachineGenerator", SpriteId::MachineGenerator},
        {"MachinePowerPole", SpriteId::MachinePowerPole},
        {"MachineElectricMiner", SpriteId::MachineElectricMiner},
        {"Player", SpriteId::Player},
    }};
    return names;
}

std::optional<SpriteId> spriteIdFromName(std::string_view name)
{
    for (const auto& entry : spriteNameMap()) {
        if (entry.first == name) {
            return entry.second;
        }
    }
    return std::nullopt;
}

bool authoredAtlasColor(char glyph, Color& color)
{
    switch (glyph) {
    case '.':
        color = BLANK;
        return true;
    case 'o':
        color = Color{20, 24, 24, 255};
        return true;
    case 'x':
        color = Color{12, 14, 16, 255};
        return true;
    case 'n':
        color = Color{50, 54, 56, 255};
        return true;
    case 'N':
        color = Color{86, 94, 96, 255};
        return true;
    case 'm':
        color = Color{96, 108, 112, 255};
        return true;
    case 'M':
        color = Color{178, 188, 184, 255};
        return true;
    case 'h':
        color = Color{232, 238, 224, 255};
        return true;
    case 'g':
        color = Color{58, 146, 70, 255};
        return true;
    case 'G':
        color = Color{112, 190, 88, 255};
        return true;
    case 'd':
        color = Color{126, 88, 54, 255};
        return true;
    case 'D':
        color = Color{184, 126, 72, 255};
        return true;
    case 'z':
        color = Color{190, 168, 96, 255};
        return true;
    case 'Z':
        color = Color{230, 210, 132, 255};
        return true;
    case 'l':
        color = Color{202, 218, 220, 255};
        return true;
    case 'L':
        color = Color{240, 250, 250, 255};
        return true;
    case 'j':
        color = Color{82, 76, 48, 255};
        return true;
    case 'J':
        color = Color{128, 118, 74, 255};
        return true;
    case 'w':
        color = Color{48, 128, 182, 255};
        return true;
    case 'W':
        color = Color{118, 204, 232, 255};
        return true;
    case 't':
        color = Color{34, 118, 54, 255};
        return true;
    case 'T':
        color = Color{82, 164, 72, 255};
        return true;
    case 'b':
        color = Color{92, 58, 36, 255};
        return true;
    case 'B':
        color = Color{160, 104, 58, 255};
        return true;
    case 's':
        color = Color{106, 114, 112, 255};
        return true;
    case 'S':
        color = Color{176, 184, 176, 255};
        return true;
    case 'i':
        color = Color{156, 104, 70, 255};
        return true;
    case 'I':
        color = Color{236, 172, 112, 255};
        return true;
    case 'c':
        color = Color{164, 78, 48, 255};
        return true;
    case 'C':
        color = Color{248, 154, 82, 255};
        return true;
    case 'k':
        color = Color{24, 25, 28, 255};
        return true;
    case 'K':
        color = Color{80, 82, 84, 255};
        return true;
    case 'f':
        color = Color{116, 98, 68, 255};
        return true;
    case 'F':
        color = Color{170, 150, 100, 255};
        return true;
    case 'y':
        color = Color{198, 146, 44, 255};
        return true;
    case 'Y':
        color = Color{255, 220, 86, 255};
        return true;
    case 'r':
        color = Color{188, 78, 42, 255};
        return true;
    case 'R':
        color = Color{255, 164, 86, 255};
        return true;
    case 'e':
        color = Color{56, 100, 178, 255};
        return true;
    case 'E':
        color = Color{124, 218, 255, 255};
        return true;
    case 'p':
        color = Color{98, 68, 146, 255};
        return true;
    case 'P':
        color = Color{170, 132, 224, 255};
        return true;
    case 'q':
        color = Color{120, 216, 255, 255};
        return true;
    case 'Q':
        color = Color{214, 244, 255, 255};
        return true;
    case 'u':
        color = Color{210, 184, 136, 255};
        return true;
    case 'U':
        color = Color{246, 228, 184, 255};
        return true;
    case 'v':
        color = Color{78, 120, 122, 255};
        return true;
    case 'V':
        color = Color{120, 164, 164, 255};
        return true;
    case 'a':
        color = Color{50, 98, 144, 255};
        return true;
    case 'A':
        color = Color{100, 162, 214, 255};
        return true;
    default:
        break;
    }
    return false;
}

bool applyAuthoredAtlasSource(Image& image, const std::filesystem::path& path, std::string* error)
{
    std::ifstream input(path);
    if (!input) {
        if (error != nullptr) {
            *error = "failed to open authored atlas source";
        }
        return false;
    }

    bool header = false;
    std::optional<SpriteId> currentSprite;
    std::string currentName;
    int row = 0;
    int lineNumber = 0;
    std::string line;
    while (std::getline(input, line)) {
        ++lineNumber;
        const auto trimmed = trimAscii(line);
        if (trimmed.empty() || trimmed[0] == '#') {
            continue;
        }
        if (!header) {
            if (trimmed != "THOTH_ATLAS_ART 1") {
                if (error != nullptr) {
                    *error = "line " + std::to_string(lineNumber) + ": expected THOTH_ATLAS_ART 1";
                }
                return false;
            }
            header = true;
            continue;
        }
        if (trimmed.rfind("sprite ", 0) == 0) {
            if (currentSprite.has_value() && row != kSpritePixels) {
                if (error != nullptr) {
                    *error = "line " + std::to_string(lineNumber) + ": sprite " + currentName + " has " +
                        std::to_string(row) + " rows";
                }
                return false;
            }
            currentName = trimAscii(trimmed.substr(7));
            currentSprite = spriteIdFromName(currentName);
            row = 0;
            if (!currentSprite.has_value()) {
                if (error != nullptr) {
                    *error = "line " + std::to_string(lineNumber) + ": unknown sprite " + currentName;
                }
                return false;
            }
            continue;
        }
        if (!currentSprite.has_value()) {
            if (error != nullptr) {
                *error = "line " + std::to_string(lineNumber) + ": pixel row outside sprite";
            }
            return false;
        }
        if (row >= kSpritePixels || static_cast<int>(trimmed.size()) != kSpritePixels) {
            if (error != nullptr) {
                *error = "line " + std::to_string(lineNumber) + ": expected 16 pixel glyphs";
            }
            return false;
        }
        for (int x = 0; x < kSpritePixels; ++x) {
            Color color{};
            if (!authoredAtlasColor(trimmed[static_cast<std::size_t>(x)], color)) {
                if (error != nullptr) {
                    *error = "line " + std::to_string(lineNumber) + ": unknown pixel glyph";
                }
                return false;
            }
            if (color.a > 0) {
                ImageDrawPixel(&image, spriteOriginX(*currentSprite) + x, spriteOriginY(*currentSprite) + row, color);
            }
        }
        ++row;
        if (row == kSpritePixels) {
            currentSprite.reset();
            currentName.clear();
        }
    }

    if (!header) {
        if (error != nullptr) {
            *error = "missing authored atlas header";
        }
        return false;
    }
    if (currentSprite.has_value()) {
        if (error != nullptr) {
            *error = "sprite " + currentName + " has " + std::to_string(row) + " rows";
        }
        return false;
    }
    return true;
}

bool isExpectedAtlasImage(const Image& image)
{
    return image.data != nullptr &&
        image.width == kSpriteAtlasColumns * kSpritePixels &&
        image.height == kSpriteAtlasRows * kSpritePixels;
}

VisualAtlas loadVisualAtlas()
{
    VisualAtlas atlas;
    std::string fallbackSource = "generated";

    if (const auto path = findBundledPath(kAuthoredSpriteAtlasPath)) {
        Image authored = makeGeneratedAtlasImage();
        std::string error;
        if (applyAuthoredAtlasSource(authored, *path, &error)) {
            atlas.texture = LoadTextureFromImage(authored);
            UnloadImage(authored);
            atlas.ready = atlas.texture.id != 0;
            atlas.generated = false;
            atlas.source = path->generic_string();
            if (atlas.ready) {
                SetTextureFilter(atlas.texture, TEXTURE_FILTER_POINT);
            }
            return atlas;
        }
        UnloadImage(authored);
        fallbackSource = "generated (authored atlas invalid: " + error + ")";
    }

    if (const auto path = findBundledPath(kSpriteAtlasPath)) {
        Image external = LoadImage(path->string().c_str());
        if (isExpectedAtlasImage(external)) {
            atlas.texture = LoadTextureFromImage(external);
            UnloadImage(external);
            atlas.ready = atlas.texture.id != 0;
            atlas.generated = false;
            atlas.source = path->generic_string();
            if (atlas.ready) {
                SetTextureFilter(atlas.texture, TEXTURE_FILTER_POINT);
            }
            return atlas;
        }
        if (external.data != nullptr) {
            UnloadImage(external);
        }
        fallbackSource = "generated (external atlas invalid)";
    }

    Image image = makeGeneratedAtlasImage();
    atlas.texture = LoadTextureFromImage(image);
    UnloadImage(image);
    atlas.ready = atlas.texture.id != 0;
    atlas.generated = true;
    atlas.source = fallbackSource;
    if (atlas.ready) {
        SetTextureFilter(atlas.texture, TEXTURE_FILTER_POINT);
    }
    return atlas;
}

bool saveGeneratedAtlas(const std::filesystem::path& path, std::string* error)
{
    if (path.has_parent_path()) {
        std::error_code ec;
        std::filesystem::create_directories(path.parent_path(), ec);
        if (ec) {
            if (error != nullptr) {
                *error = "failed to create sprite asset directory: " + ec.message();
            }
            return false;
        }
    }

    Image image = makeGeneratedAtlasImage();
    const bool saved = ExportImage(image, path.string().c_str());
    UnloadImage(image);
    if (!saved && error != nullptr) {
        *error = "failed to export generated sprite atlas";
    }
    return saved;
}

bool saveAuthoredAtlas(const std::filesystem::path& path, std::string* error)
{
    const auto source = findBundledPath(kAuthoredSpriteAtlasPath);
    if (!source.has_value()) {
        if (error != nullptr) {
            *error = "authored atlas source not found: " + kAuthoredSpriteAtlasPath.generic_string();
        }
        return false;
    }

    if (path.has_parent_path()) {
        std::error_code ec;
        std::filesystem::create_directories(path.parent_path(), ec);
        if (ec) {
            if (error != nullptr) {
                *error = "failed to create sprite asset directory: " + ec.message();
            }
            return false;
        }
    }

    Image image = makeGeneratedAtlasImage();
    if (!applyAuthoredAtlasSource(image, *source, error)) {
        UnloadImage(image);
        return false;
    }

    const bool saved = ExportImage(image, path.string().c_str());
    UnloadImage(image);
    if (!saved && error != nullptr) {
        *error = "failed to export authored sprite atlas";
    }
    return saved;
}

std::vector<AudioCueSpec> defaultAudioCueSpecs()
{
    std::vector<AudioCueSpec> specs;
    specs.reserve(kToneSpecs.size());
    for (const auto& spec : kToneSpecs) {
        specs.push_back(AudioCueSpec{
            spec.filename,
            spec.frequency,
            spec.endFrequency,
            spec.seconds,
            spec.volume});
    }
    return specs;
}

bool cueFilenameKnown(std::string_view filename)
{
    for (const auto& spec : kToneSpecs) {
        if (filename == spec.filename) {
            return true;
        }
    }
    return false;
}

bool loadAuthoredAudioCueSpecs(
    const std::filesystem::path& path,
    std::vector<AudioCueSpec>& specs,
    std::string* error)
{
    std::ifstream input(path);
    if (!input) {
        if (error != nullptr) {
            *error = "failed to open authored audio cue source";
        }
        return false;
    }

    specs.clear();
    bool header = false;
    int lineNumber = 0;
    std::string line;
    while (std::getline(input, line)) {
        ++lineNumber;
        const auto trimmed = trimAscii(line);
        if (trimmed.empty() || trimmed[0] == '#') {
            continue;
        }
        if (!header) {
            if (trimmed != "THOTH_AUDIO_CUES 1") {
                if (error != nullptr) {
                    *error = "line " + std::to_string(lineNumber) + ": expected THOTH_AUDIO_CUES 1";
                }
                return false;
            }
            header = true;
            continue;
        }

        std::istringstream stream(trimmed);
        std::string token;
        AudioCueSpec spec;
        if (!(stream >> token >> spec.filename >> spec.frequency >> spec.endFrequency >> spec.seconds >> spec.volume) ||
            token != "cue") {
            if (error != nullptr) {
                *error = "line " + std::to_string(lineNumber) +
                    ": expected cue <filename> <start_hz> <end_hz> <seconds> <volume>";
            }
            return false;
        }
        std::string extra;
        if (stream >> extra) {
            if (error != nullptr) {
                *error = "line " + std::to_string(lineNumber) + ": unexpected trailing token";
            }
            return false;
        }
        if (!cueFilenameKnown(spec.filename)) {
            if (error != nullptr) {
                *error = "line " + std::to_string(lineNumber) + ": unknown cue filename " + spec.filename;
            }
            return false;
        }
        if (spec.frequency <= 0.0f || spec.endFrequency <= 0.0f ||
            spec.seconds <= 0.0f || spec.seconds > 0.35f ||
            spec.volume <= 0.0f || spec.volume > 0.4f) {
            if (error != nullptr) {
                *error = "line " + std::to_string(lineNumber) + ": invalid cue numeric range";
            }
            return false;
        }
        if (std::any_of(specs.begin(), specs.end(), [&spec](const AudioCueSpec& existing) {
                return existing.filename == spec.filename;
            })) {
            if (error != nullptr) {
                *error = "line " + std::to_string(lineNumber) + ": duplicate cue " + spec.filename;
            }
            return false;
        }
        specs.push_back(std::move(spec));
    }

    if (!header) {
        if (error != nullptr) {
            *error = "missing authored audio cue header";
        }
        return false;
    }
    if (specs.size() != kToneSpecs.size()) {
        if (error != nullptr) {
            *error = "authored audio cue source must define all " + std::to_string(kToneSpecs.size()) + " cues";
        }
        return false;
    }

    std::vector<AudioCueSpec> ordered;
    ordered.reserve(kToneSpecs.size());
    for (const auto& required : kToneSpecs) {
        const auto found = std::find_if(specs.begin(), specs.end(), [&required](const AudioCueSpec& spec) {
            return spec.filename == required.filename;
        });
        if (found == specs.end()) {
            if (error != nullptr) {
                *error = "missing cue " + std::string(required.filename);
            }
            return false;
        }
        ordered.push_back(*found);
    }
    specs = std::move(ordered);
    return true;
}

std::vector<short> makeToneSamples(float frequency, float endFrequency, float seconds, float volume)
{
    const int frameCount = std::max(1, static_cast<int>(seconds * static_cast<float>(kAudioSampleRate)));
    std::vector<short> samples(static_cast<std::size_t>(frameCount));

    for (int i = 0; i < frameCount; ++i) {
        const float t = static_cast<float>(i) / static_cast<float>(kAudioSampleRate);
        const float phase = static_cast<float>(i) / static_cast<float>(std::max(1, frameCount - 1));
        const float currentFrequency = frequency + ((endFrequency - frequency) * phase);
        const float attack = std::min(1.0f, static_cast<float>(i) / std::max(1.0f, static_cast<float>(frameCount) * 0.18f));
        const float release = 1.0f - phase;
        const float envelope = attack * release * release;
        const float wave = std::sin(2.0f * static_cast<float>(kPi) * currentFrequency * t);
        const float overtone = std::sin(2.0f * static_cast<float>(kPi) * currentFrequency * 2.0f * t) * 0.22f;
        samples[static_cast<std::size_t>(i)] = static_cast<short>((wave + overtone) * envelope * volume * 32767.0f);
    }

    return samples;
}

Wave makeToneWave(std::vector<short>& samples)
{
    Wave wave{};
    wave.frameCount = static_cast<unsigned int>(samples.size());
    wave.sampleRate = kAudioSampleRate;
    wave.sampleSize = 16;
    wave.channels = 1;
    wave.data = samples.data();
    return wave;
}

bool saveAudioCueSpecs(const std::vector<AudioCueSpec>& specs, const std::filesystem::path& directory, std::string* error)
{
    std::error_code ec;
    std::filesystem::create_directories(directory, ec);
    if (ec) {
        if (error != nullptr) {
            *error = "failed to create audio asset directory: " + ec.message();
        }
        return false;
    }

    for (const auto& spec : specs) {
        auto samples = makeToneSamples(spec.frequency, spec.endFrequency, spec.seconds, spec.volume);
        Wave wave = makeToneWave(samples);
        const auto path = directory / spec.filename;
        if (!ExportWave(wave, path.string().c_str())) {
            if (error != nullptr) {
                *error = "failed to export generated audio cue: " + path.generic_string();
            }
            return false;
        }
    }

    return true;
}

bool saveGeneratedAudioCues(const std::filesystem::path& directory, std::string* error)
{
    return saveAudioCueSpecs(defaultAudioCueSpecs(), directory, error);
}

bool saveAuthoredAudioCues(const std::filesystem::path& directory, std::string* error)
{
    const auto source = findBundledPath(kAuthoredAudioCuePath);
    if (!source.has_value()) {
        if (error != nullptr) {
            *error = "authored audio cue source not found: " + kAuthoredAudioCuePath.generic_string();
        }
        return false;
    }

    std::vector<AudioCueSpec> specs;
    if (!loadAuthoredAudioCueSpecs(*source, specs, error)) {
        return false;
    }
    return saveAudioCueSpecs(specs, directory, error);
}

bool validateAuthoredAtlasAsset(std::string* error)
{
    const auto source = findBundledPath(kAuthoredSpriteAtlasPath);
    if (!source.has_value()) {
        if (error != nullptr) {
            *error = "authored atlas source not found: " + kAuthoredSpriteAtlasPath.generic_string();
        }
        return false;
    }

    Image image = makeGeneratedAtlasImage();
    const bool valid = applyAuthoredAtlasSource(image, *source, error);
    UnloadImage(image);
    if (!valid) {
        return false;
    }

    std::cout << "validated authored atlas source " << source->generic_string() << '\n';
    return true;
}

bool validateRuntimeAtlasAsset(std::string* error)
{
    const auto path = findBundledPath(kSpriteAtlasPath);
    if (!path.has_value()) {
        if (error != nullptr) {
            *error = "runtime atlas PNG not found: " + kSpriteAtlasPath.generic_string();
        }
        return false;
    }

    Image image = LoadImage(path->string().c_str());
    const bool valid = isExpectedAtlasImage(image);
    if (image.data != nullptr) {
        UnloadImage(image);
    }
    if (!valid) {
        if (error != nullptr) {
            *error = "runtime atlas PNG has wrong dimensions: " + path->generic_string();
        }
        return false;
    }

    std::cout << "validated runtime atlas " << path->generic_string()
              << " " << (kSpriteAtlasColumns * kSpritePixels)
              << "x" << (kSpriteAtlasRows * kSpritePixels) << '\n';
    return true;
}

bool validateAudioCueWav(const std::filesystem::path& path, const AudioCueSpec& spec, std::string* error)
{
    Wave wave = LoadWave(path.string().c_str());
    const bool valid = IsWaveValid(wave);
    if (!valid) {
        if (error != nullptr) {
            *error = "invalid audio cue WAV: " + path.generic_string();
        }
        return false;
    }

    const auto cleanup = [&wave]() {
        UnloadWave(wave);
    };
    if (wave.sampleRate != kAudioSampleRate || wave.sampleSize != 16 || wave.channels != 1) {
        if (error != nullptr) {
            *error = "audio cue WAV format mismatch: " + path.generic_string();
        }
        cleanup();
        return false;
    }

    const auto expectedFrames = static_cast<unsigned int>(spec.seconds * static_cast<float>(kAudioSampleRate));
    const auto actualFrames = wave.frameCount;
    const auto frameDelta = actualFrames > expectedFrames ? actualFrames - expectedFrames : expectedFrames - actualFrames;
    if (frameDelta > 1U) {
        if (error != nullptr) {
            *error = "audio cue WAV duration mismatch: " + path.generic_string();
        }
        cleanup();
        return false;
    }

    const double seconds = static_cast<double>(wave.frameCount) / static_cast<double>(wave.sampleRate);
    cleanup();
    std::cout << "validated audio cue " << path.generic_string()
              << " " << seconds << "s\n";
    return true;
}

bool validateAudioCueAssets(std::string* error)
{
    const auto source = findBundledPath(kAuthoredAudioCuePath);
    if (!source.has_value()) {
        if (error != nullptr) {
            *error = "authored audio cue source not found: " + kAuthoredAudioCuePath.generic_string();
        }
        return false;
    }

    std::vector<AudioCueSpec> specs;
    if (!loadAuthoredAudioCueSpecs(*source, specs, error)) {
        return false;
    }
    std::cout << "validated authored audio source " << source->generic_string() << '\n';

    for (const auto& spec : specs) {
        const auto path = findBundledPath(kAudioAssetDir / spec.filename);
        if (!path.has_value()) {
            if (error != nullptr) {
                *error = "audio cue WAV not found: " + (kAudioAssetDir / spec.filename).generic_string();
            }
            return false;
        }
        if (!validateAudioCueWav(*path, spec, error)) {
            return false;
        }
    }

    return true;
}

bool validateBundledAssets(std::string* error)
{
    return validateAuthoredAtlasAsset(error) &&
        validateRuntimeAtlasAsset(error) &&
        validateAudioCueAssets(error);
}

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

bool saveMediaPreview(const std::filesystem::path& path, std::string* error);
bool saveWindowSmokeScreenshot(const std::filesystem::path& path, std::string* error);

void printCommandLineUsage(const char* executable)
{
    std::cout
        << "Usage: " << executable << " [--export-atlas [path]] [--export-authored-atlas [path]] [--export-audio [dir]] [--export-authored-audio [dir]] [--export-media-preview [path]] [--window-smoke [path]] [--validate-assets] [--validate-replays]\n"
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

void unloadVisualAtlas(VisualAtlas& atlas)
{
    if (!atlas.ready) {
        return;
    }
    UnloadTexture(atlas.texture);
    atlas.ready = false;
}

SpriteId tileSprite(thoth::game::TileId id)
{
    using thoth::game::TileId;
    switch (id) {
    case TileId::Grass:
        return SpriteId::TileGrass;
    case TileId::Dirt:
        return SpriteId::TileDirt;
    case TileId::Sand:
    case TileId::Beach:
        return SpriteId::TileSand;
    case TileId::Snow:
    case TileId::Ice:
        return SpriteId::TileSnow;
    case TileId::Mud:
    case TileId::Reeds:
        return SpriteId::TileMud;
    case TileId::Water:
    case TileId::DeepWater:
        return SpriteId::TileWater;
    case TileId::Tree:
    case TileId::Cactus:
        return SpriteId::TileTree;
    case TileId::Stone:
    case TileId::Basalt:
    case TileId::Crystal:
    case TileId::DungeonWall:
        return SpriteId::TileStone;
    case TileId::IronOre:
        return SpriteId::TileIronOre;
    case TileId::CopperOre:
        return SpriteId::TileCopperOre;
    case TileId::CoalOre:
        return SpriteId::TileCoalOre;
    case TileId::Floor:
    case TileId::Wall:
    case TileId::PlankWall:
    case TileId::Door:
    case TileId::StairsUp:
    case TileId::StairsDown:
    case TileId::Bed:
    case TileId::DungeonFloor:
        return SpriteId::TileFloor;
    case TileId::Coral:
        return SpriteId::TileWater;
    }
    return SpriteId::TileGrass;
}

SpriteId itemSprite(thoth::game::ItemId item)
{
    using thoth::game::ItemId;
    switch (item) {
    case ItemId::Wood:
        return SpriteId::ItemWood;
    case ItemId::Stone:
        return SpriteId::ItemStone;
    case ItemId::Coal:
        return SpriteId::ItemCoal;
    case ItemId::IronOre:
        return SpriteId::ItemIronOre;
    case ItemId::IronPlate:
        return SpriteId::ItemIronPlate;
    case ItemId::CopperOre:
        return SpriteId::ItemCopperOre;
    case ItemId::CopperPlate:
        return SpriteId::ItemCopperPlate;
    case ItemId::Sand:
    case ItemId::Shell:
    case ItemId::IceShard:
        return SpriteId::TileSand;
    case ItemId::SandGlass:
    case ItemId::Crystal:
    case ItemId::Venom:
        return SpriteId::ItemSciencePack;
    case ItemId::ReedFiber:
    case ItemId::CactusFiber:
    case ItemId::Kelp:
        return SpriteId::TileTree;
    case ItemId::CoralShard:
        return SpriteId::TileWater;
    case ItemId::Basalt:
    case ItemId::Bone:
        return SpriteId::ItemStone;
    case ItemId::Hide:
    case ItemId::Slime:
        return SpriteId::ItemWood;
    case ItemId::SciencePack:
        return SpriteId::ItemSciencePack;
    case ItemId::AdvancedSciencePack:
        return SpriteId::ItemSciencePack;
    case ItemId::CircuitBoard:
        return SpriteId::ItemCopperPlate;
    case ItemId::Belt:
        return SpriteId::MachineBelt;
    case ItemId::FastBelt:
        return SpriteId::MachineFastBelt;
    case ItemId::Inserter:
        return SpriteId::MachineInserter;
    case ItemId::CircuitInserter:
        return SpriteId::MachineInserter;
    case ItemId::BurnerMiner:
        return SpriteId::MachineBurnerMiner;
    case ItemId::Furnace:
        return SpriteId::MachineFurnace;
    case ItemId::Chest:
        return SpriteId::MachineChest;
    case ItemId::ProviderChest:
    case ItemId::RequesterChest:
        return SpriteId::MachineChest;
    case ItemId::Workbench:
        return SpriteId::MachineWorkbench;
    case ItemId::Assembler:
        return SpriteId::MachineAssembler;
    case ItemId::Lab:
        return SpriteId::MachineLab;
    case ItemId::Generator:
        return SpriteId::MachineGenerator;
    case ItemId::PowerPole:
        return SpriteId::MachinePowerPole;
    case ItemId::ElectricMiner:
        return SpriteId::MachineElectricMiner;
    case ItemId::LogisticPort:
        return SpriteId::MachinePowerPole;
    case ItemId::LogisticDrone:
        return SpriteId::MachineElectricMiner;
    case ItemId::BeaconCore:
        return SpriteId::ItemSciencePack;
    case ItemId::ArchiveTerminal:
        return SpriteId::MachineLab;
    case ItemId::Splitter:
        return SpriteId::MachineFastBelt;
    case ItemId::TrainStop:
        return SpriteId::MachineChest;
    case ItemId::WaterBarrel:
        return SpriteId::TileWater;
    case ItemId::Pipe:
        return SpriteId::MachineBelt;
    case ItemId::OffshorePump:
        return SpriteId::MachineElectricMiner;
    case ItemId::RiftGate:
        return SpriteId::MachineLab;
    case ItemId::Wall:
    case ItemId::PlankWall:
    case ItemId::Door:
    case ItemId::StairsUp:
    case ItemId::StairsDown:
    case ItemId::Bed:
        return SpriteId::TileFloor;
    case ItemId::Boat:
        return SpriteId::TileWater;
    case ItemId::None:
        return SpriteId::TileFloor;
    }
    return SpriteId::TileFloor;
}

SpriteId placementSprite(thoth::game::ItemId item)
{
    const auto& def = thoth::game::itemDef(item);
    if (def.canPlaceTile) {
        return tileSprite(def.placeTile);
    }
    return itemSprite(item);
}

SpriteId machineSprite(thoth::game::MachineKind kind)
{
    using thoth::game::MachineKind;
    switch (kind) {
    case MachineKind::Belt:
        return SpriteId::MachineBelt;
    case MachineKind::FastBelt:
        return SpriteId::MachineFastBelt;
    case MachineKind::Inserter:
        return SpriteId::MachineInserter;
    case MachineKind::CircuitInserter:
        return SpriteId::MachineInserter;
    case MachineKind::BurnerMiner:
        return SpriteId::MachineBurnerMiner;
    case MachineKind::Furnace:
        return SpriteId::MachineFurnace;
    case MachineKind::Chest:
        return SpriteId::MachineChest;
    case MachineKind::ProviderChest:
    case MachineKind::RequesterChest:
        return SpriteId::MachineChest;
    case MachineKind::Workbench:
        return SpriteId::MachineWorkbench;
    case MachineKind::Assembler:
        return SpriteId::MachineAssembler;
    case MachineKind::Lab:
        return SpriteId::MachineLab;
    case MachineKind::Generator:
        return SpriteId::MachineGenerator;
    case MachineKind::PowerPole:
        return SpriteId::MachinePowerPole;
    case MachineKind::ElectricMiner:
        return SpriteId::MachineElectricMiner;
    case MachineKind::LogisticPort:
        return SpriteId::MachinePowerPole;
    case MachineKind::ArchiveTerminal:
        return SpriteId::MachineLab;
    case MachineKind::Splitter:
        return SpriteId::MachineFastBelt;
    case MachineKind::TrainStop:
        return SpriteId::MachineChest;
    case MachineKind::Pipe:
        return SpriteId::MachineBelt;
    case MachineKind::OffshorePump:
        return SpriteId::MachineElectricMiner;
    case MachineKind::RiftGate:
        return SpriteId::MachineLab;
    }
    return SpriteId::MachineChest;
}

bool drawSprite(SpriteId id, Rectangle destination, SpriteDrawOptions options)
{
    if (gVisualAtlas == nullptr || !gVisualAtlas->ready) {
        return false;
    }
    DrawTexturePro(gVisualAtlas->texture, transformedSpriteSource(id, options), destination, Vector2{0.0f, 0.0f}, 0.0f, options.tint);
    return true;
}

bool drawSprite(SpriteId id, Rectangle destination, Color tint = WHITE)
{
    return drawSprite(id, destination, SpriteDrawOptions{false, false, tint});
}

bool drawSpriteCentered(SpriteId id, int centerX, int centerY, int size, Color tint = WHITE)
{
    const Rectangle destination{
        static_cast<float>(centerX - (size / 2)),
        static_cast<float>(centerY - (size / 2)),
        static_cast<float>(size),
        static_cast<float>(size),
    };
    return drawSprite(id, destination, tint);
}

Sound makeTone(const AudioCueSpec& spec)
{
    auto samples = makeToneSamples(spec.frequency, spec.endFrequency, spec.seconds, spec.volume);
    Wave wave = makeToneWave(samples);
    return LoadSoundFromWave(wave);
}

Sound loadCueSound(const AudioCueSpec& spec, int& externalSounds)
{
    if (const auto path = findBundledPath(kAudioAssetDir / spec.filename)) {
        Sound sound = LoadSound(path->string().c_str());
        if (IsSoundValid(sound)) {
            ++externalSounds;
            return sound;
        }
    }

    return makeTone(spec);
}

AudioBank loadAudioBank()
{
    AudioBank audio;
    InitAudioDevice();
    audio.ready = IsAudioDeviceReady();
    if (!audio.ready) {
        audio.source = "disabled";
        return audio;
    }

    auto specs = defaultAudioCueSpecs();
    std::string specSource = "generated tones";
    if (const auto source = findBundledPath(kAuthoredAudioCuePath)) {
        std::vector<AudioCueSpec> authoredSpecs;
        std::string error;
        if (loadAuthoredAudioCueSpecs(*source, authoredSpecs, &error)) {
            specs = std::move(authoredSpecs);
            specSource = "authored cues";
        } else {
            specSource = "generated tones (authored cues invalid: " + error + ")";
        }
    }

    audio.mine = loadCueSound(specs[0], audio.externalSounds);
    audio.place = loadCueSound(specs[1], audio.externalSounds);
    audio.craft = loadCueSound(specs[2], audio.externalSounds);
    audio.invalid = loadCueSound(specs[3], audio.externalSounds);
    audio.save = loadCueSound(specs[4], audio.externalSounds);
    audio.load = loadCueSound(specs[5], audio.externalSounds);
    audio.tick = loadCueSound(specs[6], audio.externalSounds);
    audio.produce = loadCueSound(specs[7], audio.externalSounds);
    audio.source = audio.externalSounds > 0 ?
        "assets/audio " + std::to_string(audio.externalSounds) + "/8 + " + specSource :
        specSource;
    return audio;
}

void unloadSoundIfValid(Sound sound)
{
    if (IsSoundValid(sound)) {
        UnloadSound(sound);
    }
}

void unloadAudioBank(AudioBank& audio)
{
    if (!audio.ready) {
        return;
    }

    unloadSoundIfValid(audio.mine);
    unloadSoundIfValid(audio.place);
    unloadSoundIfValid(audio.craft);
    unloadSoundIfValid(audio.invalid);
    unloadSoundIfValid(audio.save);
    unloadSoundIfValid(audio.load);
    unloadSoundIfValid(audio.tick);
    unloadSoundIfValid(audio.produce);
    CloseAudioDevice();
    audio.ready = false;
}

void playCue(const AudioBank& audio, const Sound& sound)
{
    if (audio.ready && IsSoundValid(sound)) {
        PlaySound(sound);
    }
}

int audioCueIndex(int index)
{
    const auto cueCount = static_cast<int>(kToneSpecs.size());
    if (cueCount <= 0) {
        return 0;
    }
    const int wrapped = index % cueCount;
    return wrapped < 0 ? wrapped + cueCount : wrapped;
}

std::string_view audioCueName(int index)
{
    return kToneSpecs[static_cast<std::size_t>(audioCueIndex(index))].filename;
}

const Sound& audioCueSound(const AudioBank& audio, int index)
{
    switch (audioCueIndex(index)) {
    case 0:
        return audio.mine;
    case 1:
        return audio.place;
    case 2:
        return audio.craft;
    case 3:
        return audio.invalid;
    case 4:
        return audio.save;
    case 5:
        return audio.load;
    case 6:
        return audio.tick;
    case 7:
        return audio.produce;
    }
    return audio.tick;
}

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

Color machineColor(thoth::game::MachineKind kind)
{
    using thoth::game::MachineKind;
    switch (kind) {
    case MachineKind::Belt:
        return Color{204, 166, 63, 255};
    case MachineKind::FastBelt:
        return Color{232, 196, 72, 255};
    case MachineKind::Inserter:
        return Color{80, 142, 142, 255};
    case MachineKind::CircuitInserter:
        return Color{91, 178, 154, 255};
    case MachineKind::BurnerMiner:
        return Color{114, 86, 70, 255};
    case MachineKind::Furnace:
        return Color{94, 96, 102, 255};
    case MachineKind::Chest:
        return Color{155, 101, 54, 255};
    case MachineKind::ProviderChest:
        return Color{168, 121, 56, 255};
    case MachineKind::RequesterChest:
        return Color{90, 138, 177, 255};
    case MachineKind::Workbench:
        return Color{123, 83, 51, 255};
    case MachineKind::Assembler:
        return Color{72, 124, 172, 255};
    case MachineKind::Lab:
        return Color{132, 94, 174, 255};
    case MachineKind::Generator:
        return Color{186, 111, 55, 255};
    case MachineKind::PowerPole:
        return Color{189, 174, 126, 255};
    case MachineKind::ElectricMiner:
        return Color{83, 116, 188, 255};
    case MachineKind::LogisticPort:
        return Color{91, 184, 204, 255};
    case MachineKind::ArchiveTerminal:
        return Color{116, 92, 190, 255};
    case MachineKind::Splitter:
        return Color{218, 182, 64, 255};
    case MachineKind::TrainStop:
        return Color{126, 126, 142, 255};
    case MachineKind::Pipe:
        return Color{70, 146, 168, 255};
    case MachineKind::OffshorePump:
        return Color{64, 132, 188, 255};
    case MachineKind::RiftGate:
        return Color{146, 76, 210, 255};
    }
    return Color{220, 220, 220, 255};
}

Color itemColor(thoth::game::ItemId item)
{
    using thoth::game::ItemId;
    switch (item) {
    case ItemId::Wood:
        return Color{118, 81, 46, 255};
    case ItemId::Stone:
        return Color{154, 158, 151, 255};
    case ItemId::Coal:
        return Color{42, 45, 49, 255};
    case ItemId::IronOre:
        return Color{171, 132, 96, 255};
    case ItemId::IronPlate:
        return Color{198, 205, 196, 255};
    case ItemId::CopperOre:
        return Color{178, 106, 70, 255};
    case ItemId::CopperPlate:
        return Color{218, 135, 76, 255};
    case ItemId::Sand:
    case ItemId::SandGlass:
    case ItemId::Shell:
        return Color{218, 198, 122, 255};
    case ItemId::ReedFiber:
    case ItemId::CactusFiber:
    case ItemId::Kelp:
        return Color{82, 156, 82, 255};
    case ItemId::CoralShard:
    case ItemId::Venom:
        return Color{214, 100, 144, 255};
    case ItemId::IceShard:
        return Color{154, 218, 230, 255};
    case ItemId::Basalt:
    case ItemId::Bone:
        return Color{118, 118, 126, 255};
    case ItemId::Crystal:
        return Color{112, 210, 218, 255};
    case ItemId::Hide:
        return Color{136, 84, 52, 255};
    case ItemId::Slime:
        return Color{96, 204, 112, 255};
    case ItemId::Belt:
        return Color{204, 166, 63, 255};
    case ItemId::Inserter:
        return Color{80, 142, 142, 255};
    case ItemId::BurnerMiner:
        return Color{114, 86, 70, 255};
    case ItemId::Furnace:
        return Color{94, 96, 102, 255};
    case ItemId::Chest:
        return Color{155, 101, 54, 255};
    case ItemId::Workbench:
        return Color{123, 83, 51, 255};
    case ItemId::SciencePack:
        return Color{118, 210, 255, 255};
    case ItemId::AdvancedSciencePack:
        return Color{184, 130, 244, 255};
    case ItemId::CircuitBoard:
        return Color{78, 174, 122, 255};
    case ItemId::Assembler:
        return Color{72, 124, 172, 255};
    case ItemId::Lab:
        return Color{132, 94, 174, 255};
    case ItemId::FastBelt:
        return Color{232, 196, 72, 255};
    case ItemId::Generator:
        return Color{186, 111, 55, 255};
    case ItemId::PowerPole:
        return Color{189, 174, 126, 255};
    case ItemId::ElectricMiner:
        return Color{83, 116, 188, 255};
    case ItemId::CircuitInserter:
        return Color{91, 178, 154, 255};
    case ItemId::ProviderChest:
        return Color{168, 121, 56, 255};
    case ItemId::RequesterChest:
        return Color{90, 138, 177, 255};
    case ItemId::LogisticPort:
        return Color{91, 184, 204, 255};
    case ItemId::LogisticDrone:
        return Color{150, 214, 226, 255};
    case ItemId::BeaconCore:
        return Color{202, 164, 255, 255};
    case ItemId::ArchiveTerminal:
        return Color{116, 92, 190, 255};
    case ItemId::Splitter:
        return Color{218, 182, 64, 255};
    case ItemId::TrainStop:
        return Color{126, 126, 142, 255};
    case ItemId::WaterBarrel:
        return Color{86, 184, 226, 255};
    case ItemId::Pipe:
        return Color{70, 146, 168, 255};
    case ItemId::OffshorePump:
        return Color{64, 132, 188, 255};
    case ItemId::RiftGate:
        return Color{146, 76, 210, 255};
    case ItemId::Wall:
    case ItemId::PlankWall:
    case ItemId::Door:
    case ItemId::StairsUp:
    case ItemId::StairsDown:
    case ItemId::Boat:
    case ItemId::Bed:
        return Color{144, 112, 76, 255};
    case ItemId::None:
        return Color{70, 76, 78, 255};
    }
    return Color{220, 220, 220, 255};
}

Color statusColor(thoth::game::MachineStatus status)
{
    using thoth::game::MachineStatus;
    switch (status) {
    case MachineStatus::Working:
        return Color{98, 220, 118, 255};
    case MachineStatus::MissingInput:
        return Color{236, 205, 95, 255};
    case MachineStatus::MissingFuel:
        return Color{236, 136, 72, 255};
    case MachineStatus::MissingPower:
        return Color{112, 184, 244, 255};
    case MachineStatus::OutputBlocked:
        return Color{236, 84, 84, 255};
    case MachineStatus::Idle:
        return Color{184, 194, 188, 255};
    }
    return RAYWHITE;
}

bool makeAuthoredAtlasImage(Image& image, std::string* error)
{
    const auto source = findBundledPath(kAuthoredSpriteAtlasPath);
    if (!source.has_value()) {
        if (error != nullptr) {
            *error = "authored atlas source not found: " + kAuthoredSpriteAtlasPath.generic_string();
        }
        return false;
    }

    image = makeGeneratedAtlasImage();
    if (!applyAuthoredAtlasSource(image, *source, error)) {
        UnloadImage(image);
        image = Image{};
        return false;
    }
    return true;
}

void drawPreviewRectLines(Image& image, int x, int y, int width, int height, Color color)
{
    ImageDrawRectangle(&image, x, y, width, 1, color);
    ImageDrawRectangle(&image, x, y + height - 1, width, 1, color);
    ImageDrawRectangle(&image, x, y, 1, height, color);
    ImageDrawRectangle(&image, x + width - 1, y, 1, height, color);
}

std::array<std::uint8_t, 7> previewGlyph(char raw)
{
    char c = raw;
    if (c >= 'a' && c <= 'z') {
        c = static_cast<char>('A' + (c - 'a'));
    }

    switch (c) {
    case 'A':
        return {0b01110, 0b10001, 0b10001, 0b11111, 0b10001, 0b10001, 0b10001};
    case 'B':
        return {0b11110, 0b10001, 0b10001, 0b11110, 0b10001, 0b10001, 0b11110};
    case 'C':
        return {0b01111, 0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b01111};
    case 'D':
        return {0b11110, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b11110};
    case 'E':
        return {0b11111, 0b10000, 0b10000, 0b11110, 0b10000, 0b10000, 0b11111};
    case 'F':
        return {0b11111, 0b10000, 0b10000, 0b11110, 0b10000, 0b10000, 0b10000};
    case 'G':
        return {0b01111, 0b10000, 0b10000, 0b10111, 0b10001, 0b10001, 0b01111};
    case 'H':
        return {0b10001, 0b10001, 0b10001, 0b11111, 0b10001, 0b10001, 0b10001};
    case 'I':
        return {0b11111, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b11111};
    case 'J':
        return {0b00111, 0b00010, 0b00010, 0b00010, 0b10010, 0b10010, 0b01100};
    case 'K':
        return {0b10001, 0b10010, 0b10100, 0b11000, 0b10100, 0b10010, 0b10001};
    case 'L':
        return {0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b11111};
    case 'M':
        return {0b10001, 0b11011, 0b10101, 0b10101, 0b10001, 0b10001, 0b10001};
    case 'N':
        return {0b10001, 0b11001, 0b10101, 0b10011, 0b10001, 0b10001, 0b10001};
    case 'O':
        return {0b01110, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01110};
    case 'P':
        return {0b11110, 0b10001, 0b10001, 0b11110, 0b10000, 0b10000, 0b10000};
    case 'Q':
        return {0b01110, 0b10001, 0b10001, 0b10001, 0b10101, 0b10010, 0b01101};
    case 'R':
        return {0b11110, 0b10001, 0b10001, 0b11110, 0b10100, 0b10010, 0b10001};
    case 'S':
        return {0b01111, 0b10000, 0b10000, 0b01110, 0b00001, 0b00001, 0b11110};
    case 'T':
        return {0b11111, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100};
    case 'U':
        return {0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01110};
    case 'V':
        return {0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01010, 0b00100};
    case 'W':
        return {0b10001, 0b10001, 0b10001, 0b10101, 0b10101, 0b10101, 0b01010};
    case 'X':
        return {0b10001, 0b10001, 0b01010, 0b00100, 0b01010, 0b10001, 0b10001};
    case 'Y':
        return {0b10001, 0b10001, 0b01010, 0b00100, 0b00100, 0b00100, 0b00100};
    case 'Z':
        return {0b11111, 0b00001, 0b00010, 0b00100, 0b01000, 0b10000, 0b11111};
    case '0':
        return {0b01110, 0b10001, 0b10011, 0b10101, 0b11001, 0b10001, 0b01110};
    case '1':
        return {0b00100, 0b01100, 0b00100, 0b00100, 0b00100, 0b00100, 0b01110};
    case '2':
        return {0b01110, 0b10001, 0b00001, 0b00010, 0b00100, 0b01000, 0b11111};
    case '3':
        return {0b11110, 0b00001, 0b00001, 0b01110, 0b00001, 0b00001, 0b11110};
    case '4':
        return {0b00010, 0b00110, 0b01010, 0b10010, 0b11111, 0b00010, 0b00010};
    case '5':
        return {0b11111, 0b10000, 0b10000, 0b11110, 0b00001, 0b00001, 0b11110};
    case '6':
        return {0b01110, 0b10000, 0b10000, 0b11110, 0b10001, 0b10001, 0b01110};
    case '7':
        return {0b11111, 0b00001, 0b00010, 0b00100, 0b01000, 0b01000, 0b01000};
    case '8':
        return {0b01110, 0b10001, 0b10001, 0b01110, 0b10001, 0b10001, 0b01110};
    case '9':
        return {0b01110, 0b10001, 0b10001, 0b01111, 0b00001, 0b00001, 0b01110};
    case '-':
        return {0b00000, 0b00000, 0b00000, 0b11110, 0b00000, 0b00000, 0b00000};
    case '>':
        return {0b10000, 0b01000, 0b00100, 0b00010, 0b00100, 0b01000, 0b10000};
    case ':':
        return {0b00000, 0b00100, 0b00100, 0b00000, 0b00100, 0b00100, 0b00000};
    case '/':
        return {0b00001, 0b00001, 0b00010, 0b00100, 0b01000, 0b10000, 0b10000};
    case '_':
        return {0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b11111};
    case '.':
        return {0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b01100, 0b01100};
    case '+':
        return {0b00000, 0b00100, 0b00100, 0b11111, 0b00100, 0b00100, 0b00000};
    case ' ':
        return {};
    }
    return {0b01110, 0b10001, 0b00001, 0b00010, 0b00100, 0b00000, 0b00100};
}

void drawPreviewText(Image& image, std::string_view text, int x, int y, int scale, Color color)
{
    constexpr int glyphWidth = 5;
    constexpr int glyphHeight = 7;
    constexpr int glyphAdvance = 6;
    int cursorX = x;
    int cursorY = y;

    for (const char raw : text) {
        if (raw == '\n') {
            cursorX = x;
            cursorY += (glyphHeight + 2) * scale;
            continue;
        }

        const auto glyph = previewGlyph(raw);
        for (int row = 0; row < glyphHeight; ++row) {
            for (int column = 0; column < glyphWidth; ++column) {
                const bool filled = ((glyph[row] >> (glyphWidth - 1 - column)) & 1U) != 0;
                if (filled) {
                    ImageDrawRectangle(
                        &image,
                        cursorX + column * scale,
                        cursorY + row * scale,
                        scale,
                        scale,
                        color);
                }
            }
        }
        cursorX += glyphAdvance * scale;
    }
}

void drawPreviewSprite(
    Image& target,
    const Color* atlasPixels,
    SpriteId id,
    int x,
    int y,
    int scale,
    SpriteDrawOptions options = {})
{
    const int atlasWidth = kSpriteAtlasColumns * kSpritePixels;
    const int originX = spriteOriginX(id);
    const int originY = spriteOriginY(id);
    for (int sy = 0; sy < kSpritePixels; ++sy) {
        for (int sx = 0; sx < kSpritePixels; ++sx) {
            const int sourceX = options.flipX ? (kSpritePixels - 1 - sx) : sx;
            const int sourceY = options.flipY ? (kSpritePixels - 1 - sy) : sy;
            const auto color = multiplyTint(atlasPixels[(originY + sourceY) * atlasWidth + originX + sourceX], options.tint);
            if (color.a == 0) {
                continue;
            }
            ImageDrawRectangle(&target, x + sx * scale, y + sy * scale, scale, scale, color);
        }
    }
}

void drawPreviewLine(Image& image, int x, int& y, std::string_view text, int scale, Color color)
{
    drawPreviewText(image, text, x, y, scale, color);
    y += (7 * scale) + 8;
}

bool previewMachineIssue(thoth::game::MachineStatus status)
{
    using thoth::game::MachineStatus;
    return status == MachineStatus::MissingInput ||
        status == MachineStatus::MissingFuel ||
        status == MachineStatus::MissingPower ||
        status == MachineStatus::OutputBlocked;
}

std::string previewMachineIssueBadgeText(thoth::game::MachineStatus status)
{
    using thoth::game::MachineStatus;
    switch (status) {
    case MachineStatus::MissingInput:
        return "i";
    case MachineStatus::MissingFuel:
        return "f";
    case MachineStatus::MissingPower:
        return "p";
    case MachineStatus::OutputBlocked:
        return "b";
    case MachineStatus::Idle:
    case MachineStatus::Working:
        break;
    }
    return "";
}

int renderAnimationPhase(std::uint64_t tick, int x, int y, int period)
{
    if (period <= 0) {
        return 0;
    }
    const auto offset = thoth::core::hashCoordinates(0xa7c0518e5ULL, x, y) % static_cast<std::uint64_t>(period);
    return static_cast<int>((tick + offset) % static_cast<std::uint64_t>(period));
}

bool isBeltMachine(thoth::game::MachineKind kind)
{
    return kind == thoth::game::MachineKind::Belt ||
        kind == thoth::game::MachineKind::FastBelt ||
        kind == thoth::game::MachineKind::Splitter ||
        kind == thoth::game::MachineKind::Pipe;
}

Color activityPulseColor(thoth::game::MachineKind kind)
{
    using thoth::game::MachineKind;
    switch (kind) {
    case MachineKind::BurnerMiner:
    case MachineKind::Furnace:
    case MachineKind::Generator:
        return Color{255, 158, 72, 255};
    case MachineKind::ElectricMiner:
    case MachineKind::PowerPole:
    case MachineKind::LogisticPort:
    case MachineKind::OffshorePump:
        return Color{118, 210, 255, 255};
    case MachineKind::ArchiveTerminal:
    case MachineKind::RiftGate:
        return Color{202, 164, 255, 255};
    case MachineKind::TrainStop:
        return Color{200, 200, 210, 255};
    case MachineKind::Assembler:
        return Color{118, 230, 164, 255};
    case MachineKind::Lab:
        return Color{180, 132, 238, 255};
    case MachineKind::Inserter:
    case MachineKind::CircuitInserter:
        return Color{196, 236, 226, 255};
    case MachineKind::Belt:
    case MachineKind::FastBelt:
    case MachineKind::Splitter:
    case MachineKind::Pipe:
    case MachineKind::Chest:
    case MachineKind::ProviderChest:
    case MachineKind::RequesterChest:
    case MachineKind::Workbench:
        break;
    }
    return Color{210, 220, 214, 255};
}

bool hasMachineActivityPulse(const thoth::game::Machine& machine)
{
    using thoth::game::MachineKind;
    using thoth::game::MachineStatus;
    if (isBeltMachine(machine.kind) ||
        machine.kind == MachineKind::Chest ||
        machine.kind == MachineKind::ProviderChest ||
        machine.kind == MachineKind::RequesterChest ||
        machine.kind == MachineKind::Workbench) {
        return false;
    }
    return machine.status == MachineStatus::Working ||
        machine.progress > 0 ||
        machine.fuelTicks > 0 ||
        machine.carriedItem != thoth::game::ItemId::None ||
        machine.outputItem != thoth::game::ItemId::None;
}

unsigned char pulseAlpha(std::uint64_t tick, int x, int y, int baseAlpha, int rangeAlpha)
{
    constexpr int period = 32;
    const int phase = renderAnimationPhase(tick, x, y, period);
    const int triangle = phase < (period / 2) ? phase : period - phase;
    return static_cast<unsigned char>(std::clamp(baseAlpha + ((triangle * rangeAlpha) / (period / 2)), 0, 255));
}

void drawPreviewBeltMotionOverlay(
    Image& image,
    const thoth::game::Machine& machine,
    std::uint64_t tick,
    int px,
    int py,
    int tileSize)
{
    if (!isBeltMachine(machine.kind)) {
        return;
    }

    const int period = machine.kind == thoth::game::MachineKind::FastBelt ? 6 : 8;
    const int phase = renderAnimationPhase(tick / (machine.kind == thoth::game::MachineKind::FastBelt ? 2U : 4U), machine.x, machine.y, period);
    const int travel = std::max(1, tileSize - 14);
    const int along = -travel / 2 + ((travel * phase) / std::max(1, period - 1));
    const int cx = px + (tileSize / 2) + thoth::game::dx(machine.direction) * along;
    const int cy = py + (tileSize / 2) + thoth::game::dy(machine.direction) * along;
    const int normX = -thoth::game::dy(machine.direction);
    const int normY = thoth::game::dx(machine.direction);
    const int span = std::max(5, tileSize / 4);
    const int thickness = std::max(2, tileSize / 12);
    const Color color = machine.kind == thoth::game::MachineKind::FastBelt ?
        Color{255, 248, 190, 205} :
        Color{40, 32, 24, 190};

    if (normX != 0) {
        ImageDrawRectangle(&image, cx - (span / 2), cy - (thickness / 2), span, thickness, color);
    } else if (normY != 0) {
        ImageDrawRectangle(&image, cx - (thickness / 2), cy - (span / 2), thickness, span, color);
    }
}

void drawPreviewMachineActivityOverlay(
    Image& image,
    const thoth::game::Machine& machine,
    std::uint64_t tick,
    int px,
    int py,
    int tileSize)
{
    if (!hasMachineActivityPulse(machine)) {
        return;
    }

    auto color = activityPulseColor(machine.kind);
    color.a = pulseAlpha(tick, machine.x, machine.y, 82, 84);
    const int inset = std::max(4, tileSize / 8);
    const int diode = std::max(5, tileSize / 8);
    const int railHeight = std::max(3, tileSize / 15);
    ImageDrawRectangle(&image, px + inset, py + tileSize - inset - diode, diode, diode, color);
    ImageDrawRectangle(
        &image,
        px + inset + diode + 3,
        py + tileSize - inset - railHeight,
        tileSize - (inset * 2) - diode - 3,
        railHeight,
        color);
}

void drawPreviewGrid(
    Image& image,
    const Color* atlasPixels,
    const thoth::game::Simulation& sim,
    int originX,
    int originY,
    int tileSize)
{
    int minX = sim.player().x;
    int maxX = sim.player().x;
    int minY = sim.player().y;
    int maxY = sim.player().y;
    for (const auto& machine : sim.machines()) {
        minX = std::min(minX, machine.x);
        maxX = std::max(maxX, machine.x);
        minY = std::min(minY, machine.y);
        maxY = std::max(maxY, machine.y);
    }
    --minX;
    ++maxX;
    --minY;
    ++maxY;

    const int scale = std::max(1, tileSize / kSpritePixels);
    for (int y = minY; y <= maxY; ++y) {
        for (int x = minX; x <= maxX; ++x) {
            const int px = originX + (x - minX) * tileSize;
            const int py = originY + (y - minY) * tileSize;
            const auto tile = sim.world().getTile(x, y);
            ImageDrawRectangle(&image, px, py, tileSize, tileSize, Color{18, 22, 22, 255});
            drawPreviewSprite(image, atlasPixels, tileSprite(tile.id), px, py, scale, tileSpriteOptions(tile.id, x, y));
            drawPreviewRectLines(image, px, py, tileSize, tileSize, Color{0, 0, 0, 72});
            if (tile.data > 0) {
                ImageDrawRectangle(&image, px + tileSize - 13, py + 3, 10, 10, Color{10, 12, 12, 190});
                drawPreviewText(image, std::to_string(tile.data), px + tileSize - 11, py + 5, 1, RAYWHITE);
            }
        }
    }

    for (const auto& machine : sim.machines()) {
        const int px = originX + (machine.x - minX) * tileSize;
        const int py = originY + (machine.y - minY) * tileSize;
        drawPreviewSprite(image, atlasPixels, machineSprite(machine.kind), px, py, scale);
        drawPreviewMachineActivityOverlay(image, machine, sim.tick(), px, py, tileSize);
        drawPreviewBeltMotionOverlay(image, machine, sim.tick(), px, py, tileSize);
        drawPreviewRectLines(image, px + 2, py + 2, tileSize - 4, tileSize - 4, statusColor(machine.status));

        const int cx = px + tileSize / 2;
        const int cy = py + tileSize / 2;
        ImageDrawLine(
            &image,
            cx,
            cy,
            cx + thoth::game::dx(machine.direction) * (tileSize / 3),
            cy + thoth::game::dy(machine.direction) * (tileSize / 3),
            Color{248, 248, 232, 230});

        if (previewMachineIssue(machine.status)) {
            const auto badge = previewMachineIssueBadgeText(machine.status);
            ImageDrawRectangle(&image, px + tileSize - 16, py + 2, 14, 12, Color{12, 14, 14, 210});
            drawPreviewText(image, badge, px + tileSize - 12, py + 5, 1, statusColor(machine.status));
        }
    }

    const int playerX = originX + (sim.player().x - minX) * tileSize;
    const int playerY = originY + (sim.player().y - minY) * tileSize;
    drawPreviewSprite(image, atlasPixels, SpriteId::Player, playerX, playerY, scale);
    drawPreviewRectLines(image, playerX + 5, playerY + 5, tileSize - 10, tileSize - 10, Color{246, 248, 232, 255});
}

void drawPreviewSpriteStrip(Image& image, const Color* atlasPixels, int x, int y)
{
    const std::array<SpriteId, 14> sprites = {
        SpriteId::TileIronOre,
        SpriteId::MachineBurnerMiner,
        SpriteId::MachineBelt,
        SpriteId::MachineInserter,
        SpriteId::MachineFurnace,
        SpriteId::MachineChest,
        SpriteId::MachineAssembler,
        SpriteId::MachineLab,
        SpriteId::MachineGenerator,
        SpriteId::MachinePowerPole,
        SpriteId::MachineElectricMiner,
        SpriteId::ItemIronPlate,
        SpriteId::ItemSciencePack,
        SpriteId::Player,
    };
    constexpr int scale = 2;
    constexpr int spriteSize = kSpritePixels * scale;
    constexpr int gap = 8;
    for (std::size_t i = 0; i < sprites.size(); ++i) {
        const int px = x + static_cast<int>(i) * (spriteSize + gap);
        drawPreviewSprite(image, atlasPixels, sprites[i], px, y, scale);
        drawPreviewRectLines(image, px, y, spriteSize, spriteSize, Color{0, 0, 0, 110});
    }
}

bool saveMediaPreview(const std::filesystem::path& path, std::string* error)
{
    const auto replayPath = findBundledPath(kFullFlowReplayPath);
    if (!replayPath.has_value()) {
        if (error != nullptr) {
            *error = "full-flow replay not found: " + kFullFlowReplayPath.generic_string();
        }
        return false;
    }

    std::string localError;
    auto document = thoth::game::loadReplayDocument(*replayPath, &localError);
    if (!document.has_value()) {
        if (error != nullptr) {
            *error = "failed to load full-flow replay: " + localError;
        }
        return false;
    }
    auto simulation = thoth::game::runReplayDocument(*document);
    if (!validateFullFlowReplay(simulation, *document, &localError)) {
        if (error != nullptr) {
            *error = "full-flow replay failed validation: " + localError;
        }
        return false;
    }

    Image atlas{};
    if (!makeAuthoredAtlasImage(atlas, error)) {
        return false;
    }
    Color* atlasPixels = LoadImageColors(atlas);
    if (atlasPixels == nullptr) {
        UnloadImage(atlas);
        if (error != nullptr) {
            *error = "failed to read authored atlas pixels";
        }
        return false;
    }

    Image preview = GenImageColor(960, 540, Color{14, 18, 20, 255});
    drawPreviewText(preview, "Thoth full-flow replay preview", 28, 24, 3, Color{232, 238, 232, 255});
    drawPreviewText(preview, "mining -> first automation -> science -> research -> electric mining", 30, 55, 2, Color{154, 172, 168, 255});

    ImageDrawRectangle(&preview, 22, 82, 406, 360, Color{24, 30, 30, 255});
    drawPreviewRectLines(preview, 22, 82, 406, 360, Color{54, 66, 64, 255});
    drawPreviewGrid(preview, atlasPixels, simulation, 34, 98, 48);

    ImageDrawRectangle(&preview, 452, 82, 470, 360, Color{24, 30, 30, 255});
    drawPreviewRectLines(preview, 452, 82, 470, 360, Color{54, 66, 64, 255});
    int y = 104;
    drawPreviewLine(preview, 476, y, "Deterministic artifact", 2, Color{232, 238, 232, 255});
    drawPreviewLine(preview, 476, y, "replay: " + kFullFlowReplayPath.generic_string(), 1, Color{170, 188, 184, 255});
    drawPreviewLine(preview, 476, y, "tick: " + std::to_string(simulation.tick()) +
        " / machines: " + std::to_string(simulation.machines().size()), 1, RAYWHITE);

    const auto* firstChest = simulation.machineAt(5, 0);
    const auto* poweredChest = simulation.machineAt(3, 4);
    const int plates = firstChest == nullptr ? 0 : firstChest->inventory.count(thoth::game::ItemId::IronPlate);
    const int poweredOre = poweredChest == nullptr ? 0 : poweredChest->inventory.count(thoth::game::ItemId::IronOre);
    drawPreviewLine(preview, 476, y, "first line iron plates: " + std::to_string(plates), 1, Color{198, 205, 196, 255});
    drawPreviewLine(preview, 476, y, "powered miner iron ore: " + std::to_string(poweredOre), 1, Color{171, 132, 96, 255});
    drawPreviewLine(preview, 476, y, "logistics_1: " +
        std::string(simulation.isTechCompleted("logistics_1") ? "complete" : "incomplete"), 1, Color{118, 210, 255, 255});

    int supply = 0;
    int demand = 0;
    int poweredNetworks = 0;
    for (const auto& network : simulation.powerNetworks()) {
        supply += network.supply;
        demand += network.demand;
        if (network.powered) {
            ++poweredNetworks;
        }
    }
    drawPreviewLine(preview, 476, y, "power: supply " + std::to_string(supply) +
        " demand " + std::to_string(demand) +
        " powered networks " + std::to_string(poweredNetworks), 1, Color{124, 218, 255, 255});
    y += 8;
    drawPreviewLine(preview, 476, y, "Review hooks", 2, Color{232, 238, 232, 255});
    drawPreviewLine(preview, 476, y, "make cpp-validate-assets", 1, Color{206, 220, 214, 255});
    drawPreviewLine(preview, 476, y, "make cpp-validate-replays", 1, Color{206, 220, 214, 255});
    drawPreviewLine(preview, 476, y, "F10 loads this replay, F11 auditions cues", 1, Color{206, 220, 214, 255});

    ImageDrawRectangle(&preview, 22, 462, 900, 54, Color{24, 30, 30, 255});
    drawPreviewRectLines(preview, 22, 462, 900, 54, Color{54, 66, 64, 255});
    drawPreviewSpriteStrip(preview, atlasPixels, 36, 473);

    if (path.has_parent_path()) {
        std::error_code ec;
        std::filesystem::create_directories(path.parent_path(), ec);
        if (ec) {
            UnloadImageColors(atlasPixels);
            UnloadImage(atlas);
            UnloadImage(preview);
            if (error != nullptr) {
                *error = "failed to create preview directory: " + ec.message();
            }
            return false;
        }
    }

    const bool saved = ExportImage(preview, path.string().c_str());
    UnloadImageColors(atlasPixels);
    UnloadImage(atlas);
    UnloadImage(preview);
    if (!saved && error != nullptr) {
        *error = "failed to export media preview";
    }
    return saved;
}

std::string shortItemName(thoth::game::ItemId item)
{
    using thoth::game::ItemId;
    switch (item) {
    case ItemId::None:
        return "-";
    case ItemId::Wood:
        return "wood";
    case ItemId::Stone:
        return "stone";
    case ItemId::Coal:
        return "coal";
    case ItemId::IronOre:
        return "ore";
    case ItemId::IronPlate:
        return "plate";
    case ItemId::CopperOre:
        return "cu ore";
    case ItemId::CopperPlate:
        return "copper";
    case ItemId::Sand:
        return "sand";
    case ItemId::SandGlass:
        return "glass";
    case ItemId::ReedFiber:
        return "reed";
    case ItemId::CactusFiber:
        return "fiber";
    case ItemId::Kelp:
        return "kelp";
    case ItemId::Shell:
        return "shell";
    case ItemId::CoralShard:
        return "coral";
    case ItemId::IceShard:
        return "ice";
    case ItemId::Basalt:
        return "basalt";
    case ItemId::Crystal:
        return "crystal";
    case ItemId::Hide:
        return "hide";
    case ItemId::Bone:
        return "bone";
    case ItemId::Slime:
        return "slime";
    case ItemId::Venom:
        return "venom";
    case ItemId::Belt:
        return "belt";
    case ItemId::Inserter:
        return "ins";
    case ItemId::BurnerMiner:
        return "miner";
    case ItemId::Furnace:
        return "furn";
    case ItemId::Chest:
        return "chest";
    case ItemId::Workbench:
        return "bench";
    case ItemId::SciencePack:
        return "sci";
    case ItemId::AdvancedSciencePack:
        return "adv sci";
    case ItemId::CircuitBoard:
        return "circuit";
    case ItemId::Assembler:
        return "asm";
    case ItemId::Lab:
        return "lab";
    case ItemId::FastBelt:
        return "fast";
    case ItemId::Generator:
        return "gen";
    case ItemId::PowerPole:
        return "pole";
    case ItemId::ElectricMiner:
        return "e-miner";
    case ItemId::CircuitInserter:
        return "c-ins";
    case ItemId::ProviderChest:
        return "prov";
    case ItemId::RequesterChest:
        return "req";
    case ItemId::LogisticPort:
        return "port";
    case ItemId::LogisticDrone:
        return "drone";
    case ItemId::BeaconCore:
        return "core";
    case ItemId::ArchiveTerminal:
        return "archive";
    case ItemId::Splitter:
        return "split";
    case ItemId::TrainStop:
        return "stop";
    case ItemId::WaterBarrel:
        return "water";
    case ItemId::Pipe:
        return "pipe";
    case ItemId::OffshorePump:
        return "pump";
    case ItemId::RiftGate:
        return "rift";
    case ItemId::Wall:
        return "wall";
    case ItemId::PlankWall:
        return "plank";
    case ItemId::Door:
        return "door";
    case ItemId::StairsUp:
        return "up";
    case ItemId::StairsDown:
        return "down";
    case ItemId::Boat:
        return "boat";
    case ItemId::Bed:
        return "bed";
    }
    return "?";
}

std::string machineGlyph(thoth::game::MachineKind kind)
{
    using thoth::game::MachineKind;
    switch (kind) {
    case MachineKind::Belt:
        return "B";
    case MachineKind::FastBelt:
        return "F";
    case MachineKind::Inserter:
        return "I";
    case MachineKind::CircuitInserter:
        return "S";
    case MachineKind::BurnerMiner:
        return "M";
    case MachineKind::Furnace:
        return "U";
    case MachineKind::Chest:
        return "C";
    case MachineKind::ProviderChest:
        return "P";
    case MachineKind::RequesterChest:
        return "R";
    case MachineKind::Workbench:
        return "W";
    case MachineKind::Assembler:
        return "A";
    case MachineKind::Lab:
        return "L";
    case MachineKind::Generator:
        return "G";
    case MachineKind::PowerPole:
        return "P";
    case MachineKind::ElectricMiner:
        return "E";
    case MachineKind::LogisticPort:
        return "O";
    case MachineKind::ArchiveTerminal:
        return "Z";
    case MachineKind::Splitter:
        return "Y";
    case MachineKind::TrainStop:
        return "T";
    case MachineKind::Pipe:
        return "P";
    case MachineKind::OffshorePump:
        return "H";
    case MachineKind::RiftGate:
        return "R";
    }
    return "?";
}

float machineProgressRatio(const thoth::game::Machine& machine)
{
    using thoth::game::MachineKind;
    int denominator = 0;
    switch (machine.kind) {
    case MachineKind::BurnerMiner:
        denominator = 10;
        break;
    case MachineKind::ElectricMiner:
        denominator = 8;
        break;
    case MachineKind::Inserter:
    case MachineKind::CircuitInserter:
        denominator = 15;
        break;
    case MachineKind::Furnace:
        denominator = 30;
        break;
    case MachineKind::Assembler:
        if (const auto* recipe = thoth::game::recipeDef(machine.recipeKey.empty() ? "science_pack" : machine.recipeKey)) {
            denominator = recipe->ticks;
        }
        break;
    case MachineKind::Lab:
        denominator = 30;
        break;
    case MachineKind::ArchiveTerminal:
        denominator = 360;
        break;
    case MachineKind::TrainStop:
        denominator = 90;
        break;
    case MachineKind::Pipe:
        denominator = 3;
        break;
    case MachineKind::OffshorePump:
        denominator = 30;
        break;
    case MachineKind::RiftGate:
        denominator = 180;
        break;
    case MachineKind::Belt:
    case MachineKind::FastBelt:
    case MachineKind::Splitter:
    case MachineKind::Chest:
    case MachineKind::ProviderChest:
    case MachineKind::RequesterChest:
    case MachineKind::Workbench:
    case MachineKind::Generator:
    case MachineKind::PowerPole:
    case MachineKind::LogisticPort:
        break;
    }
    if (denominator <= 0 || machine.progress <= 0) {
        return 0.0f;
    }
    return std::clamp(static_cast<float>(machine.progress) / static_cast<float>(denominator), 0.0f, 1.0f);
}

void drawDirectionArrow(Vector2 center, thoth::game::Direction direction, float length, Color color)
{
    const float dirX = static_cast<float>(thoth::game::dx(direction));
    const float dirY = static_cast<float>(thoth::game::dy(direction));
    const float normX = -dirY;
    const float normY = dirX;
    const Vector2 tail{center.x - dirX * length * 0.45f, center.y - dirY * length * 0.45f};
    const Vector2 tip{center.x + dirX * length * 0.55f, center.y + dirY * length * 0.55f};
    const Vector2 wingA{tip.x - dirX * 5.0f + normX * 3.5f, tip.y - dirY * 5.0f + normY * 3.5f};
    const Vector2 wingB{tip.x - dirX * 5.0f - normX * 3.5f, tip.y - dirY * 5.0f - normY * 3.5f};

    DrawLineEx(tail, tip, 2.0f, color);
    DrawTriangle(tip, wingA, wingB, color);
}

void drawItemIcon(int centerX, int centerY, thoth::game::ItemId item, int radius)
{
    if (item != thoth::game::ItemId::None && drawSpriteCentered(itemSprite(item), centerX, centerY, std::max(8, radius * 2))) {
        DrawRectangleLines(
            centerX - radius,
            centerY - radius,
            radius * 2,
            radius * 2,
            Color{18, 20, 20, 190});
        return;
    }

    const Color fill = itemColor(item);
    DrawCircle(centerX, centerY, static_cast<float>(radius), fill);
    DrawCircleLines(centerX, centerY, static_cast<float>(radius), Color{18, 20, 20, 220});
    if (item != thoth::game::ItemId::None && radius >= 8) {
        const auto label = shortItemName(item).substr(0, 1);
        const int fontSize = radius <= 8 ? 7 : 9;
        DrawText(label.c_str(), centerX - (MeasureText(label.c_str(), fontSize) / 2), centerY - (fontSize / 2), fontSize, BLACK);
    }
}

void drawTileDetail(thoth::game::TileId id, int x, int y)
{
    const int px = x * kTilePixels;
    const int py = y * kTilePixels;
    using thoth::game::TileId;
    switch (id) {
    case TileId::Tree:
        DrawRectangle(px + 10, py + 9, 4, 10, Color{85, 55, 34, 255});
        DrawCircle(px + 12, py + 8, 7.0f, Color{36, 88, 43, 255});
        DrawCircle(px + 7, py + 11, 5.0f, Color{46, 106, 52, 255});
        DrawCircle(px + 17, py + 12, 5.0f, Color{46, 106, 52, 255});
        break;
    case TileId::Stone:
        DrawRectangle(px + 5, py + 7, 14, 11, Color{128, 134, 132, 255});
        DrawRectangle(px + 8, py + 5, 9, 6, Color{146, 150, 147, 255});
        break;
    case TileId::IronOre:
        DrawCircle(px + 8, py + 8, 3.0f, Color{196, 139, 94, 255});
        DrawCircle(px + 15, py + 13, 2.5f, Color{216, 170, 122, 255});
        DrawCircle(px + 10, py + 17, 2.0f, Color{129, 101, 84, 255});
        break;
    case TileId::CopperOre:
        DrawCircle(px + 8, py + 8, 3.0f, Color{210, 119, 70, 255});
        DrawCircle(px + 15, py + 13, 2.5f, Color{232, 150, 88, 255});
        DrawCircle(px + 10, py + 17, 2.0f, Color{130, 76, 55, 255});
        break;
    case TileId::CoalOre:
        DrawCircle(px + 9, py + 9, 3.5f, Color{25, 27, 30, 255});
        DrawCircle(px + 16, py + 14, 3.0f, Color{35, 37, 41, 255});
        DrawCircle(px + 10, py + 17, 2.0f, Color{75, 78, 80, 255});
        break;
    case TileId::Water:
        DrawLine(px + 4, py + 9, px + 10, py + 7, Color{104, 158, 205, 180});
        DrawLine(px + 12, py + 15, px + 20, py + 13, Color{104, 158, 205, 180});
        break;
    case TileId::Floor:
        DrawLine(px + 2, py + 2, px + 21, py + 2, Color{152, 142, 116, 80});
        DrawLine(px + 2, py + 21, px + 21, py + 21, Color{78, 70, 58, 80});
        break;
    case TileId::Grass:
    case TileId::Dirt:
    case TileId::Sand:
    case TileId::Snow:
    case TileId::Mud:
        break;
    }
}

thoth::game::Direction rotateClockwise(thoth::game::Direction direction)
{
    using thoth::game::Direction;
    switch (direction) {
    case Direction::North:
        return Direction::East;
    case Direction::East:
        return Direction::South;
    case Direction::South:
        return Direction::West;
    case Direction::West:
        return Direction::North;
    }
    return Direction::South;
}

std::string stacksText(const thoth::game::Inventory& inventory)
{
    const auto stacks = inventory.stacks();
    if (stacks.empty()) {
        return "-";
    }

    std::string result;
    for (std::size_t i = 0; i < stacks.size(); ++i) {
        if (i > 0) {
            result += ",";
        }
        result += std::string(thoth::game::toString(stacks[i].item));
        result += ":";
        result += std::to_string(stacks[i].count);
    }
    return result;
}

int machineCount(const thoth::game::Simulation& sim, thoth::game::MachineKind kind)
{
    int count = 0;
    for (const auto& machine : sim.machines()) {
        if (machine.kind == kind) {
            ++count;
        }
    }
    return count;
}

const thoth::game::Machine* machineById(const thoth::game::Simulation& sim, std::uint32_t id)
{
    for (const auto& machine : sim.machines()) {
        if (machine.id == id) {
            return &machine;
        }
    }
    return nullptr;
}

const thoth::game::Machine* facedMachine(const thoth::game::Simulation& sim)
{
    const auto& player = sim.player();
    return sim.machineAt(
        player.x + thoth::game::dx(player.facing),
        player.y + thoth::game::dy(player.facing));
}

int beltItemCount(const thoth::game::Simulation& sim)
{
    int count = 0;
    for (const auto& machine : sim.machines()) {
        if ((machine.kind == thoth::game::MachineKind::Belt ||
                machine.kind == thoth::game::MachineKind::FastBelt) &&
            machine.carriedItem != thoth::game::ItemId::None) {
            ++count;
        }
    }
    return count;
}

int blockedMachineCount(const thoth::game::Simulation& sim)
{
    int count = 0;
    for (const auto& machine : sim.machines()) {
        if (machine.status == thoth::game::MachineStatus::OutputBlocked) {
            ++count;
        }
    }
    return count;
}

int machineStatusCount(const thoth::game::Simulation& sim, thoth::game::MachineStatus status)
{
    int count = 0;
    for (const auto& machine : sim.machines()) {
        if (machine.status == status) {
            ++count;
        }
    }
    return count;
}

int itemCountInMachines(const thoth::game::Simulation& sim, thoth::game::MachineKind kind, thoth::game::ItemId item)
{
    int count = 0;
    for (const auto& machine : sim.machines()) {
        if (machine.kind == kind) {
            count += machine.inventory.count(item);
            if (machine.carriedItem == item) {
                ++count;
            }
            if (machine.outputItem == item) {
                ++count;
            }
        }
    }
    return count;
}

int itemCountInFactory(const thoth::game::Simulation& sim, thoth::game::ItemId item)
{
    int count = 0;
    for (const auto& machine : sim.machines()) {
        count += machine.inventory.count(item);
        if (machine.carriedItem == item) {
            ++count;
        }
        if (machine.outputItem == item) {
            ++count;
        }
    }
    return count;
}

void syncProductionCounters(const thoth::game::Simulation& sim, AppState& state)
{
    using thoth::game::ItemId;

    state.lastFactoryIronPlates = itemCountInFactory(sim, ItemId::IronPlate);
    state.lastFactoryCopperPlates = itemCountInFactory(sim, ItemId::CopperPlate);
    state.lastFactorySciencePacks = itemCountInFactory(sim, ItemId::SciencePack);
}

void updateProductionFeedback(const thoth::game::Simulation& sim, AppState& state, const AudioBank& audio)
{
    using thoth::game::ItemId;

    const int ironPlates = itemCountInFactory(sim, ItemId::IronPlate);
    const int copperPlates = itemCountInFactory(sim, ItemId::CopperPlate);
    const int sciencePacks = itemCountInFactory(sim, ItemId::SciencePack);
    if (state.lastFactoryIronPlates < 0 ||
        state.lastFactoryCopperPlates < 0 ||
        state.lastFactorySciencePacks < 0) {
        syncProductionCounters(sim, state);
        return;
    }

    if (state.productionCueCooldown <= 0) {
        if (sciencePacks > state.lastFactorySciencePacks) {
            setFeedback(state, "factory output: science pack", Color{118, 210, 255, 220});
            playCue(audio, audio.produce);
            state.productionCueCooldown = 30;
        } else if (copperPlates > state.lastFactoryCopperPlates) {
            setFeedback(state, "factory output: copper plate", Color{218, 135, 76, 220});
            playCue(audio, audio.produce);
            state.productionCueCooldown = 30;
        } else if (ironPlates > state.lastFactoryIronPlates) {
            setFeedback(state, "factory output: iron plate", Color{198, 205, 196, 220});
            playCue(audio, audio.produce);
            state.productionCueCooldown = 30;
        }
    }

    state.lastFactoryIronPlates = ironPlates;
    state.lastFactoryCopperPlates = copperPlates;
    state.lastFactorySciencePacks = sciencePacks;
}

std::string checklistMark(bool complete)
{
    return complete ? "[x] " : "[ ] ";
}

bool hasPlacedFirstLine(const thoth::game::Simulation& sim)
{
    using thoth::game::MachineKind;
    return machineCount(sim, MachineKind::BurnerMiner) > 0 &&
        (machineCount(sim, MachineKind::Belt) + machineCount(sim, MachineKind::FastBelt)) > 0 &&
        machineCount(sim, MachineKind::Inserter) > 0 &&
        machineCount(sim, MachineKind::Furnace) > 0 &&
        machineCount(sim, MachineKind::Chest) > 0;
}

bool hasFirstLineParts(const thoth::game::Simulation& sim)
{
    using thoth::game::ItemId;
    using thoth::game::MachineKind;
    return (sim.itemCount(ItemId::BurnerMiner) + machineCount(sim, MachineKind::BurnerMiner)) > 0 &&
        (sim.itemCount(ItemId::Belt) + sim.itemCount(ItemId::FastBelt) +
            machineCount(sim, MachineKind::Belt) + machineCount(sim, MachineKind::FastBelt)) > 0 &&
        (sim.itemCount(ItemId::Inserter) + machineCount(sim, MachineKind::Inserter)) > 0 &&
        (sim.itemCount(ItemId::Furnace) + machineCount(sim, MachineKind::Furnace)) > 0 &&
        (sim.itemCount(ItemId::Chest) + machineCount(sim, MachineKind::Chest)) > 0;
}

std::vector<std::string> firstLineChecklist(const thoth::game::Simulation& sim)
{
    using thoth::game::ItemId;
    using thoth::game::MachineKind;
    const bool placedLine = hasPlacedFirstLine(sim);
    const bool craftedParts = placedLine || hasFirstLineParts(sim);
    const bool gatheredStarter =
        craftedParts ||
        ((sim.itemCount(ItemId::Wood) > 0 || machineCount(sim, MachineKind::Chest) > 0) &&
            sim.itemCount(ItemId::Stone) > 0 &&
            (sim.itemCount(ItemId::Coal) > 0 || machineCount(sim, MachineKind::BurnerMiner) > 0));
    const bool storedPlate = itemCountInMachines(sim, MachineKind::Chest, ItemId::IronPlate) > 0;

    return {
        checklistMark(gatheredStarter) + "gather wood, stone, coal",
        checklistMark(sim.itemCount(ItemId::Workbench) > 0 || machineCount(sim, MachineKind::Workbench) > 0) + "craft/place a workbench",
        checklistMark(craftedParts) + "use workbench to craft miner, belt, inserter, furnace, chest",
        checklistMark(placedLine) + "place miner -> belt -> inserter -> furnace -> chest",
        checklistMark(storedPlate) + "fuel line and store first iron plate",
    };
}

bool hasItemOrMachine(const thoth::game::Simulation& sim, thoth::game::ItemId item, thoth::game::MachineKind machine)
{
    return sim.itemCount(item) > 0 || machineCount(sim, machine) > 0;
}

bool shouldShowScienceChecklist(const thoth::game::Simulation& sim)
{
    using thoth::game::ItemId;
    using thoth::game::MachineKind;
    return itemCountInMachines(sim, MachineKind::Chest, ItemId::IronPlate) > 0 ||
        itemCountInMachines(sim, MachineKind::Chest, ItemId::CopperPlate) > 0 ||
        machineCount(sim, MachineKind::Assembler) > 0 ||
        machineCount(sim, MachineKind::Lab) > 0 ||
        itemCountInFactory(sim, ItemId::SciencePack) > 0 ||
        sim.itemCount(ItemId::SciencePack) > 0 ||
        sim.researchProgress() > 0 ||
        sim.isRecipeUnlocked("fast_belt");
}

std::vector<std::string> scienceChecklist(const thoth::game::Simulation& sim)
{
    using thoth::game::ItemId;
    using thoth::game::MachineKind;
    if (!shouldShowScienceChecklist(sim)) {
        return {};
    }

    const bool hasIronPlate = itemCountInMachines(sim, MachineKind::Chest, ItemId::IronPlate) > 0;
    const bool hasCopperPlate = itemCountInMachines(sim, MachineKind::Chest, ItemId::CopperPlate) > 0;
    const bool hasAssembler = hasItemOrMachine(sim, ItemId::Assembler, MachineKind::Assembler);
    const bool hasLab = hasItemOrMachine(sim, ItemId::Lab, MachineKind::Lab);
    const bool hasScience = itemCountInFactory(sim, ItemId::SciencePack) > 0 ||
        sim.itemCount(ItemId::SciencePack) > 0 ||
        sim.researchProgress() > 0 ||
        sim.isRecipeUnlocked("fast_belt");
    const bool labFed = itemCountInMachines(sim, MachineKind::Lab, ItemId::SciencePack) > 0 ||
        sim.researchProgress() > 0 ||
        sim.isRecipeUnlocked("fast_belt");

    return {
        checklistMark(hasIronPlate && hasCopperPlate) + "store iron and copper plates",
        checklistMark(hasAssembler && hasLab) + "craft/place assembler and lab",
        checklistMark(hasScience) + "make science packs from iron+copper",
        checklistMark(labFed) + "load science packs into lab",
        checklistMark(sim.isRecipeUnlocked("fast_belt")) + "finish Logistics 1 research",
    };
}

bool hasPoweredConsumerNetwork(const thoth::game::Simulation& sim)
{
    for (const auto& network : sim.powerNetworks()) {
        if (network.powered && !network.consumerIds.empty()) {
            return true;
        }
    }
    return false;
}

bool hasGeneratorFuel(const thoth::game::Simulation& sim)
{
    using thoth::game::ItemId;
    using thoth::game::MachineKind;
    for (const auto& machine : sim.machines()) {
        if (machine.kind == MachineKind::Generator &&
            (machine.fuelTicks > 0 || machine.inventory.count(ItemId::Coal) > 0)) {
            return true;
        }
    }
    return false;
}

bool shouldShowPowerChecklist(const thoth::game::Simulation& sim)
{
    using thoth::game::ItemId;
    using thoth::game::MachineKind;
    return sim.isRecipeUnlocked("fast_belt") ||
        hasItemOrMachine(sim, ItemId::Generator, MachineKind::Generator) ||
        hasItemOrMachine(sim, ItemId::PowerPole, MachineKind::PowerPole) ||
        hasItemOrMachine(sim, ItemId::ElectricMiner, MachineKind::ElectricMiner) ||
        hasItemOrMachine(sim, ItemId::FastBelt, MachineKind::FastBelt);
}

std::vector<std::string> powerChecklist(const thoth::game::Simulation& sim)
{
    using thoth::game::ItemId;
    using thoth::game::MachineKind;
    if (!shouldShowPowerChecklist(sim)) {
        return {};
    }

    const bool hasPowerParts =
        hasItemOrMachine(sim, ItemId::Generator, MachineKind::Generator) &&
        hasItemOrMachine(sim, ItemId::PowerPole, MachineKind::PowerPole) &&
        hasItemOrMachine(sim, ItemId::ElectricMiner, MachineKind::ElectricMiner);
    const bool placedPower =
        machineCount(sim, MachineKind::Generator) > 0 &&
        machineCount(sim, MachineKind::PowerPole) > 0 &&
        machineCount(sim, MachineKind::ElectricMiner) > 0;
    const bool fueledGenerator = hasGeneratorFuel(sim);
    const bool poweredNetwork = hasPoweredConsumerNetwork(sim);
    const bool hasFastBelt = hasItemOrMachine(sim, ItemId::FastBelt, MachineKind::FastBelt);

    return {
        checklistMark(hasPowerParts) + "craft generator, poles, electric miner",
        checklistMark(placedPower) + "place generator + poles + electric miner",
        checklistMark(fueledGenerator) + "fuel generator with coal",
        checklistMark(poweredNetwork) + "connect powered mining network",
        checklistMark(hasFastBelt) + "craft/place fast belts for throughput",
    };
}

std::string statusStatsText(const thoth::game::Simulation& sim)
{
    using thoth::game::MachineStatus;
    return "status: work=" + std::to_string(machineStatusCount(sim, MachineStatus::Working)) +
        " input=" + std::to_string(machineStatusCount(sim, MachineStatus::MissingInput)) +
        " fuel=" + std::to_string(machineStatusCount(sim, MachineStatus::MissingFuel)) +
        " power=" + std::to_string(machineStatusCount(sim, MachineStatus::MissingPower)) +
        " blocked=" + std::to_string(machineStatusCount(sim, MachineStatus::OutputBlocked));
}

void syncMachineIssueCounters(const thoth::game::Simulation& sim, AppState& state)
{
    using thoth::game::MachineStatus;
    state.lastFuelIssues = machineStatusCount(sim, MachineStatus::MissingFuel);
    state.lastPowerIssues = machineStatusCount(sim, MachineStatus::MissingPower);
    state.lastBlockedIssues = machineStatusCount(sim, MachineStatus::OutputBlocked);
}

void updateMachineIssueFeedback(const thoth::game::Simulation& sim, AppState& state, const AudioBank& audio)
{
    using thoth::game::MachineStatus;

    const int fuelIssues = machineStatusCount(sim, MachineStatus::MissingFuel);
    const int powerIssues = machineStatusCount(sim, MachineStatus::MissingPower);
    const int blockedIssues = machineStatusCount(sim, MachineStatus::OutputBlocked);

    if (state.lastFuelIssues < 0 || state.lastPowerIssues < 0 || state.lastBlockedIssues < 0) {
        syncMachineIssueCounters(sim, state);
        return;
    }

    if (state.machineIssueCueCooldown <= 0) {
        if (blockedIssues > state.lastBlockedIssues) {
            setFeedback(state, "factory issue: output blocked", Color{236, 84, 84, 220});
            playCue(audio, audio.invalid);
            state.machineIssueCueCooldown = 45;
        } else if (fuelIssues > state.lastFuelIssues) {
            setFeedback(state, "factory issue: needs fuel", Color{238, 180, 74, 220});
            playCue(audio, audio.invalid);
            state.machineIssueCueCooldown = 45;
        } else if (powerIssues > state.lastPowerIssues) {
            setFeedback(state, "factory issue: no power", Color{122, 184, 244, 220});
            playCue(audio, audio.invalid);
            state.machineIssueCueCooldown = 45;
        }
    }

    state.lastFuelIssues = fuelIssues;
    state.lastPowerIssues = powerIssues;
    state.lastBlockedIssues = blockedIssues;
}

bool isMachineIssue(thoth::game::MachineStatus status)
{
    using thoth::game::MachineStatus;
    return status == MachineStatus::MissingInput ||
        status == MachineStatus::MissingFuel ||
        status == MachineStatus::MissingPower ||
        status == MachineStatus::OutputBlocked;
}

std::string machineIssueBadgeText(thoth::game::MachineStatus status)
{
    using thoth::game::MachineStatus;
    switch (status) {
    case MachineStatus::MissingInput:
        return "input";
    case MachineStatus::MissingFuel:
        return "fuel";
    case MachineStatus::MissingPower:
        return "power";
    case MachineStatus::OutputBlocked:
        return "blocked";
    case MachineStatus::Idle:
    case MachineStatus::Working:
        break;
    }
    return "";
}

std::string machineIssueSummaryText(const thoth::game::Simulation& sim)
{
    std::string text = "issues:";
    int shown = 0;
    int total = 0;
    for (const auto& machine : sim.machines()) {
        if (!isMachineIssue(machine.status)) {
            continue;
        }
        ++total;
        if (shown >= 4) {
            continue;
        }
        text += shown == 0 ? " " : "; ";
        text += std::string(thoth::game::toString(machine.kind));
        text += "@";
        text += std::to_string(machine.x);
        text += ",";
        text += std::to_string(machine.y);
        text += " ";
        text += std::string(thoth::game::toString(machine.status));
        ++shown;
    }

    if (total == 0) {
        return "issues: none";
    }
    if (total > shown) {
        text += "; +";
        text += std::to_string(total - shown);
        text += " more";
    }
    return text;
}

const std::vector<CraftMenuEntry>& craftMenuEntries()
{
    static const std::vector<CraftMenuEntry> entries = {
        {"workbench", "K"},
        {"chest", "C"},
        {"furnace", "F"},
        {"belt", "B"},
        {"inserter", "I"},
        {"burner_miner", "M"},
        {"assembler", "X"},
        {"lab", "L"},
        {"fast_belt", "T"},
        {"generator", "G"},
        {"power_pole", "O"},
        {"electric_miner", "N"},
        {"circuit_inserter", ""},
        {"provider_chest", ""},
        {"requester_chest", ""},
        {"logistic_port", ""},
        {"logistic_drone", ""},
        {"splitter", ""},
        {"pipe", ""},
        {"offshore_pump", ""},
        {"beacon_core", ""},
        {"archive_terminal", ""},
        {"train_stop", ""},
        {"rift_gate", ""},
    };
    return entries;
}

bool machineCanAcceptForPanel(const thoth::game::Machine& machine, thoth::game::ItemId item)
{
    if (item == thoth::game::ItemId::None) {
        return false;
    }

    using thoth::game::ItemId;
    using thoth::game::MachineKind;
    switch (machine.kind) {
    case MachineKind::Belt:
    case MachineKind::FastBelt:
    case MachineKind::Splitter:
        return machine.carriedItem == ItemId::None;
    case MachineKind::Pipe:
        return item == ItemId::WaterBarrel && machine.carriedItem == ItemId::None;
    case MachineKind::Chest:
    case MachineKind::ProviderChest:
    case MachineKind::RequesterChest:
    case MachineKind::TrainStop:
        return true;
    case MachineKind::BurnerMiner:
    case MachineKind::Generator:
        return item == ItemId::Coal;
    case MachineKind::Furnace:
        if (item == ItemId::Coal) {
            return true;
        }
        if (machine.recipeLocked && !machine.recipeKey.empty()) {
            const auto* recipe = thoth::game::recipeDef(machine.recipeKey);
            return recipe != nullptr &&
                recipe->station == "furnace" &&
                furnaceOreInput(*recipe) == item;
        }
        return item == ItemId::Coal || item == ItemId::IronOre || item == ItemId::CopperOre;
    case MachineKind::Assembler: {
        const auto* recipe = thoth::game::recipeDef(machine.recipeKey.empty() ? "science_pack" : machine.recipeKey);
        if (recipe == nullptr) {
            return false;
        }
        return std::any_of(recipe->inputs.begin(), recipe->inputs.end(), [item](const thoth::game::ItemStack& input) {
            return input.item == item;
        });
    }
    case MachineKind::Lab:
        return item == ItemId::SciencePack || item == ItemId::AdvancedSciencePack;
    case MachineKind::LogisticPort:
        return item == ItemId::LogisticDrone;
    case MachineKind::ArchiveTerminal:
    case MachineKind::RiftGate:
        return item == ItemId::BeaconCore;
    case MachineKind::Inserter:
    case MachineKind::CircuitInserter:
    case MachineKind::Workbench:
    case MachineKind::PowerPole:
    case MachineKind::ElectricMiner:
    case MachineKind::OffshorePump:
        return false;
    }
    return false;
}

std::vector<thoth::game::ItemId> withdrawableItemsForPanel(const thoth::game::Machine& machine)
{
    std::vector<thoth::game::ItemId> items;
    const auto addUnique = [&items](thoth::game::ItemId item) {
        if (item == thoth::game::ItemId::None ||
            std::find(items.begin(), items.end(), item) != items.end()) {
            return;
        }
        items.push_back(item);
    };

    addUnique(machine.carriedItem);
    addUnique(machine.outputItem);
    for (const auto& stack : machine.inventory.stacks()) {
        addUnique(stack.item);
    }
    return items;
}

std::vector<MachinePanelButton> machinePanelButtons(const thoth::game::Simulation& sim)
{
    std::vector<MachinePanelButton> buttons;
    const auto* machine = facedMachine(sim);
    if (machine == nullptr) {
        return buttons;
    }

    constexpr int buttonWidth = 62;
    constexpr int buttonHeight = 30;
    constexpr int gap = 6;
    const int startX = kMachinePanelX + 10;

    int depositIndex = 0;
    for (const auto& stack : sim.player().inventory.stacks()) {
        if (!machineCanAcceptForPanel(*machine, stack.item)) {
            continue;
        }
        const int x = startX + depositIndex * (buttonWidth + gap);
        buttons.push_back(MachinePanelButton{
            Rectangle{static_cast<float>(x), static_cast<float>(kMachinePanelY + 148), static_cast<float>(buttonWidth), static_cast<float>(buttonHeight)},
            stack.item,
            true});
        ++depositIndex;
        if (depositIndex >= 5) {
            break;
        }
    }

    int withdrawIndex = 0;
    for (const auto item : withdrawableItemsForPanel(*machine)) {
        const int x = startX + withdrawIndex * (buttonWidth + gap);
        buttons.push_back(MachinePanelButton{
            Rectangle{static_cast<float>(x), static_cast<float>(kMachinePanelY + 196), static_cast<float>(buttonWidth), static_cast<float>(buttonHeight)},
            item,
            false});
        ++withdrawIndex;
        if (withdrawIndex >= 5) {
            break;
        }
    }

    return buttons;
}

std::vector<TransferAmountButton> transferAmountButtons()
{
    std::vector<TransferAmountButton> buttons;
    constexpr int buttonWidth = 36;
    constexpr int buttonHeight = 18;
    constexpr int gap = 5;
    constexpr std::array<int, 3> amounts = {1, 5, 0};
    const int startX = kMachinePanelX + kMachinePanelWidth - 10 - (buttonWidth * 3 + gap * 2);
    for (int i = 0; i < static_cast<int>(amounts.size()); ++i) {
        buttons.push_back(TransferAmountButton{
            Rectangle{
                static_cast<float>(startX + i * (buttonWidth + gap)),
                static_cast<float>(kMachinePanelY + 130),
                static_cast<float>(buttonWidth),
                static_cast<float>(buttonHeight)},
            amounts[static_cast<std::size_t>(i)]});
    }
    return buttons;
}

std::vector<RecipePanelButton> machineRecipeButtons(const thoth::game::Simulation& sim)
{
    std::vector<RecipePanelButton> buttons;
    const auto* machine = facedMachine(sim);
    if (machine == nullptr ||
        (machine->kind != thoth::game::MachineKind::Assembler &&
            machine->kind != thoth::game::MachineKind::Furnace)) {
        return buttons;
    }

    const std::string_view station =
        machine->kind == thoth::game::MachineKind::Assembler ? "assembler" : "furnace";

    constexpr int buttonWidth = 112;
    constexpr int buttonHeight = 36;
    constexpr int gap = 6;
    int index = 0;
    for (const auto& recipe : thoth::game::recipeDefs()) {
        if (recipe.station != station || !sim.isRecipeUnlocked(recipe.key)) {
            continue;
        }
        const int x = kMachinePanelX + 10 + index * (buttonWidth + gap);
        buttons.push_back(RecipePanelButton{
            Rectangle{
                static_cast<float>(x),
                static_cast<float>(kMachinePanelY + 244),
                static_cast<float>(buttonWidth),
                static_cast<float>(buttonHeight)},
            recipe.key});
        ++index;
        if (index >= 3) {
            break;
        }
    }
    return buttons;
}

std::vector<MachineConfigButton> machineConfigButtons(const thoth::game::Simulation& sim)
{
    using thoth::game::CircuitComparator;
    using thoth::game::ItemId;
    using thoth::game::MachineKind;

    std::vector<MachineConfigButton> buttons;
    const auto* machine = facedMachine(sim);
    if (machine == nullptr) {
        return buttons;
    }

    constexpr int buttonWidth = 82;
    constexpr int buttonHeight = 36;
    constexpr int gap = 5;
    const int startX = kMachinePanelX + 10;
    const int y = kMachinePanelY + 244;

    if (machine->kind == MachineKind::CircuitInserter) {
        const std::array<MachineConfigButton, 4> configs = {
            MachineConfigButton{{}, MachineConfigAction::Circuit, ItemId::IronOre, CircuitComparator::LessThan, 1, "iron ore <1"},
            MachineConfigButton{{}, MachineConfigAction::Circuit, ItemId::CopperOre, CircuitComparator::LessThan, 1, "copper <1"},
            MachineConfigButton{{}, MachineConfigAction::Circuit, ItemId::IronPlate, CircuitComparator::LessThan, 5, "iron <5"},
            MachineConfigButton{{}, MachineConfigAction::Circuit, ItemId::Coal, CircuitComparator::LessThan, 1, "coal <1"},
        };
        for (int i = 0; i < static_cast<int>(configs.size()); ++i) {
            auto config = configs[static_cast<std::size_t>(i)];
            config.rect = Rectangle{
                static_cast<float>(startX + i * (buttonWidth + gap)),
                static_cast<float>(y),
                static_cast<float>(buttonWidth),
                static_cast<float>(buttonHeight)};
            buttons.push_back(config);
        }
    }

    if (machine->kind == MachineKind::RequesterChest) {
        const std::array<MachineConfigButton, 4> configs = {
            MachineConfigButton{{}, MachineConfigAction::Request, ItemId::IronPlate, CircuitComparator::Always, 10, "iron x10"},
            MachineConfigButton{{}, MachineConfigAction::Request, ItemId::CopperPlate, CircuitComparator::Always, 10, "copper x10"},
            MachineConfigButton{{}, MachineConfigAction::Request, ItemId::Coal, CircuitComparator::Always, 10, "coal x10"},
            MachineConfigButton{{}, MachineConfigAction::Request, ItemId::None, CircuitComparator::Always, 0, "clear"},
        };
        for (int i = 0; i < static_cast<int>(configs.size()); ++i) {
            auto config = configs[static_cast<std::size_t>(i)];
            config.rect = Rectangle{
                static_cast<float>(startX + i * (buttonWidth + gap)),
                static_cast<float>(y),
                static_cast<float>(buttonWidth),
                static_cast<float>(buttonHeight)};
            buttons.push_back(config);
        }
    }

    return buttons;
}

std::vector<InventoryButton> inventoryButtons(const thoth::game::Simulation& sim)
{
    std::vector<InventoryButton> buttons;
    if (sim.player().inventory.stacks().empty()) {
        return buttons;
    }

    constexpr int columns = 6;
    const int startX = kInventoryPanelX + 12;
    const int startY = kInventoryPanelY + 92;
    int index = 0;
    for (const auto& stack : sim.player().inventory.stacks()) {
        const int col = index % columns;
        const int row = index / columns;
        buttons.push_back(InventoryButton{
            Rectangle{
                static_cast<float>(startX + col * (kInventorySlotSize + kInventorySlotGap)),
                static_cast<float>(startY + row * (kInventorySlotSize + kInventorySlotGap)),
                static_cast<float>(kInventorySlotSize),
                static_cast<float>(kInventorySlotSize)},
            stack.item,
            -1,
            false});
        ++index;
    }
    return buttons;
}

std::vector<InventoryButton> inventoryHotbarButtons()
{
    std::vector<InventoryButton> buttons;
    constexpr int columns = 5;
    const int startX = kInventoryPanelX + 12;
    const int startY = kInventoryPanelY + 36;
    for (int i = 0; i < thoth::game::kHotbarSlots; ++i) {
        const int col = i % columns;
        const int row = i / columns;
        buttons.push_back(InventoryButton{
            Rectangle{
                static_cast<float>(startX + col * 80),
                static_cast<float>(startY + row * 25),
                72.0f,
                20.0f},
            thoth::game::ItemId::None,
            i,
            true});
    }
    return buttons;
}

int craftMenuRowCount()
{
    const auto count = static_cast<int>(craftMenuEntries().size());
    return (count + kCraftMenuColumns - 1) / kCraftMenuColumns;
}

int craftCardWidth()
{
    const int contentWidth = kCraftMenuWidth - 20;
    return (contentWidth - (kCraftMenuColumns - 1) * kCraftCardGap) / kCraftMenuColumns;
}

Rectangle craftCardRect(int index)
{
    const int cardWidth = craftCardWidth();
    const int col = index % kCraftMenuColumns;
    const int row = index / kCraftMenuColumns;
    return Rectangle{
        static_cast<float>(kCraftMenuX + 10 + col * (cardWidth + kCraftCardGap)),
        static_cast<float>(kCraftMenuY + 34 + row * (kCraftCardHeight + kCraftCardGap)),
        static_cast<float>(cardWidth),
        static_cast<float>(kCraftCardHeight)};
}

void clampCraftSelection(AppState& state)
{
    const int last = static_cast<int>(craftMenuEntries().size()) - 1;
    state.craftSelection = std::clamp(state.craftSelection, 0, std::max(0, last));
}

bool canCraftRecipe(const thoth::game::Simulation& sim, std::string_view recipeKey)
{
    return sim.canCraft(recipeKey);
}

void queueCraft(
    thoth::game::Simulation& sim,
    AppState& state,
    const AudioBank& audio,
    std::string recipeKey)
{
    if (!canCraftRecipe(sim, recipeKey)) {
        setFeedback(state, "craft blocked: " + recipeKey, Color{236, 84, 84, 220});
        playCue(audio, audio.invalid);
        return;
    }

    sim.queue(thoth::game::Command::craft(recipeKey));
    setFeedback(state, "crafted: " + recipeKey, Color{103, 214, 132, 220});
    playCue(audio, audio.craft);
}

void queueSelectedCraft(thoth::game::Simulation& sim, AppState& state, const AudioBank& audio)
{
    clampCraftSelection(state);
    const auto& entries = craftMenuEntries();
    if (entries.empty()) {
        return;
    }
    queueCraft(sim, state, audio, std::string(entries[static_cast<std::size_t>(state.craftSelection)].recipeKey));
}

std::string recipeCostText(const thoth::game::Simulation& sim, const thoth::game::RecipeDef& recipe)
{
    std::string text;
    for (std::size_t i = 0; i < recipe.inputs.size(); ++i) {
        const auto& input = recipe.inputs[i];
        if (i > 0) {
            text += " ";
        }
        text += shortItemName(input.item);
        text += " ";
        text += std::to_string(sim.itemCount(input.item));
        text += "/";
        text += std::to_string(input.count);
    }
    return text;
}

std::string recipeMachineCostText(const thoth::game::Inventory& inventory, const thoth::game::RecipeDef& recipe)
{
    bool ready = true;
    std::string text;
    for (std::size_t i = 0; i < recipe.inputs.size(); ++i) {
        const auto& input = recipe.inputs[i];
        const int available = inventory.count(input.item);
        ready = ready && available >= input.count;
        if (i > 0) {
            text += " ";
        }
        text += shortItemName(input.item);
        text += " ";
        text += std::to_string(available);
        text += "/";
        text += std::to_string(input.count);
    }
    return std::string(ready ? "input " : "need ") + text;
}

bool containsMachineId(const std::vector<std::uint32_t>& ids, std::uint32_t id)
{
    return std::find(ids.begin(), ids.end(), id) != ids.end();
}

std::string powerNetworkDetail(const thoth::game::Simulation& sim, const thoth::game::Machine& machine)
{
    for (const auto& network : sim.powerNetworks()) {
        if (!containsMachineId(network.poleIds, machine.id) &&
            !containsMachineId(network.generatorIds, machine.id) &&
            !containsMachineId(network.consumerIds, machine.id)) {
            continue;
        }

        return "power " + std::to_string(network.supply) + "/" +
            std::to_string(network.demand) + (network.powered ? " ok" : " low");
    }
    return "power unlinked";
}

std::string targetNameAt(const thoth::game::Simulation& sim, int x, int y)
{
    if (const auto* target = sim.machineAt(x, y)) {
        return std::string(thoth::game::toString(target->kind));
    }
    return std::string(thoth::game::toString(sim.world().getTile(x, y).id));
}

std::string outputTargetText(const thoth::game::Simulation& sim, const thoth::game::Machine& machine)
{
    return "-> " + targetNameAt(
        sim,
        machine.x + thoth::game::dx(machine.direction),
        machine.y + thoth::game::dy(machine.direction));
}

const thoth::game::RecipeDef* panelFurnaceRecipe(const thoth::game::Machine& machine)
{
    if (!machine.recipeKey.empty()) {
        if (const auto* recipe = thoth::game::recipeDef(machine.recipeKey)) {
            if (recipe->station == "furnace") {
                return recipe;
            }
        }
    }
    if (machine.inventory.count(thoth::game::ItemId::CopperOre) > 0) {
        return thoth::game::recipeDef("copper_plate");
    }
    if (machine.inventory.count(thoth::game::ItemId::IronOre) > 0) {
        return thoth::game::recipeDef("iron_plate");
    }
    return nullptr;
}

thoth::game::ItemId furnaceOreInput(const thoth::game::RecipeDef& recipe)
{
    for (const auto& input : recipe.inputs) {
        if (input.item != thoth::game::ItemId::Coal) {
            return input.item;
        }
    }
    return thoth::game::ItemId::None;
}

std::string depositActionText(const thoth::game::Simulation& sim, thoth::game::ItemId item)
{
    if (item == thoth::game::ItemId::None) {
        return "action: inspect the flow strip for the missing item";
    }
    if (sim.itemCount(item) > 0) {
        return "action: click +" + shortItemName(item) + ", or select " + shortItemName(item) + " and press E";
    }
    return "action: gather " + shortItemName(item) + " before loading this machine";
}

std::string missingRecipeInputAction(
    const thoth::game::Simulation& sim,
    const thoth::game::Machine& machine,
    const thoth::game::RecipeDef& recipe)
{
    for (const auto& input : recipe.inputs) {
        if (machine.inventory.count(input.item) < input.count) {
            return depositActionText(sim, input.item);
        }
    }
    return "action: inputs are loaded; wait for the machine tick";
}

std::string machineHintText(const thoth::game::Simulation& sim, const thoth::game::Machine& machine)
{
    using thoth::game::ItemId;
    using thoth::game::MachineKind;
    using thoth::game::MachineStatus;

    if (machine.status == MachineStatus::OutputBlocked) {
        const int targetX = machine.x + thoth::game::dx(machine.direction);
        const int targetY = machine.y + thoth::game::dy(machine.direction);
        return "action: output blocked " + outputTargetText(sim, machine) +
            " at " + std::to_string(targetX) + "," + std::to_string(targetY) +
            "; take items or extend the line";
    }
    if (machine.status == MachineStatus::MissingFuel) {
        return "needs coal fuel; " + depositActionText(sim, ItemId::Coal);
    }
    if (machine.status == MachineStatus::MissingPower) {
        return "action: " + powerNetworkDetail(sim, machine) +
            "; place/fuel a generator and connect power poles within reach";
    }

    switch (machine.kind) {
    case MachineKind::Belt:
    case MachineKind::FastBelt:
    case MachineKind::Splitter:
    case MachineKind::Pipe:
        if (machine.carriedItem == ItemId::None) {
            return "transport empty; action: feed an upstream miner, inserter, or belt";
        }
        return "carrying " + shortItemName(machine.carriedItem) + " " + outputTargetText(sim, machine);
    case MachineKind::Inserter:
        if (machine.status == MachineStatus::MissingInput) {
            return "action: no source item behind inserter; check " +
                targetNameAt(
                    sim,
                    machine.x - thoth::game::dx(machine.direction),
                    machine.y - thoth::game::dy(machine.direction));
        }
        return "moves " +
            targetNameAt(
                sim,
                machine.x - thoth::game::dx(machine.direction),
                machine.y - thoth::game::dy(machine.direction)) +
            " -> " +
            targetNameAt(
                sim,
                machine.x + thoth::game::dx(machine.direction),
                machine.y + thoth::game::dy(machine.direction));
    case MachineKind::CircuitInserter:
        if (machine.filterItem == ItemId::None || machine.circuitComparator == thoth::game::CircuitComparator::Always) {
            return "unfiltered circuit inserter; choose a filter/threshold in this panel";
        }
        if (machine.status == MachineStatus::MissingInput) {
            return "action: no matching source item behind circuit inserter; config filter in this panel";
        }
        return "filter " + shortItemName(machine.filterItem) + " " +
            std::string(thoth::game::toString(machine.circuitComparator)) + " " +
            std::to_string(machine.circuitThreshold) + " " +
            targetNameAt(
                sim,
                machine.x - thoth::game::dx(machine.direction),
                machine.y - thoth::game::dy(machine.direction)) +
            " -> " +
            targetNameAt(
                sim,
                machine.x + thoth::game::dx(machine.direction),
                machine.y + thoth::game::dy(machine.direction));
    case MachineKind::BurnerMiner:
    case MachineKind::ElectricMiner: {
        const auto tile = sim.world().getTile(machine.x, machine.y);
        if (machine.status == MachineStatus::MissingInput) {
            return "action: miner needs ore/coal under it; current tile is " +
                std::string(thoth::game::toString(tile.id));
        }
        std::string text = "resource " + std::string(thoth::game::toString(tile.id)) +
            " " + std::to_string(tile.data) + " " + outputTargetText(sim, machine);
        if (machine.kind == MachineKind::ElectricMiner) {
            text += " " + powerNetworkDetail(sim, machine);
        }
        return text;
    }
    case MachineKind::Furnace: {
        const auto* recipe = panelFurnaceRecipe(machine);
        if (recipe == nullptr) {
            if (machine.inventory.count(ItemId::Coal) <= 0) {
                return depositActionText(sim, ItemId::Coal);
            }
            return "action: load iron_ore or copper_ore with the deposit buttons";
        }
        const auto ore = furnaceOreInput(*recipe);
        if (machine.status == MachineStatus::MissingInput && machine.inventory.count(ore) <= 0) {
            return depositActionText(sim, ore);
        }
        return std::string(recipe->key) + " " + shortItemName(ore) + " " +
            std::to_string(machine.inventory.count(ore)) + "/1 coal " +
            std::to_string(machine.inventory.count(ItemId::Coal)) + " " +
            outputTargetText(sim, machine);
    }
    case MachineKind::Assembler: {
        const auto key = machine.recipeKey.empty() ? "science_pack" : machine.recipeKey;
        const auto* recipe = thoth::game::recipeDef(key);
        if (recipe == nullptr) {
            return "recipe missing";
        }
        if (machine.status == MachineStatus::MissingInput) {
            return missingRecipeInputAction(sim, machine, *recipe);
        }
        return std::string(key) + " " + recipeMachineCostText(machine.inventory, *recipe) + " " +
            outputTargetText(sim, machine);
    }
    case MachineKind::Lab:
        if (machine.status == MachineStatus::MissingInput) {
            return depositActionText(sim, ItemId::SciencePack);
        }
        if (sim.isTechCompleted(sim.activeTech())) {
            return "research complete pack " + std::to_string(machine.inventory.count(ItemId::SciencePack));
        }
        return "research " + std::string(sim.activeTech()) + " " +
            std::to_string(sim.researchProgress()) + "/" + std::to_string(sim.researchGoal()) +
            " pack " + std::to_string(machine.inventory.count(ItemId::SciencePack));
    case MachineKind::Generator:
        return "fuel " + std::to_string(machine.fuelTicks) + " coal " +
            std::to_string(machine.inventory.count(ItemId::Coal)) + " " + powerNetworkDetail(sim, machine);
    case MachineKind::PowerPole:
        return powerNetworkDetail(sim, machine);
    case MachineKind::Chest:
        return "storage " + stacksText(machine.inventory);
    case MachineKind::ProviderChest:
        return "provider storage " + stacksText(machine.inventory);
    case MachineKind::RequesterChest:
        if (machine.requestItem == ItemId::None || machine.requestThreshold <= 0) {
            return "request unset; choose a request in this panel";
        }
        return "request " + shortItemName(machine.requestItem) + " x" +
            std::to_string(machine.requestThreshold) + " stored " +
            std::to_string(machine.inventory.count(machine.requestItem));
    case MachineKind::LogisticPort:
        return "drones " + std::to_string(machine.inventory.count(ItemId::LogisticDrone)) +
            " jobs " + std::to_string(static_cast<int>(sim.logisticJobs().size())) + " " +
            powerNetworkDetail(sim, machine);
    case MachineKind::ArchiveTerminal:
        if (machine.status == MachineStatus::MissingInput) {
            return depositActionText(sim, ItemId::BeaconCore);
        }
        return "archive charge " + std::to_string(machine.progress) + "/360 " +
            powerNetworkDetail(sim, machine);
    case MachineKind::TrainStop:
        return "train buffer " + stacksText(machine.inventory) +
            " trips " + std::to_string(sim.productionTotals().trainDeliveries);
    case MachineKind::OffshorePump:
        return "pumps water barrels from adjacent water " + outputTargetText(sim, machine);
    case MachineKind::RiftGate:
        if (machine.status == MachineStatus::MissingInput) {
            return depositActionText(sim, ItemId::BeaconCore);
        }
        return "rift charge " + std::to_string(machine.progress) + "/180 " +
            powerNetworkDetail(sim, machine);
    case MachineKind::Workbench:
        return "crafting station";
    }
    return "";
}

void drawFittedText(
    std::string text,
    int x,
    int y,
    int maxWidth,
    int fontSize,
    Color color)
{
    if (MeasureText(text.c_str(), fontSize) <= maxWidth) {
        DrawText(text.c_str(), x, y, fontSize, color);
        return;
    }

    constexpr std::string_view ellipsis = "...";
    while (text.size() > ellipsis.size() && MeasureText((text + std::string(ellipsis)).c_str(), fontSize) > maxWidth) {
        text.pop_back();
    }
    text += ellipsis;
    DrawText(text.c_str(), x, y, fontSize, color);
}

void drawChip(
    int x,
    int y,
    int width,
    const std::string& label,
    const std::string& value,
    Color accent)
{
    const Rectangle rect{
        static_cast<float>(x),
        static_cast<float>(y),
        static_cast<float>(width),
        24.0f};
    DrawRectangleRec(rect, Color{22, 27, 29, 232});
    DrawRectangle(static_cast<int>(rect.x), static_cast<int>(rect.y), 3, static_cast<int>(rect.height), accent);
    DrawRectangleLinesEx(rect, 1.0f, Color{70, 84, 88, 190});
    drawFittedText(label, x + 8, y + 3, width - 14, 8, Color{150, 166, 162, 255});
    drawFittedText(value, x + 8, y + 12, width - 14, 10, Color{232, 238, 232, 255});
}

const thoth::game::RecipeDef* activePanelRecipe(const thoth::game::Machine& machine)
{
    using thoth::game::MachineKind;
    if (machine.kind == MachineKind::Furnace) {
        return panelFurnaceRecipe(machine);
    }
    if (machine.kind == MachineKind::Assembler) {
        return thoth::game::recipeDef(machine.recipeKey.empty() ? "science_pack" : machine.recipeKey);
    }
    return nullptr;
}

std::string machineProcessChipText(const thoth::game::Simulation& sim, const thoth::game::Machine& machine)
{
    using thoth::game::ItemId;
    using thoth::game::MachineKind;

    if (const auto* recipe = activePanelRecipe(machine)) {
        if (machine.kind == MachineKind::Furnace) {
            return std::string(recipe->key) + " " + std::to_string(machine.progress) + "/30";
        }
        return std::string(recipe->key) + " " + std::to_string(machine.progress) + "/" +
            std::to_string(recipe->ticks);
    }

    switch (machine.kind) {
    case MachineKind::Belt:
    case MachineKind::FastBelt:
    case MachineKind::Splitter:
    case MachineKind::Pipe:
        return machine.carriedItem == ItemId::None ?
            "empty " + directionText(machine.direction) :
            shortItemName(machine.carriedItem) + " " + directionText(machine.direction);
    case MachineKind::Inserter:
    case MachineKind::CircuitInserter:
        return machine.carriedItem == ItemId::None ?
            "ready " + directionText(machine.direction) :
            "holding " + shortItemName(machine.carriedItem);
    case MachineKind::BurnerMiner:
    case MachineKind::ElectricMiner: {
        const auto tile = sim.world().getTile(machine.x, machine.y);
        return std::string(thoth::game::toString(tile.id)) + " x" + std::to_string(std::max(0, tile.data));
    }
    case MachineKind::Lab:
        return std::string(sim.activeTech()) + " " + std::to_string(sim.researchProgress()) + "/" +
            std::to_string(sim.researchGoal());
    case MachineKind::Generator:
        return "fuel " + std::to_string(machine.fuelTicks) + " coal " +
            std::to_string(machine.inventory.count(ItemId::Coal));
    case MachineKind::PowerPole:
        return powerNetworkDetail(sim, machine);
    case MachineKind::Chest:
    case MachineKind::ProviderChest:
    case MachineKind::RequesterChest:
        return "stacks " + std::to_string(static_cast<int>(machine.inventory.stacks().size()));
    case MachineKind::LogisticPort:
        return "drones " + std::to_string(machine.inventory.count(ItemId::LogisticDrone)) +
            " jobs " + std::to_string(static_cast<int>(sim.logisticJobs().size()));
    case MachineKind::ArchiveTerminal:
        return "charge " + std::to_string(machine.progress) + "/360";
    case MachineKind::TrainStop:
        return "stacks " + std::to_string(static_cast<int>(machine.inventory.stacks().size()));
    case MachineKind::OffshorePump:
        return "water " + std::to_string(machine.progress) + "/30";
    case MachineKind::RiftGate:
        return "rift " + std::to_string(machine.progress) + "/180";
    case MachineKind::Workbench:
        return "hand recipes";
    case MachineKind::Furnace:
    case MachineKind::Assembler:
        break;
    }
    return "idle";
}

std::string machineActionChipText(const thoth::game::Simulation& sim, const thoth::game::Machine& machine)
{
    using thoth::game::MachineKind;
    using thoth::game::MachineStatus;

    switch (machine.status) {
    case MachineStatus::MissingInput:
        if (machine.kind == MachineKind::Lab) {
            return "load science";
        }
        if (machine.kind == MachineKind::BurnerMiner || machine.kind == MachineKind::ElectricMiner) {
            return "move to ore";
        }
        return "load input";
    case MachineStatus::MissingFuel:
        return "add coal";
    case MachineStatus::MissingPower:
        return "link power";
    case MachineStatus::OutputBlocked:
        return "clear output";
    case MachineStatus::Working:
        return "producing";
    case MachineStatus::Idle:
        break;
    }

    if (machine.kind == MachineKind::PowerPole) {
        return powerNetworkDetail(sim, machine);
    }
    if (machine.kind == MachineKind::Chest ||
        machine.kind == MachineKind::ProviderChest ||
        machine.kind == MachineKind::RequesterChest ||
        machine.kind == MachineKind::TrainStop) {
        return "store/take";
    }
    if (machine.kind == MachineKind::LogisticPort ||
        machine.kind == MachineKind::ArchiveTerminal ||
        machine.kind == MachineKind::RiftGate) {
        return powerNetworkDetail(sim, machine);
    }
    return "inspect";
}

int machineAvailableCountForPanel(const thoth::game::Machine& machine, thoth::game::ItemId item)
{
    int count = machine.inventory.count(item);
    if (machine.carriedItem == item) {
        ++count;
    }
    if (machine.outputItem == item) {
        ++count;
    }
    return count;
}

int effectiveMachineTransferAmount(
    const thoth::game::Simulation& sim,
    const thoth::game::Machine& machine,
    const MachinePanelButton& button,
    int requestedAmount)
{
    using thoth::game::ItemId;
    using thoth::game::MachineKind;

    const bool singleSlotTransfer =
        machine.kind == MachineKind::Belt ||
        machine.kind == MachineKind::FastBelt ||
        machine.kind == MachineKind::Splitter ||
        machine.kind == MachineKind::Pipe;
    if (button.deposit) {
        const int available = sim.itemCount(button.item);
        if (available <= 0) {
            return 0;
        }
        if (singleSlotTransfer) {
            return machine.carriedItem == ItemId::None ? 1 : 0;
        }
        if (requestedAmount == 0) {
            return available;
        }
        return std::min(requestedAmount, available);
    }

    const int available = machineAvailableCountForPanel(machine, button.item);
    if (available <= 0) {
        return 0;
    }
    if (requestedAmount == 0) {
        return available;
    }
    return std::min(requestedAmount, available);
}

const std::vector<FirstLinePartGuide>& firstLinePartGuides()
{
    using thoth::game::ItemId;
    using thoth::game::MachineKind;

    static const std::vector<FirstLinePartGuide> guides = {
        {ItemId::Workbench, MachineKind::Workbench, "workbench", "workbench", "K"},
        {ItemId::BurnerMiner, MachineKind::BurnerMiner, "burner_miner", "burner miner", "M"},
        {ItemId::Belt, MachineKind::Belt, "belt", "belt", "B"},
        {ItemId::Inserter, MachineKind::Inserter, "inserter", "inserter", "I"},
        {ItemId::Furnace, MachineKind::Furnace, "furnace", "furnace", "F"},
        {ItemId::Chest, MachineKind::Chest, "chest", "chest", "C"},
    };
    return guides;
}

int firstLinePartCount(const thoth::game::Simulation& sim, const FirstLinePartGuide& guide)
{
    int count = sim.itemCount(guide.item) + machineCount(sim, guide.machine);
    if (guide.item == thoth::game::ItemId::Belt) {
        count += sim.itemCount(thoth::game::ItemId::FastBelt) + machineCount(sim, thoth::game::MachineKind::FastBelt);
    }
    return count;
}

const FirstLinePartGuide* firstMissingFirstLinePart(const thoth::game::Simulation& sim)
{
    for (const auto& guide : firstLinePartGuides()) {
        if (firstLinePartCount(sim, guide) <= 0) {
            return &guide;
        }
    }
    return nullptr;
}

const thoth::game::Machine* firstMachineByKind(const thoth::game::Simulation& sim, thoth::game::MachineKind kind)
{
    for (const auto& machine : sim.machines()) {
        if (machine.kind == kind ||
            (kind == thoth::game::MachineKind::Belt && machine.kind == thoth::game::MachineKind::FastBelt)) {
            return &machine;
        }
    }
    return nullptr;
}

std::string firstLinePlacementHint(const thoth::game::Simulation& sim)
{
    using thoth::game::MachineKind;

    if (firstMachineByKind(sim, MachineKind::BurnerMiner) == nullptr) {
        return "next: select miner, face iron ore, rotate output toward open ground, then press P";
    }
    if (firstMachineByKind(sim, MachineKind::Belt) == nullptr) {
        return "next: place a belt on the miner output tile so ore can move";
    }
    if (firstMachineByKind(sim, MachineKind::Inserter) == nullptr) {
        return "next: place an inserter after the belt, arrow pointing into the furnace";
    }
    if (firstMachineByKind(sim, MachineKind::Furnace) == nullptr) {
        return "next: place a furnace where the inserter arrow ends";
    }
    if (firstMachineByKind(sim, MachineKind::Chest) == nullptr) {
        return "next: place a chest on the furnace output side to store plates";
    }
    return "";
}

std::string firstLineFuelHint(const thoth::game::Simulation& sim)
{
    using thoth::game::ItemId;
    using thoth::game::MachineKind;

    for (const auto& machine : sim.machines()) {
        if ((machine.kind == MachineKind::BurnerMiner || machine.kind == MachineKind::Furnace) &&
            machine.fuelTicks == 0 && machine.inventory.count(ItemId::Coal) == 0) {
            const std::string label = machine.kind == MachineKind::BurnerMiner ? "miner" : "furnace";
            if (sim.itemCount(ItemId::Coal) > 0) {
                return "next: select coal, face the " + label + " at " +
                    std::to_string(machine.x) + "," + std::to_string(machine.y) + ", then press E";
            }
            return "next: mine coal east of spawn, then fuel the " + label;
        }
    }
    return "";
}

std::string firstLineBlockerHint(const thoth::game::Simulation& sim)
{
    using thoth::game::MachineStatus;

    for (const auto& machine : sim.machines()) {
        if (machine.status == MachineStatus::OutputBlocked) {
            return "next: output blocked at " + std::to_string(machine.x) + "," + std::to_string(machine.y) +
                "; face it, inspect the panel, then clear or extend its output";
        }
    }
    for (const auto& machine : sim.machines()) {
        if (machine.status == MachineStatus::MissingInput) {
            return "next: " + std::string(thoth::game::toString(machine.kind)) + " at " +
                std::to_string(machine.x) + "," + std::to_string(machine.y) +
                " needs input; check arrows from miner -> belt -> inserter -> furnace -> chest";
        }
    }
    return "";
}

std::string tutorialNextStepText(const thoth::game::Simulation& sim)
{
    using thoth::game::ItemId;
    using thoth::game::MachineKind;

    if (sim.isRecipeUnlocked("fast_belt")) {
        if (!hasItemOrMachine(sim, ItemId::Generator, MachineKind::Generator)) {
            return "next: craft generator with G or the build card";
        }
        if (!hasItemOrMachine(sim, ItemId::PowerPole, MachineKind::PowerPole)) {
            return "next: craft power poles with O or the build card";
        }
        if (!hasItemOrMachine(sim, ItemId::ElectricMiner, MachineKind::ElectricMiner)) {
            return "next: craft electric miner with N or the build card";
        }
        if (machineCount(sim, MachineKind::Generator) == 0) {
            return "next: place the generator near where the first pole will go";
        }
        if (machineCount(sim, MachineKind::PowerPole) == 0) {
            return "next: place a power pole within 2 tiles of the generator";
        }
        if (machineCount(sim, MachineKind::ElectricMiner) == 0) {
            return "next: place electric miner on ore within 2 tiles of a pole";
        }
        if (!hasGeneratorFuel(sim)) {
            return "next: face the generator and deposit coal";
        }
        if (!hasPoweredConsumerNetwork(sim)) {
            return "next: connect generator -> pole -> electric miner; poles link within 4 tiles";
        }
        if (!hasItemOrMachine(sim, ItemId::FastBelt, MachineKind::FastBelt)) {
            return "next: craft fast belts with T to upgrade busy lines";
        }
        return "next: scale powered mining, add poles before networks become underpowered";
    }

    const bool hasIronPlate = itemCountInMachines(sim, MachineKind::Chest, ItemId::IronPlate) > 0;
    const bool hasCopperPlate = itemCountInMachines(sim, MachineKind::Chest, ItemId::CopperPlate) > 0;
    if (hasIronPlate && hasCopperPlate) {
        const bool hasAssembler = hasItemOrMachine(sim, ItemId::Assembler, MachineKind::Assembler);
        const bool hasLab = hasItemOrMachine(sim, ItemId::Lab, MachineKind::Lab);
        if (!hasAssembler) {
            return "next: craft assembler with X or the build card";
        }
        if (!hasLab) {
            return "next: craft lab with L or the build card";
        }
        if (machineCount(sim, MachineKind::Assembler) == 0) {
            return "next: place the assembler, face it, then load iron and copper plates";
        }
        if (itemCountInFactory(sim, ItemId::SciencePack) <= 0 && sim.itemCount(ItemId::SciencePack) <= 0) {
            return "next: face the assembler and deposit iron plus copper plates";
        }
        if (machineCount(sim, MachineKind::Lab) == 0) {
            return "next: place the lab near the science output";
        }
        if (itemCountInMachines(sim, MachineKind::Lab, ItemId::SciencePack) <= 0 &&
            sim.researchProgress() <= 0) {
            return "next: face the lab and deposit science packs";
        }
        return "next: keep the lab fed until Logistics 1 unlocks power and fast belts";
    }
    if (hasIronPlate) {
        return "next: repeat the line on copper ore; science needs copper plates too";
    }

    if (!hasFirstLineParts(sim)) {
        if (sim.itemCount(ItemId::Wood) <= 0) {
            return "next: mine trees west of spawn for wood";
        }
        if (sim.itemCount(ItemId::Stone) <= 0) {
            return "next: mine stone south of spawn for crafting";
        }
        if (!hasItemOrMachine(sim, ItemId::Workbench, MachineKind::Workbench)) {
            if (canCraftRecipe(sim, "workbench")) {
                return "next: press K or click the build card to craft a workbench";
            }
            return "next: gather wood and stone for a workbench";
        }
        if (machineCount(sim, MachineKind::Workbench) == 0) {
            return "next: place the workbench, then stand next to it to craft machines";
        }
        if (sim.itemCount(ItemId::Coal) <= 0 && machineCount(sim, MachineKind::BurnerMiner) == 0) {
            return "next: mine coal east of spawn for burner fuel";
        }
        if (const auto* missing = firstMissingFirstLinePart(sim)) {
            if (canCraftRecipe(sim, missing->recipeKey)) {
                return "next: press " + std::string(missing->hotkey) + " or click the build card to craft " +
                    std::string(missing->label);
            }
            if (const auto* recipe = thoth::game::recipeDef(missing->recipeKey)) {
                return "next: gather inputs for " + std::string(missing->label) + " (" + recipeCostText(sim, *recipe) + ")";
            }
        }
    }

    if (!hasPlacedFirstLine(sim)) {
        return firstLinePlacementHint(sim);
    }

    if (const auto fuel = firstLineFuelHint(sim); !fuel.empty()) {
        return fuel;
    }
    if (const auto blocker = firstLineBlockerHint(sim); !blocker.empty()) {
        return blocker;
    }
    return "next: wait for the first iron plate, or face each machine to inspect progress";
}

void handleCraftMenuInput(thoth::game::Simulation& sim, AppState& state, const AudioBank& audio)
{
    if (IsKeyPressed(KEY_Q)) {
        state.craftMenuOpen = !state.craftMenuOpen;
        state.status = state.craftMenuOpen ? "build menu open" : "build menu hidden";
        playCue(audio, audio.tick);
    }

    if (!state.craftMenuOpen) {
        return;
    }

    clampCraftSelection(state);
    const int entryCount = static_cast<int>(craftMenuEntries().size());
    if (entryCount <= 0) {
        return;
    }

    if (IsKeyPressed(KEY_LEFT_BRACKET)) {
        state.craftSelection = (state.craftSelection + entryCount - 1) % entryCount;
        playCue(audio, audio.tick);
    }
    if (IsKeyPressed(KEY_RIGHT_BRACKET)) {
        state.craftSelection = (state.craftSelection + 1) % entryCount;
        playCue(audio, audio.tick);
    }
    if (IsKeyPressed(KEY_Z)) {
        queueSelectedCraft(sim, state, audio);
    }

    if (IsMouseButtonPressed(MOUSE_BUTTON_LEFT)) {
        const auto mouse = GetMousePosition();
        for (int i = 0; i < entryCount; ++i) {
            if (!CheckCollisionPointRec(mouse, craftCardRect(i))) {
                continue;
            }
            state.craftSelection = i;
            queueSelectedCraft(sim, state, audio);
            break;
        }
    }
}

std::string factoryStatsText(const thoth::game::Simulation& sim)
{
    using thoth::game::ItemId;
    using thoth::game::MachineKind;

    return "factory: miners=" + std::to_string(machineCount(sim, MachineKind::BurnerMiner)) +
        " furnaces=" + std::to_string(machineCount(sim, MachineKind::Furnace)) +
        " assemblers=" + std::to_string(machineCount(sim, MachineKind::Assembler)) +
        " labs=" + std::to_string(machineCount(sim, MachineKind::Lab)) +
        " generators=" + std::to_string(machineCount(sim, MachineKind::Generator)) +
        " poles=" + std::to_string(machineCount(sim, MachineKind::PowerPole)) +
        " electric_miners=" + std::to_string(machineCount(sim, MachineKind::ElectricMiner)) +
        " inserters=" + std::to_string(machineCount(sim, MachineKind::Inserter)) +
        " circuit_ins=" + std::to_string(machineCount(sim, MachineKind::CircuitInserter)) +
        " ports=" + std::to_string(machineCount(sim, MachineKind::LogisticPort)) +
        " splitters=" + std::to_string(machineCount(sim, MachineKind::Splitter)) +
        " trains=" + std::to_string(machineCount(sim, MachineKind::TrainStop)) +
        " pumps=" + std::to_string(machineCount(sim, MachineKind::OffshorePump)) +
        " archive=" + std::to_string(sim.productionTotals().archiveSignals) +
        " rift=" + std::to_string(sim.productionTotals().riftJumps) +
        " deliveries=" + std::to_string(sim.productionTotals().logisticDeliveries) +
        " chests=" + std::to_string(machineCount(sim, MachineKind::Chest)) +
        " belts_loaded=" + std::to_string(beltItemCount(sim)) +
        " plates_in_chests=" + std::to_string(itemCountInMachines(sim, MachineKind::Chest, ItemId::IronPlate)) +
        " copper_in_chests=" + std::to_string(itemCountInMachines(sim, MachineKind::Chest, ItemId::CopperPlate)) +
        " blocked=" + std::to_string(blockedMachineCount(sim));
}

std::string powerStatsText(const thoth::game::Simulation& sim)
{
    const auto& networks = sim.powerNetworks();
    if (networks.empty()) {
        return "power: no networks";
    }

    std::string text = "power:";
    for (const auto& network : networks) {
        text += " net";
        text += std::to_string(network.id);
        text += " ";
        text += std::to_string(network.supply);
        text += "/";
        text += std::to_string(network.demand);
        text += network.powered ? " ok" : " under";
    }
    return text;
}

std::string objectiveText(const thoth::game::Simulation& sim)
{
    using thoth::game::ItemId;
    using thoth::game::MachineKind;

    if (sim.productionTotals().riftJumps > 0) {
        return "objective: exploit the rift dimension's richer resources";
    }
    if (sim.productionTotals().archiveSignals > 0) {
        return "objective: craft/place a rift gate, power it, and load a beacon core";
    }
    if (sim.isRecipeUnlocked("archive_terminal")) {
        return "objective: craft beacon cores, build a powered archive terminal, then charge it";
    }
    if (sim.isRecipeUnlocked("fast_belt")) {
        return "objective: logistics researched; use the build menu for generator, poles, electric miners, and fast belts";
    }
    const bool hasStoredIronPlate = itemCountInMachines(sim, MachineKind::Chest, ItemId::IronPlate) > 0;
    const bool hasStoredCopperPlate = itemCountInMachines(sim, MachineKind::Chest, ItemId::CopperPlate) > 0;
    if (hasStoredIronPlate && hasStoredCopperPlate) {
        return "objective: craft assembler and lab, then feed iron plus copper plates into science";
    }
    if (hasStoredIronPlate) {
        return "objective: smelt copper too; science needs both iron and copper plates";
    }
    if (machineCount(sim, MachineKind::BurnerMiner) == 0 ||
        machineCount(sim, MachineKind::Furnace) == 0 ||
        machineCount(sim, MachineKind::Inserter) == 0 ||
        machineCount(sim, MachineKind::Chest) == 0) {
        return "objective: mine trees west, stone south, coal east; craft/place a workbench, then build factory parts";
    }
    for (const auto& machine : sim.machines()) {
        if ((machine.kind == MachineKind::BurnerMiner || machine.kind == MachineKind::Furnace) &&
            machine.fuelTicks == 0 && machine.inventory.count(ItemId::Coal) == 0) {
            return "objective: select coal and press E facing each burner machine";
        }
    }
    if (blockedMachineCount(sim) > 0) {
        return "objective: clear blocked output; face machines to inspect status";
    }
    return "objective: wait for ore -> plate -> chest";
}

std::string placementBlockReason(const thoth::game::Simulation& sim, thoth::game::ItemId item)
{
    using thoth::game::TileId;

    if (item == thoth::game::ItemId::None) {
        return "select an item";
    }
    if (sim.itemCount(item) <= 0) {
        return "no item left";
    }

    const auto& player = sim.player();
    const int tx = player.x + thoth::game::dx(player.facing);
    const int ty = player.y + thoth::game::dy(player.facing);
    if (sim.machineAt(tx, ty) != nullptr) {
        return "target occupied";
    }

    const auto targetTile = sim.world().getTile(tx, ty);
    const auto& def = thoth::game::itemDef(item);
    if (def.canPlaceMachine) {
        const auto& machine = thoth::game::machineDef(def.placeMachine);
        if (machine.requiresResourceTile) {
            if (targetTile.id != TileId::IronOre && targetTile.id != TileId::CopperOre && targetTile.id != TileId::CoalOre) {
                return "needs ore or coal tile";
            }
            return "";
        }
        if (machine.requiresBuildableTile) {
            const auto& tile = thoth::game::tileDef(targetTile.id);
            if (!tile.walkable) {
                return "clear " + std::string(tile.displayName);
            }
            if (!tile.buildable) {
                return "needs buildable ground";
            }
        }
        return "";
    }
    if (def.canPlaceTile) {
        if (!thoth::game::isWalkable(targetTile.id)) {
            return "clear target first";
        }
        if (!thoth::game::tileDef(def.placeTile).walkable) {
            return "cannot place blocking tile";
        }
        return "";
    }
    return "item is not placeable";
}

bool canPreviewPlace(const thoth::game::Simulation& sim, thoth::game::ItemId item)
{
    return placementBlockReason(sim, item).empty();
}

bool selectedBuildToolActive(const thoth::game::Simulation& sim)
{
    const auto item = sim.selectedItem();
    if (item == thoth::game::ItemId::None) {
        return false;
    }
    const auto& def = thoth::game::itemDef(item);
    return def.canPlaceTile || def.canPlaceMachine;
}

thoth::game::Direction facingFromInput(thoth::game::Direction fallback)
{
    using thoth::game::Direction;
    if (IsKeyDown(KEY_W) || IsKeyDown(KEY_UP)) {
        return Direction::North;
    }
    if (IsKeyDown(KEY_D) || IsKeyDown(KEY_RIGHT)) {
        return Direction::East;
    }
    if (IsKeyDown(KEY_S) || IsKeyDown(KEY_DOWN)) {
        return Direction::South;
    }
    if (IsKeyDown(KEY_A) || IsKeyDown(KEY_LEFT)) {
        return Direction::West;
    }
    return fallback;
}

bool movementInputHeld()
{
    return IsKeyDown(KEY_W) || IsKeyDown(KEY_A) || IsKeyDown(KEY_S) || IsKeyDown(KEY_D) ||
        IsKeyDown(KEY_UP) || IsKeyDown(KEY_DOWN) || IsKeyDown(KEY_LEFT) || IsKeyDown(KEY_RIGHT);
}

void updatePlayerVisual(const thoth::game::Simulation& sim, AppState& state)
{
    const float targetX = static_cast<float>(sim.player().x);
    const float targetY = static_cast<float>(sim.player().y);
    if (!state.renderPlayerReady || std::abs(state.renderPlayerX - targetX) + std::abs(state.renderPlayerY - targetY) > 4.0f) {
        state.renderPlayerX = targetX;
        state.renderPlayerY = targetY;
        state.renderPlayerReady = true;
        return;
    }
    state.renderPlayerX += (targetX - state.renderPlayerX) * kPlayerVisualLerp;
    state.renderPlayerY += (targetY - state.renderPlayerY) * kPlayerVisualLerp;
    if (std::abs(state.renderPlayerX - targetX) < 0.01f) {
        state.renderPlayerX = targetX;
    }
    if (std::abs(state.renderPlayerY - targetY) < 0.01f) {
        state.renderPlayerY = targetY;
    }
}

std::string facedMachineText(const thoth::game::Simulation& sim)
{
    const auto* machine = facedMachine(sim);
    if (machine == nullptr) {
        return "facing: none";
    }

    return "facing: " + std::string(thoth::game::toString(machine->kind)) +
        " status=" + std::string(thoth::game::toString(machine->status)) +
        " fuel=" + std::to_string(machine->fuelTicks) +
        " progress=" + std::to_string(machine->progress) +
        " carry=" + std::string(thoth::game::toString(machine->carriedItem)) +
        " output=" + std::string(thoth::game::toString(machine->outputItem)) +
        " inv=" + stacksText(machine->inventory);
}

std::string directionText(thoth::game::Direction direction)
{
    switch (direction) {
    case thoth::game::Direction::North:
        return "north";
    case thoth::game::Direction::East:
        return "east";
    case thoth::game::Direction::South:
        return "south";
    case thoth::game::Direction::West:
        return "west";
    }
    return "south";
}

std::string placementPreviewText(
    const thoth::game::Simulation& sim,
    thoth::game::ItemId item,
    thoth::game::Direction buildDirection)
{
    const auto reason = placementBlockReason(sim, item);
    if (!reason.empty()) {
        return "blocked: " + reason;
    }
    return "place " + shortItemName(item) + " -> " + directionText(buildDirection);
}

bool canMineFacing(const thoth::game::Simulation& sim)
{
    const auto& player = sim.player();
    const auto tile = sim.world().getTile(
        player.x + thoth::game::dx(player.facing),
        player.y + thoth::game::dy(player.facing));
    return thoth::game::isMineable(tile.id);
}

bool isResourceTile(thoth::game::TileId id)
{
    return id == thoth::game::TileId::IronOre ||
        id == thoth::game::TileId::CopperOre ||
        id == thoth::game::TileId::CoalOre;
}

void handleInventoryInput(thoth::game::Simulation& sim, AppState& state, const AudioBank& audio)
{
    if (IsKeyPressed(KEY_V)) {
        state.inventoryOpen = !state.inventoryOpen;
        state.status = state.inventoryOpen ? "inventory open" : "inventory closed";
        playCue(audio, audio.tick);
    }

    if (!state.inventoryOpen) {
        return;
    }

    const bool leftClick = IsMouseButtonPressed(MOUSE_BUTTON_LEFT);
    const bool rightClick = IsMouseButtonPressed(MOUSE_BUTTON_RIGHT);
    if (!leftClick && !rightClick) {
        return;
    }

    const auto mouse = GetMousePosition();
    for (const auto& button : inventoryHotbarButtons()) {
        if (!CheckCollisionPointRec(mouse, button.rect)) {
            continue;
        }

        if (rightClick) {
            sim.queue(thoth::game::Command::assignHotbar(button.hotbarIndex, thoth::game::ItemId::None));
            setFeedback(state, "cleared slot " + std::to_string(button.hotbarIndex + 1), Color{122, 184, 244, 220});
        } else {
            sim.queue(thoth::game::Command::selectHotbar(button.hotbarIndex));
            setFeedback(state, "selected slot " + std::to_string(button.hotbarIndex + 1), Color{122, 184, 244, 220});
        }
        playCue(audio, audio.tick);
        return;
    }

    if (!leftClick) {
        return;
    }

    for (const auto& button : inventoryButtons(sim)) {
        if (!CheckCollisionPointRec(mouse, button.rect)) {
            continue;
        }

        sim.queue(thoth::game::Command::assignHotbar(sim.player().selectedHotbar, button.item));
        setFeedback(
            state,
            "slot " + std::to_string(sim.player().selectedHotbar + 1) + " <- " + std::string(thoth::game::toString(button.item)),
            Color{103, 214, 132, 220});
        playCue(audio, audio.tick);
        return;
    }
}

void handleMachinePanelInput(thoth::game::Simulation& sim, AppState& state, const AudioBank& audio)
{
    if (!IsMouseButtonPressed(MOUSE_BUTTON_LEFT)) {
        return;
    }

    const auto mouse = GetMousePosition();
    const auto* machine = facedMachine(sim);
    if (machine == nullptr) {
        return;
    }

    for (const auto& button : transferAmountButtons()) {
        if (!CheckCollisionPointRec(mouse, button.rect)) {
            continue;
        }

        state.machineTransferAmount = button.amount;
        setFeedback(
            state,
            std::string("machine transfer ") + (button.amount == 0 ? "all" : std::to_string(button.amount) + "x"),
            Color{122, 184, 244, 220});
        playCue(audio, audio.tick);
        return;
    }

    for (const auto& button : machinePanelButtons(sim)) {
        if (!CheckCollisionPointRec(mouse, button.rect)) {
            continue;
        }

        const int amount = effectiveMachineTransferAmount(sim, *machine, button, state.machineTransferAmount);
        if (amount <= 0) {
            setFeedback(state, "transfer blocked: " + std::string(thoth::game::toString(button.item)), Color{236, 84, 84, 220});
            playCue(audio, audio.invalid);
            return;
        }

        if (button.deposit) {
            for (int i = 0; i < amount; ++i) {
                sim.queue(thoth::game::Command::depositItem(sim.player().facing, button.item));
            }
            setFeedback(
                state,
                "deposited " + std::to_string(amount) + "x " + std::string(thoth::game::toString(button.item)),
                Color{103, 214, 132, 220});
            playCue(audio, audio.place);
        } else {
            for (int i = 0; i < amount; ++i) {
                sim.queue(thoth::game::Command::withdrawItem(sim.player().facing, button.item));
            }
            setFeedback(
                state,
                "withdrew " + std::to_string(amount) + "x " + std::string(thoth::game::toString(button.item)),
                Color{122, 184, 244, 220});
            playCue(audio, audio.tick);
        }
        return;
    }

    for (const auto& button : machineRecipeButtons(sim)) {
        if (!CheckCollisionPointRec(mouse, button.rect)) {
            continue;
        }

        sim.queue(thoth::game::Command::configureMachineRecipe(sim.player().facing, std::string(button.recipeKey)));
        setFeedback(state, "machine recipe " + std::string(button.recipeKey), Color{122, 184, 244, 220});
        playCue(audio, audio.tick);
        return;
    }

    for (const auto& button : machineConfigButtons(sim)) {
        if (!CheckCollisionPointRec(mouse, button.rect)) {
            continue;
        }

        if (button.action == MachineConfigAction::Circuit) {
            sim.queue(thoth::game::Command::configureCircuit(sim.player().facing, button.item, button.comparator, button.threshold));
            setFeedback(state, "circuit " + std::string(button.label), Color{122, 184, 244, 220});
        } else {
            sim.queue(thoth::game::Command::configureRequest(sim.player().facing, button.item, button.threshold));
            setFeedback(state, "request " + std::string(button.label), Color{122, 184, 244, 220});
        }
        playCue(audio, audio.tick);
        return;
    }
}

void placeScenarioMachine(
    thoth::game::Simulation& sim,
    thoth::game::ItemId item,
    int x,
    int y,
    thoth::game::Direction targetDirection,
    thoth::game::Direction orientation,
    thoth::game::Tile tile)
{
    sim.world().setTile(x, y, tile);
    const auto added = sim.player().inventory.add(item, 1);
    (void)added;
    sim.player().x = x - thoth::game::dx(targetDirection);
    sim.player().y = y - thoth::game::dy(targetDirection);
    sim.queue(thoth::game::Command::placeItem(targetDirection, item, orientation));
    sim.step();
}

thoth::game::Simulation makeDemoScenario()
{
    using thoth::game::Direction;
    using thoth::game::ItemId;
    using thoth::game::MachineKind;
    using thoth::game::Tile;
    using thoth::game::TileId;

    thoth::game::Simulation sim(20260609);
    placeScenarioMachine(sim, ItemId::BurnerMiner, 1, 0, Direction::East, Direction::East, Tile{TileId::IronOre, 1});
    placeScenarioMachine(sim, ItemId::Belt, 2, 0, Direction::East, Direction::East, Tile{TileId::Floor, 0});
    placeScenarioMachine(sim, ItemId::Inserter, 3, 0, Direction::East, Direction::East, Tile{TileId::Floor, 0});
    placeScenarioMachine(sim, ItemId::Furnace, 4, 0, Direction::East, Direction::East, Tile{TileId::Floor, 0});
    placeScenarioMachine(sim, ItemId::Chest, 5, 0, Direction::East, Direction::East, Tile{TileId::Floor, 0});

    auto* miner = sim.machineAt(1, 0);
    auto* furnace = sim.machineAt(4, 0);
    if (miner != nullptr && miner->kind == MachineKind::BurnerMiner) {
        const auto addedCoal = miner->inventory.add(ItemId::Coal, 2);
        (void)addedCoal;
    }
    if (furnace != nullptr && furnace->kind == MachineKind::Furnace) {
        const auto addedCoal = furnace->inventory.add(ItemId::Coal, 2);
        (void)addedCoal;
    }

    sim.player().x = 0;
    sim.player().y = 1;
    for (int i = 0; i < 90; ++i) {
        sim.step();
    }
    return sim;
}

std::optional<thoth::game::Simulation> loadPackagedReplay(
    const std::filesystem::path& replayPath,
    std::string* error)
{
    const auto path = findBundledPath(replayPath);
    if (!path) {
        if (error != nullptr) {
            *error = "demo replay file not found";
        }
        return std::nullopt;
    }

    auto document = thoth::game::loadReplayDocument(*path, error);
    if (!document) {
        return std::nullopt;
    }
    return thoth::game::runReplayDocument(*document);
}

void queueInput(thoth::game::Simulation& sim, AppState& state, const AudioBank& audio)
{
    using thoth::game::Command;

    handleInventoryInput(sim, state, audio);
    handleCraftMenuInput(sim, state, audio);
    handleMachinePanelInput(sim, state, audio);

    if (state.movementCooldownFrames > 0) {
        --state.movementCooldownFrames;
    }
    const bool moving = movementInputHeld();
    auto direction = facingFromInput(sim.player().facing);
    if (moving && state.movementCooldownFrames <= 0) {
        sim.queue(Command::move(direction));
        state.movementCooldownFrames = kMoveRepeatFrames;
    } else if (moving && direction != sim.player().facing) {
        sim.queue(Command::face(direction));
    } else if (!moving) {
        state.movementCooldownFrames = 0;
    }

    if (IsKeyPressed(KEY_SPACE)) {
        if (canMineFacing(sim)) {
            setFeedback(state, "mined target", Color{240, 218, 123, 220});
            playCue(audio, audio.mine);
        } else {
            setFeedback(state, "nothing mineable", Color{236, 84, 84, 220});
            playCue(audio, audio.invalid);
        }
        sim.queue(Command::mine(sim.player().facing));
    }

    const std::array<int, thoth::game::kHotbarSlots> numberKeys = {
        KEY_ONE,
        KEY_TWO,
        KEY_THREE,
        KEY_FOUR,
        KEY_FIVE,
        KEY_SIX,
        KEY_SEVEN,
        KEY_EIGHT,
        KEY_NINE,
        KEY_ZERO,
    };
    for (int i = 0; i < thoth::game::kHotbarSlots; ++i) {
        if (IsKeyPressed(numberKeys[static_cast<std::size_t>(i)])) {
            sim.queue(Command::selectHotbar(i));
        }
    }

    if (IsKeyPressed(KEY_P)) {
        if (canPreviewPlace(sim, sim.selectedItem())) {
            sim.queue(Command::placeItem(sim.player().facing, sim.selectedItem(), state.buildDirection));
            setFeedback(state, "placed " + std::string(thoth::game::toString(sim.selectedItem())), Color{103, 214, 132, 220});
            playCue(audio, audio.place);
        } else {
            setFeedback(state, "place blocked: " + placementBlockReason(sim, sim.selectedItem()), Color{236, 84, 84, 220});
            playCue(audio, audio.invalid);
        }
    }
    if (IsKeyPressed(KEY_R)) {
        state.buildDirection = rotateClockwise(state.buildDirection);
        setFeedback(state, "build " + directionText(state.buildDirection), Color{122, 184, 244, 220});
        playCue(audio, audio.tick);
    }
    if (IsKeyPressed(KEY_E)) {
        const auto selected = sim.selectedItem();
        const auto& player = sim.player();
        const auto* target = sim.machineAt(
            player.x + thoth::game::dx(player.facing),
            player.y + thoth::game::dy(player.facing));
        if (selected != thoth::game::ItemId::None && sim.itemCount(selected) > 0 && target != nullptr) {
            setFeedback(state, "deposited " + std::string(thoth::game::toString(selected)), Color{103, 214, 132, 220});
            playCue(audio, audio.place);
        } else {
            setFeedback(state, "deposit blocked", Color{236, 84, 84, 220});
            playCue(audio, audio.invalid);
        }
        sim.queue(Command::depositSelected(sim.player().facing));
    }

    if (IsKeyPressed(KEY_K)) {
        queueCraft(sim, state, audio, "workbench");
    }
    if (IsKeyPressed(KEY_C)) {
        queueCraft(sim, state, audio, "chest");
    }
    if (IsKeyPressed(KEY_F)) {
        queueCraft(sim, state, audio, "furnace");
    }
    if (IsKeyPressed(KEY_B)) {
        queueCraft(sim, state, audio, "belt");
    }
    if (IsKeyPressed(KEY_I)) {
        queueCraft(sim, state, audio, "inserter");
    }
    if (IsKeyPressed(KEY_M)) {
        queueCraft(sim, state, audio, "burner_miner");
    }
    if (IsKeyPressed(KEY_X)) {
        queueCraft(sim, state, audio, "assembler");
    }
    if (IsKeyPressed(KEY_L)) {
        queueCraft(sim, state, audio, "lab");
    }
    if (IsKeyPressed(KEY_T)) {
        queueCraft(sim, state, audio, "fast_belt");
    }
    if (IsKeyPressed(KEY_G)) {
        queueCraft(sim, state, audio, "generator");
    }
    if (IsKeyPressed(KEY_O)) {
        queueCraft(sim, state, audio, "power_pole");
    }
    if (IsKeyPressed(KEY_N)) {
        queueCraft(sim, state, audio, "electric_miner");
    }

    if (IsKeyPressed(KEY_TAB)) {
        state.debug = !state.debug;
        playCue(audio, audio.tick);
    }
    if (IsKeyPressed(KEY_BACKSPACE)) {
        state.paused = !state.paused;
        state.status = state.paused ? "paused" : "running";
        playCue(audio, audio.tick);
    }
    if (IsKeyPressed(KEY_ENTER)) {
        state.paused = true;
        stepSimulationTimed(sim, state);
        updateProductionFeedback(sim, state, audio);
        updateMachineIssueFeedback(sim, state, audio);
        state.status = "stepped one tick";
        playCue(audio, audio.tick);
    }
    if (IsKeyPressed(KEY_F11)) {
        const int index = audioCueIndex(state.audioAuditionIndex);
        const auto name = audioCueName(index);
        playCue(audio, audioCueSound(audio, index));
        state.status = "auditioned " + std::string(name);
        setFeedback(state, "audio " + std::string(name), Color{122, 184, 244, 220});
        state.audioAuditionIndex = audioCueIndex(index + 1);
    }
    if (IsKeyPressed(KEY_F6)) {
        std::string error;
        if (saveGeneratedAtlas(kGeneratedSpriteAtlasPath, &error)) {
            state.status = "exported generated sprite atlas";
            setFeedback(state, "atlas exported", Color{103, 214, 132, 220});
            playCue(audio, audio.load);
        } else {
            state.status = "atlas export failed: " + error;
            setFeedback(state, "atlas export failed", Color{236, 84, 84, 220});
            playCue(audio, audio.invalid);
        }
    }
    if (IsKeyPressed(KEY_F7)) {
        std::string error;
        auto demo = loadPackagedReplay(kScienceReplayPath, &error);
        if (demo) {
            sim = *demo;
            state.status = "loaded science replay demo";
        } else {
            sim = makeDemoScenario();
            state.status = "science replay fallback: " + error;
        }
        syncProductionCounters(sim, state);
        syncMachineIssueCounters(sim, state);
        state.paused = false;
        setFeedback(state, "science demo loaded", Color{103, 214, 132, 220});
        playCue(audio, audio.load);
    }
    if (IsKeyPressed(KEY_F8)) {
        std::string error;
        auto demo = loadPackagedReplay(kDemoReplayPath, &error);
        if (demo) {
            sim = *demo;
            state.status = "loaded packaged replay demo";
        } else {
            sim = makeDemoScenario();
            state.status = "replay fallback: " + error;
        }
        syncProductionCounters(sim, state);
        syncMachineIssueCounters(sim, state);
        state.paused = false;
        setFeedback(state, "demo line loaded", Color{103, 214, 132, 220});
        playCue(audio, audio.load);
    }
    if (IsKeyPressed(KEY_F10)) {
        std::string error;
        auto demo = loadPackagedReplay(kFullFlowReplayPath, &error);
        if (demo) {
            sim = *demo;
            state.status = "loaded full-flow replay demo";
        } else {
            sim = makeDemoScenario();
            state.status = "full-flow fallback: " + error;
        }
        syncProductionCounters(sim, state);
        syncMachineIssueCounters(sim, state);
        state.paused = false;
        setFeedback(state, "full flow loaded", Color{103, 214, 132, 220});
        playCue(audio, audio.load);
    }

    if (IsKeyPressed(KEY_F5)) {
        std::string error;
        state.status = thoth::game::saveSimulation(sim, kSavePath, &error) ? "saved thoth_save.txt" : "save failed: " + error;
        playCue(audio, error.empty() ? audio.save : audio.invalid);
    }

    if (IsKeyPressed(KEY_F9)) {
        std::string error;
        auto loaded = thoth::game::loadSimulation(kSavePath, &error);
        if (loaded) {
            sim = *loaded;
            state.status = "loaded thoth_save.txt";
            syncProductionCounters(sim, state);
            syncMachineIssueCounters(sim, state);
            playCue(audio, audio.load);
        } else {
            state.status = "load failed: " + error;
            playCue(audio, audio.invalid);
        }
    }
}

void drawPlacementPreview(const thoth::game::Simulation& sim, thoth::game::Direction buildDirection)
{
    const auto item = sim.selectedItem();
    if (item == thoth::game::ItemId::None || !selectedBuildToolActive(sim)) {
        return;
    }

    const auto& player = sim.player();
    const int tx = player.x + thoth::game::dx(player.facing);
    const int ty = player.y + thoth::game::dy(player.facing);
    const bool valid = canPreviewPlace(sim, item);
    const Color fill = valid ? Color{90, 210, 125, 46} : Color{224, 74, 74, 46};
    const Color stroke = valid ? Color{138, 244, 170, 176} : Color{250, 122, 122, 176};
    const int px = tx * kTilePixels;
    const int py = ty * kTilePixels;

    DrawRectangle(px, py, kTilePixels, kTilePixels, fill);
    DrawRectangleLines(px, py, kTilePixels, kTilePixels, stroke);

    const Rectangle ghost{
        static_cast<float>(px + 3),
        static_cast<float>(py + 3),
        static_cast<float>(kTilePixels - 6),
        static_cast<float>(kTilePixels - 6),
    };
    if (!drawSprite(placementSprite(item), ghost, valid ? Color{255, 255, 255, 188} : Color{255, 255, 255, 106})) {
        drawItemIcon(px + (kTilePixels / 2), py + (kTilePixels / 2), item, 8);
    }

    const int cx = px + (kTilePixels / 2);
    const int cy = py + (kTilePixels / 2);
    DrawLineEx(
        Vector2{static_cast<float>(cx), static_cast<float>(cy)},
        Vector2{
            static_cast<float>(cx + thoth::game::dx(player.facing) * 9),
            static_cast<float>(cy + thoth::game::dy(player.facing) * 9)},
        1.0f,
        stroke);
    DrawLineEx(
        Vector2{static_cast<float>(cx), static_cast<float>(cy)},
        Vector2{
            static_cast<float>(cx + thoth::game::dx(buildDirection) * 7),
            static_cast<float>(cy + thoth::game::dy(buildDirection) * 7)},
        2.0f,
        Color{255, 255, 255, 230});

    const auto label = placementPreviewText(sim, item, buildDirection);
    const int fontSize = 10;
    const int textWidth = MeasureText(label.c_str(), fontSize);
    const int labelX = cx - (textWidth / 2) - 4;
    const int labelY = py - 16;
    DrawRectangle(labelX, labelY, textWidth + 8, 13, Color{12, 15, 16, 210});
    DrawRectangleLines(labelX, labelY, textWidth + 8, 13, Color{0, 0, 0, 170});
    DrawText(label.c_str(), labelX + 4, labelY + 2, fontSize, valid ? Color{180, 248, 196, 255} : Color{255, 166, 166, 255});
}

void drawBuildGridOverlay(const thoth::game::Simulation& sim)
{
    if (!selectedBuildToolActive(sim)) {
        return;
    }

    const auto& player = sim.player();
    const int centerX = player.x + thoth::game::dx(player.facing);
    const int centerY = player.y + thoth::game::dy(player.facing);
    constexpr int radius = 2;
    const int left = (centerX - radius) * kTilePixels;
    const int top = (centerY - radius) * kTilePixels;
    const int size = ((radius * 2) + 1) * kTilePixels;
    const Color line = Color{8, 12, 12, 52};

    for (int i = 0; i <= (radius * 2) + 1; ++i) {
        const int x = left + (i * kTilePixels);
        const int y = top + (i * kTilePixels);
        DrawLine(x, top, x, top + size, line);
        DrawLine(left, y, left + size, y, line);
    }
}

bool machineShowsDirection(thoth::game::MachineKind kind)
{
    using thoth::game::MachineKind;
    switch (kind) {
    case MachineKind::Belt:
    case MachineKind::FastBelt:
    case MachineKind::Splitter:
    case MachineKind::Pipe:
    case MachineKind::Inserter:
    case MachineKind::CircuitInserter:
    case MachineKind::BurnerMiner:
    case MachineKind::Furnace:
    case MachineKind::Assembler:
    case MachineKind::ElectricMiner:
    case MachineKind::OffshorePump:
        return true;
    case MachineKind::Chest:
    case MachineKind::ProviderChest:
    case MachineKind::RequesterChest:
    case MachineKind::Workbench:
    case MachineKind::Lab:
    case MachineKind::Generator:
    case MachineKind::PowerPole:
    case MachineKind::LogisticPort:
    case MachineKind::ArchiveTerminal:
    case MachineKind::TrainStop:
    case MachineKind::RiftGate:
        return false;
    }
    return false;
}

void drawMachineIssueBadge(const thoth::game::Machine& machine, int tileX, int tileY)
{
    const auto label = machineIssueBadgeText(machine.status);
    if (label.empty()) {
        return;
    }

    constexpr int fontSize = 8;
    const int width = MeasureText(label.c_str(), fontSize) + 6;
    const int x = tileX + (kTilePixels / 2) - (width / 2);
    const int y = tileY - 9;
    const Color color = statusColor(machine.status);
    DrawRectangle(x, y, width, 9, Color{12, 15, 16, 224});
    DrawRectangleLines(x, y, width, 9, color);
    DrawText(label.c_str(), x + 3, y + 1, fontSize, color);
}

Color resourceRichnessColor(thoth::game::TileId id)
{
    using thoth::game::TileId;
    switch (id) {
    case TileId::IronOre:
        return Color{226, 168, 112, 230};
    case TileId::CopperOre:
        return Color{238, 136, 78, 230};
    case TileId::CoalOre:
        return Color{38, 42, 46, 230};
    case TileId::Grass:
    case TileId::Dirt:
    case TileId::Sand:
    case TileId::Snow:
    case TileId::Mud:
    case TileId::Water:
    case TileId::Tree:
    case TileId::Stone:
    case TileId::Floor:
        break;
    }
    return Color{220, 220, 210, 230};
}

void drawResourceRichnessPips(thoth::game::Tile tile, int tileX, int tileY)
{
    if (!isResourceTile(tile.id) || tile.data <= 0) {
        return;
    }

    constexpr int maxPips = 6;
    const int pips = std::clamp(tile.data, 0, maxPips);
    const int px = tileX * kTilePixels;
    const int py = tileY * kTilePixels;
    const Color fill = resourceRichnessColor(tile.id);
    const Color empty = Color{8, 10, 10, 138};

    DrawRectangle(px + 3, py + 16, 18, 6, Color{8, 10, 10, 118});
    for (int i = 0; i < maxPips; ++i) {
        const int x = px + 5 + ((i % 6) * 3);
        const int y = py + 18;
        DrawRectangle(x, y, 2, 2, i < pips ? fill : empty);
    }
}

void drawBeltMotionOverlay(const thoth::game::Machine& machine, std::uint64_t tick, int px, int py)
{
    using thoth::game::MachineKind;
    if (!isBeltMachine(machine.kind)) {
        return;
    }

    const int period = machine.kind == MachineKind::FastBelt ? 6 : 8;
    const int phase = renderAnimationPhase(tick / (machine.kind == MachineKind::FastBelt ? 2U : 4U), machine.x, machine.y, period);
    const float travel = static_cast<float>(kTilePixels - 8);
    const float along = (-travel * 0.5f) + (travel * static_cast<float>(phase) / static_cast<float>(std::max(1, period - 1)));
    const float dirX = static_cast<float>(thoth::game::dx(machine.direction));
    const float dirY = static_cast<float>(thoth::game::dy(machine.direction));
    const float normX = -dirY;
    const float normY = dirX;
    const Vector2 center{
        static_cast<float>(px + (kTilePixels / 2)) + dirX * along,
        static_cast<float>(py + (kTilePixels / 2)) + dirY * along};
    const Vector2 a{center.x - normX * 5.0f, center.y - normY * 5.0f};
    const Vector2 b{center.x + normX * 5.0f, center.y + normY * 5.0f};
    const Color color = machine.kind == MachineKind::FastBelt ?
        Color{255, 248, 190, 214} :
        Color{34, 28, 22, 202};
    DrawLineEx(a, b, machine.kind == MachineKind::FastBelt ? 2.5f : 2.0f, color);
}

void drawMachineActivityOverlay(const thoth::game::Machine& machine, std::uint64_t tick, int px, int py)
{
    if (!hasMachineActivityPulse(machine)) {
        return;
    }

    auto color = activityPulseColor(machine.kind);
    color.a = pulseAlpha(tick, machine.x, machine.y, 76, 72);
    DrawRectangle(px + 5, py + 17, kTilePixels - 10, 3, color);
    DrawRectangle(px + 5, py + 5, 4, 4, color);
}

void drawMachine(const thoth::game::Machine& machine, std::uint64_t tick)
{
    using thoth::game::MachineKind;

    const int px = machine.x * kTilePixels;
    const int py = machine.y * kTilePixels;
    const int cx = px + (kTilePixels / 2);
    const int cy = py + (kTilePixels / 2);
    const Rectangle body{
        static_cast<float>(px + 3),
        static_cast<float>(py + 3),
        static_cast<float>(kTilePixels - 6),
        static_cast<float>(kTilePixels - 6)};
    const Color base = machineColor(machine.kind);
    const Color border = statusColor(machine.status);

    if (!drawSprite(machineSprite(machine.kind), body)) {
        DrawRectangleRec(body, base);
        const auto glyph = machineGlyph(machine.kind);
        DrawText(glyph.c_str(), cx - (MeasureText(glyph.c_str(), 9) / 2), cy - 5, 9, Color{248, 248, 238, 220});
    }
    drawMachineActivityOverlay(machine, tick, px, py);
    drawBeltMotionOverlay(machine, tick, px, py);
    DrawRectangleLinesEx(body, 2.0f, border);

    if (machineShowsDirection(machine.kind)) {
        const Color arrow = machine.kind == MachineKind::FastBelt ? Color{255, 255, 255, 218} : Color{20, 24, 24, 224};
        drawDirectionArrow(Vector2{static_cast<float>(cx), static_cast<float>(cy)}, machine.direction, 13.0f, arrow);
        if (machine.kind == MachineKind::FastBelt) {
            const float nx = static_cast<float>(-thoth::game::dy(machine.direction));
            const float ny = static_cast<float>(thoth::game::dx(machine.direction));
            drawDirectionArrow(
                Vector2{static_cast<float>(cx) + nx * 3.0f, static_cast<float>(cy) + ny * 3.0f},
                machine.direction,
                8.0f,
                Color{30, 32, 28, 210});
        }
    }

    if (machine.carriedItem != thoth::game::ItemId::None) {
        drawItemIcon(cx, cy, machine.carriedItem, 5);
    } else if (machine.outputItem != thoth::game::ItemId::None) {
        drawItemIcon(px + 18, py + 18, machine.outputItem, 5);
    }

    const float progress = machineProgressRatio(machine);
    if (progress > 0.0f) {
        DrawRectangle(px + 4, py + 20, kTilePixels - 8, 2, Color{10, 12, 12, 190});
        DrawRectangle(px + 4, py + 20, static_cast<int>((kTilePixels - 8) * progress), 2, Color{118, 230, 164, 255});
    }

    DrawCircle(px + 20, py + 5, 2.5f, border);
    drawMachineIssueBadge(machine, px, py);
}

void drawWorld(thoth::game::Simulation& sim, const AppState& state)
{
    const auto& player = sim.player();
    const int halfTilesX = (kScreenWidth / kTilePixels) / 2 + 3;
    const int halfTilesY = (kScreenHeight / kTilePixels) / 2 + 3;

    for (int y = player.y - halfTilesY; y <= player.y + halfTilesY; ++y) {
        for (int x = player.x - halfTilesX; x <= player.x + halfTilesX; ++x) {
            const auto tile = sim.world().getTile(x, y);
            const auto& def = thoth::game::tileDef(tile.id);
            const Rectangle destination{
                static_cast<float>(x * kTilePixels),
                static_cast<float>(y * kTilePixels),
                static_cast<float>(kTilePixels),
                static_cast<float>(kTilePixels),
            };
            if (!drawSprite(tileSprite(tile.id), destination, tileSpriteOptions(tile.id, x, y))) {
                DrawRectangle(
                    x * kTilePixels,
                    y * kTilePixels,
                    kTilePixels,
                    kTilePixels,
                    toColor(def.color));
                drawTileDetail(tile.id, x, y);
            }
            drawResourceRichnessPips(tile, x, y);
        }
    }

    const float playerDrawX = state.renderPlayerReady ? state.renderPlayerX : static_cast<float>(player.x);
    const float playerDrawY = state.renderPlayerReady ? state.renderPlayerY : static_cast<float>(player.y);
    const Rectangle playerDestination{
        (playerDrawX * static_cast<float>(kTilePixels)) + 3.0f,
        (playerDrawY * static_cast<float>(kTilePixels)) + 3.0f,
        static_cast<float>(kTilePixels - 6),
        static_cast<float>(kTilePixels - 6),
    };
    if (!drawSprite(SpriteId::Player, playerDestination)) {
        DrawRectangle(
            static_cast<int>((playerDrawX * static_cast<float>(kTilePixels)) + 4.0f),
            static_cast<int>((playerDrawY * static_cast<float>(kTilePixels)) + 4.0f),
            kTilePixels - 8,
            kTilePixels - 8,
            Color{235, 238, 230, 255});
    }
    drawDirectionArrow(
        Vector2{
            (playerDrawX * static_cast<float>(kTilePixels)) + (static_cast<float>(kTilePixels) * 0.5f),
            (playerDrawY * static_cast<float>(kTilePixels)) + (static_cast<float>(kTilePixels) * 0.5f)},
        player.facing,
        13.0f,
        Color{32, 42, 42, 255});

    for (const auto& network : sim.powerNetworks()) {
        const Color wire = network.powered ? Color{118, 210, 255, 126} : Color{245, 92, 92, 126};
        for (const auto poleId : network.poleIds) {
            const auto* pole = machineById(sim, poleId);
            if (pole == nullptr) {
                continue;
            }
            const int px = pole->x * kTilePixels + (kTilePixels / 2);
            const int py = pole->y * kTilePixels + (kTilePixels / 2);
            for (const auto otherPoleId : network.poleIds) {
                if (otherPoleId <= poleId) {
                    continue;
                }
                const auto* other = machineById(sim, otherPoleId);
                if (other == nullptr) {
                    continue;
                }
                const int distance = std::abs(pole->x - other->x) + std::abs(pole->y - other->y);
                if (distance <= 4) {
                    DrawLineEx(
                        Vector2{static_cast<float>(px), static_cast<float>(py)},
                        Vector2{
                            static_cast<float>(other->x * kTilePixels + (kTilePixels / 2)),
                            static_cast<float>(other->y * kTilePixels + (kTilePixels / 2))},
                        2.0f,
                        wire);
                }
            }
            for (const auto generatorId : network.generatorIds) {
                const auto* generator = machineById(sim, generatorId);
                if (generator != nullptr) {
                    DrawLine(px, py, generator->x * kTilePixels + (kTilePixels / 2), generator->y * kTilePixels + (kTilePixels / 2), wire);
                }
            }
            for (const auto consumerId : network.consumerIds) {
                const auto* consumer = machineById(sim, consumerId);
                if (consumer != nullptr) {
                    DrawLine(px, py, consumer->x * kTilePixels + (kTilePixels / 2), consumer->y * kTilePixels + (kTilePixels / 2), wire);
                }
            }
        }
    }

    for (const auto& machine : sim.machines()) {
        drawMachine(machine, sim.tick());
    }

    const int tx = player.x + thoth::game::dx(player.facing);
    const int ty = player.y + thoth::game::dy(player.facing);
    const auto targetTile = sim.world().getTile(tx, ty);
    const bool buildTarget = selectedBuildToolActive(sim);
    if (thoth::game::isMineable(targetTile.id) || buildTarget) {
        const Color targetColor = thoth::game::isMineable(targetTile.id) ? Color{246, 220, 118, 190} : Color{255, 255, 255, 96};
        DrawRectangleLines(tx * kTilePixels + 1, ty * kTilePixels + 1, kTilePixels - 2, kTilePixels - 2, targetColor);
    }

    if (state.feedbackTicks > 0) {
        DrawRectangle(
            tx * kTilePixels,
            ty * kTilePixels,
            kTilePixels,
            kTilePixels,
            Color{state.feedbackColor.r, state.feedbackColor.g, state.feedbackColor.b, 82});
    }

    drawBuildGridOverlay(sim);
    drawPlacementPreview(sim, state.buildDirection);
}

void appendWrapped(std::vector<std::string>& lines, const std::string& text, std::size_t width)
{
    std::string current;
    std::string word;
    for (std::size_t i = 0; i <= text.size(); ++i) {
        const char c = i < text.size() ? text[i] : ' ';
        if (c != ' ') {
            word += c;
            continue;
        }
        if (word.empty()) {
            continue;
        }
        if (!current.empty() && current.size() + 1 + word.size() > width) {
            lines.push_back(current);
            current.clear();
        }
        if (!current.empty()) {
            current += ' ';
        }
        current += word;
        word.clear();
    }
    if (!current.empty()) {
        lines.push_back(current);
    }
}

void drawPanel(int x, int y, int width, const std::string& title, const std::vector<std::string>& lines)
{
    const int lineHeight = 17;
    const int height = 36 + static_cast<int>(lines.size()) * lineHeight;
    DrawRectangle(x, y, width, height, Color{18, 22, 24, 218});
    DrawRectangleLines(x, y, width, height, Color{96, 111, 118, 190});
    DrawText(title.c_str(), x + 10, y + 8, 16, Color{232, 238, 232, 255});
    for (int i = 0; i < static_cast<int>(lines.size()); ++i) {
        DrawText(lines[static_cast<std::size_t>(i)].c_str(), x + 10, y + 30 + i * lineHeight, 14, RAYWHITE);
    }
}

void drawCraftMenu(const thoth::game::Simulation& sim, const AppState& state)
{
    if (!state.craftMenuOpen) {
        DrawRectangle(12, kScreenHeight - 92, 64, 20, Color{18, 22, 24, 178});
        DrawRectangleLines(12, kScreenHeight - 92, 64, 20, Color{96, 111, 118, 150});
        DrawText("Q build", 20, kScreenHeight - 88, 12, Color{206, 220, 214, 235});
        return;
    }

    const int rows = craftMenuRowCount();
    const int height = 42 + rows * kCraftCardHeight + std::max(0, rows - 1) * kCraftCardGap + 10;
    const Rectangle panel{
        static_cast<float>(kCraftMenuX),
        static_cast<float>(kCraftMenuY),
        static_cast<float>(kCraftMenuWidth),
        static_cast<float>(height)};
    DrawRectangleRec(panel, Color{18, 22, 24, 226});
    DrawRectangleLinesEx(panel, 1.0f, Color{96, 111, 118, 190});
    DrawText("Build Menu", kCraftMenuX + 10, kCraftMenuY + 8, 16, Color{232, 238, 232, 255});
    DrawText("Q hide   [ ] select   Z craft selected   click card to craft", kCraftMenuX + 112, kCraftMenuY + 10, 13, Color{178, 194, 190, 255});

    const auto mouse = GetMousePosition();
    const auto& entries = craftMenuEntries();
    for (int i = 0; i < static_cast<int>(entries.size()); ++i) {
        const auto* recipe = thoth::game::recipeDef(entries[static_cast<std::size_t>(i)].recipeKey);
        if (recipe == nullptr) {
            continue;
        }

        const Rectangle card = craftCardRect(i);
        const bool selected = i == state.craftSelection;
        const bool hovered = CheckCollisionPointRec(mouse, card);
        const bool unlocked = sim.isRecipeUnlocked(recipe->key);
        const bool ready = canCraftRecipe(sim, recipe->key);
        const Color fill = selected ? Color{52, 72, 72, 242} :
            hovered ? Color{35, 45, 46, 238} :
            Color{24, 29, 31, 232};
        const Color border = ready ? Color{104, 224, 142, 255} :
            unlocked ? Color{216, 178, 72, 255} :
            Color{108, 116, 120, 220};

        DrawRectangleRec(card, fill);
        DrawRectangleLinesEx(card, selected ? 2.0f : 1.0f, border);
        drawItemIcon(static_cast<int>(card.x) + 20, static_cast<int>(card.y) + 19, recipe->output.item, 11);

        const auto name = shortItemName(recipe->output.item);
        DrawText(name.c_str(), static_cast<int>(card.x) + 38, static_cast<int>(card.y) + 6, 13, RAYWHITE);
        const std::string count = "x" + std::to_string(recipe->output.count);
        DrawText(count.c_str(), static_cast<int>(card.x) + static_cast<int>(card.width) - 32, static_cast<int>(card.y) + 6, 12, Color{206, 220, 214, 255});
        DrawText(std::string(entries[static_cast<std::size_t>(i)].hotkey).c_str(), static_cast<int>(card.x) + 8, static_cast<int>(card.y) + 4, 10, Color{170, 184, 184, 255});

        const std::string detail = unlocked ?
            std::string(ready ? "ready " : "need ") + recipeCostText(sim, *recipe) :
            "locked by research";
        drawFittedText(
            detail,
            static_cast<int>(card.x) + 38,
            static_cast<int>(card.y) + 22,
            static_cast<int>(card.width) - 48,
            10,
            unlocked ? Color{188, 200, 196, 255} : Color{136, 144, 146, 255});
        if (ready) {
            DrawCircle(static_cast<int>(card.x + card.width) - 12, static_cast<int>(card.y + card.height) - 11, 3.0f, Color{104, 224, 142, 255});
        }
    }
}

void drawMachineButton(
    const MachinePanelButton& button,
    const thoth::game::Simulation& sim,
    const thoth::game::Machine& machine)
{
    const auto mouse = GetMousePosition();
    const bool hovered = CheckCollisionPointRec(mouse, button.rect);
    const Color fill = button.deposit ? Color{28, 44, 37, 235} : Color{30, 38, 50, 235};
    const Color border = button.deposit ? Color{104, 224, 142, 230} : Color{122, 184, 244, 230};
    DrawRectangleRec(button.rect, hovered ? Color{46, 58, 58, 244} : fill);
    DrawRectangleLinesEx(button.rect, hovered ? 2.0f : 1.0f, border);
    DrawText(button.deposit ? "+" : "-", static_cast<int>(button.rect.x) + 5, static_cast<int>(button.rect.y) + 4, 12, Color{206, 220, 214, 255});
    drawFittedText(
        shortItemName(button.item),
        static_cast<int>(button.rect.x) + 16,
        static_cast<int>(button.rect.y) + 5,
        static_cast<int>(button.rect.width) - 22,
        10,
        RAYWHITE);
    drawItemIcon(static_cast<int>(button.rect.x) + 14, static_cast<int>(button.rect.y) + 22, button.item, 7);

    const int count = button.deposit ? sim.itemCount(button.item) : machineAvailableCountForPanel(machine, button.item);
    if (count > 0) {
        const auto text = std::to_string(count);
        DrawText(text.c_str(), static_cast<int>(button.rect.x + button.rect.width) - MeasureText(text.c_str(), 10) - 4, static_cast<int>(button.rect.y) + 17, 10, Color{206, 220, 214, 255});
    }
}

void drawRecipeButton(const RecipePanelButton& button, const thoth::game::Machine& machine)
{
    const auto* recipe = thoth::game::recipeDef(button.recipeKey);
    if (recipe == nullptr) {
        return;
    }

    const auto mouse = GetMousePosition();
    const bool hovered = CheckCollisionPointRec(mouse, button.rect);
    const std::string active =
        machine.kind == thoth::game::MachineKind::Assembler ?
        (machine.recipeKey.empty() ? "science_pack" : machine.recipeKey) :
        machine.recipeKey;
    const bool selected = active == button.recipeKey;
    DrawRectangleRec(button.rect, selected ? Color{45, 66, 58, 242} : hovered ? Color{42, 50, 52, 238} : Color{24, 29, 31, 232});
    DrawRectangleLinesEx(button.rect, selected ? 2.0f : 1.0f, selected ? Color{130, 232, 182, 255} : Color{96, 111, 118, 190});
    drawItemIcon(static_cast<int>(button.rect.x) + 13, static_cast<int>(button.rect.y) + 12, recipe->output.item, 8);
    DrawText(shortItemName(recipe->output.item).c_str(), static_cast<int>(button.rect.x) + 28, static_cast<int>(button.rect.y) + 5, 11, RAYWHITE);
    drawFittedText(
        recipeMachineCostText(machine.inventory, *recipe),
        static_cast<int>(button.rect.x) + 8,
        static_cast<int>(button.rect.y) + 20,
        static_cast<int>(button.rect.width) - 14,
        9,
        selected ? Color{190, 232, 210, 255} : Color{160, 174, 170, 255});
}

void drawConfigButton(const MachineConfigButton& button, const thoth::game::Machine& machine)
{
    const auto mouse = GetMousePosition();
    const bool hovered = CheckCollisionPointRec(mouse, button.rect);
    const bool selected =
        (button.action == MachineConfigAction::Circuit &&
            machine.filterItem == button.item &&
            machine.circuitComparator == button.comparator &&
            machine.circuitThreshold == button.threshold) ||
        (button.action == MachineConfigAction::Request &&
            machine.requestItem == button.item &&
            machine.requestThreshold == button.threshold);
    DrawRectangleRec(button.rect, selected ? Color{45, 66, 58, 242} : hovered ? Color{42, 50, 52, 238} : Color{24, 29, 31, 232});
    DrawRectangleLinesEx(button.rect, selected ? 2.0f : 1.0f, selected ? Color{130, 232, 182, 255} : Color{96, 111, 118, 190});
    if (button.item != thoth::game::ItemId::None) {
        drawItemIcon(static_cast<int>(button.rect.x) + 12, static_cast<int>(button.rect.y) + 18, button.item, 8);
        drawFittedText(
            std::string(button.label),
            static_cast<int>(button.rect.x) + 24,
            static_cast<int>(button.rect.y) + 13,
            static_cast<int>(button.rect.width) - 28,
            10,
            RAYWHITE);
    } else {
        drawFittedText(
            std::string(button.label),
            static_cast<int>(button.rect.x) + 8,
            static_cast<int>(button.rect.y) + 13,
            static_cast<int>(button.rect.width) - 14,
            10,
            RAYWHITE);
    }
}

std::string transferAmountLabel(int amount)
{
    return amount == 0 ? "all" : std::to_string(amount) + "x";
}

void drawTransferAmountButton(const TransferAmountButton& button, const AppState& state)
{
    const auto mouse = GetMousePosition();
    const bool hovered = CheckCollisionPointRec(mouse, button.rect);
    const bool selected = state.machineTransferAmount == button.amount;
    DrawRectangleRec(
        button.rect,
        selected ? Color{52, 72, 72, 242} :
        hovered ? Color{42, 50, 52, 238} :
        Color{24, 29, 31, 232});
    DrawRectangleLinesEx(
        button.rect,
        selected ? 2.0f : 1.0f,
        selected ? Color{130, 232, 182, 255} : Color{96, 111, 118, 190});

    const auto label = transferAmountLabel(button.amount);
    DrawText(
        label.c_str(),
        static_cast<int>(button.rect.x + (button.rect.width - MeasureText(label.c_str(), 10)) / 2),
        static_cast<int>(button.rect.y) + 5,
        10,
        RAYWHITE);
}

struct FlowStack {
    thoth::game::ItemId item = thoth::game::ItemId::None;
    int available = 0;
    int required = 0;
};

void drawFlowSlot(const FlowStack& stack, int x, int y, bool output)
{
    const Rectangle slot{
        static_cast<float>(x),
        static_cast<float>(y),
        40.0f,
        30.0f};
    const bool ready = stack.required <= 0 || stack.available >= stack.required;
    const Color border = output ? Color{122, 184, 244, 230} :
        ready ? Color{130, 232, 182, 230} : Color{238, 180, 74, 230};

    DrawRectangleRec(slot, Color{24, 29, 31, 232});
    DrawRectangleLinesEx(slot, 1.0f, border);
    drawItemIcon(x + 13, y + 15, stack.item, 8);

    std::string count;
    if (stack.required > 0) {
        count = std::to_string(stack.available) + "/" + std::to_string(stack.required);
    } else if (stack.available > 0) {
        count = "x" + std::to_string(stack.available);
    }

    if (!count.empty()) {
        DrawText(count.c_str(), x + 19, y + 20, 8, Color{206, 220, 214, 255});
    }
}

void drawFlowArrow(int x, int y, Color color)
{
    DrawLineEx(
        Vector2{static_cast<float>(x), static_cast<float>(y)},
        Vector2{static_cast<float>(x + 16), static_cast<float>(y)},
        1.5f,
        color);
    DrawTriangle(
        Vector2{static_cast<float>(x + 18), static_cast<float>(y)},
        Vector2{static_cast<float>(x + 12), static_cast<float>(y - 4)},
        Vector2{static_cast<float>(x + 12), static_cast<float>(y + 4)},
        color);
}

thoth::game::ItemId resourceOutputItem(thoth::game::TileId tile)
{
    if (!isResourceTile(tile)) {
        return thoth::game::ItemId::None;
    }
    return thoth::game::tileDef(tile).drop;
}

std::vector<FlowStack> recipeInputFlow(const thoth::game::Machine& machine, const thoth::game::RecipeDef& recipe)
{
    std::vector<FlowStack> inputs;
    for (const auto& input : recipe.inputs) {
        inputs.push_back(FlowStack{input.item, machine.inventory.count(input.item), input.count});
    }
    return inputs;
}

void drawFlowStacks(const std::vector<FlowStack>& stacks, int x, int y, int maxSlots, bool output)
{
    const int count = std::min(static_cast<int>(stacks.size()), maxSlots);
    for (int i = 0; i < count; ++i) {
        drawFlowSlot(stacks[static_cast<std::size_t>(i)], x + (i * 44), y, output);
    }
}

void drawMachineFlowStrip(const thoth::game::Simulation& sim, const thoth::game::Machine& machine)
{
    using thoth::game::ItemId;
    using thoth::game::MachineKind;

    const int x = kMachinePanelX + 10;
    const int y = kMachinePanelY + 84;
    const int width = kMachinePanelWidth - 20;
    const Rectangle strip{
        static_cast<float>(x),
        static_cast<float>(y),
        static_cast<float>(width),
        34.0f};

    DrawRectangleRec(strip, Color{13, 17, 18, 198});
    DrawRectangleLinesEx(strip, 1.0f, Color{64, 78, 82, 180});
    DrawText("flow", x + 8, y + 11, 10, Color{150, 166, 162, 255});

    std::vector<FlowStack> inputs;
    std::vector<FlowStack> outputs;
    std::string detail;

    switch (machine.kind) {
    case MachineKind::Belt:
    case MachineKind::FastBelt:
    case MachineKind::Splitter:
    case MachineKind::Pipe:
        outputs.push_back(FlowStack{machine.carriedItem, machine.carriedItem == ItemId::None ? 0 : 1, 0});
        detail = outputTargetText(sim, machine);
        break;
    case MachineKind::Inserter:
    case MachineKind::CircuitInserter:
        outputs.push_back(FlowStack{machine.carriedItem, machine.carriedItem == ItemId::None ? 0 : 1, 0});
        detail = targetNameAt(
            sim,
            machine.x - thoth::game::dx(machine.direction),
            machine.y - thoth::game::dy(machine.direction)) +
            " -> " +
            targetNameAt(
                sim,
                machine.x + thoth::game::dx(machine.direction),
                machine.y + thoth::game::dy(machine.direction));
        break;
    case MachineKind::BurnerMiner:
    case MachineKind::ElectricMiner: {
        const auto tile = sim.world().getTile(machine.x, machine.y);
        if (machine.kind == MachineKind::BurnerMiner) {
            inputs.push_back(FlowStack{ItemId::Coal, machine.inventory.count(ItemId::Coal), 1});
        }
        outputs.push_back(FlowStack{resourceOutputItem(tile.id), std::max(0, tile.data), 0});
        detail = outputTargetText(sim, machine);
        break;
    }
    case MachineKind::Furnace:
        if (const auto* recipe = panelFurnaceRecipe(machine)) {
            inputs = recipeInputFlow(machine, *recipe);
            outputs.push_back(FlowStack{machine.outputItem == ItemId::None ? recipe->output.item : machine.outputItem,
                machine.outputItem == ItemId::None ? 0 : recipe->output.count,
                0});
        } else {
            inputs.push_back(FlowStack{ItemId::IronOre, machine.inventory.count(ItemId::IronOre), 1});
            inputs.push_back(FlowStack{ItemId::CopperOre, machine.inventory.count(ItemId::CopperOre), 1});
            inputs.push_back(FlowStack{ItemId::Coal, machine.inventory.count(ItemId::Coal), 1});
            detail = "needs ore + coal";
        }
        break;
    case MachineKind::Assembler:
        if (const auto* recipe = thoth::game::recipeDef(machine.recipeKey.empty() ? "science_pack" : machine.recipeKey)) {
            inputs = recipeInputFlow(machine, *recipe);
            outputs.push_back(FlowStack{machine.outputItem == ItemId::None ? recipe->output.item : machine.outputItem,
                machine.outputItem == ItemId::None ? 0 : recipe->output.count,
                0});
        }
        break;
    case MachineKind::Lab:
        inputs.push_back(FlowStack{ItemId::SciencePack, machine.inventory.count(ItemId::SciencePack), 1});
        inputs.push_back(FlowStack{ItemId::AdvancedSciencePack, machine.inventory.count(ItemId::AdvancedSciencePack), 1});
        detail = "research " + std::to_string(sim.researchProgress()) + "/" + std::to_string(sim.researchGoal());
        break;
    case MachineKind::Generator:
        inputs.push_back(FlowStack{ItemId::Coal, machine.inventory.count(ItemId::Coal), 1});
        detail = powerNetworkDetail(sim, machine);
        break;
    case MachineKind::Chest:
    case MachineKind::ProviderChest:
    case MachineKind::RequesterChest: {
        for (const auto& stack : machine.inventory.stacks()) {
            outputs.push_back(FlowStack{stack.item, stack.count, 0});
        }
        detail = outputs.empty() ? "empty storage" : "storage";
        break;
    }
    case MachineKind::LogisticPort:
        inputs.push_back(FlowStack{ItemId::LogisticDrone, machine.inventory.count(ItemId::LogisticDrone), 1});
        detail = "jobs " + std::to_string(static_cast<int>(sim.logisticJobs().size()));
        break;
    case MachineKind::ArchiveTerminal:
        inputs.push_back(FlowStack{ItemId::BeaconCore, machine.inventory.count(ItemId::BeaconCore), 1});
        detail = "charge " + std::to_string(machine.progress) + "/360";
        break;
    case MachineKind::TrainStop:
        for (const auto& stack : machine.inventory.stacks()) {
            outputs.push_back(FlowStack{stack.item, stack.count, 0});
        }
        detail = "train queue";
        break;
    case MachineKind::OffshorePump:
        outputs.push_back(FlowStack{ItemId::WaterBarrel, machine.status == thoth::game::MachineStatus::Working ? 1 : 0, 0});
        detail = outputTargetText(sim, machine);
        break;
    case MachineKind::RiftGate:
        inputs.push_back(FlowStack{ItemId::BeaconCore, machine.inventory.count(ItemId::BeaconCore), 1});
        detail = "jump " + std::to_string(machine.progress) + "/180";
        break;
    case MachineKind::Workbench:
        detail = "hand crafting helper";
        break;
    case MachineKind::PowerPole:
        detail = powerNetworkDetail(sim, machine);
        break;
    }

    const int inputX = x + 44;
    const int outputX = x + 218;
    drawFlowStacks(inputs, inputX, y + 2, 3, false);
    drawFlowArrow(x + 180, y + 17, statusColor(machine.status));
    drawFlowStacks(outputs, outputX, y + 2, 3, true);

    if (!detail.empty()) {
        drawFittedText(detail, x + 44, y + 24, width - 54, 8, Color{150, 166, 162, 255});
    }
}

void drawMachinePanel(const thoth::game::Simulation& sim, const AppState& state)
{
    const auto* machine = facedMachine(sim);
    if (machine == nullptr) {
        return;
    }

    const Rectangle panel{
        static_cast<float>(kMachinePanelX),
        static_cast<float>(kMachinePanelY),
        static_cast<float>(kMachinePanelWidth),
        282.0f};
    DrawRectangleRec(panel, Color{18, 22, 24, 226});
    DrawRectangleLinesEx(panel, 1.0f, Color{96, 111, 118, 190});
    DrawText("Machine", kMachinePanelX + 10, kMachinePanelY + 8, 16, Color{232, 238, 232, 255});

    const Color stateColor = statusColor(machine->status);
    DrawCircle(kMachinePanelX + kMachinePanelWidth - 18, kMachinePanelY + 17, 5.0f, stateColor);
    const auto name = std::string(thoth::game::toString(machine->kind));
    DrawText(name.c_str(), kMachinePanelX + 10, kMachinePanelY + 36, 15, RAYWHITE);
    drawFittedText(
        "id " + std::to_string(machine->id) + "  dir " + directionText(machine->direction),
        kMachinePanelX + 150,
        kMachinePanelY + 39,
        kMachinePanelWidth - 178,
        11,
        Color{160, 174, 170, 255});

    constexpr int chipWidth = 109;
    constexpr int chipGap = 6;
    const int chipY = kMachinePanelY + 58;
    drawChip(
        kMachinePanelX + 10,
        chipY,
        chipWidth,
        "state",
        std::string(thoth::game::toString(machine->status)),
        stateColor);
    drawChip(
        kMachinePanelX + 10 + chipWidth + chipGap,
        chipY,
        chipWidth,
        "process",
        machineProcessChipText(sim, *machine),
        Color{122, 184, 244, 255});
    drawChip(
        kMachinePanelX + 10 + (chipWidth + chipGap) * 2,
        chipY,
        chipWidth,
        "action",
        machineActionChipText(sim, *machine),
        machine->status == thoth::game::MachineStatus::Idle ? Color{184, 194, 188, 255} : stateColor);

    drawMachineFlowStrip(sim, *machine);
    drawFittedText(
        machineHintText(sim, *machine),
        kMachinePanelX + 10,
        kMachinePanelY + 122,
        kMachinePanelWidth - 20,
        12,
        Color{206, 220, 214, 255});

    const auto buttons = machinePanelButtons(sim);
    const auto hasDeposit = std::any_of(buttons.begin(), buttons.end(), [](const MachinePanelButton& button) {
        return button.deposit;
    });
    const auto hasWithdraw = std::any_of(buttons.begin(), buttons.end(), [](const MachinePanelButton& button) {
        return !button.deposit;
    });

    DrawText("deposit", kMachinePanelX + 10, kMachinePanelY + 134, 12, Color{160, 174, 170, 255});
    if (!hasDeposit) {
        DrawText("no valid item", kMachinePanelX + 82, kMachinePanelY + 134, 12, Color{112, 122, 122, 255});
    }
    DrawText("amount", kMachinePanelX + 204, kMachinePanelY + 134, 10, Color{150, 166, 162, 255});
    for (const auto& button : transferAmountButtons()) {
        drawTransferAmountButton(button, state);
    }
    DrawText("take", kMachinePanelX + 10, kMachinePanelY + 182, 12, Color{160, 174, 170, 255});
    if (!hasWithdraw) {
        DrawText("nothing available", kMachinePanelX + 82, kMachinePanelY + 182, 12, Color{112, 122, 122, 255});
    }

    for (const auto& button : buttons) {
        drawMachineButton(button, sim, *machine);
    }
    const auto recipeButtons = machineRecipeButtons(sim);
    if (machine->kind == thoth::game::MachineKind::Assembler ||
        machine->kind == thoth::game::MachineKind::Furnace) {
        DrawText("recipe", kMachinePanelX + 10, kMachinePanelY + 230, 12, Color{160, 174, 170, 255});
        if (recipeButtons.empty()) {
            DrawText("no unlocked machine recipe", kMachinePanelX + 82, kMachinePanelY + 230, 12, Color{112, 122, 122, 255});
        }
    }
    for (const auto& button : recipeButtons) {
        drawRecipeButton(button, *machine);
    }
    const auto configButtons = machineConfigButtons(sim);
    if (machine->kind == thoth::game::MachineKind::CircuitInserter ||
        machine->kind == thoth::game::MachineKind::RequesterChest) {
        DrawText("config", kMachinePanelX + 10, kMachinePanelY + 230, 12, Color{160, 174, 170, 255});
    }
    for (const auto& button : configButtons) {
        drawConfigButton(button, *machine);
    }
}

std::string inventoryRoleLabel(thoth::game::ItemId item)
{
    if (item == thoth::game::ItemId::SciencePack) {
        return "tech";
    }
    const auto& def = thoth::game::itemDef(item);
    if (def.canPlaceMachine) {
        return "build";
    }
    if (def.canPlaceTile) {
        return "tile";
    }
    return "mat";
}

Color inventoryRoleColor(thoth::game::ItemId item)
{
    if (item == thoth::game::ItemId::SciencePack) {
        return Color{118, 210, 255, 255};
    }
    const auto& def = thoth::game::itemDef(item);
    if (def.canPlaceMachine) {
        return Color{232, 196, 72, 255};
    }
    if (def.canPlaceTile) {
        return Color{132, 122, 100, 255};
    }
    return Color{130, 232, 182, 255};
}

void drawInventoryButton(const InventoryButton& button, const thoth::game::Simulation& sim)
{
    const auto mouse = GetMousePosition();
    const bool hovered = CheckCollisionPointRec(mouse, button.rect);
    const auto& player = sim.player();

    if (button.hotbar) {
        const int index = button.hotbarIndex;
        const bool selected = index == player.selectedHotbar;
        const auto item = player.hotbar[static_cast<std::size_t>(index)];
        DrawRectangleRec(button.rect, selected ? Color{72, 91, 88, 242} : hovered ? Color{42, 50, 52, 238} : Color{24, 29, 31, 232});
        DrawRectangleLinesEx(button.rect, selected ? 2.0f : 1.0f, selected ? Color{130, 232, 182, 255} : Color{96, 111, 118, 190});
        const auto number = std::to_string((index + 1) % 10);
        DrawText(number.c_str(), static_cast<int>(button.rect.x) + 5, static_cast<int>(button.rect.y) + 4, 10, Color{170, 184, 184, 255});
        DrawText(shortItemName(item).c_str(), static_cast<int>(button.rect.x) + 20, static_cast<int>(button.rect.y) + 4, 10, RAYWHITE);
        return;
    }

    const bool assigned = player.hotbar[static_cast<std::size_t>(player.selectedHotbar)] == button.item;
    DrawRectangleRec(button.rect, assigned ? Color{45, 66, 58, 242} : hovered ? Color{42, 50, 52, 238} : Color{24, 29, 31, 232});
    const Color roleColor = inventoryRoleColor(button.item);
    DrawRectangleLinesEx(button.rect, assigned ? 2.0f : 1.0f, assigned ? Color{130, 232, 182, 255} : roleColor);
    DrawRectangle(
        static_cast<int>(button.rect.x),
        static_cast<int>(button.rect.y),
        static_cast<int>(button.rect.width),
        3,
        roleColor);
    DrawText(inventoryRoleLabel(button.item).c_str(), static_cast<int>(button.rect.x) + 5, static_cast<int>(button.rect.y) + 5, 8, Color{170, 184, 184, 255});
    drawItemIcon(static_cast<int>(button.rect.x) + 28, static_cast<int>(button.rect.y) + 22, button.item, 13);
    DrawText(shortItemName(button.item).c_str(), static_cast<int>(button.rect.x) + 6, static_cast<int>(button.rect.y) + 38, 10, RAYWHITE);

    const auto count = std::to_string(sim.itemCount(button.item));
    DrawText(count.c_str(), static_cast<int>(button.rect.x + button.rect.width) - MeasureText(count.c_str(), 11) - 5, static_cast<int>(button.rect.y) + 5, 11, Color{206, 220, 214, 255});
}

void drawInventoryPanel(const thoth::game::Simulation& sim, const AppState& state)
{
    if (!state.inventoryOpen) {
        return;
    }

    const Rectangle panel{
        static_cast<float>(kInventoryPanelX),
        static_cast<float>(kInventoryPanelY),
        static_cast<float>(kInventoryPanelWidth),
        298.0f};
    DrawRectangleRec(panel, Color{18, 22, 24, 232});
    DrawRectangleLinesEx(panel, 1.0f, Color{96, 111, 118, 190});
    DrawText("Inventory", kInventoryPanelX + 10, kInventoryPanelY + 8, 16, Color{232, 238, 232, 255});
    const std::string selected = "slot " + std::to_string(sim.player().selectedHotbar + 1) +
        "  " + std::string(thoth::game::toString(sim.selectedItem())) +
        " x" + std::to_string(sim.itemCount(sim.selectedItem()));
    DrawText(selected.c_str(), kInventoryPanelX + 120, kInventoryPanelY + 11, 12, Color{188, 200, 196, 255});

    DrawText("Hotbar", kInventoryPanelX + 12, kInventoryPanelY + 31, 12, Color{160, 174, 170, 255});
    for (const auto& button : inventoryHotbarButtons()) {
        drawInventoryButton(button, sim);
    }

    DrawText("Items", kInventoryPanelX + 12, kInventoryPanelY + 78, 12, Color{160, 174, 170, 255});
    const auto buttons = inventoryButtons(sim);
    if (buttons.empty()) {
        DrawText("empty", kInventoryPanelX + 64, kInventoryPanelY + 78, 12, Color{112, 122, 122, 255});
    }
    for (const auto& button : buttons) {
        drawInventoryButton(button, sim);
    }
}

void drawHotbar(const thoth::game::Simulation& sim)
{
    const auto& player = sim.player();
    constexpr int slotWidth = 116;
    constexpr int slotHeight = 46;
    constexpr int gap = 5;
    const int totalWidth = thoth::game::kHotbarSlots * slotWidth + (thoth::game::kHotbarSlots - 1) * gap;
    const int startX = (kScreenWidth - totalWidth) / 2;
    const int y = kScreenHeight - slotHeight - 12;

    for (int i = 0; i < thoth::game::kHotbarSlots; ++i) {
        const auto item = player.hotbar[static_cast<std::size_t>(i)];
        const bool selected = i == player.selectedHotbar;
        const int x = startX + i * (slotWidth + gap);
        DrawRectangle(x, y, slotWidth, slotHeight, selected ? Color{72, 91, 88, 238} : Color{22, 27, 29, 228});
        DrawRectangleLines(x, y, slotWidth, slotHeight, selected ? Color{130, 232, 182, 255} : Color{86, 100, 104, 210});
        const std::string number = std::to_string((i + 1) % 10);
        DrawText(number.c_str(), x + 8, y + 6, 13, Color{170, 184, 184, 255});
        drawItemIcon(x + 24, y + 28, item, 10);
        DrawText(shortItemName(item).c_str(), x + 42, y + 22, 13, RAYWHITE);
        if (item != thoth::game::ItemId::None) {
            const auto count = std::to_string(sim.itemCount(item));
            DrawText(count.c_str(), x + slotWidth - MeasureText(count.c_str(), 12) - 8, y + 7, 12, Color{206, 220, 214, 255});
        }
    }
}

void drawHud(const thoth::game::Simulation& sim, const AppState& state)
{
    drawInventoryPanel(sim, state);

    drawCraftMenu(sim, state);

    if (state.debug) {
        const auto& player = sim.player();
        std::vector<std::string> objective;
        appendWrapped(objective, objectiveText(sim), 48);
        appendWrapped(objective, sim.milestoneText(), 48);
        appendWrapped(objective, tutorialNextStepText(sim), 48);
        objective.push_back("status: " + state.status);
        if (!state.feedbackText.empty() && state.feedbackTicks > 0) {
            objective.push_back("feedback: " + state.feedbackText);
        }
        const auto checklist = firstLineChecklist(sim);
        objective.insert(objective.end(), checklist.begin(), checklist.end());
        const auto science = scienceChecklist(sim);
        objective.insert(objective.end(), science.begin(), science.end());
        const auto power = powerChecklist(sim);
        objective.insert(objective.end(), power.begin(), power.end());
        objective.push_back("sim: " + std::string(state.paused ? "paused" : "running") + "  debug: on");
        drawPanel(12, 12, 430, "Objective", objective);

        std::vector<std::string> inspector;
        appendWrapped(inspector, facedMachineText(sim), 46);
        appendWrapped(inspector, factoryStatsText(sim), 46);
        appendWrapped(inspector, statusStatsText(sim), 46);
        appendWrapped(inspector, machineIssueSummaryText(sim), 46);
        appendWrapped(inspector, powerStatsText(sim), 46);
        inspector.push_back("tick " + std::to_string(sim.tick()) +
            "  chunks " + std::to_string(sim.world().loadedChunkCount()) +
            "  pos " + std::to_string(player.x) + "," + std::to_string(player.y));
        inspector.push_back("debug: Tab overlay  Backspace pause  Enter step");
        inspector.push_back("assets: F6 export atlas  atlas " +
            std::string(gVisualAtlas == nullptr ? "none" : gVisualAtlas->source));
        inspector.push_back("audio: " + state.audioSource +
            "  F11 " + std::string(audioCueName(state.audioAuditionIndex)));
        inspector.push_back("demo: F7 science  F8 replay line  F10 full flow  save/load: F5/F9");
        inspector.push_back("tick cost last " + std::to_string(static_cast<int>(std::lround(state.lastTickUs))) +
            "us avg " + std::to_string(static_cast<int>(std::lround(state.averageTickUs))) +
            "us steps " + std::to_string(state.simStepsLastFrame));
        inspector.push_back("issue cue cd " + std::to_string(state.machineIssueCueCooldown) +
            " fuel " + std::to_string(state.lastFuelIssues) +
            " power " + std::to_string(state.lastPowerIssues) +
            " blocked " + std::to_string(state.lastBlockedIssues));
        inspector.push_back("research " + std::string(sim.activeTech()) + " " +
            std::to_string(sim.researchProgress()) + "/" + std::to_string(sim.researchGoal()));
        drawPanel(846, 12, 422, "Machine / Debug", inspector);

        std::vector<std::string> help;
        appendWrapped(help, "WASD/Arrows move and face. Space mines the target. P places selected item. E deposits into the faced machine.", 40);
        appendWrapped(help, "Q opens the build menu. [ ] selects recipes. Z crafts selected. R rotates build output.", 40);
        appendWrapped(help, "V opens inventory. Hold Left Shift to fast-forward. Number keys select hotbar slots.", 40);
        appendWrapped(help, "F5/F9 save/load. F7/F8/F10 replay demos. F6 exports atlas. F11 auditions audio.", 40);
        drawPanel(462, 12, 364, "Controls", help);
    }

    if (state.inventoryOpen || state.debug) {
        drawMachinePanel(sim, state);
    }

    drawHotbar(sim);

    const int flash = std::clamp(state.feedbackTicks * 7, 0, 120);
    if (flash > 0) {
        DrawRectangle(0, 0, kScreenWidth, kScreenHeight, Color{state.feedbackColor.r, state.feedbackColor.g, state.feedbackColor.b, static_cast<unsigned char>(flash)});
    }
}

bool saveWindowSmokeScreenshot(const std::filesystem::path& path, std::string* error)
{
    const auto replayPath = findBundledPath(kFullFlowReplayPath);
    if (!replayPath.has_value()) {
        if (error != nullptr) {
            *error = "full-flow replay not found: " + kFullFlowReplayPath.generic_string();
        }
        return false;
    }

    std::string localError;
    auto document = thoth::game::loadReplayDocument(*replayPath, &localError);
    if (!document.has_value()) {
        if (error != nullptr) {
            *error = "failed to load full-flow replay: " + localError;
        }
        return false;
    }
    auto simulation = thoth::game::runReplayDocument(*document);
    if (!validateFullFlowReplay(simulation, *document, &localError)) {
        if (error != nullptr) {
            *error = "full-flow replay failed validation: " + localError;
        }
        return false;
    }

    if (path.has_parent_path()) {
        std::error_code ec;
        std::filesystem::create_directories(path.parent_path(), ec);
        if (ec) {
            if (error != nullptr) {
                *error = "failed to create window smoke directory: " + ec.message();
            }
            return false;
        }
    }

    InitWindow(kScreenWidth, kScreenHeight, "Thoth - window smoke");
    if (!IsWindowReady()) {
        CloseWindow();
        if (error != nullptr) {
            *error = "failed to initialize raylib window for smoke screenshot";
        }
        return false;
    }
    SetTargetFPS(60);

    AppState state;
    state.status = "window smoke: full-flow replay";
    state.debug = false;
    state.craftMenuOpen = false;
    state.inventoryOpen = false;
    auto visuals = loadVisualAtlas();
    gVisualAtlas = &visuals;
    auto audio = loadAudioBank();
    state.audioSource = audio.source;
    syncProductionCounters(simulation, state);
    syncMachineIssueCounters(simulation, state);
    updatePlayerVisual(simulation, state);

    Camera2D camera{};
    camera.offset = Vector2{kScreenWidth * 0.5f, kScreenHeight * 0.5f};
    camera.target = Vector2{
        (state.renderPlayerX * static_cast<float>(kTilePixels)) + (static_cast<float>(kTilePixels) * 0.5f),
        (state.renderPlayerY * static_cast<float>(kTilePixels)) + (static_cast<float>(kTilePixels) * 0.5f)};
    camera.zoom = 1.0f;

    bool saved = false;
    for (int frame = 0; frame < 3; ++frame) {
        BeginDrawing();
        ClearBackground(Color{16, 18, 18, 255});
        BeginMode2D(camera);
        drawWorld(simulation, state);
        EndMode2D();
        drawHud(simulation, state);
        EndDrawing();
    }

    std::string saveError;
    Image screenshot = LoadImageFromScreen();
    if (screenshot.data == nullptr || screenshot.width <= 0 || screenshot.height <= 0) {
        saveError = "failed to capture window smoke screenshot";
    } else if (screenshot.width != kScreenWidth || screenshot.height != kScreenHeight) {
        saveError = "window smoke screenshot size mismatch: expected " + std::to_string(kScreenWidth) + "x" + std::to_string(kScreenHeight) +
            ", got " + std::to_string(screenshot.width) + "x" + std::to_string(screenshot.height);
    } else {
        saved = ExportImage(screenshot, path.string().c_str());
        if (!saved) {
            saveError = "failed to save window smoke screenshot";
        }
    }
    if (screenshot.data != nullptr) {
        UnloadImage(screenshot);
    }

    gVisualAtlas = nullptr;
    unloadVisualAtlas(visuals);
    unloadAudioBank(audio);
    CloseWindow();

    if (!saved && error != nullptr) {
        *error = saveError.empty() ? "failed to save window smoke screenshot" : saveError;
    }
    return saved;
}

} // namespace

int main(int argc, char** argv)
{
    const int commandLineExit = runCommandLineMode(argc, argv);
    if (commandLineExit >= 0) {
        return commandLineExit;
    }

    InitWindow(kScreenWidth, kScreenHeight, "Thoth - C++ raylib automation sandbox");
    SetTargetFPS(60);

    thoth::game::Simulation sim(1337);
    AppState state;
    auto visuals = loadVisualAtlas();
    gVisualAtlas = &visuals;
    auto audio = loadAudioBank();
    state.audioSource = audio.source;
    syncProductionCounters(sim, state);
    syncMachineIssueCounters(sim, state);
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
