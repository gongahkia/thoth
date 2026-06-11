#pragma once

#include "thoth/game/inventory.hpp"
#include "thoth/game/registry.hpp"
#include "thoth/game/world.hpp"

#include <array>
#include <cstddef>
#include <cstdint>
#include <optional>
#include <string>
#include <string_view>
#include <unordered_map>
#include <vector>

namespace thoth::game {

enum class Direction : std::uint8_t {
    North,
    East,
    South,
    West,
};

enum class CommandType : std::uint8_t {
    Face,
    Move,
    Mine,
    Place,
    Craft,
    SelectHotbar,
    AssignHotbar,
    ConfigureMachineRecipe,
    DepositSelected,
    DepositItem,
    WithdrawItem,
    ConfigureCircuit,
    ConfigureRequest,
    Interact,
    Attack,
};

enum class MachineStatus : std::uint8_t {
    Idle,
    MissingInput,
    MissingFuel,
    MissingPower,
    Working,
    OutputBlocked,
};

enum class CircuitComparator : std::uint8_t {
    Always,
    LessThan,
    GreaterOrEqual,
};

inline constexpr int kHotbarSlots = 10;

struct Player {
    int x = 0;
    int y = 0;
    int z = 0;
    Direction facing = Direction::South;
    Inventory inventory;
    std::array<ItemId, kHotbarSlots> hotbar{};
    int selectedHotbar = 0;
    bool inBoat = false;
    int hp = 20;
};

struct Machine {
    std::uint32_t id = 0;
    MachineKind kind = MachineKind::Chest;
    int x = 0;
    int y = 0;
    int z = 0;
    Direction direction = Direction::South;
    Inventory inventory;
    int progress = 0;
    int fuelTicks = 0;
    ItemId carriedItem = ItemId::None;
    ItemId outputItem = ItemId::None;
    std::string recipeKey;
    bool recipeLocked = false;
    ItemId filterItem = ItemId::None;
    CircuitComparator circuitComparator = CircuitComparator::Always;
    int circuitThreshold = 0;
    ItemId requestItem = ItemId::None;
    int requestThreshold = 0;
    MachineStatus status = MachineStatus::Idle;
};

// Prototype power rules:
// - Power poles connect to poles within Manhattan distance <= 4.
// - Generators and electric consumers connect to any pole within Manhattan distance <= 2.
// - If a network's supply is below demand, all electric consumers in that network stop.
struct PowerNetwork {
    std::uint32_t id = 0;
    int supply = 0;
    int demand = 0;
    bool powered = false;
    std::vector<std::uint32_t> poleIds;
    std::vector<std::uint32_t> generatorIds;
    std::vector<std::uint32_t> consumerIds;
};

struct LogisticJob {
    std::uint32_t portId = 0;
    std::uint32_t sourceId = 0;
    std::uint32_t targetId = 0;
    ItemId item = ItemId::None;
    int ticksRemaining = 0;
    int totalTicks = 0;
};

struct ProductionTotals {
    int ironPlates = 0;
    int copperPlates = 0;
    int sciencePacks = 0;
    int advancedSciencePacks = 0;
    int logisticDeliveries = 0;
    int poweredOre = 0;
    int archiveSignals = 0;
    int trainDeliveries = 0;
    int waterBarrels = 0;
    int riftJumps = 0;
    int creaturesDefeated = 0;
    int dungeonChestsOpened = 0;
    int bossesDefeated = 0;
};

struct BiomeContractProgress {
    BiomeKind biome = BiomeKind::Grassland;
    std::string label;
    int current = 0;
    int required = 0;
    bool complete = false;
};

enum class EntityKind : std::uint8_t {
    Deer,
    Chicken,
    Crab,
    Fish,
    Slime,
    Skeleton,
    CaveCrawler,
    DungeonSentinel,
    MarshBroodheart,
};

struct Entity {
    std::uint32_t id = 0;
    EntityKind kind = EntityKind::Deer;
    int x = 0;
    int y = 0;
    int z = 0;
    int hp = 1;
    Direction facing = Direction::South;
    int cooldown = 0;
};

struct Command {
    CommandType type = CommandType::Move;
    Direction direction = Direction::South;
    Direction orientation = Direction::South;
    TileId tile = TileId::Floor;
    ItemId item = ItemId::None;
    int hotbarIndex = 0;
    CircuitComparator comparator = CircuitComparator::Always;
    int amount = 0;
    std::string recipeKey;

