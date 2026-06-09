#include "thoth/game/registry.hpp"
#include "thoth/game/save.hpp"
#include "thoth/game/simulation.hpp"
#include "thoth/game/world.hpp"

#include <cstdlib>
#include <filesystem>
#include <iostream>
#include <string>

namespace {

void require(bool condition, const std::string& message)
{
    if (!condition) {
        std::cerr << "FAIL: " << message << '\n';
        std::exit(1);
    }
}

void testChunkCoordinates()
{
    require(thoth::game::floorDiv(0, thoth::game::kChunkSize) == 0, "origin chunk div");
    require(thoth::game::floorDiv(31, thoth::game::kChunkSize) == 0, "positive edge chunk div");
    require(thoth::game::floorDiv(32, thoth::game::kChunkSize) == 1, "positive boundary chunk div");
    require(thoth::game::floorDiv(-1, thoth::game::kChunkSize) == -1, "negative edge chunk div");
    require(thoth::game::floorMod(-1, thoth::game::kChunkSize) == 31, "negative edge chunk mod");
}

void testDeterministicTerrain()
{
    thoth::game::World a(42);
    thoth::game::World b(42);
    for (int y = -48; y <= 48; y += 3) {
        for (int x = -48; x <= 48; x += 5) {
            require(a.getTile(x, y).id == b.getTile(x, y).id, "same seed terrain mismatch");
        }
    }

    thoth::game::World c(43);
    bool foundDifference = false;
    for (int y = 16; y <= 80 && !foundDifference; y += 4) {
        for (int x = 16; x <= 80 && !foundDifference; x += 4) {
            foundDifference = a.getTile(x, y).id != c.getTile(x, y).id;
        }
    }
    require(foundDifference, "different seeds should produce different terrain");
}

void testChunkBoundaryMutation()
{
    thoth::game::World world(7);
    world.setTile(31, 0, thoth::game::Tile{thoth::game::TileId::Floor, 0});
    world.setTile(32, 0, thoth::game::Tile{thoth::game::TileId::Water, 0});
    world.setTile(-1, 0, thoth::game::Tile{thoth::game::TileId::CoalOre, 2});

    require(world.getTile(31, 0).id == thoth::game::TileId::Floor, "positive local edge mutation");
    require(world.getTile(32, 0).id == thoth::game::TileId::Water, "positive next chunk mutation");
    require(world.getTile(-1, 0).id == thoth::game::TileId::CoalOre, "negative chunk mutation");
    require(world.getTile(-1, 0).data == 2, "tile data mutation");
}

void testStarterResources()
{
    thoth::game::World world(99);
    require(world.getTile(0, 0).id == thoth::game::TileId::Grass, "spawn should be walkable");
    require(world.getTile(-4, 0).id == thoth::game::TileId::Tree, "starter trees near spawn");
    require(world.getTile(4, 0).id == thoth::game::TileId::IronOre, "starter iron near spawn");
    require(world.getTile(6, 0).id == thoth::game::TileId::CoalOre, "starter coal near spawn");
}

void testSimulationMovementAndMining()
{
    thoth::game::Simulation sim(1);
    sim.world().setTile(1, 0, thoth::game::Tile{thoth::game::TileId::Water, 0});
    sim.queue(thoth::game::Command::move(thoth::game::Direction::East));
    sim.step();
    require(sim.player().x == 0 && sim.player().y == 0, "player should not walk into water");

    sim.world().setTile(1, 0, thoth::game::Tile{thoth::game::TileId::Grass, 0});
    sim.queue(thoth::game::Command::move(thoth::game::Direction::East));
    sim.step();
    require(sim.player().x == 1 && sim.player().y == 0, "player should walk onto grass");

    sim.world().setTile(2, 0, thoth::game::Tile{thoth::game::TileId::Tree, 1});
    sim.queue(thoth::game::Command::mine(thoth::game::Direction::East));
    sim.step();
    require(sim.world().getTile(2, 0).id == thoth::game::TileId::Grass, "mined tree should become grass");
    require(sim.itemCount(thoth::game::ItemId::Wood) == 1, "mining tree should add wood");
}

void testCraftingHotbarAndPlacement()
{
    thoth::game::Simulation sim(2);
    require(sim.player().inventory.add(thoth::game::ItemId::Wood, 8), "test should add wood");
    sim.queue(thoth::game::Command::craft("chest"));
    sim.step();

    require(sim.itemCount(thoth::game::ItemId::Wood) == 0, "crafting should consume recipe inputs");
    require(sim.itemCount(thoth::game::ItemId::Chest) == 1, "crafting should add recipe output");

    sim.queue(thoth::game::Command::selectHotbar(0));
    sim.step();
    require(sim.selectedItem() == thoth::game::ItemId::Stone, "slot 0 should keep starter stone");

    sim.world().setTile(0, 1, thoth::game::Tile{thoth::game::TileId::Grass, 0});
    sim.queue(thoth::game::Command::placeItem(thoth::game::Direction::South, sim.selectedItem()));
    sim.step();
    require(sim.world().getTile(0, 1).id == thoth::game::TileId::Floor, "placing selected stone should create floor");
    require(sim.itemCount(thoth::game::ItemId::Stone) == 9, "placing selected stone should consume one stone");
}

void testSaveLoadRoundTrip()
{
    thoth::game::Simulation sim(5);
    sim.world().setTile(1, 0, thoth::game::Tile{thoth::game::TileId::Tree, 1});
    sim.queue(thoth::game::Command::mine(thoth::game::Direction::East));
    sim.step();
    require(sim.player().inventory.add(thoth::game::ItemId::Wood, 7), "test should add wood for save/load crafting");
    sim.queue(thoth::game::Command::craft("chest"));
    sim.step();
    sim.queue(thoth::game::Command::selectHotbar(1));
    sim.step();

    const auto path = std::filesystem::temp_directory_path() / "thoth_save_roundtrip.txt";
    std::string error;
    require(thoth::game::saveSimulation(sim, path, &error), "save should succeed: " + error);

    auto loaded = thoth::game::loadSimulation(path, &error);
    require(loaded.has_value(), "load should succeed: " + error);
    std::filesystem::remove(path);

    require(loaded->tick() == sim.tick(), "loaded tick should match");
    require(loaded->world().seed() == sim.world().seed(), "loaded seed should match");
    require(loaded->player().x == sim.player().x && loaded->player().y == sim.player().y, "loaded player position should match");
    require(loaded->selectedItem() == sim.selectedItem(), "loaded selected hotbar item should match");
    require(loaded->itemCount(thoth::game::ItemId::Chest) == sim.itemCount(thoth::game::ItemId::Chest), "loaded inventory should match");
    require(loaded->world().getTile(1, 0).id == thoth::game::TileId::Grass, "loaded terrain mutation should match");
}

} // namespace

int main()
{
    testChunkCoordinates();
    testDeterministicTerrain();
    testChunkBoundaryMutation();
    testStarterResources();
    testSimulationMovementAndMining();
    testCraftingHotbarAndPlacement();
    testSaveLoadRoundTrip();

    std::cout << "thoth_tests passed\n";
    return 0;
}
