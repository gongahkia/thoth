#include "thoth/game/simulation.hpp"

#include <algorithm>
#include <array>
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
constexpr int kRiftOffset = 4096;

int absInt(int value)
{
    return value < 0 ? -value : value;
}

int manhattanDistance(const Machine& left, const Machine& right)
{
    return absInt(left.x - right.x) + absInt(left.y - right.y);
}

int manhattanDistance(int ax, int ay, int bx, int by)
{
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

std::uint64_t machineCellKey(int x, int y)
{
    const auto ux = static_cast<std::uint64_t>(static_cast<std::uint32_t>(x));
    const auto uy = static_cast<std::uint64_t>(static_cast<std::uint32_t>(y));
    return (ux << 32U) | uy;
}

TileId minedReplacement(TileId id)
{
    switch (id) {
    case TileId::Tree:
        return TileId::Grass;
    case TileId::Stone:
    case TileId::IronOre:
    case TileId::CopperOre:
    case TileId::CoalOre:
        return TileId::Floor;
    case TileId::Dirt:
    case TileId::Floor:
    case TileId::Grass:
    case TileId::Water:
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
    case TileId::Dirt:
    case TileId::Floor:
    case TileId::Grass:
    case TileId::Stone:
    case TileId::Tree:
    case TileId::Water:
        return ItemId::None;
    }
    return ItemId::None;
}

void depleteResourceTile(World& world, int x, int y)
{
    auto tile = world.getTile(x, y);
    if (resourceTileOutput(tile.id) == ItemId::None) {
        return;
    }

    const int remaining = std::max(1, tile.data) - 1;
    if (remaining <= 0) {
        world.setTile(x, y, Tile{minedReplacement(tile.id), 0});
        return;
    }

    tile.data = remaining;
    world.setTile(x, y, tile);
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
    auto queue = commandQueue_;
    commandQueue_.clear();
    for (const auto& command : queue) {
        apply(command);
    }
    updateMachines();
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
    const auto found = machineCellIndex_.find(machineCellKey(x, y));
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
    const auto found = machineCellIndex_.find(machineCellKey(x, y));
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

std::string Simulation::milestoneText() const
{
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
    playerSnapshot.facing = player_.facing;
    playerSnapshot.selectedHotbar = player_.selectedHotbar;
    playerSnapshot.hotbar = player_.hotbar;
    playerSnapshot.inventory = player_.inventory.stacks();

    SimulationSnapshot result;
    result.seed = world_.seed();
    result.tick = tick_;
    result.player = playerSnapshot;
    result.tiles = world_.loadedTiles();
    result.nextMachineId = nextMachineId_;
    result.machines = machines_;
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
        world_.setTile(tile.x, tile.y, tile.tile);
    }

    player_.x = snapshot.player.x;
    player_.y = snapshot.player.y;
    player_.facing = snapshot.player.facing;
    player_.selectedHotbar = std::clamp(snapshot.player.selectedHotbar, 0, kHotbarSlots - 1);
    player_.hotbar = snapshot.player.hotbar;
    player_.inventory.clear();
    for (const auto& stack : snapshot.player.inventory) {
        const auto added = player_.inventory.add(stack.item, stack.count);
        (void)added;
    }

    tick_ = snapshot.tick;
    nextMachineId_ = snapshot.nextMachineId == 0 ? 1 : snapshot.nextMachineId;
    machines_ = snapshot.machines;
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
                machineCellIndex_[machineCellKey(machine.x + ox, machine.y + oy)] = index;
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
    }
}

void Simulation::move(Direction direction)
{
    const int nx = player_.x + dx(direction);
    const int ny = player_.y + dy(direction);
    if (world_.isWalkable(nx, ny)) {
        player_.x = nx;
        player_.y = ny;
    }
}

void Simulation::mine(Direction direction)
{
    const int tx = player_.x + dx(direction);
    const int ty = player_.y + dy(direction);
    const auto tile = world_.getTile(tx, ty);
    if (!isMineable(tile.id)) {
        return;
    }

    const auto& def = tileDef(tile.id);
    addItem(def.drop, std::max(1, tile.data));
    world_.setTile(tx, ty, Tile{minedReplacement(tile.id), 0});
}

