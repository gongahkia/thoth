#include "thoth/game/registry.hpp"

#include <algorithm>
#include <stdexcept>
#include <string>
#include <unordered_set>
#include <utility>

namespace thoth::game {
namespace {

const std::vector<TileDef> kTiles = {
    {TileId::Grass, "grass", "Grass", 1, true, true, ItemId::None, Rgb{76, 154, 84}},
    {TileId::Dirt, "dirt", "Dirt", 1, true, true, ItemId::Stone, Rgb{118, 82, 55}},
    {TileId::Stone, "stone", "Stone", 3, false, true, ItemId::Stone, Rgb{106, 112, 111}},
    {TileId::Tree, "tree", "Tree", 2, false, false, ItemId::Wood, Rgb{49, 104, 56}},
    {TileId::Water, "water", "Water", -1, false, false, ItemId::None, Rgb{58, 111, 168}},
    {TileId::IronOre, "iron_ore", "Iron Ore", 3, false, false, ItemId::IronOre, Rgb{145, 126, 105}},
    {TileId::CopperOre, "copper_ore", "Copper Ore", 3, false, false, ItemId::CopperOre, Rgb{153, 102, 70}},
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
    {ItemId::CopperOre, "copper_ore", "Copper Ore", 100, TileId::CopperOre, false, MachineKind::Chest, false},
    {ItemId::CopperPlate, "copper_plate", "Copper Plate", 100, TileId::Grass, false, MachineKind::Chest, false},
    {ItemId::Belt, "belt", "Belt", 100, TileId::Floor, false, MachineKind::Belt, true},
    {ItemId::Inserter, "inserter", "Inserter", 100, TileId::Floor, false, MachineKind::Inserter, true},
    {ItemId::BurnerMiner, "burner_miner", "Burner Miner", 50, TileId::Floor, false, MachineKind::BurnerMiner, true},
    {ItemId::Furnace, "furnace", "Furnace", 50, TileId::Floor, false, MachineKind::Furnace, true},
    {ItemId::Chest, "chest", "Chest", 50, TileId::Floor, false, MachineKind::Chest, true},
    {ItemId::Workbench, "workbench", "Workbench", 50, TileId::Floor, false, MachineKind::Workbench, true},
    {ItemId::SciencePack, "science_pack", "Science Pack", 100, TileId::Grass, false, MachineKind::Chest, false},
    {ItemId::Assembler, "assembler", "Assembler", 50, TileId::Floor, false, MachineKind::Assembler, true},
    {ItemId::Lab, "lab", "Lab", 50, TileId::Floor, false, MachineKind::Lab, true},
    {ItemId::FastBelt, "fast_belt", "Fast Belt", 100, TileId::Floor, false, MachineKind::FastBelt, true},
    {ItemId::Generator, "generator", "Generator", 50, TileId::Floor, false, MachineKind::Generator, true},
    {ItemId::PowerPole, "power_pole", "Power Pole", 100, TileId::Floor, false, MachineKind::PowerPole, true},
    {ItemId::ElectricMiner, "electric_miner", "Electric Miner", 50, TileId::Floor, false, MachineKind::ElectricMiner, true},
};

const std::vector<MachineDef> kMachines = {
    {MachineKind::Belt, "belt", "Belt", 1, 1, false, true, false, 1, MachineBehaviorKind::TransportBelt},
    {MachineKind::FastBelt, "fast_belt", "Fast Belt", 1, 1, false, true, false, 1, MachineBehaviorKind::TransportBelt},
    {MachineKind::Inserter, "inserter", "Inserter", 1, 1, false, true, false, 0, MachineBehaviorKind::Inserter},
    {MachineKind::BurnerMiner, "burner_miner", "Burner Miner", 1, 1, false, false, true, 1, MachineBehaviorKind::BurnerMiner},
    {MachineKind::Furnace, "furnace", "Furnace", 1, 1, false, true, false, 2, MachineBehaviorKind::Furnace},
    {MachineKind::Chest, "chest", "Chest", 1, 1, false, true, false, 16, MachineBehaviorKind::Storage},
    {MachineKind::Workbench, "workbench", "Workbench", 1, 1, false, true, false, 0, MachineBehaviorKind::CraftingStation},
    {MachineKind::Assembler, "assembler", "Assembler", 1, 1, false, true, false, 3, MachineBehaviorKind::Assembler},
    {MachineKind::Lab, "lab", "Lab", 1, 1, false, true, false, 1, MachineBehaviorKind::Lab},
    {MachineKind::Generator, "generator", "Generator", 1, 1, false, true, false, 1, MachineBehaviorKind::Generator},
    {MachineKind::PowerPole, "power_pole", "Power Pole", 1, 1, false, true, false, 0, MachineBehaviorKind::PowerPole},
    {MachineKind::ElectricMiner, "electric_miner", "Electric Miner", 1, 1, false, false, true, 0, MachineBehaviorKind::ElectricMiner},
};

const std::vector<RecipeDef> kRecipes = {
    {"furnace", {ItemStack{ItemId::Stone, 8}}, ItemStack{ItemId::Furnace, 1}, 30, "hand", true},
    {"chest", {ItemStack{ItemId::Wood, 8}}, ItemStack{ItemId::Chest, 1}, 20, "hand", true},
    {"belt", {ItemStack{ItemId::Stone, 1}}, ItemStack{ItemId::Belt, 2}, 15, "hand", true},
    {"inserter", {ItemStack{ItemId::Stone, 1}, ItemStack{ItemId::Wood, 1}}, ItemStack{ItemId::Inserter, 1}, 20, "hand", true},
    {"burner_miner", {ItemStack{ItemId::Stone, 4}, ItemStack{ItemId::Wood, 2}}, ItemStack{ItemId::BurnerMiner, 1}, 45, "hand", true},
    {"assembler", {ItemStack{ItemId::Stone, 4}, ItemStack{ItemId::Wood, 2}, ItemStack{ItemId::IronPlate, 2}}, ItemStack{ItemId::Assembler, 1}, 60, "hand", true},
    {"lab", {ItemStack{ItemId::Stone, 4}, ItemStack{ItemId::Wood, 4}, ItemStack{ItemId::IronPlate, 2}}, ItemStack{ItemId::Lab, 1}, 60, "hand", true},
    {"iron_plate", {ItemStack{ItemId::IronOre, 1}, ItemStack{ItemId::Coal, 1}}, ItemStack{ItemId::IronPlate, 1}, 60, "furnace", true},
    {"copper_plate", {ItemStack{ItemId::CopperOre, 1}, ItemStack{ItemId::Coal, 1}}, ItemStack{ItemId::CopperPlate, 1}, 60, "furnace", true},
    {"science_pack", {ItemStack{ItemId::IronPlate, 1}, ItemStack{ItemId::CopperPlate, 1}}, ItemStack{ItemId::SciencePack, 1}, 45, "assembler", true},
    {"fast_belt", {ItemStack{ItemId::Belt, 1}, ItemStack{ItemId::IronPlate, 1}}, ItemStack{ItemId::FastBelt, 1}, 30, "hand", false},
    {"generator", {ItemStack{ItemId::Stone, 4}, ItemStack{ItemId::IronPlate, 2}, ItemStack{ItemId::CopperPlate, 1}}, ItemStack{ItemId::Generator, 1}, 45, "hand", false},
    {"power_pole", {ItemStack{ItemId::Wood, 2}, ItemStack{ItemId::CopperPlate, 1}}, ItemStack{ItemId::PowerPole, 2}, 25, "hand", false},
    {"electric_miner", {ItemStack{ItemId::Stone, 4}, ItemStack{ItemId::IronPlate, 3}, ItemStack{ItemId::CopperPlate, 1}}, ItemStack{ItemId::ElectricMiner, 1}, 60, "hand", false},
};

const std::vector<TechDef> kTechs = {
    {"logistics_1", "Logistics 1", {ItemStack{ItemId::SciencePack, 3}}, 20, {"fast_belt", "generator", "power_pole", "electric_miner"}},
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

template <typename TId>
std::string enumKey(TId id)
{
    return std::to_string(static_cast<int>(id));
}

template <typename TId>
bool addUnique(std::unordered_set<int>& seen, TId id)
{
    return seen.insert(static_cast<int>(id)).second;
}

bool isKnownStation(std::string_view station)
{
    return station == "hand" || station == "furnace" || station == "assembler";
}

bool hasRecipeUnlock(std::string_view recipeKey)
{
    return std::any_of(kTechs.begin(), kTechs.end(), [recipeKey](const TechDef& tech) {
        return std::any_of(tech.unlockRecipes.begin(), tech.unlockRecipes.end(), [recipeKey](std::string_view unlock) {
            return unlock == recipeKey;
        });
    });
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

const std::vector<MachineDef>& machineDefs()
{
    return kMachines;
}

const std::vector<RecipeDef>& recipeDefs()
{
    return kRecipes;
}

const std::vector<TechDef>& techDefs()
{
    return kTechs;
}

const TileDef& tileDef(TileId id)
{
    return findById(kTiles, id);
}

const ItemDef& itemDef(ItemId id)
{
    return findById(kItems, id);
}

const MachineDef& machineDef(MachineKind id)
{
    return findById(kMachines, id);
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

const TechDef* techDef(std::string_view key)
{
    for (const auto& tech : kTechs) {
        if (tech.key == key) {
            return &tech;
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
    return machineDef(kind).key;
}

std::string_view toString(MachineBehaviorKind behavior)
{
    switch (behavior) {
    case MachineBehaviorKind::TransportBelt:
        return "transport_belt";
    case MachineBehaviorKind::Inserter:
        return "inserter";
    case MachineBehaviorKind::BurnerMiner:
        return "burner_miner";
    case MachineBehaviorKind::Furnace:
        return "furnace";
    case MachineBehaviorKind::Storage:
        return "storage";
    case MachineBehaviorKind::CraftingStation:
        return "crafting_station";
    case MachineBehaviorKind::Assembler:
        return "assembler";
    case MachineBehaviorKind::Lab:
        return "lab";
    case MachineBehaviorKind::Generator:
        return "generator";
    case MachineBehaviorKind::PowerPole:
        return "power_pole";
    case MachineBehaviorKind::ElectricMiner:
        return "electric_miner";
    }
    return "unknown";
}

std::optional<MachineKind> machineKindFromKey(std::string_view key)
{
    for (const auto& def : kMachines) {
        if (def.key == key) {
            return def.id;
        }
    }
    return std::nullopt;
}

std::vector<std::string> validateRegistries()
{
    std::vector<std::string> errors;

    const auto addError = [&errors](std::string message) {
        errors.push_back(std::move(message));
    };

    std::unordered_set<int> tileIds;
    std::unordered_set<std::string> tileKeys;
    for (const auto& tile : kTiles) {
        if (!addUnique(tileIds, tile.id)) {
            addError("duplicate tile id: " + enumKey(tile.id));
        }
        if (tile.key.empty()) {
            addError("tile has empty key");
        } else if (!tileKeys.insert(std::string(tile.key)).second) {
            addError("duplicate tile key: " + std::string(tile.key));
        }
        if (tile.displayName.empty()) {
            addError("tile " + std::string(tile.key) + " has empty display name");
        }
        if (tile.hardness < 0 && tile.drop != ItemId::None) {
            addError("tile " + std::string(tile.key) + " is unmineable but has a drop");
        }
        if (tileIdFromKey(tile.key) != tile.id) {
            addError("tile " + std::string(tile.key) + " fails key round trip");
        }
    }

    std::unordered_set<int> itemIds;
    std::unordered_set<std::string> itemKeys;
    for (const auto& item : kItems) {
        if (!addUnique(itemIds, item.id)) {
            addError("duplicate item id: " + enumKey(item.id));
        }
        if (item.key.empty()) {
            addError("item has empty key");
        } else if (!itemKeys.insert(std::string(item.key)).second) {
            addError("duplicate item key: " + std::string(item.key));
        }
        if (item.displayName.empty()) {
            addError("item " + std::string(item.key) + " has empty display name");
        }
        if (item.id == ItemId::None) {
            if (item.stackSize != 0) {
                addError("item none must have zero stack size");
            }
        } else if (item.stackSize <= 0) {
            addError("item " + std::string(item.key) + " must have positive stack size");
        }
        if (item.canPlaceTile && !tileIdFromKey(toString(item.placeTile)).has_value()) {
            addError("item " + std::string(item.key) + " references unknown place tile");
        }
        if (item.canPlaceMachine) {
            if (item.id == ItemId::None) {
                addError("item none cannot place a machine");
            }
            if (machineKindFromKey(toString(item.placeMachine)) != item.placeMachine) {
                addError("item " + std::string(item.key) + " references unknown place machine");
            }
        }
        if (itemIdFromKey(item.key) != item.id) {
            addError("item " + std::string(item.key) + " fails key round trip");
        }
    }

    std::unordered_set<int> machineIds;
    std::unordered_set<std::string> machineKeys;
    for (const auto& machine : kMachines) {
        if (!addUnique(machineIds, machine.id)) {
            addError("duplicate machine id: " + enumKey(machine.id));
        }
        if (machine.key.empty()) {
            addError("machine has empty key");
        } else if (!machineKeys.insert(std::string(machine.key)).second) {
            addError("duplicate machine key: " + std::string(machine.key));
        }
        if (machine.displayName.empty()) {
            addError("machine " + std::string(machine.key) + " has empty display name");
        }
        if (machine.width <= 0 || machine.height <= 0) {
            addError("machine " + std::string(machine.key) + " must have positive size");
        }
        if (machine.inventorySlots < 0) {
            addError("machine " + std::string(machine.key) + " has negative inventory slots");
        }
        if (machine.requiresBuildableTile && machine.requiresResourceTile) {
            addError("machine " + std::string(machine.key) + " cannot require both buildable and resource tiles");
        }
        if (!machine.requiresBuildableTile && !machine.requiresResourceTile) {
            addError("machine " + std::string(machine.key) + " must declare a placement surface rule");
        }
        if (toString(machine.behavior).empty() || toString(machine.behavior) == "unknown") {
            addError("machine " + std::string(machine.key) + " has unknown behavior kind");
        }
        if (machineKindFromKey(machine.key) != machine.id) {
            addError("machine " + std::string(machine.key) + " fails key round trip");
        }
        if (&machineDef(machine.id) != &machine) {
            addError("machine " + std::string(machine.key) + " fails id round trip");
        }
    }

    for (const auto& machine : kMachines) {
        const auto hasPlaceableItem = std::any_of(kItems.begin(), kItems.end(), [&machine](const ItemDef& item) {
            return item.canPlaceMachine && item.placeMachine == machine.id;
        });
        if (!hasPlaceableItem) {
            addError("machine " + std::string(machine.key) + " has no placeable item");
        }
    }

    std::unordered_set<std::string> recipeKeys;
    for (const auto& recipe : kRecipes) {
        if (recipe.key.empty()) {
            addError("recipe has empty key");
        } else if (!recipeKeys.insert(std::string(recipe.key)).second) {
            addError("duplicate recipe key: " + std::string(recipe.key));
        }
        if (recipe.inputs.empty()) {
            addError("recipe " + std::string(recipe.key) + " has no inputs");
        }
        for (const auto& input : recipe.inputs) {
            if (input.item == ItemId::None || input.count <= 0) {
                addError("recipe " + std::string(recipe.key) + " has invalid input stack");
            }
            if (!itemIdFromKey(toString(input.item)).has_value()) {
                addError("recipe " + std::string(recipe.key) + " references unknown input item");
            }
        }
        if (recipe.output.item == ItemId::None || recipe.output.count <= 0) {
            addError("recipe " + std::string(recipe.key) + " has invalid output stack");
        }
        if (recipe.ticks <= 0) {
            addError("recipe " + std::string(recipe.key) + " must have positive ticks");
        }
        if (!isKnownStation(recipe.station)) {
            addError("recipe " + std::string(recipe.key) + " has unknown station " + std::string(recipe.station));
        }
        if (!recipe.unlockedByDefault && !hasRecipeUnlock(recipe.key)) {
            addError("locked recipe " + std::string(recipe.key) + " is not unlocked by any tech");
        }
        if (recipeDef(recipe.key) != &recipe) {
            addError("recipe " + std::string(recipe.key) + " fails key round trip");
        }
    }

    std::unordered_set<std::string> techKeys;
    for (const auto& tech : kTechs) {
        if (tech.key.empty()) {
            addError("tech has empty key");
        } else if (!techKeys.insert(std::string(tech.key)).second) {
            addError("duplicate tech key: " + std::string(tech.key));
        }
        if (tech.displayName.empty()) {
            addError("tech " + std::string(tech.key) + " has empty display name");
        }
        if (tech.inputs.empty()) {
            addError("tech " + std::string(tech.key) + " has no inputs");
        }
        if (tech.ticks <= 0) {
            addError("tech " + std::string(tech.key) + " must have positive ticks");
        }
        for (const auto& input : tech.inputs) {
            if (input.item == ItemId::None || input.count <= 0) {
                addError("tech " + std::string(tech.key) + " has invalid input stack");
            }
        }

        std::unordered_set<std::string> unlocks;
        for (const auto unlock : tech.unlockRecipes) {
            if (recipeDef(unlock) == nullptr) {
                addError("tech " + std::string(tech.key) + " unlocks unknown recipe " + std::string(unlock));
            }
            if (!unlocks.insert(std::string(unlock)).second) {
                addError("tech " + std::string(tech.key) + " repeats unlock " + std::string(unlock));
            }
        }
        if (techDef(tech.key) != &tech) {
            addError("tech " + std::string(tech.key) + " fails key round trip");
        }
    }

    return errors;
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
