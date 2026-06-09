#pragma once

#include <cstdint>
#include <optional>
#include <string_view>
#include <vector>

namespace thoth::game {

enum class TileId : std::uint8_t {
    Grass,
    Dirt,
    Stone,
    Tree,
    Water,
    IronOre,
    CoalOre,
    Floor,
};

enum class ItemId : std::uint8_t {
    None,
    Wood,
    Stone,
    Coal,
    IronOre,
    IronPlate,
    Belt,
    BurnerMiner,
    Furnace,
    Chest,
    Workbench,
};

enum class MachineKind : std::uint8_t {
    Belt,
    BurnerMiner,
    Furnace,
    Chest,
    Workbench,
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
};

[[nodiscard]] const std::vector<TileDef>& tileDefs();
[[nodiscard]] const std::vector<ItemDef>& itemDefs();
[[nodiscard]] const std::vector<RecipeDef>& recipeDefs();

[[nodiscard]] const TileDef& tileDef(TileId id);
[[nodiscard]] const ItemDef& itemDef(ItemId id);
[[nodiscard]] const RecipeDef* recipeDef(std::string_view key);
[[nodiscard]] std::string_view toString(TileId id);
[[nodiscard]] std::string_view toString(ItemId id);
[[nodiscard]] std::optional<TileId> tileIdFromKey(std::string_view key);
[[nodiscard]] std::optional<ItemId> itemIdFromKey(std::string_view key);
[[nodiscard]] std::string_view toString(MachineKind kind);
[[nodiscard]] std::optional<MachineKind> machineKindFromKey(std::string_view key);
[[nodiscard]] bool isWalkable(TileId id);
[[nodiscard]] bool isMineable(TileId id);

} // namespace thoth::game
