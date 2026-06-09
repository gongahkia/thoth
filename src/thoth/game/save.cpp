#include "thoth/game/save.hpp"

#include <fstream>
#include <sstream>
#include <utility>

namespace thoth::game {
namespace {

std::string_view directionToString(Direction direction)
{
    switch (direction) {
    case Direction::North:
        return "north";
    case Direction::East:
        return "east";
    case Direction::South:
        return "south";
    case Direction::West:
        return "west";
    }
    return "south";
}

std::optional<Direction> directionFromKey(std::string_view key)
{
    if (key == "north") {
        return Direction::North;
    }
    if (key == "east") {
        return Direction::East;
    }
    if (key == "south") {
        return Direction::South;
    }
    if (key == "west") {
        return Direction::West;
    }
    return std::nullopt;
}

void setError(std::string* error, const std::string& message)
{
    if (error != nullptr) {
        *error = message;
    }
}

template <typename T>
bool readValue(std::istream& input, T& value, const std::string& label, std::string* error)
{
    if (!(input >> value)) {
        setError(error, "failed to read " + label);
        return false;
    }
    return true;
}

bool expectToken(std::istream& input, const std::string& expected, std::string* error)
{
    std::string token;
    if (!(input >> token) || token != expected) {
        setError(error, "expected token '" + expected + "'");
        return false;
    }
    return true;
}

} // namespace

bool saveSimulation(const Simulation& simulation, const std::filesystem::path& path, std::string* error)
{
    std::ofstream output(path);
    if (!output) {
        setError(error, "failed to open save file for writing");
        return false;
    }

    const auto snapshot = simulation.snapshot();
    output << "THOTH_SAVE 6\n";
    output << "seed " << snapshot.seed << "\n";
    output << "tick " << snapshot.tick << "\n";
    output << "player " << snapshot.player.x << ' ' << snapshot.player.y << ' '
           << directionToString(snapshot.player.facing) << ' ' << snapshot.player.selectedHotbar << "\n";

    output << "hotbar";
    for (const auto item : snapshot.player.hotbar) {
        output << ' ' << toString(item);
    }
    output << "\n";

    output << "inventory " << snapshot.player.inventory.size() << "\n";
    for (const auto& stack : snapshot.player.inventory) {
        output << "item " << toString(stack.item) << ' ' << stack.count << "\n";
    }

    output << "tiles " << snapshot.tiles.size() << "\n";
    for (const auto& tile : snapshot.tiles) {
        output << "tile " << tile.x << ' ' << tile.y << ' ' << toString(tile.tile.id) << ' '
               << tile.tile.data << "\n";
    }

    output << "next_machine " << snapshot.nextMachineId << "\n";
    output << "machines " << snapshot.machines.size() << "\n";
    for (const auto& machine : snapshot.machines) {
        output << "machine " << machine.id << ' ' << toString(machine.kind) << ' ' << machine.x
               << ' ' << machine.y << ' ' << directionToString(machine.direction) << ' '
               << machine.progress << ' ' << toString(machine.carriedItem) << ' '
               << machine.fuelTicks << ' ' << toString(machine.outputItem) << ' '
               << (machine.recipeKey.empty() ? "none" : machine.recipeKey) << ' '
               << (machine.recipeLocked ? 1 : 0) << "\n";
        const auto inventory = machine.inventory.stacks();
        output << "machine_inventory " << inventory.size() << "\n";
        for (const auto& stack : inventory) {
            output << "machine_item " << toString(stack.item) << ' ' << stack.count << "\n";
        }
    }

    output << "research " << (snapshot.activeTech.empty() ? "none" : snapshot.activeTech) << ' '
           << snapshot.researchProgress << ' ' << snapshot.completedTechs.size() << ' '
           << snapshot.unlockedRecipes.size() << "\n";
    for (const auto& key : snapshot.completedTechs) {
        output << "completed_tech " << key << "\n";
    }
    for (const auto& key : snapshot.unlockedRecipes) {
        output << "unlocked_recipe " << key << "\n";
    }

    return true;
}

std::optional<SimulationSnapshot> loadSimulationSnapshot(const std::filesystem::path& path, std::string* error)
{
    std::ifstream input(path);
    if (!input) {
        setError(error, "failed to open save file for reading");
        return std::nullopt;
    }

    if (!expectToken(input, "THOTH_SAVE", error)) {
        return std::nullopt;
    }

    int version = 0;
    if (!readValue(input, version, "save version", error) || (version < 1 || version > 6)) {
        setError(error, "unsupported save version");
        return std::nullopt;
    }

    SimulationSnapshot snapshot;
    if (!expectToken(input, "seed", error) || !readValue(input, snapshot.seed, "seed", error)) {
        return std::nullopt;
    }
    if (!expectToken(input, "tick", error) || !readValue(input, snapshot.tick, "tick", error)) {
        return std::nullopt;
    }

    if (!expectToken(input, "player", error) ||
        !readValue(input, snapshot.player.x, "player x", error) ||
        !readValue(input, snapshot.player.y, "player y", error)) {
        return std::nullopt;
    }
    std::string facing;
    if (!readValue(input, facing, "player facing", error)) {
        return std::nullopt;
    }
    const auto parsedDirection = directionFromKey(facing);
    if (!parsedDirection) {
        setError(error, "invalid player facing");
        return std::nullopt;
    }
    snapshot.player.facing = *parsedDirection;
    if (!readValue(input, snapshot.player.selectedHotbar, "selected hotbar", error)) {
        return std::nullopt;
    }

    if (!expectToken(input, "hotbar", error)) {
        return std::nullopt;
    }
    for (auto& item : snapshot.player.hotbar) {
        std::string key;
        if (!readValue(input, key, "hotbar item", error)) {
            return std::nullopt;
        }
        const auto parsedItem = itemIdFromKey(key);
        if (!parsedItem) {
            setError(error, "invalid hotbar item");
            return std::nullopt;
        }
        item = *parsedItem;
    }

    std::size_t inventoryCount = 0;
    if (!expectToken(input, "inventory", error) ||
        !readValue(input, inventoryCount, "inventory count", error)) {
        return std::nullopt;
    }
    snapshot.player.inventory.clear();
    for (std::size_t i = 0; i < inventoryCount; ++i) {
        std::string key;
        int count = 0;
        if (!expectToken(input, "item", error) || !readValue(input, key, "item key", error) ||
            !readValue(input, count, "item count", error)) {
            return std::nullopt;
        }
        const auto parsedItem = itemIdFromKey(key);
        if (!parsedItem) {
            setError(error, "invalid inventory item");
            return std::nullopt;
        }
        snapshot.player.inventory.push_back(ItemStack{*parsedItem, count});
    }

    std::size_t tileCount = 0;
    if (!expectToken(input, "tiles", error) || !readValue(input, tileCount, "tile count", error)) {
        return std::nullopt;
    }
    snapshot.tiles.clear();
    for (std::size_t i = 0; i < tileCount; ++i) {
        TileSnapshot tile;
        std::string key;
        if (!expectToken(input, "tile", error) || !readValue(input, tile.x, "tile x", error) ||
            !readValue(input, tile.y, "tile y", error) ||
            !readValue(input, key, "tile key", error) ||
            !readValue(input, tile.tile.data, "tile data", error)) {
            return std::nullopt;
        }
        const auto parsedTile = tileIdFromKey(key);
        if (!parsedTile) {
            setError(error, "invalid tile id");
            return std::nullopt;
        }
        tile.tile.id = *parsedTile;
        snapshot.tiles.push_back(tile);
    }

    std::string token;
    if (!(input >> token)) {
        if (version >= 4) {
            setError(error, "expected token 'next_machine' or 'machines'");
            return std::nullopt;
        }
        return snapshot;
    }

    if (token == "next_machine") {
        if (!readValue(input, snapshot.nextMachineId, "next machine id", error)) {
            return std::nullopt;
        }
        if (!expectToken(input, "machines", error)) {
            return std::nullopt;
        }
    } else if (token != "machines") {
        setError(error, "expected token 'next_machine' or 'machines'");
        return std::nullopt;
    }

    std::size_t machineCount = 0;
    if (!readValue(input, machineCount, "machine count", error)) {
        return std::nullopt;
    }
    snapshot.machines.clear();
    for (std::size_t i = 0; i < machineCount; ++i) {
        Machine machine;
        std::string kindKey;
        std::string directionKey;
        std::string carriedKey;
        if (!expectToken(input, "machine", error) ||
            !readValue(input, machine.id, "machine id", error) ||
            !readValue(input, kindKey, "machine kind", error) ||
            !readValue(input, machine.x, "machine x", error) ||
            !readValue(input, machine.y, "machine y", error) ||
            !readValue(input, directionKey, "machine direction", error) ||
            !readValue(input, machine.progress, "machine progress", error) ||
            !readValue(input, carriedKey, "machine carried item", error)) {
            return std::nullopt;
        }
        if (version >= 2 && !readValue(input, machine.fuelTicks, "machine fuel ticks", error)) {
            return std::nullopt;
        }
        std::string outputKey = "none";
        if (version >= 3 && !readValue(input, outputKey, "machine output item", error)) {
            return std::nullopt;
        }
        std::string machineRecipe = "none";
        if (version >= 5 && !readValue(input, machineRecipe, "machine recipe", error)) {
            return std::nullopt;
        }
        int recipeLocked = 0;
        if (version >= 6 && !readValue(input, recipeLocked, "machine recipe locked", error)) {
            return std::nullopt;
        }

        const auto parsedKind = machineKindFromKey(kindKey);
        const auto parsedDirection = directionFromKey(directionKey);
        const auto parsedCarried = itemIdFromKey(carriedKey);
        const auto parsedOutput = itemIdFromKey(outputKey);
        if (!parsedKind || !parsedDirection || !parsedCarried || !parsedOutput) {
            setError(error, "invalid machine field");
            return std::nullopt;
        }
        machine.kind = *parsedKind;
        machine.direction = *parsedDirection;
        machine.carriedItem = *parsedCarried;
        machine.outputItem = *parsedOutput;
        if (machineRecipe != "none") {
            const auto* recipe = recipeDef(machineRecipe);
            const bool validAssemblerRecipe = machine.kind == MachineKind::Assembler &&
                recipe != nullptr && recipe->station == "assembler";
            const bool validFurnaceRecipe = machine.kind == MachineKind::Furnace &&
                recipe != nullptr && recipe->station == "furnace";
            if (!validAssemblerRecipe && !validFurnaceRecipe) {
                setError(error, "invalid machine recipe");
                return std::nullopt;
            }
            machine.recipeKey = machineRecipe;
        } else if (machine.kind == MachineKind::Assembler) {
            machine.recipeKey = "science_pack";
        }
        machine.recipeLocked = recipeLocked != 0 && machineRecipe != "none";

        std::size_t inventorySize = 0;
        if (!expectToken(input, "machine_inventory", error) ||
            !readValue(input, inventorySize, "machine inventory size", error)) {
            return std::nullopt;
        }
        for (std::size_t itemIndex = 0; itemIndex < inventorySize; ++itemIndex) {
            std::string itemKey;
            int count = 0;
            if (!expectToken(input, "machine_item", error) ||
                !readValue(input, itemKey, "machine item", error) ||
                !readValue(input, count, "machine item count", error)) {
                return std::nullopt;
            }
            const auto parsedItem = itemIdFromKey(itemKey);
            if (!parsedItem || !machine.inventory.add(*parsedItem, count)) {
                setError(error, "invalid machine inventory item");
                return std::nullopt;
            }
        }
        snapshot.machines.push_back(std::move(machine));
    }

    if (version >= 4) {
        std::string activeTech;
        int researchProgress = 0;
        std::size_t completedCount = 0;
        std::size_t unlockedCount = 0;
        if (!expectToken(input, "research", error) ||
            !readValue(input, activeTech, "active tech", error) ||
            !readValue(input, researchProgress, "research progress", error) ||
            !readValue(input, completedCount, "completed tech count", error) ||
            !readValue(input, unlockedCount, "unlocked recipe count", error)) {
            return std::nullopt;
        }
        if (activeTech == "none") {
            snapshot.activeTech.clear();
        } else if (techDef(activeTech) == nullptr) {
            setError(error, "invalid active tech");
            return std::nullopt;
        } else {
            snapshot.activeTech = activeTech;
        }
        snapshot.researchProgress = researchProgress;

        snapshot.completedTechs.clear();
        for (std::size_t i = 0; i < completedCount; ++i) {
            std::string key;
            if (!expectToken(input, "completed_tech", error) ||
                !readValue(input, key, "completed tech", error)) {
                return std::nullopt;
            }
            if (techDef(key) == nullptr) {
                setError(error, "invalid completed tech");
                return std::nullopt;
            }
            snapshot.completedTechs.push_back(std::move(key));
        }

        snapshot.unlockedRecipes.clear();
        for (std::size_t i = 0; i < unlockedCount; ++i) {
            std::string key;
            if (!expectToken(input, "unlocked_recipe", error) ||
                !readValue(input, key, "unlocked recipe", error)) {
                return std::nullopt;
            }
            if (recipeDef(key) == nullptr) {
                setError(error, "invalid unlocked recipe");
                return std::nullopt;
            }
            snapshot.unlockedRecipes.push_back(std::move(key));
        }
    }

    return snapshot;
}

std::optional<Simulation> loadSimulation(const std::filesystem::path& path, std::string* error)
{
    auto snapshot = loadSimulationSnapshot(path, error);
    if (!snapshot) {
        return std::nullopt;
    }
    return Simulation::fromSnapshot(*snapshot);
}

} // namespace thoth::game
