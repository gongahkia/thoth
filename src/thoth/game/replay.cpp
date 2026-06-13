#include "thoth/game/replay.hpp"

#include <algorithm>
#include <cstddef>
#include <fstream>
#include <sstream>
#include <string>
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

std::string commandTypeKey(CommandType type)
{
    switch (type) {
    case CommandType::Face:
        return "face";
    case CommandType::Move:
        return "move";
    case CommandType::Mine:
        return "mine";
    case CommandType::Place:
        return "place";
    case CommandType::PlaceGhost:
        return "place_ghost";
    case CommandType::CancelGhost:
        return "cancel_ghost";
    case CommandType::Craft:
        return "craft";
    case CommandType::SelectHotbar:
        return "select_hotbar";
    case CommandType::AssignHotbar:
        return "assign_hotbar";
    case CommandType::ConfigureMachineRecipe:
        return "configure_recipe";
    case CommandType::DepositSelected:
        return "deposit_selected";
    case CommandType::DepositItem:
        return "deposit";
    case CommandType::WithdrawItem:
        return "withdraw";
    case CommandType::ConfigureCircuit:
        return "configure_circuit";
    case CommandType::ConfigureRequest:
        return "configure_request";
    case CommandType::Interact:
        return "interact";
    case CommandType::Attack:
        return "attack";
    case CommandType::SelectArchiveChoice:
        return "select_archive_choice";
    case CommandType::TogglePlanningMode:
        return "toggle_planning";
    }
    return "move";
}

bool writeCommand(std::ostream& output, const ReplayFrame& frame, std::string* error)
{
    output << "frame " << frame.tick << ' ' << commandTypeKey(frame.command.type);
    switch (frame.command.type) {
    case CommandType::Face:
    case CommandType::Move:
    case CommandType::Mine:
    case CommandType::DepositSelected:
    case CommandType::Interact:
    case CommandType::Attack:
    case CommandType::CancelGhost:
        output << ' ' << directionToString(frame.command.direction);
        break;
    case CommandType::Place:
    case CommandType::PlaceGhost:
        output << ' ' << directionToString(frame.command.direction)
               << ' ' << directionToString(frame.command.orientation)
               << ' ' << toString(frame.command.item)
               << ' ' << toString(frame.command.tile);
        break;
    case CommandType::Craft:
        if (frame.command.recipeKey.empty()) {
            setError(error, "cannot write replay craft command with empty recipe");
            return false;
        }
        output << ' ' << frame.command.recipeKey;
        break;
    case CommandType::SelectHotbar:
        output << ' ' << frame.command.hotbarIndex;
        break;
    case CommandType::AssignHotbar:
        output << ' ' << frame.command.hotbarIndex
               << ' ' << toString(frame.command.item);
        break;
    case CommandType::ConfigureMachineRecipe:
        if (frame.command.recipeKey.empty()) {
            setError(error, "cannot write replay configure_recipe command with empty recipe");
            return false;
        }
        output << ' ' << directionToString(frame.command.direction)
               << ' ' << frame.command.recipeKey;
        break;
    case CommandType::DepositItem:
    case CommandType::WithdrawItem:
        output << ' ' << directionToString(frame.command.direction)
               << ' ' << toString(frame.command.item);
        break;
    case CommandType::ConfigureCircuit:
        output << ' ' << directionToString(frame.command.direction)
               << ' ' << toString(frame.command.item)
               << ' ' << toString(frame.command.comparator)
               << ' ' << frame.command.amount;
        break;
    case CommandType::ConfigureRequest:
        output << ' ' << directionToString(frame.command.direction)
               << ' ' << toString(frame.command.item)
               << ' ' << frame.command.amount;
        break;
    case CommandType::SelectArchiveChoice:
        output << ' ' << directionToString(frame.command.direction)
               << ' ' << frame.command.amount;
        break;
    case CommandType::TogglePlanningMode:
        break;
    }
    output << '\n';
    return true;
}

