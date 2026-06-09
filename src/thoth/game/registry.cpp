#include "thoth/game/registry.hpp"

#include <stdexcept>

namespace thoth::game {
namespace {

const std::vector<TileDef> kTiles = {
    {TileId::Grass, "grass", "Grass", 1, true, true, ItemId::None, Rgb{76, 154, 84}},
    {TileId::Dirt, "dirt", "Dirt", 1, true, true, ItemId::Stone, Rgb{118, 82, 55}},
    {TileId::Stone, "stone", "Stone", 3, false, true, ItemId::Stone, Rgb{106, 112, 111}},
    {TileId::Tree, "tree", "Tree", 2, false, false, ItemId::Wood, Rgb{49, 104, 56}},
    {TileId::Water, "water", "Water", -1, false, false, ItemId::None, Rgb{58, 111, 168}},
    {TileId::IronOre, "iron_ore", "Iron Ore", 3, false, false, ItemId::IronOre, Rgb{145, 126, 105}},
    {TileId::CoalOre, "coal_ore", "Coal Ore", 3, false, false, ItemId::Coal, Rgb{55, 58, 61}},
    {TileId::Floor, "floor", "Floor", 1, true, true, ItemId::Stone, Rgb{132, 122, 100}},
};

const std::vector<ItemDef> kItems = {
    {ItemId::None, "none", "None", 0, TileId::Grass, false, MachineKind::Chest, false},
    {ItemId::Wood, "wood", "Wood", 100, TileId::Grass, false, MachineKind::Chest, false},
    {ItemId::Stone, "stone", "Stone", 100, TileId::Floor, true, MachineKind::Chest, false},
    {ItemId::Coal, "coal", "Coal", 100, TileId::Grass, false, MachineKind::Chest, false},
    {ItemId::IronOre, "iron_ore", "Iron Ore", 100, TileId::IronOre, false, MachineKind::Chest, false},
    {ItemId::IronPlate, "iron_plate", "Iron Plate", 100, TileId::Grass, false, MachineKind::Chest, false},
    {ItemId::Belt, "belt", "Belt", 100, TileId::Floor, false, MachineKind::Belt, true},
    {ItemId::BurnerMiner, "burner_miner", "Burner Miner", 50, TileId::Floor, false, MachineKind::BurnerMiner, true},
    {ItemId::Furnace, "furnace", "Furnace", 50, TileId::Floor, false, MachineKind::Furnace, true},
    {ItemId::Chest, "chest", "Chest", 50, TileId::Floor, false, MachineKind::Chest, true},
    {ItemId::Workbench, "workbench", "Workbench", 50, TileId::Floor, false, MachineKind::Workbench, true},
};

const std::vector<RecipeDef> kRecipes = {
    {"furnace", {ItemStack{ItemId::Stone, 8}}, ItemStack{ItemId::Furnace, 1}, 30, "hand"},
    {"chest", {ItemStack{ItemId::Wood, 8}}, ItemStack{ItemId::Chest, 1}, 20, "hand"},
    {"belt", {ItemStack{ItemId::IronPlate, 1}}, ItemStack{ItemId::Belt, 2}, 15, "hand"},
    {"burner_miner", {ItemStack{ItemId::Stone, 6}, ItemStack{ItemId::IronPlate, 4}}, ItemStack{ItemId::BurnerMiner, 1}, 45, "workbench"},
    {"iron_plate", {ItemStack{ItemId::IronOre, 1}, ItemStack{ItemId::Coal, 1}}, ItemStack{ItemId::IronPlate, 1}, 60, "furnace"},
};

template <typename TId, typename TDef>
const TDef& findById(const std::vector<TDef>& defs, TId id)
{
    for (const auto& def : defs) {
        if (def.id == id) {
            return def;
        }
    }
    throw std::out_of_range("registry id not found");
}

} // namespace

const std::vector<TileDef>& tileDefs()
{
    return kTiles;
}

const std::vector<ItemDef>& itemDefs()
{
    return kItems;
}

const std::vector<RecipeDef>& recipeDefs()
{
    return kRecipes;
}

const TileDef& tileDef(TileId id)
{
    return findById(kTiles, id);
}

const ItemDef& itemDef(ItemId id)
{
    return findById(kItems, id);
}

const RecipeDef* recipeDef(std::string_view key)
{
    for (const auto& recipe : kRecipes) {
        if (recipe.key == key) {
            return &recipe;
        }
    }
    return nullptr;
}

std::string_view toString(TileId id)
{
    return tileDef(id).key;
}

std::string_view toString(ItemId id)
{
    return itemDef(id).key;
}

std::optional<TileId> tileIdFromKey(std::string_view key)
{
    for (const auto& def : kTiles) {
        if (def.key == key) {
            return def.id;
        }
    }
    return std::nullopt;
}

std::optional<ItemId> itemIdFromKey(std::string_view key)
{
    for (const auto& def : kItems) {
        if (def.key == key) {
            return def.id;
        }
    }
    return std::nullopt;
}

std::string_view toString(MachineKind kind)
{
    switch (kind) {
    case MachineKind::Belt:
        return "belt";
    case MachineKind::BurnerMiner:
        return "burner_miner";
    case MachineKind::Furnace:
        return "furnace";
    case MachineKind::Chest:
        return "chest";
    case MachineKind::Workbench:
        return "workbench";
    }
    return "chest";
}

std::optional<MachineKind> machineKindFromKey(std::string_view key)
{
    if (key == "belt") {
        return MachineKind::Belt;
    }
    if (key == "burner_miner") {
        return MachineKind::BurnerMiner;
    }
    if (key == "furnace") {
        return MachineKind::Furnace;
    }
    if (key == "chest") {
        return MachineKind::Chest;
    }
    if (key == "workbench") {
        return MachineKind::Workbench;
    }
    return std::nullopt;
}

bool isWalkable(TileId id)
{
    return tileDef(id).walkable;
}

bool isMineable(TileId id)
{
    return tileDef(id).hardness >= 0 && tileDef(id).drop != ItemId::None;
}

} // namespace thoth::game
