#include "thoth/game/simulation.hpp"

#include <algorithm>
#include <stdexcept>
#include <utility>

namespace thoth::game {

namespace {

TileId minedReplacement(TileId id)
{
    switch (id) {
    case TileId::Tree:
        return TileId::Grass;
    case TileId::Stone:
    case TileId::IronOre:
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

} // namespace

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
    Command command;
    command.type = CommandType::Place;
    command.direction = direction;
    command.item = item;
    return command;
}

Command Command::placeTile(Direction direction, TileId tile)
{
    Command command;
    command.type = CommandType::Place;
    command.direction = direction;
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
    for (const auto& machine : machines_) {
        if (machine.x == x && machine.y == y) {
            return &machine;
        }
    }
    return nullptr;
}

Machine* Simulation::machineAt(int x, int y)
{
    for (auto& machine : machines_) {
        if (machine.x == x && machine.y == y) {
            return &machine;
        }
    }
    return nullptr;
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
    commandQueue_.clear();
}

Simulation Simulation::fromSnapshot(const SimulationSnapshot& snapshot)
{
    Simulation simulation(snapshot.seed);
    simulation.restore(snapshot);
    return simulation;
}

void Simulation::apply(const Command& command)
{
    switch (command.type) {
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
        place(command.direction, command.tile, command.item);
        break;
    case CommandType::Craft:
        craft(command.recipeKey);
        break;
    case CommandType::SelectHotbar:
        selectHotbar(command.hotbarIndex);
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

void Simulation::place(Direction direction, TileId tile, ItemId item)
{
    if (isMachineItem(item)) {
        placeMachine(direction, item);
        return;
    }

    const int tx = player_.x + dx(direction);
    const int ty = player_.y + dy(direction);

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

    if (!world_.isWalkable(tx, ty) || !tileDef(tileToPlace).walkable) {
        return;
    }

    if (requiredItem != ItemId::None && !consumeItem(requiredItem, 1)) {
        return;
    }
    world_.setTile(tx, ty, Tile{tileToPlace, 0});
}

void Simulation::placeMachine(Direction direction, ItemId item)
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
    machine.direction = direction;
    machines_.push_back(std::move(machine));

    std::sort(machines_.begin(), machines_.end(), [](const Machine& left, const Machine& right) {
        return left.id < right.id;
    });
}

void Simulation::craft(std::string_view recipeKey)
{
    const auto* recipe = recipeDef(recipeKey);
    if (recipe == nullptr) {
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

void Simulation::updateMachines()
{
    updateMiners();
    updateBelts();
    updateFurnaces();
}

void Simulation::updateMiners()
{
    constexpr int kMinerTicks = 10;
    for (auto& machine : machines_) {
        if (machine.kind != MachineKind::BurnerMiner) {
            continue;
        }

        const auto tile = world_.getTile(machine.x, machine.y);
        ItemId output = ItemId::None;
        if (tile.id == TileId::IronOre) {
            output = ItemId::IronOre;
        } else if (tile.id == TileId::CoalOre) {
            output = ItemId::Coal;
        }

        if (output == ItemId::None) {
            machine.progress = 0;
            continue;
        }

        machine.progress = std::min(machine.progress + 1, kMinerTicks);
        if (machine.progress >= kMinerTicks && outputItem(machine, output)) {
            machine.progress = 0;
        }
    }
}

void Simulation::updateBelts()
{
    std::vector<std::uint32_t> sourceIds;
    for (const auto& machine : machines_) {
        if (machine.kind == MachineKind::Belt && machine.carriedItem != ItemId::None) {
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

        if (machine.progress == 0) {
            if (!machine.inventory.canConsume(ItemId::IronOre, 1) ||
                !machine.inventory.canConsume(ItemId::Coal, 1)) {
                continue;
            }
            const auto consumedOre = machine.inventory.consume(ItemId::IronOre, 1);
            const auto consumedCoal = machine.inventory.consume(ItemId::Coal, 1);
            (void)consumedOre;
            (void)consumedCoal;
        }

        machine.progress = std::min(machine.progress + 1, kFurnaceTicks);
        if (machine.progress >= kFurnaceTicks && outputItem(machine, ItemId::IronPlate)) {
            machine.progress = 0;
        }
    }
}

bool Simulation::canPlaceMachine(MachineKind kind, int x, int y) const
{
    if (machineAt(x, y) != nullptr) {
        return false;
    }

    const auto tile = world_.getTile(x, y);
    if (kind == MachineKind::BurnerMiner) {
        return tile.id == TileId::IronOre || tile.id == TileId::CoalOre;
    }
    return tileDef(tile.id).walkable && tileDef(tile.id).buildable;
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
        if (machine.carriedItem != ItemId::None) {
            return false;
        }
        machine.carriedItem = item;
        return true;
    case MachineKind::Chest:
        return machine.inventory.add(item, 1);
    case MachineKind::Furnace:
        if (item != ItemId::IronOre && item != ItemId::Coal) {
            return false;
        }
        return machine.inventory.add(item, 1);
    case MachineKind::BurnerMiner:
    case MachineKind::Workbench:
        return false;
    }
    return false;
}

bool Simulation::outputItem(Machine& machine, ItemId item)
{
    return acceptItemAt(machine.x + dx(machine.direction), machine.y + dy(machine.direction), item);
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

    const auto& def = itemDef(item);
    if (!def.canPlaceTile && item != ItemId::Belt && item != ItemId::BurnerMiner &&
        item != ItemId::Furnace && item != ItemId::Chest && item != ItemId::Workbench) {
        return;
    }

    for (auto& slot : player_.hotbar) {
        if (slot == ItemId::None) {
            slot = item;
            return;
        }
    }
}

} // namespace thoth::game