bool readDirection(std::istream& input, Direction& direction, const std::string& label, std::string* error)
{
    std::string key;
    if (!readValue(input, key, label, error)) {
        return false;
    }
    const auto parsed = directionFromKey(key);
    if (!parsed) {
        setError(error, "invalid " + label);
        return false;
    }
    direction = *parsed;
    return true;
}

bool readItem(std::istream& input, ItemId& item, const std::string& label, std::string* error)
{
    std::string key;
    if (!readValue(input, key, label, error)) {
        return false;
    }
    const auto parsed = itemIdFromKey(key);
    if (!parsed) {
        setError(error, "invalid " + label);
        return false;
    }
    item = *parsed;
    return true;
}

bool readTile(std::istream& input, TileId& tile, const std::string& label, std::string* error)
{
    std::string key;
    if (!readValue(input, key, label, error)) {
        return false;
    }
    const auto parsed = tileIdFromKey(key);
    if (!parsed) {
        setError(error, "invalid " + label);
        return false;
    }
    tile = *parsed;
    return true;
}

bool readCommand(std::istream& input, ReplayFrame& frame, std::string* error)
{
    std::string type;
    if (!expectToken(input, "frame", error) ||
        !readValue(input, frame.tick, "replay frame tick", error) ||
        !readValue(input, type, "replay command type", error)) {
        return false;
    }

    Command command;
    if (type == "face") {
        command.type = CommandType::Face;
        if (!readDirection(input, command.direction, "face direction", error)) {
            return false;
        }
    } else if (type == "move") {
        command.type = CommandType::Move;
        if (!readDirection(input, command.direction, "move direction", error)) {
            return false;
        }
    } else if (type == "mine") {
        command.type = CommandType::Mine;
        if (!readDirection(input, command.direction, "mine direction", error)) {
            return false;
        }
    } else if (type == "place") {
        command.type = CommandType::Place;
        if (!readDirection(input, command.direction, "place direction", error) ||
            !readDirection(input, command.orientation, "place orientation", error) ||
            !readItem(input, command.item, "place item", error) ||
            !readTile(input, command.tile, "place tile", error)) {
            return false;
        }
    } else if (type == "place_ghost") {
        command.type = CommandType::PlaceGhost;
        if (!readDirection(input, command.direction, "place ghost direction", error) ||
            !readDirection(input, command.orientation, "place ghost orientation", error) ||
            !readItem(input, command.item, "place ghost item", error) ||
            !readTile(input, command.tile, "place ghost tile", error)) {
            return false;
        }
    } else if (type == "cancel_ghost") {
        command.type = CommandType::CancelGhost;
        if (!readDirection(input, command.direction, "cancel ghost direction", error)) {
            return false;
        }
    } else if (type == "craft") {
        command.type = CommandType::Craft;
        if (!readValue(input, command.recipeKey, "craft recipe", error) ||
            recipeDef(command.recipeKey) == nullptr) {
            setError(error, "invalid craft recipe");
            return false;
        }
    } else if (type == "select_hotbar") {
        command.type = CommandType::SelectHotbar;
        if (!readValue(input, command.hotbarIndex, "hotbar index", error)) {
            return false;
        }
    } else if (type == "assign_hotbar") {
        command.type = CommandType::AssignHotbar;
        if (!readValue(input, command.hotbarIndex, "hotbar index", error) ||
            !readItem(input, command.item, "hotbar item", error)) {
            return false;
        }
    } else if (type == "configure_recipe") {
        command.type = CommandType::ConfigureMachineRecipe;
        if (!readDirection(input, command.direction, "configure recipe direction", error) ||
            !readValue(input, command.recipeKey, "configure recipe", error) ||
            recipeDef(command.recipeKey) == nullptr) {
            setError(error, "invalid configure recipe");
            return false;
        }
    } else if (type == "deposit_selected") {
        command.type = CommandType::DepositSelected;
        if (!readDirection(input, command.direction, "deposit selected direction", error)) {
            return false;
        }
    } else if (type == "deposit") {
        command.type = CommandType::DepositItem;
        if (!readDirection(input, command.direction, "deposit direction", error) ||
            !readItem(input, command.item, "deposit item", error)) {
            return false;
        }
    } else if (type == "withdraw") {
        command.type = CommandType::WithdrawItem;
        if (!readDirection(input, command.direction, "withdraw direction", error) ||
            !readItem(input, command.item, "withdraw item", error)) {
            return false;
        }
    } else if (type == "configure_circuit") {
        command.type = CommandType::ConfigureCircuit;
        std::string comparatorKey;
        if (!readDirection(input, command.direction, "configure circuit direction", error) ||
            !readItem(input, command.item, "configure circuit item", error) ||
            !readValue(input, comparatorKey, "configure circuit comparator", error) ||
            !readValue(input, command.amount, "configure circuit threshold", error)) {
            return false;
        }
        command.comparator = circuitComparatorFromKey(comparatorKey);
    } else if (type == "configure_request") {
        command.type = CommandType::ConfigureRequest;
        if (!readDirection(input, command.direction, "configure request direction", error) ||
            !readItem(input, command.item, "configure request item", error) ||
            !readValue(input, command.amount, "configure request threshold", error)) {
            return false;
        }
    } else if (type == "interact") {
        command.type = CommandType::Interact;
        if (!readDirection(input, command.direction, "interact direction", error)) {
            return false;
        }
    } else if (type == "attack") {
        command.type = CommandType::Attack;
        if (!readDirection(input, command.direction, "attack direction", error)) {
            return false;
        }
    } else if (type == "select_archive_choice") {
        command.type = CommandType::SelectArchiveChoice;
        if (!readDirection(input, command.direction, "select archive direction", error) ||
            !readValue(input, command.amount, "select archive choice", error)) {
            return false;
        }
    } else if (type == "toggle_planning") {
        command.type = CommandType::TogglePlanningMode;
    } else {
        setError(error, "unknown replay command type");
        return false;
    }

    frame.command = std::move(command);
    return true;
}

} // namespace

