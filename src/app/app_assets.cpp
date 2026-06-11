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
    case ItemId::MarshHeart:
    case ItemId::GlassHeart:
    case ItemId::WardenCore:
    case ItemId::FrostCore:
    case ItemId::RiftCrown:
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
    case ItemId::GuardTower:
    case ItemId::OutpostBeacon:
    case ItemId::RepairPylon:
    case ItemId::PressureRelay:
    case ItemId::ArcTower:
        return SpriteId::MachinePowerPole;
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
    case MachineKind::GuardTower:
    case MachineKind::OutpostBeacon:
    case MachineKind::RepairPylon:
    case MachineKind::PressureRelay:
    case MachineKind::ArcTower:
        return SpriteId::MachinePowerPole;
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

bool drawSprite(SpriteId id, Rectangle destination, Color tint)
{
    return drawSprite(id, destination, SpriteDrawOptions{false, false, tint});
}

bool drawSpriteCentered(SpriteId id, int centerX, int centerY, int size, Color tint)
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
    case MachineKind::GuardTower:
        return Color{106, 170, 118, 255};
    case MachineKind::OutpostBeacon:
        return Color{112, 190, 204, 255};
    case MachineKind::RepairPylon:
        return Color{132, 204, 142, 255};
    case MachineKind::PressureRelay:
        return Color{168, 126, 220, 255};
    case MachineKind::ArcTower:
        return Color{132, 226, 255, 255};
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
    case ItemId::MarshHeart:
        return Color{214, 100, 144, 255};
    case ItemId::GlassHeart:
        return Color{238, 190, 86, 255};
    case ItemId::WardenCore:
        return Color{188, 126, 84, 255};
    case ItemId::FrostCore:
        return Color{132, 226, 255, 255};
    case ItemId::RiftCrown:
        return Color{204, 126, 255, 255};
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
    case ItemId::GuardTower:
        return Color{106, 170, 118, 255};
    case ItemId::OutpostBeacon:
        return Color{112, 190, 204, 255};
    case ItemId::RepairPylon:
        return Color{132, 204, 142, 255};
    case ItemId::PressureRelay:
        return Color{168, 126, 220, 255};
    case ItemId::ArcTower:
        return Color{132, 226, 255, 255};
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

} // namespace thoth::app