    [[nodiscard]] static Command face(Direction direction);
    [[nodiscard]] static Command move(Direction direction);
    [[nodiscard]] static Command mine(Direction direction);
    [[nodiscard]] static Command placeItem(Direction direction, ItemId item);
    [[nodiscard]] static Command placeItem(Direction direction, ItemId item, Direction orientation);
    [[nodiscard]] static Command placeTile(Direction direction, TileId tile);
    [[nodiscard]] static Command craft(std::string recipeKey);
    [[nodiscard]] static Command selectHotbar(int index);
    [[nodiscard]] static Command assignHotbar(int index, ItemId item);
    [[nodiscard]] static Command configureMachineRecipe(Direction direction, std::string recipeKey);
    [[nodiscard]] static Command depositSelected(Direction direction);
    [[nodiscard]] static Command depositItem(Direction direction, ItemId item);
    [[nodiscard]] static Command withdrawItem(Direction direction, ItemId item);
    [[nodiscard]] static Command configureCircuit(Direction direction, ItemId filterItem, CircuitComparator comparator, int threshold);
    [[nodiscard]] static Command configureRequest(Direction direction, ItemId requestItem, int threshold);
    [[nodiscard]] static Command interact(Direction direction);
    [[nodiscard]] static Command attack(Direction direction);
};

struct PlayerSnapshot {
    int x = 0;
    int y = 0;
    int z = 0;
    Direction facing = Direction::South;
    int selectedHotbar = 0;
    std::array<ItemId, kHotbarSlots> hotbar{};
    std::vector<ItemStack> inventory;
    bool inBoat = false;
    int hp = 20;
};

struct SimulationSnapshot {
    std::uint64_t seed = 0;
    std::uint64_t tick = 0;
    PlayerSnapshot player;
    std::vector<TileSnapshot> tiles;
    std::uint32_t nextMachineId = 1;
    std::uint32_t nextEntityId = 1;
    std::vector<Machine> machines;
    std::vector<Entity> entities;
    std::vector<LogisticJob> logisticJobs;
    ProductionTotals productionTotals;
    std::string activeTech = "logistics_1";
    int researchProgress = 0;
    std::vector<std::string> completedTechs;
    std::vector<std::string> unlockedRecipes;
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
    [[nodiscard]] const Machine* machineAt(int x, int y, int z) const;
    [[nodiscard]] Machine* machineAt(int x, int y);
    [[nodiscard]] Machine* machineAt(int x, int y, int z);
    [[nodiscard]] const std::vector<Entity>& entities() const;
    [[nodiscard]] const Entity* entityAt(int x, int y, int z) const;
    [[nodiscard]] bool isRecipeUnlocked(std::string_view recipeKey) const;
    [[nodiscard]] bool isTechCompleted(std::string_view techKey) const;
    [[nodiscard]] std::string_view activeTech() const;
    [[nodiscard]] int researchProgress() const;
    [[nodiscard]] int researchGoal() const;
    [[nodiscard]] const std::vector<PowerNetwork>& powerNetworks() const;
    [[nodiscard]] const std::vector<LogisticJob>& logisticJobs() const;
    [[nodiscard]] const ProductionTotals& productionTotals() const;
    [[nodiscard]] bool canCraft(std::string_view recipeKey) const;
    [[nodiscard]] int completedSupplyContracts() const;
    [[nodiscard]] int totalSupplyContracts() const;
    [[nodiscard]] std::string currentSupplyContractText() const;
    [[nodiscard]] int factoryPressureLevel() const;
    [[nodiscard]] std::string factoryPressureText() const;
    [[nodiscard]] bool mainObjectiveComplete() const;
    [[nodiscard]] int completedBiomeContracts() const;
    [[nodiscard]] std::vector<BiomeContractProgress> biomeContractProgress() const;
    [[nodiscard]] std::string currentBiomeContractText() const;
    [[nodiscard]] std::string milestoneText() const;
    [[nodiscard]] bool isMachinePowered(std::uint32_t machineId) const;
    [[nodiscard]] SimulationSnapshot snapshot() const;
    void restore(const SimulationSnapshot& snapshot);
    [[nodiscard]] static Simulation fromSnapshot(const SimulationSnapshot& snapshot);

private:
    void apply(const Command& command);
    void move(Direction direction);
    void mine(Direction direction);
    void place(Direction direction, TileId tile, ItemId item, Direction orientation);
    void placeMachine(Direction direction, ItemId item, Direction orientation);
    void depositSelected(Direction direction);
    void depositItem(Direction direction, ItemId item);
    void withdrawItem(Direction direction, ItemId item);
    void craft(std::string_view recipeKey);
    void selectHotbar(int index);
    void assignHotbarSlot(int index, ItemId item);
    void configureMachineRecipe(Direction direction, std::string_view recipeKey);
    void configureCircuit(Direction direction, ItemId filterItem, CircuitComparator comparator, int threshold);
    void configureRequest(Direction direction, ItemId requestItem, int threshold);
    void interact(Direction direction);
    void attack(Direction direction);
    [[nodiscard]] bool trySummonMarshBoss(int x, int y, int z);
    void updateMachines();
    void updateEntities();
    void ensureLocalEntities();
    void ensureLairEntities();
    void ensureFactoryPressureEntity();
    void updatePowerNetworks();
    void updateMiners();
    void updateElectricMiners();
    void updateBelts();
    void updateSplitters();
    void updateInserters();
    void updateFurnaces();
    void updateAssemblers();
    void updateLabs();
    void updateLogistics();
    void updateTrainStops();
    void updateFluidPumps();
    void updatePipes();
    void updateArchiveTerminals();
    void updateRiftGates();
    [[nodiscard]] bool canPlaceMachine(MachineKind kind, int x, int y) const;
    [[nodiscard]] bool canPlaceMachine(MachineKind kind, int x, int y, int z) const;
    [[nodiscard]] bool acceptItemAt(int x, int y, ItemId item);
    [[nodiscard]] bool acceptItemAt(int x, int y, int z, ItemId item);
    [[nodiscard]] bool acceptItem(Machine& machine, ItemId item);
    [[nodiscard]] ItemId extractItemAt(int x, int y, ItemId filterItem = ItemId::None);
    [[nodiscard]] ItemId extractItemAt(int x, int y, int z, ItemId filterItem = ItemId::None);
    [[nodiscard]] ItemId extractItem(Machine& machine, ItemId filterItem = ItemId::None);
    [[nodiscard]] bool returnItem(Machine& machine, ItemId item);
    [[nodiscard]] bool outputItem(Machine& machine, ItemId item);
    [[nodiscard]] bool refuel(Machine& machine);
    [[nodiscard]] bool isMachineItem(ItemId item) const;
    [[nodiscard]] bool isBelt(MachineKind kind) const;
    [[nodiscard]] bool isPipe(MachineKind kind) const;
    [[nodiscard]] bool isPowerPole(MachineKind kind) const;
    [[nodiscard]] bool isPowerConsumer(MachineKind kind) const;
    [[nodiscard]] bool isLogisticStorage(MachineKind kind) const;
    [[nodiscard]] int powerDemand(MachineKind kind) const;
    [[nodiscard]] bool hasAdjacentWater(int x, int y) const;
    [[nodiscard]] bool hasAdjacentWater(int x, int y, int z) const;
    [[nodiscard]] Machine* machineById(std::uint32_t id);
    [[nodiscard]] const Machine* machineById(std::uint32_t id) const;
    [[nodiscard]] bool isRecipeInput(std::string_view recipeKey, ItemId item) const;
    [[nodiscard]] bool isAdjacentToWorkbench() const;
    [[nodiscard]] bool canCraftAtCurrentStation(const RecipeDef& recipe) const;
    [[nodiscard]] bool circuitConditionAllows(const Machine& inserter, const Machine* target) const;
    [[nodiscard]] int countMachineItem(const Machine& machine, ItemId item) const;
    [[nodiscard]] int totalItemCount(ItemId item) const;
    [[nodiscard]] std::vector<std::uint32_t> poweredLogisticPortIds() const;
    [[nodiscard]] bool isWaterTile(TileId id) const;
    [[nodiscard]] bool isHostile(EntityKind kind) const;
    [[nodiscard]] ItemId entityDrop(EntityKind kind) const;
    [[nodiscard]] int entityDropCount(EntityKind kind) const;
    [[nodiscard]] int entityMaxHp(EntityKind kind) const;
    [[nodiscard]] std::optional<EntityKind> localEntityKindForTile(int x, int y, int z) const;
    [[nodiscard]] int activeTechGoal() const;
    [[nodiscard]] std::string nextIncompleteTech() const;
    void rebuildMachineCellIndex();
    void completeActiveTech();
    void recordProduced(ItemId item, MachineKind producer);
    void addItem(ItemId item, int count);
    [[nodiscard]] bool consumeItem(ItemId item, int count);
    void assignHotbar(ItemId item);

    World world_;
    Player player_;
    std::uint64_t tick_ = 0;
    std::uint32_t nextMachineId_ = 1;
    std::uint32_t nextEntityId_ = 1;
    std::vector<Machine> machines_;
    std::vector<Entity> entities_;
    std::unordered_map<std::uint64_t, std::size_t> machineCellIndex_;
    std::vector<Command> commandQueue_;
    std::string activeTech_ = "logistics_1";
    int researchProgress_ = 0;
    std::vector<std::string> completedTechs_;
    std::vector<std::string> unlockedRecipes_;
    std::vector<PowerNetwork> powerNetworks_;
    std::vector<std::uint32_t> poweredMachineIds_;
    std::vector<LogisticJob> logisticJobs_;
    ProductionTotals productionTotals_;
};

[[nodiscard]] int dx(Direction direction);
[[nodiscard]] int dy(Direction direction);
[[nodiscard]] std::string_view toString(MachineStatus status);
[[nodiscard]] std::string_view toString(CircuitComparator comparator);
[[nodiscard]] CircuitComparator circuitComparatorFromKey(std::string_view key);

} // namespace thoth::game