void applyReplay(Simulation& simulation, const Replay& replay, std::uint64_t finalTick)
{
    std::size_t nextFrame = 0;
    while (nextFrame < replay.size() && replay[nextFrame].tick < simulation.tick()) {
        ++nextFrame;
    }

    while (simulation.tick() < finalTick) {
        while (nextFrame < replay.size() && replay[nextFrame].tick == simulation.tick()) {
            simulation.queue(replay[nextFrame].command);
            ++nextFrame;
        }
        simulation.step();
    }
}

Simulation simulationFromReplayDocument(const ReplayDocument& document)
{
    Simulation simulation(document.seed);
    simulation.player().x = document.playerX;
    simulation.player().y = document.playerY;
    simulation.player().z = document.playerZ;
    simulation.player().facing = document.playerFacing;
    simulation.player().selectedHotbar = std::clamp(document.selectedHotbar, 0, kHotbarSlots - 1);
    simulation.player().hotbar.fill(ItemId::None);
    simulation.player().inventory.clear();

    for (const auto& stack : document.playerInventory) {
        const auto added = simulation.player().inventory.add(stack.item, stack.count);
        (void)added;
    }
    for (const auto& tile : document.tiles) {
        simulation.world().setTile(tile.x, tile.y, tile.z, tile.tile);
    }
    return simulation;
}

Simulation runReplayDocument(const ReplayDocument& document)
{
    auto simulation = simulationFromReplayDocument(document);
    applyReplay(simulation, document.replay, document.finalTick);
    return simulation;
}

bool saveReplayDocument(const ReplayDocument& document, const std::filesystem::path& path, std::string* error)
{
    std::ofstream output(path);
    if (!output) {
        setError(error, "failed to open replay file for writing");
        return false;
    }

    output << "THOTH_REPLAY 2\n";
    output << "seed " << document.seed << "\n";
    output << "final_tick " << document.finalTick << "\n";
    output << "player " << document.playerX << ' ' << document.playerY << ' '
           << document.playerZ << ' ' << directionToString(document.playerFacing) << ' '
           << document.selectedHotbar << "\n";

    output << "inventory " << document.playerInventory.size() << "\n";
    for (const auto& stack : document.playerInventory) {
        output << "item " << toString(stack.item) << ' ' << stack.count << "\n";
    }

    output << "tiles " << document.tiles.size() << "\n";
    for (const auto& tile : document.tiles) {
        output << "tile " << tile.x << ' ' << tile.y << ' ' << tile.z << ' '
               << toString(tile.tile.id) << ' ' << tile.tile.data << "\n";
    }

    output << "frames " << document.replay.size() << "\n";
    for (const auto& frame : document.replay) {
        if (!writeCommand(output, frame, error)) {
            return false;
        }
    }
    return true;
}

