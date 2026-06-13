#include "thoth/game/simulation.hpp"

#include "thoth/core/deterministic_random.hpp"

#include <algorithm>
#include <array>
#include <cstddef>
#include <sstream>
#include <stdexcept>
#include <utility>

namespace thoth::game {

namespace {

constexpr int kCoalFuelTicks = 120;
constexpr int kGeneratorPower = 2;
constexpr int kPowerPoleConnectionRange = 4;
constexpr int kPowerMachineReach = 2;
constexpr int kLogisticPortRange = 4;
constexpr int kMinLogisticJobTicks = 20;
constexpr int kMaxLogisticJobTicks = 240;
constexpr int kScoutDispatchTicks = 120;
constexpr int kArchiveTerminalTicks = 360;
constexpr int kTrainStopTicks = 90;
constexpr int kPumpTicks = 30;
constexpr int kPipeTicks = 3;
constexpr int kRiftGateTicks = 180;
constexpr int kRiftCrownGateTicks = 120;
constexpr int kGuardTowerTicks = 45;
constexpr int kGuardTowerRange = 5;
constexpr int kArcTowerTicks = 30;
constexpr int kArcTowerRange = 7;
constexpr int kOutpostBeaconTicks = 80;
constexpr int kOutpostDeliveryTicks = 100;
constexpr int kRepairPylonTicks = 60;
constexpr int kPressureRelayTicks = 120;
constexpr int kRiftOffset = 4096;
constexpr int kDesertHeatBaseTicks = 120;
constexpr int kBadlandsSlagBaseTicks = 90;
constexpr int kSnowfieldFreezeBaseTicks = 90;
constexpr int kMarshRotBaseTicks = 180;
constexpr int kCrystalResonanceBaseTicks = 150;
constexpr int kRiftStormBaseTicks = 120;
constexpr int kRiftStormCooldownTicks = 300;
constexpr int kRiftStormSpawnCadence = 45;
constexpr int kRiftStormJoltCadence = 60;
constexpr int kTutorialSpawnX = 0;
constexpr int kTutorialSpawnY = 0;
constexpr int kTutorialExitX = 5;
constexpr int kTutorialExitY = 0;
constexpr int kTutorialChestX = 3;
constexpr int kTutorialChestY = 0;
constexpr int kTutorialRequiredMask =
    (1 << static_cast<int>(TutorialAction::Move)) |
    (1 << static_cast<int>(TutorialAction::Mine)) |
    (1 << static_cast<int>(TutorialAction::Craft)) |
    (1 << static_cast<int>(TutorialAction::Place)) |
    (1 << static_cast<int>(TutorialAction::Deposit));

constexpr std::array<BiomeKind, 5> kRequiredOutpostBiomes{{
    BiomeKind::Marsh,
    BiomeKind::Desert,
    BiomeKind::Badlands,
    BiomeKind::Snowfield,
    BiomeKind::CrystalField,
}};

constexpr std::array<BiomeKind, 6> kScoutBiomes{{
    BiomeKind::Marsh,
    BiomeKind::Desert,
    BiomeKind::Badlands,
    BiomeKind::Snowfield,
    BiomeKind::CrystalField,
    BiomeKind::Rift,
}};

struct AchievementDef {
    AchievementId id = AchievementId::FirstIronPlate;
    std::string_view key;
    std::string_view title;
    std::string_view description;
    int required = 1;
};

constexpr std::array<AchievementDef, 10> kAchievementDefs{{
    {AchievementId::FirstIronPlate, "first_iron_plate", "First Plate", "Produce an iron plate", 1},
    {AchievementId::FirstSciencePack, "first_science_pack", "Lab Sample", "Produce a science pack", 1},
    {AchievementId::LogisticsOne, "logistics_one", "Logistics Online", "Complete Logistics 1 research", 1},
    {AchievementId::FirstCreatureDefeated, "first_creature_defeated", "Perimeter Secured", "Defeat a creature", 1},
    {AchievementId::FirstBossDefeated, "first_boss_defeated", "Lair Breaker", "Defeat a lair boss", 1},
    {AchievementId::FirstPressureReward, "first_pressure_reward", "Pressure Harvest", "Claim a pressure wave reward", 1},
    {AchievementId::FirstRiftJump, "first_rift_jump", "Through the Rift", "Open a rift jump", 1},
    {AchievementId::FirstOutpost, "first_outpost", "Signal Outpost", "Activate an outpost beacon", 1},
    {AchievementId::FirstScoutDispatch, "first_scout_dispatch", "Scout Launched", "Dispatch a logistic scout", 1},
    {AchievementId::ScoutRecovery, "scout_recovery", "Field Sample", "Recover material through scouting", 1},
}};

const AchievementDef* achievementDef(AchievementId id)
{
    const auto found = std::find_if(
        kAchievementDefs.begin(),
        kAchievementDefs.end(),
        [id](const AchievementDef& def) {
            return def.id == id;
        });
    return found == kAchievementDefs.end() ? nullptr : &*found;
}

int absInt(int value)
{
    return value < 0 ? -value : value;
}

int manhattanDistance(const Machine& left, const Machine& right)
{
    if (left.z != right.z) {
        return 1'000'000;
    }
    return absInt(left.x - right.x) + absInt(left.y - right.y);
}

int manhattanDistance(int ax, int ay, int az, int bx, int by, int bz)
{
    if (az != bz) {
        return 1'000'000;
    }
    return absInt(ax - bx) + absInt(ay - by);
}

bool containsId(const std::vector<std::uint32_t>& ids, std::uint32_t id)
{
    return std::find(ids.begin(), ids.end(), id) != ids.end();
}

bool isWaterTileId(TileId id)
{
    return id == TileId::Water || id == TileId::DeepWater || id == TileId::Coral;
}

bool isScienceItem(ItemId item)
{
    return item == ItemId::SciencePack || item == ItemId::AdvancedSciencePack;
}

Direction leftOf(Direction direction)
{
    switch (direction) {
    case Direction::North:
        return Direction::West;
    case Direction::East:
        return Direction::North;
    case Direction::South:
        return Direction::East;
    case Direction::West:
        return Direction::South;
    }
    return Direction::West;
}

Direction rightOf(Direction direction)
{
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
    return Direction::East;
}

std::uint64_t machineCellKey(int x, int y, int z)
{
    const auto ux = static_cast<std::uint64_t>(static_cast<std::uint32_t>(x));
    const auto uy = static_cast<std::uint64_t>(static_cast<std::uint32_t>(y));
    auto value = (ux << 32U) | uy;
    value ^= static_cast<std::uint64_t>(static_cast<std::uint32_t>(z)) * 0x9e3779b97f4a7c15ULL;
    return value;
}

TileId minedReplacement(TileId id)
{
    switch (id) {
    case TileId::Tree:
        return TileId::Grass;
    case TileId::Reeds:
        return TileId::Mud;
    case TileId::Cactus:
        return TileId::Sand;
    case TileId::Coral:
        return TileId::Water;
    case TileId::DeepWater:
        return TileId::Water;
    case TileId::Stone:
    case TileId::Basalt:
    case TileId::Crystal:
    case TileId::IronOre:
    case TileId::CopperOre:
    case TileId::CoalOre:
        return TileId::Floor;
    case TileId::DungeonWall:
        return TileId::DungeonFloor;
    case TileId::Wall:
    case TileId::PlankWall:
    case TileId::Door:
    case TileId::StairsUp:
    case TileId::StairsDown:
    case TileId::Bed:
        return TileId::Floor;
    case TileId::Dirt:
    case TileId::Floor:
    case TileId::Grass:
    case TileId::Beach:
    case TileId::Mud:
    case TileId::Sand:
    case TileId::Snow:
    case TileId::Ice:
    case TileId::Water:
    case TileId::DungeonFloor:
        return TileId::Grass;
    }
    return TileId::Grass;
}

ItemId resourceTileOutput(TileId id)
{
    switch (id) {
    case TileId::IronOre:
        return ItemId::IronOre;
    case TileId::CopperOre:
        return ItemId::CopperOre;
    case TileId::CoalOre:
        return ItemId::Coal;
    case TileId::Basalt:
        return ItemId::Basalt;
    case TileId::Crystal:
        return ItemId::Crystal;
    case TileId::DeepWater:
        return ItemId::Kelp;
    case TileId::Coral:
        return ItemId::CoralShard;
    case TileId::Beach:
        return ItemId::Shell;
    case TileId::Reeds:
        return ItemId::ReedFiber;
    case TileId::Cactus:
        return ItemId::CactusFiber;
    case TileId::Ice:
        return ItemId::IceShard;
    case TileId::Dirt:
    case TileId::Floor:
    case TileId::Grass:
    case TileId::Mud:
    case TileId::Sand:
    case TileId::Snow:
    case TileId::Stone:
    case TileId::Tree:
    case TileId::Water:
    case TileId::Wall:
    case TileId::PlankWall:
    case TileId::Door:
    case TileId::StairsUp:
    case TileId::StairsDown:
    case TileId::Bed:
    case TileId::DungeonFloor:
    case TileId::DungeonWall:
        return ItemId::None;
    }
    return ItemId::None;
}

ItemId outpostActivationItem(BiomeKind biome)
{
    switch (biome) {
    case BiomeKind::Marsh:
        return ItemId::WaterBarrel;
    case BiomeKind::Desert:
        return ItemId::SandGlass;
    case BiomeKind::Badlands:
        return ItemId::Basalt;
    case BiomeKind::Snowfield:
        return ItemId::IceShard;
    case BiomeKind::CrystalField:
        return ItemId::Crystal;
    case BiomeKind::Rift:
        return ItemId::BeaconCore;
    case BiomeKind::Grassland:
        return ItemId::Stone;
    }
    return ItemId::Stone;
}

bool isRepairableWallGap(TileId tile)
{
    return tile == TileId::Floor || tile == TileId::DungeonFloor || tile == TileId::Grass || tile == TileId::Dirt;
}

int biomeMask(BiomeKind biome)
{
    return 1 << static_cast<int>(biome);
}

bool hasBiomeMask(int mask, BiomeKind biome)
{
    return (mask & biomeMask(biome)) != 0;
}

int countOutpostBiomeCoverage(int mask)
{
    int count = 0;
    for (const auto biome : kRequiredOutpostBiomes) {
        if (hasBiomeMask(mask, biome)) {
            ++count;
        }
    }
    return count;
}

int biomeHazardLevel(int pressure, bool outpostStabilized)
{
    int level = 1;
    if (pressure >= 120) {
        ++level;
    }
    if (pressure >= 220) {
        ++level;
    }
    if (outpostStabilized && level > 1) {
        --level;
    }
    return level;
}

int hazardCadence(int baseTicks, int level)
{
    return std::max(30, baseTicks - ((std::max(1, level) - 1) * 30));
}

bool isOrganicHazardItem(ItemId item)
{
    return item == ItemId::ReedFiber ||
        item == ItemId::Kelp ||
        item == ItemId::CactusFiber ||
        item == ItemId::Slime ||
        item == ItemId::Hide;
}

ItemId scoutRewardForBiome(BiomeKind biome)
{
    switch (biome) {
    case BiomeKind::Marsh:
        return ItemId::ReedFiber;
    case BiomeKind::Desert:
        return ItemId::CactusFiber;
    case BiomeKind::Badlands:
        return ItemId::Basalt;
    case BiomeKind::Snowfield:
        return ItemId::IceShard;
    case BiomeKind::CrystalField:
        return ItemId::Crystal;
    case BiomeKind::Rift:
        return ItemId::Scrap;
    case BiomeKind::Grassland:
        return ItemId::Wood;
    }
    return ItemId::Wood;
}

int scoutRewardCountForBiome(BiomeKind biome)
{
    if (biome == BiomeKind::Rift || biome == BiomeKind::CrystalField) {
        return 1;
    }
    return 2;
}

std::optional<BiomeKind> scoutBiomeForReward(ItemId item)
{
    switch (item) {
    case ItemId::ReedFiber:
        return BiomeKind::Marsh;
    case ItemId::CactusFiber:
        return BiomeKind::Desert;
    case ItemId::Basalt:
        return BiomeKind::Badlands;
    case ItemId::IceShard:
        return BiomeKind::Snowfield;
    case ItemId::Crystal:
        return BiomeKind::CrystalField;
    case ItemId::Scrap:
        return BiomeKind::Rift;
    default:
        return std::nullopt;
    }
}

bool isHeatSensitiveMachine(MachineKind kind)
{
    switch (kind) {
    case MachineKind::BurnerMiner:
    case MachineKind::Furnace:
    case MachineKind::ElectricMiner:
    case MachineKind::Assembler:
    case MachineKind::Lab:
    case MachineKind::Generator:
    case MachineKind::LogisticPort:
    case MachineKind::ArchiveTerminal:
    case MachineKind::RiftGate:
    case MachineKind::OutpostBeacon:
    case MachineKind::GuardTower:
    case MachineKind::RepairPylon:
    case MachineKind::PressureRelay:
    case MachineKind::ArcTower:
        return true;
    case MachineKind::Belt:
    case MachineKind::FastBelt:
    case MachineKind::Inserter:
    case MachineKind::CircuitInserter:
    case MachineKind::Chest:
    case MachineKind::ProviderChest:
    case MachineKind::RequesterChest:
    case MachineKind::Workbench:
    case MachineKind::Splitter:
    case MachineKind::TrainStop:
    case MachineKind::Pipe:
    case MachineKind::OffshorePump:
    case MachineKind::PowerPole:
        return false;
    }
    return false;
}

bool isActiveIndustrialMachine(const Machine& machine)
{
    switch (machine.kind) {
    case MachineKind::BurnerMiner:
    case MachineKind::Furnace:
    case MachineKind::ElectricMiner:
    case MachineKind::Assembler:
    case MachineKind::Lab:
    case MachineKind::Generator:
    case MachineKind::LogisticPort:
    case MachineKind::ArchiveTerminal:
    case MachineKind::RiftGate:
    case MachineKind::OutpostBeacon:
    case MachineKind::GuardTower:
    case MachineKind::RepairPylon:
    case MachineKind::PressureRelay:
    case MachineKind::ArcTower:
        return machine.progress > 0 || machine.fuelTicks > 0 || machine.status == MachineStatus::Working;
    case MachineKind::Belt:
    case MachineKind::FastBelt:
    case MachineKind::Inserter:
    case MachineKind::CircuitInserter:
    case MachineKind::Chest:
    case MachineKind::ProviderChest:
    case MachineKind::RequesterChest:
    case MachineKind::Workbench:
    case MachineKind::Splitter:
    case MachineKind::TrainStop:
    case MachineKind::Pipe:
    case MachineKind::OffshorePump:
    case MachineKind::PowerPole:
        return false;
    }
    return false;
}

bool isRelicItem(ItemId item)
{
    return item == ItemId::MarshHeart ||
        item == ItemId::GlassHeart ||
        item == ItemId::WardenCore ||
        item == ItemId::FrostCore ||
        item == ItemId::RiftCrown;
}

bool canSocketRelic(MachineKind kind, ItemId relic)
{
    if (!isRelicItem(relic)) {
        return false;
    }
    switch (kind) {
    case MachineKind::RepairPylon:
        return relic == ItemId::MarshHeart;
    case MachineKind::PressureRelay:
        return relic == ItemId::GlassHeart;
    case MachineKind::GuardTower:
        return relic == ItemId::WardenCore;
    case MachineKind::ArcTower:
        return relic == ItemId::FrostCore || relic == ItemId::WardenCore;
    case MachineKind::RiftGate:
    case MachineKind::OutpostBeacon:
        return relic == ItemId::RiftCrown;
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

BiomeHazardState biomeHazardFor(BiomeKind biome, int level)
{
    switch (biome) {
    case BiomeKind::Marsh:
        return BiomeHazardState{
            biome,
            "Marsh rot",
            level,
            "unsealed organic inputs decay inside machines and stockpiles",
            "activate a marsh outpost or move organics through sealed routes quickly"};
    case BiomeKind::Desert:
        return BiomeHazardState{
            biome,
            "Desert heat",
            level,
            "machines consume water barrels as coolant or lose durability",
            "pipe or deliver water barrels before running desert industry"};
    case BiomeKind::Badlands:
        return BiomeHazardState{
            biome,
            "Badlands slag",
            level,
            "active industrial machines shed basalt byproduct while working",
            "route basalt into walls, contracts, or later salvage chains"};
    case BiomeKind::Snowfield:
        return BiomeHazardState{
            biome,
            "Snowfield freeze",
            level,
            "unheated machines lose progress during cold pulses",
            "keep coal or active fuel in machines before long snow runs"};
    case BiomeKind::CrystalField:
        return BiomeHazardState{
            biome,
            "Crystal resonance",
            level,
            "working machines surge forward but can attract null wisps",
            "stabilize the biome with an outpost and defend resonant builds"};
    case BiomeKind::Rift:
        return BiomeHazardState{
            biome,
            "Rift shear",
            level,
            "rift machinery operates under volatile pressure bands",
            "complete outpost coverage before committing deep rift infrastructure"};
    case BiomeKind::Grassland:
        return BiomeHazardState{
            biome,
            "Stable grassland",
            0,
            "no active biome hazard",
            "use this area for the starter factory and safe routing"};
    }
    return BiomeHazardState{biome, "Unknown", level, "no active biome hazard", "none"};
}

std::string jsonString(std::string_view text)
{
    std::string escaped;
    escaped.reserve(text.size() + 2);
    escaped.push_back('"');
    for (const char c : text) {
        switch (c) {
        case '\\':
            escaped += "\\\\";
            break;
        case '"':
            escaped += "\\\"";
            break;
        case '\n':
            escaped += "\\n";
            break;
        case '\r':
            escaped += "\\r";
            break;
        case '\t':
            escaped += "\\t";
            break;
        default:
            escaped.push_back(c);
            break;
        }
    }
    escaped.push_back('"');
    return escaped;
}

void depleteResourceTile(World& world, int x, int y, int z)
{
    auto tile = world.getTile(x, y, z);
    if (resourceTileOutput(tile.id) == ItemId::None) {
        return;
    }

    const int remaining = std::max(1, tile.data) - 1;
    if (remaining <= 0) {
        world.setTile(x, y, z, Tile{minedReplacement(tile.id), 0});
        return;
    }

    tile.data = remaining;
    world.setTile(x, y, z, tile);
}

ItemId furnaceInputItem(const RecipeDef& recipe)
{
    for (const auto& input : recipe.inputs) {
        if (input.item != ItemId::Coal) {
            return input.item;
        }
    }
    return ItemId::None;
}

const RecipeDef* furnaceRecipeForInput(ItemId item)
{
    for (const auto& recipe : recipeDefs()) {
        if (recipe.station != "furnace") {
            continue;
        }
        if (furnaceInputItem(recipe) == item) {
            return &recipe;
        }
    }
    return nullptr;
}

const RecipeDef* selectedFurnaceRecipe(const Machine& machine)
{
    if (!machine.recipeKey.empty()) {
        const auto* recipe = recipeDef(machine.recipeKey);
        if (recipe != nullptr && recipe->station == "furnace") {
            return recipe;
        }
    }

    for (const auto& recipe : recipeDefs()) {
        if (recipe.station != "furnace") {
            continue;
        }
        const auto input = furnaceInputItem(recipe);
        if (input != ItemId::None && machine.inventory.canConsume(input, 1)) {
            return &recipe;
        }
    }
    return nullptr;
}

} // namespace

Command Command::face(Direction direction)
{
    Command command;
    command.type = CommandType::Face;
    command.direction = direction;
    return command;
}

Command Command::move(Direction direction)
{
    Command command;
    command.type = CommandType::Move;
    command.direction = direction;
    return command;
}

Command Command::mine(Direction direction)
{
    Command command;
    command.type = CommandType::Mine;
    command.direction = direction;
    return command;
}

Command Command::placeItem(Direction direction, ItemId item)
{
    return placeItem(direction, item, direction);
}

Command Command::placeItem(Direction direction, ItemId item, Direction orientation)
{
    Command command;
    command.type = CommandType::Place;
    command.direction = direction;
    command.orientation = orientation;
    command.item = item;
    return command;
}

Command Command::placeTile(Direction direction, TileId tile)
{
    Command command;
    command.type = CommandType::Place;
    command.direction = direction;
    command.orientation = direction;
    command.tile = tile;
    return command;
}

Command Command::craft(std::string recipeKey)
{
    Command command;
    command.type = CommandType::Craft;
    command.recipeKey = std::move(recipeKey);
    return command;
}

Command Command::selectHotbar(int index)
{
    Command command;
    command.type = CommandType::SelectHotbar;
    command.hotbarIndex = index;
    return command;
}

Command Command::assignHotbar(int index, ItemId item)
{
    Command command;
    command.type = CommandType::AssignHotbar;
    command.hotbarIndex = index;
    command.item = item;
    return command;
}

Command Command::configureMachineRecipe(Direction direction, std::string recipeKey)
{
    Command command;
    command.type = CommandType::ConfigureMachineRecipe;
    command.direction = direction;
    command.recipeKey = std::move(recipeKey);
    return command;
}

Command Command::depositSelected(Direction direction)
{
    Command command;
    command.type = CommandType::DepositSelected;
    command.direction = direction;
    return command;
}

Command Command::depositItem(Direction direction, ItemId item)
{
    Command command;
    command.type = CommandType::DepositItem;
    command.direction = direction;
    command.item = item;
    return command;
}

Command Command::withdrawItem(Direction direction, ItemId item)
{
    Command command;
    command.type = CommandType::WithdrawItem;
    command.direction = direction;
    command.item = item;
    return command;
}

Command Command::configureCircuit(Direction direction, ItemId filterItem, CircuitComparator comparator, int threshold)
{
    Command command;
    command.type = CommandType::ConfigureCircuit;
    command.direction = direction;
    command.item = filterItem;
    command.comparator = comparator;
    command.amount = threshold;
    return command;
}

Command Command::configureRequest(Direction direction, ItemId requestItem, int threshold)
{
    Command command;
    command.type = CommandType::ConfigureRequest;
    command.direction = direction;
    command.item = requestItem;
    command.amount = threshold;
    return command;
}

Command Command::interact(Direction direction)
{
    Command command;
    command.type = CommandType::Interact;
    command.direction = direction;
    return command;
}

Command Command::attack(Direction direction)
{
    Command command;
    command.type = CommandType::Attack;
    command.direction = direction;
    return command;
}

int dx(Direction direction)
{
    switch (direction) {
    case Direction::East:
        return 1;
    case Direction::West:
        return -1;
    case Direction::North:
    case Direction::South:
        return 0;
    }
    return 0;
}

int dy(Direction direction)
{
    switch (direction) {
    case Direction::South:
        return 1;
    case Direction::North:
        return -1;
    case Direction::East:
    case Direction::West:
        return 0;
    }
    return 0;
}

std::string_view toString(MachineStatus status)
{
    switch (status) {
    case MachineStatus::Idle:
        return "idle";
    case MachineStatus::MissingInput:
        return "missing_input";
    case MachineStatus::MissingFuel:
        return "missing_fuel";
    case MachineStatus::MissingPower:
        return "missing_power";
    case MachineStatus::Working:
        return "working";
    case MachineStatus::OutputBlocked:
        return "output_blocked";
    }
    return "idle";
}

std::string_view toString(CircuitComparator comparator)
{
    switch (comparator) {
    case CircuitComparator::Always:
        return "always";
    case CircuitComparator::LessThan:
        return "less_than";
    case CircuitComparator::GreaterOrEqual:
        return "greater_or_equal";
    }
    return "always";
}

std::string_view toString(AchievementId id)
{
    switch (id) {
    case AchievementId::FirstIronPlate:
        return "first_iron_plate";
    case AchievementId::FirstSciencePack:
        return "first_science_pack";
    case AchievementId::LogisticsOne:
        return "logistics_one";
    case AchievementId::FirstCreatureDefeated:
        return "first_creature_defeated";
    case AchievementId::FirstBossDefeated:
        return "first_boss_defeated";
    case AchievementId::FirstPressureReward:
        return "first_pressure_reward";
    case AchievementId::FirstRiftJump:
        return "first_rift_jump";
    case AchievementId::FirstOutpost:
        return "first_outpost";
    case AchievementId::FirstScoutDispatch:
        return "first_scout_dispatch";
    case AchievementId::ScoutRecovery:
        return "scout_recovery";
    }
    return "first_iron_plate";
}

CircuitComparator circuitComparatorFromKey(std::string_view key)
{
    if (key == "less_than") {
        return CircuitComparator::LessThan;
    }
    if (key == "greater_or_equal") {
        return CircuitComparator::GreaterOrEqual;
    }
    return CircuitComparator::Always;
}

std::optional<AchievementId> achievementIdFromKey(std::string_view key)
{
    if (key == "first_iron_plate") {
        return AchievementId::FirstIronPlate;
    }
    if (key == "first_science_pack") {
        return AchievementId::FirstSciencePack;
    }
    if (key == "logistics_one") {
        return AchievementId::LogisticsOne;
    }
    if (key == "first_creature_defeated") {
        return AchievementId::FirstCreatureDefeated;
    }
    if (key == "first_boss_defeated") {
        return AchievementId::FirstBossDefeated;
    }
    if (key == "first_pressure_reward") {
        return AchievementId::FirstPressureReward;
    }
    if (key == "first_rift_jump") {
        return AchievementId::FirstRiftJump;
    }
    if (key == "first_outpost") {
        return AchievementId::FirstOutpost;
    }
    if (key == "first_scout_dispatch") {
        return AchievementId::FirstScoutDispatch;
    }
    if (key == "scout_recovery") {
        return AchievementId::ScoutRecovery;
    }
    return std::nullopt;
}

Simulation::Simulation(std::uint64_t seed)
    : world_(seed)
{
    const auto addedStarter = player_.inventory.add(ItemId::Stone, 10);
    (void)addedStarter;
    player_.hotbar.fill(ItemId::None);
    assignHotbar(ItemId::Stone);
}

Simulation Simulation::newGame(std::uint64_t seed, bool startInTutorial)
{
    Simulation simulation(seed);
    simulation.tutorialState_ = simulation.findRealWorldSpawn();
    if (startInTutorial) {
        simulation.beginTutorial();
    } else {
        simulation.player_.x = simulation.tutorialState_.realSpawnX;
        simulation.player_.y = simulation.tutorialState_.realSpawnY;
        simulation.player_.z = simulation.tutorialState_.realSpawnZ;
        simulation.player_.facing = Direction::South;
        simulation.tutorialState_.active = false;
        simulation.tutorialState_.completed = true;
        simulation.tutorialState_.actionMask = kTutorialRequiredMask;
    }
    return simulation;
}

void Simulation::queue(Command command)
{
    commandQueue_.push_back(command);
}

void Simulation::step()
{
    ensureLocalEntities();
    auto queue = commandQueue_;
    commandQueue_.clear();
    for (const auto& command : queue) {
        apply(command);
    }
    updateMachines();
    updateEntities();
    updateAchievements();
    ++tick_;
}

World& Simulation::world()
{
    return world_;
}

const World& Simulation::world() const
{
    return world_;
}

Player& Simulation::player()
{
    return player_;
}

const Player& Simulation::player() const
{
    return player_;
}

std::uint64_t Simulation::tick() const
{
    return tick_;
}

int Simulation::itemCount(ItemId item) const
{
    return player_.inventory.count(item);
}

ItemId Simulation::selectedItem() const
{
    if (player_.selectedHotbar < 0 || player_.selectedHotbar >= kHotbarSlots) {
        return ItemId::None;
    }
    return player_.hotbar[static_cast<std::size_t>(player_.selectedHotbar)];
}

const std::vector<Machine>& Simulation::machines() const
{
    return machines_;
}

const Machine* Simulation::machineAt(int x, int y) const
{
    return machineAt(x, y, 0);
}

const Machine* Simulation::machineAt(int x, int y, int z) const
{
    const auto found = machineCellIndex_.find(machineCellKey(x, y, z));
    if (found == machineCellIndex_.end() || found->second >= machines_.size()) {
        return nullptr;
    }
    const auto& machine = machines_[found->second];
    const auto& def = machineDef(machine.kind);
    if (x < machine.x || y < machine.y || x >= machine.x + def.width || y >= machine.y + def.height) {
        return nullptr;
    }
    return &machine;
}

Machine* Simulation::machineAt(int x, int y)
{
    return machineAt(x, y, 0);
}

Machine* Simulation::machineAt(int x, int y, int z)
{
    const auto found = machineCellIndex_.find(machineCellKey(x, y, z));
    if (found == machineCellIndex_.end() || found->second >= machines_.size()) {
        return nullptr;
    }
    auto& machine = machines_[found->second];
    const auto& def = machineDef(machine.kind);
    if (x < machine.x || y < machine.y || x >= machine.x + def.width || y >= machine.y + def.height) {
        return nullptr;
    }
    return &machine;
}

const std::vector<Entity>& Simulation::entities() const
{
    return entities_;
}

const Entity* Simulation::entityAt(int x, int y, int z) const
{
    for (const auto& entity : entities_) {
        if (entity.x == x && entity.y == y && entity.z == z && entity.hp > 0) {
            return &entity;
        }
    }
    return nullptr;
}

bool Simulation::isRecipeUnlocked(std::string_view recipeKey) const
{
    const auto* recipe = recipeDef(recipeKey);
    if (recipe == nullptr) {
        return false;
    }
    if (recipe->unlockedByDefault) {
        return true;
    }
    return std::any_of(unlockedRecipes_.begin(), unlockedRecipes_.end(), [recipeKey](const std::string& key) {
        return std::string_view(key) == recipeKey;
    });
}

bool Simulation::isTechCompleted(std::string_view techKey) const
{
    return std::any_of(completedTechs_.begin(), completedTechs_.end(), [techKey](const std::string& key) {
        return std::string_view(key) == techKey;
    });
}

std::string_view Simulation::activeTech() const
{
    return activeTech_;
}

int Simulation::researchProgress() const
{
    return researchProgress_;
}

int Simulation::researchGoal() const
{
    return activeTechGoal();
}

const std::vector<PowerNetwork>& Simulation::powerNetworks() const
{
    return powerNetworks_;
}

const std::vector<LogisticJob>& Simulation::logisticJobs() const
{
    return logisticJobs_;
}

const ProductionTotals& Simulation::productionTotals() const
{
    return productionTotals_;
}

std::vector<AchievementProgress> Simulation::achievementProgress() const
{
    std::vector<AchievementProgress> progress;
    progress.reserve(kAchievementDefs.size());
    for (const auto& def : kAchievementDefs) {
        progress.push_back(AchievementProgress{
            def.id,
            std::string(def.key),
            std::string(def.title),
            std::string(def.description),
            achievementCurrent(def.id),
            def.required,
            isAchievementUnlocked(def.id)});
    }
    return progress;
}

const std::vector<AchievementId>& Simulation::unlockedAchievements() const
{
    return unlockedAchievements_;
}

int Simulation::unlockedAchievementCount() const
{
    return static_cast<int>(unlockedAchievements_.size());
}

const TutorialState& Simulation::tutorialState() const
{
    return tutorialState_;
}

std::vector<TutorialStepProgress> Simulation::tutorialProgress() const
{
    return {
        TutorialStepProgress{TutorialAction::Move, "Move with WASD", (tutorialState_.actionMask & (1 << static_cast<int>(TutorialAction::Move))) != 0},
        TutorialStepProgress{TutorialAction::Mine, "Mine a resource with Space", (tutorialState_.actionMask & (1 << static_cast<int>(TutorialAction::Mine))) != 0},
        TutorialStepProgress{TutorialAction::Craft, "Craft a workbench with K or the build card", (tutorialState_.actionMask & (1 << static_cast<int>(TutorialAction::Craft))) != 0},
        TutorialStepProgress{TutorialAction::Place, "Place a machine or tile with P", (tutorialState_.actionMask & (1 << static_cast<int>(TutorialAction::Place))) != 0},
        TutorialStepProgress{TutorialAction::Deposit, "Deposit an item into the chest with E", (tutorialState_.actionMask & (1 << static_cast<int>(TutorialAction::Deposit))) != 0},
    };
}

bool Simulation::tutorialExitReady() const
{
    return (tutorialState_.actionMask & kTutorialRequiredMask) == kTutorialRequiredMask;
}

std::array<int, 3> Simulation::realWorldSpawn() const
{
    return {tutorialState_.realSpawnX, tutorialState_.realSpawnY, tutorialState_.realSpawnZ};
}

bool Simulation::canCraft(std::string_view recipeKey) const
{
    const auto* recipe = recipeDef(recipeKey);
    return recipe != nullptr &&
        isRecipeUnlocked(recipeKey) &&
        canCraftAtCurrentStation(*recipe) &&
        player_.inventory.canConsumeAll(recipe->inputs);
}

int Simulation::completedSupplyContracts() const
{
    int completed = 0;
    if (productionTotals_.ironPlates >= 3) {
        ++completed;
    }
    if (productionTotals_.copperPlates >= 3) {
        ++completed;
    }
    if (productionTotals_.sciencePacks >= 2) {
        ++completed;
    }
    if (productionTotals_.poweredOre >= 5) {
        ++completed;
    }
    if (productionTotals_.logisticDeliveries >= 3) {
        ++completed;
    }
    if (productionTotals_.advancedSciencePacks >= 1) {
        ++completed;
    }
    if (productionTotals_.archiveSignals >= 1) {
        ++completed;
    }
    if (productionTotals_.riftJumps >= 1) {
        ++completed;
    }
    return completed;
}

int Simulation::totalSupplyContracts() const
{
    return 8;
}

std::string Simulation::currentSupplyContractText() const
{
    const auto progressText = [this](std::string_view label, int current, int required) {
        return "contract " + std::to_string(completedSupplyContracts() + 1) + "/" +
            std::to_string(totalSupplyContracts()) + ": " + std::string(label) + " (" +
            std::to_string(std::min(current, required)) + "/" + std::to_string(required) + ")";
    };

    if (productionTotals_.ironPlates < 3) {
        return progressText("store 3 iron plates", productionTotals_.ironPlates, 3);
    }
    if (productionTotals_.copperPlates < 3) {
        return progressText("store 3 copper plates", productionTotals_.copperPlates, 3);
    }
    if (productionTotals_.sciencePacks < 2) {
        return progressText("produce 2 science packs", productionTotals_.sciencePacks, 2);
    }
    if (productionTotals_.poweredOre < 5) {
        return progressText("mine 5 powered ore", productionTotals_.poweredOre, 5);
    }
    if (productionTotals_.logisticDeliveries < 3) {
        return progressText("complete 3 logistic deliveries", productionTotals_.logisticDeliveries, 3);
    }
    if (productionTotals_.advancedSciencePacks < 1) {
        return progressText("produce advanced science", productionTotals_.advancedSciencePacks, 1);
    }
    if (productionTotals_.archiveSignals < 1) {
        return progressText("charge an archive signal", productionTotals_.archiveSignals, 1);
    }
    if (productionTotals_.riftJumps < 1) {
        return progressText("open a rift jump", productionTotals_.riftJumps, 1);
    }
    return "contract complete: supply chain proved across plates, science, logistics, archive, and rift";
}

int Simulation::factoryPressureLevel() const
{
    const int rawPressure = productionTotals_.ironPlates +
        productionTotals_.copperPlates +
        productionTotals_.sciencePacks * 12 +
        productionTotals_.advancedSciencePacks * 24 +
        productionTotals_.poweredOre / 2 +
        productionTotals_.logisticDeliveries * 8 +
        productionTotals_.archiveSignals * 50 +
        productionTotals_.riftJumps * 80;
    return std::max(0, rawPressure - (productionTotals_.pressureWavesRepelled * 35));
}

int Simulation::ticksUntilNextPressureWave() const
{
    if (productionTotals_.sciencePacks == 0 || factoryPressureLevel() < 120) {
        return -1;
    }
    if (tick_ > 0 && (tick_ % 300U) == 0U) {
        return 0;
    }
    return static_cast<int>(300U - (tick_ % 300U));
}

std::string Simulation::factoryPressureText() const
{
    const int pressure = factoryPressureLevel();
    if (pressure < 60 || productionTotals_.sciencePacks == 0) {
        return "pressure: quiet (" + std::to_string(pressure) + ")";
    }
    if (pressure < 120) {
        return "pressure: watched (" + std::to_string(pressure) + "); keep walls and exits clear";
    }
    if (pressure < 220) {
        return "pressure: raids possible (" + std::to_string(pressure) + "); clear hostiles before expanding";
    }
    return "pressure: hostile surge (" + std::to_string(pressure) + "); secure the factory perimeter";
}

std::string Simulation::pressureWaveAlertText() const
{
    const int ticks = ticksUntilNextPressureWave();
    if (ticks < 0) {
        return "wave alert: none; pressure below raid threshold";
    }
    const auto event = nextPressureEvent();
    if (ticks == 0) {
        return "wave alert: " + event.label + " incoming now";
    }
    const auto severity = factoryPressureLevel() >= 220 ? "surge" : "probe";
    const auto unit = ticks == 1 ? " tick" : " ticks";
    return "wave alert: next " + std::string(severity) + " in " + std::to_string(ticks) +
        unit + "; event " + event.label +
        "; relays repelled " + std::to_string(productionTotals_.pressureWavesRepelled);
}

PressureEventCard Simulation::nextPressureEvent() const
{
    const int ticks = ticksUntilNextPressureWave();
    if (ticks < 0) {
        return PressureEventCard{
            "none",
            "Dormant",
            0,
            0,
            "pressure is below the raid threshold",
            "keep scaling production and build defenses before the threshold"};
    }
    return pressureEventForTick(tick_ + static_cast<std::uint64_t>(ticks));
}

std::string Simulation::pressureEventDeckText() const
{
    const auto event = nextPressureEvent();
    const auto rewards = "; pressure kills " +
        std::to_string(productionTotals_.pressureEnemiesDefeated) +
        "; rewards claimed " +
        std::to_string(productionTotals_.pressureWaveRewardsClaimed);
    if (event.spawnCount <= 0) {
        return "pressure deck: dormant; " + event.effect + rewards;
    }
    return "pressure deck: " + event.label + " L" + std::to_string(event.severity) +
        " x" + std::to_string(event.spawnCount) + "; " + event.effect + "; " + event.counterplay +
        rewards;
}

const RiftStormState& Simulation::riftStorm() const
{
    return riftStorm_;
}

std::string Simulation::riftStormText() const
{
    if (riftStorm_.ticksRemaining > 0) {
        return "rift storm: active L" + std::to_string(riftStorm_.severity) +
            " for " + std::to_string(riftStorm_.ticksRemaining) +
            " ticks; gates charge faster but unanchored gates shed stalkers; socket Rift Crown or stabilize a rift outpost";
    }
    if (productionTotals_.riftJumps == 0) {
        return "rift storm: dormant; first rift jump can tear open a storm";
    }
    if (riftStorm_.cooldownTicks > 0) {
        return "rift storm: residual static for " + std::to_string(riftStorm_.cooldownTicks) +
            " ticks; use the lull to repair gates and restock defenses";
    }
    return "rift storm: charged; deep rift travel or lingering in the rift band can trigger the next storm";
}

std::vector<FactoryDashboardPanel> Simulation::factoryDashboard() const
{
    std::vector<FactoryDashboardPanel> panels;
    panels.reserve(7);
    const auto addPanel = [&panels](
                              std::string key,
                              std::string label,
                              std::string status,
                              std::string detail,
                              int current,
                              int target,
                              bool urgent) {
        panels.push_back(FactoryDashboardPanel{
            std::move(key),
            std::move(label),
            std::move(status),
            std::move(detail),
            current,
            target,
            urgent});
    };

    int poweredNetworks = 0;
    int totalPowerSupply = 0;
    int totalPowerDemand = 0;
    for (const auto& network : powerNetworks_) {
        if (network.powered) {
            ++poweredNetworks;
        }
        totalPowerSupply += network.supply;
        totalPowerDemand += network.demand;
    }
    addPanel(
        "power",
        "Power",
        totalPowerDemand == 0 ? "idle" : (totalPowerSupply >= totalPowerDemand ? "stable" : "underpowered"),
        "networks " + std::to_string(poweredNetworks) + "/" + std::to_string(powerNetworks_.size()) +
            "; supply " + std::to_string(totalPowerSupply) + "/" + std::to_string(totalPowerDemand),
        totalPowerSupply,
        totalPowerDemand,
        totalPowerDemand > totalPowerSupply);

    const int pressure = factoryPressureLevel();
    const int ticksUntilWave = ticksUntilNextPressureWave();
    const bool waveSoon = ticksUntilWave >= 0 && ticksUntilWave <= 30;
    addPanel(
        "pressure",
        "Factory Pressure",
        pressure >= 220 ? "surge" : (pressure >= 120 ? "raid-ready" : "watched"),
        ticksUntilWave < 0
            ? "below wave threshold; " + pressureEventDeckText()
            : "next wave in " + std::to_string(ticksUntilWave) + " ticks; " + pressureEventDeckText(),
        pressure,
        pressure >= 220 ? 320 : 120,
        pressure >= 220 || waveSoon);

    int hostileEntities = 0;
    int activeBosses = 0;
    for (const auto& entity : entities_) {
        if (isHostile(entity.kind)) {
            ++hostileEntities;
        }
        if (entity.kind == EntityKind::MarshBroodheart ||
            entity.kind == EntityKind::GlassMaw ||
            entity.kind == EntityKind::BadlandsWarden ||
            entity.kind == EntityKind::FrostNullifier ||
            entity.kind == EntityKind::RiftSignalTyrant) {
            ++activeBosses;
        }
    }
    addPanel(
        "defense",
        "Defense",
        activeBosses > 0 ? "boss" : (hostileEntities > 0 ? "hostiles" : "clear"),
        "hostiles " + std::to_string(hostileEntities) +
            "; bosses " + std::to_string(activeBosses) +
            "; pressure kills " + std::to_string(productionTotals_.pressureEnemiesDefeated),
        hostileEntities,
        0,
        hostileEntities > 0 || activeBosses > 0);

    int damagedMachines = 0;
    for (const auto& machine : machines_) {
        const int maxDurability = machineMaxDurability(machine.kind);
        if (machine.durability > 0 && machine.durability < maxDurability) {
            ++damagedMachines;
        }
    }
    int damagedStructureTiles = 0;
    for (const auto& tile : world_.loadedTiles()) {
        if (isDamageableStructureTile(tile.tile.id) && tile.tile.data > 0) {
            ++damagedStructureTiles;
        }
    }
    const int damagedAssets = damagedMachines + damagedStructureTiles;
    addPanel(
        "repairs",
        "Repairs",
        damagedAssets > 0 ? "damaged" : "stable",
        "machines " + std::to_string(damagedMachines) +
            "; structures " + std::to_string(damagedStructureTiles),
        damagedAssets,
        0,
        damagedAssets > 0);

    const auto bossExams = bossExamProgress();
    const int completedBossExams = static_cast<int>(std::count_if(
        bossExams.begin(),
        bossExams.end(),
        [](const BossExamProgress& exam) {
            return exam.complete;
        }));
    const int completedProgress =
        completedSupplyContracts() +
        completedBiomeContracts() +
        completedOutpostDeliveryContracts() +
        completedBossExams;
    const int totalProgress =
        totalSupplyContracts() +
        static_cast<int>(biomeContractProgress().size()) +
        static_cast<int>(outpostDeliveryProgress().size()) +
        static_cast<int>(bossExams.size());
    addPanel(
        "progression",
        "Progression",
        completedProgress >= totalProgress ? "complete" : "in-progress",
        currentSupplyContractText() + "; " + currentBossExamText(),
        completedProgress,
        totalProgress,
        false);

    const int logisticsCurrent = productionTotals_.logisticDeliveries + productionTotals_.outpostDeliveries;
    const int logisticsTarget = 3 + static_cast<int>(outpostDeliveryProgress().size());
    addPanel(
        "logistics",
        "Logistics",
        logisticJobs_.empty() ? "idle" : "moving",
        "jobs " + std::to_string(logisticJobs_.size()) +
            "; deliveries " + std::to_string(productionTotals_.logisticDeliveries) +
            "; outposts " + std::to_string(productionTotals_.outpostDeliveries),
        logisticsCurrent,
        logisticsTarget,
        false);

    addPanel(
        "exploration",
        "Exploration",
        scoutedBiomeCount() >= static_cast<int>(kScoutBiomes.size()) ? "mapped" : "scouting",
        scoutAutomationText(),
        scoutedBiomeCount(),
        static_cast<int>(kScoutBiomes.size()),
        false);

    addPanel(
        "rift",
        "Rift",
        riftStormActive() ? "storm" : (productionTotals_.riftJumps > 0 ? "open" : "locked"),
        riftStormText(),
        productionTotals_.riftJumps,
        2,
        riftStormActive());

    return panels;
}

std::string Simulation::factoryDashboardText() const
{
    const auto panels = factoryDashboard();
    const auto urgent = std::find_if(
        panels.begin(),
        panels.end(),
        [](const FactoryDashboardPanel& panel) {
            return panel.urgent;
        });
    if (urgent != panels.end()) {
        return "dashboard: urgent " + urgent->label + " (" + urgent->status + "); " + urgent->detail;
    }

    const auto incomplete = std::find_if(
        panels.begin(),
        panels.end(),
        [](const FactoryDashboardPanel& panel) {
            return panel.target > 0 && panel.current < panel.target;
        });
    if (incomplete != panels.end()) {
        return "dashboard: next " + incomplete->label + " (" + incomplete->status + "); " + incomplete->detail;
    }

    return "dashboard: all tracked systems stable";
}

std::vector<ExpeditionBoardEntry> Simulation::postVictoryExpeditionBoard() const
{
    std::vector<ExpeditionBoardEntry> entries;
    entries.reserve(9);
    const bool unlocked = mainObjectiveComplete();
    const auto addEntry = [&entries, unlocked](
                              std::string key,
                              std::string label,
                              int current,
                              int required) {
        entries.push_back(ExpeditionBoardEntry{
            std::move(key),
            std::move(label),
            current,
            required,
            unlocked,
            unlocked && current >= required});
    };

    addEntry(
        "cartography",
        "Map every biome with automated scout dispatches",
        scoutedBiomeCount(),
        static_cast<int>(kScoutBiomes.size()));
    addEntry(
        "relic_set",
        "Claim the full five-relic boss set",
        productionTotals_.bossRelicsClaimed,
        5);
    addEntry(
        "storm_veteran",
        "Survive three rift storms after opening the gate",
        productionTotals_.riftStormsSurvived,
        3);
    addEntry(
        "outpost_network",
        "Complete all outpost delivery routes",
        completedOutpostDeliveryContracts(),
        static_cast<int>(outpostDeliveryProgress().size()));
    addEntry(
        "pressure_harvest",
        "Claim five pressure wave rewards",
        productionTotals_.pressureWaveRewardsClaimed,
        5);
    addEntry(
        "lair_caches",
        "Open five dungeon or lair caches",
        productionTotals_.dungeonChestsOpened,
        5);
    addEntry(
        "rift_freight",
        "Complete twenty train-stop cargo hops for remote freight",
        productionTotals_.trainDeliveries,
        20);
    addEntry(
        "scrap_economy",
        "Recycle ten scrap into useful factory plates",
        productionTotals_.scrapRecycled,
        10);
    addEntry(
        "powered_industry",
        "Extract fifty resources with electric miners",
        productionTotals_.poweredOre,
        50);
    return entries;
}

int Simulation::completedPostVictoryExpeditions() const
{
    int completed = 0;
    for (const auto& entry : postVictoryExpeditionBoard()) {
        if (entry.complete) {
            ++completed;
        }
    }
    return completed;
}

std::string Simulation::postVictoryExpeditionText() const
{
    const auto board = postVictoryExpeditionBoard();
    if (!mainObjectiveComplete()) {
        return "expedition board: locked until the main rift objective is complete";
    }
    for (std::size_t index = 0; index < board.size(); ++index) {
        const auto& entry = board[index];
        if (!entry.complete) {
            return "expedition " + std::to_string(index + 1) + "/" +
                std::to_string(board.size()) + ": " + entry.label + " (" +
                std::to_string(std::min(entry.current, entry.required)) + "/" +
                std::to_string(entry.required) + ")";
        }
    }
    return "expedition board complete: rift-era mastery proven across scouting, bosses, storms, outposts, pressure, lairs, freight, scrap, and powered mining";
}

bool Simulation::mainObjectiveComplete() const
{
    return productionTotals_.riftJumps > 0 &&
        completedSupplyContracts() >= totalSupplyContracts();
}

bool Simulation::hasActivatedOutpostBiome(BiomeKind biome) const
{
    return hasBiomeMask(productionTotals_.outpostBiomeMask, biome);
}

int Simulation::activatedOutpostBiomeCount() const
{
    return countOutpostBiomeCoverage(productionTotals_.outpostBiomeMask);
}

std::vector<BiomeKind> Simulation::activatedOutpostBiomes() const
{
    std::vector<BiomeKind> biomes;
    for (const auto biome : kRequiredOutpostBiomes) {
        if (hasActivatedOutpostBiome(biome)) {
            biomes.push_back(biome);
        }
    }
    return biomes;
}

bool Simulation::hasCompletedOutpostDeliveryBiome(BiomeKind biome) const
{
    return hasBiomeMask(productionTotals_.outpostDeliveryBiomeMask, biome);
}

int Simulation::outpostDeliveryBiomeCount() const
{
    return countOutpostBiomeCoverage(productionTotals_.outpostDeliveryBiomeMask);
}

std::vector<OutpostDeliveryProgress> Simulation::outpostDeliveryProgress() const
{
    std::vector<OutpostDeliveryProgress> progress;
    progress.reserve(kRequiredOutpostBiomes.size());
    for (const auto biome : kRequiredOutpostBiomes) {
        const auto label = std::string(toString(biome)) + " delivery: feed an activated outpost " +
            std::string(toString(outpostActivationItem(biome)));
        progress.push_back(OutpostDeliveryProgress{
            biome,
            label,
            hasCompletedOutpostDeliveryBiome(biome) ? 1 : 0,
            1,
            hasCompletedOutpostDeliveryBiome(biome)});
    }
    return progress;
}

int Simulation::completedOutpostDeliveryContracts() const
{
    int completed = 0;
    for (const auto& delivery : outpostDeliveryProgress()) {
        if (delivery.complete) {
            ++completed;
        }
    }
    return completed;
}

std::string Simulation::currentOutpostDeliveryText() const
{
    const auto deliveries = outpostDeliveryProgress();
    for (std::size_t index = 0; index < deliveries.size(); ++index) {
        const auto& delivery = deliveries[index];
        if (!delivery.complete && hasActivatedOutpostBiome(delivery.biome)) {
            return "outpost delivery " + std::to_string(index + 1) + "/" +
                std::to_string(deliveries.size()) + ": " + delivery.label + " (" +
                std::to_string(delivery.current) + "/" + std::to_string(delivery.required) + ")";
        }
    }
    for (std::size_t index = 0; index < deliveries.size(); ++index) {
        const auto& delivery = deliveries[index];
        if (!delivery.complete) {
            return "outpost delivery " + std::to_string(index + 1) + "/" +
                std::to_string(deliveries.size()) + ": " + delivery.label + " (" +
                std::to_string(delivery.current) + "/" + std::to_string(delivery.required) + ")";
        }
    }
    return "outpost deliveries complete: all stabilized biomes have accepted local supply";
}

bool Simulation::hasScoutedBiome(BiomeKind biome) const
{
    return hasBiomeMask(productionTotals_.scoutedBiomeMask, biome);
}

int Simulation::scoutedBiomeCount() const
{
    int count = 0;
    for (const auto biome : kScoutBiomes) {
        if (hasScoutedBiome(biome)) {
            ++count;
        }
    }
    return count;
}

std::vector<BiomeKind> Simulation::scoutedBiomes() const
{
    std::vector<BiomeKind> biomes;
    for (const auto biome : kScoutBiomes) {
        if (hasScoutedBiome(biome)) {
            biomes.push_back(biome);
        }
    }
    return biomes;
}

std::string Simulation::scoutAutomationText() const
{
    int poweredPorts = 0;
    const Machine* activePort = nullptr;
    const Machine* readyPort = nullptr;
    for (const auto& machine : machines_) {
        if (machine.kind != MachineKind::LogisticPort || !isMachinePowered(machine.id)) {
            continue;
        }
        ++poweredPorts;
        if (machine.progress > 0 && machine.carriedItem != ItemId::None) {
            activePort = &machine;
            break;
        }
        if (readyPort == nullptr) {
            readyPort = &machine;
        }
    }

    const auto countText = std::to_string(scoutedBiomeCount()) + "/" +
        std::to_string(kScoutBiomes.size());
    if (activePort != nullptr) {
        return "scouts: dispatching " + std::string(toString(activePort->carriedItem)) +
            " sample " + std::to_string(activePort->progress) + "/" +
            std::to_string(kScoutDispatchTicks) + "; scouted " + countText;
    }
    if (poweredPorts == 0) {
        return "scouts: offline; power a logistic port with drones and science packs";
    }
    if (readyPort != nullptr) {
        const auto targetBiome = scoutTargetBiome(*readyPort);
        const auto localBiome = world_.biomeAt(readyPort->x, readyPort->y, readyPort->z);
        const auto routeBonus = localBiome == targetBiome ? "; local route bonus" : "";
        return "scouts: ready from " + std::to_string(poweredPorts) +
            " powered port(s); next target " + std::string(toString(targetBiome)) +
            routeBonus + "; scouted " + countText;
    }
    return "scouts: scouted " + countText;
}

int Simulation::completedBiomeContracts() const
{
    int completed = 0;
    for (const auto& contract : biomeContractProgress()) {
        if (contract.complete) {
            ++completed;
        }
    }
    return completed;
}

std::vector<BiomeContractProgress> Simulation::biomeContractProgress() const
{
    std::vector<BiomeContractProgress> contracts;
    const auto addContract = [&contracts](BiomeKind biome, std::string label, int current, int required) {
        contracts.push_back(BiomeContractProgress{
            biome,
            std::move(label),
            current,
            required,
            current >= required});
    };

    addContract(BiomeKind::Marsh, "Marsh: pump 3 water barrels", productionTotals_.waterBarrels, 3);
    addContract(BiomeKind::Desert, "Desert: stockpile 2 sand glass", totalItemCount(ItemId::SandGlass), 2);
    addContract(BiomeKind::Badlands, "Badlands: stockpile 6 basalt", totalItemCount(ItemId::Basalt), 6);
    addContract(BiomeKind::Snowfield, "Snowfield: stockpile 4 ice shards", totalItemCount(ItemId::IceShard), 4);
    addContract(BiomeKind::CrystalField, "Crystal Field: stockpile 3 crystal", totalItemCount(ItemId::Crystal), 3);
    addContract(BiomeKind::Rift, "Rift: complete 2 rift jumps", productionTotals_.riftJumps, 2);
    addContract(BiomeKind::Marsh, "Marsh Outpost: activate powered beacon", hasActivatedOutpostBiome(BiomeKind::Marsh) ? 1 : 0, 1);
    addContract(BiomeKind::Desert, "Desert Outpost: activate powered beacon", hasActivatedOutpostBiome(BiomeKind::Desert) ? 1 : 0, 1);
    addContract(BiomeKind::Badlands, "Badlands Outpost: activate powered beacon", hasActivatedOutpostBiome(BiomeKind::Badlands) ? 1 : 0, 1);
    addContract(BiomeKind::Snowfield, "Snowfield Outpost: activate powered beacon", hasActivatedOutpostBiome(BiomeKind::Snowfield) ? 1 : 0, 1);
    addContract(BiomeKind::CrystalField, "Crystal Outpost: activate powered beacon", hasActivatedOutpostBiome(BiomeKind::CrystalField) ? 1 : 0, 1);
    return contracts;
}

std::string Simulation::currentBiomeContractText() const
{
    const auto contracts = biomeContractProgress();
    for (std::size_t index = 0; index < contracts.size(); ++index) {
        const auto& contract = contracts[index];
        if (!contract.complete) {
            return "biome contract " + std::to_string(index + 1) + "/" +
                std::to_string(contracts.size()) + ": " + contract.label + " (" +
                std::to_string(std::min(contract.current, contract.required)) + "/" +
                std::to_string(contract.required) + ")";
        }
    }
    return "biome contracts complete: outposts proved across marsh, desert, badlands, snowfield, crystal, and rift";
}

std::vector<BiomeHazardState> Simulation::biomeHazards() const
{
    std::vector<BiomeHazardState> hazards;
    hazards.reserve(6);
    for (const auto biome : {BiomeKind::Marsh, BiomeKind::Desert, BiomeKind::Badlands,
             BiomeKind::Snowfield, BiomeKind::CrystalField, BiomeKind::Rift}) {
        hazards.push_back(biomeHazardFor(
            biome,
            biomeHazardLevel(factoryPressureLevel(), hasActivatedOutpostBiome(biome))));
    }
    return hazards;
}

std::string Simulation::currentBiomeHazardText() const
{
    const auto biome = world_.biomeAt(player_.x, player_.y, player_.z);
    const auto hazard = biomeHazardFor(
        biome,
        biomeHazardLevel(factoryPressureLevel(), hasActivatedOutpostBiome(biome)));
    if (hazard.level <= 0) {
        return "hazard: " + std::string(toString(biome)) + " stable; no active biome hazard";
    }
    return "hazard: " + hazard.label + " L" + std::to_string(hazard.level) + "; " +
        hazard.effect + "; " + hazard.mitigation;
}

std::vector<BossExamProgress> Simulation::bossExamProgress() const
{
    std::vector<BossExamProgress> exams;
    exams.reserve(5);
    const auto addExam = [&exams](EntityKind boss, BiomeKind biome, std::string label, int current, int required) {
        exams.push_back(BossExamProgress{
            boss,
            biome,
            std::move(label),
            current,
            required,
            current >= required});
    };

    addExam(
        EntityKind::MarshBroodheart,
        BiomeKind::Marsh,
        "Broodheart exam: pump 3 water barrels before opening the hive",
        productionTotals_.waterBarrels,
        3);
    addExam(
        EntityKind::GlassMaw,
        BiomeKind::Desert,
        "Glass Maw exam: stockpile 3 sand glass at the spire",
        totalItemCount(ItemId::SandGlass),
        3);
    addExam(
        EntityKind::BadlandsWarden,
        BiomeKind::Badlands,
        "Warden exam: extract 8 powered ore before challenging the foundry",
        productionTotals_.poweredOre,
        8);
    addExam(
        EntityKind::FrostNullifier,
        BiomeKind::Snowfield,
        "Frost exam: complete 3 logistic deliveries before entering the vault",
        productionTotals_.logisticDeliveries,
        3);
    const int riftCurrent =
        (productionTotals_.archiveSignals > 0 ? 1 : 0) +
        (productionTotals_.riftJumps > 0 ? 1 : 0) +
        std::min(3, activatedOutpostBiomeCount());
    addExam(
        EntityKind::RiftSignalTyrant,
        BiomeKind::CrystalField,
        "Rift exam: charge archive, open a rift jump, and stabilize 3 outposts",
        riftCurrent,
        5);
    return exams;
}

std::string Simulation::currentBossExamText() const
{
    const auto exams = bossExamProgress();
    for (std::size_t index = 0; index < exams.size(); ++index) {
        const auto& exam = exams[index];
        if (!exam.complete) {
            return "boss exam " + std::to_string(index + 1) + "/" + std::to_string(exams.size()) +
                ": " + exam.label + " (" + std::to_string(std::min(exam.current, exam.required)) +
                "/" + std::to_string(exam.required) + ")";
        }
    }
    return "boss exams complete: factory has proven fluid, glass, power, logistics, and rift readiness";
}

std::string Simulation::currentDemoGoalText() const
{
    const auto expeditionBoard = postVictoryExpeditionBoard();
    if (mainObjectiveComplete() &&
        completedPostVictoryExpeditions() >= static_cast<int>(expeditionBoard.size())) {
        return "demo goal complete: expedition board mastered across rift-era systems";
    }
    if (mainObjectiveComplete()) {
        return "demo goal: complete the post-victory expedition board";
    }
    if (mainObjectiveComplete() && productionTotals_.bossRelicsClaimed >= 5) {
        return "demo goal complete: factory, lairs, relics, outposts, defenses, and rift are online";
    }
    if (productionTotals_.bossRelicsClaimed >= 5) {
        return "demo goal: use the full relic set to finish rift stabilization";
    }
    if (productionTotals_.bossRelicsClaimed > 0) {
        return "demo goal: claim five boss relics, then stabilize the rift";
    }
    if (completedSupplyContracts() >= 3) {
        return "demo goal: prepare a biome boss summon with factory output";
    }
    return "demo goal: build plates, automate science, conquer lairs, and stabilize the rift";
}

std::string Simulation::objectiveMarkerText() const
{
    if (productionTotals_.ironPlates < 3 || productionTotals_.copperPlates < 3) {
        return "marker: starter ore lanes east of spawn";
    }
    if (productionTotals_.sciencePacks < 2) {
        return "marker: craft assembler + lab beside the starter factory";
    }
    if (productionTotals_.bossRelicsClaimed == 0) {
        return "marker: marsh hive at x0 y18";
    }
    if (productionTotals_.bossRelicsClaimed == 1) {
        return "marker: glass spire at x18 y-2";
    }
    if (productionTotals_.bossRelicsClaimed == 2) {
        return "marker: badlands foundry at x36 y20";
    }
    if (productionTotals_.bossRelicsClaimed == 3) {
        return "marker: frost vault at x-18 y0";
    }
    if (productionTotals_.bossRelicsClaimed == 4) {
        return "marker: crystal vault at x-36 y20";
    }
    if (activatedOutpostBiomeCount() < static_cast<int>(kRequiredOutpostBiomes.size())) {
        return "marker: power unique outpost beacons in marsh, desert, badlands, snowfield, and crystal";
    }
    if (productionTotals_.riftJumps < 1) {
        return "marker: charge archive terminal, craft rift gate, then feed beacon core";
    }
    return "marker: rift band begins near x4096 and x-4096";
}

std::string Simulation::milestoneText() const
{
    const auto expeditionBoard = postVictoryExpeditionBoard();
    if (mainObjectiveComplete() &&
        completedPostVictoryExpeditions() >= static_cast<int>(expeditionBoard.size())) {
        return "milestone: expedition board complete; rift-era mastery achieved";
    }
    if (mainObjectiveComplete()) {
        return "milestone: main objective complete; use the expedition board for post-victory goals";
    }
    if (productionTotals_.riftJumps > 0) {
        return "milestone: rift reached; mine the rich outer world and route it back";
    }
    if (productionTotals_.archiveSignals > 0) {
        return "milestone: archive signal charged; build a rift gate for the next dimension";
    }
    if (isRecipeUnlocked("archive_terminal")) {
        return "milestone: craft beacon cores, power an archive terminal, and charge it";
    }
    if (productionTotals_.logisticDeliveries >= 10) {
        return "milestone: expand remote logistics; next delivery quota " +
            std::to_string(((productionTotals_.logisticDeliveries / 10) + 1) * 10);
    }
    if (productionTotals_.logisticDeliveries > 0) {
        return "milestone: complete 10 logistic deliveries";
    }
    if (isTechCompleted("logistic_network")) {
        return "milestone: connect provider/requester chests to a powered logistic port";
    }
    if (isTechCompleted("automation_control")) {
        return "milestone: produce advanced science for logistic networks";
    }
    if (isTechCompleted("logistics_1")) {
        return "milestone: automate circuit boards and controlled inserters";
    }
    return "milestone: automate science and finish Logistics 1";
}

std::string Simulation::playtestTelemetryText() const
{
    int hostileEntities = 0;
    int activeBosses = 0;
    for (const auto& entity : entities_) {
        if (!isHostile(entity.kind)) {
            continue;
        }
        ++hostileEntities;
        if (entity.kind == EntityKind::MarshBroodheart ||
            entity.kind == EntityKind::GlassMaw ||
            entity.kind == EntityKind::BadlandsWarden ||
            entity.kind == EntityKind::FrostNullifier ||
            entity.kind == EntityKind::RiftSignalTyrant) {
            ++activeBosses;
        }
    }

    int damagedMachines = 0;
    int socketedRelics = 0;
    for (const auto& machine : machines_) {
        const int maxDurability = machineMaxDurability(machine.kind);
        if (machine.durability > 0 && machine.durability < maxDurability) {
            ++damagedMachines;
        }
        if (machine.socketedRelic != ItemId::None) {
            ++socketedRelics;
        }
    }

    int damagedStructureTiles = 0;
    for (const auto& tile : world_.loadedTiles()) {
        if (isDamageableStructureTile(tile.tile.id) && tile.tile.data > 0) {
            ++damagedStructureTiles;
        }
    }

    int poweredNetworks = 0;
    int totalPowerSupply = 0;
    int totalPowerDemand = 0;
    for (const auto& network : powerNetworks_) {
        if (network.powered) {
            ++poweredNetworks;
        }
        totalPowerSupply += network.supply;
        totalPowerDemand += network.demand;
    }

    const auto bossExams = bossExamProgress();
    const auto completedBossExams = static_cast<int>(std::count_if(
        bossExams.begin(),
        bossExams.end(),
        [](const BossExamProgress& exam) {
            return exam.complete;
        }));
    const auto pressureEvent = nextPressureEvent();

    std::ostringstream out;
    out << "{\n";
    out << "  \"schema\": \"thoth.playtest.telemetry.v1\",\n";
    out << "  \"seed\": " << world_.seed() << ",\n";
    out << "  \"tick\": " << tick_ << ",\n";
    out << "  \"player\": {\"x\": " << player_.x << ", \"y\": " << player_.y
        << ", \"z\": " << player_.z << ", \"hp\": " << player_.hp << "},\n";
    out << "  \"main_objective_complete\": " << (mainObjectiveComplete() ? "true" : "false") << ",\n";
    out << "  \"contracts\": {\"supply_completed\": " << completedSupplyContracts()
        << ", \"supply_total\": " << totalSupplyContracts()
        << ", \"biome_completed\": " << completedBiomeContracts()
        << ", \"biome_total\": " << biomeContractProgress().size()
        << ", \"outpost_delivery_completed\": " << completedOutpostDeliveryContracts()
        << ", \"outpost_delivery_total\": " << outpostDeliveryProgress().size()
        << ", \"boss_exam_completed\": " << completedBossExams
        << ", \"boss_exam_total\": " << bossExams.size()
        << ", \"post_victory_expedition_completed\": " << completedPostVictoryExpeditions()
        << ", \"post_victory_expedition_total\": " << postVictoryExpeditionBoard().size() << "},\n";
    out << "  \"pressure\": {\"level\": " << factoryPressureLevel()
        << ", \"ticks_until_wave\": " << ticksUntilNextPressureWave()
        << ", \"waves_repelled\": " << productionTotals_.pressureWavesRepelled
        << ", \"event_key\": " << jsonString(pressureEvent.key)
        << ", \"event_label\": " << jsonString(pressureEvent.label)
        << ", \"event_severity\": " << pressureEvent.severity
        << ", \"event_spawns\": " << pressureEvent.spawnCount
        << ", \"alert\": " << jsonString(pressureWaveAlertText()) << "},\n";
    out << "  \"rift_storm\": {\"active\": " << (riftStormActive() ? "true" : "false")
        << ", \"severity\": " << riftStorm_.severity
        << ", \"ticks_remaining\": " << riftStorm_.ticksRemaining
        << ", \"cooldown_ticks\": " << riftStorm_.cooldownTicks
        << ", \"triggered\": " << productionTotals_.riftStormsTriggered
        << ", \"survived\": " << productionTotals_.riftStormsSurvived
        << ", \"summary\": " << jsonString(riftStormText()) << "},\n";
    out << "  \"production\": {\"iron_plates\": " << productionTotals_.ironPlates
        << ", \"copper_plates\": " << productionTotals_.copperPlates
        << ", \"science_packs\": " << productionTotals_.sciencePacks
        << ", \"advanced_science_packs\": " << productionTotals_.advancedSciencePacks
        << ", \"powered_ore\": " << productionTotals_.poweredOre
        << ", \"logistic_deliveries\": " << productionTotals_.logisticDeliveries
        << ", \"archive_signals\": " << productionTotals_.archiveSignals
        << ", \"rift_jumps\": " << productionTotals_.riftJumps
        << ", \"bosses_defeated\": " << productionTotals_.bossesDefeated
        << ", \"boss_relics_claimed\": " << productionTotals_.bossRelicsClaimed
        << ", \"outposts_activated\": " << productionTotals_.outpostsActivated
        << ", \"outpost_deliveries\": " << productionTotals_.outpostDeliveries
        << ", \"scrap_recovered\": " << productionTotals_.scrapRecovered
        << ", \"scrap_recycled\": " << productionTotals_.scrapRecycled
        << ", \"pressure_enemies_defeated\": " << productionTotals_.pressureEnemiesDefeated
        << ", \"pressure_wave_rewards_claimed\": " << productionTotals_.pressureWaveRewardsClaimed
        << ", \"rift_storms_triggered\": " << productionTotals_.riftStormsTriggered
        << ", \"rift_storms_survived\": " << productionTotals_.riftStormsSurvived
        << ", \"scout_dispatches\": " << productionTotals_.scoutDispatches
        << ", \"scout_materials_recovered\": " << productionTotals_.scoutMaterialsRecovered << "},\n";
    out << "  \"entities\": {\"total\": " << entities_.size()
        << ", \"hostile\": " << hostileEntities
        << ", \"active_bosses\": " << activeBosses
        << ", \"creatures_defeated\": " << productionTotals_.creaturesDefeated << "},\n";
    out << "  \"structures\": {\"machines\": " << machines_.size()
        << ", \"damaged_machines\": " << damagedMachines
        << ", \"socketed_relics\": " << socketedRelics
        << ", \"damaged_tiles\": " << damagedStructureTiles
        << ", \"powered_networks\": " << poweredNetworks
        << ", \"power_supply\": " << totalPowerSupply
        << ", \"power_demand\": " << totalPowerDemand << "},\n";

    out << "  \"machine_counts\": {";
    bool wroteMachine = false;
    for (const auto& def : machineDefs()) {
        int count = 0;
        for (const auto& machine : machines_) {
            if (machine.kind == def.id) {
                ++count;
            }
        }
        if (count == 0) {
            continue;
        }
        if (wroteMachine) {
            out << ",";
        }
        out << "\n    " << jsonString(def.key) << ": " << count;
        wroteMachine = true;
    }
    if (wroteMachine) {
        out << "\n  ";
    }
    out << "},\n";

    out << "  \"biome_hazards\": [";
    const auto hazards = biomeHazards();
    for (std::size_t i = 0; i < hazards.size(); ++i) {
        const auto& hazard = hazards[i];
        if (i > 0) {
            out << ",";
        }
        out << "\n    {\"biome\": " << jsonString(toString(hazard.biome))
            << ", \"label\": " << jsonString(hazard.label)
            << ", \"level\": " << hazard.level
            << ", \"effect\": " << jsonString(hazard.effect)
            << ", \"mitigation\": " << jsonString(hazard.mitigation) << "}";
    }
    if (!hazards.empty()) {
        out << "\n  ";
    }
    out << "],\n";

    out << "  \"factory_dashboard\": [";
    const auto dashboardPanels = factoryDashboard();
    for (std::size_t i = 0; i < dashboardPanels.size(); ++i) {
        const auto& panel = dashboardPanels[i];
        if (i > 0) {
            out << ",";
        }
        out << "\n    {\"key\": " << jsonString(panel.key)
            << ", \"label\": " << jsonString(panel.label)
            << ", \"status\": " << jsonString(panel.status)
            << ", \"urgent\": " << (panel.urgent ? "true" : "false")
            << ", \"current\": " << panel.current
            << ", \"target\": " << panel.target
            << ", \"detail\": " << jsonString(panel.detail) << "}";
    }
    if (!dashboardPanels.empty()) {
        out << "\n  ";
    }
    out << "],\n";

    out << "  \"post_victory_expeditions\": [";
    const auto expeditionBoard = postVictoryExpeditionBoard();
    for (std::size_t i = 0; i < expeditionBoard.size(); ++i) {
        const auto& entry = expeditionBoard[i];
        if (i > 0) {
            out << ",";
        }
        out << "\n    {\"key\": " << jsonString(entry.key)
            << ", \"label\": " << jsonString(entry.label)
            << ", \"unlocked\": " << (entry.unlocked ? "true" : "false")
            << ", \"complete\": " << (entry.complete ? "true" : "false")
            << ", \"current\": " << entry.current
            << ", \"required\": " << entry.required << "}";
    }
    if (!expeditionBoard.empty()) {
        out << "\n  ";
    }
    out << "],\n";

    out << "  \"activated_outpost_biomes\": [";
    const auto biomes = activatedOutpostBiomes();
    for (std::size_t i = 0; i < biomes.size(); ++i) {
        if (i > 0) {
            out << ", ";
        }
        out << jsonString(toString(biomes[i]));
    }
    out << "],\n";
    out << "  \"completed_outpost_delivery_biomes\": [";
    bool wroteDeliveryBiome = false;
    for (const auto biome : kRequiredOutpostBiomes) {
        if (!hasCompletedOutpostDeliveryBiome(biome)) {
            continue;
        }
        if (wroteDeliveryBiome) {
            out << ", ";
        }
        out << jsonString(toString(biome));
        wroteDeliveryBiome = true;
    }
    out << "],\n";
    out << "  \"scouted_biomes\": [";
    const auto scouted = scoutedBiomes();
    for (std::size_t i = 0; i < scouted.size(); ++i) {
        if (i > 0) {
            out << ", ";
        }
        out << jsonString(toString(scouted[i]));
    }
    out << "],\n";
    out << "  \"guidance\": {\"goal\": " << jsonString(currentDemoGoalText())
        << ", \"supply_contract\": " << jsonString(currentSupplyContractText())
        << ", \"biome_contract\": " << jsonString(currentBiomeContractText())
        << ", \"outpost_delivery\": " << jsonString(currentOutpostDeliveryText())
        << ", \"scouts\": " << jsonString(scoutAutomationText())
        << ", \"post_victory_expedition\": " << jsonString(postVictoryExpeditionText())
        << ", \"biome_hazard\": " << jsonString(currentBiomeHazardText())
        << ", \"boss_exam\": " << jsonString(currentBossExamText())
        << ", \"pressure_deck\": " << jsonString(pressureEventDeckText())
        << ", \"rift_storm\": " << jsonString(riftStormText())
        << ", \"marker\": " << jsonString(objectiveMarkerText())
        << ", \"milestone\": " << jsonString(milestoneText()) << "}\n";
    out << "}\n";
    return out.str();
}

bool Simulation::isMachinePowered(std::uint32_t machineId) const
{
    return containsId(poweredMachineIds_, machineId);
}

SimulationSnapshot Simulation::snapshot() const
{
    PlayerSnapshot playerSnapshot;
    playerSnapshot.x = player_.x;
    playerSnapshot.y = player_.y;
    playerSnapshot.z = player_.z;
    playerSnapshot.facing = player_.facing;
    playerSnapshot.selectedHotbar = player_.selectedHotbar;
    playerSnapshot.hotbar = player_.hotbar;
    playerSnapshot.inventory = player_.inventory.stacks();
    playerSnapshot.inBoat = player_.inBoat;
    playerSnapshot.hp = player_.hp;

    SimulationSnapshot result;
    result.seed = world_.seed();
    result.tick = tick_;
    result.player = playerSnapshot;
    result.tiles = world_.loadedTiles();
    result.nextMachineId = nextMachineId_;
    result.nextEntityId = nextEntityId_;
    result.machines = machines_;
    result.entities = entities_;
    result.logisticJobs = logisticJobs_;
    result.productionTotals = productionTotals_;
    result.riftStorm = riftStorm_;
    result.activeTech = activeTech_;
    result.researchProgress = researchProgress_;
    result.completedTechs = completedTechs_;
    result.unlockedRecipes = unlockedRecipes_;
    result.unlockedAchievements = unlockedAchievements_;
    result.tutorial = tutorialState_;
    return result;
}

void Simulation::restore(const SimulationSnapshot& snapshot)
{
    world_ = World(snapshot.seed);
    world_.clearLoadedChunks();
    for (const auto& tile : snapshot.tiles) {
        world_.setTile(tile.x, tile.y, tile.z, tile.tile);
    }

    player_.x = snapshot.player.x;
    player_.y = snapshot.player.y;
    player_.z = snapshot.player.z;
    player_.facing = snapshot.player.facing;
    player_.selectedHotbar = std::clamp(snapshot.player.selectedHotbar, 0, kHotbarSlots - 1);
    player_.hotbar = snapshot.player.hotbar;
    player_.inBoat = snapshot.player.inBoat;
    player_.hp = snapshot.player.hp <= 0 ? 20 : snapshot.player.hp;
    player_.inventory.clear();
    for (const auto& stack : snapshot.player.inventory) {
        const auto added = player_.inventory.add(stack.item, stack.count);
        (void)added;
    }

    tick_ = snapshot.tick;
    nextMachineId_ = snapshot.nextMachineId == 0 ? 1 : snapshot.nextMachineId;
    nextEntityId_ = snapshot.nextEntityId == 0 ? 1 : snapshot.nextEntityId;
    machines_ = snapshot.machines;
    entities_ = snapshot.entities;
    for (auto& machine : machines_) {
        if (machine.kind == MachineKind::Assembler && machine.recipeKey.empty()) {
            machine.recipeKey = "science_pack";
        } else if (machine.kind == MachineKind::Furnace && machine.progress > 0 && machine.recipeKey.empty()) {
            machine.recipeKey = "iron_plate";
        }
        const int maxDurability = machineMaxDurability(machine.kind);
        if (machine.durability <= 0) {
            machine.durability = maxDurability;
        } else {
            machine.durability = std::min(machine.durability, maxDurability);
        }
    }
    rebuildMachineCellIndex();
    logisticJobs_ = snapshot.logisticJobs;
    productionTotals_ = snapshot.productionTotals;
    riftStorm_ = snapshot.riftStorm;
    riftStorm_.severity = std::clamp(riftStorm_.severity, 0, 4);
    riftStorm_.ticksRemaining = std::max(0, riftStorm_.ticksRemaining);
    riftStorm_.cooldownTicks = std::max(0, riftStorm_.cooldownTicks);
    completedTechs_ = snapshot.completedTechs;
    unlockedRecipes_ = snapshot.unlockedRecipes;
    unlockedAchievements_.clear();
    for (const auto achievement : snapshot.unlockedAchievements) {
        if (achievementDef(achievement) != nullptr && !isAchievementUnlocked(achievement)) {
            unlockedAchievements_.push_back(achievement);
        }
    }
    tutorialState_ = snapshot.tutorial;
    if (tutorialState_.realSpawnZ != 0 ||
        (tutorialState_.realSpawnX == 0 && tutorialState_.realSpawnY == 0 && !tutorialState_.active)) {
        const auto computedSpawn = findRealWorldSpawn();
        tutorialState_.realSpawnX = computedSpawn.realSpawnX;
        tutorialState_.realSpawnY = computedSpawn.realSpawnY;
        tutorialState_.realSpawnZ = computedSpawn.realSpawnZ;
    }
    if (tutorialState_.completed) {
        tutorialState_.active = false;
        tutorialState_.actionMask = kTutorialRequiredMask;
    }
    tutorialState_.actionMask &= kTutorialRequiredMask;
    if (tutorialState_.active) {
        tutorialState_.completed = false;
    }
    activeTech_ = snapshot.activeTech.empty() ? nextIncompleteTech() : snapshot.activeTech;
    if (techDef(activeTech_) == nullptr || isTechCompleted(activeTech_)) {
        activeTech_ = nextIncompleteTech();
    }
    researchProgress_ = activeTech_.empty() ? 0 : std::max(0, snapshot.researchProgress);
    powerNetworks_.clear();
    poweredMachineIds_.clear();
    commandQueue_.clear();
}

Simulation Simulation::fromSnapshot(const SimulationSnapshot& snapshot)
{
    Simulation simulation(snapshot.seed);
    simulation.restore(snapshot);
    return simulation;
}

void Simulation::rebuildMachineCellIndex()
{
    machineCellIndex_.clear();
    for (std::size_t index = 0; index < machines_.size(); ++index) {
        const auto& machine = machines_[index];
        const auto& def = machineDef(machine.kind);
        for (int oy = 0; oy < def.height; ++oy) {
            for (int ox = 0; ox < def.width; ++ox) {
                machineCellIndex_[machineCellKey(machine.x + ox, machine.y + oy, machine.z)] = index;
            }
        }
    }
}

void Simulation::apply(const Command& command)
{
    switch (command.type) {
    case CommandType::Face:
        player_.facing = command.direction;
        break;
    case CommandType::Move:
        player_.facing = command.direction;
        move(command.direction);
        break;
    case CommandType::Mine:
        player_.facing = command.direction;
        mine(command.direction);
        break;
    case CommandType::Place:
        player_.facing = command.direction;
        place(command.direction, command.tile, command.item, command.orientation);
        break;
    case CommandType::Craft:
        craft(command.recipeKey);
        break;
    case CommandType::SelectHotbar:
        selectHotbar(command.hotbarIndex);
        break;
    case CommandType::AssignHotbar:
        assignHotbarSlot(command.hotbarIndex, command.item);
        break;
    case CommandType::ConfigureMachineRecipe:
        player_.facing = command.direction;
        configureMachineRecipe(command.direction, command.recipeKey);
        break;
    case CommandType::DepositSelected:
        player_.facing = command.direction;
        depositSelected(command.direction);
        break;
    case CommandType::DepositItem:
        player_.facing = command.direction;
        depositItem(command.direction, command.item);
        break;
    case CommandType::WithdrawItem:
        player_.facing = command.direction;
        withdrawItem(command.direction, command.item);
        break;
    case CommandType::ConfigureCircuit:
        player_.facing = command.direction;
        configureCircuit(command.direction, command.item, command.comparator, command.amount);
        break;
    case CommandType::ConfigureRequest:
        player_.facing = command.direction;
        configureRequest(command.direction, command.item, command.amount);
        break;
    case CommandType::Interact:
        player_.facing = command.direction;
        interact(command.direction);
        break;
    case CommandType::Attack:
        player_.facing = command.direction;
        attack(command.direction);
        break;
    }
}

void Simulation::move(Direction direction)
{
    const int nx = player_.x + dx(direction);
    const int ny = player_.y + dy(direction);
    const auto target = world_.getTile(nx, ny, player_.z);
    if (player_.inBoat) {
        if (!isWaterTile(target.id)) {
            return;
        }
        player_.x = nx;
        player_.y = ny;
        recordTutorialAction(TutorialAction::Move);
        return;
    }
    if (world_.isWalkable(nx, ny, player_.z) && !isWaterTile(target.id)) {
        player_.x = nx;
        player_.y = ny;
        recordTutorialAction(TutorialAction::Move);
    }
}

void Simulation::mine(Direction direction)
{
    const int tx = player_.x + dx(direction);
    const int ty = player_.y + dy(direction);
    const auto tile = world_.getTile(tx, ty, player_.z);
    if (!isMineable(tile.id)) {
        return;
    }

    const auto& def = tileDef(tile.id);
    const int dropCount = isDamageableStructureTile(tile.id) ? 1 : std::max(1, tile.data);
    addItem(def.drop, dropCount);
    world_.setTile(tx, ty, player_.z, Tile{minedReplacement(tile.id), 0});
    recordTutorialAction(TutorialAction::Mine);
}

void Simulation::place(Direction direction, TileId tile, ItemId item, Direction orientation)
{
    if (isMachineItem(item)) {
        placeMachine(direction, item, orientation);
        return;
    }

    const int tx = player_.x + dx(direction);
    const int ty = player_.y + dy(direction);
    if (machineAt(tx, ty, player_.z) != nullptr) {
        return;
    }

    auto tileToPlace = tile;
    auto requiredItem = ItemId::None;
    if (item != ItemId::None) {
        const auto& def = itemDef(item);
        if (!def.canPlaceTile) {
            return;
        }
        tileToPlace = def.placeTile;
        requiredItem = item;
    } else {
        requiredItem = tileDef(tileToPlace).drop;
    }

    const auto targetTile = world_.getTile(tx, ty, player_.z);
    if (!world_.isWalkable(tx, ty, player_.z) || !tileDef(targetTile.id).buildable) {
        return;
    }

    if (requiredItem != ItemId::None && !consumeItem(requiredItem, 1)) {
        return;
    }
    world_.setTile(tx, ty, player_.z, Tile{tileToPlace, 0});
    recordTutorialAction(TutorialAction::Place);
}

void Simulation::placeMachine(Direction direction, ItemId item, Direction orientation)
{
    const auto& def = itemDef(item);
    if (!def.canPlaceMachine) {
        return;
    }

    const int tx = player_.x + dx(direction);
    const int ty = player_.y + dy(direction);
    if (!canPlaceMachine(def.placeMachine, tx, ty, player_.z)) {
        return;
    }
    if (!consumeItem(item, 1)) {
        return;
    }

    Machine machine;
    machine.id = nextMachineId_++;
    machine.kind = def.placeMachine;
    machine.x = tx;
    machine.y = ty;
    machine.z = player_.z;
    machine.direction = orientation;
    machine.durability = machineMaxDurability(machine.kind);
    if (machine.kind == MachineKind::Assembler) {
        machine.recipeKey = "science_pack";
    }
    machines_.push_back(std::move(machine));

    std::sort(machines_.begin(), machines_.end(), [](const Machine& left, const Machine& right) {
        return left.id < right.id;
    });
    rebuildMachineCellIndex();
    recordTutorialAction(TutorialAction::Place);
}

void Simulation::depositSelected(Direction direction)
{
    depositItem(direction, selectedItem());
}

void Simulation::depositItem(Direction direction, ItemId item)
{
    if (item == ItemId::None || !player_.inventory.canConsume(item, 1)) {
        return;
    }

    const int tx = player_.x + dx(direction);
    const int ty = player_.y + dy(direction);
    if (!acceptItemAt(tx, ty, player_.z, item)) {
        return;
    }

    const auto consumed = consumeItem(item, 1);
    (void)consumed;
    recordTutorialAction(TutorialAction::Deposit);
}

void Simulation::withdrawItem(Direction direction, ItemId item)
{
    if (item == ItemId::None) {
        return;
    }

    const int tx = player_.x + dx(direction);
    const int ty = player_.y + dy(direction);
    auto* machine = machineAt(tx, ty, player_.z);
    if (machine == nullptr) {
        return;
    }

    auto removed = ItemId::None;
    if (machine->carriedItem == item) {
        removed = machine->carriedItem;
        machine->carriedItem = ItemId::None;
    } else if (machine->outputItem == item) {
        removed = machine->outputItem;
        machine->outputItem = ItemId::None;
    } else if (machine->socketedRelic == item) {
        removed = machine->socketedRelic;
        machine->socketedRelic = ItemId::None;
    } else if (machine->inventory.consume(item, 1)) {
        removed = item;
    }

    if (removed != ItemId::None) {
        addItem(removed, 1);
    }
}

void Simulation::craft(std::string_view recipeKey)
{
    const auto* recipe = recipeDef(recipeKey);
    if (recipe == nullptr) {
        return;
    }
    if (!isRecipeUnlocked(recipeKey) || !canCraftAtCurrentStation(*recipe)) {
        return;
    }
    if (!player_.inventory.consumeAll(recipe->inputs)) {
        return;
    }

    addItem(recipe->output.item, recipe->output.count);
    if (recipe->output.item == ItemId::IronPlate) {
        productionTotals_.ironPlates += recipe->output.count;
    } else if (recipe->output.item == ItemId::CopperPlate) {
        productionTotals_.copperPlates += recipe->output.count;
    }
    if (recipeKey == "salvage_iron_plate" || recipeKey == "salvage_copper_plate") {
        productionTotals_.scrapRecycled += recipe->output.count;
    }
    recordTutorialAction(TutorialAction::Craft);
}

void Simulation::selectHotbar(int index)
{
    if (index < 0 || index >= kHotbarSlots) {
        return;
    }
    player_.selectedHotbar = index;
}

void Simulation::assignHotbarSlot(int index, ItemId item)
{
    if (index < 0 || index >= kHotbarSlots) {
        return;
    }
    if (item != ItemId::None && player_.inventory.count(item) <= 0) {
        return;
    }
    player_.hotbar[static_cast<std::size_t>(index)] = item;
    player_.selectedHotbar = index;
}

void Simulation::configureMachineRecipe(Direction direction, std::string_view recipeKey)
{
    const int tx = player_.x + dx(direction);
    const int ty = player_.y + dy(direction);
    auto* machine = machineAt(tx, ty, player_.z);
    if (machine == nullptr ||
        (machine->kind != MachineKind::Assembler && machine->kind != MachineKind::Furnace)) {
        return;
    }
    if (machine->progress != 0 || machine->outputItem != ItemId::None) {
        return;
    }

    const auto* recipe = recipeDef(recipeKey);
    if (recipe == nullptr || !isRecipeUnlocked(recipeKey)) {
        return;
    }
    if (machine->kind == MachineKind::Assembler && recipe->station != "assembler") {
        return;
    }
    if (machine->kind == MachineKind::Furnace && recipe->station != "furnace") {
        return;
    }

    machine->recipeKey = std::string(recipeKey);
    machine->recipeLocked = true;
}

void Simulation::configureCircuit(Direction direction, ItemId filterItem, CircuitComparator comparator, int threshold)
{
    const int tx = player_.x + dx(direction);
    const int ty = player_.y + dy(direction);
    auto* machine = machineAt(tx, ty, player_.z);
    if (machine == nullptr || machine->kind != MachineKind::CircuitInserter) {
        return;
    }
    machine->filterItem = filterItem;
    machine->circuitComparator = comparator;
    machine->circuitThreshold = std::max(0, threshold);
}

void Simulation::configureRequest(Direction direction, ItemId requestItem, int threshold)
{
    const int tx = player_.x + dx(direction);
    const int ty = player_.y + dy(direction);
    auto* machine = machineAt(tx, ty, player_.z);
    if (machine == nullptr || machine->kind != MachineKind::RequesterChest) {
        return;
    }
    machine->requestItem = requestItem;
    machine->requestThreshold = requestItem == ItemId::None ? 0 : std::max(0, threshold);
}

void Simulation::interact(Direction direction)
{
    const int tx = player_.x + dx(direction);
    const int ty = player_.y + dy(direction);
    auto tile = world_.getTile(tx, ty, player_.z);

    if (player_.inBoat) {
        if (!isWaterTile(tile.id) && world_.isWalkable(tx, ty, player_.z)) {
            player_.x = tx;
            player_.y = ty;
            player_.inBoat = false;
            addItem(ItemId::Boat, 1);
        }
        return;
    }

    if (selectedItem() == ItemId::Boat && isWaterTile(tile.id) && consumeItem(ItemId::Boat, 1)) {
        player_.x = tx;
        player_.y = ty;
        player_.inBoat = true;
        return;
    }

    if (tile.id == TileId::Door) {
        tile.data = tile.data > 0 ? 0 : 1;
        world_.setTile(tx, ty, player_.z, tile);
        return;
    }

    if (player_.z < 0 && world_.lairAt(tx, ty, player_.z).has_value()) {
        const auto reward = resourceTileOutput(tile.id);
        if (reward != ItemId::None) {
            addItem(reward, std::max(2, tile.data + 1));
            world_.setTile(tx, ty, player_.z, Tile{TileId::DungeonFloor, 0});
            ++productionTotals_.dungeonChestsOpened;
            return;
        }
    }

    if (tile.id == TileId::StairsDown &&
        tutorialState_.active &&
        player_.z == kTutorialLayer &&
        tx == kTutorialExitX &&
        ty == kTutorialExitY) {
        if (tutorialExitReady()) {
            completeTutorial();
        }
        return;
    }

    if (tile.id == TileId::StairsDown &&
        (trySummonMarshBoss(tx, ty, player_.z) ||
            trySummonGlassBoss(tx, ty, player_.z) ||
            trySummonBadlandsBoss(tx, ty, player_.z) ||
            trySummonFrostBoss(tx, ty, player_.z) ||
            trySummonRiftBoss(tx, ty, player_.z))) {
        return;
    }

    if (tile.id == TileId::StairsUp || tile.id == TileId::StairsDown) {
        const int dz = tile.id == TileId::StairsUp ? 1 : -1;
        const int targetZ = player_.z + dz;
        if (world_.isWalkable(tx, ty, targetZ)) {
            player_.x = tx;
            player_.y = ty;
            player_.z = targetZ;
        }
    }
}

bool Simulation::bossExamComplete(EntityKind boss) const
{
    for (const auto& exam : bossExamProgress()) {
        if (exam.boss == boss) {
            return exam.complete;
        }
    }
    return false;
}

bool Simulation::trySummonMarshBoss(int x, int y, int z)
{
    const auto lair = world_.lairAt(x, y, z);
    if (!lair || *lair != LairKind::MarshHive) {
        return false;
    }
    for (const auto& entity : entities_) {
        if (entity.kind == EntityKind::MarshBroodheart && entity.hp > 0) {
            return true;
        }
    }
    if (!bossExamComplete(EntityKind::MarshBroodheart)) {
        return false;
    }
    if (!player_.inventory.canConsume(ItemId::WaterBarrel, 1) ||
        !player_.inventory.canConsume(ItemId::ReedFiber, 3) ||
        !player_.inventory.canConsume(ItemId::SciencePack, 1)) {
        return false;
    }

    const auto consumedWater = consumeItem(ItemId::WaterBarrel, 1);
    const auto consumedReeds = consumeItem(ItemId::ReedFiber, 3);
    const auto consumedScience = consumeItem(ItemId::SciencePack, 1);
    (void)consumedWater;
    (void)consumedReeds;
    (void)consumedScience;

    constexpr std::array<std::pair<int, int>, 8> kOffsets{{
        {-2, 0},
        {2, 0},
        {0, -2},
        {0, 2},
        {-2, -1},
        {2, 1},
        {-1, 2},
        {1, -2},
    }};
    for (const auto& [offsetX, offsetY] : kOffsets) {
        const int sx = x + offsetX;
        const int sy = y + offsetY;
        if (world_.lairAt(sx, sy, z) != lair ||
            !world_.isWalkable(sx, sy, z) ||
            entityAt(sx, sy, z) != nullptr ||
            machineAt(sx, sy, z) != nullptr) {
            continue;
        }
        Entity boss;
        boss.id = nextEntityId_++;
        boss.kind = EntityKind::MarshBroodheart;
        boss.x = sx;
        boss.y = sy;
        boss.z = z;
        boss.hp = entityMaxHp(boss.kind);
        boss.facing = Direction::South;
        boss.cooldown = 40;
        entities_.push_back(boss);
        return true;
    }
    addItem(ItemId::WaterBarrel, 1);
    addItem(ItemId::ReedFiber, 3);
    addItem(ItemId::SciencePack, 1);
    return true;
}

bool Simulation::trySummonBadlandsBoss(int x, int y, int z)
{
    const auto lair = world_.lairAt(x, y, z);
    if (!lair || *lair != LairKind::BadlandsFoundry) {
        return false;
    }
    for (const auto& entity : entities_) {
        if (entity.kind == EntityKind::BadlandsWarden && entity.hp > 0) {
            return true;
        }
    }
    if (!bossExamComplete(EntityKind::BadlandsWarden)) {
        return false;
    }
    if (!player_.inventory.canConsume(ItemId::Basalt, 4) ||
        !player_.inventory.canConsume(ItemId::IronPlate, 4) ||
        !player_.inventory.canConsume(ItemId::AdvancedSciencePack, 1)) {
        return false;
    }

    const auto consumedBasalt = consumeItem(ItemId::Basalt, 4);
    const auto consumedIron = consumeItem(ItemId::IronPlate, 4);
    const auto consumedScience = consumeItem(ItemId::AdvancedSciencePack, 1);
    (void)consumedBasalt;
    (void)consumedIron;
    (void)consumedScience;

    constexpr std::array<std::pair<int, int>, 8> kOffsets{{
        {-2, 0},
        {2, 0},
        {0, -2},
        {0, 2},
        {-2, -1},
        {2, 1},
        {-1, 2},
        {1, -2},
    }};
    for (const auto& [offsetX, offsetY] : kOffsets) {
        const int sx = x + offsetX;
        const int sy = y + offsetY;
        if (world_.lairAt(sx, sy, z) != lair ||
            !world_.isWalkable(sx, sy, z) ||
            entityAt(sx, sy, z) != nullptr ||
            machineAt(sx, sy, z) != nullptr) {
            continue;
        }
        Entity boss;
        boss.id = nextEntityId_++;
        boss.kind = EntityKind::BadlandsWarden;
        boss.x = sx;
        boss.y = sy;
        boss.z = z;
        boss.hp = entityMaxHp(boss.kind);
        boss.facing = Direction::South;
        boss.cooldown = 45;
        entities_.push_back(boss);
        return true;
    }
    addItem(ItemId::Basalt, 4);
    addItem(ItemId::IronPlate, 4);
    addItem(ItemId::AdvancedSciencePack, 1);
    return true;
}

bool Simulation::trySummonGlassBoss(int x, int y, int z)
{
    const auto lair = world_.lairAt(x, y, z);
    if (!lair || *lair != LairKind::GlassSpire) {
        return false;
    }
    for (const auto& entity : entities_) {
        if (entity.kind == EntityKind::GlassMaw && entity.hp > 0) {
            return true;
        }
    }
    if (!bossExamComplete(EntityKind::GlassMaw)) {
        return false;
    }
    if (!player_.inventory.canConsume(ItemId::SandGlass, 3) ||
        !player_.inventory.canConsume(ItemId::CactusFiber, 3) ||
        !player_.inventory.canConsume(ItemId::SciencePack, 1)) {
        return false;
    }

    const auto consumedGlass = consumeItem(ItemId::SandGlass, 3);
    const auto consumedCactus = consumeItem(ItemId::CactusFiber, 3);
    const auto consumedScience = consumeItem(ItemId::SciencePack, 1);
    (void)consumedGlass;
    (void)consumedCactus;
    (void)consumedScience;

    constexpr std::array<std::pair<int, int>, 8> kOffsets{{
        {-2, 0},
        {2, 0},
        {0, -2},
        {0, 2},
        {-2, -1},
        {2, 1},
        {-1, 2},
        {1, -2},
    }};
    for (const auto& [offsetX, offsetY] : kOffsets) {
        const int sx = x + offsetX;
        const int sy = y + offsetY;
        if (world_.lairAt(sx, sy, z) != lair ||
            !world_.isWalkable(sx, sy, z) ||
            entityAt(sx, sy, z) != nullptr ||
            machineAt(sx, sy, z) != nullptr) {
            continue;
        }
        Entity boss;
        boss.id = nextEntityId_++;
        boss.kind = EntityKind::GlassMaw;
        boss.x = sx;
        boss.y = sy;
        boss.z = z;
        boss.hp = entityMaxHp(boss.kind);
        boss.facing = Direction::South;
        boss.cooldown = 42;
        entities_.push_back(boss);
        return true;
    }
    addItem(ItemId::SandGlass, 3);
    addItem(ItemId::CactusFiber, 3);
    addItem(ItemId::SciencePack, 1);
    return true;
}

bool Simulation::trySummonFrostBoss(int x, int y, int z)
{
    const auto lair = world_.lairAt(x, y, z);
    if (!lair || *lair != LairKind::FrostVault) {
        return false;
    }
    for (const auto& entity : entities_) {
        if (entity.kind == EntityKind::FrostNullifier && entity.hp > 0) {
            return true;
        }
    }
    if (!bossExamComplete(EntityKind::FrostNullifier)) {
        return false;
    }
    if (!player_.inventory.canConsume(ItemId::IceShard, 4) ||
        !player_.inventory.canConsume(ItemId::CircuitBoard, 2) ||
        !player_.inventory.canConsume(ItemId::AdvancedSciencePack, 1)) {
        return false;
    }

    const auto consumedIce = consumeItem(ItemId::IceShard, 4);
    const auto consumedCircuits = consumeItem(ItemId::CircuitBoard, 2);
    const auto consumedScience = consumeItem(ItemId::AdvancedSciencePack, 1);
    (void)consumedIce;
    (void)consumedCircuits;
    (void)consumedScience;

    constexpr std::array<std::pair<int, int>, 8> kOffsets{{
        {-2, 0},
        {2, 0},
        {0, -2},
        {0, 2},
        {-2, -1},
        {2, 1},
        {-1, 2},
        {1, -2},
    }};
    for (const auto& [offsetX, offsetY] : kOffsets) {
        const int sx = x + offsetX;
        const int sy = y + offsetY;
        if (world_.lairAt(sx, sy, z) != lair ||
            !world_.isWalkable(sx, sy, z) ||
            entityAt(sx, sy, z) != nullptr ||
            machineAt(sx, sy, z) != nullptr) {
            continue;
        }
        Entity boss;
        boss.id = nextEntityId_++;
        boss.kind = EntityKind::FrostNullifier;
        boss.x = sx;
        boss.y = sy;
        boss.z = z;
        boss.hp = entityMaxHp(boss.kind);
        boss.facing = Direction::South;
        boss.cooldown = 48;
        entities_.push_back(boss);
        return true;
    }
    addItem(ItemId::IceShard, 4);
    addItem(ItemId::CircuitBoard, 2);
    addItem(ItemId::AdvancedSciencePack, 1);
    return true;
}

bool Simulation::trySummonRiftBoss(int x, int y, int z)
{
    const auto lair = world_.lairAt(x, y, z);
    if (!lair || *lair != LairKind::CrystalVault) {
        return false;
    }
    if (!bossExamComplete(EntityKind::RiftSignalTyrant)) {
        return false;
    }
    for (const auto& entity : entities_) {
        if (entity.kind == EntityKind::RiftSignalTyrant && entity.hp > 0) {
            return true;
        }
    }
    if (!player_.inventory.canConsume(ItemId::BeaconCore, 1) ||
        !player_.inventory.canConsume(ItemId::Crystal, 2) ||
        !player_.inventory.canConsume(ItemId::AdvancedSciencePack, 2)) {
        return false;
    }

    const auto consumedCore = consumeItem(ItemId::BeaconCore, 1);
    const auto consumedCrystal = consumeItem(ItemId::Crystal, 2);
    const auto consumedScience = consumeItem(ItemId::AdvancedSciencePack, 2);
    (void)consumedCore;
    (void)consumedCrystal;
    (void)consumedScience;

    constexpr std::array<std::pair<int, int>, 8> kOffsets{{
        {-2, 0},
        {2, 0},
        {0, -2},
        {0, 2},
        {-2, -1},
        {2, 1},
        {-1, 2},
        {1, -2},
    }};
    for (const auto& [offsetX, offsetY] : kOffsets) {
        const int sx = x + offsetX;
        const int sy = y + offsetY;
        if (world_.lairAt(sx, sy, z) != lair ||
            !world_.isWalkable(sx, sy, z) ||
            entityAt(sx, sy, z) != nullptr ||
            machineAt(sx, sy, z) != nullptr) {
            continue;
        }
        Entity boss;
        boss.id = nextEntityId_++;
        boss.kind = EntityKind::RiftSignalTyrant;
        boss.x = sx;
        boss.y = sy;
        boss.z = z;
        boss.hp = entityMaxHp(boss.kind);
        boss.facing = Direction::South;
        boss.cooldown = 50;
        entities_.push_back(boss);
        return true;
    }
    addItem(ItemId::BeaconCore, 1);
    addItem(ItemId::Crystal, 2);
    addItem(ItemId::AdvancedSciencePack, 2);
    return true;
}

void Simulation::attack(Direction direction)
{
    const int tx = player_.x + dx(direction);
    const int ty = player_.y + dy(direction);
    for (std::size_t index = 0; index < entities_.size(); ++index) {
        auto& entity = entities_[index];
        if (entity.x != tx || entity.y != ty || entity.z != player_.z || entity.hp <= 0) {
            continue;
        }
        entity.hp -= playerAttackDamage(entity);
        if (entity.hp > 0) {
            return;
        }
        defeatEntity(index);
        return;
    }
}

void Simulation::updateMachines()
{
    updatePowerNetworks();
    updateMiners();
    updateElectricMiners();
    updateBelts();
    updateSplitters();
    updateInserters();
    updateFurnaces();
    updateAssemblers();
    updateLabs();
    updateLogistics();
    updateTrainStops();
    updateFluidPumps();
    updatePipes();
    updateArchiveTerminals();
    updateRiftGates();
    updateRiftStorms();
    updateOutpostBeacons();
    updateGuardTowers();
    updateRepairPylons();
    updatePressureRelays();
    updateArcTowers();
    updateBiomeHazards();
}

void Simulation::updatePowerNetworks()
{
    powerNetworks_.clear();
    poweredMachineIds_.clear();

    for (auto& machine : machines_) {
        if (machine.kind == MachineKind::Generator || machine.kind == MachineKind::PowerPole) {
            machine.status = MachineStatus::Idle;
        }
    }

    std::vector<std::size_t> poleIndices;
    for (std::size_t i = 0; i < machines_.size(); ++i) {
        if (isPowerPole(machines_[i].kind)) {
            poleIndices.push_back(i);
        }
    }

    std::vector<bool> assigned(poleIndices.size(), false);
    for (std::size_t start = 0; start < poleIndices.size(); ++start) {
        if (assigned[start]) {
            continue;
        }

        PowerNetwork network;
        network.id = machines_[poleIndices[start]].id;
        std::vector<std::size_t> group;
        group.push_back(start);
        assigned[start] = true;

        for (std::size_t cursor = 0; cursor < group.size(); ++cursor) {
            const auto& pole = machines_[poleIndices[group[cursor]]];
            network.poleIds.push_back(pole.id);
            network.id = std::min(network.id, pole.id);

            for (std::size_t candidate = 0; candidate < poleIndices.size(); ++candidate) {
                if (assigned[candidate]) {
                    continue;
                }
                const auto& otherPole = machines_[poleIndices[candidate]];
                if (manhattanDistance(pole, otherPole) <= kPowerPoleConnectionRange) {
                    assigned[candidate] = true;
                    group.push_back(candidate);
                }
            }
        }

        for (const auto& machine : machines_) {
            if (isPowerPole(machine.kind)) {
                continue;
            }

            const auto connectedToPole = std::any_of(group.begin(), group.end(), [this, &machine, &poleIndices](std::size_t groupIndex) {
                return manhattanDistance(machine, machines_[poleIndices[groupIndex]]) <= kPowerMachineReach;
            });
            if (!connectedToPole) {
                continue;
            }

            if (machine.kind == MachineKind::Generator) {
                network.generatorIds.push_back(machine.id);
            } else if (isPowerConsumer(machine.kind)) {
                network.consumerIds.push_back(machine.id);
                network.demand += powerDemand(machine.kind);
            }
        }

        if (network.demand > 0) {
            for (const auto generatorId : network.generatorIds) {
                auto* generator = machineById(generatorId);
                if (generator == nullptr) {
                    continue;
                }
                if (!refuel(*generator)) {
                    generator->status = MachineStatus::MissingFuel;
                    continue;
                }
                --generator->fuelTicks;
                generator->status = MachineStatus::Working;
                network.supply += kGeneratorPower;
            }
        }

        network.powered = network.supply >= network.demand;
        if (network.powered) {
            for (const auto consumerId : network.consumerIds) {
                poweredMachineIds_.push_back(consumerId);
            }
        }

        powerNetworks_.push_back(std::move(network));
    }
}

void Simulation::updateMiners()
{
    constexpr int kMinerTicks = 10;
    for (auto& machine : machines_) {
        if (machine.kind != MachineKind::BurnerMiner) {
            continue;
        }

        const auto output = resourceTileOutput(world_.getTile(machine.x, machine.y, machine.z).id);

        if (output == ItemId::None) {
            machine.progress = 0;
            machine.status = MachineStatus::MissingInput;
            continue;
        }

        if (machine.progress >= kMinerTicks) {
            if (outputItem(machine, output)) {
                depleteResourceTile(world_, machine.x, machine.y, machine.z);
                recordProduced(output, machine.kind);
                machine.progress = 0;
                machine.status = MachineStatus::Idle;
            } else {
                machine.status = MachineStatus::OutputBlocked;
            }
            continue;
        }

        if (!refuel(machine)) {
            machine.status = MachineStatus::MissingFuel;
            continue;
        }

        --machine.fuelTicks;
        machine.progress = std::min(machine.progress + 1, kMinerTicks);
        machine.status = MachineStatus::Working;
        if (machine.progress >= kMinerTicks) {
            if (outputItem(machine, output)) {
                depleteResourceTile(world_, machine.x, machine.y, machine.z);
                recordProduced(output, machine.kind);
                machine.progress = 0;
                machine.status = MachineStatus::Idle;
            } else {
                machine.status = MachineStatus::OutputBlocked;
            }
        }
    }
}

void Simulation::updateElectricMiners()
{
    constexpr int kElectricMinerTicks = 8;
    for (auto& machine : machines_) {
        if (machine.kind != MachineKind::ElectricMiner) {
            continue;
        }

        const auto output = resourceTileOutput(world_.getTile(machine.x, machine.y, machine.z).id);

        if (output == ItemId::None) {
            machine.progress = 0;
            machine.status = MachineStatus::MissingInput;
            continue;
        }

        if (machine.progress >= kElectricMinerTicks) {
            if (outputItem(machine, output)) {
                depleteResourceTile(world_, machine.x, machine.y, machine.z);
                recordProduced(output, machine.kind);
                machine.progress = 0;
                machine.status = MachineStatus::Idle;
            } else {
                machine.status = MachineStatus::OutputBlocked;
            }
            continue;
        }

        if (!isMachinePowered(machine.id)) {
            machine.status = MachineStatus::MissingPower;
            continue;
        }

        machine.progress = std::min(machine.progress + 1, kElectricMinerTicks);
        machine.status = MachineStatus::Working;
        if (machine.progress >= kElectricMinerTicks) {
            if (outputItem(machine, output)) {
                depleteResourceTile(world_, machine.x, machine.y, machine.z);
                recordProduced(output, machine.kind);
                machine.progress = 0;
                machine.status = MachineStatus::Idle;
            } else {
                machine.status = MachineStatus::OutputBlocked;
            }
        }
    }
}

void Simulation::updateBelts()
{
    const auto transferPass = [this](bool fastOnly) {
        std::vector<std::uint32_t> sourceIds;
        for (const auto& machine : machines_) {
            if (isBelt(machine.kind) && machine.carriedItem != ItemId::None &&
                (!fastOnly || machine.kind == MachineKind::FastBelt)) {
                sourceIds.push_back(machine.id);
            }
        }

        for (const auto id : sourceIds) {
            auto it = std::find_if(machines_.begin(), machines_.end(), [id](const Machine& machine) {
                return machine.id == id;
            });
            if (it == machines_.end() || it->carriedItem == ItemId::None) {
                continue;
            }

            const auto item = it->carriedItem;
            if (outputItem(*it, item)) {
                it->carriedItem = ItemId::None;
                it->status = MachineStatus::Idle;
            } else {
                it->status = MachineStatus::OutputBlocked;
            }
        }
    };

    transferPass(false);
    transferPass(true);

    for (auto& machine : machines_) {
        if (isBelt(machine.kind) && machine.carriedItem == ItemId::None) {
            machine.status = MachineStatus::Idle;
        }
    }
}

void Simulation::updateSplitters()
{
    std::vector<std::uint32_t> sourceIds;
    for (const auto& machine : machines_) {
        if (machine.kind == MachineKind::Splitter && machine.carriedItem != ItemId::None) {
            sourceIds.push_back(machine.id);
        }
    }

    for (const auto id : sourceIds) {
        auto* machine = machineById(id);
        if (machine == nullptr || machine->carriedItem == ItemId::None) {
            continue;
        }

        const auto item = machine->carriedItem;
        const Direction side = (machine->progress % 2) == 0 ? leftOf(machine->direction) : rightOf(machine->direction);
        const Direction otherSide = (machine->progress % 2) == 0 ? rightOf(machine->direction) : leftOf(machine->direction);
        const std::array<Direction, 3> outputs = {side, machine->direction, otherSide};
        for (const auto outputDirection : outputs) {
            if (acceptItemAt(machine->x + dx(outputDirection), machine->y + dy(outputDirection), machine->z, item)) {
                machine->carriedItem = ItemId::None;
                machine->progress = (machine->progress + 1) % 2;
                machine->status = MachineStatus::Idle;
                break;
            }
        }
        if (machine->carriedItem != ItemId::None) {
            machine->status = MachineStatus::OutputBlocked;
        }
    }
}

void Simulation::updateFurnaces()
{
    constexpr int kFurnaceTicks = 30;
    for (auto& machine : machines_) {
        if (machine.kind != MachineKind::Furnace) {
            continue;
        }

        if (machine.outputItem != ItemId::None) {
            if (outputItem(machine, machine.outputItem)) {
                machine.outputItem = ItemId::None;
                machine.status = MachineStatus::Idle;
            } else {
                machine.status = MachineStatus::OutputBlocked;
                continue;
            }
        }

        if (machine.progress == 0) {
            const auto* recipe = selectedFurnaceRecipe(machine);
            if (recipe == nullptr) {
                machine.status = MachineStatus::MissingInput;
                continue;
            }
            const auto input = furnaceInputItem(*recipe);
            if (input == ItemId::None || !machine.inventory.canConsume(input, 1)) {
                machine.status = MachineStatus::MissingInput;
                continue;
            }
            if (!refuel(machine)) {
                machine.status = MachineStatus::MissingFuel;
                continue;
            }
            const auto consumedOre = machine.inventory.consume(input, 1);
            (void)consumedOre;
            machine.recipeKey = std::string(recipe->key);
        } else if (!refuel(machine)) {
            machine.status = MachineStatus::MissingFuel;
            continue;
        }

        const auto* activeRecipe = selectedFurnaceRecipe(machine);
        if (activeRecipe == nullptr) {
            machine.progress = 0;
            machine.status = MachineStatus::MissingInput;
            continue;
        }
        --machine.fuelTicks;
        machine.progress = std::min(machine.progress + 1, kFurnaceTicks);
        machine.status = MachineStatus::Working;
        if (machine.progress >= kFurnaceTicks) {
            machine.progress = 0;
            machine.outputItem = activeRecipe->output.item;
            recordProduced(activeRecipe->output.item, machine.kind);
            if (!machine.recipeLocked) {
                machine.recipeKey.clear();
            }
        }
    }
}

void Simulation::updateAssemblers()
{
    for (auto& machine : machines_) {
        if (machine.kind != MachineKind::Assembler) {
            continue;
        }

        const auto* recipe = recipeDef(machine.recipeKey.empty() ? "science_pack" : machine.recipeKey);
        if (recipe == nullptr || recipe->station != "assembler") {
            machine.status = MachineStatus::MissingInput;
            continue;
        }

        if (machine.outputItem != ItemId::None) {
            if (outputItem(machine, machine.outputItem)) {
                machine.outputItem = ItemId::None;
                machine.status = MachineStatus::Idle;
            } else {
                machine.status = MachineStatus::OutputBlocked;
                continue;
            }
        }

        if (machine.progress == 0) {
            if (!machine.inventory.consumeAll(recipe->inputs)) {
                machine.status = MachineStatus::MissingInput;
                continue;
            }
        }

        machine.progress = std::min(machine.progress + 1, recipe->ticks);
        machine.status = MachineStatus::Working;
        if (machine.progress >= recipe->ticks) {
            machine.progress = 0;
            machine.outputItem = recipe->output.item;
            recordProduced(recipe->output.item, machine.kind);
        }
    }
}

void Simulation::updateLabs()
{
    const auto* tech = techDef(activeTech_);
    if (tech == nullptr || isTechCompleted(activeTech_)) {
        for (auto& machine : machines_) {
            if (machine.kind == MachineKind::Lab) {
                machine.status = MachineStatus::Idle;
            }
        }
        return;
    }

    for (auto& machine : machines_) {
        if (machine.kind != MachineKind::Lab) {
            continue;
        }
        if (isTechCompleted(activeTech_)) {
            machine.status = MachineStatus::Idle;
            continue;
        }

        if (machine.progress == 0) {
            const auto requiredScience = tech->inputs.empty() ? ItemId::SciencePack : tech->inputs.front().item;
            if (!machine.inventory.consume(requiredScience, 1)) {
                machine.status = MachineStatus::MissingInput;
                continue;
            }
        }

        machine.progress = std::min(machine.progress + 1, tech->ticks);
        machine.status = MachineStatus::Working;
        if (machine.progress >= tech->ticks) {
            machine.progress = 0;
            researchProgress_ = std::min(researchProgress_ + 1, activeTechGoal());
            if (researchProgress_ >= activeTechGoal()) {
                completeActiveTech();
                machine.status = MachineStatus::Idle;
            }
        }
    }
}

void Simulation::updateInserters()
{
    constexpr int kInserterTicks = 15;
    for (auto& machine : machines_) {
        if (machine.kind != MachineKind::Inserter && machine.kind != MachineKind::CircuitInserter) {
            continue;
        }

        machine.progress = std::min(machine.progress + 1, kInserterTicks);
        if (machine.progress < kInserterTicks) {
            continue;
        }

        const int sourceX = machine.x - dx(machine.direction);
        const int sourceY = machine.y - dy(machine.direction);
        const int targetX = machine.x + dx(machine.direction);
        const int targetY = machine.y + dy(machine.direction);
        auto* target = machineAt(targetX, targetY, machine.z);
        if (!circuitConditionAllows(machine, target)) {
            machine.status = MachineStatus::Idle;
            continue;
        }
        const auto item = extractItemAt(sourceX, sourceY, machine.z, machine.kind == MachineKind::CircuitInserter ? machine.filterItem : ItemId::None);
        if (item == ItemId::None) {
            machine.status = MachineStatus::MissingInput;
            continue;
        }

        if (target != nullptr && acceptItem(*target, item)) {
            machine.progress = 0;
            machine.status = MachineStatus::Idle;
            continue;
        }

        machine.status = MachineStatus::OutputBlocked;
        auto* source = machineAt(sourceX, sourceY, machine.z);
        if (source != nullptr) {
            const auto returned = returnItem(*source, item);
            (void)returned;
        }
    }
}

void Simulation::updateLogistics()
{
    const auto poweredPorts = poweredLogisticPortIds();

    for (auto it = logisticJobs_.begin(); it != logisticJobs_.end();) {
        if (!containsId(poweredPorts, it->portId)) {
            ++it;
            continue;
        }
        it->ticksRemaining = std::max(0, it->ticksRemaining - 1);
        if (it->ticksRemaining > 0) {
            ++it;
            continue;
        }

        auto* target = machineById(it->targetId);
        if (target != nullptr && acceptItem(*target, it->item)) {
            ++productionTotals_.logisticDeliveries;
        }
        it = logisticJobs_.erase(it);
    }

    for (const auto portId : poweredPorts) {
        auto* port = machineById(portId);
        if (port == nullptr) {
            continue;
        }
        const int activeJobs = static_cast<int>(std::count_if(
            logisticJobs_.begin(),
            logisticJobs_.end(),
            [portId](const LogisticJob& job) {
                return job.portId == portId;
            }));
        const int activeScout = port->progress > 0 && port->carriedItem != ItemId::None ? 1 : 0;
        int availableDrones = port->inventory.count(ItemId::LogisticDrone) - activeJobs - activeScout;
        while (availableDrones > 0) {
            Machine* selectedRequester = nullptr;
            Machine* selectedProvider = nullptr;
            ItemId selectedItem = ItemId::None;

            for (auto& requester : machines_) {
                if (requester.kind != MachineKind::RequesterChest ||
                    requester.requestItem == ItemId::None ||
                    requester.requestThreshold <= 0 ||
                    requester.inventory.count(requester.requestItem) >= requester.requestThreshold ||
                    manhattanDistance(port->x, port->y, port->z, requester.x, requester.y, requester.z) > kLogisticPortRange) {
                    continue;
                }

                for (auto& provider : machines_) {
                    if (provider.kind != MachineKind::ProviderChest ||
                        provider.inventory.count(requester.requestItem) <= 0 ||
                        manhattanDistance(port->x, port->y, port->z, provider.x, provider.y, provider.z) > kLogisticPortRange) {
                        continue;
                    }
                    selectedRequester = &requester;
                    selectedProvider = &provider;
                    selectedItem = requester.requestItem;
                    break;
                }
                if (selectedRequester != nullptr) {
                    break;
                }
            }

            if (selectedRequester == nullptr || selectedProvider == nullptr || selectedItem == ItemId::None) {
                break;
            }
            if (!selectedProvider->inventory.consume(selectedItem, 1)) {
                break;
            }

            const int distance = manhattanDistance(
                selectedProvider->x,
                selectedProvider->y,
                selectedProvider->z,
                selectedRequester->x,
                selectedRequester->y,
                selectedRequester->z);
            const int totalTicks = std::clamp(distance * 4, kMinLogisticJobTicks, kMaxLogisticJobTicks);
            logisticJobs_.push_back(LogisticJob{
                port->id,
                selectedProvider->id,
                selectedRequester->id,
                selectedItem,
                totalTicks,
                totalTicks});
            --availableDrones;
        }
    }

    updateScoutAutomation(poweredPorts);
}

BiomeKind Simulation::scoutTargetBiome(const Machine& port) const
{
    const auto localBiome = world_.biomeAt(port.x, port.y, port.z);
    if (localBiome != BiomeKind::Grassland &&
        (localBiome != BiomeKind::Rift || productionTotals_.riftJumps > 0) &&
        !hasScoutedBiome(localBiome)) {
        return localBiome;
    }

    for (const auto biome : kScoutBiomes) {
        if (biome == BiomeKind::Rift && productionTotals_.riftJumps <= 0) {
            continue;
        }
        if (!hasScoutedBiome(biome)) {
            return biome;
        }
    }

    const std::size_t unlockedBiomes = productionTotals_.riftJumps > 0 ? kScoutBiomes.size() : kScoutBiomes.size() - 1;
    const auto index = static_cast<std::size_t>((tick_ / kScoutDispatchTicks) + port.id) % unlockedBiomes;
    return kScoutBiomes[index];
}

void Simulation::updateScoutAutomation(const std::vector<std::uint32_t>& poweredPorts)
{
    for (const auto portId : poweredPorts) {
        auto* port = machineById(portId);
        if (port == nullptr || port->kind != MachineKind::LogisticPort) {
            continue;
        }

        const int activeJobs = static_cast<int>(std::count_if(
            logisticJobs_.begin(),
            logisticJobs_.end(),
            [portId](const LogisticJob& job) {
                return job.portId == portId;
            }));
        const int activeScout = port->progress > 0 && port->carriedItem != ItemId::None ? 1 : 0;
        const int availableDrones = port->inventory.count(ItemId::LogisticDrone) - activeJobs - activeScout;
        if (port->progress == 0 && port->carriedItem == ItemId::None) {
            if (availableDrones <= 0) {
                port->status = MachineStatus::MissingInput;
                continue;
            }
            if (!port->inventory.consume(ItemId::SciencePack, 1) &&
                !port->inventory.consume(ItemId::AdvancedSciencePack, 1)) {
                port->status = MachineStatus::MissingInput;
                continue;
            }
            port->carriedItem = scoutRewardForBiome(scoutTargetBiome(*port));
        }

        if (port->carriedItem == ItemId::None) {
            continue;
        }

        const int charge = 1 + (riftStormActive() ? 1 : 0);
        port->progress = std::min(port->progress + charge, kScoutDispatchTicks);
        port->status = MachineStatus::Working;
        if (port->progress < kScoutDispatchTicks) {
            continue;
        }

        const auto biome = scoutBiomeForReward(port->carriedItem).value_or(scoutTargetBiome(*port));
        int recovered = scoutRewardCountForBiome(biome);
        if (world_.biomeAt(port->x, port->y, port->z) == biome) {
            ++recovered;
        }
        if (hasActivatedOutpostBiome(biome)) {
            ++recovered;
        }
        if (!port->inventory.add(port->carriedItem, recovered)) {
            port->status = MachineStatus::OutputBlocked;
            continue;
        }
        productionTotals_.scoutedBiomeMask |= biomeMask(biome);
        ++productionTotals_.scoutDispatches;
        productionTotals_.scoutMaterialsRecovered += recovered;
        port->progress = 0;
        port->carriedItem = ItemId::None;
        port->status = MachineStatus::Idle;
    }
}

void Simulation::updateTrainStops()
{
    std::vector<std::uint32_t> stopIds;
    for (const auto& machine : machines_) {
        if (machine.kind == MachineKind::TrainStop) {
            stopIds.push_back(machine.id);
        }
    }
    if (stopIds.size() < 2) {
        for (const auto id : stopIds) {
            if (auto* stop = machineById(id)) {
                stop->status = MachineStatus::MissingInput;
            }
        }
        return;
    }
    std::sort(stopIds.begin(), stopIds.end());

    for (std::size_t index = 0; index < stopIds.size(); ++index) {
        auto* stop = machineById(stopIds[index]);
        auto* target = machineById(stopIds[(index + 1U) % stopIds.size()]);
        if (stop == nullptr || target == nullptr) {
            continue;
        }
        if (stop->inventory.stacks().empty()) {
            stop->progress = 0;
            stop->status = MachineStatus::MissingInput;
            continue;
        }
        stop->progress = std::min(stop->progress + 1, kTrainStopTicks);
        stop->status = MachineStatus::Working;
        if (stop->progress < kTrainStopTicks) {
            continue;
        }
        const auto stacks = stop->inventory.stacks();
        const auto item = stacks.empty() ? ItemId::None : stacks.front().item;
        if (item != ItemId::None && target->inventory.add(item, 1) && stop->inventory.consume(item, 1)) {
            ++productionTotals_.trainDeliveries;
            stop->progress = 0;
            stop->status = MachineStatus::Idle;
        } else {
            stop->status = MachineStatus::OutputBlocked;
        }
    }
}

void Simulation::updateFluidPumps()
{
    for (auto& machine : machines_) {
        if (machine.kind != MachineKind::OffshorePump) {
            continue;
        }
        if (!hasAdjacentWater(machine.x, machine.y, machine.z)) {
            machine.progress = 0;
            machine.status = MachineStatus::MissingInput;
            continue;
        }
        machine.progress = std::min(machine.progress + 1, kPumpTicks);
        machine.status = MachineStatus::Working;
        if (machine.progress < kPumpTicks) {
            continue;
        }
        if (outputItem(machine, ItemId::WaterBarrel)) {
            ++productionTotals_.waterBarrels;
            machine.progress = 0;
            machine.status = MachineStatus::Idle;
        } else {
            machine.status = MachineStatus::OutputBlocked;
        }
    }
}

void Simulation::updatePipes()
{
    std::vector<std::uint32_t> sourceIds;
    for (const auto& machine : machines_) {
        if (isPipe(machine.kind) && machine.carriedItem != ItemId::None) {
            sourceIds.push_back(machine.id);
        }
    }
    for (const auto id : sourceIds) {
        auto* pipe = machineById(id);
        if (pipe == nullptr || pipe->carriedItem == ItemId::None) {
            continue;
        }
        pipe->progress = std::min(pipe->progress + 1, kPipeTicks);
        if (pipe->progress < kPipeTicks) {
            pipe->status = MachineStatus::Working;
            continue;
        }
        const auto item = pipe->carriedItem;
        if (outputItem(*pipe, item)) {
            pipe->carriedItem = ItemId::None;
            pipe->progress = 0;
            pipe->status = MachineStatus::Idle;
        } else {
            pipe->status = MachineStatus::OutputBlocked;
        }
    }
}

void Simulation::updateArchiveTerminals()
{
    for (auto& machine : machines_) {
        if (machine.kind != MachineKind::ArchiveTerminal) {
            continue;
        }
        if (!isMachinePowered(machine.id)) {
            machine.status = MachineStatus::MissingPower;
            continue;
        }
        if (machine.progress == 0 && !machine.inventory.consume(ItemId::BeaconCore, 1)) {
            machine.status = MachineStatus::MissingInput;
            continue;
        }
        machine.progress = std::min(machine.progress + 1, kArchiveTerminalTicks);
        machine.status = MachineStatus::Working;
        if (machine.progress >= kArchiveTerminalTicks) {
            ++productionTotals_.archiveSignals;
            machine.progress = 0;
            machine.status = MachineStatus::Idle;
        }
    }
}

void Simulation::updateRiftGates()
{
    for (auto& machine : machines_) {
        if (machine.kind != MachineKind::RiftGate) {
            continue;
        }
        if (!isMachinePowered(machine.id)) {
            machine.status = MachineStatus::MissingPower;
            continue;
        }
        if (machine.progress == 0 && !machine.inventory.consume(ItemId::BeaconCore, 1)) {
            machine.status = MachineStatus::MissingInput;
            continue;
        }
        const int goalTicks = machine.socketedRelic == ItemId::RiftCrown ? kRiftCrownGateTicks : kRiftGateTicks;
        machine.progress = std::min(machine.progress + 1 + riftStormChargeBonus(machine), goalTicks);
        machine.status = MachineStatus::Working;
        if (machine.progress < goalTicks) {
            continue;
        }
        player_.x += player_.x >= (kRiftOffset / 2) ? -kRiftOffset : kRiftOffset;
        ++productionTotals_.riftJumps;
        startRiftStorm(currentRiftStormSeverity());
        machine.progress = 0;
        machine.status = MachineStatus::Idle;
    }
}

void Simulation::updateOutpostBeacons()
{
    for (auto& machine : machines_) {
        if (machine.kind != MachineKind::OutpostBeacon) {
            continue;
        }
        if (machine.progress >= kOutpostBeaconTicks) {
            if (!isMachinePowered(machine.id)) {
                machine.status = MachineStatus::MissingPower;
                continue;
            }
            const auto deliveryItem = outpostActivationItem(world_.biomeAt(machine.x, machine.y, machine.z));
            if (!machine.inventory.canConsume(deliveryItem, 1)) {
                machine.progress = kOutpostBeaconTicks;
                machine.status = MachineStatus::Idle;
                continue;
            }
            const int deliveryTicks = machine.socketedRelic == ItemId::RiftCrown ? 70 : kOutpostDeliveryTicks;
            machine.progress = std::min(machine.progress + 1, kOutpostBeaconTicks + deliveryTicks);
            machine.status = MachineStatus::Working;
            if (machine.progress < kOutpostBeaconTicks + deliveryTicks) {
                continue;
            }
            const auto delivered = machine.inventory.consume(deliveryItem, 1);
            (void)delivered;
            ++productionTotals_.outpostDeliveries;
            productionTotals_.outpostDeliveryBiomeMask |= biomeMask(world_.biomeAt(machine.x, machine.y, machine.z));
            machine.progress = kOutpostBeaconTicks;
            machine.status = MachineStatus::Idle;
            continue;
        }
        if (!isMachinePowered(machine.id)) {
            machine.status = MachineStatus::MissingPower;
            continue;
        }
        const auto activationItem = outpostActivationItem(world_.biomeAt(machine.x, machine.y, machine.z));
        if (machine.progress == 0 && !machine.inventory.consume(activationItem, 1)) {
            machine.status = MachineStatus::MissingInput;
            continue;
        }
        machine.progress = std::min(machine.progress + 1, kOutpostBeaconTicks);
        machine.status = MachineStatus::Working;
        if (machine.progress >= kOutpostBeaconTicks) {
            ++productionTotals_.outpostsActivated;
            productionTotals_.outpostBiomeMask |= biomeMask(world_.biomeAt(machine.x, machine.y, machine.z));
            machine.status = MachineStatus::Idle;
        }
    }
}

void Simulation::updateGuardTowers()
{
    for (auto& machine : machines_) {
        if (machine.kind != MachineKind::GuardTower) {
            continue;
        }
        if (!isMachinePowered(machine.id)) {
            machine.progress = 0;
            machine.status = MachineStatus::MissingPower;
            continue;
        }

        std::size_t targetIndex = entities_.size();
        int bestDistance = kGuardTowerRange + 1;
        for (std::size_t index = 0; index < entities_.size(); ++index) {
            const auto& entity = entities_[index];
            if (entity.z != machine.z || !isHostile(entity.kind) || entity.hp <= 0) {
                continue;
            }
            const int distance = manhattanDistance(machine.x, machine.y, machine.z, entity.x, entity.y, entity.z);
            if (distance <= kGuardTowerRange && distance < bestDistance) {
                targetIndex = index;
                bestDistance = distance;
            }
        }

        if (targetIndex == entities_.size()) {
            machine.progress = 0;
            machine.status = MachineStatus::MissingInput;
            continue;
        }

        const int goalTicks = machine.socketedRelic == ItemId::WardenCore ? 35 : kGuardTowerTicks;
        machine.progress = std::min(machine.progress + 1, goalTicks);
        machine.status = MachineStatus::Working;
        if (machine.progress < goalTicks) {
            continue;
        }

        int damage = entities_[targetIndex].kind == EntityKind::BadlandsWarden ? 1 : 2;
        if (machine.socketedRelic == ItemId::WardenCore) {
            ++damage;
        }
        entities_[targetIndex].hp -= damage;
        machine.progress = 0;
        if (entities_[targetIndex].hp <= 0) {
            defeatEntity(targetIndex);
        }
    }
}

void Simulation::updateArcTowers()
{
    for (auto& machine : machines_) {
        if (machine.kind != MachineKind::ArcTower) {
            continue;
        }
        if (!isMachinePowered(machine.id)) {
            machine.progress = 0;
            machine.status = MachineStatus::MissingPower;
            continue;
        }

        std::size_t targetIndex = entities_.size();
        int bestDistance = kArcTowerRange + 1;
        for (std::size_t index = 0; index < entities_.size(); ++index) {
            const auto& entity = entities_[index];
            if (entity.z != machine.z || !isHostile(entity.kind) || entity.hp <= 0) {
                continue;
            }
            const int distance = manhattanDistance(machine.x, machine.y, machine.z, entity.x, entity.y, entity.z);
            if (distance <= kArcTowerRange && distance < bestDistance) {
                targetIndex = index;
                bestDistance = distance;
            }
        }

        if (targetIndex == entities_.size()) {
            machine.progress = 0;
            machine.status = MachineStatus::MissingInput;
            continue;
        }

        const int goalTicks = machine.socketedRelic == ItemId::FrostCore ? 20 : kArcTowerTicks;
        machine.progress = std::min(machine.progress + 1, goalTicks);
        machine.status = MachineStatus::Working;
        if (machine.progress < goalTicks) {
            continue;
        }

        entities_[targetIndex].hp -= machine.socketedRelic == ItemId::FrostCore ? 5 : 4;
        machine.progress = 0;
        if (entities_[targetIndex].hp <= 0) {
            defeatEntity(targetIndex);
        }
    }
}

void Simulation::updateRepairPylons()
{
    enum class RepairTargetKind {
        DamagedMachine,
        DamagedTile,
        WallGap,
    };

    struct RepairTarget {
        RepairTargetKind kind = RepairTargetKind::WallGap;
        int x = 0;
        int y = 0;
        int z = 0;
        std::uint32_t machineId = 0;
        TileId tile = TileId::Wall;
    };

    constexpr std::array<Direction, 4> kDirections{{
        Direction::North,
        Direction::East,
        Direction::South,
        Direction::West,
    }};

    const auto findTarget = [this, &kDirections](const Machine& pylon) -> std::optional<RepairTarget> {
        for (const auto direction : kDirections) {
            const int x = pylon.x + dx(direction);
            const int y = pylon.y + dy(direction);
            auto* machine = machineAt(x, y, pylon.z);
            if (machine == nullptr || machine->id == pylon.id) {
                continue;
            }
            const int maxDurability = machineMaxDurability(machine->kind);
            if (machine->durability > 0 && machine->durability < maxDurability) {
                return RepairTarget{RepairTargetKind::DamagedMachine, x, y, pylon.z, machine->id, TileId::Wall};
            }
        }

        for (const auto direction : kDirections) {
            const int x = pylon.x + dx(direction);
            const int y = pylon.y + dy(direction);
            if (machineAt(x, y, pylon.z) != nullptr || entityAt(x, y, pylon.z) != nullptr) {
                continue;
            }
            const auto tile = world_.getTile(x, y, pylon.z);
            const int maxDurability = tileMaxDurability(tile.id);
            if (isDamageableStructureTile(tile.id) && tile.data > 0 && tile.data < maxDurability) {
                return RepairTarget{RepairTargetKind::DamagedTile, x, y, pylon.z, 0, tile.id};
            }
        }

        for (const auto direction : kDirections) {
            const int x = pylon.x + dx(direction);
            const int y = pylon.y + dy(direction);
            if (machineAt(x, y, pylon.z) != nullptr || entityAt(x, y, pylon.z) != nullptr) {
                continue;
            }
            if (isRepairableWallGap(world_.getTile(x, y, pylon.z).id)) {
                return RepairTarget{RepairTargetKind::WallGap, x, y, pylon.z, 0, TileId::Wall};
            }
        }
        return std::nullopt;
    };

    const auto consumeMaterial = [](Machine& pylon, const RepairTarget& target) {
        if (target.kind == RepairTargetKind::WallGap) {
            if (pylon.inventory.consume(ItemId::Wall, 1)) {
                return ItemId::Wall;
            }
            if (pylon.inventory.consume(ItemId::PlankWall, 1)) {
                return ItemId::PlankWall;
            }
            return ItemId::None;
        }
        if (target.kind == RepairTargetKind::DamagedMachine || target.tile == TileId::Door) {
            return pylon.inventory.consume(ItemId::IronPlate, 1) ? ItemId::IronPlate : ItemId::None;
        }
        if (target.tile == TileId::PlankWall) {
            return pylon.inventory.consume(ItemId::PlankWall, 1) ? ItemId::PlankWall : ItemId::None;
        }
        return pylon.inventory.consume(ItemId::Wall, 1) ? ItemId::Wall : ItemId::None;
    };

    for (auto& machine : machines_) {
        if (machine.kind != MachineKind::RepairPylon) {
            continue;
        }
        if (!isMachinePowered(machine.id)) {
            machine.status = MachineStatus::MissingPower;
            continue;
        }
        const auto target = findTarget(machine);
        if (!target) {
            machine.progress = 0;
            machine.carriedItem = ItemId::None;
            machine.status = MachineStatus::Idle;
            continue;
        }
        if (machine.progress == 0) {
            machine.carriedItem = consumeMaterial(machine, *target);
            if (machine.carriedItem == ItemId::None) {
                machine.status = MachineStatus::MissingInput;
                continue;
            }
        }
        const int goalTicks = machine.socketedRelic == ItemId::MarshHeart ? 40 : kRepairPylonTicks;
        machine.progress = std::min(machine.progress + 1, goalTicks);
        machine.status = MachineStatus::Working;
        if (machine.progress < goalTicks) {
            continue;
        }
        if (target->kind == RepairTargetKind::DamagedMachine) {
            if (auto* repaired = machineById(target->machineId); repaired != nullptr) {
                repaired->durability = machineMaxDurability(repaired->kind);
            }
        } else if (target->kind == RepairTargetKind::DamagedTile) {
            world_.setTile(target->x, target->y, target->z, Tile{target->tile, tileMaxDurability(target->tile)});
        } else {
            const auto wall = machine.carriedItem == ItemId::PlankWall ? TileId::PlankWall : TileId::Wall;
            world_.setTile(target->x, target->y, target->z, Tile{wall, 0});
        }
        machine.progress = 0;
        machine.carriedItem = ItemId::None;
        machine.status = MachineStatus::Idle;
    }
}

void Simulation::updatePressureRelays()
{
    for (auto& machine : machines_) {
        if (machine.kind != MachineKind::PressureRelay) {
            continue;
        }
        if (!isMachinePowered(machine.id)) {
            machine.status = MachineStatus::MissingPower;
            continue;
        }
        if (machine.progress == 0 && !machine.inventory.consume(ItemId::AdvancedSciencePack, 1)) {
            machine.status = MachineStatus::MissingInput;
            continue;
        }
        const int goalTicks = machine.socketedRelic == ItemId::GlassHeart ? 90 : kPressureRelayTicks;
        machine.progress = std::min(machine.progress + 1, goalTicks);
        machine.status = MachineStatus::Working;
        if (machine.progress < goalTicks) {
            continue;
        }
        productionTotals_.pressureWavesRepelled += machine.socketedRelic == ItemId::GlassHeart ? 2 : 1;
        machine.progress = 0;
        machine.status = MachineStatus::Idle;
    }
}

bool Simulation::riftStormActive() const
{
    return riftStorm_.severity > 0 && riftStorm_.ticksRemaining > 0;
}

int Simulation::currentRiftStormSeverity() const
{
    int severity = 1 + std::min(3, productionTotals_.riftJumps / 2);
    if (factoryPressureLevel() >= 220) {
        ++severity;
    }
    if (world_.biomeAt(player_.x, player_.y, player_.z) == BiomeKind::Rift) {
        ++severity;
    }
    if (hasActivatedOutpostBiome(BiomeKind::Rift)) {
        --severity;
    }
    if (productionTotals_.pressureWavesRepelled >= 3) {
        --severity;
    }
    return std::clamp(severity, 1, 4);
}

int Simulation::riftStormChargeBonus(const Machine& machine) const
{
    if (!riftStormActive() || machine.kind != MachineKind::RiftGate) {
        return 0;
    }
    if (machine.socketedRelic == ItemId::RiftCrown) {
        return 1 + (riftStorm_.severity / 2);
    }
    return 1;
}

void Simulation::startRiftStorm(int severity)
{
    const int normalizedSeverity = std::clamp(severity, 1, 4);
    const int duration = kRiftStormBaseTicks + (normalizedSeverity * 30);
    ++productionTotals_.riftStormsTriggered;

    if (riftStormActive()) {
        riftStorm_.severity = std::max(riftStorm_.severity, normalizedSeverity);
        riftStorm_.ticksRemaining = std::max(riftStorm_.ticksRemaining, duration);
        riftStorm_.cooldownTicks = std::max(riftStorm_.cooldownTicks, kRiftStormCooldownTicks);
        return;
    }

    riftStorm_.severity = normalizedSeverity;
    riftStorm_.ticksRemaining = duration;
    riftStorm_.cooldownTicks = kRiftStormCooldownTicks;
}

void Simulation::updateRiftStorms()
{
    if (!riftStormActive()) {
        if (riftStorm_.cooldownTicks > 0) {
            --riftStorm_.cooldownTicks;
        }
        if (productionTotals_.riftJumps > 0 &&
            riftStorm_.cooldownTicks == 0 &&
            tick_ > 0 &&
            world_.biomeAt(player_.x, player_.y, player_.z) == BiomeKind::Rift &&
            (tick_ % 240U) == 0U) {
            startRiftStorm(currentRiftStormSeverity());
        }
        return;
    }

    const int severity = std::clamp(riftStorm_.severity, 1, 4);
    if (tick_ > 0 && (tick_ % static_cast<std::uint64_t>(kRiftStormSpawnCadence)) == 0U) {
        int spawnBudget = std::min(3, 1 + (severity / 2));
        if (world_.biomeAt(player_.x, player_.y, player_.z) == BiomeKind::Rift &&
            spawnBudget > 0 &&
            spawnEntityNear(player_.x, player_.y, player_.z, EntityKind::RiftStalker, 7)) {
            --spawnBudget;
        }
        for (const auto& machine : machines_) {
            if (spawnBudget <= 0) {
                break;
            }
            if (machine.kind != MachineKind::RiftGate ||
                machine.socketedRelic == ItemId::RiftCrown) {
                continue;
            }
            const auto biome = world_.biomeAt(machine.x, machine.y, machine.z);
            if (hasActivatedOutpostBiome(biome) && severity <= 2) {
                continue;
            }
            if (spawnEntityNear(machine.x, machine.y, machine.z, EntityKind::RiftStalker, 5)) {
                --spawnBudget;
            }
        }
    }

    if (tick_ > 0 && (tick_ % static_cast<std::uint64_t>(kRiftStormJoltCadence)) == 0U) {
        for (auto& machine : machines_) {
            if (machine.kind != MachineKind::RiftGate || machine.progress <= 0) {
                continue;
            }
            if (machine.socketedRelic == ItemId::RiftCrown) {
                machine.progress = std::min(machine.progress + severity * 2, kRiftCrownGateTicks);
                machine.status = MachineStatus::Working;
                continue;
            }
            machine.progress = std::max(0, machine.progress - severity);
            machine.status = MachineStatus::OutputBlocked;
        }
    }

    --riftStorm_.ticksRemaining;
    if (riftStorm_.ticksRemaining <= 0) {
        riftStorm_.severity = 0;
        riftStorm_.ticksRemaining = 0;
        riftStorm_.cooldownTicks = std::max(riftStorm_.cooldownTicks, kRiftStormCooldownTicks);
        ++productionTotals_.riftStormsSurvived;
    }
}

void Simulation::updateBiomeHazards()
{
    if (tick_ == 0) {
        return;
    }

    const int pressure = factoryPressureLevel();
    std::vector<std::uint32_t> destroyedMachineIds;
    for (auto& machine : machines_) {
        const auto biome = world_.biomeAt(machine.x, machine.y, machine.z);
        const int level = biomeHazardLevel(pressure, hasActivatedOutpostBiome(biome));

        if (biome == BiomeKind::Marsh) {
            const int cadence = hazardCadence(kMarshRotBaseTicks, level);
            if ((tick_ % static_cast<std::uint64_t>(cadence)) != 0U) {
                continue;
            }
            for (const auto& stack : machine.inventory.stacks()) {
                if (isOrganicHazardItem(stack.item) && machine.inventory.consume(stack.item, 1)) {
                    machine.status = MachineStatus::OutputBlocked;
                    break;
                }
            }
            continue;
        }

        if (biome == BiomeKind::Desert) {
            if (!isHeatSensitiveMachine(machine.kind)) {
                continue;
            }
            const int cadence = hazardCadence(kDesertHeatBaseTicks, level);
            if ((tick_ % static_cast<std::uint64_t>(cadence)) != 0U) {
                continue;
            }
            if (machine.inventory.consume(ItemId::WaterBarrel, 1)) {
                continue;
            }
            const int maxDurability = machineMaxDurability(machine.kind);
            if (machine.durability <= 0) {
                machine.durability = maxDurability;
            }
            machine.durability -= level >= 3 ? 2 : 1;
            machine.status = MachineStatus::MissingInput;
            if (machine.durability <= 0) {
                destroyedMachineIds.push_back(machine.id);
            }
            continue;
        }

        if (biome == BiomeKind::Badlands) {
            if (!isActiveIndustrialMachine(machine)) {
                continue;
            }
            const int cadence = hazardCadence(kBadlandsSlagBaseTicks, level);
            if ((tick_ % static_cast<std::uint64_t>(cadence)) == 0U) {
                const auto added = machine.inventory.add(ItemId::Basalt, level >= 3 ? 2 : 1);
                (void)added;
            }
            continue;
        }

        if (biome == BiomeKind::Snowfield) {
            if (machine.progress <= 0 || machine.inventory.count(ItemId::Coal) > 0 || machine.fuelTicks > 0) {
                continue;
            }
            const int cadence = hazardCadence(kSnowfieldFreezeBaseTicks, level);
            if ((tick_ % static_cast<std::uint64_t>(cadence)) == 0U) {
                machine.progress = std::max(0, machine.progress - level);
                machine.status = MachineStatus::MissingFuel;
            }
            continue;
        }

        if (biome == BiomeKind::CrystalField) {
            if (!isActiveIndustrialMachine(machine) || machine.progress <= 0) {
                continue;
            }
            const int cadence = hazardCadence(kCrystalResonanceBaseTicks, level);
            if ((tick_ % static_cast<std::uint64_t>(cadence)) != 0U) {
                continue;
            }
            machine.progress += level;
            if (level >= 2 && (tick_ % static_cast<std::uint64_t>(cadence * 2)) == 0U) {
                (void)spawnEntityNear(machine.x, machine.y, machine.z, EntityKind::NullWisp, 4);
            }
        }
    }

    if (destroyedMachineIds.empty()) {
        return;
    }
    machines_.erase(
        std::remove_if(
            machines_.begin(),
            machines_.end(),
            [&destroyedMachineIds](const Machine& machine) {
                return containsId(destroyedMachineIds, machine.id);
            }),
        machines_.end());
    rebuildMachineCellIndex();
}

bool Simulation::canPlaceMachine(MachineKind kind, int x, int y) const
{
    return canPlaceMachine(kind, x, y, 0);
}

bool Simulation::canPlaceMachine(MachineKind kind, int x, int y, int z) const
{
    const auto& def = machineDef(kind);
    for (int oy = 0; oy < def.height; ++oy) {
        for (int ox = 0; ox < def.width; ++ox) {
            const int tx = x + ox;
            const int ty = y + oy;
            if (machineAt(tx, ty, z) != nullptr) {
                return false;
            }

            const auto tile = world_.getTile(tx, ty, z);
            if (def.requiresResourceTile) {
                if (resourceTileOutput(tile.id) == ItemId::None) {
                    return false;
                }
                continue;
            }

            if (def.requiresBuildableTile && (!tileDef(tile.id).walkable || !tileDef(tile.id).buildable)) {
                return false;
            }
        }
    }
    return true;
}

bool Simulation::acceptItemAt(int x, int y, ItemId item)
{
    return acceptItemAt(x, y, 0, item);
}

bool Simulation::acceptItemAt(int x, int y, int z, ItemId item)
{
    auto* machine = machineAt(x, y, z);
    if (machine == nullptr) {
        return false;
    }
    return acceptItem(*machine, item);
}

bool Simulation::acceptItem(Machine& machine, ItemId item)
{
    if (item == ItemId::None) {
        return false;
    }
    if (machine.socketedRelic == ItemId::None && canSocketRelic(machine.kind, item)) {
        machine.socketedRelic = item;
        return true;
    }

    switch (machine.kind) {
    case MachineKind::Belt:
    case MachineKind::FastBelt:
    case MachineKind::Splitter:
        if (machine.carriedItem != ItemId::None) {
            return false;
        }
        machine.carriedItem = item;
        return true;
    case MachineKind::Pipe:
        if (item != ItemId::WaterBarrel || machine.carriedItem != ItemId::None) {
            return false;
        }
        machine.carriedItem = item;
        return true;
    case MachineKind::Chest:
    case MachineKind::ProviderChest:
    case MachineKind::RequesterChest:
    case MachineKind::TrainStop:
        return machine.inventory.add(item, 1);
    case MachineKind::Inserter:
    case MachineKind::CircuitInserter:
        return false;
    case MachineKind::BurnerMiner:
        if (item != ItemId::Coal) {
            return false;
        }
        return machine.inventory.add(item, 1);
    case MachineKind::Furnace:
        if (item == ItemId::Coal) {
            return machine.inventory.add(item, 1);
        }
        if (machine.recipeLocked && !machine.recipeKey.empty()) {
            const auto* recipe = recipeDef(machine.recipeKey);
            if (recipe == nullptr || recipe->station != "furnace" || furnaceInputItem(*recipe) != item) {
                return false;
            }
            return machine.inventory.add(item, 1);
        }
        if (furnaceRecipeForInput(item) == nullptr) {
            return false;
        }
        return machine.inventory.add(item, 1);
    case MachineKind::Workbench:
        return false;
    case MachineKind::Assembler:
        if (!isRecipeInput(machine.recipeKey.empty() ? "science_pack" : machine.recipeKey, item)) {
            return false;
        }
        return machine.inventory.add(item, 1);
    case MachineKind::Lab:
        if (!isScienceItem(item)) {
            return false;
        }
        return machine.inventory.add(item, 1);
    case MachineKind::Generator:
        if (item != ItemId::Coal) {
            return false;
        }
        return machine.inventory.add(item, 1);
    case MachineKind::LogisticPort:
        if (item != ItemId::LogisticDrone) {
            return false;
        }
        return machine.inventory.add(item, 1);
    case MachineKind::ArchiveTerminal:
    case MachineKind::RiftGate:
        if (item != ItemId::BeaconCore) {
            return false;
        }
        return machine.inventory.add(item, 1);
    case MachineKind::OutpostBeacon:
        return item == outpostActivationItem(world_.biomeAt(machine.x, machine.y, machine.z)) &&
            machine.inventory.add(item, 1);
    case MachineKind::RepairPylon:
        return (item == ItemId::Wall || item == ItemId::PlankWall || item == ItemId::IronPlate) &&
            machine.inventory.add(item, 1);
    case MachineKind::PressureRelay:
        return item == ItemId::AdvancedSciencePack && machine.inventory.add(item, 1);
    case MachineKind::PowerPole:
    case MachineKind::ElectricMiner:
    case MachineKind::OffshorePump:
    case MachineKind::GuardTower:
    case MachineKind::ArcTower:
        return false;
    }
    return false;
}

ItemId Simulation::extractItemAt(int x, int y, ItemId filterItem)
{
    return extractItemAt(x, y, 0, filterItem);
}

ItemId Simulation::extractItemAt(int x, int y, int z, ItemId filterItem)
{
    auto* machine = machineAt(x, y, z);
    if (machine == nullptr) {
        return ItemId::None;
    }
    return extractItem(*machine, filterItem);
}

ItemId Simulation::extractItem(Machine& machine, ItemId filterItem)
{
    if (isBelt(machine.kind) || machine.kind == MachineKind::Splitter || isPipe(machine.kind)) {
        const auto item = machine.carriedItem;
        if (filterItem != ItemId::None && item != filterItem) {
            return ItemId::None;
        }
        machine.carriedItem = ItemId::None;
        return item;
    }

    if (machine.kind == MachineKind::Furnace || machine.kind == MachineKind::Assembler) {
        const auto item = machine.outputItem;
        if (filterItem != ItemId::None && item != filterItem) {
            return ItemId::None;
        }
        machine.outputItem = ItemId::None;
        return item;
    }

    if (machine.kind == MachineKind::Chest || machine.kind == MachineKind::ProviderChest ||
        machine.kind == MachineKind::RequesterChest || machine.kind == MachineKind::TrainStop) {
        const auto stacks = machine.inventory.stacks();
        if (stacks.empty()) {
            return ItemId::None;
        }
        const auto item = filterItem == ItemId::None ? stacks.front().item : filterItem;
        if (machine.inventory.consume(item, 1)) {
            return item;
        }
    }

    return ItemId::None;
}

bool Simulation::returnItem(Machine& machine, ItemId item)
{
    if (item == ItemId::None) {
        return false;
    }

    if ((machine.kind == MachineKind::Furnace || machine.kind == MachineKind::Assembler) &&
        machine.outputItem == ItemId::None) {
        machine.outputItem = item;
        return true;
    }

    return acceptItem(machine, item);
}

bool Simulation::outputItem(Machine& machine, ItemId item)
{
    return acceptItemAt(machine.x + dx(machine.direction), machine.y + dy(machine.direction), machine.z, item);
}

bool Simulation::refuel(Machine& machine)
{
    if (machine.fuelTicks > 0) {
        return true;
    }
    if (!machine.inventory.consume(ItemId::Coal, 1)) {
        return false;
    }
    machine.fuelTicks = kCoalFuelTicks;
    return true;
}

bool Simulation::isBelt(MachineKind kind) const
{
    return kind == MachineKind::Belt || kind == MachineKind::FastBelt;
}

bool Simulation::isPipe(MachineKind kind) const
{
    return kind == MachineKind::Pipe;
}

bool Simulation::isPowerPole(MachineKind kind) const
{
    return kind == MachineKind::PowerPole;
}

bool Simulation::isPowerConsumer(MachineKind kind) const
{
    return kind == MachineKind::ElectricMiner ||
        kind == MachineKind::LogisticPort ||
        kind == MachineKind::ArchiveTerminal ||
        kind == MachineKind::RiftGate ||
        kind == MachineKind::GuardTower ||
        kind == MachineKind::OutpostBeacon ||
        kind == MachineKind::RepairPylon ||
        kind == MachineKind::PressureRelay ||
        kind == MachineKind::ArcTower;
}

bool Simulation::isLogisticStorage(MachineKind kind) const
{
    return kind == MachineKind::ProviderChest || kind == MachineKind::RequesterChest;
}

int Simulation::machineMaxDurability(MachineKind kind) const
{
    switch (kind) {
    case MachineKind::Belt:
    case MachineKind::FastBelt:
    case MachineKind::Inserter:
    case MachineKind::CircuitInserter:
    case MachineKind::Splitter:
    case MachineKind::Pipe:
        return 3;
    case MachineKind::PowerPole:
    case MachineKind::Chest:
    case MachineKind::ProviderChest:
    case MachineKind::RequesterChest:
    case MachineKind::Workbench:
    case MachineKind::OffshorePump:
        return 4;
    case MachineKind::BurnerMiner:
    case MachineKind::Furnace:
    case MachineKind::ElectricMiner:
    case MachineKind::Assembler:
    case MachineKind::Lab:
    case MachineKind::Generator:
    case MachineKind::LogisticPort:
    case MachineKind::TrainStop:
        return 5;
    case MachineKind::ArchiveTerminal:
    case MachineKind::GuardTower:
    case MachineKind::OutpostBeacon:
    case MachineKind::RepairPylon:
    case MachineKind::PressureRelay:
    case MachineKind::ArcTower:
        return 6;
    case MachineKind::RiftGate:
        return 8;
    }
    return 4;
}

int Simulation::tileMaxDurability(TileId id) const
{
    switch (id) {
    case TileId::PlankWall:
        return 4;
    case TileId::Door:
        return 5;
    case TileId::Wall:
        return 6;
    case TileId::Dirt:
    case TileId::Floor:
    case TileId::Grass:
    case TileId::Beach:
    case TileId::Mud:
    case TileId::Sand:
    case TileId::Snow:
    case TileId::Ice:
    case TileId::Water:
    case TileId::DeepWater:
    case TileId::Coral:
    case TileId::Stone:
    case TileId::Basalt:
    case TileId::Crystal:
    case TileId::IronOre:
    case TileId::CopperOre:
    case TileId::CoalOre:
    case TileId::Tree:
    case TileId::Reeds:
    case TileId::Cactus:
    case TileId::StairsUp:
    case TileId::StairsDown:
    case TileId::Bed:
    case TileId::DungeonFloor:
    case TileId::DungeonWall:
        return 0;
    }
    return 0;
}

bool Simulation::isDamageableStructureTile(TileId id) const
{
    return id == TileId::Wall || id == TileId::PlankWall || id == TileId::Door;
}

bool Simulation::damageStructureAt(int x, int y, int z, int amount)
{
    if (amount <= 0) {
        return false;
    }

    if (auto* machine = machineAt(x, y, z); machine != nullptr) {
        const auto machineId = machine->id;
        const int maxDurability = machineMaxDurability(machine->kind);
        const auto socketedRelic = machine->socketedRelic;
        if (machine->durability <= 0) {
            machine->durability = maxDurability;
        }
        machine->durability -= amount;
        if (machine->durability > 0) {
            return true;
        }

        const int recoveredScrap = std::max(1, maxDurability / 2);
        addItem(ItemId::Scrap, recoveredScrap);
        productionTotals_.scrapRecovered += recoveredScrap;
        if (socketedRelic != ItemId::None) {
            addItem(socketedRelic, 1);
        }
        const auto found = std::find_if(machines_.begin(), machines_.end(), [machineId](const Machine& candidate) {
            return candidate.id == machineId;
        });
        if (found != machines_.end()) {
            machines_.erase(found);
            rebuildMachineCellIndex();
        }
        return true;
    }

    const auto tile = world_.getTile(x, y, z);
    if (!isDamageableStructureTile(tile.id)) {
        return false;
    }

    const int maxDurability = tileMaxDurability(tile.id);
    const int currentDurability = tile.data <= 0 ? maxDurability : std::min(tile.data, maxDurability);
    const int remaining = currentDurability - amount;
    if (remaining <= 0) {
        world_.setTile(x, y, z, Tile{TileId::Floor, 0});
    } else {
        world_.setTile(x, y, z, Tile{tile.id, remaining});
    }
    return true;
}

bool Simulation::damageAdjacentStructure(Entity& entity, int amount)
{
    constexpr std::array<Direction, 4> kDirections{{
        Direction::North,
        Direction::East,
        Direction::South,
        Direction::West,
    }};
    for (const auto direction : kDirections) {
        if (damageStructureAt(entity.x + dx(direction), entity.y + dy(direction), entity.z, amount)) {
            entity.facing = direction;
            return true;
        }
    }
    return false;
}

int Simulation::powerDemand(MachineKind kind) const
{
    if (kind == MachineKind::ElectricMiner) {
        return 1;
    }
    if (kind == MachineKind::LogisticPort) {
        return 1;
    }
    if (kind == MachineKind::GuardTower) {
        return 1;
    }
    if (kind == MachineKind::ArchiveTerminal || kind == MachineKind::RiftGate) {
        return 2;
    }
    if (kind == MachineKind::OutpostBeacon) {
        return 1;
    }
    if (kind == MachineKind::RepairPylon) {
        return 1;
    }
    if (kind == MachineKind::PressureRelay) {
        return 1;
    }
    if (kind == MachineKind::ArcTower) {
        return 2;
    }
    return 0;
}

bool Simulation::hasAdjacentWater(int x, int y) const
{
    return hasAdjacentWater(x, y, 0);
}

bool Simulation::hasAdjacentWater(int x, int y, int z) const
{
    for (const auto direction : {Direction::North, Direction::East, Direction::South, Direction::West}) {
        if (isWaterTile(world_.getTile(x + dx(direction), y + dy(direction), z).id)) {
            return true;
        }
    }
    return false;
}

Machine* Simulation::machineById(std::uint32_t id)
{
    for (auto& machine : machines_) {
        if (machine.id == id) {
            return &machine;
        }
    }
    return nullptr;
}

const Machine* Simulation::machineById(std::uint32_t id) const
{
    for (const auto& machine : machines_) {
        if (machine.id == id) {
            return &machine;
        }
    }
    return nullptr;
}

bool Simulation::isRecipeInput(std::string_view recipeKey, ItemId item) const
{
    const auto* recipe = recipeDef(recipeKey);
    if (recipe == nullptr || item == ItemId::None) {
        return false;
    }

    return std::any_of(recipe->inputs.begin(), recipe->inputs.end(), [item](const ItemStack& stack) {
        return stack.item == item;
    });
}

bool Simulation::isAdjacentToWorkbench() const
{
    for (const auto direction : {Direction::North, Direction::East, Direction::South, Direction::West}) {
        const auto* machine = machineAt(player_.x + dx(direction), player_.y + dy(direction), player_.z);
        if (machine != nullptr && machine->kind == MachineKind::Workbench) {
            return true;
        }
    }
    return false;
}

bool Simulation::canCraftAtCurrentStation(const RecipeDef& recipe) const
{
    if (recipe.station == "hand") {
        return true;
    }
    if (recipe.station == "workbench") {
        return isAdjacentToWorkbench();
    }
    return false;
}

int Simulation::countMachineItem(const Machine& machine, ItemId item) const
{
    if (item == ItemId::None) {
        int total = machine.inventory.stacks().empty() ? 0 : 0;
        for (const auto& stack : machine.inventory.stacks()) {
            total += stack.count;
        }
        if (machine.carriedItem != ItemId::None) {
            ++total;
        }
        if (machine.outputItem != ItemId::None) {
            ++total;
        }
        if (machine.socketedRelic != ItemId::None) {
            ++total;
        }
        return total;
    }

    int total = machine.inventory.count(item);
    if (machine.carriedItem == item) {
        ++total;
    }
    if (machine.outputItem == item) {
        ++total;
    }
    if (machine.socketedRelic == item) {
        ++total;
    }
    return total;
}

int Simulation::totalItemCount(ItemId item) const
{
    if (item == ItemId::None) {
        return 0;
    }

    int total = player_.inventory.count(item);
    for (const auto& machine : machines_) {
        total += countMachineItem(machine, item);
    }
    return total;
}

bool Simulation::circuitConditionAllows(const Machine& inserter, const Machine* target) const
{
    if (inserter.kind != MachineKind::CircuitInserter ||
        inserter.circuitComparator == CircuitComparator::Always) {
        return true;
    }
    if (target == nullptr) {
        return false;
    }

    const int count = countMachineItem(*target, inserter.filterItem);
    if (inserter.circuitComparator == CircuitComparator::LessThan) {
        return count < inserter.circuitThreshold;
    }
    if (inserter.circuitComparator == CircuitComparator::GreaterOrEqual) {
        return count >= inserter.circuitThreshold;
    }
    return true;
}

std::vector<std::uint32_t> Simulation::poweredLogisticPortIds() const
{
    std::vector<std::uint32_t> ids;
    for (const auto& machine : machines_) {
        if (machine.kind == MachineKind::LogisticPort && isMachinePowered(machine.id)) {
            ids.push_back(machine.id);
        }
    }
    return ids;
}

bool Simulation::isWaterTile(TileId id) const
{
    return id == TileId::Water || id == TileId::DeepWater || id == TileId::Coral;
}

bool Simulation::isHostile(EntityKind kind) const
{
    return kind == EntityKind::Slime ||
        kind == EntityKind::GlassSkitter ||
        kind == EntityKind::SunScarab ||
        kind == EntityKind::Skeleton ||
        kind == EntityKind::CaveCrawler ||
        kind == EntityKind::FrostCrawler ||
        kind == EntityKind::NullWisp ||
        kind == EntityKind::DungeonSentinel ||
        kind == EntityKind::RiftStalker ||
        kind == EntityKind::MarshBroodheart ||
        kind == EntityKind::GlassMaw ||
        kind == EntityKind::BadlandsWarden ||
        kind == EntityKind::FrostNullifier ||
        kind == EntityKind::RiftSignalTyrant;
}

int Simulation::playerAttackDamage(const Entity& entity) const
{
    if (entity.kind == EntityKind::GlassMaw &&
        productionTotals_.pressureWavesRepelled == 0 &&
        (tick_ % 80U) < 40U) {
        return 1;
    }
    return 2;
}

int Simulation::achievementCurrent(AchievementId id) const
{
    switch (id) {
    case AchievementId::FirstIronPlate:
        return productionTotals_.ironPlates;
    case AchievementId::FirstSciencePack:
        return productionTotals_.sciencePacks;
    case AchievementId::LogisticsOne:
        return isTechCompleted("logistics_1") ? 1 : 0;
    case AchievementId::FirstCreatureDefeated:
        return productionTotals_.creaturesDefeated;
    case AchievementId::FirstBossDefeated:
        return productionTotals_.bossesDefeated;
    case AchievementId::FirstPressureReward:
        return productionTotals_.pressureWaveRewardsClaimed;
    case AchievementId::FirstRiftJump:
        return productionTotals_.riftJumps;
    case AchievementId::FirstOutpost:
        return productionTotals_.outpostsActivated;
    case AchievementId::FirstScoutDispatch:
        return productionTotals_.scoutDispatches;
    case AchievementId::ScoutRecovery:
        return productionTotals_.scoutMaterialsRecovered;
    }
    return 0;
}

bool Simulation::isAchievementUnlocked(AchievementId id) const
{
    return std::find(unlockedAchievements_.begin(), unlockedAchievements_.end(), id) != unlockedAchievements_.end();
}

void Simulation::updateAchievements()
{
    for (const auto& def : kAchievementDefs) {
        if (isAchievementUnlocked(def.id) || achievementCurrent(def.id) < def.required) {
            continue;
        }
        unlockedAchievements_.push_back(def.id);
    }
}

void Simulation::beginTutorial()
{
    tutorialState_.active = true;
    tutorialState_.completed = false;
    tutorialState_.actionMask = 0;
    player_.x = kTutorialSpawnX;
    player_.y = kTutorialSpawnY;
    player_.z = kTutorialLayer;
    player_.facing = Direction::East;
    player_.inBoat = false;

    if (machineAt(kTutorialChestX, kTutorialChestY, kTutorialLayer) == nullptr) {
        Machine chest;
        chest.id = nextMachineId_++;
        chest.kind = MachineKind::Chest;
        chest.x = kTutorialChestX;
        chest.y = kTutorialChestY;
        chest.z = kTutorialLayer;
        chest.direction = Direction::South;
        chest.durability = machineMaxDurability(chest.kind);
        machines_.push_back(chest);
        std::sort(machines_.begin(), machines_.end(), [](const Machine& left, const Machine& right) {
            return left.id < right.id;
        });
        rebuildMachineCellIndex();
    }
}

void Simulation::completeTutorial()
{
    tutorialState_.active = false;
    tutorialState_.completed = true;
    tutorialState_.actionMask = kTutorialRequiredMask;
    player_.x = tutorialState_.realSpawnX;
    player_.y = tutorialState_.realSpawnY;
    player_.z = tutorialState_.realSpawnZ;
    player_.facing = Direction::South;
    player_.inBoat = false;
    removeTutorialLayerState();
}

void Simulation::recordTutorialAction(TutorialAction action)
{
    if (!tutorialState_.active || tutorialState_.completed || player_.z != kTutorialLayer) {
        return;
    }
    tutorialState_.actionMask |= 1 << static_cast<int>(action);
}

TutorialState Simulation::findRealWorldSpawn() const
{
    TutorialState state;
    state.active = false;
    state.completed = true;
    state.actionMask = kTutorialRequiredMask;
    state.realSpawnZ = 0;

    World candidateWorld(world_.seed());
    std::optional<std::array<int, 3>> fallback;
    for (int attempt = 0; attempt < 3072; ++attempt) {
        const auto roll = thoth::core::hashCoordinates(
            world_.seed() ^ 0x7475746f7269616cULL,
            attempt,
            attempt * 17);
        const int x = static_cast<int>(roll % 769U) - 384;
        const int y = static_cast<int>((roll >> 20U) % 769U) - 384;
        if (std::abs(x) + std::abs(y) < 96) {
            continue;
        }

        const auto tile = candidateWorld.getTile(x, y, 0);
        if (isWaterTileId(tile.id) || !candidateWorld.isWalkable(x, y, 0) || !tileDef(tile.id).buildable) {
            continue;
        }
        if (!fallback) {
            fallback = std::array<int, 3>{x, y, 0};
        }
        if (!hasNearbyStarterResources(candidateWorld, x, y)) {
            continue;
        }

        state.realSpawnX = x;
        state.realSpawnY = y;
        return state;
    }

    if (fallback) {
        state.realSpawnX = (*fallback)[0];
        state.realSpawnY = (*fallback)[1];
    }
    return state;
}

bool Simulation::hasNearbyStarterResources(const World& world, int x, int y) const
{
    bool hasTree = false;
    bool hasStone = false;
    bool hasIron = false;
    bool hasCoal = false;
    bool hasCopper = false;
    constexpr int kSearchRadius = 34;

    for (int oy = -kSearchRadius; oy <= kSearchRadius; ++oy) {
        for (int ox = -kSearchRadius; ox <= kSearchRadius; ++ox) {
            if ((ox * ox) + (oy * oy) > kSearchRadius * kSearchRadius) {
                continue;
            }
            switch (world.getTile(x + ox, y + oy, 0).id) {
            case TileId::Tree:
                hasTree = true;
                break;
            case TileId::Stone:
                hasStone = true;
                break;
            case TileId::IronOre:
                hasIron = true;
                break;
            case TileId::CoalOre:
                hasCoal = true;
                break;
            case TileId::CopperOre:
                hasCopper = true;
                break;
            default:
                break;
            }
            if (hasTree && hasStone && hasIron && hasCoal && hasCopper) {
                return true;
            }
        }
    }
    return false;
}

void Simulation::removeTutorialLayerState()
{
    machines_.erase(
        std::remove_if(
            machines_.begin(),
            machines_.end(),
            [](const Machine& machine) {
                return machine.z == kTutorialLayer;
            }),
        machines_.end());
    entities_.erase(
        std::remove_if(
            entities_.begin(),
            entities_.end(),
            [](const Entity& entity) {
                return entity.z == kTutorialLayer;
            }),
        entities_.end());
    rebuildMachineCellIndex();
}

ItemId Simulation::entityDrop(EntityKind kind) const
{
    switch (kind) {
    case EntityKind::Deer:
        return ItemId::Hide;
    case EntityKind::Chicken:
        return ItemId::ReedFiber;
    case EntityKind::Crab:
        return ItemId::Shell;
    case EntityKind::Fish:
        return ItemId::Kelp;
    case EntityKind::Slime:
        return ItemId::Slime;
    case EntityKind::GlassSkitter:
        return ItemId::CactusFiber;
    case EntityKind::SunScarab:
        return ItemId::SandGlass;
    case EntityKind::Skeleton:
        return ItemId::Bone;
    case EntityKind::CaveCrawler:
        return ItemId::Venom;
    case EntityKind::FrostCrawler:
        return ItemId::IceShard;
    case EntityKind::NullWisp:
        return ItemId::Crystal;
    case EntityKind::DungeonSentinel:
        return ItemId::Crystal;
    case EntityKind::RiftStalker:
        return ItemId::Crystal;
    case EntityKind::MarshBroodheart:
        return ItemId::MarshHeart;
    case EntityKind::GlassMaw:
        return ItemId::GlassHeart;
    case EntityKind::BadlandsWarden:
        return ItemId::WardenCore;
    case EntityKind::FrostNullifier:
        return ItemId::FrostCore;
    case EntityKind::RiftSignalTyrant:
        return ItemId::RiftCrown;
    }
    return ItemId::None;
}

int Simulation::entityDropCount(EntityKind kind) const
{
    switch (kind) {
    case EntityKind::MarshBroodheart:
    case EntityKind::GlassMaw:
    case EntityKind::BadlandsWarden:
    case EntityKind::FrostNullifier:
    case EntityKind::RiftSignalTyrant:
        return 1;
    case EntityKind::Deer:
    case EntityKind::Chicken:
    case EntityKind::Crab:
    case EntityKind::Fish:
    case EntityKind::Slime:
    case EntityKind::GlassSkitter:
    case EntityKind::SunScarab:
    case EntityKind::Skeleton:
    case EntityKind::CaveCrawler:
    case EntityKind::FrostCrawler:
    case EntityKind::NullWisp:
    case EntityKind::DungeonSentinel:
    case EntityKind::RiftStalker:
        return 1;
    }
    return 1;
}

int Simulation::entityMaxHp(EntityKind kind) const
{
    switch (kind) {
    case EntityKind::Chicken:
    case EntityKind::Fish:
        return 1;
    case EntityKind::Deer:
    case EntityKind::Crab:
    case EntityKind::Slime:
        return 2;
    case EntityKind::GlassSkitter:
        return 3;
    case EntityKind::SunScarab:
    case EntityKind::Skeleton:
    case EntityKind::CaveCrawler:
    case EntityKind::FrostCrawler:
        return 4;
    case EntityKind::NullWisp:
        return 5;
    case EntityKind::DungeonSentinel:
        return 6;
    case EntityKind::RiftStalker:
        return 8;
    case EntityKind::MarshBroodheart:
        return 14;
    case EntityKind::GlassMaw:
        return 16;
    case EntityKind::BadlandsWarden:
        return 18;
    case EntityKind::FrostNullifier:
        return 20;
    case EntityKind::RiftSignalTyrant:
        return 24;
    }
    return 1;
}

void Simulation::defeatEntity(std::size_t entityIndex)
{
    if (entityIndex >= entities_.size()) {
        return;
    }
    const auto kind = entities_[entityIndex].kind;
    const bool pressureSpawn = entities_[entityIndex].pressureSpawn;
    addItem(entityDrop(kind), entityDropCount(kind));
    if (pressureSpawn) {
        ++productionTotals_.pressureEnemiesDefeated;
        ++productionTotals_.scrapRecovered;
        addItem(ItemId::Scrap, 1);

        if ((productionTotals_.pressureEnemiesDefeated % 3) == 0) {
            if (factoryPressureLevel() >= 220) {
                ++productionTotals_.advancedSciencePacks;
                addItem(ItemId::AdvancedSciencePack, 1);
            } else {
                ++productionTotals_.sciencePacks;
                addItem(ItemId::SciencePack, 1);
            }
            ++productionTotals_.pressureWaveRewardsClaimed;
        }
    }
    if (kind == EntityKind::MarshBroodheart ||
        kind == EntityKind::GlassMaw ||
        kind == EntityKind::BadlandsWarden ||
        kind == EntityKind::FrostNullifier ||
        kind == EntityKind::RiftSignalTyrant) {
        ++productionTotals_.bossesDefeated;
        ++productionTotals_.bossRelicsClaimed;
    }
    ++productionTotals_.creaturesDefeated;
    entities_.erase(entities_.begin() + static_cast<std::ptrdiff_t>(entityIndex));
}

std::optional<EntityKind> Simulation::localEntityKindForTile(int x, int y, int z) const
{
    if (z == kTutorialLayer) {
        return std::nullopt;
    }
    const auto tile = world_.getTile(x, y, z);
    const auto roll = thoth::core::hashCoordinates(world_.seed() ^ 0x656e74697479ULL, x + (z * 8192), y);
    if (z < 0) {
        if (!world_.isWalkable(x, y, z) || static_cast<int>(roll % 1000U) >= 70) {
            return std::nullopt;
        }
        const auto kindRoll = static_cast<int>((roll >> 16U) % 100U);
        if (kindRoll < 45) {
            return EntityKind::Slime;
        }
        if (kindRoll < 78) {
            return EntityKind::Skeleton;
        }
        if (kindRoll < 95) {
            return EntityKind::CaveCrawler;
        }
        return EntityKind::DungeonSentinel;
    }
    if (isWaterTile(tile.id) && static_cast<int>(roll % 1000U) < 45) {
        return tile.id == TileId::Coral ? EntityKind::Crab : EntityKind::Fish;
    }
    if (world_.biomeAt(x, y, z) == BiomeKind::Rift &&
        world_.isWalkable(x, y, z) &&
        static_cast<int>(roll % 1000U) < 45) {
        return EntityKind::RiftStalker;
    }
    if ((tile.id == TileId::Beach || tile.id == TileId::Sand) && static_cast<int>(roll % 1000U) < 35) {
        return EntityKind::Crab;
    }
    if (world_.isWalkable(x, y, z) && static_cast<int>(roll % 1000U) < 28) {
        return static_cast<int>((roll >> 12U) % 100U) < 55 ? EntityKind::Chicken : EntityKind::Deer;
    }
    return std::nullopt;
}

void Simulation::ensureLocalEntities()
{
    if (entities_.size() >= 80) {
        return;
    }
    if (world_.lairAt(player_.x, player_.y, player_.z).has_value()) {
        ensureLairEntities();
        if (player_.z >= 0) {
            ensureFactoryPressureEntity();
        }
        return;
    }
    if (!entities_.empty() && player_.z >= 0) {
        ensureFactoryPressureEntity();
        return;
    }
    constexpr int kSpawnRadius = 9;
    for (int y = player_.y - kSpawnRadius; y <= player_.y + kSpawnRadius; ++y) {
        for (int x = player_.x - kSpawnRadius; x <= player_.x + kSpawnRadius; ++x) {
            if (entities_.size() >= 80 || entityAt(x, y, player_.z) != nullptr) {
                continue;
            }
            const auto kind = localEntityKindForTile(x, y, player_.z);
            if (!kind) {
                continue;
            }
            Entity entity;
            entity.id = nextEntityId_++;
            entity.kind = *kind;
            entity.x = x;
            entity.y = y;
            entity.z = player_.z;
            entity.hp = entityMaxHp(entity.kind);
            entity.facing = Direction::South;
            entities_.push_back(entity);
        }
    }
    ensureFactoryPressureEntity();
}

void Simulation::ensureLairEntities()
{
    const auto lair = world_.lairAt(player_.x, player_.y, player_.z);
    if (!lair || entities_.size() >= 80) {
        return;
    }

    int nearbyHostiles = 0;
    for (const auto& entity : entities_) {
        if (entity.z == player_.z &&
            isHostile(entity.kind) &&
            world_.lairAt(entity.x, entity.y, entity.z) == lair &&
            manhattanDistance(entity.x, entity.y, entity.z, player_.x, player_.y, player_.z) <= 12) {
            ++nearbyHostiles;
        }
    }
    if (nearbyHostiles >= 3 || (nearbyHostiles > 0 && (tick_ % 90U) != 0U)) {
        return;
    }

    constexpr std::array<std::pair<int, int>, 8> kOffsets{{
        {3, 0},
        {-3, 0},
        {0, 3},
        {0, -3},
        {2, 2},
        {-2, 2},
        {2, -2},
        {-2, -2},
    }};

    EntityKind kind = EntityKind::Slime;
    if (*lair == LairKind::GlassSpire) {
        kind = nearbyHostiles == 0 ? EntityKind::GlassSkitter : EntityKind::SunScarab;
    } else if (*lair == LairKind::BadlandsFoundry) {
        kind = nearbyHostiles == 0 ? EntityKind::Skeleton : EntityKind::CaveCrawler;
    } else if (*lair == LairKind::FrostVault) {
        kind = nearbyHostiles == 0 ? EntityKind::FrostCrawler : EntityKind::NullWisp;
    } else if (*lair == LairKind::CrystalVault) {
        kind = EntityKind::DungeonSentinel;
    }

    for (const auto& [offsetX, offsetY] : kOffsets) {
        const int x = player_.x + offsetX;
        const int y = player_.y + offsetY;
        const auto candidateLair = world_.lairAt(x, y, player_.z);
        if (!candidateLair ||
            *candidateLair != *lair ||
            entityAt(x, y, player_.z) != nullptr ||
            machineAt(x, y, player_.z) != nullptr ||
            !world_.isWalkable(x, y, player_.z)) {
            continue;
        }

        Entity entity;
        entity.id = nextEntityId_++;
        entity.kind = kind;
        entity.x = x;
        entity.y = y;
        entity.z = player_.z;
        entity.hp = entityMaxHp(entity.kind);
        entity.facing = Direction::South;
        entity.cooldown = 20;
        entities_.push_back(entity);
        return;
    }
}

PressureEventCard Simulation::pressureEventForTick(std::uint64_t waveTick) const
{
    const int pressure = factoryPressureLevel();
    if (productionTotals_.sciencePacks == 0 || pressure < 120) {
        return PressureEventCard{
            "none",
            "Dormant",
            0,
            0,
            "pressure is below the raid threshold",
            "keep scaling production and build defenses before the threshold"};
    }

    int severity = 1;
    if (pressure >= 220) {
        severity = 2;
    }
    if (pressure >= 320) {
        severity = 3;
    }
    if (activatedOutpostBiomeCount() >= 3 && severity > 1) {
        --severity;
    }

    const auto waveIndex = static_cast<int>(
        (waveTick / 300U) +
        (world_.seed() % 23U) +
        static_cast<std::uint64_t>(productionTotals_.riftJumps * 5) +
        static_cast<std::uint64_t>(productionTotals_.archiveSignals * 3) +
        static_cast<std::uint64_t>(productionTotals_.pressureWavesRepelled));

    if (riftStormActive() && pressure >= 180 && productionTotals_.riftJumps > 0 && (waveIndex % 2) == 0) {
        return PressureEventCard{
            "rift_storm_breach",
            "Rift Storm Breach",
            std::max(severity, riftStorm_.severity),
            std::min(4, 1 + riftStorm_.severity),
            "the active storm folds stalkers into the next pressure wave",
            "anchor rift gates with the Rift Crown and hold arc tower coverage"};
    }

    if (pressure >= 260 && productionTotals_.riftJumps > 0 && (waveIndex % 4) == 0) {
        return PressureEventCard{
            "rift_stalker_incursion",
            "Rift Stalker Incursion",
            severity,
            severity >= 3 ? 3 : 2,
            "stalkers phase in around the factory perimeter",
            "arc towers and full outpost coverage reduce the chaos window"};
    }

    if (pressure >= 220) {
        switch (waveIndex % 4) {
        case 0:
            return PressureEventCard{
                "siege_line",
                "Siege Line",
                severity,
                severity >= 3 ? 3 : 2,
                "skeletons arrive in a small formation and pressure walls",
                "keep repair pylons loaded and towers powered"};
        case 1:
            return PressureEventCard{
                "wisp_interference",
                "Wisp Interference",
                severity,
                2,
                "null wisps ride the wave and threaten active machines",
                "spread production blocks and cover crystal-side builds"};
        case 2:
            return PressureEventCard{
                "brood_overflow",
                "Brood Overflow",
                severity,
                severity >= 3 ? 4 : 3,
                "fast slimes flood multiple approach lanes",
                "belts and walls buy time while guard towers thin the pack"};
        default:
            return PressureEventCard{
                "mixed_raid",
                "Mixed Raid",
                severity,
                severity >= 3 ? 3 : 2,
                "slimes and skeletons arrive together",
                "pair relays with overlapping guard and arc tower coverage"};
        }
    }

    switch (waveIndex % 3) {
    case 0:
        return PressureEventCard{
            "scout_probe",
            "Scout Probe",
            severity,
            1,
            "a lone hostile tests the nearest open approach",
            "clear it quickly before the next deck card escalates"};
    case 1:
        return PressureEventCard{
            "splitter_sappers",
            "Splitter Sappers",
            severity,
            2,
            "two weak attackers probe separate approach lanes",
            "early walls or one powered guard tower can stabilize this wave"};
    default:
        return PressureEventCard{
            "bone_scout",
            "Bone Scout",
            severity,
            pressure >= 180 ? 2 : 1,
            "a tougher scout appears once science pressure climbs",
            "build a guard tower before scaling advanced science"};
    }
}

std::vector<EntityKind> Simulation::pressureEventSpawns(const PressureEventCard& card) const
{
    std::vector<EntityKind> spawns;
    spawns.reserve(static_cast<std::size_t>(std::max(0, card.spawnCount)));

    if (card.key == "rift_stalker_incursion") {
        for (int i = 0; i < card.spawnCount; ++i) {
            spawns.push_back(i == 0 ? EntityKind::RiftStalker : EntityKind::Skeleton);
        }
        return spawns;
    }
    if (card.key == "rift_storm_breach") {
        for (int i = 0; i < card.spawnCount; ++i) {
            spawns.push_back((i % 2) == 0 ? EntityKind::RiftStalker : EntityKind::NullWisp);
        }
        return spawns;
    }
    if (card.key == "siege_line") {
        for (int i = 0; i < card.spawnCount; ++i) {
            spawns.push_back(EntityKind::Skeleton);
        }
        return spawns;
    }
    if (card.key == "wisp_interference") {
        spawns.push_back(EntityKind::NullWisp);
        if (card.spawnCount > 1) {
            spawns.push_back(EntityKind::Skeleton);
        }
        return spawns;
    }
    if (card.key == "brood_overflow") {
        for (int i = 0; i < card.spawnCount; ++i) {
            spawns.push_back(EntityKind::Slime);
        }
        return spawns;
    }
    if (card.key == "mixed_raid") {
        for (int i = 0; i < card.spawnCount; ++i) {
            spawns.push_back((i % 2) == 0 ? EntityKind::Slime : EntityKind::Skeleton);
        }
        return spawns;
    }
    if (card.key == "bone_scout") {
        for (int i = 0; i < card.spawnCount; ++i) {
            spawns.push_back(EntityKind::Skeleton);
        }
        return spawns;
    }
    if (card.key == "splitter_sappers") {
        for (int i = 0; i < card.spawnCount; ++i) {
            spawns.push_back(EntityKind::Slime);
        }
        return spawns;
    }
    if (card.key == "scout_probe") {
        spawns.push_back(EntityKind::Slime);
    }
    return spawns;
}

void Simulation::ensureFactoryPressureEntity()
{
    if (entities_.size() >= 80 ||
        player_.z != 0 ||
        tick_ == 0 ||
        (tick_ % 300U) != 0U ||
        productionTotals_.sciencePacks == 0 ||
        factoryPressureLevel() < 120) {
        return;
    }

    constexpr std::array<std::pair<int, int>, 12> kOffsets{{
        {0, -10},
        {8, -6},
        {10, 0},
        {8, 6},
        {0, 10},
        {-8, 6},
        {-10, 0},
        {-8, -6},
        {4, -9},
        {9, 4},
        {-4, 9},
        {-9, -4},
    }};

    const auto event = pressureEventForTick(tick_);
    const auto spawns = pressureEventSpawns(event);
    for (std::size_t spawnIndex = 0; spawnIndex < spawns.size() && entities_.size() < 80; ++spawnIndex) {
        const auto kind = spawns[spawnIndex];
        const auto startOffset = static_cast<std::size_t>(
            ((tick_ / 300U) + spawnIndex * 3U + static_cast<std::uint64_t>(event.severity)) % kOffsets.size());
        for (std::size_t attempt = 0; attempt < kOffsets.size(); ++attempt) {
            const auto& [offsetX, offsetY] = kOffsets[(startOffset + attempt) % kOffsets.size()];
            const int x = player_.x + offsetX;
            const int y = player_.y + offsetY;
            if ((x == player_.x && y == player_.y) ||
                machineAt(x, y, player_.z) != nullptr ||
                entityAt(x, y, player_.z) != nullptr) {
                continue;
            }
            const auto tile = world_.getTile(x, y, player_.z);
            if (isWaterTile(tile.id) || !world_.isWalkable(x, y, player_.z)) {
                continue;
            }

            Entity entity;
            entity.id = nextEntityId_++;
            entity.kind = kind;
            entity.x = x;
            entity.y = y;
            entity.z = player_.z;
            entity.hp = entityMaxHp(entity.kind);
            entity.facing = Direction::South;
            entity.cooldown = 20;
            entity.pressureSpawn = true;
            entities_.push_back(entity);
            break;
        }
    }
}

bool Simulation::spawnEntityNear(int x, int y, int z, EntityKind kind, int range)
{
    if (entities_.size() >= 80) {
        return false;
    }
    for (int distance = 1; distance <= range; ++distance) {
        for (int offsetY = -distance; offsetY <= distance; ++offsetY) {
            for (int offsetX = -distance; offsetX <= distance; ++offsetX) {
                if (absInt(offsetX) + absInt(offsetY) != distance) {
                    continue;
                }
                const int sx = x + offsetX;
                const int sy = y + offsetY;
                if ((sx == player_.x && sy == player_.y && z == player_.z) ||
                    machineAt(sx, sy, z) != nullptr ||
                    entityAt(sx, sy, z) != nullptr ||
                    !world_.isWalkable(sx, sy, z)) {
                    continue;
                }

                Entity entity;
                entity.id = nextEntityId_++;
                entity.kind = kind;
                entity.x = sx;
                entity.y = sy;
                entity.z = z;
                entity.hp = entityMaxHp(entity.kind);
                entity.facing = Direction::South;
                entity.cooldown = 20;
                entities_.push_back(entity);
                return true;
            }
        }
    }
    return false;
}

void Simulation::updateBossPhases()
{
    struct SpawnRequest {
        int x = 0;
        int y = 0;
        int z = 0;
        EntityKind kind = EntityKind::Slime;
        int range = 1;
    };

    struct PulseRequest {
        int x = 0;
        int y = 0;
        int z = 0;
    };

    std::vector<SpawnRequest> spawns;
    std::vector<PulseRequest> frostPulses;
    for (const auto& entity : entities_) {
        if (entity.hp <= 0 || entity.z != player_.z || tick_ == 0) {
            continue;
        }
        if (entity.kind == EntityKind::MarshBroodheart &&
            entity.hp <= entityMaxHp(entity.kind) / 2 &&
            (tick_ % 90U) == 0U) {
            spawns.push_back(SpawnRequest{entity.x, entity.y, entity.z, EntityKind::Slime, 3});
        } else if (entity.kind == EntityKind::FrostNullifier &&
            (tick_ % 120U) == 0U) {
            frostPulses.push_back(PulseRequest{entity.x, entity.y, entity.z});
        } else if (entity.kind == EntityKind::RiftSignalTyrant &&
            activatedOutpostBiomeCount() < static_cast<int>(kRequiredOutpostBiomes.size()) &&
            (tick_ % 90U) == 0U) {
            spawns.push_back(SpawnRequest{entity.x, entity.y, entity.z, EntityKind::RiftStalker, 3});
        }
    }

    for (const auto& pulse : frostPulses) {
        for (auto& machine : machines_) {
            if (manhattanDistance(machine.x, machine.y, machine.z, pulse.x, pulse.y, pulse.z) > 3) {
                continue;
            }
            machine.progress = 0;
            machine.status = MachineStatus::MissingPower;
        }
    }

    for (const auto& spawn : spawns) {
        (void)spawnEntityNear(spawn.x, spawn.y, spawn.z, spawn.kind, spawn.range);
    }
}

void Simulation::updateEntities()
{
    updateBossPhases();
    for (auto& entity : entities_) {
        if (entity.cooldown > 0) {
            --entity.cooldown;
        }
        if (entity.z != player_.z) {
            continue;
        }

        const int distance = manhattanDistance(entity.x, entity.y, entity.z, player_.x, player_.y, player_.z);
        if (isHostile(entity.kind) && distance <= 1 && entity.cooldown == 0) {
            player_.hp = std::max(0, player_.hp - 1);
            entity.cooldown = 30;
            continue;
        }
        if (isHostile(entity.kind) && entity.cooldown == 0) {
            const bool isBoss = entity.kind == EntityKind::MarshBroodheart ||
                entity.kind == EntityKind::GlassMaw ||
                entity.kind == EntityKind::BadlandsWarden ||
                entity.kind == EntityKind::FrostNullifier ||
                entity.kind == EntityKind::RiftSignalTyrant;
            if (damageAdjacentStructure(entity, isBoss ? 2 : 1)) {
                entity.cooldown = isBoss ? 35 : 45;
                continue;
            }
        }
        if (isHostile(entity.kind) && distance <= 6 && (tick_ % 12U) == 0U) {
            const int stepX = player_.x == entity.x ? 0 : (player_.x > entity.x ? 1 : -1);
            const int stepY = player_.y == entity.y ? 0 : (player_.y > entity.y ? 1 : -1);
            const int nx = entity.x + (absInt(player_.x - entity.x) >= absInt(player_.y - entity.y) ? stepX : 0);
            const int ny = entity.y + (absInt(player_.x - entity.x) < absInt(player_.y - entity.y) ? stepY : 0);
            if (world_.isWalkable(nx, ny, entity.z) && machineAt(nx, ny, entity.z) == nullptr && entityAt(nx, ny, entity.z) == nullptr) {
                entity.x = nx;
                entity.y = ny;
            }
            continue;
        }
        if (!isHostile(entity.kind) && (tick_ + entity.id) % 90U == 0U) {
            const auto roll = thoth::core::hashCoordinates(world_.seed() ^ entity.id, static_cast<int>(tick_), entity.x + entity.y);
            const auto direction = static_cast<Direction>(roll % 4U);
            const int nx = entity.x + dx(direction);
            const int ny = entity.y + dy(direction);
            const auto target = world_.getTile(nx, ny, entity.z);
            const bool canSwim = entity.kind == EntityKind::Fish || entity.kind == EntityKind::Crab;
            if (((canSwim && isWaterTile(target.id)) || (!canSwim && world_.isWalkable(nx, ny, entity.z))) &&
                machineAt(nx, ny, entity.z) == nullptr &&
                entityAt(nx, ny, entity.z) == nullptr) {
                entity.x = nx;
                entity.y = ny;
            }
        }
    }
}

int Simulation::activeTechGoal() const
{
    const auto* tech = techDef(activeTech_);
    if (tech == nullptr) {
        return 0;
    }

    int goal = 0;
    for (const auto& input : tech->inputs) {
        goal += input.count;
    }
    return std::max(1, goal);
}

std::string Simulation::nextIncompleteTech() const
{
    for (const auto& tech : techDefs()) {
        if (!isTechCompleted(tech.key)) {
            return std::string(tech.key);
        }
    }
    return {};
}

void Simulation::completeActiveTech()
{
    const auto* tech = techDef(activeTech_);
    if (tech == nullptr || isTechCompleted(activeTech_)) {
        return;
    }

    completedTechs_.push_back(activeTech_);
    for (const auto unlock : tech->unlockRecipes) {
        const auto alreadyUnlocked = std::any_of(
            unlockedRecipes_.begin(),
            unlockedRecipes_.end(),
            [unlock](const std::string& key) {
                return std::string_view(key) == unlock;
            });
        if (!alreadyUnlocked) {
            unlockedRecipes_.push_back(std::string(unlock));
        }
    }
    activeTech_ = nextIncompleteTech();
    researchProgress_ = 0;
}

void Simulation::recordProduced(ItemId item, MachineKind producer)
{
    if (item == ItemId::IronPlate) {
        ++productionTotals_.ironPlates;
    } else if (item == ItemId::CopperPlate) {
        ++productionTotals_.copperPlates;
    } else if (item == ItemId::SciencePack) {
        ++productionTotals_.sciencePacks;
    } else if (item == ItemId::AdvancedSciencePack) {
        ++productionTotals_.advancedSciencePacks;
    } else if (item == ItemId::WaterBarrel) {
        ++productionTotals_.waterBarrels;
    }
    if (producer == MachineKind::ElectricMiner && item != ItemId::None) {
        ++productionTotals_.poweredOre;
    }
}

bool Simulation::isMachineItem(ItemId item) const
{
    return item != ItemId::None && itemDef(item).canPlaceMachine;
}

void Simulation::addItem(ItemId item, int count)
{
    if (!player_.inventory.add(item, count)) {
        return;
    }
    assignHotbar(item);
}

bool Simulation::consumeItem(ItemId item, int count)
{
    return player_.inventory.consume(item, count);
}

void Simulation::assignHotbar(ItemId item)
{
    if (item == ItemId::None) {
        return;
    }

    for (const auto slot : player_.hotbar) {
        if (slot == item) {
            return;
        }
    }

    for (auto& slot : player_.hotbar) {
        if (slot == ItemId::None) {
            slot = item;
            return;
        }
    }
}

} // namespace thoth::game
