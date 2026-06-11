#pragma once

#include <cstdint>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

namespace thoth::game {

enum class TileId : std::uint8_t {
    Grass,
    Dirt,
    Sand,
    Beach,
    Snow,
    Ice,
    Mud,
    Reeds,
    Cactus,
    Stone,
    Basalt,
    Crystal,
    Tree,
    Water,
    DeepWater,
    Coral,
    IronOre,
    CopperOre,
    CoalOre,
    Floor,
    Wall,
    PlankWall,
    Door,
    StairsUp,
    StairsDown,
    Bed,
    DungeonFloor,
    DungeonWall,
};

enum class ItemId : std::uint8_t {
    None,
    Wood,
    Stone,
    Coal,
    IronOre,
    IronPlate,
    CopperOre,
    CopperPlate,
    Sand,
    SandGlass,
    ReedFiber,
    CactusFiber,
    Kelp,
    Shell,
    CoralShard,
    IceShard,
    Basalt,
    Crystal,
    Hide,
    Bone,
    Slime,
    Venom,
    Belt,
    Inserter,
    BurnerMiner,
    Furnace,
    Chest,
    Workbench,
    SciencePack,
    Assembler,
    Lab,
    FastBelt,
    Generator,
    PowerPole,
    ElectricMiner,
    CircuitBoard,
    AdvancedSciencePack,
    CircuitInserter,
    ProviderChest,
    RequesterChest,
    LogisticPort,
    LogisticDrone,
    BeaconCore,
    ArchiveTerminal,
    Splitter,
    TrainStop,
    WaterBarrel,
    Pipe,
    OffshorePump,
    RiftGate,
    GuardTower,
    Wall,
    PlankWall,
    Door,
    StairsUp,
    StairsDown,
    Boat,
    Bed,
};

enum class MachineKind : std::uint8_t {
    Belt,
    FastBelt,
    Inserter,
    BurnerMiner,
    Furnace,
    Chest,
    Workbench,
    Assembler,
    Lab,
    Generator,
    PowerPole,
    ElectricMiner,
    CircuitInserter,
    ProviderChest,
    RequesterChest,
    LogisticPort,
    ArchiveTerminal,
    Splitter,
    TrainStop,
    Pipe,
    OffshorePump,
    RiftGate,
    GuardTower,
};

enum class MachineBehaviorKind : std::uint8_t {
    TransportBelt,
    Inserter,
    BurnerMiner,
    Furnace,
    Storage,
    CraftingStation,
    Assembler,
    Lab,
    Generator,
    PowerPole,
    ElectricMiner,
    CircuitInserter,
    LogisticStorage,
    LogisticPort,
    ArchiveTerminal,
    Splitter,
    TrainStop,
    Pipe,
    OffshorePump,
    RiftGate,
    GuardTower,
};

struct Rgb {
    unsigned char r;
    unsigned char g;
    unsigned char b;
};

struct TileDef {
    TileId id;
    std::string_view key;
    std::string_view displayName;
    int hardness;
    bool walkable;
    bool buildable;
    ItemId drop;
    Rgb color;
};

struct ItemDef {
    ItemId id;
    std::string_view key;
    std::string_view displayName;
    int stackSize;
    TileId placeTile;
    bool canPlaceTile;
    MachineKind placeMachine;
    bool canPlaceMachine;
};

struct MachineDef {
    MachineKind id;
    std::string_view key;
    std::string_view displayName;
    int width;
    int height;
    bool blocksMovement;
    bool requiresBuildableTile;
    bool requiresResourceTile;
    int inventorySlots;
    MachineBehaviorKind behavior;
};

struct ItemStack {
    ItemId item;
    int count;
};

struct RecipeDef {
    std::string_view key;
    std::vector<ItemStack> inputs;
    ItemStack output;
    int ticks;
    std::string_view station;
    bool unlockedByDefault;
};

struct TechDef {
    std::string_view key;
    std::string_view displayName;
    std::vector<ItemStack> inputs;
    int ticks;
    std::vector<std::string_view> unlockRecipes;
};

[[nodiscard]] const std::vector<TileDef>& tileDefs();
[[nodiscard]] const std::vector<ItemDef>& itemDefs();
[[nodiscard]] const std::vector<MachineDef>& machineDefs();
[[nodiscard]] const std::vector<RecipeDef>& recipeDefs();
[[nodiscard]] const std::vector<TechDef>& techDefs();

[[nodiscard]] const TileDef& tileDef(TileId id);
[[nodiscard]] const ItemDef& itemDef(ItemId id);
[[nodiscard]] const MachineDef& machineDef(MachineKind id);
[[nodiscard]] const RecipeDef* recipeDef(std::string_view key);
[[nodiscard]] const TechDef* techDef(std::string_view key);
[[nodiscard]] std::string_view toString(TileId id);
[[nodiscard]] std::string_view toString(ItemId id);
[[nodiscard]] std::optional<TileId> tileIdFromKey(std::string_view key);
[[nodiscard]] std::optional<ItemId> itemIdFromKey(std::string_view key);
[[nodiscard]] std::string_view toString(MachineKind kind);
[[nodiscard]] std::string_view toString(MachineBehaviorKind behavior);
[[nodiscard]] std::optional<MachineKind> machineKindFromKey(std::string_view key);
[[nodiscard]] std::vector<std::string> validateRegistries();
[[nodiscard]] bool isWalkable(TileId id);
[[nodiscard]] bool isMineable(TileId id);

} // namespace thoth::game