std::optional<ReplayDocument> loadReplayDocument(const std::filesystem::path& path, std::string* error)
{
    std::ifstream input(path);
    if (!input) {
        setError(error, "failed to open replay file for reading");
        return std::nullopt;
    }

    if (!expectToken(input, "THOTH_REPLAY", error)) {
        return std::nullopt;
    }
    int version = 0;
    if (!readValue(input, version, "replay version", error) || (version < 1 || version > 2)) {
        setError(error, "unsupported replay version");
        return std::nullopt;
    }

    ReplayDocument document;
    if (!expectToken(input, "seed", error) ||
        !readValue(input, document.seed, "replay seed", error) ||
        !expectToken(input, "final_tick", error) ||
        !readValue(input, document.finalTick, "replay final tick", error) ||
        !expectToken(input, "player", error) ||
        !readValue(input, document.playerX, "replay player x", error) ||
        !readValue(input, document.playerY, "replay player y", error)) {
        return std::nullopt;
    }
    if (version >= 2 && !readValue(input, document.playerZ, "replay player z", error)) {
        return std::nullopt;
    }
    if (
        !readDirection(input, document.playerFacing, "replay player facing", error) ||
        !readValue(input, document.selectedHotbar, "replay selected hotbar", error)) {
        return std::nullopt;
    }

    std::size_t inventoryCount = 0;
    if (!expectToken(input, "inventory", error) ||
        !readValue(input, inventoryCount, "replay inventory count", error)) {
        return std::nullopt;
    }
    for (std::size_t i = 0; i < inventoryCount; ++i) {
        ItemId item = ItemId::None;
        int count = 0;
        if (!expectToken(input, "item", error) ||
            !readItem(input, item, "replay inventory item", error) ||
            !readValue(input, count, "replay inventory item count", error) ||
            item == ItemId::None || count <= 0) {
            setError(error, "invalid replay inventory item");
            return std::nullopt;
        }
        document.playerInventory.push_back(ItemStack{item, count});
    }

    std::size_t tileCount = 0;
    if (!expectToken(input, "tiles", error) ||
        !readValue(input, tileCount, "replay tile count", error)) {
        return std::nullopt;
    }
    for (std::size_t i = 0; i < tileCount; ++i) {
        TileSnapshot tile;
        if (!expectToken(input, "tile", error) ||
            !readValue(input, tile.x, "replay tile x", error) ||
            !readValue(input, tile.y, "replay tile y", error)) {
            return std::nullopt;
        }
        if (version >= 2 && !readValue(input, tile.z, "replay tile z", error)) {
            return std::nullopt;
        }
        if (
            !readTile(input, tile.tile.id, "replay tile id", error) ||
            !readValue(input, tile.tile.data, "replay tile data", error)) {
            return std::nullopt;
        }
        document.tiles.push_back(tile);
    }

    std::size_t frameCount = 0;
    if (!expectToken(input, "frames", error) ||
        !readValue(input, frameCount, "replay frame count", error)) {
        return std::nullopt;
    }
    document.replay.reserve(frameCount);
    for (std::size_t i = 0; i < frameCount; ++i) {
        ReplayFrame frame;
        if (!readCommand(input, frame, error)) {
            return std::nullopt;
        }
        document.replay.push_back(std::move(frame));
    }

    std::stable_sort(document.replay.begin(), document.replay.end(), [](const ReplayFrame& left, const ReplayFrame& right) {
        return left.tick < right.tick;
    });
    return document;
}

} // namespace thoth::game
