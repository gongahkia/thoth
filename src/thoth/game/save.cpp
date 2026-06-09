#include "thoth/game/save.hpp"

#include <fstream>
#include <sstream>

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
    output << "THOTH_SAVE 1\n";
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
    if (!readValue(input, version, "save version", error) || version != 1) {
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
