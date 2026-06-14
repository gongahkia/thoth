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
    case ItemId::Scrap:
        return "scrap";
    case ItemId::MarshHeart:
        return "m-heart";
    case ItemId::GlassHeart:
        return "g-heart";
    case ItemId::WardenCore:
        return "w-core";
    case ItemId::FrostCore:
        return "f-core";
    case ItemId::RiftCrown:
        return "crown";
    case ItemId::ArchiveFragment:
        return "frag";
    case ItemId::MarshFragment:
        return "m-frag";
    case ItemId::DesertFragment:
        return "d-frag";
    case ItemId::BadlandsFragment:
        return "b-frag";
    case ItemId::FrostFragment:
        return "f-frag";
    case ItemId::CrystalFragment:
        return "c-frag";
    case ItemId::RiftFragment:
        return "r-frag";
    case ItemId::PowerShard:
        return "power";
    case ItemId::StoneShot:
        return "shot";
    case ItemId::CopperCoil:
        return "coil";
    case ItemId::CrystalCharge:
        return "charge";
    case ItemId::FrostCell:
        return "cell";
    case ItemId::RiftShell:
        return "shell";
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
    case ItemId::GuardTower:
        return "tower";
    case ItemId::OutpostBeacon:
        return "beacon";
    case ItemId::RepairPylon:
        return "repair";
    case ItemId::PressureRelay:
        return "relay";
    case ItemId::ArcTower:
        return "arc";
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
    case ItemId::LairHearth:
        return "hearth";
    case ItemId::RecoveryCrate:
        return "crate";
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
    case MachineKind::GuardTower:
        return "D";
    case MachineKind::OutpostBeacon:
        return "Q";
    case MachineKind::RepairPylon:
        return "J";
    case MachineKind::PressureRelay:
        return "V";
    case MachineKind::ArcTower:
        return "X";
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
    case MachineKind::GuardTower:
        denominator = 45;
        break;
    case MachineKind::OutpostBeacon:
        denominator = 80;
        break;
    case MachineKind::RepairPylon:
        denominator = 60;
        break;
    case MachineKind::PressureRelay:
        denominator = 120;
        break;
    case MachineKind::ArcTower:
        denominator = 30;
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
    default:
        break;
    }
}

thoth::game::TileId tileIdInDrawBounds(
    const thoth::game::World& world,
    thoth::game::TileId fallback,
    int x,
    int y,
    int z,
    int minX,
    int maxX,
    int minY,
    int maxY)
{
    if (x < minX || x > maxX || y < minY || y > maxY) {
        return fallback;
    }
    return world.getTile(x, y, z).id;
}

TileVariantEdges tileVariantEdgesAt(
    const thoth::game::World& world,
    thoth::game::TileId center,
    int x,
    int y,
    int z,
    int minX,
    int maxX,
    int minY,
    int maxY)
{
    return tileVariantEdges(
        center,
        tileIdInDrawBounds(world, center, x, y - 1, z, minX, maxX, minY, maxY),
        tileIdInDrawBounds(world, center, x + 1, y, z, minX, maxX, minY, maxY),
        tileIdInDrawBounds(world, center, x, y + 1, z, minX, maxX, minY, maxY),
        tileIdInDrawBounds(world, center, x - 1, y, z, minX, maxX, minY, maxY),
        tileIdInDrawBounds(world, center, x - 1, y - 1, z, minX, maxX, minY, maxY),
        tileIdInDrawBounds(world, center, x + 1, y - 1, z, minX, maxX, minY, maxY),
        tileIdInDrawBounds(world, center, x + 1, y + 1, z, minX, maxX, minY, maxY),
        tileIdInDrawBounds(world, center, x - 1, y + 1, z, minX, maxX, minY, maxY));
}

