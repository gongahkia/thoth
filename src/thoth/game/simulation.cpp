#include "thoth/game/simulation.hpp"

#include "thoth/core/deterministic_random.hpp"

#include <algorithm>
#include <array>
#include <cstddef>
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
constexpr int kArchiveTerminalTicks = 360;
constexpr int kTrainStopTicks = 90;
constexpr int kPumpTicks = 30;
constexpr int kPipeTicks = 3;
constexpr int kRiftGateTicks = 180;
constexpr int kGuardTowerTicks = 45;
constexpr int kGuardTowerRange = 5;
constexpr int kRiftOffset = 4096;

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

Simulation::Simulation(std::uint64_t seed)
    : world_(seed)
{
    const auto addedStarter = player_.inventory.add(ItemId::Stone, 10);
    (void)addedStarter;
    player_.hotbar.fill(ItemId::None);
    assignHotbar(ItemId::Stone);
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
    return productionTotals_.ironPlates +
        productionTotals_.copperPlates +
        productionTotals_.sciencePacks * 12 +
        productionTotals_.advancedSciencePacks * 24 +
        productionTotals_.poweredOre / 2 +
        productionTotals_.logisticDeliveries * 8 +
        productionTotals_.archiveSignals * 50 +
        productionTotals_.riftJumps * 80;
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

bool Simulation::mainObjectiveComplete() const
{
    return productionTotals_.riftJumps > 0 &&
        completedSupplyContracts() >= totalSupplyContracts();
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
    addContract(BiomeKind::CrystalField, "Crystal Field: stockpile 3 crystal", totalItemCount(ItemId::Crystal), 3);
    addContract(BiomeKind::Rift, "Rift: complete 2 rift jumps", productionTotals_.riftJumps, 2);
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
    return "biome contracts complete: outposts proved across marsh, desert, badlands, crystal, and rift";
}

std::string Simulation::milestoneText() const
{
    if (mainObjectiveComplete()) {
        return "milestone: main objective complete; optimize the factory or push deeper into the rift";
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
    result.activeTech = activeTech_;
    result.researchProgress = researchProgress_;
    result.completedTechs = completedTechs_;
    result.unlockedRecipes = unlockedRecipes_;
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
    }
    rebuildMachineCellIndex();
    logisticJobs_ = snapshot.logisticJobs;
    productionTotals_ = snapshot.productionTotals;
    completedTechs_ = snapshot.completedTechs;
    unlockedRecipes_ = snapshot.unlockedRecipes;
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
        return;
    }
    if (world_.isWalkable(nx, ny, player_.z) && !isWaterTile(target.id)) {
        player_.x = nx;
        player_.y = ny;
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
    addItem(def.drop, std::max(1, tile.data));
    world_.setTile(tx, ty, player_.z, Tile{minedReplacement(tile.id), 0});
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
    if (machine.kind == MachineKind::Assembler) {
        machine.recipeKey = "science_pack";
    }
    machines_.push_back(std::move(machine));

    std::sort(machines_.begin(), machines_.end(), [](const Machine& left, const Machine& right) {
        return left.id < right.id;
    });
    rebuildMachineCellIndex();
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

    if (tile.id == TileId::StairsDown && trySummonMarshBoss(tx, ty, player_.z)) {
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

void Simulation::attack(Direction direction)
{
    const int tx = player_.x + dx(direction);
    const int ty = player_.y + dy(direction);
    for (std::size_t index = 0; index < entities_.size(); ++index) {
        auto& entity = entities_[index];
        if (entity.x != tx || entity.y != ty || entity.z != player_.z || entity.hp <= 0) {
            continue;
        }
        entity.hp -= 2;
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
    updateGuardTowers();
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
        int availableDrones = port->inventory.count(ItemId::LogisticDrone) - activeJobs;
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
        machine.progress = std::min(machine.progress + 1, kRiftGateTicks);
        machine.status = MachineStatus::Working;
        if (machine.progress < kRiftGateTicks) {
            continue;
        }
        player_.x += player_.x >= (kRiftOffset / 2) ? -kRiftOffset : kRiftOffset;
        ++productionTotals_.riftJumps;
        machine.progress = 0;
        machine.status = MachineStatus::Idle;
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

        machine.progress = std::min(machine.progress + 1, kGuardTowerTicks);
        machine.status = MachineStatus::Working;
        if (machine.progress < kGuardTowerTicks) {
            continue;
        }

        entities_[targetIndex].hp -= 2;
        machine.progress = 0;
        if (entities_[targetIndex].hp <= 0) {
            defeatEntity(targetIndex);
        }
    }
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
    case MachineKind::PowerPole:
    case MachineKind::ElectricMiner:
    case MachineKind::OffshorePump:
    case MachineKind::GuardTower:
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
        kind == MachineKind::GuardTower;
}

bool Simulation::isLogisticStorage(MachineKind kind) const
{
    return kind == MachineKind::ProviderChest || kind == MachineKind::RequesterChest;
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
        return total;
    }

    int total = machine.inventory.count(item);
    if (machine.carriedItem == item) {
        ++total;
    }
    if (machine.outputItem == item) {
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
        kind == EntityKind::Skeleton ||
        kind == EntityKind::CaveCrawler ||
        kind == EntityKind::DungeonSentinel ||
        kind == EntityKind::MarshBroodheart;
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
    case EntityKind::Skeleton:
        return ItemId::Bone;
    case EntityKind::CaveCrawler:
        return ItemId::Venom;
    case EntityKind::DungeonSentinel:
        return ItemId::Crystal;
    case EntityKind::MarshBroodheart:
        return ItemId::Venom;
    }
    return ItemId::None;
}

int Simulation::entityDropCount(EntityKind kind) const
{
    switch (kind) {
    case EntityKind::MarshBroodheart:
        return 4;
    case EntityKind::Deer:
    case EntityKind::Chicken:
    case EntityKind::Crab:
    case EntityKind::Fish:
    case EntityKind::Slime:
    case EntityKind::Skeleton:
    case EntityKind::CaveCrawler:
    case EntityKind::DungeonSentinel:
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
    case EntityKind::Skeleton:
    case EntityKind::CaveCrawler:
        return 4;
    case EntityKind::DungeonSentinel:
        return 6;
    case EntityKind::MarshBroodheart:
        return 14;
    }
    return 1;
}

void Simulation::defeatEntity(std::size_t entityIndex)
{
    if (entityIndex >= entities_.size()) {
        return;
    }
    const auto kind = entities_[entityIndex].kind;
    addItem(entityDrop(kind), entityDropCount(kind));
    if (kind == EntityKind::MarshBroodheart) {
        ++productionTotals_.bossesDefeated;
    }
    ++productionTotals_.creaturesDefeated;
    entities_.erase(entities_.begin() + static_cast<std::ptrdiff_t>(entityIndex));
}

std::optional<EntityKind> Simulation::localEntityKindForTile(int x, int y, int z) const
{
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
    if (player_.z >= 0 && world_.lairAt(player_.x, player_.y, player_.z).has_value()) {
        ensureLairEntities();
        ensureFactoryPressureEntity();
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
    if (*lair == LairKind::BadlandsFoundry) {
        kind = nearbyHostiles == 0 ? EntityKind::Skeleton : EntityKind::CaveCrawler;
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

    const auto kind = factoryPressureLevel() >= 220 ? EntityKind::Skeleton : EntityKind::Slime;
    for (const auto& [offsetX, offsetY] : kOffsets) {
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
        entities_.push_back(entity);
        return;
    }
}

void Simulation::updateEntities()
{
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
