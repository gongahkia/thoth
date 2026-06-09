#pragma once

#include "thoth/game/inventory.hpp"
#include "thoth/game/registry.hpp"
#include "thoth/game/world.hpp"

#include <array>
#include <cstdint>
#include <string>
#include <string_view>
#include <vector>

namespace thoth::game {

enum class Direction : std::uint8_t {
    North,
    East,
    South,
    West,
};

enum class CommandType : std::uint8_t {
    Move,
    Mine,
    Place,
    Craft,
    SelectHotbar,
};

inline constexpr int kHotbarSlots = 10;

struct Player {
    int x = 0;
    int y = 0;
    Direction facing = Direction::South;
    Inventory inventory;
    std::array<ItemId, kHotbarSlots> hotbar{};
    int selectedHotbar = 0;
};

struct Machine {
    std::uint32_t id = 0;
    MachineKind kind = MachineKind::Chest;
    int x = 0;
    int y = 0;
    Direction direction = Direction::South;
    Inventory inventory;
    int progress = 0;
    ItemId carriedItem = ItemId::None;
};

struct Command {
    CommandType type = CommandType::Move;
    Direction direction = Direction::South;
    TileId tile = TileId::Floor;
    ItemId item = ItemId::None;
    int hotbarIndex = 0;
    std::string recipeKey;

    [[nodiscard]] static Command move(Direction direction);
    [[nodiscard]] static Command mine(Direction direction);
    [[nodiscard]] static Command placeItem(Direction direction, ItemId item);
    [[nodiscard]] static Command placeTile(Direction direction, TileId tile);
    [[nodiscard]] static Command craft(std::string recipeKey);
    [[nodiscard]] static Command selectHotbar(int index);
};

struct PlayerSnapshot {
    int x = 0;
    int y = 0;
    Direction facing = Direction::South;
    int selectedHotbar = 0;
    std::array<ItemId, kHotbarSlots> hotbar{};
    std::vector<ItemStack> inventory;
};

struct SimulationSnapshot {
    std::uint64_t seed = 0;
    std::uint64_t tick = 0;
    PlayerSnapshot player;
    std::vector<TileSnapshot> tiles;
    std::uint32_t nextMachineId = 1;
    std::vector<Machine> machines;
};

class Simulation {
public:
    explicit Simulation(std::uint64_t seed);

    void queue(Command command);
    void step();

    [[nodiscard]] World& world();
    [[nodiscard]] const World& world() const;
    [[nodiscard]] Player& player();
    [[nodiscard]] const Player& player() const;
    [[nodiscard]] std::uint64_t tick() const;
    [[nodiscard]] int itemCount(ItemId item) const;
    [[nodiscard]] ItemId selectedItem() const;
    [[nodiscard]] const std::vector<Machine>& machines() const;
    [[nodiscard]] const Machine* machineAt(int x, int y) const;
    [[nodiscard]] Machine* machineAt(int x, int y);
    [[nodiscard]] SimulationSnapshot snapshot() const;
    void restore(const SimulationSnapshot& snapshot);
    [[nodiscard]] static Simulation fromSnapshot(const SimulationSnapshot& snapshot);

private:
    void apply(const Command& command);
    void move(Direction direction);
    void mine(Direction direction);
    void place(Direction direction, TileId tile, ItemId item);
    void placeMachine(Direction direction, ItemId item);
    void craft(std::string_view recipeKey);
    void selectHotbar(int index);
    void updateMachines();
    void updateMiners();
    void updateBelts();
    void updateFurnaces();
    [[nodiscard]] bool canPlaceMachine(MachineKind kind, int x, int y) const;
    [[nodiscard]] bool acceptItemAt(int x, int y, ItemId item);
    [[nodiscard]] bool acceptItem(Machine& machine, ItemId item);
    [[nodiscard]] bool outputItem(Machine& machine, ItemId item);
    [[nodiscard]] bool isMachineItem(ItemId item) const;
    void addItem(ItemId item, int count);
    [[nodiscard]] bool consumeItem(ItemId item, int count);
    void assignHotbar(ItemId item);

    World world_;
    Player player_;
    std::uint64_t tick_ = 0;
    std::uint32_t nextMachineId_ = 1;
    std::vector<Machine> machines_;
    std::vector<Command> commandQueue_;
};

[[nodiscard]] int dx(Direction direction);
[[nodiscard]] int dy(Direction direction);

} // namespace thoth::game