void drawTileVariantEdges(thoth::game::TileId id, const TileVariantEdges& edges, int x, int y)
{
    if (!hasTileVariantEdges(edges)) {
        return;
    }

    const int px = x * kTilePixels;
    const int py = y * kTilePixels;
    constexpr int edge = 3;
    constexpr int corner = 6;
    const Color edgeColor = tileVariantEdgeColor(id);
    const Color cornerColor = tileVariantCornerColor(id);

    if (edges.north) {
        DrawRectangle(px, py, kTilePixels, edge, edgeColor);
    }
    if (edges.east) {
        DrawRectangle(px + kTilePixels - edge, py, edge, kTilePixels, edgeColor);
    }
    if (edges.south) {
        DrawRectangle(px, py + kTilePixels - edge, kTilePixels, edge, edgeColor);
    }
    if (edges.west) {
        DrawRectangle(px, py, edge, kTilePixels, edgeColor);
    }

    if (edges.northWest) {
        DrawRectangle(px, py, corner, corner, cornerColor);
    }
    if (edges.northEast) {
        DrawRectangle(px + kTilePixels - corner, py, corner, corner, cornerColor);
    }
    if (edges.southEast) {
        DrawRectangle(px + kTilePixels - corner, py + kTilePixels - corner, corner, corner, cornerColor);
    }
    if (edges.southWest) {
        DrawRectangle(px, py + kTilePixels - corner, corner, corner, cornerColor);
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
        player.y + thoth::game::dy(player.facing),
        player.z);
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

std::string achievementTitle(const thoth::game::Simulation& sim, thoth::game::AchievementId id)
{
    for (const auto& progress : sim.achievementProgress()) {
        if (progress.id == id) {
            return progress.title;
        }
    }
    return "Achievement";
}

void syncAchievementCounters(const thoth::game::Simulation& sim, AppState& state)
{
    state.lastAchievementUnlockCount = sim.unlockedAchievementCount();
}

void updateAchievementFeedback(const thoth::game::Simulation& sim, AppState& state, const AudioBank& audio)
{
    const int unlocked = sim.unlockedAchievementCount();
    if (state.lastAchievementUnlockCount < 0) {
        syncAchievementCounters(sim, state);
        return;
    }
    if (unlocked <= state.lastAchievementUnlockCount) {
        state.lastAchievementUnlockCount = unlocked;
        return;
    }

    std::string title = "Achievement";
    const auto& achievements = sim.unlockedAchievements();
    if (!achievements.empty()) {
        title = achievementTitle(sim, achievements.back());
    }
    setFeedback(state, "achievement: " + title, Color{255, 218, 92, 220});
    playCue(audio, audio.produce);
    state.lastAchievementUnlockCount = unlocked;
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

std::vector<std::string> supplyContractChecklist(const thoth::game::Simulation& sim)
{
    const auto& totals = sim.productionTotals();
    return {
        "contracts: " + std::to_string(sim.completedSupplyContracts()) + "/" +
            std::to_string(sim.totalSupplyContracts()),
        checklistMark(totals.ironPlates >= 3) + "3 iron plates",
        checklistMark(totals.copperPlates >= 3) + "3 copper plates",
        checklistMark(totals.sciencePacks >= 2) + "2 science packs",
        checklistMark(totals.poweredOre >= 5) + "5 powered ore",
        checklistMark(totals.logisticDeliveries >= 3) + "3 logistic deliveries",
        checklistMark(totals.advancedSciencePacks >= 1) + "advanced science",
        checklistMark(totals.archiveSignals >= 1) + "archive signal",
        checklistMark(totals.riftJumps >= 1) + "rift jump",
    };
}

std::vector<std::string> biomeContractChecklist(const thoth::game::Simulation& sim)
{
    const auto progress = sim.biomeContractProgress();
    std::vector<std::string> lines;
    lines.reserve(progress.size() + 1);
    lines.push_back("biomes: " + std::to_string(sim.completedBiomeContracts()) + "/" +
        std::to_string(progress.size()));
    for (const auto& contract : progress) {
        lines.push_back(checklistMark(contract.complete) + contract.label);
    }
    return lines;
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
        {"guard_tower", ""},
        {"salvage_iron_plate", ""},
        {"salvage_copper_plate", ""},
    };
    return entries;
}

bool isRelicItemForPanel(thoth::game::ItemId item)
{
    using thoth::game::ItemId;
    return item == ItemId::MarshHeart ||
        item == ItemId::GlassHeart ||
        item == ItemId::WardenCore ||
        item == ItemId::FrostCore ||
        item == ItemId::RiftCrown;
}

bool canSocketRelicForPanel(const thoth::game::Machine& machine, thoth::game::ItemId item)
{
    if (machine.socketedRelic != thoth::game::ItemId::None || !isRelicItemForPanel(item)) {
        return false;
    }
    using thoth::game::ItemId;
    using thoth::game::MachineKind;
    switch (machine.kind) {
    case MachineKind::RepairPylon:
        return item == ItemId::MarshHeart;
    case MachineKind::PressureRelay:
        return item == ItemId::GlassHeart;
    case MachineKind::GuardTower:
        return item == ItemId::WardenCore;
    case MachineKind::ArcTower:
        return item == ItemId::FrostCore || item == ItemId::WardenCore;
    case MachineKind::RiftGate:
    case MachineKind::OutpostBeacon:
        return item == ItemId::RiftCrown;
    case MachineKind::Belt:
    case MachineKind::FastBelt:
    case MachineKind::Inserter:
    case MachineKind::CircuitInserter:
    case MachineKind::Chest:
    case MachineKind::ProviderChest:
    case MachineKind::RequesterChest:
    case MachineKind::Splitter:
    case MachineKind::BurnerMiner:
    case MachineKind::Furnace:
    case MachineKind::Workbench:
    case MachineKind::Assembler:
    case MachineKind::Lab:
    case MachineKind::Generator:
    case MachineKind::PowerPole:
    case MachineKind::ElectricMiner:
    case MachineKind::LogisticPort:
    case MachineKind::TrainStop:
    case MachineKind::Pipe:
    case MachineKind::OffshorePump:
    case MachineKind::ArchiveTerminal:
        return false;
    }
    return false;
}

bool machineCanAcceptForPanel(const thoth::game::Machine& machine, thoth::game::ItemId item)
{
    if (item == thoth::game::ItemId::None) {
        return false;
    }
    if (canSocketRelicForPanel(machine, item)) {
        return true;
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
    case MachineKind::OutpostBeacon:
        return item == ItemId::WaterBarrel ||
            item == ItemId::SandGlass ||
            item == ItemId::Basalt ||
            item == ItemId::IceShard ||
            item == ItemId::Crystal ||
            item == ItemId::BeaconCore ||
            item == ItemId::Stone;
    case MachineKind::RepairPylon:
        return item == ItemId::Wall || item == ItemId::PlankWall;
    case MachineKind::PressureRelay:
        return item == ItemId::AdvancedSciencePack;
    case MachineKind::Inserter:
    case MachineKind::CircuitInserter:
    case MachineKind::Workbench:
    case MachineKind::PowerPole:
    case MachineKind::ElectricMiner:
    case MachineKind::OffshorePump:
    case MachineKind::GuardTower:
    case MachineKind::ArcTower:
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
    addUnique(machine.socketedRelic);
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
            "scout " + std::to_string(machine.progress) + "/120 " +
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
        return "rift charge " + std::to_string(machine.progress) + "/" +
            std::to_string(machine.socketedRelic == ItemId::RiftCrown ? 120 : 180) + " " +
            powerNetworkDetail(sim, machine);
    case MachineKind::GuardTower:
        if (machine.status == MachineStatus::MissingPower) {
            return powerNetworkDetail(sim, machine);
        }
        return "defense charge " + std::to_string(machine.progress) + "/" +
            std::to_string(machine.socketedRelic == ItemId::WardenCore ? 35 : 45) + " " +
            powerNetworkDetail(sim, machine);
    case MachineKind::OutpostBeacon:
        if (machine.status == MachineStatus::MissingPower) {
            return powerNetworkDetail(sim, machine);
        }
        if (machine.status == MachineStatus::MissingInput) {
            return "deposit local biome activation item";
        }
        if (machine.progress >= 80) {
            return "outpost delivery " + std::to_string(machine.progress - 80) + "/" +
                std::to_string(machine.socketedRelic == ItemId::RiftCrown ? 70 : 100) + " delivered " +
                std::to_string(sim.productionTotals().outpostDeliveries) + " " +
                powerNetworkDetail(sim, machine);
        }
        return "outpost charge " + std::to_string(machine.progress) + "/80 activated " +
            std::to_string(sim.productionTotals().outpostsActivated) + " " +
            powerNetworkDetail(sim, machine);
    case MachineKind::RepairPylon:
        if (machine.status == MachineStatus::MissingPower) {
            return powerNetworkDetail(sim, machine);
        }
        if (machine.status == MachineStatus::MissingInput) {
            return "deposit walls for adjacent repairs";
        }
        return "repair charge " + std::to_string(machine.progress) + "/" +
            std::to_string(machine.socketedRelic == ItemId::MarshHeart ? 40 : 60) + " " +
            powerNetworkDetail(sim, machine);
    case MachineKind::PressureRelay:
        if (machine.status == MachineStatus::MissingPower) {
            return powerNetworkDetail(sim, machine);
        }
        if (machine.status == MachineStatus::MissingInput) {
            return depositActionText(sim, ItemId::AdvancedSciencePack);
        }
        return "pressure relay " + std::to_string(machine.progress) + "/" +
            std::to_string(machine.socketedRelic == ItemId::GlassHeart ? 90 : 120) + " mitigated " +
            std::to_string(sim.productionTotals().pressureWavesRepelled) + " " +
            powerNetworkDetail(sim, machine);
    case MachineKind::ArcTower:
        if (machine.status == MachineStatus::MissingPower) {
            return powerNetworkDetail(sim, machine);
        }
        return "arc defense " + std::to_string(machine.progress) + "/" +
            std::to_string(machine.socketedRelic == ItemId::FrostCore ? 20 : 30) + " " +
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
    case MachineKind::GuardTower:
        return "guard " + std::to_string(machine.progress) + "/45";
    case MachineKind::OutpostBeacon:
        return "outpost " + std::to_string(machine.progress) + "/80";
    case MachineKind::RepairPylon:
        return "repair " + std::to_string(machine.progress) + "/60";
    case MachineKind::PressureRelay:
        return "relay " + std::to_string(machine.progress) + "/120";
    case MachineKind::ArcTower:
        return "arc " + std::to_string(machine.progress) + "/30";
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
        machine.kind == MachineKind::RiftGate ||
        machine.kind == MachineKind::GuardTower) {
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
    if (machine.socketedRelic == item) {
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
    case MachineKind::GuardTower:
    case MachineKind::OutpostBeacon:
        return false;
    case MachineKind::RepairPylon:
        return false;
    case MachineKind::PressureRelay:
    case MachineKind::ArcTower:
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
    default:
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

Color entityColor(thoth::game::EntityKind kind)
{
    using thoth::game::EntityKind;
    switch (kind) {
    case EntityKind::Deer:
        return Color{156, 104, 62, 255};
    case EntityKind::Chicken:
        return Color{236, 226, 188, 255};
    case EntityKind::Crab:
        return Color{214, 92, 74, 255};
    case EntityKind::Fish:
        return Color{84, 172, 222, 255};
    case EntityKind::Slime:
        return Color{92, 206, 112, 255};
    case EntityKind::GlassSkitter:
        return Color{238, 190, 86, 255};
    case EntityKind::SunScarab:
        return Color{228, 142, 58, 255};
    case EntityKind::Skeleton:
        return Color{212, 212, 196, 255};
    case EntityKind::CaveCrawler:
        return Color{138, 74, 168, 255};
    case EntityKind::FrostCrawler:
        return Color{138, 212, 232, 255};
    case EntityKind::NullWisp:
        return Color{176, 232, 255, 255};
    case EntityKind::DungeonSentinel:
        return Color{112, 210, 218, 255};
    case EntityKind::RiftStalker:
        return Color{172, 92, 232, 255};
    case EntityKind::MarshBroodheart:
        return Color{132, 226, 122, 255};
    case EntityKind::GlassMaw:
        return Color{255, 198, 90, 255};
    case EntityKind::BadlandsWarden:
        return Color{188, 126, 84, 255};
    case EntityKind::FrostNullifier:
        return Color{132, 226, 255, 255};
    case EntityKind::RiftSignalTyrant:
        return Color{204, 126, 255, 255};
    }
    return Color{220, 220, 220, 255};
}

void drawEntityHpBar(const thoth::game::Entity& entity, int px, int py)
{
    const int width = std::clamp(entity.hp * 2, 2, 24);
    DrawRectangle(px + 4, py + 25, 24, 3, Color{8, 10, 10, 190});
    DrawRectangle(px + 4, py + 25, width, 3, Color{236, 84, 84, 235});
}

void drawSegmentedCrawler(int px, int py, Color color, Color accent)
{
    DrawCircle(px + 9, py + 17, 5.5f, color);
    DrawCircle(px + 15, py + 14, 6.5f, color);
    DrawCircle(px + 22, py + 17, 5.5f, color);
    DrawLine(px + 7, py + 23, px + 4, py + 27, accent);
    DrawLine(px + 13, py + 22, px + 11, py + 28, accent);
    DrawLine(px + 20, py + 22, px + 22, py + 28, accent);
    DrawLine(px + 25, py + 23, px + 28, py + 27, accent);
}

void drawEntity(const thoth::game::Entity& entity)
{
    using thoth::game::EntityKind;

    const int px = entity.x * kTilePixels;
    const int py = entity.y * kTilePixels;
    const auto color = entityColor(entity.kind);
    const Color dark{22, 24, 26, 235};
    const Color shadow{0, 0, 0, 110};
    const Color light{242, 248, 238, 235};
    DrawEllipse(px + 16, py + 22, 11.0f, 5.0f, shadow);

    switch (entity.kind) {
    case EntityKind::Deer:
        DrawRectangle(px + 9, py + 13, 13, 8, color);
        DrawCircle(px + 22, py + 12, 4.0f, Color{190, 132, 78, 255});
        DrawLine(px + 11, py + 21, px + 10, py + 26, dark);
        DrawLine(px + 20, py + 21, px + 21, py + 26, dark);
        DrawLine(px + 23, py + 8, px + 20, py + 4, Color{102, 68, 42, 255});
        DrawLine(px + 25, py + 8, px + 28, py + 4, Color{102, 68, 42, 255});
        break;
    case EntityKind::Chicken:
        DrawCircle(px + 15, py + 16, 6.0f, color);
        DrawCircle(px + 20, py + 12, 3.5f, Color{248, 238, 204, 255});
        DrawTriangle(Vector2{static_cast<float>(px + 23), static_cast<float>(py + 12)}, Vector2{static_cast<float>(px + 28), static_cast<float>(py + 10)}, Vector2{static_cast<float>(px + 23), static_cast<float>(py + 15)}, Color{234, 154, 58, 255});
        DrawLine(px + 13, py + 21, px + 11, py + 25, Color{234, 154, 58, 255});
        DrawLine(px + 17, py + 21, px + 19, py + 25, Color{234, 154, 58, 255});
        break;
    case EntityKind::Crab:
        DrawEllipse(px + 16, py + 17, 8.0f, 5.0f, color);
        DrawCircle(px + 6, py + 14, 3.0f, Color{240, 122, 92, 255});
        DrawCircle(px + 26, py + 14, 3.0f, Color{240, 122, 92, 255});
        DrawLine(px + 9, py + 20, px + 4, py + 24, dark);
        DrawLine(px + 23, py + 20, px + 28, py + 24, dark);
        break;
    case EntityKind::Fish:
        DrawEllipse(px + 15, py + 16, 8.0f, 5.0f, color);
        DrawTriangle(Vector2{static_cast<float>(px + 6), static_cast<float>(py + 16)}, Vector2{static_cast<float>(px + 2), static_cast<float>(py + 11)}, Vector2{static_cast<float>(px + 2), static_cast<float>(py + 21)}, Color{54, 126, 190, 255});
        DrawCircle(px + 21, py + 14, 1.5f, dark);
        break;
    case EntityKind::Slime:
        DrawCircle(px + 16, py + 17, 9.0f, color);
        DrawEllipse(px + 16, py + 20, 11.0f, 5.0f, Color{72, 162, 88, 255});
        DrawCircle(px + 12, py + 14, 2.0f, Color{196, 255, 204, 210});
        break;
    case EntityKind::GlassSkitter:
        DrawTriangle(Vector2{static_cast<float>(px + 16), static_cast<float>(py + 5)}, Vector2{static_cast<float>(px + 26), static_cast<float>(py + 18)}, Vector2{static_cast<float>(px + 16), static_cast<float>(py + 27)}, color);
        DrawTriangle(Vector2{static_cast<float>(px + 16), static_cast<float>(py + 5)}, Vector2{static_cast<float>(px + 6), static_cast<float>(py + 18)}, Vector2{static_cast<float>(px + 16), static_cast<float>(py + 27)}, Color{255, 226, 138, 255});
        DrawLine(px + 9, py + 17, px + 3, py + 13, dark);
        DrawLine(px + 23, py + 17, px + 29, py + 13, dark);
        DrawLine(px + 9, py + 20, px + 3, py + 25, dark);
        DrawLine(px + 23, py + 20, px + 29, py + 25, dark);
        break;
    case EntityKind::SunScarab:
        DrawEllipse(px + 16, py + 16, 8.0f, 9.0f, color);
        DrawEllipse(px + 10, py + 16, 5.0f, 7.0f, Color{246, 188, 80, 210});
        DrawEllipse(px + 22, py + 16, 5.0f, 7.0f, Color{246, 188, 80, 210});
        DrawLine(px + 16, py + 7, px + 16, py + 24, dark);
        DrawCircle(px + 16, py + 12, 2.0f, Color{255, 236, 128, 255});
        break;
    case EntityKind::Skeleton:
        DrawCircle(px + 16, py + 10, 5.0f, color);
        DrawLineEx(Vector2{static_cast<float>(px + 16), static_cast<float>(py + 15)}, Vector2{static_cast<float>(px + 16), static_cast<float>(py + 24)}, 2.0f, color);
        DrawLine(px + 10, py + 17, px + 22, py + 17, color);
        DrawLine(px + 12, py + 21, px + 20, py + 21, color);
        DrawCircle(px + 14, py + 9, 1.5f, dark);
        DrawCircle(px + 18, py + 9, 1.5f, dark);
        break;
    case EntityKind::CaveCrawler:
        drawSegmentedCrawler(px, py, color, Color{72, 38, 96, 255});
        DrawCircle(px + 15, py + 12, 2.0f, Color{234, 178, 255, 255});
        break;
    case EntityKind::FrostCrawler:
        drawSegmentedCrawler(px, py, color, Color{214, 248, 255, 255});
        DrawLine(px + 16, py + 7, px + 16, py + 22, Color{236, 252, 255, 255});
        DrawLine(px + 10, py + 14, px + 22, py + 18, Color{236, 252, 255, 255});
        break;
    case EntityKind::NullWisp:
        DrawCircle(px + 16, py + 16, 9.0f, Color{176, 232, 255, 130});
        DrawCircle(px + 17, py + 14, 5.0f, color);
        DrawLine(px + 10, py + 9, px + 23, py + 22, Color{236, 252, 255, 230});
        DrawLine(px + 23, py + 9, px + 10, py + 22, Color{236, 252, 255, 230});
        break;
    case EntityKind::DungeonSentinel:
        DrawRectangle(px + 8, py + 8, 16, 16, Color{48, 86, 96, 255});
        DrawRectangleLines(px + 8, py + 8, 16, 16, color);
        DrawCircle(px + 16, py + 16, 4.0f, Color{142, 238, 246, 255});
        DrawCircle(px + 16, py + 16, 1.8f, dark);
        break;
    case EntityKind::RiftStalker:
        DrawTriangle(Vector2{static_cast<float>(px + 16), static_cast<float>(py + 4)}, Vector2{static_cast<float>(px + 27), static_cast<float>(py + 25)}, Vector2{static_cast<float>(px + 5), static_cast<float>(py + 25)}, color);
        DrawTriangle(Vector2{static_cast<float>(px + 16), static_cast<float>(py + 10)}, Vector2{static_cast<float>(px + 22), static_cast<float>(py + 23)}, Vector2{static_cast<float>(px + 10), static_cast<float>(py + 23)}, Color{38, 22, 52, 245});
        DrawCircle(px + 16, py + 17, 2.0f, Color{236, 190, 255, 255});
        break;
    case EntityKind::MarshBroodheart:
        DrawCircle(px + 12, py + 13, 7.0f, color);
        DrawCircle(px + 20, py + 13, 7.0f, color);
        DrawTriangle(Vector2{static_cast<float>(px + 6), static_cast<float>(py + 16)}, Vector2{static_cast<float>(px + 26), static_cast<float>(py + 16)}, Vector2{static_cast<float>(px + 16), static_cast<float>(py + 28)}, Color{84, 174, 84, 255});
        DrawCircle(px + 16, py + 17, 3.0f, Color{226, 255, 180, 255});
        break;
    case EntityKind::GlassMaw:
        DrawTriangle(Vector2{static_cast<float>(px + 16), static_cast<float>(py + 3)}, Vector2{static_cast<float>(px + 29), static_cast<float>(py + 17)}, Vector2{static_cast<float>(px + 16), static_cast<float>(py + 29)}, color);
        DrawTriangle(Vector2{static_cast<float>(px + 16), static_cast<float>(py + 3)}, Vector2{static_cast<float>(px + 3), static_cast<float>(py + 17)}, Vector2{static_cast<float>(px + 16), static_cast<float>(py + 29)}, Color{255, 226, 138, 255});
        DrawRectangle(px + 10, py + 15, 12, 4, dark);
        DrawLine(px + 11, py + 15, px + 13, py + 19, light);
        DrawLine(px + 20, py + 15, px + 18, py + 19, light);
        break;
    case EntityKind::BadlandsWarden:
        DrawRectangle(px + 7, py + 7, 18, 19, Color{118, 78, 56, 255});
        DrawRectangle(px + 10, py + 5, 12, 5, color);
        DrawRectangleLines(px + 7, py + 7, 18, 19, Color{226, 174, 116, 255});
        DrawRectangle(px + 13, py + 13, 6, 8, dark);
        break;
    case EntityKind::FrostNullifier:
        DrawCircle(px + 16, py + 16, 10.0f, Color{96, 174, 210, 235});
        DrawLine(px + 16, py + 4, px + 16, py + 28, light);
        DrawLine(px + 4, py + 16, px + 28, py + 16, light);
        DrawLine(px + 8, py + 8, px + 24, py + 24, light);
        DrawLine(px + 24, py + 8, px + 8, py + 24, light);
        DrawCircle(px + 16, py + 16, 4.0f, color);
        break;
    case EntityKind::RiftSignalTyrant:
        DrawCircle(px + 16, py + 17, 10.0f, Color{82, 38, 120, 245});
        DrawTriangle(Vector2{static_cast<float>(px + 7), static_cast<float>(py + 11)}, Vector2{static_cast<float>(px + 11), static_cast<float>(py + 4)}, Vector2{static_cast<float>(px + 15), static_cast<float>(py + 12)}, color);
        DrawTriangle(Vector2{static_cast<float>(px + 13), static_cast<float>(py + 10)}, Vector2{static_cast<float>(px + 16), static_cast<float>(py + 2)}, Vector2{static_cast<float>(px + 20), static_cast<float>(py + 10)}, color);
        DrawTriangle(Vector2{static_cast<float>(px + 18), static_cast<float>(py + 12)}, Vector2{static_cast<float>(px + 23), static_cast<float>(py + 4)}, Vector2{static_cast<float>(px + 26), static_cast<float>(py + 13)}, color);
        DrawCircle(px + 16, py + 17, 3.0f, Color{246, 210, 255, 255});
        DrawLine(px + 16, py + 20, px + 16, py + 28, color);
        break;
    }

    if (entity.pressureSpawn) {
        DrawRectangleLines(px + 2, py + 2, kTilePixels - 4, kTilePixels - 4, Color{255, 114, 74, 220});
        DrawCircle(px + 25, py + 7, 2.5f, Color{255, 188, 92, 235});
    }
    drawEntityHpBar(entity, px, py);
}

void drawTutorialWorldLabel(int tileX, int tileY, const std::string& text, Color color)
{
    const int x = tileX * kTilePixels;
    const int y = tileY * kTilePixels;
    const int width = MeasureText(text.c_str(), 10) + 8;
    DrawRectangle(x, y, width, 15, Color{12, 15, 16, 210});
    DrawRectangleLines(x, y, width, 15, color);
    DrawText(text.c_str(), x + 4, y + 3, 10, Color{236, 242, 236, 255});
}

void drawTutorialWorldArea(Rectangle area, Color color)
{
    DrawRectangleRec(area, Color{color.r, color.g, color.b, 34});
    DrawRectangleLinesEx(area, 2.0f, Color{color.r, color.g, color.b, 210});
}

bool shouldDrawTutorial(const thoth::game::Simulation& sim, const AppState& state)
{
    return sim.tutorialState().active || state.tutorialManualOpen;
}

void drawTutorialStartArea(const thoth::game::Simulation& sim, const AppState& state)
{
    if (!shouldDrawTutorial(sim, state) ||
        !sim.tutorialState().active ||
        sim.player().z != thoth::game::kTutorialLayer) {
        return;
    }

    drawTutorialWorldArea(Rectangle{-5.0f * kTilePixels, -4.0f * kTilePixels, 10.0f * kTilePixels, 8.0f * kTilePixels}, Color{78, 92, 98, 255});
    drawTutorialWorldArea(Rectangle{-3.0f * kTilePixels, 0.0f * kTilePixels, 1.0f * kTilePixels, 1.0f * kTilePixels}, Color{96, 214, 126, 255});
    drawTutorialWorldArea(Rectangle{-2.0f * kTilePixels, 2.0f * kTilePixels, 1.0f * kTilePixels, 1.0f * kTilePixels}, Color{166, 174, 170, 255});
    drawTutorialWorldArea(Rectangle{3.0f * kTilePixels, 0.0f * kTilePixels, 1.0f * kTilePixels, 1.0f * kTilePixels}, Color{246, 220, 118, 255});
    drawTutorialWorldArea(Rectangle{5.0f * kTilePixels, 0.0f * kTilePixels, 1.0f * kTilePixels, 1.0f * kTilePixels}, Color{122, 184, 244, 255});

    drawTutorialWorldLabel(-3, -1, "mine tree: Space", Color{96, 214, 126, 255});
    drawTutorialWorldLabel(-2, 3, "stone", Color{166, 174, 170, 255});
    drawTutorialWorldLabel(3, -1, "deposit chest: E", Color{246, 220, 118, 255});
    drawTutorialWorldLabel(5, -1, sim.tutorialExitReady() ? "exit: J" : "exit locked", Color{122, 184, 244, 255});
}

void drawWorld(thoth::game::Simulation& sim, const AppState& state)
{
    const auto& player = sim.player();
    const int halfTilesX = (kScreenWidth / kTilePixels) / 2 + 3;
    const int halfTilesY = (kScreenHeight / kTilePixels) / 2 + 3;
    const int minX = player.x - halfTilesX;
    const int maxX = player.x + halfTilesX;
    const int minY = player.y - halfTilesY;
    const int maxY = player.y + halfTilesY;

    for (int y = minY; y <= maxY; ++y) {
        for (int x = minX; x <= maxX; ++x) {
            const auto tile = sim.world().getTile(x, y, player.z);
            const auto& def = thoth::game::tileDef(tile.id);
            const auto edges = tileVariantEdgesAt(sim.world(), tile.id, x, y, player.z, minX, maxX, minY, maxY);
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
            drawTileVariantEdges(tile.id, edges, x, y);
            drawResourceRichnessPips(tile, x, y);
        }
    }

    drawTutorialStartArea(sim, state);

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
            if (pole == nullptr || pole->z != player.z) {
                continue;
            }
            const int px = pole->x * kTilePixels + (kTilePixels / 2);
            const int py = pole->y * kTilePixels + (kTilePixels / 2);
            for (const auto otherPoleId : network.poleIds) {
                if (otherPoleId <= poleId) {
                    continue;
                }
                const auto* other = machineById(sim, otherPoleId);
                if (other == nullptr || other->z != player.z) {
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
                if (generator != nullptr && generator->z == player.z) {
                    DrawLine(px, py, generator->x * kTilePixels + (kTilePixels / 2), generator->y * kTilePixels + (kTilePixels / 2), wire);
                }
            }
            for (const auto consumerId : network.consumerIds) {
                const auto* consumer = machineById(sim, consumerId);
                if (consumer != nullptr && consumer->z == player.z) {
                    DrawLine(px, py, consumer->x * kTilePixels + (kTilePixels / 2), consumer->y * kTilePixels + (kTilePixels / 2), wire);
                }
            }
        }
    }

    for (const auto& machine : sim.machines()) {
        if (machine.z != player.z) {
            continue;
        }
        drawMachine(machine, sim.tick());
    }

    for (const auto& entity : sim.entities()) {
        if (entity.z == player.z) {
            drawEntity(entity);
        }
    }

    const int tx = player.x + thoth::game::dx(player.facing);
    const int ty = player.y + thoth::game::dy(player.facing);
    const auto targetTile = sim.world().getTile(tx, ty, player.z);
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
        inputs.push_back(FlowStack{ItemId::SciencePack, machine.inventory.count(ItemId::SciencePack), 1});
        detail = "jobs " + std::to_string(static_cast<int>(sim.logisticJobs().size())) +
            " scout " + std::to_string(machine.progress) + "/120";
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
        detail = "jump " + std::to_string(machine.progress) + "/" +
            std::to_string(machine.socketedRelic == ItemId::RiftCrown ? 120 : 180);
        break;
    case MachineKind::GuardTower:
        detail = "defense " + std::to_string(machine.progress) + "/" +
            std::to_string(machine.socketedRelic == ItemId::WardenCore ? 35 : 45) + " " +
            powerNetworkDetail(sim, machine);
        break;
    case MachineKind::OutpostBeacon:
        for (const auto& stack : machine.inventory.stacks()) {
            inputs.push_back(FlowStack{stack.item, stack.count, 1});
        }
        if (machine.progress >= 80) {
            detail = "outpost delivery " + std::to_string(machine.progress - 80) + "/" +
                std::to_string(machine.socketedRelic == ItemId::RiftCrown ? 70 : 100) + " " +
                powerNetworkDetail(sim, machine);
        } else {
            detail = "outpost " + std::to_string(machine.progress) + "/80 " + powerNetworkDetail(sim, machine);
        }
        break;
    case MachineKind::RepairPylon:
        inputs.push_back(FlowStack{ItemId::Wall, machine.inventory.count(ItemId::Wall), 1});
        inputs.push_back(FlowStack{ItemId::PlankWall, machine.inventory.count(ItemId::PlankWall), 1});
        detail = "repair " + std::to_string(machine.progress) + "/" +
            std::to_string(machine.socketedRelic == ItemId::MarshHeart ? 40 : 60) + " " +
            powerNetworkDetail(sim, machine);
        break;
    case MachineKind::PressureRelay:
        inputs.push_back(FlowStack{ItemId::AdvancedSciencePack, machine.inventory.count(ItemId::AdvancedSciencePack), 1});
        detail = "pressure " + std::to_string(machine.progress) + "/" +
            std::to_string(machine.socketedRelic == ItemId::GlassHeart ? 90 : 120) + " " +
            powerNetworkDetail(sim, machine);
        break;
    case MachineKind::ArcTower:
        detail = "arc defense " + std::to_string(machine.progress) + "/" +
            std::to_string(machine.socketedRelic == ItemId::FrostCore ? 20 : 30) + " " +
            powerNetworkDetail(sim, machine);
        break;
    case MachineKind::Workbench:
        detail = "hand crafting helper";
        break;
    case MachineKind::PowerPole:
        detail = powerNetworkDetail(sim, machine);
        break;
    }
    if (machine.socketedRelic != ItemId::None) {
        detail += detail.empty() ? "socket " : " socket ";
        detail += shortItemName(machine.socketedRelic);
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

void drawTutorialPanel(const thoth::game::Simulation& sim)
{
    std::vector<std::string> lines;
    if (sim.tutorialState().active) {
        appendWrapped(lines, "Training room: complete each basic action, then face the blue exit and press J.", 46);
        for (const auto& step : sim.tutorialProgress()) {
            lines.push_back(checklistMark(step.complete) + step.label);
        }
        lines.push_back(sim.tutorialExitReady() ? "exit ready: press J at the blue stairs" : "exit locked until checklist is complete");
        appendWrapped(lines, "Move WASD. Space mines. K crafts workbench. P places selected item. E deposits.", 46);
    } else {
        appendWrapped(lines, tutorialNextStepText(sim), 46);
        appendWrapped(lines, "Move WASD. Space mines. Q opens build. P places. E deposits. F1 hides this.", 46);
        const auto checklist = firstLineChecklist(sim);
        lines.insert(lines.end(), checklist.begin(), checklist.end());
    }
    drawPanel(12, 12, 430, "Tutorial", lines);
}

void drawAchievementPanel(const thoth::game::Simulation& sim)
{
    const auto progress = sim.achievementProgress();
    std::vector<std::string> lines;
    lines.push_back("unlocked " + std::to_string(sim.unlockedAchievementCount()) + "/" +
        std::to_string(progress.size()));

    int shown = 0;
    for (const auto& achievement : progress) {
        if (achievement.unlocked) {
            continue;
        }
        lines.push_back(achievement.title + " " +
            std::to_string(std::min(achievement.current, achievement.required)) + "/" +
            std::to_string(achievement.required));
        ++shown;
        if (shown >= 3) {
            break;
        }
    }
    if (shown == 0 && !progress.empty()) {
        lines.push_back("all tracked achievements complete");
    }

    drawPanel(846, 12, 422, "Achievements", lines);
}

void drawHud(const thoth::game::Simulation& sim, const AppState& state)
{
    drawInventoryPanel(sim, state);

    drawCraftMenu(sim, state);

    if (!state.debug) {
        if (shouldDrawTutorial(sim, state)) {
            drawTutorialPanel(sim);
        }
        drawAchievementPanel(sim);
    }

    if (state.debug) {
        const auto& player = sim.player();
        std::vector<std::string> objective;
        appendWrapped(objective, sim.currentDemoGoalText(), 48);
        appendWrapped(objective, sim.objectiveMarkerText(), 48);
        appendWrapped(objective, objectiveText(sim), 48);
        appendWrapped(objective, sim.factoryDashboardText(), 48);
        appendWrapped(objective, sim.scoutAutomationText(), 48);
        appendWrapped(objective, sim.postVictoryExpeditionText(), 48);
        appendWrapped(objective, sim.currentSupplyContractText(), 48);
        appendWrapped(objective, sim.currentBiomeContractText(), 48);
        appendWrapped(objective, sim.currentOutpostDeliveryText(), 48);
        appendWrapped(objective, sim.currentBiomeHazardText(), 48);
        appendWrapped(objective, sim.currentBossExamText(), 48);
        appendWrapped(objective, sim.factoryPressureText(), 48);
        appendWrapped(objective, sim.pressureWaveAlertText(), 48);
        appendWrapped(objective, sim.pressureEventDeckText(), 48);
        appendWrapped(objective, sim.riftStormText(), 48);
        appendWrapped(objective, sim.milestoneText(), 48);
        appendWrapped(objective, tutorialNextStepText(sim), 48);
        objective.push_back("status: " + state.status);
        if (!state.feedbackText.empty() && state.feedbackTicks > 0) {
            objective.push_back("feedback: " + state.feedbackText);
        }
        const auto contracts = supplyContractChecklist(sim);
        objective.insert(objective.end(), contracts.begin(), contracts.end());
        const auto biomeContracts = biomeContractChecklist(sim);
        objective.insert(objective.end(), biomeContracts.begin(), biomeContracts.end());
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
            "  pos " + std::to_string(player.x) + "," + std::to_string(player.y) + "," + std::to_string(player.z) +
            "  hp " + std::to_string(player.hp) +
            (player.inBoat ? "  boat" : "") +
            "  entities " + std::to_string(sim.entities().size()));
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
        appendWrapped(help, "J interacts with boats, doors, and stairs. H attacks the faced creature.", 40);
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

} // namespace thoth::app
