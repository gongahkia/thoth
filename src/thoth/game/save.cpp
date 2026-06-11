#include "thoth/game/save.hpp"

#include <algorithm>
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

std::string_view entityKindToString(EntityKind kind)
{
    switch (kind) {
    case EntityKind::Deer:
        return "deer";
    case EntityKind::Chicken:
        return "chicken";
    case EntityKind::Crab:
        return "crab";
    case EntityKind::Fish:
        return "fish";
    case EntityKind::Slime:
        return "slime";
    case EntityKind::Skeleton:
        return "skeleton";
    case EntityKind::CaveCrawler:
        return "cave_crawler";
    case EntityKind::DungeonSentinel:
        return "dungeon_sentinel";
    case EntityKind::MarshBroodheart:
        return "marsh_broodheart";
    }
    return "deer";
}

std::optional<EntityKind> entityKindFromKey(std::string_view key)
{
    if (key == "deer") {
        return EntityKind::Deer;
    }
    if (key == "chicken") {
        return EntityKind::Chicken;
    }
    if (key == "crab") {
        return EntityKind::Crab;
    }
    if (key == "fish") {
        return EntityKind::Fish;
    }
    if (key == "slime") {
        return EntityKind::Slime;
    }
    if (key == "skeleton") {
        return EntityKind::Skeleton;
    }
    if (key == "cave_crawler") {
        return EntityKind::CaveCrawler;
    }
    if (key == "dungeon_sentinel") {
        return EntityKind::DungeonSentinel;
    }
    if (key == "marsh_broodheart") {
        return EntityKind::MarshBroodheart;
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
    output << "THOTH_SAVE 10\n";
    output << "seed " << snapshot.seed << "\n";
    output << "tick " << snapshot.tick << "\n";
    output << "player " << snapshot.player.x << ' ' << snapshot.player.y << ' '
           << snapshot.player.z << ' ' << directionToString(snapshot.player.facing) << ' '
           << snapshot.player.selectedHotbar << ' ' << (snapshot.player.inBoat ? 1 : 0) << ' '
           << snapshot.player.hp << "\n";

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
        output << "tile " << tile.x << ' ' << tile.y << ' ' << tile.z << ' '
               << toString(tile.tile.id) << ' ' << tile.tile.data << "\n";
    }

    output << "next_machine " << snapshot.nextMachineId << "\n";
    output << "machines " << snapshot.machines.size() << "\n";
    for (const auto& machine : snapshot.machines) {
        output << "machine " << machine.id << ' ' << toString(machine.kind) << ' ' << machine.x
               << ' ' << machine.y << ' ' << machine.z << ' ' << directionToString(machine.direction) << ' '
               << machine.progress << ' ' << toString(machine.carriedItem) << ' '
               << machine.fuelTicks << ' ' << toString(machine.outputItem) << ' '
               << (machine.recipeKey.empty() ? "none" : machine.recipeKey) << ' '
               << (machine.recipeLocked ? 1 : 0) << ' '
               << toString(machine.filterItem) << ' '
               << toString(machine.circuitComparator) << ' '
               << machine.circuitThreshold << ' '
               << toString(machine.requestItem) << ' '
               << machine.requestThreshold << "\n";
        const auto inventory = machine.inventory.stacks();
        output << "machine_inventory " << inventory.size() << "\n";
        for (const auto& stack : inventory) {
            output << "machine_item " << toString(stack.item) << ' ' << stack.count << "\n";
        }
    }

    output << "next_entity " << snapshot.nextEntityId << "\n";
    output << "entities " << snapshot.entities.size() << "\n";
    for (const auto& entity : snapshot.entities) {
        output << "entity " << entity.id << ' ' << entityKindToString(entity.kind) << ' '
               << entity.x << ' ' << entity.y << ' ' << entity.z << ' '
               << entity.hp << ' ' << directionToString(entity.facing) << ' '
               << entity.cooldown << "\n";
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

    output << "logistic_jobs " << snapshot.logisticJobs.size() << "\n";
    for (const auto& job : snapshot.logisticJobs) {
        output << "logistic_job " << job.portId << ' ' << job.sourceId << ' '
               << job.targetId << ' ' << toString(job.item) << ' '
               << job.ticksRemaining << ' ' << job.totalTicks << "\n";
    }

    output << "production_totals "
           << snapshot.productionTotals.ironPlates << ' '
           << snapshot.productionTotals.copperPlates << ' '
           << snapshot.productionTotals.sciencePacks << ' '
           << snapshot.productionTotals.advancedSciencePacks << ' '
           << snapshot.productionTotals.logisticDeliveries << ' '
           << snapshot.productionTotals.poweredOre << ' '
           << snapshot.productionTotals.archiveSignals << ' '
           << snapshot.productionTotals.trainDeliveries << ' '
           << snapshot.productionTotals.waterBarrels << ' '
           << snapshot.productionTotals.riftJumps << ' '
           << snapshot.productionTotals.creaturesDefeated << ' '
           << snapshot.productionTotals.dungeonChestsOpened << ' '
           << snapshot.productionTotals.bossesDefeated << "\n";

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
    if (!readValue(input, version, "save version", error) || (version < 1 || version > 10)) {
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
    if (version >= 9 && !readValue(input, snapshot.player.z, "player z", error)) {
        return std::nullopt;
    }
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
    if (version >= 9) {
        int inBoat = 0;
        if (!readValue(input, inBoat, "player boat state", error) ||
            !readValue(input, snapshot.player.hp, "player hp", error)) {
            return std::nullopt;
        }
        snapshot.player.inBoat = inBoat != 0;
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
            !readValue(input, tile.y, "tile y", error)) {
            return std::nullopt;
        }
        if (version >= 9 && !readValue(input, tile.z, "tile z", error)) {
            return std::nullopt;
        }
        if (!readValue(input, key, "tile key", error) ||
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
            !readValue(input, machine.y, "machine y", error)) {
            return std::nullopt;
        }
        if (version >= 9 && !readValue(input, machine.z, "machine z", error)) {
            return std::nullopt;
        }
        if (
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
        std::string filterKey = "none";
        std::string comparatorKey = "always";
        std::string requestKey = "none";
        if (version >= 7 &&
            (!readValue(input, filterKey, "machine filter item", error) ||
                !readValue(input, comparatorKey, "machine circuit comparator", error) ||
                !readValue(input, machine.circuitThreshold, "machine circuit threshold", error) ||
                !readValue(input, requestKey, "machine request item", error) ||
                !readValue(input, machine.requestThreshold, "machine request threshold", error))) {
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
        const auto parsedFilter = itemIdFromKey(filterKey);
        const auto parsedRequest = itemIdFromKey(requestKey);
        if (!parsedFilter || !parsedRequest) {
            setError(error, "invalid machine config item");
            return std::nullopt;
        }
        machine.filterItem = *parsedFilter;
        machine.circuitComparator = circuitComparatorFromKey(comparatorKey);
        machine.circuitThreshold = std::max(0, machine.circuitThreshold);
        machine.requestItem = *parsedRequest;
        machine.requestThreshold = std::max(0, machine.requestThreshold);
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

    if (version >= 9) {
        if (!expectToken(input, "next_entity", error) ||
            !readValue(input, snapshot.nextEntityId, "next entity id", error) ||
            !expectToken(input, "entities", error)) {
            return std::nullopt;
        }
        std::size_t entityCount = 0;
        if (!readValue(input, entityCount, "entity count", error)) {
            return std::nullopt;
        }
        snapshot.entities.clear();
        for (std::size_t i = 0; i < entityCount; ++i) {
            Entity entity;
            std::string kindKey;
            std::string facingKey;
            if (!expectToken(input, "entity", error) ||
                !readValue(input, entity.id, "entity id", error) ||
                !readValue(input, kindKey, "entity kind", error) ||
                !readValue(input, entity.x, "entity x", error) ||
                !readValue(input, entity.y, "entity y", error) ||
                !readValue(input, entity.z, "entity z", error) ||
                !readValue(input, entity.hp, "entity hp", error) ||
                !readValue(input, facingKey, "entity facing", error) ||
                !readValue(input, entity.cooldown, "entity cooldown", error)) {
                return std::nullopt;
            }
            const auto parsedKind = entityKindFromKey(kindKey);
            const auto parsedDirection = directionFromKey(facingKey);
            if (!parsedKind || !parsedDirection || entity.id == 0 || entity.hp <= 0) {
                setError(error, "invalid entity");
                return std::nullopt;
            }
            entity.kind = *parsedKind;
            entity.facing = *parsedDirection;
            entity.cooldown = std::max(0, entity.cooldown);
            snapshot.entities.push_back(entity);
        }
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

    if (version >= 7) {
        std::string token;
        if (!(input >> token)) {
            return snapshot;
        }
        if (token != "logistic_jobs") {
            setError(error, "expected token 'logistic_jobs'");
            return std::nullopt;
        }

        std::size_t jobCount = 0;
        if (!readValue(input, jobCount, "logistic job count", error)) {
            return std::nullopt;
        }
        snapshot.logisticJobs.clear();
        for (std::size_t i = 0; i < jobCount; ++i) {
            LogisticJob job;
            std::string itemKey;
            if (!expectToken(input, "logistic_job", error) ||
                !readValue(input, job.portId, "logistic job port", error) ||
                !readValue(input, job.sourceId, "logistic job source", error) ||
                !readValue(input, job.targetId, "logistic job target", error) ||
                !readValue(input, itemKey, "logistic job item", error) ||
                !readValue(input, job.ticksRemaining, "logistic job ticks remaining", error) ||
                !readValue(input, job.totalTicks, "logistic job total ticks", error)) {
                return std::nullopt;
            }
            const auto parsedItem = itemIdFromKey(itemKey);
            if (!parsedItem || *parsedItem == ItemId::None || job.ticksRemaining < 0 || job.totalTicks <= 0) {
                setError(error, "invalid logistic job");
                return std::nullopt;
            }
            job.item = *parsedItem;
            snapshot.logisticJobs.push_back(job);
        }

        if (!expectToken(input, "production_totals", error) ||
            !readValue(input, snapshot.productionTotals.ironPlates, "iron plate total", error) ||
            !readValue(input, snapshot.productionTotals.copperPlates, "copper plate total", error) ||
            !readValue(input, snapshot.productionTotals.sciencePacks, "science pack total", error) ||
            !readValue(input, snapshot.productionTotals.advancedSciencePacks, "advanced science pack total", error) ||
            !readValue(input, snapshot.productionTotals.logisticDeliveries, "logistic delivery total", error) ||
            !readValue(input, snapshot.productionTotals.poweredOre, "powered ore total", error)) {
            return std::nullopt;
        }
        if (version >= 8 &&
            (!readValue(input, snapshot.productionTotals.archiveSignals, "archive signal total", error) ||
                !readValue(input, snapshot.productionTotals.trainDeliveries, "train delivery total", error) ||
                !readValue(input, snapshot.productionTotals.waterBarrels, "water barrel total", error) ||
                !readValue(input, snapshot.productionTotals.riftJumps, "rift jump total", error))) {
            return std::nullopt;
        }
        if (version >= 9 &&
            (!readValue(input, snapshot.productionTotals.creaturesDefeated, "creature defeated total", error) ||
                !readValue(input, snapshot.productionTotals.dungeonChestsOpened, "dungeon chest total", error))) {
            return std::nullopt;
        }
        if (version >= 10 &&
            !readValue(input, snapshot.productionTotals.bossesDefeated, "boss defeated total", error)) {
            return std::nullopt;
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
