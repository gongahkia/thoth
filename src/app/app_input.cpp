#include "app_internal.hpp"

#include "thoth/core/deterministic_random.hpp"
#include "thoth/game/save.hpp"

#include <algorithm>
#include <array>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <fstream>
#include <filesystem>
#include <iostream>
#include <optional>
#include <sstream>
#include <string>
#include <string_view>
#include <system_error>
#include <utility>
#include <vector>

namespace thoth::app {

void handleCraftMenuInput(thoth::game::Simulation& sim, AppState& state, const AudioBank& audio)
{
    if (IsKeyPressed(KEY_Q)) {
        state.craftMenuOpen = !state.craftMenuOpen;
        state.status = state.craftMenuOpen ? "build menu open" : "build menu hidden";
        playCue(audio, audio.tick);
    }

    if (!state.craftMenuOpen) {
        return;
    }

    clampCraftSelection(state);
    const int entryCount = static_cast<int>(craftMenuEntries().size());
    if (entryCount <= 0) {
        return;
    }

    if (IsKeyPressed(KEY_LEFT_BRACKET)) {
        state.craftSelection = (state.craftSelection + entryCount - 1) % entryCount;
        playCue(audio, audio.tick);
    }
    if (IsKeyPressed(KEY_RIGHT_BRACKET)) {
        state.craftSelection = (state.craftSelection + 1) % entryCount;
        playCue(audio, audio.tick);
    }
    if (IsKeyPressed(KEY_Z)) {
        queueSelectedCraft(sim, state, audio);
    }

    if (IsMouseButtonPressed(MOUSE_BUTTON_LEFT)) {
        const auto mouse = GetMousePosition();
        for (int i = 0; i < entryCount; ++i) {
            if (!CheckCollisionPointRec(mouse, craftCardRect(i))) {
                continue;
            }
            state.craftSelection = i;
            queueSelectedCraft(sim, state, audio);
            break;
        }
    }
}

std::string factoryStatsText(const thoth::game::Simulation& sim)
{
    using thoth::game::ItemId;
    using thoth::game::MachineKind;

    return "factory: miners=" + std::to_string(machineCount(sim, MachineKind::BurnerMiner)) +
        " furnaces=" + std::to_string(machineCount(sim, MachineKind::Furnace)) +
        " assemblers=" + std::to_string(machineCount(sim, MachineKind::Assembler)) +
        " labs=" + std::to_string(machineCount(sim, MachineKind::Lab)) +
        " generators=" + std::to_string(machineCount(sim, MachineKind::Generator)) +
        " poles=" + std::to_string(machineCount(sim, MachineKind::PowerPole)) +
        " electric_miners=" + std::to_string(machineCount(sim, MachineKind::ElectricMiner)) +
        " inserters=" + std::to_string(machineCount(sim, MachineKind::Inserter)) +
        " circuit_ins=" + std::to_string(machineCount(sim, MachineKind::CircuitInserter)) +
        " ports=" + std::to_string(machineCount(sim, MachineKind::LogisticPort)) +
        " splitters=" + std::to_string(machineCount(sim, MachineKind::Splitter)) +
        " trains=" + std::to_string(machineCount(sim, MachineKind::TrainStop)) +
        " pumps=" + std::to_string(machineCount(sim, MachineKind::OffshorePump)) +
        " archive=" + std::to_string(sim.productionTotals().archiveSignals) +
        " rift=" + std::to_string(sim.productionTotals().riftJumps) +
        " deliveries=" + std::to_string(sim.productionTotals().logisticDeliveries) +
        " pressure=" + std::to_string(sim.factoryPressureLevel()) +
        " chests=" + std::to_string(machineCount(sim, MachineKind::Chest)) +
        " belts_loaded=" + std::to_string(beltItemCount(sim)) +
        " plates_in_chests=" + std::to_string(itemCountInMachines(sim, MachineKind::Chest, ItemId::IronPlate)) +
        " copper_in_chests=" + std::to_string(itemCountInMachines(sim, MachineKind::Chest, ItemId::CopperPlate)) +
        " blocked=" + std::to_string(blockedMachineCount(sim));
}

std::string powerStatsText(const thoth::game::Simulation& sim)
{
    const auto& networks = sim.powerNetworks();
    if (networks.empty()) {
        return "power: no networks";
    }

    std::string text = "power:";
    for (const auto& network : networks) {
        text += " net";
        text += std::to_string(network.id);
        text += " ";
        text += std::to_string(network.supply);
        text += "/";
        text += std::to_string(network.demand);
        text += network.powered ? " ok" : " under";
    }
    return text;
}

std::string objectiveText(const thoth::game::Simulation& sim)
{
    using thoth::game::ItemId;
    using thoth::game::MachineKind;

    if (sim.mainObjectiveComplete()) {
        return "objective complete: archive, logistics, science, power, and rift chain stabilized";
    }
    if (sim.completedSupplyContracts() < sim.totalSupplyContracts()) {
        return "objective: fulfill the next supply contract";
    }
    if (sim.productionTotals().riftJumps > 0) {
        return "objective: exploit the rift dimension's richer resources";
    }
    if (sim.productionTotals().archiveSignals > 0) {
        return "objective: craft/place a rift gate, power it, and load a beacon core";
    }
    if (sim.isRecipeUnlocked("archive_terminal")) {
        return "objective: craft beacon cores, build a powered archive terminal, then charge it";
    }
    if (sim.isRecipeUnlocked("fast_belt")) {
        return "objective: logistics researched; use the build menu for generator, poles, electric miners, and fast belts";
    }
    const bool hasStoredIronPlate = itemCountInMachines(sim, MachineKind::Chest, ItemId::IronPlate) > 0;
    const bool hasStoredCopperPlate = itemCountInMachines(sim, MachineKind::Chest, ItemId::CopperPlate) > 0;
    if (hasStoredIronPlate && hasStoredCopperPlate) {
        return "objective: craft assembler and lab, then feed iron plus copper plates into science";
    }
    if (hasStoredIronPlate) {
        return "objective: smelt copper too; science needs both iron and copper plates";
    }
    if (machineCount(sim, MachineKind::BurnerMiner) == 0 ||
        machineCount(sim, MachineKind::Furnace) == 0 ||
        machineCount(sim, MachineKind::Inserter) == 0 ||
        machineCount(sim, MachineKind::Chest) == 0) {
        return "objective: mine trees west, stone south, coal east; craft/place a workbench, then build factory parts";
    }
    for (const auto& machine : sim.machines()) {
        if ((machine.kind == MachineKind::BurnerMiner || machine.kind == MachineKind::Furnace) &&
            machine.fuelTicks == 0 && machine.inventory.count(ItemId::Coal) == 0) {
            return "objective: select coal and press E facing each burner machine";
        }
    }
    if (blockedMachineCount(sim) > 0) {
        return "objective: clear blocked output; face machines to inspect status";
    }
    return "objective: wait for ore -> plate -> chest";
}

std::string placementBlockReason(const thoth::game::Simulation& sim, thoth::game::ItemId item)
{
    using thoth::game::TileId;

    if (item == thoth::game::ItemId::None) {
        return "select an item";
    }
    if (sim.itemCount(item) <= 0) {
        return "no item left";
    }

    const auto& player = sim.player();
    const int tx = player.x + thoth::game::dx(player.facing);
    const int ty = player.y + thoth::game::dy(player.facing);
    if (sim.machineAt(tx, ty, player.z) != nullptr) {
        return "target occupied";
    }

    const auto targetTile = sim.world().getTile(tx, ty, player.z);
    const auto& def = thoth::game::itemDef(item);
    if (def.canPlaceMachine) {
        const auto& machine = thoth::game::machineDef(def.placeMachine);
        if (machine.requiresResourceTile) {
            if (targetTile.id != TileId::IronOre && targetTile.id != TileId::CopperOre && targetTile.id != TileId::CoalOre) {
                return "needs ore or coal tile";
            }
            return "";
        }
        if (machine.requiresBuildableTile) {
            const auto& tile = thoth::game::tileDef(targetTile.id);
            if (!tile.walkable) {
                return "clear " + std::string(tile.displayName);
            }
            if (!tile.buildable) {
                return "needs buildable ground";
            }
        }
        return "";
    }
    if (def.canPlaceTile) {
        if (!sim.world().isWalkable(tx, ty, player.z)) {
            return "clear target first";
        }
        return "";
    }
    return "item is not placeable";
}

bool canPreviewPlace(const thoth::game::Simulation& sim, thoth::game::ItemId item)
{
    return placementBlockReason(sim, item).empty();
}

bool selectedBuildToolActive(const thoth::game::Simulation& sim)
{
    const auto item = sim.selectedItem();
    if (item == thoth::game::ItemId::None) {
        return false;
    }
    const auto& def = thoth::game::itemDef(item);
    return def.canPlaceTile || def.canPlaceMachine;
}

thoth::game::Direction facingFromInput(thoth::game::Direction fallback)
{
    using thoth::game::Direction;
    if (IsKeyDown(KEY_W) || IsKeyDown(KEY_UP)) {
        return Direction::North;
    }
    if (IsKeyDown(KEY_D) || IsKeyDown(KEY_RIGHT)) {
        return Direction::East;
    }
    if (IsKeyDown(KEY_S) || IsKeyDown(KEY_DOWN)) {
        return Direction::South;
    }
    if (IsKeyDown(KEY_A) || IsKeyDown(KEY_LEFT)) {
        return Direction::West;
    }
    return fallback;
}

bool movementInputHeld()
{
    return IsKeyDown(KEY_W) || IsKeyDown(KEY_A) || IsKeyDown(KEY_S) || IsKeyDown(KEY_D) ||
        IsKeyDown(KEY_UP) || IsKeyDown(KEY_DOWN) || IsKeyDown(KEY_LEFT) || IsKeyDown(KEY_RIGHT);
}

void updatePlayerVisual(const thoth::game::Simulation& sim, AppState& state)
{
    const float targetX = static_cast<float>(sim.player().x);
    const float targetY = static_cast<float>(sim.player().y);
    if (!state.renderPlayerReady || std::abs(state.renderPlayerX - targetX) + std::abs(state.renderPlayerY - targetY) > 4.0f) {
        state.renderPlayerX = targetX;
        state.renderPlayerY = targetY;
        state.renderPlayerReady = true;
        return;
    }
    state.renderPlayerX += (targetX - state.renderPlayerX) * kPlayerVisualLerp;
    state.renderPlayerY += (targetY - state.renderPlayerY) * kPlayerVisualLerp;
    if (std::abs(state.renderPlayerX - targetX) < 0.01f) {
        state.renderPlayerX = targetX;
    }
    if (std::abs(state.renderPlayerY - targetY) < 0.01f) {
        state.renderPlayerY = targetY;
    }
}

std::string facedMachineText(const thoth::game::Simulation& sim)
{
    const auto* machine = facedMachine(sim);
    if (machine == nullptr) {
        return "facing: none";
    }

    return "facing: " + std::string(thoth::game::toString(machine->kind)) +
        " status=" + std::string(thoth::game::toString(machine->status)) +
        " fuel=" + std::to_string(machine->fuelTicks) +
        " progress=" + std::to_string(machine->progress) +
        " carry=" + std::string(thoth::game::toString(machine->carriedItem)) +
        " output=" + std::string(thoth::game::toString(machine->outputItem)) +
        " inv=" + stacksText(machine->inventory);
}

std::string directionText(thoth::game::Direction direction)
{
    switch (direction) {
    case thoth::game::Direction::North:
        return "north";
    case thoth::game::Direction::East:
        return "east";
    case thoth::game::Direction::South:
        return "south";
    case thoth::game::Direction::West:
        return "west";
    }
    return "south";
}

std::string placementPreviewText(
    const thoth::game::Simulation& sim,
    thoth::game::ItemId item,
    thoth::game::Direction buildDirection)
{
    const auto reason = placementBlockReason(sim, item);
    if (!reason.empty()) {
        return "blocked: " + reason;
    }
    return "place " + shortItemName(item) + " -> " + directionText(buildDirection);
}

bool canMineFacing(const thoth::game::Simulation& sim)
{
    const auto& player = sim.player();
    const auto tile = sim.world().getTile(
        player.x + thoth::game::dx(player.facing),
        player.y + thoth::game::dy(player.facing),
        player.z);
    return thoth::game::isMineable(tile.id);
}

bool isResourceTile(thoth::game::TileId id)
{
    return id == thoth::game::TileId::IronOre ||
        id == thoth::game::TileId::CopperOre ||
        id == thoth::game::TileId::CoalOre;
}

void handleInventoryInput(thoth::game::Simulation& sim, AppState& state, const AudioBank& audio)
{
    if (IsKeyPressed(KEY_V)) {
        state.inventoryOpen = !state.inventoryOpen;
        state.status = state.inventoryOpen ? "inventory open" : "inventory closed";
        playCue(audio, audio.tick);
    }

    if (!state.inventoryOpen) {
        return;
    }

    const bool leftClick = IsMouseButtonPressed(MOUSE_BUTTON_LEFT);
    const bool rightClick = IsMouseButtonPressed(MOUSE_BUTTON_RIGHT);
    if (!leftClick && !rightClick) {
        return;
    }

    const auto mouse = GetMousePosition();
    for (const auto& button : inventoryHotbarButtons()) {
        if (!CheckCollisionPointRec(mouse, button.rect)) {
            continue;
        }

        if (rightClick) {
            sim.queue(thoth::game::Command::assignHotbar(button.hotbarIndex, thoth::game::ItemId::None));
            setFeedback(state, "cleared slot " + std::to_string(button.hotbarIndex + 1), Color{122, 184, 244, 220});
        } else {
            sim.queue(thoth::game::Command::selectHotbar(button.hotbarIndex));
            setFeedback(state, "selected slot " + std::to_string(button.hotbarIndex + 1), Color{122, 184, 244, 220});
        }
        playCue(audio, audio.tick);
        return;
    }

    if (!leftClick) {
        return;
    }

    for (const auto& button : inventoryButtons(sim)) {
        if (!CheckCollisionPointRec(mouse, button.rect)) {
            continue;
        }

        sim.queue(thoth::game::Command::assignHotbar(sim.player().selectedHotbar, button.item));
        setFeedback(
            state,
            "slot " + std::to_string(sim.player().selectedHotbar + 1) + " <- " + std::string(thoth::game::toString(button.item)),
            Color{103, 214, 132, 220});
        playCue(audio, audio.tick);
        return;
    }
}

void handleMachinePanelInput(thoth::game::Simulation& sim, AppState& state, const AudioBank& audio)
{
    if (!IsMouseButtonPressed(MOUSE_BUTTON_LEFT)) {
        return;
    }

    const auto mouse = GetMousePosition();
    const auto* machine = facedMachine(sim);
    if (machine == nullptr) {
        return;
    }

    for (const auto& button : transferAmountButtons()) {
        if (!CheckCollisionPointRec(mouse, button.rect)) {
            continue;
        }

        state.machineTransferAmount = button.amount;
        setFeedback(
            state,
            std::string("machine transfer ") + (button.amount == 0 ? "all" : std::to_string(button.amount) + "x"),
            Color{122, 184, 244, 220});
        playCue(audio, audio.tick);
        return;
    }

    for (const auto& button : machinePanelButtons(sim)) {
        if (!CheckCollisionPointRec(mouse, button.rect)) {
            continue;
        }

        const int amount = effectiveMachineTransferAmount(sim, *machine, button, state.machineTransferAmount);
        if (amount <= 0) {
            setFeedback(state, "transfer blocked: " + std::string(thoth::game::toString(button.item)), Color{236, 84, 84, 220});
            playCue(audio, audio.invalid);
            return;
        }

        if (button.deposit) {
            for (int i = 0; i < amount; ++i) {
                sim.queue(thoth::game::Command::depositItem(sim.player().facing, button.item));
            }
            setFeedback(
                state,
                "deposited " + std::to_string(amount) + "x " + std::string(thoth::game::toString(button.item)),
                Color{103, 214, 132, 220});
            playCue(audio, audio.place);
        } else {
            for (int i = 0; i < amount; ++i) {
                sim.queue(thoth::game::Command::withdrawItem(sim.player().facing, button.item));
            }
            setFeedback(
                state,
                "withdrew " + std::to_string(amount) + "x " + std::string(thoth::game::toString(button.item)),
                Color{122, 184, 244, 220});
            playCue(audio, audio.tick);
        }
        return;
    }

    for (const auto& button : machineRecipeButtons(sim)) {
        if (!CheckCollisionPointRec(mouse, button.rect)) {
            continue;
        }

        sim.queue(thoth::game::Command::configureMachineRecipe(sim.player().facing, std::string(button.recipeKey)));
        setFeedback(state, "machine recipe " + std::string(button.recipeKey), Color{122, 184, 244, 220});
        playCue(audio, audio.tick);
        return;
    }

    for (const auto& button : machineConfigButtons(sim)) {
        if (!CheckCollisionPointRec(mouse, button.rect)) {
            continue;
        }

        if (button.action == MachineConfigAction::Circuit) {
            sim.queue(thoth::game::Command::configureCircuit(sim.player().facing, button.item, button.comparator, button.threshold));
            setFeedback(state, "circuit " + std::string(button.label), Color{122, 184, 244, 220});
        } else {
            sim.queue(thoth::game::Command::configureRequest(sim.player().facing, button.item, button.threshold));
            setFeedback(state, "request " + std::string(button.label), Color{122, 184, 244, 220});
        }
        playCue(audio, audio.tick);
        return;
    }
}

void placeScenarioMachine(
    thoth::game::Simulation& sim,
    thoth::game::ItemId item,
    int x,
    int y,
    thoth::game::Direction targetDirection,
    thoth::game::Direction orientation,
    thoth::game::Tile tile)
{
    sim.world().setTile(x, y, tile);
    const auto added = sim.player().inventory.add(item, 1);
    (void)added;
    sim.player().x = x - thoth::game::dx(targetDirection);
    sim.player().y = y - thoth::game::dy(targetDirection);
    sim.queue(thoth::game::Command::placeItem(targetDirection, item, orientation));
    sim.step();
}

thoth::game::Simulation makeDemoScenario()
{
    using thoth::game::Direction;
    using thoth::game::ItemId;
    using thoth::game::MachineKind;
    using thoth::game::Tile;
    using thoth::game::TileId;

    thoth::game::Simulation sim(20260609);
    placeScenarioMachine(sim, ItemId::BurnerMiner, 1, 0, Direction::East, Direction::East, Tile{TileId::IronOre, 1});
    placeScenarioMachine(sim, ItemId::Belt, 2, 0, Direction::East, Direction::East, Tile{TileId::Floor, 0});
    placeScenarioMachine(sim, ItemId::Inserter, 3, 0, Direction::East, Direction::East, Tile{TileId::Floor, 0});
    placeScenarioMachine(sim, ItemId::Furnace, 4, 0, Direction::East, Direction::East, Tile{TileId::Floor, 0});
    placeScenarioMachine(sim, ItemId::Chest, 5, 0, Direction::East, Direction::East, Tile{TileId::Floor, 0});

    auto* miner = sim.machineAt(1, 0);
    auto* furnace = sim.machineAt(4, 0);
    if (miner != nullptr && miner->kind == MachineKind::BurnerMiner) {
        const auto addedCoal = miner->inventory.add(ItemId::Coal, 2);
        (void)addedCoal;
    }
    if (furnace != nullptr && furnace->kind == MachineKind::Furnace) {
        const auto addedCoal = furnace->inventory.add(ItemId::Coal, 2);
        (void)addedCoal;
    }

    sim.player().x = 0;
    sim.player().y = 1;
    for (int i = 0; i < 90; ++i) {
        sim.step();
    }
    return sim;
}

std::optional<thoth::game::Simulation> loadPackagedReplay(
    const std::filesystem::path& replayPath,
    std::string* error)
{
    const auto path = findBundledPath(replayPath);
    if (!path) {
        if (error != nullptr) {
            *error = "demo replay file not found";
        }
        return std::nullopt;
    }

    auto document = thoth::game::loadReplayDocument(*path, error);
    if (!document) {
        return std::nullopt;
    }
    return thoth::game::runReplayDocument(*document);
}

void queueInput(thoth::game::Simulation& sim, AppState& state, const AudioBank& audio)
{
    using thoth::game::Command;

    handleInventoryInput(sim, state, audio);
    handleCraftMenuInput(sim, state, audio);
    handleMachinePanelInput(sim, state, audio);

    if (state.movementCooldownFrames > 0) {
        --state.movementCooldownFrames;
    }
    const bool moving = movementInputHeld();
    auto direction = facingFromInput(sim.player().facing);
    if (moving && state.movementCooldownFrames <= 0) {
        sim.queue(Command::move(direction));
        state.movementCooldownFrames = kMoveRepeatFrames;
    } else if (moving && direction != sim.player().facing) {
        sim.queue(Command::face(direction));
    } else if (!moving) {
        state.movementCooldownFrames = 0;
    }

    if (IsKeyPressed(KEY_SPACE)) {
        if (canMineFacing(sim)) {
            setFeedback(state, "mined target", Color{240, 218, 123, 220});
            playCue(audio, audio.mine);
        } else {
            setFeedback(state, "nothing mineable", Color{236, 84, 84, 220});
            playCue(audio, audio.invalid);
        }
        sim.queue(Command::mine(sim.player().facing));
    }

    const std::array<int, thoth::game::kHotbarSlots> numberKeys = {
        KEY_ONE,
        KEY_TWO,
        KEY_THREE,
        KEY_FOUR,
        KEY_FIVE,
        KEY_SIX,
        KEY_SEVEN,
        KEY_EIGHT,
        KEY_NINE,
        KEY_ZERO,
    };
    for (int i = 0; i < thoth::game::kHotbarSlots; ++i) {
        if (IsKeyPressed(numberKeys[static_cast<std::size_t>(i)])) {
            sim.queue(Command::selectHotbar(i));
        }
    }

    if (IsKeyPressed(KEY_P)) {
        if (canPreviewPlace(sim, sim.selectedItem())) {
            sim.queue(Command::placeItem(sim.player().facing, sim.selectedItem(), state.buildDirection));
            setFeedback(state, "placed " + std::string(thoth::game::toString(sim.selectedItem())), Color{103, 214, 132, 220});
            playCue(audio, audio.place);
        } else {
            setFeedback(state, "place blocked: " + placementBlockReason(sim, sim.selectedItem()), Color{236, 84, 84, 220});
            playCue(audio, audio.invalid);
        }
    }
    if (IsKeyPressed(KEY_R)) {
        state.buildDirection = rotateClockwise(state.buildDirection);
        setFeedback(state, "build " + directionText(state.buildDirection), Color{122, 184, 244, 220});
        playCue(audio, audio.tick);
    }
    if (IsKeyPressed(KEY_E)) {
        const auto selected = sim.selectedItem();
        const auto& player = sim.player();
        const auto* target = sim.machineAt(
            player.x + thoth::game::dx(player.facing),
            player.y + thoth::game::dy(player.facing),
            player.z);
        if (selected != thoth::game::ItemId::None && sim.itemCount(selected) > 0 && target != nullptr) {
            setFeedback(state, "deposited " + std::string(thoth::game::toString(selected)), Color{103, 214, 132, 220});
            playCue(audio, audio.place);
        } else {
            setFeedback(state, "deposit blocked", Color{236, 84, 84, 220});
            playCue(audio, audio.invalid);
        }
        sim.queue(Command::depositSelected(sim.player().facing));
    }
    if (IsKeyPressed(KEY_J)) {
        sim.queue(Command::interact(sim.player().facing));
        setFeedback(state, "interact", Color{122, 184, 244, 220});
        playCue(audio, audio.tick);
    }
    if (IsKeyPressed(KEY_H)) {
        sim.queue(Command::attack(sim.player().facing));
        setFeedback(state, "attack", Color{240, 218, 123, 220});
        playCue(audio, audio.mine);
    }

    if (IsKeyPressed(KEY_K)) {
        queueCraft(sim, state, audio, "workbench");
    }
    if (IsKeyPressed(KEY_C)) {
        queueCraft(sim, state, audio, "chest");
    }
    if (IsKeyPressed(KEY_F)) {
        queueCraft(sim, state, audio, "furnace");
    }
    if (IsKeyPressed(KEY_B)) {
        queueCraft(sim, state, audio, "belt");
    }
    if (IsKeyPressed(KEY_I)) {
        queueCraft(sim, state, audio, "inserter");
    }
    if (IsKeyPressed(KEY_M)) {
        queueCraft(sim, state, audio, "burner_miner");
    }
    if (IsKeyPressed(KEY_X)) {
        queueCraft(sim, state, audio, "assembler");
    }
    if (IsKeyPressed(KEY_L)) {
        queueCraft(sim, state, audio, "lab");
    }
    if (IsKeyPressed(KEY_T)) {
        queueCraft(sim, state, audio, "fast_belt");
    }
    if (IsKeyPressed(KEY_G)) {
        queueCraft(sim, state, audio, "generator");
    }
    if (IsKeyPressed(KEY_O)) {
        queueCraft(sim, state, audio, "power_pole");
    }
    if (IsKeyPressed(KEY_N)) {
        queueCraft(sim, state, audio, "electric_miner");
    }

    if (IsKeyPressed(KEY_TAB)) {
        state.debug = !state.debug;
        playCue(audio, audio.tick);
    }
    if (IsKeyPressed(KEY_BACKSPACE)) {
        state.paused = !state.paused;
        state.status = state.paused ? "paused" : "running";
        playCue(audio, audio.tick);
    }
    if (IsKeyPressed(KEY_ENTER)) {
        state.paused = true;
        stepSimulationTimed(sim, state);
        updateProductionFeedback(sim, state, audio);
        updateMachineIssueFeedback(sim, state, audio);
        state.status = "stepped one tick";
        playCue(audio, audio.tick);
    }
    if (IsKeyPressed(KEY_F11)) {
        const int index = audioCueIndex(state.audioAuditionIndex);
        const auto name = audioCueName(index);
        playCue(audio, audioCueSound(audio, index));
        state.status = "auditioned " + std::string(name);
        setFeedback(state, "audio " + std::string(name), Color{122, 184, 244, 220});
        state.audioAuditionIndex = audioCueIndex(index + 1);
    }
    if (IsKeyPressed(KEY_F6)) {
        std::string error;
        if (saveGeneratedAtlas(kGeneratedSpriteAtlasPath, &error)) {
            state.status = "exported generated sprite atlas";
            setFeedback(state, "atlas exported", Color{103, 214, 132, 220});
            playCue(audio, audio.load);
        } else {
            state.status = "atlas export failed: " + error;
            setFeedback(state, "atlas export failed", Color{236, 84, 84, 220});
            playCue(audio, audio.invalid);
        }
    }
    if (IsKeyPressed(KEY_F7)) {
        std::string error;
        auto demo = loadPackagedReplay(kScienceReplayPath, &error);
        if (demo) {
            sim = *demo;
            state.status = "loaded science replay demo";
        } else {
            sim = makeDemoScenario();
            state.status = "science replay fallback: " + error;
        }
        syncProductionCounters(sim, state);
        syncMachineIssueCounters(sim, state);
        state.paused = false;
        setFeedback(state, "science demo loaded", Color{103, 214, 132, 220});
        playCue(audio, audio.load);
    }
    if (IsKeyPressed(KEY_F8)) {
        std::string error;
        auto demo = loadPackagedReplay(kDemoReplayPath, &error);
        if (demo) {
            sim = *demo;
            state.status = "loaded packaged replay demo";
        } else {
            sim = makeDemoScenario();
            state.status = "replay fallback: " + error;
        }
        syncProductionCounters(sim, state);
        syncMachineIssueCounters(sim, state);
        state.paused = false;
        setFeedback(state, "demo line loaded", Color{103, 214, 132, 220});
        playCue(audio, audio.load);
    }
    if (IsKeyPressed(KEY_F10)) {
        std::string error;
        auto demo = loadPackagedReplay(kFullFlowReplayPath, &error);
        if (demo) {
            sim = *demo;
            state.status = "loaded full-flow replay demo";
        } else {
            sim = makeDemoScenario();
            state.status = "full-flow fallback: " + error;
        }
        syncProductionCounters(sim, state);
        syncMachineIssueCounters(sim, state);
        state.paused = false;
        setFeedback(state, "full flow loaded", Color{103, 214, 132, 220});
        playCue(audio, audio.load);
    }

    if (IsKeyPressed(KEY_F5)) {
        std::string error;
        state.status = thoth::game::saveSimulation(sim, kSavePath, &error) ? "saved thoth_save.txt" : "save failed: " + error;
        playCue(audio, error.empty() ? audio.save : audio.invalid);
    }

    if (IsKeyPressed(KEY_F9)) {
        std::string error;
        auto loaded = thoth::game::loadSimulation(kSavePath, &error);
        if (loaded) {
            sim = *loaded;
            state.status = "loaded thoth_save.txt";
            syncProductionCounters(sim, state);
            syncMachineIssueCounters(sim, state);
            playCue(audio, audio.load);
        } else {
            state.status = "load failed: " + error;
            playCue(audio, audio.invalid);
        }
    }
}


} // namespace thoth::app