void Simulation::place(Direction direction, TileId tile, ItemId item, Direction orientation)
{
    if (isMachineItem(item)) {
        placeMachine(direction, item, orientation);
        return;
    }

    const int tx = player_.x + dx(direction);
    const int ty = player_.y + dy(direction);
    if (machineAt(tx, ty) != nullptr) {
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

    const auto targetTile = world_.getTile(tx, ty);
    if (!world_.isWalkable(tx, ty) || !tileDef(targetTile.id).buildable || !tileDef(tileToPlace).walkable) {
        return;
    }

    if (requiredItem != ItemId::None && !consumeItem(requiredItem, 1)) {
        return;
    }
    world_.setTile(tx, ty, Tile{tileToPlace, 0});
}

void Simulation::placeMachine(Direction direction, ItemId item, Direction orientation)
{
    const auto& def = itemDef(item);
    if (!def.canPlaceMachine) {
        return;
    }

    const int tx = player_.x + dx(direction);
    const int ty = player_.y + dy(direction);
    if (!canPlaceMachine(def.placeMachine, tx, ty)) {
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
    if (!acceptItemAt(tx, ty, item)) {
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
    auto* machine = machineAt(tx, ty);
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
    auto* machine = machineAt(tx, ty);
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
    auto* machine = machineAt(tx, ty);
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
    auto* machine = machineAt(tx, ty);
    if (machine == nullptr || machine->kind != MachineKind::RequesterChest) {
        return;
    }
    machine->requestItem = requestItem;
    machine->requestThreshold = requestItem == ItemId::None ? 0 : std::max(0, threshold);
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

        const auto output = resourceTileOutput(world_.getTile(machine.x, machine.y).id);

        if (output == ItemId::None) {
            machine.progress = 0;
            machine.status = MachineStatus::MissingInput;
            continue;
        }

        if (machine.progress >= kMinerTicks) {
            if (outputItem(machine, output)) {
                depleteResourceTile(world_, machine.x, machine.y);
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
                depleteResourceTile(world_, machine.x, machine.y);
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

        const auto output = resourceTileOutput(world_.getTile(machine.x, machine.y).id);

        if (output == ItemId::None) {
            machine.progress = 0;
            machine.status = MachineStatus::MissingInput;
            continue;
        }

        if (machine.progress >= kElectricMinerTicks) {
            if (outputItem(machine, output)) {
                depleteResourceTile(world_, machine.x, machine.y);
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
                depleteResourceTile(world_, machine.x, machine.y);
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
            if (acceptItemAt(machine->x + dx(outputDirection), machine->y + dy(outputDirection), item)) {
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
        auto* target = machineAt(targetX, targetY);
        if (!circuitConditionAllows(machine, target)) {
            machine.status = MachineStatus::Idle;
            continue;
        }
        const auto item = extractItemAt(sourceX, sourceY, machine.kind == MachineKind::CircuitInserter ? machine.filterItem : ItemId::None);
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
        auto* source = machineAt(sourceX, sourceY);
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
                    manhattanDistance(port->x, port->y, requester.x, requester.y) > kLogisticPortRange) {
                    continue;
                }

                for (auto& provider : machines_) {
                    if (provider.kind != MachineKind::ProviderChest ||
                        provider.inventory.count(requester.requestItem) <= 0 ||
                        manhattanDistance(port->x, port->y, provider.x, provider.y) > kLogisticPortRange) {
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
                selectedRequester->x,
                selectedRequester->y);
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
        if (!hasAdjacentWater(machine.x, machine.y)) {
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

bool Simulation::canPlaceMachine(MachineKind kind, int x, int y) const
{
    const auto& def = machineDef(kind);
    for (int oy = 0; oy < def.height; ++oy) {
        for (int ox = 0; ox < def.width; ++ox) {
            const int tx = x + ox;
            const int ty = y + oy;
            if (machineAt(tx, ty) != nullptr) {
                return false;
            }

            const auto tile = world_.getTile(tx, ty);
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
    auto* machine = machineAt(x, y);
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
        return false;
    }
    return false;
}

ItemId Simulation::extractItemAt(int x, int y, ItemId filterItem)
{
    auto* machine = machineAt(x, y);
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
    return acceptItemAt(machine.x + dx(machine.direction), machine.y + dy(machine.direction), item);
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
        kind == MachineKind::RiftGate;
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
    if (kind == MachineKind::ArchiveTerminal || kind == MachineKind::RiftGate) {
        return 2;
    }
    return 0;
}

bool Simulation::hasAdjacentWater(int x, int y) const
{
    for (const auto direction : {Direction::North, Direction::East, Direction::South, Direction::West}) {
        if (world_.getTile(x + dx(direction), y + dy(direction)).id == TileId::Water) {
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
        const auto* machine = machineAt(player_.x + dx(direction), player_.y + dy(direction));
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
