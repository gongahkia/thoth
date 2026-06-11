#include "thoth/game/registry.hpp"
#include "thoth/game/replay.hpp"
#include "thoth/game/save.hpp"
#include "thoth/game/simulation.hpp"
#include "thoth/game/world.hpp"

#include <algorithm>
#include <cstdint>
#include <cstdlib>
#include <filesystem>
#include <iostream>
#include <map>
#include <queue>
#include <sstream>
#include <string>
#include <utility>
#include <vector>

namespace {

void require(bool condition, const std::string& message)
{
    if (!condition) {
        std::cerr << "FAIL: " << message << '\n';
        std::exit(1);
    }
}

bool isStarterProtectedCell(int x, int y)
{
    return (((x == -5 || x == -4 || x == -3) && y >= -3 && y <= 3) ||
        (x >= -2 && x <= 3 && y == 4) ||
        (x == 4 && y >= -2 && y <= 2) ||
        (x == 6 && y >= -2 && y <= 2) ||
        (x == 8 && y >= -2 && y <= 2) ||
        (x >= -2 && x <= 9 && y >= -3 && y <= 3));
}

int biomeMaskForTest(thoth::game::BiomeKind biome)
{
    return 1 << static_cast<int>(biome);
}

std::string canonicalSignature(const thoth::game::Simulation& sim)
{
    const auto snapshot = sim.snapshot();
    std::ostringstream out;
    out << "seed=" << snapshot.seed << " tick=" << snapshot.tick
        << " next_machine=" << snapshot.nextMachineId
        << " player=" << snapshot.player.x << "," << snapshot.player.y << ","
        << static_cast<int>(snapshot.player.facing) << "," << snapshot.player.selectedHotbar;

    out << " hotbar";
    for (const auto item : snapshot.player.hotbar) {
        out << "," << thoth::game::toString(item);
    }

    out << " inventory";
    for (const auto& stack : snapshot.player.inventory) {
        out << "," << thoth::game::toString(stack.item) << ":" << stack.count;
    }

    out << " research=" << snapshot.activeTech << ":" << snapshot.researchProgress;
    out << " completed";
    for (const auto& key : snapshot.completedTechs) {
        out << "," << key;
    }
    out << " unlocked";
    for (const auto& key : snapshot.unlockedRecipes) {
        out << "," << key;
    }

    out << " tiles";
    for (const auto& tile : snapshot.tiles) {
        out << "," << tile.x << ":" << tile.y << ":" << thoth::game::toString(tile.tile.id)
            << ":" << tile.tile.data;
    }

    out << " machines";
    for (const auto& machine : snapshot.machines) {
        out << "," << machine.id << ":" << thoth::game::toString(machine.kind)
            << ":" << machine.x << ":" << machine.y << ":" << static_cast<int>(machine.direction)
            << ":" << machine.progress << ":" << machine.fuelTicks
            << ":" << thoth::game::toString(machine.status)
            << ":" << thoth::game::toString(machine.carriedItem)
            << ":" << thoth::game::toString(machine.outputItem)
            << ":" << (machine.recipeKey.empty() ? "none" : machine.recipeKey);
        for (const auto& stack : machine.inventory.stacks()) {
            out << ":" << thoth::game::toString(stack.item) << "=" << stack.count;
        }
    }

    return out.str();
}

std::string persistedSignature(const thoth::game::Simulation& sim)
{
    const auto snapshot = sim.snapshot();
    std::ostringstream out;
    out << "seed=" << snapshot.seed << " tick=" << snapshot.tick
        << " next_machine=" << snapshot.nextMachineId
        << " player=" << snapshot.player.x << "," << snapshot.player.y << ","
        << static_cast<int>(snapshot.player.facing) << "," << snapshot.player.selectedHotbar;

    out << " hotbar";
    for (const auto item : snapshot.player.hotbar) {
        out << "," << thoth::game::toString(item);
    }

    out << " inventory";
    for (const auto& stack : snapshot.player.inventory) {
        out << "," << thoth::game::toString(stack.item) << ":" << stack.count;
    }

    out << " research=" << snapshot.activeTech << ":" << snapshot.researchProgress;
    out << " completed";
    for (const auto& key : snapshot.completedTechs) {
        out << "," << key;
    }
    out << " unlocked";
    for (const auto& key : snapshot.unlockedRecipes) {
        out << "," << key;
    }

    out << " tiles";
    for (const auto& tile : snapshot.tiles) {
        out << "," << tile.x << ":" << tile.y << ":" << thoth::game::toString(tile.tile.id)
            << ":" << tile.tile.data;
    }

    out << " machines";
    for (const auto& machine : snapshot.machines) {
        out << "," << machine.id << ":" << thoth::game::toString(machine.kind)
            << ":" << machine.x << ":" << machine.y << ":" << static_cast<int>(machine.direction)
            << ":" << machine.progress << ":" << machine.fuelTicks
            << ":" << thoth::game::toString(machine.carriedItem)
            << ":" << thoth::game::toString(machine.outputItem)
            << ":" << (machine.recipeKey.empty() ? "none" : machine.recipeKey);
        for (const auto& stack : machine.inventory.stacks()) {
            out << ":" << thoth::game::toString(stack.item) << "=" << stack.count;
        }
    }

    return out.str();
}

void testRegistryValidation()
{
    const auto errors = thoth::game::validateRegistries();
    for (const auto& error : errors) {
        std::cerr << "registry: " << error << '\n';
    }
    require(errors.empty(), "registry validation should pass");
}

void testSciencePackRecipeRequiresCopperProgression()
{
    using thoth::game::ItemId;

    const auto* science = thoth::game::recipeDef("science_pack");
    require(science != nullptr, "science pack recipe should exist");
    require(science->station == "assembler", "science pack should be an assembler recipe");
    require(science->inputs.size() == 2, "science pack should have two resource inputs");
    require(science->inputs[0].item == ItemId::IronPlate && science->inputs[0].count == 1,
        "science pack should require one iron plate");
    require(science->inputs[1].item == ItemId::CopperPlate && science->inputs[1].count == 1,
        "science pack should require one copper plate");
    require(science->output.item == ItemId::SciencePack && science->output.count == 1,
        "science pack recipe should produce one science pack");
}

void testMachineRegistryMetadata()
{
    using thoth::game::ItemDef;
    using thoth::game::MachineBehaviorKind;
    using thoth::game::MachineKind;

    require(!thoth::game::machineDefs().empty(), "machine registry should expose machine definitions");

    for (const auto& machine : thoth::game::machineDefs()) {
        require(thoth::game::machineKindFromKey(machine.key) == machine.id, "machine key should round trip");
        require(&thoth::game::machineDef(machine.id) == &machine, "machine id should round trip");
        require(machine.width == 1 && machine.height == 1, "MVP machine footprints should be explicit 1x1");
        require(machine.requiresBuildableTile != machine.requiresResourceTile, "machine should have one placement surface rule");
        require(!thoth::game::toString(machine.behavior).empty(), "machine should expose behavior kind");
    }

    const auto& belt = thoth::game::machineDef(MachineKind::Belt);
    const auto& fastBelt = thoth::game::machineDef(MachineKind::FastBelt);
    require(belt.behavior == MachineBehaviorKind::TransportBelt, "belt should use transport behavior");
    require(fastBelt.behavior == MachineBehaviorKind::TransportBelt, "fast belt should use transport behavior");
    require(belt.inventorySlots == 1 && fastBelt.inventorySlots == 1, "belts should expose one carried-item slot");

    const auto& chest = thoth::game::machineDef(MachineKind::Chest);
    require(chest.behavior == MachineBehaviorKind::Storage, "chest should use storage behavior");
    require(chest.inventorySlots >= 16, "chest should expose storage slots");

    const auto& burnerMiner = thoth::game::machineDef(MachineKind::BurnerMiner);
    const auto& electricMiner = thoth::game::machineDef(MachineKind::ElectricMiner);
    require(burnerMiner.requiresResourceTile, "burner miner should require resource tile placement");
    require(electricMiner.requiresResourceTile, "electric miner should require resource tile placement");

    int placeableMachineItems = 0;
    for (const ItemDef& item : thoth::game::itemDefs()) {
        if (!item.canPlaceMachine) {
            continue;
        }
        ++placeableMachineItems;
        const auto& machine = thoth::game::machineDef(item.placeMachine);
        require(item.key == machine.key, "placeable item key should match machine key");
        require(!machine.displayName.empty(), "placeable item should reference named machine");
    }
    require(placeableMachineItems == static_cast<int>(thoth::game::machineDefs().size()), "each machine should have one placeable item");
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
    require(world.getTile(-3, 0).id == thoth::game::TileId::Tree, "starter inner trees near spawn");
    require(world.getTile(-4, 0).id == thoth::game::TileId::Tree, "starter outer trees near spawn");
    require(world.getTile(0, 4).id == thoth::game::TileId::Stone, "starter stone near spawn");
    require(world.getTile(4, 0).id == thoth::game::TileId::IronOre, "starter iron near spawn");
    require(world.getTile(4, 0).data == 6, "starter iron should have finite richness");
    require(world.getTile(6, 0).id == thoth::game::TileId::CoalOre, "starter coal near spawn");
    require(world.getTile(6, 0).data == 6, "starter coal should have finite richness");
    require(world.getTile(8, 0).id == thoth::game::TileId::CopperOre, "starter copper near spawn");
    require(world.getTile(8, 0).data == 6, "starter copper should have finite richness");
}

void testEarlyBiomeTiles()
{
    using thoth::game::BiomeKind;

    thoth::game::World world(99);
    require(world.biomeAt(12, 0) == BiomeKind::Desert, "public biome query should expose starter desert");
    require(world.biomeAt(-12, 0) == BiomeKind::Snowfield, "public biome query should expose starter snowfield");
    require(world.biomeAt(0, 12) == BiomeKind::Marsh, "public biome query should expose starter marsh");
    require(world.biomeAt(4096, 0) == BiomeKind::Rift, "public biome query should expose rift band");
    require(thoth::game::toString(world.biomeAt(12, 0)) == "desert", "biome key should be stable");

    bool foundSand = false;
    bool foundSnow = false;
    bool foundMud = false;

    for (int y = -24; y <= 24; ++y) {
        for (int x = -24; x <= 24; ++x) {
            if (isStarterProtectedCell(x, y)) {
                continue;
            }
            const auto tile = world.getTile(x, y).id;
            foundSand = foundSand || tile == thoth::game::TileId::Sand;
            foundSnow = foundSnow || tile == thoth::game::TileId::Snow;
            foundMud = foundMud || tile == thoth::game::TileId::Mud;
        }
    }

    require(foundSand, "early world should include sand biome tiles");
    require(foundSnow, "early world should include snow biome tiles");
    require(foundMud, "early world should include mud biome tiles");
}

void testBiomeLairGeneration()
{
    using thoth::game::BiomeKind;
    using thoth::game::LairKind;
    using thoth::game::TileId;

    thoth::game::World world(99);
    require(world.biomeAt(0, 18) == BiomeKind::Marsh, "marsh lair should sit in early marsh");
    require(world.biomeAt(18, -2) == BiomeKind::Desert, "glass spire should sit in early desert");
    require(world.biomeAt(36, 20) == BiomeKind::Badlands, "badlands lair should sit in early badlands");
    require(world.biomeAt(-18, 0) == BiomeKind::Snowfield, "frost vault should sit in early snowfield");
    require(world.biomeAt(-36, 20) == BiomeKind::CrystalField, "crystal lair should sit in early crystal field");

    require(world.lairAt(0, 18).has_value() && *world.lairAt(0, 18) == LairKind::MarshHive,
        "marsh hive center should report lair identity");
    require(world.lairAt(18, -2).has_value() && *world.lairAt(18, -2) == LairKind::GlassSpire,
        "glass spire center should report lair identity");
    require(world.lairAt(36, 20).has_value() && *world.lairAt(36, 20) == LairKind::BadlandsFoundry,
        "badlands foundry center should report lair identity");
    require(world.lairAt(-18, 0).has_value() && *world.lairAt(-18, 0) == LairKind::FrostVault,
        "frost vault center should report lair identity");
    require(world.lairAt(-36, 20).has_value() && *world.lairAt(-36, 20) == LairKind::CrystalVault,
        "crystal vault center should report lair identity");
    require(!world.lairAt(60, 60).has_value(), "ordinary terrain should not report a lair");
    require(thoth::game::toString(LairKind::GlassSpire) == "glass_spire", "glass lair key should be stable");
    require(thoth::game::toString(LairKind::FrostVault) == "frost_vault", "frost lair key should be stable");
    require(thoth::game::toString(LairKind::CrystalVault) == "crystal_vault", "lair key should be stable");

    require(world.getTile(0, 18).id == TileId::StairsDown, "lair center should be an entrance");
    require(world.getTile(1, 18).id == TileId::DungeonFloor, "lair interior should be walkable floor");
    require(world.getTile(5, 18).id == TileId::DungeonWall, "lair perimeter should be wall");
    require(world.getTile(19, -2).id == TileId::Cactus, "glass spire should expose cactus rewards");
    require(world.getTile(-17, 0).id == TileId::Ice, "frost vault should expose ice rewards");
    require(world.getTile(-35, 20).id == TileId::Crystal, "crystal vault should expose crystal rewards");
    require(world.getTile(37, 20).id == TileId::Basalt, "badlands foundry should expose basalt rewards");
}

void testLairEnemyPressureSpawnsBiomeHostiles()
{
    using namespace thoth::game;

    const auto containsKind = [](const Simulation& sim, EntityKind kind) {
        for (const auto& entity : sim.entities()) {
            if (entity.kind == kind) {
                return true;
            }
        }
        return false;
    };

    Simulation marsh(20260611);
    auto snapshot = marsh.snapshot();
    snapshot.player.x = 0;
    snapshot.player.y = 18;
    marsh.restore(snapshot);
    marsh.step();
    require(containsKind(marsh, EntityKind::Slime), "marsh hive should spawn slime pressure");
    require(marsh.player().hp == 20, "marsh lair spawn should not deal immediate damage");

    Simulation badlands(20260611);
    snapshot = badlands.snapshot();
    snapshot.player.x = 36;
    snapshot.player.y = 20;
    badlands.restore(snapshot);
    badlands.step();
    require(containsKind(badlands, EntityKind::Skeleton), "badlands foundry should spawn skeleton pressure");
    require(badlands.player().hp == 20, "badlands lair spawn should not deal immediate damage");

    Simulation desert(20260611);
    snapshot = desert.snapshot();
    snapshot.player.x = 18;
    snapshot.player.y = -2;
    desert.restore(snapshot);
    desert.step();
    require(containsKind(desert, EntityKind::GlassSkitter), "glass spire should spawn glass skitter pressure");
    require(desert.player().hp == 20, "glass spire spawn should not deal immediate damage");

    Simulation snow(20260611);
    snapshot = snow.snapshot();
    snapshot.player.x = -18;
    snapshot.player.y = 0;
    snow.restore(snapshot);
    snow.step();
    require(containsKind(snow, EntityKind::FrostCrawler), "frost vault should spawn frost crawler pressure");
    require(snow.player().hp == 20, "frost vault spawn should not deal immediate damage");

    Simulation crystal(20260611);
    snapshot = crystal.snapshot();
    snapshot.player.x = -36;
    snapshot.player.y = 20;
    crystal.restore(snapshot);
    crystal.step();
    require(containsKind(crystal, EntityKind::DungeonSentinel), "crystal vault should spawn sentinel pressure");
    require(crystal.player().hp == 20, "crystal lair spawn should not deal immediate damage");
}

void testMarshBossSummonPersistenceAndReward()
{
    using namespace thoth::game;

    const auto containsBoss = [](const Simulation& sim) {
        for (const auto& entity : sim.entities()) {
            if (entity.kind == EntityKind::MarshBroodheart) {
                return true;
            }
        }
        return false;
    };

    Simulation sim(20260611);
    auto snapshot = sim.snapshot();
    snapshot.player.x = -1;
    snapshot.player.y = 18;
    snapshot.player.inventory = {
        ItemStack{ItemId::WaterBarrel, 1},
        ItemStack{ItemId::ReedFiber, 3},
        ItemStack{ItemId::SciencePack, 1},
    };
    sim.restore(snapshot);

    sim.queue(Command::interact(Direction::East));
    sim.step();
    require(containsBoss(sim), "prepared marsh hive interaction should summon Broodheart");
    require(sim.itemCount(ItemId::WaterBarrel) == 0, "boss summon should consume water barrel");
    require(sim.itemCount(ItemId::ReedFiber) == 0, "boss summon should consume reed fiber");
    require(sim.itemCount(ItemId::SciencePack) == 0, "boss summon should consume science pack");

    const auto path = std::filesystem::temp_directory_path() / "thoth_marsh_boss_roundtrip.txt";
    std::string error;
    require(thoth::game::saveSimulation(sim, path, &error), "boss save should succeed: " + error);
    auto loaded = thoth::game::loadSimulation(path, &error);
    std::filesystem::remove(path);
    require(loaded.has_value(), "boss load should succeed: " + error);
    require(containsBoss(*loaded), "boss save/load should preserve active boss");

    for (int i = 0; i < 8 && containsBoss(*loaded); ++i) {
        for (const auto& entity : loaded->entities()) {
            if (entity.kind == EntityKind::MarshBroodheart) {
                loaded->player().x = entity.x + 1;
                loaded->player().y = entity.y;
                loaded->player().z = entity.z;
                break;
            }
        }
        loaded->queue(Command::attack(Direction::West));
        loaded->step();
    }
    require(!containsBoss(*loaded), "seven attacks should defeat Broodheart");
    require(loaded->itemCount(ItemId::MarshHeart) == 1, "Broodheart should drop a marsh relic");
    require(loaded->productionTotals().bossesDefeated == 1, "boss defeat should increment boss total");
    require(loaded->productionTotals().bossRelicsClaimed == 1, "boss defeat should increment relic total");
    require(loaded->productionTotals().creaturesDefeated >= 1, "boss defeat should also count as creature defeat");
}

void testBadlandsBossSummonPersistenceAndReward()
{
    using namespace thoth::game;

    const auto containsBoss = [](const Simulation& sim) {
        for (const auto& entity : sim.entities()) {
            if (entity.kind == EntityKind::BadlandsWarden) {
                return true;
            }
        }
        return false;
    };

    Simulation sim(20260611);
    auto snapshot = sim.snapshot();
    snapshot.player.x = 35;
    snapshot.player.y = 20;
    snapshot.player.inventory = {
        ItemStack{ItemId::Basalt, 4},
        ItemStack{ItemId::IronPlate, 4},
        ItemStack{ItemId::AdvancedSciencePack, 1},
    };
    sim.restore(snapshot);

    sim.queue(Command::interact(Direction::East));
    sim.step();
    require(containsBoss(sim), "prepared badlands foundry interaction should summon Warden");
    require(sim.itemCount(ItemId::Basalt) == 0, "Warden summon should consume basalt");
    require(sim.itemCount(ItemId::IronPlate) == 0, "Warden summon should consume iron plates");
    require(sim.itemCount(ItemId::AdvancedSciencePack) == 0, "Warden summon should consume advanced science");

    const auto path = std::filesystem::temp_directory_path() / "thoth_badlands_boss_roundtrip.txt";
    std::string error;
    require(thoth::game::saveSimulation(sim, path, &error), "badlands boss save should succeed: " + error);
    auto loaded = thoth::game::loadSimulation(path, &error);
    std::filesystem::remove(path);
    require(loaded.has_value(), "badlands boss load should succeed: " + error);
    require(containsBoss(*loaded), "badlands boss save/load should preserve active boss");

    for (int i = 0; i < 10 && containsBoss(*loaded); ++i) {
        for (const auto& entity : loaded->entities()) {
            if (entity.kind == EntityKind::BadlandsWarden) {
                loaded->player().x = entity.x + 1;
                loaded->player().y = entity.y;
                loaded->player().z = entity.z;
                break;
            }
        }
        loaded->queue(Command::attack(Direction::West));
        loaded->step();
    }
    require(!containsBoss(*loaded), "repeated attacks should defeat Badlands Warden");
    require(loaded->itemCount(ItemId::WardenCore) == 1, "Badlands Warden should drop a warden relic");
    require(loaded->productionTotals().bossesDefeated == 1, "Badlands Warden should increment boss total");
    require(loaded->productionTotals().bossRelicsClaimed == 1, "Badlands Warden should increment relic total");
}

void testGlassBossSummonPersistenceAndReward()
{
    using namespace thoth::game;

    const auto containsBoss = [](const Simulation& sim) {
        for (const auto& entity : sim.entities()) {
            if (entity.kind == EntityKind::GlassMaw) {
                return true;
            }
        }
        return false;
    };

    Simulation sim(20260611);
    auto snapshot = sim.snapshot();
    snapshot.player.x = 17;
    snapshot.player.y = -2;
    snapshot.player.inventory = {
        ItemStack{ItemId::SandGlass, 3},
        ItemStack{ItemId::CactusFiber, 3},
        ItemStack{ItemId::SciencePack, 1},
    };
    sim.restore(snapshot);

    sim.queue(Command::interact(Direction::East));
    sim.step();
    require(containsBoss(sim), "prepared glass spire interaction should summon Glass Maw");
    require(sim.itemCount(ItemId::SandGlass) == 0, "Glass Maw summon should consume sand glass");
    require(sim.itemCount(ItemId::CactusFiber) == 0, "Glass Maw summon should consume cactus fiber");
    require(sim.itemCount(ItemId::SciencePack) == 0, "Glass Maw summon should consume science");

    const auto path = std::filesystem::temp_directory_path() / "thoth_glass_boss_roundtrip.txt";
    std::string error;
    require(thoth::game::saveSimulation(sim, path, &error), "glass boss save should succeed: " + error);
    auto loaded = thoth::game::loadSimulation(path, &error);
    std::filesystem::remove(path);
    require(loaded.has_value(), "glass boss load should succeed: " + error);
    require(containsBoss(*loaded), "glass boss save/load should preserve active boss");

    for (int i = 0; i < 9 && containsBoss(*loaded); ++i) {
        for (const auto& entity : loaded->entities()) {
            if (entity.kind == EntityKind::GlassMaw) {
                loaded->player().x = entity.x + 1;
                loaded->player().y = entity.y;
                loaded->player().z = entity.z;
                break;
            }
        }
        loaded->queue(Command::attack(Direction::West));
        loaded->step();
    }
    require(!containsBoss(*loaded), "repeated attacks should defeat Glass Maw");
    require(loaded->itemCount(ItemId::GlassHeart) == 1, "Glass Maw should drop a glass relic");
    require(loaded->productionTotals().bossesDefeated == 1, "Glass Maw should increment boss total");
    require(loaded->productionTotals().bossRelicsClaimed == 1, "Glass Maw should increment relic total");
}

void testFrostBossSummonPersistenceAndReward()
{
    using namespace thoth::game;

    const auto containsBoss = [](const Simulation& sim) {
        for (const auto& entity : sim.entities()) {
            if (entity.kind == EntityKind::FrostNullifier) {
                return true;
            }
        }
        return false;
    };

    Simulation sim(20260611);
    auto snapshot = sim.snapshot();
    snapshot.player.x = -19;
    snapshot.player.y = 0;
    snapshot.player.inventory = {
        ItemStack{ItemId::IceShard, 4},
        ItemStack{ItemId::CircuitBoard, 2},
        ItemStack{ItemId::AdvancedSciencePack, 1},
    };
    sim.restore(snapshot);

    sim.queue(Command::interact(Direction::East));
    sim.step();
    require(containsBoss(sim), "prepared frost vault interaction should summon Frost Nullifier");
    require(sim.itemCount(ItemId::IceShard) == 0, "Frost Nullifier summon should consume ice shards");
    require(sim.itemCount(ItemId::CircuitBoard) == 0, "Frost Nullifier summon should consume circuit boards");
    require(sim.itemCount(ItemId::AdvancedSciencePack) == 0, "Frost Nullifier summon should consume advanced science");

    const auto path = std::filesystem::temp_directory_path() / "thoth_frost_boss_roundtrip.txt";
    std::string error;
    require(thoth::game::saveSimulation(sim, path, &error), "frost boss save should succeed: " + error);
    auto loaded = thoth::game::loadSimulation(path, &error);
    std::filesystem::remove(path);
    require(loaded.has_value(), "frost boss load should succeed: " + error);
    require(containsBoss(*loaded), "frost boss save/load should preserve active boss");

    for (int i = 0; i < 11 && containsBoss(*loaded); ++i) {
        for (const auto& entity : loaded->entities()) {
            if (entity.kind == EntityKind::FrostNullifier) {
                loaded->player().x = entity.x + 1;
                loaded->player().y = entity.y;
                loaded->player().z = entity.z;
                break;
            }
        }
        loaded->queue(Command::attack(Direction::West));
        loaded->step();
    }
    require(!containsBoss(*loaded), "repeated attacks should defeat Frost Nullifier");
    require(loaded->itemCount(ItemId::FrostCore) == 1, "Frost Nullifier should drop a frost relic");
    require(loaded->productionTotals().bossesDefeated == 1, "Frost Nullifier should increment boss total");
    require(loaded->productionTotals().bossRelicsClaimed == 1, "Frost Nullifier should increment relic total");
}

void testRiftBossRequiresArchiveAndRiftProgress()
{
    using namespace thoth::game;

    const auto containsBoss = [](const Simulation& sim) {
        for (const auto& entity : sim.entities()) {
            if (entity.kind == EntityKind::RiftSignalTyrant) {
                return true;
            }
        }
        return false;
    };

    Simulation blocked(20260611);
    auto snapshot = blocked.snapshot();
    snapshot.player.x = -37;
    snapshot.player.y = 20;
    snapshot.player.inventory = {
        ItemStack{ItemId::BeaconCore, 1},
        ItemStack{ItemId::Crystal, 2},
        ItemStack{ItemId::AdvancedSciencePack, 2},
    };
    blocked.restore(snapshot);
    blocked.queue(Command::interact(Direction::East));
    blocked.step();
    require(!containsBoss(blocked), "rift boss should not summon before archive and rift progress");

    Simulation sim(20260611);
    snapshot = sim.snapshot();
    snapshot.player.x = -37;
    snapshot.player.y = 20;
    snapshot.productionTotals.archiveSignals = 1;
    snapshot.productionTotals.riftJumps = 1;
    snapshot.player.inventory = {
        ItemStack{ItemId::BeaconCore, 1},
        ItemStack{ItemId::Crystal, 2},
        ItemStack{ItemId::AdvancedSciencePack, 2},
    };
    sim.restore(snapshot);

    sim.queue(Command::interact(Direction::East));
    sim.step();
    require(containsBoss(sim), "prepared crystal vault interaction should summon Rift Signal Tyrant");
    require(sim.itemCount(ItemId::BeaconCore) == 0, "Rift boss summon should consume beacon core");
    require(sim.itemCount(ItemId::Crystal) == 0, "Rift boss summon should consume crystals");
    require(sim.itemCount(ItemId::AdvancedSciencePack) == 0, "Rift boss summon should consume advanced science");

    const auto path = std::filesystem::temp_directory_path() / "thoth_rift_boss_roundtrip.txt";
    std::string error;
    require(thoth::game::saveSimulation(sim, path, &error), "rift boss save should succeed: " + error);
    auto loaded = thoth::game::loadSimulation(path, &error);
    std::filesystem::remove(path);
    require(loaded.has_value(), "rift boss load should succeed: " + error);
    require(containsBoss(*loaded), "rift boss save/load should preserve active boss");

    for (int i = 0; i < 13 && containsBoss(*loaded); ++i) {
        for (const auto& entity : loaded->entities()) {
            if (entity.kind == EntityKind::RiftSignalTyrant) {
                loaded->player().x = entity.x + 1;
                loaded->player().y = entity.y;
                loaded->player().z = entity.z;
                break;
            }
        }
        loaded->queue(Command::attack(Direction::West));
        loaded->step();
    }
    require(!containsBoss(*loaded), "repeated attacks should defeat Rift Signal Tyrant");
    require(loaded->itemCount(ItemId::RiftCrown) == 1, "Rift Signal Tyrant should drop a rift relic");
    require(loaded->productionTotals().bossesDefeated == 1, "Rift Signal Tyrant should increment boss total");
    require(loaded->productionTotals().bossRelicsClaimed == 1, "Rift Signal Tyrant should increment relic total");
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

    sim.world().setTile(2, 0, thoth::game::Tile{thoth::game::TileId::IronOre, 3});
    sim.queue(thoth::game::Command::move(thoth::game::Direction::East));
    sim.step();
    require(sim.player().x == 2 && sim.player().y == 0, "player should walk over ore");

    sim.world().setTile(3, 0, thoth::game::Tile{thoth::game::TileId::Stone, 1});
    sim.queue(thoth::game::Command::move(thoth::game::Direction::East));
    sim.step();
    require(sim.player().x == 3 && sim.player().y == 0, "player should walk over stone");

    sim.world().setTile(4, 0, thoth::game::Tile{thoth::game::TileId::Tree, 1});
    sim.queue(thoth::game::Command::mine(thoth::game::Direction::East));
    sim.step();
    require(sim.world().getTile(4, 0).id == thoth::game::TileId::Grass, "mined tree should become grass");
    require(sim.itemCount(thoth::game::ItemId::Wood) == 1, "mining tree should add wood");
}

void testCraftingHotbarAndPlacement()
{
    thoth::game::Simulation sim(2);
    require(sim.player().inventory.add(thoth::game::ItemId::Wood, 14), "test should add wood");
    sim.world().setTile(1, 0, thoth::game::Tile{thoth::game::TileId::Grass, 0});
    sim.queue(thoth::game::Command::craft("workbench"));
    sim.step();
    sim.queue(thoth::game::Command::placeItem(thoth::game::Direction::East, thoth::game::ItemId::Workbench));
    sim.step();
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
    require(sim.itemCount(thoth::game::ItemId::Stone) == 7, "placing selected stone should consume one stone after workbench");

    sim.world().setTile(0, -1, thoth::game::Tile{thoth::game::TileId::IronOre, 3});
    sim.queue(thoth::game::Command::placeItem(thoth::game::Direction::North, sim.selectedItem()));
    sim.step();
    require(sim.world().getTile(0, -1).id == thoth::game::TileId::IronOre, "floor placement should not cover ore");
    require(sim.itemCount(thoth::game::ItemId::Stone) == 7, "blocked ore floor placement should not consume stone");
}

void testAssignHotbarCommand()
{
    using thoth::game::Command;
    using thoth::game::ItemId;

    thoth::game::Simulation sim(33);
    require(sim.player().inventory.add(ItemId::Wood, 3), "test should add assignable wood");

    sim.queue(Command::assignHotbar(4, ItemId::Wood));
    sim.step();
    require(sim.player().selectedHotbar == 4, "assign hotbar should select assigned slot");
    require(sim.selectedItem() == ItemId::Wood, "assign hotbar should put item in selected slot");

    sim.queue(Command::assignHotbar(4, ItemId::IronPlate));
    sim.step();
    require(sim.selectedItem() == ItemId::Wood, "assign hotbar should reject items not in inventory");

    sim.queue(Command::assignHotbar(99, ItemId::Stone));
    sim.step();
    require(sim.player().selectedHotbar == 4, "assign hotbar should reject invalid slot");
    require(sim.selectedItem() == ItemId::Wood, "invalid assign slot should leave selected item unchanged");

    sim.queue(Command::assignHotbar(4, ItemId::None));
    sim.step();
    require(sim.player().selectedHotbar == 4, "clearing hotbar should keep slot selected");
    require(sim.selectedItem() == ItemId::None, "clearing hotbar should empty assigned slot");
}

void testFacingCommandAndMachineTileProtection()
{
    using thoth::game::Command;
    using thoth::game::Direction;
    using thoth::game::ItemId;
    using thoth::game::MachineKind;
    using thoth::game::Tile;
    using thoth::game::TileId;

    thoth::game::Simulation sim(22);
    sim.queue(Command::face(Direction::East));
    sim.step();
    require(sim.player().facing == Direction::East, "face command should rotate player without moving");
    require(sim.player().x == 0 && sim.player().y == 0, "face command should not move player");

    sim.world().setTile(1, 0, Tile{TileId::Grass, 0});
    require(sim.player().inventory.add(ItemId::Chest, 1), "test should add chest");
    sim.queue(Command::placeItem(Direction::East, ItemId::Chest));
    sim.step();
    auto* chest = sim.machineAt(1, 0);
    require(chest != nullptr && chest->kind == MachineKind::Chest, "chest should be placed");

    sim.queue(Command::placeItem(Direction::East, ItemId::Stone));
    sim.step();
    require(sim.world().getTile(1, 0).id == TileId::Grass, "tile placement should not overwrite under a machine");
    require(sim.itemCount(ItemId::Stone) == 10, "blocked machine tile placement should not consume item");
}

void testSaveLoadRoundTrip()
{
    thoth::game::Simulation sim(5);
    sim.world().setTile(1, 0, thoth::game::Tile{thoth::game::TileId::Tree, 1});
    sim.queue(thoth::game::Command::mine(thoth::game::Direction::East));
    sim.step();
    require(sim.player().inventory.add(thoth::game::ItemId::Wood, 13), "test should add wood for save/load crafting");
    sim.world().setTile(1, 0, thoth::game::Tile{thoth::game::TileId::Grass, 0});
    sim.queue(thoth::game::Command::craft("workbench"));
    sim.step();
    sim.queue(thoth::game::Command::placeItem(thoth::game::Direction::East, thoth::game::ItemId::Workbench));
    sim.step();
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

void testRichPersistedStateRoundTrip()
{
    using thoth::game::Direction;
    using thoth::game::ItemId;
    using thoth::game::ItemStack;
    using thoth::game::Machine;
    using thoth::game::MachineKind;
    using thoth::game::Simulation;
    using thoth::game::SimulationSnapshot;
    using thoth::game::Tile;
    using thoth::game::TileId;
    using thoth::game::TileSnapshot;

    SimulationSnapshot snapshot;
    snapshot.seed = 20260609;
    snapshot.tick = 123;
    snapshot.player.x = -4;
    snapshot.player.y = 7;
    snapshot.player.facing = Direction::West;
    snapshot.player.selectedHotbar = 3;
    snapshot.player.hotbar.fill(ItemId::None);
    snapshot.player.hotbar[0] = ItemId::Stone;
    snapshot.player.hotbar[1] = ItemId::Belt;
    snapshot.player.hotbar[3] = ItemId::Assembler;
    snapshot.player.inventory = {
        ItemStack{ItemId::Wood, 5},
        ItemStack{ItemId::IronPlate, 3},
        ItemStack{ItemId::CopperPlate, 2},
    };
    snapshot.tiles = {
        TileSnapshot{-1, 0, Tile{TileId::Floor, 0}},
        TileSnapshot{0, 0, Tile{TileId::Grass, 0}},
        TileSnapshot{31, 0, Tile{TileId::IronOre, 4}},
        TileSnapshot{32, 0, Tile{TileId::CopperOre, 5}},
    };
    snapshot.nextMachineId = 9;
    snapshot.activeTech = "logistics_1";
    snapshot.researchProgress = 2;
    snapshot.completedTechs = {"logistics_1"};
    snapshot.unlockedRecipes = {"fast_belt", "generator"};
    snapshot.productionTotals.bossesDefeated = 2;
    snapshot.productionTotals.outpostsActivated = 1;
    snapshot.productionTotals.pressureWavesRepelled = 3;
    snapshot.productionTotals.bossRelicsClaimed = 2;
    snapshot.productionTotals.outpostBiomeMask =
        biomeMaskForTest(thoth::game::BiomeKind::Marsh) |
        biomeMaskForTest(thoth::game::BiomeKind::Desert);

    Machine belt;
    belt.id = 1;
    belt.kind = MachineKind::Belt;
    belt.x = 0;
    belt.y = 1;
    belt.direction = Direction::East;
    belt.carriedItem = ItemId::IronOre;
    snapshot.machines.push_back(belt);

    Machine furnace;
    furnace.id = 2;
    furnace.kind = MachineKind::Furnace;
    furnace.x = 1;
    furnace.y = 1;
    furnace.direction = Direction::East;
    furnace.progress = 17;
    furnace.fuelTicks = 42;
    furnace.outputItem = ItemId::IronPlate;
    furnace.recipeKey = "iron_plate";
    require(furnace.inventory.add(ItemId::IronOre, 1), "test should seed furnace input");
    require(furnace.inventory.add(ItemId::Coal, 2), "test should seed furnace fuel inventory");
    snapshot.machines.push_back(furnace);

    Machine assembler;
    assembler.id = 3;
    assembler.kind = MachineKind::Assembler;
    assembler.x = 2;
    assembler.y = 1;
    assembler.direction = Direction::South;
    assembler.progress = 11;
    assembler.recipeKey = "science_pack";
    require(assembler.inventory.add(ItemId::IronPlate, 1), "test should seed assembler iron input");
    require(assembler.inventory.add(ItemId::CopperPlate, 1), "test should seed assembler copper input");
    snapshot.machines.push_back(assembler);

    Machine lab;
    lab.id = 4;
    lab.kind = MachineKind::Lab;
    lab.x = 3;
    lab.y = 1;
    lab.direction = Direction::West;
    lab.progress = 19;
    require(lab.inventory.add(ItemId::SciencePack, 1), "test should seed lab science input");
    snapshot.machines.push_back(lab);

    const auto sim = Simulation::fromSnapshot(snapshot);
    const auto path = std::filesystem::temp_directory_path() / "thoth_rich_persisted_state_roundtrip.txt";
    std::string error;
    require(thoth::game::saveSimulation(sim, path, &error), "rich state save should succeed: " + error);
    auto loaded = thoth::game::loadSimulation(path, &error);
    require(loaded.has_value(), "rich state load should succeed: " + error);
    std::filesystem::remove(path);

    require(
        persistedSignature(*loaded) == persistedSignature(sim),
        "rich persisted save/load signature should match");
    require(loaded->productionTotals().bossesDefeated == 2, "boss total should persist");
    require(loaded->productionTotals().outpostsActivated == 1, "outpost total should persist");
    require(loaded->productionTotals().pressureWavesRepelled == 3, "pressure wave total should persist");
    require(loaded->productionTotals().bossRelicsClaimed == 2, "boss relic total should persist");
    require(loaded->productionTotals().outpostBiomeMask == snapshot.productionTotals.outpostBiomeMask,
        "outpost biome mask should persist");
    require(loaded->hasActivatedOutpostBiome(thoth::game::BiomeKind::Marsh), "marsh outpost coverage should persist");
    require(loaded->hasActivatedOutpostBiome(thoth::game::BiomeKind::Desert), "desert outpost coverage should persist");
}

void prepareReplayWorld(thoth::game::Simulation& sim)
{
    sim.world().setTile(1, 0, thoth::game::Tile{thoth::game::TileId::Tree, 14});
    sim.world().setTile(1, 1, thoth::game::Tile{thoth::game::TileId::Floor, 0});
    sim.world().setTile(0, 0, thoth::game::Tile{thoth::game::TileId::Grass, 0});
}

thoth::game::Replay shortReplay()
{
    using thoth::game::Command;
    using thoth::game::Direction;
    using thoth::game::ItemId;

    return thoth::game::Replay{
        thoth::game::ReplayFrame{0, Command::mine(Direction::East)},
        thoth::game::ReplayFrame{1, Command::craft("workbench")},
        thoth::game::ReplayFrame{2, Command::placeItem(Direction::East, ItemId::Workbench)},
        thoth::game::ReplayFrame{3, Command::craft("chest")},
        thoth::game::ReplayFrame{4, Command::move(Direction::East)},
        thoth::game::ReplayFrame{5, Command::placeItem(Direction::South, ItemId::Chest)},
        thoth::game::ReplayFrame{6, Command::placeItem(Direction::West, ItemId::Stone)},
    };
}

std::filesystem::path packagedReplayPath(const char* replayName)
{
    const std::vector<std::filesystem::path> candidates = {
        std::filesystem::path("assets/replays") / replayName,
        std::filesystem::path("../assets/replays") / replayName,
        std::filesystem::path("../../assets/replays") / replayName,
        std::filesystem::path("../../../assets/replays") / replayName,
    };
    for (const auto& candidate : candidates) {
        if (std::filesystem::exists(candidate)) {
            return candidate;
        }
    }
    return candidates.front();
}

void testReplayDeterminismAcrossSaveLoad()
{
    constexpr std::uint64_t kSeed = 17;
    constexpr std::uint64_t kSplitTick = 3;
    constexpr std::uint64_t kFinalTick = 8;
    const auto replay = shortReplay();

    thoth::game::Simulation full(kSeed);
    prepareReplayWorld(full);
    thoth::game::applyReplay(full, replay, kFinalTick);

    thoth::game::Simulation repeated(kSeed);
    prepareReplayWorld(repeated);
    thoth::game::applyReplay(repeated, replay, kFinalTick);
    require(canonicalSignature(repeated) == canonicalSignature(full), "replaying same commands should match");

    thoth::game::Simulation split(kSeed);
    prepareReplayWorld(split);
    thoth::game::applyReplay(split, replay, kSplitTick);

    const auto path = std::filesystem::temp_directory_path() / "thoth_replay_roundtrip.txt";
    std::string error;
    require(thoth::game::saveSimulation(split, path, &error), "replay split save should succeed: " + error);
    auto loaded = thoth::game::loadSimulation(path, &error);
    require(loaded.has_value(), "replay split load should succeed: " + error);
    std::filesystem::remove(path);

    thoth::game::applyReplay(*loaded, replay, kFinalTick);
    require(canonicalSignature(*loaded) == canonicalSignature(full), "replay after save/load should match full replay");
}

void testReplayDocumentRoundTrip()
{
    using thoth::game::Command;
    using thoth::game::Direction;
    using thoth::game::ItemId;

    thoth::game::ReplayDocument document;
    document.seed = 51;
    document.finalTick = 5;
    document.playerInventory = {
        thoth::game::ItemStack{ItemId::Wood, 8},
        thoth::game::ItemStack{ItemId::Workbench, 1},
    };
    document.tiles = {
        thoth::game::TileSnapshot{1, 0, thoth::game::Tile{thoth::game::TileId::Floor, 0}},
    };
    document.replay = {
        thoth::game::ReplayFrame{0, Command::placeItem(Direction::East, ItemId::Workbench)},
        thoth::game::ReplayFrame{1, Command::craft("chest")},
        thoth::game::ReplayFrame{2, Command::assignHotbar(2, ItemId::Chest)},
        thoth::game::ReplayFrame{3, Command::face(Direction::East)},
        thoth::game::ReplayFrame{4, Command::configureMachineRecipe(Direction::East, "science_pack")},
    };

    const auto path = std::filesystem::temp_directory_path() / "thoth_replay_document_roundtrip.txt";
    std::string error;
    require(thoth::game::saveReplayDocument(document, path, &error), "replay document save should succeed: " + error);
    auto loaded = thoth::game::loadReplayDocument(path, &error);
    require(loaded.has_value(), "replay document load should succeed: " + error);
    std::filesystem::remove(path);

    auto original = thoth::game::runReplayDocument(document);
    auto replayed = thoth::game::runReplayDocument(*loaded);
    require(canonicalSignature(replayed) == canonicalSignature(original), "loaded replay document should reproduce canonical state");
    require(replayed.itemCount(ItemId::Chest) == 1, "replay document should craft a chest from setup inventory");
    require(replayed.player().hotbar[2] == ItemId::Chest, "replay document should reproduce hotbar assignment");
}

void testPackagedOreToPlateReplay()
{
    using thoth::game::ItemId;
    using thoth::game::MachineKind;

    std::string error;
    auto document = thoth::game::loadReplayDocument(packagedReplayPath("ore_to_plate.thothreplay"), &error);
    require(document.has_value(), "packaged replay should load: " + error);
    auto simulation = thoth::game::runReplayDocument(*document);

    const auto* chest = simulation.machineAt(5, 0);
    require(chest != nullptr && chest->kind == MachineKind::Chest, "packaged replay should place output chest");
    require(chest->inventory.count(ItemId::IronPlate) >= 1, "packaged replay should produce at least one iron plate");
    require(simulation.tick() == document->finalTick, "packaged replay should run to final tick");
}

void testPackagedOreToScienceReplay()
{
    using thoth::game::MachineKind;

    std::string error;
    auto document = thoth::game::loadReplayDocument(packagedReplayPath("science_research.thothreplay"), &error);
    require(document.has_value(), "packaged science replay should load: " + error);
    auto simulation = thoth::game::runReplayDocument(*document);

    const auto* assembler = simulation.machineAt(1, 0);
    const auto* lab = simulation.machineAt(2, 0);
    require(assembler != nullptr && assembler->kind == MachineKind::Assembler, "science replay should place an assembler");
    require(lab != nullptr && lab->kind == MachineKind::Lab, "science replay should place a lab");
    require(simulation.isTechCompleted("logistics_1"), "science replay should complete Logistics 1");
    require(simulation.isRecipeUnlocked("fast_belt"), "science replay should unlock fast belts");
    require(simulation.isRecipeUnlocked("generator"), "science replay should unlock generators");
    require(simulation.isRecipeUnlocked("power_pole"), "science replay should unlock power poles");
    require(simulation.isRecipeUnlocked("electric_miner"), "science replay should unlock electric miners");
    require(simulation.tick() == document->finalTick, "packaged science replay should run to final tick");
}

void testPackagedFullFlowReplay()
{
    using thoth::game::ItemId;
    using thoth::game::MachineKind;
    using thoth::game::TileId;

    std::string error;
    auto document = thoth::game::loadReplayDocument(packagedReplayPath("full_flow.thothreplay"), &error);
    require(document.has_value(), "packaged full-flow replay should load: " + error);
    auto simulation = thoth::game::runReplayDocument(*document);

    const auto* firstChest = simulation.machineAt(5, 0);
    const auto* assembler = simulation.machineAt(1, 2);
    const auto* lab = simulation.machineAt(2, 2);
    const auto* generator = simulation.machineAt(0, 4);
    const auto* pole = simulation.machineAt(1, 4);
    const auto* electricMiner = simulation.machineAt(2, 4);
    const auto* poweredChest = simulation.machineAt(3, 4);

    require(document->finalTick >= 3600, "full-flow replay should cover at least 60 seconds at 60 Hz");
    require(simulation.world().getTile(1, 1).id == TileId::Grass, "full-flow replay should mine the starter tree");
    require(firstChest != nullptr && firstChest->kind == MachineKind::Chest, "full-flow replay should place first-line output chest");
    require(firstChest->inventory.count(ItemId::IronPlate) >= 1, "full-flow replay should automate iron plates");
    require(assembler != nullptr && assembler->kind == MachineKind::Assembler, "full-flow replay should place an assembler");
    require(lab != nullptr && lab->kind == MachineKind::Lab, "full-flow replay should place a lab");
    require(simulation.isTechCompleted("logistics_1"), "full-flow replay should complete Logistics 1");
    require(simulation.isRecipeUnlocked("fast_belt"), "full-flow replay should unlock fast belts");
    require(simulation.isRecipeUnlocked("generator"), "full-flow replay should unlock generators");
    require(simulation.isRecipeUnlocked("power_pole"), "full-flow replay should unlock power poles");
    require(simulation.isRecipeUnlocked("electric_miner"), "full-flow replay should unlock electric miners");
    require(generator != nullptr && generator->kind == MachineKind::Generator, "full-flow replay should place a generator");
    require(pole != nullptr && pole->kind == MachineKind::PowerPole, "full-flow replay should place a power pole");
    require(electricMiner != nullptr && electricMiner->kind == MachineKind::ElectricMiner, "full-flow replay should place an electric miner");
    require(poweredChest != nullptr && poweredChest->kind == MachineKind::Chest, "full-flow replay should place powered-miner output chest");

    const auto hasPoweredExtractorNetwork = std::any_of(
        simulation.powerNetworks().begin(),
        simulation.powerNetworks().end(),
        [](const thoth::game::PowerNetwork& network) {
            return network.powered && network.supply >= 1 && network.demand >= 1 &&
                !network.generatorIds.empty() && !network.consumerIds.empty();
        });
    require(hasPoweredExtractorNetwork, "full-flow replay should power the electric miner network");
    require(poweredChest->inventory.count(ItemId::IronOre) >= 1, "full-flow replay should extract ore with powered mining");
    require(simulation.tick() == document->finalTick, "packaged full-flow replay should run to final tick");
}

thoth::game::Machine* placeMachineAt(
    thoth::game::Simulation& sim,
    thoth::game::ItemId item,
    int x,
    int y,
    thoth::game::Direction direction)
{
    sim.world().setTile(x, y, thoth::game::Tile{thoth::game::TileId::Floor, 0});
    require(sim.player().inventory.add(item, 1), "test should add placeable machine item");
    sim.player().x = x - thoth::game::dx(direction);
    sim.player().y = y - thoth::game::dy(direction);
    sim.queue(thoth::game::Command::placeItem(direction, item));
    sim.step();

    auto* machine = sim.machineAt(x, y);
    require(machine != nullptr, "placed machine should exist");
    return machine;
}

thoth::game::Machine* placeMachineAtOnTile(
    thoth::game::Simulation& sim,
    thoth::game::ItemId item,
    int x,
    int y,
    thoth::game::Direction direction,
    thoth::game::Tile tile)
{
    sim.world().setTile(x, y, tile);
    require(sim.player().inventory.add(item, 1), "test should add placeable machine item");
    sim.player().x = x - thoth::game::dx(direction);
    sim.player().y = y - thoth::game::dy(direction);
    sim.queue(thoth::game::Command::placeItem(direction, item));
    sim.step();

    auto* machine = sim.machineAt(x, y);
    require(machine != nullptr, "placed machine should exist on custom tile");
    return machine;
}

void stepCommand(thoth::game::Simulation& sim, thoth::game::Command command)
{
    sim.queue(std::move(command));
    sim.step();
}

void moveTo(thoth::game::Simulation& sim, int targetX, int targetY)
{
    using thoth::game::Command;
    using thoth::game::Direction;

    using Point = std::pair<int, int>;
    const Point start{sim.player().x, sim.player().y};
    const Point target{targetX, targetY};
    if (start == target) {
        return;
    }

    const int minX = std::min(start.first, target.first) - 12;
    const int maxX = std::max(start.first, target.first) + 12;
    const int minY = std::min(start.second, target.second) - 12;
    const int maxY = std::max(start.second, target.second) + 12;
    const std::array<Direction, 4> directions = {
        Direction::North,
        Direction::East,
        Direction::South,
        Direction::West,
    };

    std::queue<Point> frontier;
    std::map<Point, Point> previous;
    std::map<Point, Direction> previousDirection;
    frontier.push(start);
    previous[start] = start;

    while (!frontier.empty() && previous.find(target) == previous.end()) {
        const auto current = frontier.front();
        frontier.pop();

        for (const auto direction : directions) {
            const Point next{
                current.first + thoth::game::dx(direction),
                current.second + thoth::game::dy(direction),
            };
            if (next.first < minX || next.first > maxX || next.second < minY || next.second > maxY) {
                continue;
            }
            if (previous.find(next) != previous.end() || !sim.world().isWalkable(next.first, next.second)) {
                continue;
            }
            previous[next] = current;
            previousDirection[next] = direction;
            frontier.push(next);
        }
    }

    require(previous.find(target) != previous.end(), "test movement path should stay walkable");

    std::vector<Direction> path;
    for (auto current = target; current != start; current = previous[current]) {
        path.push_back(previousDirection[current]);
    }
    std::reverse(path.begin(), path.end());
    for (const auto direction : path) {
        stepCommand(sim, Command::move(direction));
    }
    require(sim.player().x == targetX && sim.player().y == targetY, "test helper should reach target");
}

void selectItem(thoth::game::Simulation& sim, thoth::game::ItemId item)
{
    for (int i = 0; i < thoth::game::kHotbarSlots; ++i) {
        if (sim.player().hotbar[static_cast<std::size_t>(i)] == item) {
            stepCommand(sim, thoth::game::Command::selectHotbar(i));
            require(sim.selectedItem() == item, "selected hotbar item should match requested item");
            return;
        }
    }
    require(false, "requested item should exist on hotbar");
}

void craftByCommand(thoth::game::Simulation& sim, std::string recipeKey)
{
    stepCommand(sim, thoth::game::Command::craft(std::move(recipeKey)));
}

void mineFrom(thoth::game::Simulation& sim, int x, int y, thoth::game::Direction direction)
{
    moveTo(sim, x, y);
    stepCommand(sim, thoth::game::Command::mine(direction));
}

void placeSelectedAt(
    thoth::game::Simulation& sim,
    thoth::game::ItemId item,
    int standX,
    int standY,
    thoth::game::Direction targetDirection,
    thoth::game::Direction orientation)
{
    selectItem(sim, item);
    moveTo(sim, standX, standY);
    stepCommand(sim, thoth::game::Command::placeItem(targetDirection, sim.selectedItem(), orientation));
}

void depositSelectedAt(
    thoth::game::Simulation& sim,
    thoth::game::ItemId item,
    int standX,
    int standY,
    thoth::game::Direction targetDirection)
{
    selectItem(sim, item);
    moveTo(sim, standX, standY);
    stepCommand(sim, thoth::game::Command::depositSelected(targetDirection));
}

void testBeltsMoveStraightAndSurviveSaveLoad()
{
    using thoth::game::Direction;
    using thoth::game::ItemId;
    using thoth::game::MachineKind;

    thoth::game::Simulation sim(18);
    placeMachineAt(sim, ItemId::Belt, 1, 0, Direction::East);
    placeMachineAt(sim, ItemId::Belt, 2, 0, Direction::East);
    placeMachineAt(sim, ItemId::Belt, 3, 0, Direction::East);
    placeMachineAt(sim, ItemId::Chest, 4, 0, Direction::East);
    auto* first = sim.machineAt(1, 0);
    auto* second = sim.machineAt(2, 0);
    auto* third = sim.machineAt(3, 0);
    auto* chest = sim.machineAt(4, 0);
    require(first != nullptr && second != nullptr && third != nullptr && chest != nullptr, "straight route should exist");
    require(first->kind == MachineKind::Belt && first->direction == Direction::East, "first belt should face east");
    require(second->kind == MachineKind::Belt && second->direction == Direction::East, "second belt should face east");
    require(third->kind == MachineKind::Belt && third->direction == Direction::East, "third belt should face east");
    require(chest->kind == MachineKind::Chest, "chest endpoint should exist");

    first->carriedItem = ItemId::Wood;
    sim.step();
    require(first->carriedItem == ItemId::None, "first straight belt should empty after transfer");
    require(second->carriedItem == ItemId::Wood, "second straight belt should receive item");

    const auto path = std::filesystem::temp_directory_path() / "thoth_belt_roundtrip.txt";
    std::string error;
    require(thoth::game::saveSimulation(sim, path, &error), "belt save should succeed: " + error);
    auto loaded = thoth::game::loadSimulation(path, &error);
    require(loaded.has_value(), "belt load should succeed: " + error);
    std::filesystem::remove(path);

    const auto* loadedSecond = loaded->machineAt(2, 0);
    require(loadedSecond != nullptr, "loaded second belt should exist");
    require(loadedSecond->carriedItem == ItemId::Wood, "loaded belt should preserve carried item");

    loaded->step();
    loaded->step();
    const auto* loadedChest = loaded->machineAt(4, 0);
    require(loadedChest != nullptr, "loaded chest should exist");
    require(loadedChest->inventory.count(ItemId::Wood) == 1, "straight belts should deliver item to chest");
}

void testBeltsMoveThroughTurns()
{
    using thoth::game::Direction;
    using thoth::game::ItemId;
    using thoth::game::MachineKind;

    thoth::game::Simulation sim(19);
    placeMachineAt(sim, ItemId::Belt, 1, 0, Direction::East);
    placeMachineAt(sim, ItemId::Belt, 2, 0, Direction::South);
    placeMachineAt(sim, ItemId::Belt, 2, 1, Direction::South);
    placeMachineAt(sim, ItemId::Chest, 2, 2, Direction::South);
    auto* first = sim.machineAt(1, 0);
    auto* turn = sim.machineAt(2, 0);
    auto* last = sim.machineAt(2, 1);
    auto* chest = sim.machineAt(2, 2);
    require(first != nullptr && turn != nullptr && last != nullptr && chest != nullptr, "turn route should exist");
    require(turn->kind == MachineKind::Belt && turn->direction == Direction::South, "turn belt should face south");
    require(last->kind == MachineKind::Belt && last->direction == Direction::South, "last belt should face south");
    require(chest->kind == MachineKind::Chest, "turn route chest should exist");

    first->carriedItem = ItemId::Coal;
    for (int i = 0; i < 3; ++i) {
        sim.step();
    }

    require(chest->inventory.count(ItemId::Coal) == 1, "belts should move item through a turn");
}

void testBeltsBlockWithoutDeletingItems()
{
    using thoth::game::Direction;
    using thoth::game::ItemId;
    using thoth::game::MachineStatus;

    thoth::game::Simulation sim(20);
    placeMachineAt(sim, ItemId::Belt, 1, 0, Direction::East);
    placeMachineAt(sim, ItemId::Belt, 2, 0, Direction::East);
    auto* first = sim.machineAt(1, 0);
    auto* second = sim.machineAt(2, 0);
    require(first != nullptr && second != nullptr, "blocked belts should exist");
    first->carriedItem = ItemId::Wood;
    second->carriedItem = ItemId::Coal;

    sim.step();

    require(first->carriedItem == ItemId::Wood, "blocked source belt should keep its item");
    require(second->carriedItem == ItemId::Coal, "blocked target belt should keep its item");
    require(first->status == MachineStatus::OutputBlocked, "blocked source belt should report blockage");
    require(second->status == MachineStatus::OutputBlocked, "blocked terminal belt should report blockage");
}

void testBeltsPreserveItemOrder()
{
    using thoth::game::Direction;
    using thoth::game::ItemId;

    thoth::game::Simulation sim(21);
    placeMachineAt(sim, ItemId::Belt, 1, 0, Direction::East);
    placeMachineAt(sim, ItemId::Belt, 2, 0, Direction::East);
    placeMachineAt(sim, ItemId::Belt, 3, 0, Direction::East);
    placeMachineAt(sim, ItemId::Chest, 4, 0, Direction::East);
    auto* back = sim.machineAt(1, 0);
    auto* middle = sim.machineAt(2, 0);
    auto* front = sim.machineAt(3, 0);
    auto* chest = sim.machineAt(4, 0);
    require(back != nullptr && middle != nullptr && front != nullptr && chest != nullptr, "ordered route should exist");

    back->carriedItem = ItemId::Coal;
    middle->carriedItem = ItemId::Wood;
    sim.step();
    require(back->carriedItem == ItemId::Coal, "back item should wait behind occupied belt");
    require(front->carriedItem == ItemId::Wood, "front item should stay ahead after first flow tick");

    sim.step();
    require(chest->inventory.count(ItemId::Wood) == 1, "front item should reach chest first");
    require(chest->inventory.count(ItemId::Coal) == 0, "back item should not overtake front item");
    require(middle->carriedItem == ItemId::Coal, "back item should advance after front item clears");

    sim.step();
    sim.step();
    require(chest->inventory.count(ItemId::Coal) == 1, "back item should eventually reach chest");
}

void testStarterAutomationLine()
{
    using thoth::game::Command;
    using thoth::game::Direction;
    using thoth::game::ItemId;
    using thoth::game::MachineKind;
    using thoth::game::Tile;
    using thoth::game::TileId;

    thoth::game::Simulation sim(11);
    sim.world().setTile(1, 0, Tile{TileId::IronOre, 1});
    sim.world().setTile(2, 0, Tile{TileId::Floor, 0});
    sim.world().setTile(3, 0, Tile{TileId::Floor, 0});
    sim.world().setTile(4, 0, Tile{TileId::Floor, 0});
    sim.world().setTile(5, 0, Tile{TileId::Floor, 0});

    require(sim.player().inventory.add(ItemId::BurnerMiner, 1), "test should add burner miner");
    sim.player().x = 0;
    sim.player().y = 0;
    sim.queue(Command::placeItem(Direction::East, ItemId::BurnerMiner));
    sim.step();

    require(sim.player().inventory.add(ItemId::Belt, 1), "test should add belt");
    sim.player().x = 1;
    sim.queue(Command::placeItem(Direction::East, ItemId::Belt));
    sim.step();

    require(sim.player().inventory.add(ItemId::Inserter, 1), "test should add inserter");
    sim.player().x = 2;
    sim.queue(Command::placeItem(Direction::East, ItemId::Inserter));
    sim.step();

    require(sim.player().inventory.add(ItemId::Furnace, 1), "test should add furnace");
    sim.player().x = 3;
    sim.queue(Command::placeItem(Direction::East, ItemId::Furnace));
    sim.step();

    require(sim.player().inventory.add(ItemId::Chest, 1), "test should add chest");
    sim.player().x = 4;
    sim.queue(Command::placeItem(Direction::East, ItemId::Chest));
    sim.step();

    auto* furnace = sim.machineAt(4, 0);
    require(furnace != nullptr && furnace->kind == MachineKind::Furnace, "furnace should be placed");
    require(furnace->inventory.add(ItemId::Coal, 1), "test should fuel furnace");
    auto* miner = sim.machineAt(1, 0);
    require(miner != nullptr && miner->kind == MachineKind::BurnerMiner, "miner should be placed");
    require(miner->inventory.add(ItemId::Coal, 1), "test should fuel miner");

    for (int i = 0; i < 80; ++i) {
        sim.step();
    }

    const auto* chest = sim.machineAt(5, 0);
    require(chest != nullptr && chest->kind == MachineKind::Chest, "chest should be placed");
    require(chest->inventory.count(ItemId::IronPlate) >= 1, "automation line should produce an iron plate in chest");

    const auto path = std::filesystem::temp_directory_path() / "thoth_machine_roundtrip.txt";
    std::string error;
    require(thoth::game::saveSimulation(sim, path, &error), "machine save should succeed: " + error);
    auto loaded = thoth::game::loadSimulation(path, &error);
    require(loaded.has_value(), "machine load should succeed: " + error);
    std::filesystem::remove(path);

    const auto* loadedChest = loaded->machineAt(5, 0);
    require(loadedChest != nullptr, "loaded chest should exist");
    require(loadedChest->inventory.count(ItemId::IronPlate) == chest->inventory.count(ItemId::IronPlate), "loaded chest inventory should match");
    const auto* loadedMiner = loaded->machineAt(1, 0);
    require(loadedMiner != nullptr, "loaded miner should exist");
    require(loadedMiner->fuelTicks == miner->fuelTicks, "loaded miner fuel should match");
}

void testAutomationLineAcrossChunkBoundary()
{
    using thoth::game::Direction;
    using thoth::game::ItemId;
    using thoth::game::MachineKind;
    using thoth::game::Tile;
    using thoth::game::TileId;

    thoth::game::Simulation sim(71);
    const int oreX = thoth::game::kChunkSize - 1;
    const int beltX = thoth::game::kChunkSize;

    placeMachineAtOnTile(sim, ItemId::BurnerMiner, oreX, 0, Direction::East, Tile{TileId::IronOre, 1});
    placeMachineAt(sim, ItemId::Belt, beltX, 0, Direction::East);
    placeMachineAt(sim, ItemId::Inserter, beltX + 1, 0, Direction::East);
    placeMachineAt(sim, ItemId::Furnace, beltX + 2, 0, Direction::East);
    placeMachineAt(sim, ItemId::Chest, beltX + 3, 0, Direction::East);

    auto* miner = sim.machineAt(oreX, 0);
    auto* belt = sim.machineAt(beltX, 0);
    auto* inserter = sim.machineAt(beltX + 1, 0);
    auto* furnace = sim.machineAt(beltX + 2, 0);
    auto* chest = sim.machineAt(beltX + 3, 0);

    require(miner != nullptr && miner->kind == MachineKind::BurnerMiner && miner->direction == Direction::East,
        "boundary miner should face east");
    require(belt != nullptr && belt->kind == MachineKind::Belt && belt->direction == Direction::East, "boundary belt should face east");
    require(inserter != nullptr && inserter->kind == MachineKind::Inserter && inserter->direction == Direction::East,
        "boundary inserter should face east");
    require(furnace != nullptr && furnace->kind == MachineKind::Furnace && furnace->direction == Direction::East,
        "boundary furnace should face east");
    require(chest != nullptr && chest->kind == MachineKind::Chest, "boundary chest should be placed");
    require(sim.world().loadedChunkCount() >= 2, "boundary line should load both adjacent chunks");
    require(miner->inventory.add(ItemId::Coal, 1), "test should fuel boundary miner");
    require(furnace->inventory.add(ItemId::Coal, 1), "test should fuel boundary furnace");

    for (int i = 0; i < 80; ++i) {
        sim.step();
    }

    chest = sim.machineAt(beltX + 3, 0);
    require(chest != nullptr && chest->inventory.count(ItemId::IronPlate) >= 1, "boundary line should produce an iron plate");
    require(sim.world().getTile(oreX, 0).id == TileId::Floor, "boundary miner should deplete finite edge ore");

    const auto path = std::filesystem::temp_directory_path() / "thoth_chunk_boundary_line_roundtrip.txt";
    std::string error;
    require(thoth::game::saveSimulation(sim, path, &error), "boundary line save should succeed: " + error);
    auto loaded = thoth::game::loadSimulation(path, &error);
    require(loaded.has_value(), "boundary line load should succeed: " + error);
    std::filesystem::remove(path);

    const auto* loadedChest = loaded->machineAt(beltX + 3, 0);
    require(loadedChest != nullptr, "loaded boundary chest should exist");
    require(loadedChest->inventory.count(ItemId::IronPlate) == chest->inventory.count(ItemId::IronPlate),
        "loaded boundary chest inventory should match");
    require(loaded->world().loadedChunkCount() >= 2, "loaded boundary line should preserve adjacent chunks");
    require(loaded->world().getTile(oreX, 0).id == TileId::Floor, "loaded boundary edge ore depletion should persist");
}

void testCommandOnlyStarterAutomationLoop()
{
    using thoth::game::Direction;
    using thoth::game::ItemId;
    using thoth::game::MachineKind;

    thoth::game::Simulation sim(24);

    for (int y = -3; y <= 3; ++y) {
        mineFrom(sim, -2, y, Direction::West);
        mineFrom(sim, -3, y, Direction::West);
        mineFrom(sim, -4, y, Direction::West);
    }
    require(sim.itemCount(ItemId::Wood) >= 21, "starter trees should provide enough wood");

    for (int x = -2; x <= 3; ++x) {
        mineFrom(sim, x, 3, Direction::South);
    }
    require(sim.itemCount(ItemId::Stone) >= 16, "starter stone should provide enough stone");

    mineFrom(sim, 5, 0, Direction::East);
    mineFrom(sim, 5, 1, Direction::East);
    require(sim.itemCount(ItemId::Coal) >= 2, "starter coal should provide machine fuel");

    craftByCommand(sim, "workbench");
    require(sim.itemCount(ItemId::Workbench) == 1, "normal flow should craft workbench");
    placeSelectedAt(sim, ItemId::Workbench, -1, 1, Direction::South, Direction::East);
    craftByCommand(sim, "chest");
    craftByCommand(sim, "furnace");
    craftByCommand(sim, "burner_miner");
    craftByCommand(sim, "belt");
    craftByCommand(sim, "inserter");

    require(sim.itemCount(ItemId::Chest) == 1, "normal flow should craft chest");
    require(sim.itemCount(ItemId::Furnace) == 1, "normal flow should craft furnace");
    require(sim.itemCount(ItemId::BurnerMiner) == 1, "normal flow should craft burner miner");
    require(sim.itemCount(ItemId::Belt) >= 1, "normal flow should craft belts");
    require(sim.itemCount(ItemId::Inserter) == 1, "normal flow should craft inserter");

    placeSelectedAt(sim, ItemId::Chest, 0, 1, Direction::South, Direction::West);
    placeSelectedAt(sim, ItemId::Furnace, 1, 1, Direction::South, Direction::West);
    placeSelectedAt(sim, ItemId::Inserter, 2, 1, Direction::South, Direction::West);
    placeSelectedAt(sim, ItemId::Belt, 3, 1, Direction::South, Direction::West);
    placeSelectedAt(sim, ItemId::BurnerMiner, 4, 3, Direction::North, Direction::West);

    const auto* chest = sim.machineAt(0, 2);
    const auto* furnace = sim.machineAt(1, 2);
    const auto* inserter = sim.machineAt(2, 2);
    const auto* belt = sim.machineAt(3, 2);
    const auto* miner = sim.machineAt(4, 2);
    require(chest != nullptr && chest->kind == MachineKind::Chest, "normal flow should place chest");
    require(furnace != nullptr && furnace->kind == MachineKind::Furnace && furnace->direction == Direction::West, "normal flow should place west-facing furnace");
    require(inserter != nullptr && inserter->kind == MachineKind::Inserter && inserter->direction == Direction::West, "normal flow should place west-facing inserter");
    require(belt != nullptr && belt->kind == MachineKind::Belt && belt->direction == Direction::West, "normal flow should place west-facing belt");
    require(miner != nullptr && miner->kind == MachineKind::BurnerMiner && miner->direction == Direction::West, "normal flow should place west-facing miner");

    depositSelectedAt(sim, ItemId::Coal, 4, 3, Direction::North);
    depositSelectedAt(sim, ItemId::Coal, 1, 1, Direction::South);

    for (int i = 0; i < 100; ++i) {
        sim.step();
    }

    chest = sim.machineAt(0, 2);
    require(chest != nullptr, "normal flow chest should still exist");
    require(chest->inventory.count(ItemId::IronPlate) >= 1, "normal flow should produce an iron plate in the chest");

    const auto path = std::filesystem::temp_directory_path() / "thoth_command_loop_roundtrip.txt";
    std::string error;
    require(thoth::game::saveSimulation(sim, path, &error), "normal flow save should succeed: " + error);
    auto loaded = thoth::game::loadSimulation(path, &error);
    require(loaded.has_value(), "normal flow load should succeed: " + error);
    std::filesystem::remove(path);

    const auto* loadedChest = loaded->machineAt(0, 2);
    require(loadedChest != nullptr, "normal flow loaded chest should exist");
    require(loadedChest->inventory.count(ItemId::IronPlate) == chest->inventory.count(ItemId::IronPlate), "normal flow loaded chest inventory should match");
}

void testInserterTransfersBetweenEndpoints()
{
    using thoth::game::Command;
    using thoth::game::Direction;
    using thoth::game::ItemId;
    using thoth::game::MachineKind;
    using thoth::game::Tile;
    using thoth::game::TileId;

    thoth::game::Simulation sim(12);
    sim.world().setTile(1, 0, Tile{TileId::Floor, 0});
    sim.world().setTile(2, 0, Tile{TileId::Floor, 0});
    sim.world().setTile(3, 0, Tile{TileId::Floor, 0});

    require(sim.player().inventory.add(ItemId::Chest, 2), "test should add chests");
    require(sim.player().inventory.add(ItemId::Inserter, 1), "test should add inserter");

    sim.player().x = 0;
    sim.queue(Command::placeItem(Direction::East, ItemId::Chest));
    sim.step();
    sim.player().x = 1;
    sim.queue(Command::placeItem(Direction::East, ItemId::Inserter));
    sim.step();
    sim.player().x = 2;
    sim.queue(Command::placeItem(Direction::East, ItemId::Chest));
    sim.step();

    auto* source = sim.machineAt(1, 0);
    auto* target = sim.machineAt(3, 0);
    require(source != nullptr && source->kind == MachineKind::Chest, "source chest should exist");
    require(target != nullptr && target->kind == MachineKind::Chest, "target chest should exist");
    require(source->inventory.add(ItemId::Coal, 1), "test should add coal to source chest");

    for (int i = 0; i < 20; ++i) {
        sim.step();
    }

    require(source->inventory.count(ItemId::Coal) == 0, "inserter should remove item from source");
    require(target->inventory.count(ItemId::Coal) == 1, "inserter should deposit item into target");
}

void testUnfueledBurnerMinerStaysIdle()
{
    using thoth::game::Command;
    using thoth::game::Direction;
    using thoth::game::ItemId;
    using thoth::game::MachineKind;
    using thoth::game::Tile;
    using thoth::game::TileId;

    thoth::game::Simulation sim(13);
    sim.world().setTile(1, 0, Tile{TileId::IronOre, 1});
    sim.world().setTile(2, 0, Tile{TileId::Floor, 0});

    require(sim.player().inventory.add(ItemId::BurnerMiner, 1), "test should add burner miner");
    require(sim.player().inventory.add(ItemId::Belt, 1), "test should add belt");
    sim.queue(Command::placeItem(Direction::East, ItemId::BurnerMiner));
    sim.step();
    sim.player().x = 1;
    sim.queue(Command::placeItem(Direction::East, ItemId::Belt));
    sim.step();

    for (int i = 0; i < 40; ++i) {
        sim.step();
    }

    const auto* miner = sim.machineAt(1, 0);
    const auto* belt = sim.machineAt(2, 0);
    require(miner != nullptr && miner->kind == MachineKind::BurnerMiner, "unfueled miner should exist");
    require(belt != nullptr && belt->kind == MachineKind::Belt, "output belt should exist");
    require(miner->progress == 0, "unfueled miner should not progress");
    require(miner->status == thoth::game::MachineStatus::MissingFuel, "unfueled miner should report missing fuel");
    require(belt->carriedItem == ItemId::None, "unfueled miner should not output ore");
}

void testDepositSelectedItemIntoMachine()
{
    using thoth::game::Command;
    using thoth::game::Direction;
    using thoth::game::ItemId;
    using thoth::game::MachineKind;
    using thoth::game::Tile;
    using thoth::game::TileId;

    thoth::game::Simulation sim(14);
    sim.world().setTile(1, 0, Tile{TileId::Floor, 0});

    require(sim.player().inventory.add(ItemId::Furnace, 1), "test should add furnace");
    sim.queue(Command::placeItem(Direction::East, ItemId::Furnace));
    sim.step();

    require(sim.player().inventory.add(ItemId::Coal, 1), "test should add coal");
    sim.player().hotbar[0] = ItemId::Coal;
    sim.player().selectedHotbar = 0;
    sim.queue(Command::depositSelected(Direction::East));
    sim.step();

    const auto* furnace = sim.machineAt(1, 0);
    require(furnace != nullptr && furnace->kind == MachineKind::Furnace, "furnace should exist");
    require(furnace->inventory.count(ItemId::Coal) == 1, "deposit should put selected coal into furnace");
    require(sim.itemCount(ItemId::Coal) == 0, "deposit should consume one selected coal from player");
}

void testExplicitDepositAndWithdrawItemCommands()
{
    using thoth::game::Command;
    using thoth::game::Direction;
    using thoth::game::ItemId;
    using thoth::game::MachineKind;
    using thoth::game::Tile;
    using thoth::game::TileId;

    thoth::game::Simulation sim(33);
    sim.world().setTile(1, 0, Tile{TileId::Floor, 0});
    sim.world().setTile(0, 1, Tile{TileId::Floor, 0});

    require(sim.player().inventory.add(ItemId::Furnace, 1), "test should add furnace");
    require(sim.player().inventory.add(ItemId::Chest, 1), "test should add chest");
    sim.queue(Command::placeItem(Direction::East, ItemId::Furnace));
    sim.step();
    sim.queue(Command::placeItem(Direction::South, ItemId::Chest));
    sim.step();

    require(sim.player().inventory.add(ItemId::Coal, 1), "test should add coal");
    require(sim.player().inventory.add(ItemId::Wood, 1), "test should add wood");
    sim.player().hotbar[0] = ItemId::Stone;
    sim.player().selectedHotbar = 0;

    sim.queue(Command::depositItem(Direction::East, ItemId::Coal));
    sim.step();
    const auto* furnace = sim.machineAt(1, 0);
    require(furnace != nullptr && furnace->kind == MachineKind::Furnace, "furnace should exist");
    require(furnace->inventory.count(ItemId::Coal) == 1, "explicit deposit should not depend on selected hotbar item");
    require(sim.itemCount(ItemId::Coal) == 0, "explicit deposit should consume deposited item");

    sim.queue(Command::depositItem(Direction::East, ItemId::Wood));
    sim.step();
    furnace = sim.machineAt(1, 0);
    require(furnace != nullptr, "furnace should still exist after rejected deposit");
    require(furnace->inventory.count(ItemId::Wood) == 0, "furnace should reject non-input wood");
    require(sim.itemCount(ItemId::Wood) == 1, "rejected explicit deposit should not consume item");

    auto* chest = sim.machineAt(0, 1);
    require(chest != nullptr && chest->kind == MachineKind::Chest, "chest should exist");
    require(chest->inventory.add(ItemId::IronPlate, 2), "test should add plates to chest");
    sim.queue(Command::withdrawItem(Direction::South, ItemId::IronPlate));
    sim.step();
    require(sim.itemCount(ItemId::IronPlate) == 1, "withdraw should add item to player inventory");
    require(chest->inventory.count(ItemId::IronPlate) == 1, "withdraw should remove one item from chest");
}

void testQueuedBatchDepositAndWithdrawCommands()
{
    using thoth::game::Command;
    using thoth::game::Direction;
    using thoth::game::ItemId;
    using thoth::game::MachineKind;
    using thoth::game::Tile;
    using thoth::game::TileId;

    thoth::game::Simulation sim(35);
    sim.world().setTile(1, 0, Tile{TileId::Floor, 0});

    require(sim.player().inventory.add(ItemId::Chest, 1), "test should add chest");
    sim.queue(Command::placeItem(Direction::East, ItemId::Chest));
    sim.step();

    require(sim.player().inventory.add(ItemId::Coal, 5), "test should add batch coal");
    for (int i = 0; i < 5; ++i) {
        sim.queue(Command::depositItem(Direction::East, ItemId::Coal));
    }
    sim.step();

    auto* chest = sim.machineAt(1, 0);
    require(chest != nullptr && chest->kind == MachineKind::Chest, "batch target chest should exist");
    require(chest->inventory.count(ItemId::Coal) == 5, "queued deposits should move every available item");
    require(sim.itemCount(ItemId::Coal) == 0, "queued deposits should consume the deposited batch from player");

    for (int i = 0; i < 3; ++i) {
        sim.queue(Command::withdrawItem(Direction::East, ItemId::Coal));
    }
    sim.step();

    chest = sim.machineAt(1, 0);
    require(chest != nullptr, "batch target chest should still exist");
    require(chest->inventory.count(ItemId::Coal) == 2, "queued withdraws should remove the requested batch");
    require(sim.itemCount(ItemId::Coal) == 3, "queued withdraws should add the requested batch to player");
}

void testWithdrawMachineOutputWithoutTakingInputs()
{
    using thoth::game::Command;
    using thoth::game::Direction;
    using thoth::game::ItemId;
    using thoth::game::MachineKind;
    using thoth::game::Tile;
    using thoth::game::TileId;

    thoth::game::Simulation sim(34);
    sim.world().setTile(1, 0, Tile{TileId::Floor, 0});
    require(sim.player().inventory.add(ItemId::Furnace, 1), "test should add furnace");
    sim.queue(Command::placeItem(Direction::East, ItemId::Furnace));
    sim.step();

    auto* furnace = sim.machineAt(1, 0);
    require(furnace != nullptr && furnace->kind == MachineKind::Furnace, "furnace should exist");
    require(furnace->inventory.add(ItemId::IronOre, 1), "test should add furnace input");
    furnace->outputItem = ItemId::IronPlate;

    sim.queue(Command::withdrawItem(Direction::East, ItemId::IronOre));
    sim.step();
    furnace = sim.machineAt(1, 0);
    require(furnace != nullptr, "furnace should still exist after input withdraw");
    require(sim.itemCount(ItemId::IronOre) == 1, "explicit withdraw should allow player to recover machine inputs");
    require(furnace->inventory.count(ItemId::IronOre) == 0, "input withdraw should remove requested input");
    require(furnace->outputItem == ItemId::IronPlate, "withdrawing input should not disturb output slot");

    sim.queue(Command::withdrawItem(Direction::East, ItemId::IronPlate));
    sim.step();
    furnace = sim.machineAt(1, 0);
    require(furnace != nullptr, "furnace should still exist after output withdraw");
    require(sim.itemCount(ItemId::IronPlate) == 1, "withdraw should add output item to player inventory");
    require(furnace->outputItem == ItemId::None, "withdraw should clear requested output slot");
}

void testFurnaceBlockedOutputSurvivesSaveLoad()
{
    using thoth::game::Command;
    using thoth::game::Direction;
    using thoth::game::ItemId;
    using thoth::game::MachineKind;
    using thoth::game::MachineStatus;
    using thoth::game::Tile;
    using thoth::game::TileId;

    thoth::game::Simulation sim(15);
    sim.world().setTile(1, 0, Tile{TileId::Floor, 0});
    require(sim.player().inventory.add(ItemId::Furnace, 1), "test should add furnace");
    sim.queue(Command::placeItem(Direction::East, ItemId::Furnace));
    sim.step();

    auto* furnace = sim.machineAt(1, 0);
    require(furnace != nullptr && furnace->kind == MachineKind::Furnace, "furnace should be placed");
    require(furnace->inventory.add(ItemId::Coal, 1), "test should add furnace fuel");
    require(furnace->inventory.add(ItemId::IronOre, 1), "test should add furnace input");

    for (int i = 0; i < 35; ++i) {
        sim.step();
    }

    require(furnace->progress == 0, "blocked furnace should finish the craft");
    require(furnace->outputItem == ItemId::IronPlate, "blocked furnace should retain plate in output slot");
    require(furnace->status == MachineStatus::OutputBlocked, "blocked furnace should report output blockage");

    const auto path = std::filesystem::temp_directory_path() / "thoth_furnace_output_roundtrip.txt";
    std::string error;
    require(thoth::game::saveSimulation(sim, path, &error), "furnace output save should succeed: " + error);
    auto loaded = thoth::game::loadSimulation(path, &error);
    require(loaded.has_value(), "furnace output load should succeed: " + error);
    std::filesystem::remove(path);

    const auto* loadedFurnace = loaded->machineAt(1, 0);
    require(loadedFurnace != nullptr, "loaded furnace should exist");
    require(loadedFurnace->outputItem == ItemId::IronPlate, "loaded furnace output slot should match");
    require(loadedFurnace->fuelTicks == furnace->fuelTicks, "loaded furnace fuel should match");
}

void testCopperMiningAndSmeltingChain()
{
    using thoth::game::Direction;
    using thoth::game::ItemId;
    using thoth::game::MachineKind;
    using thoth::game::Tile;
    using thoth::game::TileId;

    thoth::game::Simulation minerSim(35);
    placeMachineAtOnTile(minerSim, ItemId::BurnerMiner, 1, 0, Direction::East, Tile{TileId::CopperOre, 1});
    placeMachineAt(minerSim, ItemId::Chest, 2, 0, Direction::East);
    auto* miner = minerSim.machineAt(1, 0);
    require(miner != nullptr && miner->kind == MachineKind::BurnerMiner, "copper burner miner should be placed");
    require(miner->inventory.add(ItemId::Coal, 1), "test should fuel copper miner");
    for (int i = 0; i < 15; ++i) {
        minerSim.step();
    }
    const auto* oreChest = minerSim.machineAt(2, 0);
    require(oreChest != nullptr && oreChest->inventory.count(ItemId::CopperOre) >= 1, "copper miner should output copper ore");

    thoth::game::Simulation furnaceSim(36);
    placeMachineAt(furnaceSim, ItemId::Furnace, 1, 0, Direction::East);
    placeMachineAt(furnaceSim, ItemId::Chest, 2, 0, Direction::East);
    auto* furnace = furnaceSim.machineAt(1, 0);
    require(furnace != nullptr && furnace->kind == MachineKind::Furnace, "copper furnace should be placed");
    require(furnace->inventory.add(ItemId::CopperOre, 1), "test should add copper ore to furnace");
    require(furnace->inventory.add(ItemId::Coal, 1), "test should add copper furnace fuel");

    furnaceSim.step();
    furnace = furnaceSim.machineAt(1, 0);
    require(furnace != nullptr && furnace->recipeKey == "copper_plate", "furnace should remember active copper recipe");

    const auto path = std::filesystem::temp_directory_path() / "thoth_copper_furnace_roundtrip.txt";
    std::string error;
    require(thoth::game::saveSimulation(furnaceSim, path, &error), "copper furnace save should succeed: " + error);
    auto loaded = thoth::game::loadSimulation(path, &error);
    require(loaded.has_value(), "copper furnace load should succeed: " + error);
    std::filesystem::remove(path);

    const auto* loadedFurnace = loaded->machineAt(1, 0);
    require(loadedFurnace != nullptr && loadedFurnace->recipeKey == "copper_plate", "loaded furnace should preserve copper recipe");
    for (int i = 0; i < 40; ++i) {
        loaded->step();
    }
    const auto* plateChest = loaded->machineAt(2, 0);
    require(plateChest != nullptr && plateChest->inventory.count(ItemId::CopperPlate) == 1, "loaded furnace should finish copper plate output");
}

void testFurnaceRecipeConfigurationPersists()
{
    using thoth::game::Command;
    using thoth::game::Direction;
    using thoth::game::ItemId;
    using thoth::game::MachineKind;

    thoth::game::Simulation sim(39);
    placeMachineAt(sim, ItemId::Furnace, 1, 0, Direction::East);
    placeMachineAt(sim, ItemId::Chest, 2, 0, Direction::East);
    sim.player().x = 0;
    sim.player().y = 0;

    sim.queue(Command::configureMachineRecipe(Direction::East, "copper_plate"));
    sim.step();

    auto* furnace = sim.machineAt(1, 0);
    require(furnace != nullptr && furnace->kind == MachineKind::Furnace, "configured furnace should exist");
    require(furnace->recipeKey == "copper_plate", "configure command should assign furnace recipe");
    require(furnace->recipeLocked, "configured furnace recipe should be locked");

    require(sim.player().inventory.add(ItemId::IronOre, 1), "test should add rejected iron ore");
    sim.queue(Command::depositItem(Direction::East, ItemId::IronOre));
    sim.step();
    furnace = sim.machineAt(1, 0);
    require(furnace != nullptr, "furnace should exist after rejected locked-recipe input");
    require(furnace->inventory.count(ItemId::IronOre) == 0, "locked copper furnace should reject iron ore");
    require(sim.itemCount(ItemId::IronOre) == 1, "rejected locked-recipe deposit should not consume player ore");

    require(sim.player().inventory.add(ItemId::CopperOre, 1), "test should add copper ore");
    require(sim.player().inventory.add(ItemId::Coal, 1), "test should add furnace fuel");
    sim.queue(Command::depositItem(Direction::East, ItemId::CopperOre));
    sim.queue(Command::depositItem(Direction::East, ItemId::Coal));
    sim.step();

    for (int i = 0; i < 40; ++i) {
        sim.step();
    }

    furnace = sim.machineAt(1, 0);
    const auto* chest = sim.machineAt(2, 0);
    require(chest != nullptr && chest->inventory.count(ItemId::CopperPlate) == 1, "configured furnace should output copper plate");
    require(furnace != nullptr && furnace->recipeKey == "copper_plate", "configured furnace should keep recipe after output");
    require(furnace->recipeLocked, "configured furnace should keep recipe lock after output");

    const auto path = std::filesystem::temp_directory_path() / "thoth_configured_furnace_roundtrip.txt";
    std::string error;
    require(thoth::game::saveSimulation(sim, path, &error), "configured furnace save should succeed: " + error);
    auto loaded = thoth::game::loadSimulation(path, &error);
    require(loaded.has_value(), "configured furnace load should succeed: " + error);
    std::filesystem::remove(path);

    const auto* loadedFurnace = loaded->machineAt(1, 0);
    require(loadedFurnace != nullptr && loadedFurnace->recipeKey == "copper_plate", "loaded configured furnace should preserve recipe");
    require(loadedFurnace != nullptr && loadedFurnace->recipeLocked, "loaded configured furnace should preserve recipe lock");
}

void testFiniteResourceTilesDepleteThroughMiners()
{
    using thoth::game::Direction;
    using thoth::game::ItemId;
    using thoth::game::MachineKind;
    using thoth::game::MachineStatus;
    using thoth::game::Tile;
    using thoth::game::TileId;

    thoth::game::Simulation sim(37);
    placeMachineAtOnTile(sim, ItemId::BurnerMiner, 1, 0, Direction::East, Tile{TileId::IronOre, 2});
    placeMachineAt(sim, ItemId::Chest, 2, 0, Direction::East);
    auto* miner = sim.machineAt(1, 0);
    require(miner != nullptr && miner->kind == MachineKind::BurnerMiner, "finite resource miner should be placed");
    require(miner->inventory.add(ItemId::Coal, 1), "test should fuel finite resource miner");

    for (int i = 0; i < 12; ++i) {
        sim.step();
    }

    auto tile = sim.world().getTile(1, 0);
    const auto* chest = sim.machineAt(2, 0);
    require(chest != nullptr && chest->inventory.count(ItemId::IronOre) == 1, "finite miner should output first ore");
    require(tile.id == TileId::IronOre && tile.data == 1, "finite resource tile should lose one richness");

    const auto path = std::filesystem::temp_directory_path() / "thoth_finite_resource_roundtrip.txt";
    std::string error;
    require(thoth::game::saveSimulation(sim, path, &error), "finite resource save should succeed: " + error);
    auto loaded = thoth::game::loadSimulation(path, &error);
    require(loaded.has_value(), "finite resource load should succeed: " + error);
    std::filesystem::remove(path);
    require(loaded->world().getTile(1, 0).id == TileId::IronOre, "loaded finite resource should keep tile id");
    require(loaded->world().getTile(1, 0).data == 1, "loaded finite resource should keep remaining richness");

    for (int i = 0; i < 12; ++i) {
        loaded->step();
    }

    tile = loaded->world().getTile(1, 0);
    chest = loaded->machineAt(2, 0);
    const auto* loadedMiner = loaded->machineAt(1, 0);
    require(chest != nullptr && chest->inventory.count(ItemId::IronOre) == 2, "finite miner should output final ore");
    require(tile.id == TileId::Floor && tile.data == 0, "finite resource tile should become floor when depleted");
    require(loadedMiner != nullptr && loadedMiner->status == MachineStatus::MissingInput, "depleted miner should report missing input");

    for (int i = 0; i < 12; ++i) {
        loaded->step();
    }
    chest = loaded->machineAt(2, 0);
    require(chest != nullptr && chest->inventory.count(ItemId::IronOre) == 2, "depleted resource should not output extra ore");

    thoth::game::Simulation blocked(38);
    placeMachineAtOnTile(blocked, ItemId::BurnerMiner, 1, 0, Direction::East, Tile{TileId::CopperOre, 2});
    auto* blockedMiner = blocked.machineAt(1, 0);
    require(blockedMiner != nullptr && blockedMiner->inventory.add(ItemId::Coal, 1), "test should fuel blocked miner");
    for (int i = 0; i < 12; ++i) {
        blocked.step();
    }
    require(blocked.world().getTile(1, 0).data == 2, "blocked miner should not deplete resource before output");
    require(blockedMiner->status == MachineStatus::OutputBlocked, "blocked miner should report output blockage");
}

void testInserterDoesNotExtractFurnaceInputs()
{
    using thoth::game::Command;
    using thoth::game::Direction;
    using thoth::game::ItemId;
    using thoth::game::MachineKind;
    using thoth::game::MachineStatus;
    using thoth::game::Tile;
    using thoth::game::TileId;

    thoth::game::Simulation sim(16);
    sim.world().setTile(1, 0, Tile{TileId::Floor, 0});
    sim.world().setTile(2, 0, Tile{TileId::Floor, 0});
    sim.world().setTile(3, 0, Tile{TileId::Floor, 0});
    require(sim.player().inventory.add(ItemId::Furnace, 1), "test should add furnace");
    require(sim.player().inventory.add(ItemId::Inserter, 1), "test should add inserter");
    require(sim.player().inventory.add(ItemId::Chest, 1), "test should add chest");

    sim.queue(Command::placeItem(Direction::East, ItemId::Furnace));
    sim.step();
    sim.player().x = 1;
    sim.queue(Command::placeItem(Direction::East, ItemId::Inserter));
    sim.step();
    sim.player().x = 2;
    sim.queue(Command::placeItem(Direction::East, ItemId::Chest));
    sim.step();

    auto* furnace = sim.machineAt(1, 0);
    auto* inserter = sim.machineAt(2, 0);
    auto* chest = sim.machineAt(3, 0);
    require(furnace != nullptr && furnace->kind == MachineKind::Furnace, "furnace should exist");
    require(inserter != nullptr && inserter->kind == MachineKind::Inserter, "inserter should exist");
    require(chest != nullptr && chest->kind == MachineKind::Chest, "chest should exist");
    require(furnace->inventory.add(ItemId::IronOre, 1), "test should add furnace input");

    for (int i = 0; i < 20; ++i) {
        sim.step();
    }

    require(furnace->inventory.count(ItemId::IronOre) == 1, "inserter should not remove furnace input");
    require(chest->inventory.count(ItemId::IronOre) == 0, "inserter should not move furnace input to chest");
    require(inserter->status == MachineStatus::MissingInput, "inserter should report no extractable furnace output");

    furnace->outputItem = ItemId::IronPlate;
    for (int i = 0; i < 20; ++i) {
        sim.step();
    }

    require(furnace->outputItem == ItemId::None, "inserter should remove furnace output");
    require(chest->inventory.count(ItemId::IronPlate) == 1, "inserter should move furnace output to chest");
    require(furnace->inventory.count(ItemId::IronOre) == 1, "furnace input should remain separate from output");
}

void testResearchLocksFastBeltRecipe()
{
    using thoth::game::Command;
    using thoth::game::ItemId;

    thoth::game::Simulation sim(25);
    require(!sim.isRecipeUnlocked("fast_belt"), "fast belt recipe should start locked");
    require(sim.player().inventory.add(ItemId::Belt, 1), "test should add belt input");
    require(sim.player().inventory.add(ItemId::IronPlate, 1), "test should add plate input");

    sim.queue(Command::craft("fast_belt"));
    sim.step();

    require(sim.itemCount(ItemId::FastBelt) == 0, "locked fast belt recipe should not craft");
    require(sim.itemCount(ItemId::Belt) == 1, "locked recipe should not consume belt input");
    require(sim.itemCount(ItemId::IronPlate) == 1, "locked recipe should not consume plate input");
}

void testAssemblerCraftsSciencePackThroughAutomation()
{
    using thoth::game::Direction;
    using thoth::game::ItemId;
    using thoth::game::MachineKind;

    thoth::game::Simulation sim(26);
    placeMachineAt(sim, ItemId::Assembler, 1, 0, Direction::East);
    placeMachineAt(sim, ItemId::Chest, 2, 0, Direction::East);

    auto* assembler = sim.machineAt(1, 0);
    require(assembler != nullptr && assembler->kind == MachineKind::Assembler, "assembler should be placed");
    require(assembler->inventory.add(ItemId::IronPlate, 1), "test should add assembler iron plate input");
    require(assembler->inventory.add(ItemId::CopperPlate, 1), "test should add assembler copper plate input");

    for (int i = 0; i < 60; ++i) {
        sim.step();
    }

    const auto* chest = sim.machineAt(2, 0);
    require(chest != nullptr && chest->kind == MachineKind::Chest, "science output chest should exist");
    require(chest->inventory.count(ItemId::SciencePack) == 1, "assembler should craft and output a science pack");
    require(assembler->inventory.count(ItemId::IronPlate) == 0, "assembler should consume iron plate input");
    require(assembler->inventory.count(ItemId::CopperPlate) == 0, "assembler should consume copper plate input");
}

void testAssemblerRecipeConfigurationPersists()
{
    using thoth::game::Command;
    using thoth::game::Direction;
    using thoth::game::ItemId;
    using thoth::game::MachineKind;

    thoth::game::Simulation sim(34);
    placeMachineAt(sim, ItemId::Assembler, 1, 0, Direction::East);
    placeMachineAt(sim, ItemId::Chest, 2, 0, Direction::East);

    auto* assembler = sim.machineAt(1, 0);
    require(assembler != nullptr && assembler->kind == MachineKind::Assembler, "configurable assembler should be placed");
    require(assembler->recipeKey == "science_pack", "placed assembler should default to science pack recipe");
    assembler->recipeKey.clear();

    sim.player().x = 0;
    sim.player().y = 0;
    sim.queue(Command::configureMachineRecipe(Direction::East, "science_pack"));
    sim.step();
    assembler = sim.machineAt(1, 0);
    require(assembler != nullptr && assembler->recipeKey == "science_pack", "configure command should assign assembler recipe");

    sim.queue(Command::configureMachineRecipe(Direction::East, "fast_belt"));
    sim.step();
    assembler = sim.machineAt(1, 0);
    require(assembler != nullptr && assembler->recipeKey == "science_pack", "assembler should reject non-assembler recipe");

    require(assembler->inventory.add(ItemId::IronPlate, 1), "test should add configured assembler iron plate input");
    require(assembler->inventory.add(ItemId::CopperPlate, 1), "test should add configured assembler copper plate input");
    for (int i = 0; i < 60; ++i) {
        sim.step();
    }
    const auto* chest = sim.machineAt(2, 0);
    require(chest != nullptr && chest->inventory.count(ItemId::SciencePack) == 1, "configured assembler should craft science output");

    const auto path = std::filesystem::temp_directory_path() / "thoth_assembler_recipe_roundtrip.txt";
    std::string error;
    require(thoth::game::saveSimulation(sim, path, &error), "assembler recipe save should succeed: " + error);
    auto loaded = thoth::game::loadSimulation(path, &error);
    require(loaded.has_value(), "assembler recipe load should succeed: " + error);
    std::filesystem::remove(path);

    const auto* loadedAssembler = loaded->machineAt(1, 0);
    require(loadedAssembler != nullptr && loadedAssembler->recipeKey == "science_pack", "loaded assembler should preserve recipe key");
}

void testLabResearchUnlocksRecipeAndPersists()
{
    using thoth::game::Command;
    using thoth::game::Direction;
    using thoth::game::ItemId;
    using thoth::game::MachineKind;

    thoth::game::Simulation sim(27);
    placeMachineAt(sim, ItemId::Lab, 1, 0, Direction::East);
    auto* lab = sim.machineAt(1, 0);
    require(lab != nullptr && lab->kind == MachineKind::Lab, "lab should be placed");
    require(lab->inventory.add(ItemId::SciencePack, 3), "test should add lab science packs");

    for (int i = 0; i < 25; ++i) {
        sim.step();
    }
    require(sim.researchProgress() == 1, "lab should advance one research unit");
    require(!sim.isRecipeUnlocked("fast_belt"), "partial research should not unlock recipe");

    const auto path = std::filesystem::temp_directory_path() / "thoth_research_roundtrip.txt";
    std::string error;
    require(thoth::game::saveSimulation(sim, path, &error), "research save should succeed: " + error);
    auto loaded = thoth::game::loadSimulation(path, &error);
    require(loaded.has_value(), "research load should succeed: " + error);
    std::filesystem::remove(path);

    require(loaded->researchProgress() == 1, "loaded research progress should match");
    require(!loaded->isRecipeUnlocked("fast_belt"), "loaded partial research should remain locked");

    for (int i = 0; i < 50; ++i) {
        loaded->step();
    }

    require(loaded->isTechCompleted("logistics_1"), "loaded lab should complete logistics research");
    require(loaded->isRecipeUnlocked("fast_belt"), "completed research should unlock fast belt recipe");
    require(loaded->isRecipeUnlocked("generator"), "completed research should unlock generator recipe");
    require(loaded->isRecipeUnlocked("power_pole"), "completed research should unlock power pole recipe");
    require(loaded->isRecipeUnlocked("electric_miner"), "completed research should unlock electric miner recipe");

    placeMachineAt(*loaded, ItemId::Workbench, 0, 1, Direction::South);
    require(loaded->player().inventory.add(ItemId::Belt, 1), "test should add fast belt belt input");
    require(loaded->player().inventory.add(ItemId::IronPlate, 1), "test should add fast belt plate input");
    loaded->queue(Command::craft("fast_belt"));
    loaded->step();
    require(loaded->itemCount(ItemId::FastBelt) == 1, "unlocked fast belt recipe should craft");

    const int generatorStoneBefore = loaded->itemCount(ItemId::Stone);
    const int generatorIronBefore = loaded->itemCount(ItemId::IronPlate);
    require(loaded->player().inventory.add(ItemId::Stone, 4), "test should add generator stone input");
    require(loaded->player().inventory.add(ItemId::IronPlate, 2), "test should add generator iron input");
    loaded->queue(Command::craft("generator"));
    loaded->step();
    require(loaded->itemCount(ItemId::Generator) == 0, "generator should require copper plate after research");
    require(loaded->itemCount(ItemId::Stone) == generatorStoneBefore + 4, "blocked generator craft should preserve stone");
    require(loaded->itemCount(ItemId::IronPlate) == generatorIronBefore + 2, "blocked generator craft should preserve iron plates");
    require(loaded->player().inventory.add(ItemId::CopperPlate, 1), "test should add generator copper input");
    loaded->queue(Command::craft("generator"));
    loaded->step();
    require(loaded->itemCount(ItemId::Generator) == 1, "generator should craft with iron and copper plates");
    require(loaded->itemCount(ItemId::Stone) == generatorStoneBefore, "generator craft should consume stone input");
    require(loaded->itemCount(ItemId::IronPlate) == generatorIronBefore, "generator craft should consume iron input");

    const int powerPoleWoodBefore = loaded->itemCount(ItemId::Wood);
    require(loaded->player().inventory.add(ItemId::Wood, 2), "test should add power pole wood input");
    loaded->queue(Command::craft("power_pole"));
    loaded->step();
    require(loaded->itemCount(ItemId::PowerPole) == 0, "power pole should require copper plate after research");
    require(loaded->itemCount(ItemId::Wood) == powerPoleWoodBefore + 2, "blocked power pole craft should preserve wood");
    require(loaded->player().inventory.add(ItemId::CopperPlate, 1), "test should add power pole copper input");
    loaded->queue(Command::craft("power_pole"));
    loaded->step();
    require(loaded->itemCount(ItemId::PowerPole) == 2, "power pole recipe should craft two poles with copper");
    require(loaded->itemCount(ItemId::Wood) == powerPoleWoodBefore, "power pole craft should consume wood input");

    const int electricMinerStoneBefore = loaded->itemCount(ItemId::Stone);
    const int electricMinerIronBefore = loaded->itemCount(ItemId::IronPlate);
    require(loaded->player().inventory.add(ItemId::Stone, 4), "test should add electric miner stone input");
    require(loaded->player().inventory.add(ItemId::IronPlate, 3), "test should add electric miner iron input");
    loaded->queue(Command::craft("electric_miner"));
    loaded->step();
    require(loaded->itemCount(ItemId::ElectricMiner) == 0, "electric miner should require copper plate after research");
    require(loaded->itemCount(ItemId::Stone) == electricMinerStoneBefore + 4, "blocked electric miner craft should preserve stone");
    require(loaded->itemCount(ItemId::IronPlate) == electricMinerIronBefore + 3, "blocked electric miner craft should preserve iron plates");
    require(loaded->player().inventory.add(ItemId::CopperPlate, 1), "test should add electric miner copper input");
    loaded->queue(Command::craft("electric_miner"));
    loaded->step();
    require(loaded->itemCount(ItemId::ElectricMiner) == 1, "electric miner should craft with iron and copper plates");
    require(loaded->itemCount(ItemId::Stone) == electricMinerStoneBefore, "electric miner craft should consume stone input");
    require(loaded->itemCount(ItemId::IronPlate) == electricMinerIronBefore, "electric miner craft should consume iron input");
}

void testFastBeltsMoveItemsFaster()
{
    using thoth::game::Direction;
    using thoth::game::ItemId;
    using thoth::game::MachineKind;

    thoth::game::Simulation sim(28);
    placeMachineAt(sim, ItemId::FastBelt, 1, 0, Direction::East);
    placeMachineAt(sim, ItemId::FastBelt, 2, 0, Direction::East);
    placeMachineAt(sim, ItemId::Chest, 3, 0, Direction::East);

    auto* first = sim.machineAt(1, 0);
    const auto* second = sim.machineAt(2, 0);
    require(first != nullptr && first->kind == MachineKind::FastBelt, "first fast belt should exist");
    require(second != nullptr && second->kind == MachineKind::FastBelt, "second fast belt should exist");

    first->carriedItem = ItemId::Coal;
    sim.step();

    const auto* chest = sim.machineAt(3, 0);
    require(chest != nullptr && chest->kind == MachineKind::Chest, "fast belt chest should exist");
    require(chest->inventory.count(ItemId::Coal) == 1, "two fast belts should deliver an item in one tick");
}

void testPowerPoleNetworkGroupingAndSupplyDemand()
{
    using thoth::game::Direction;
    using thoth::game::ItemId;
    using thoth::game::MachineKind;
    using thoth::game::Tile;
    using thoth::game::TileId;

    thoth::game::Simulation sim(29);
    placeMachineAt(sim, ItemId::Generator, 0, 1, Direction::South);
    placeMachineAt(sim, ItemId::PowerPole, 0, 0, Direction::East);
    placeMachineAt(sim, ItemId::PowerPole, 4, 0, Direction::East);
    placeMachineAtOnTile(
        sim,
        ItemId::ElectricMiner,
        4,
        1,
        Direction::East,
        Tile{TileId::IronOre, 1});

    auto* generator = sim.machineAt(0, 1);
    auto* miner = sim.machineAt(4, 1);
    require(generator != nullptr && generator->kind == MachineKind::Generator, "generator should be placed");
    require(miner != nullptr && miner->kind == MachineKind::ElectricMiner, "electric miner should be placed");
    require(generator->inventory.add(ItemId::Coal, 1), "test should fuel generator");

    sim.step();

    const auto& networks = sim.powerNetworks();
    require(networks.size() == 1, "connected poles should form one power network");
    require(networks.front().poleIds.size() == 2, "network should include both connected poles");
    require(networks.front().generatorIds.size() == 1, "network should include connected generator");
    require(networks.front().consumerIds.size() == 1, "network should include connected electric miner");
    require(networks.front().supply == 2, "one fueled generator should supply two power");
    require(networks.front().demand == 1, "one electric miner should demand one power");
    require(networks.front().powered, "sufficient network should be powered");
    require(sim.isMachinePowered(miner->id), "connected electric miner should be marked powered");
    require(miner->progress == 1, "powered electric miner should advance");
}

void testElectricMinerRequiresPowerAndProducesOre()
{
    using thoth::game::Direction;
    using thoth::game::ItemId;
    using thoth::game::MachineKind;
    using thoth::game::MachineStatus;
    using thoth::game::Tile;
    using thoth::game::TileId;

    thoth::game::Simulation sim(30);
    placeMachineAtOnTile(
        sim,
        ItemId::ElectricMiner,
        1,
        0,
        Direction::East,
        Tile{TileId::IronOre, 1});
    placeMachineAt(sim, ItemId::Chest, 2, 0, Direction::East);

    for (int i = 0; i < 5; ++i) {
        sim.step();
    }

    auto* miner = sim.machineAt(1, 0);
    auto* chest = sim.machineAt(2, 0);
    require(miner != nullptr && miner->kind == MachineKind::ElectricMiner, "electric miner should exist");
    require(chest != nullptr && chest->kind == MachineKind::Chest, "electric miner output chest should exist");
    require(miner->progress == 0, "unpowered electric miner should not progress");
    require(miner->status == MachineStatus::MissingPower, "unpowered electric miner should report missing power");
    require(chest->inventory.count(ItemId::IronOre) == 0, "unpowered electric miner should not output ore");

    placeMachineAt(sim, ItemId::Generator, 0, 1, Direction::South);
    placeMachineAt(sim, ItemId::PowerPole, 1, 1, Direction::East);
    auto* generator = sim.machineAt(0, 1);
    require(generator != nullptr && generator->inventory.add(ItemId::Coal, 1), "test should fuel generator");

    for (int i = 0; i < 10; ++i) {
        sim.step();
    }

    chest = sim.machineAt(2, 0);
    require(chest != nullptr, "electric miner output chest should remain after power setup");
    require(chest->inventory.count(ItemId::IronOre) == 1, "powered electric miner should produce one finite ore into chest");
    require(sim.world().getTile(1, 0).id == TileId::Floor, "electric miner should deplete one-richness ore tile");
}

void testUnderpoweredNetworkStopsElectricMachinesDeterministically()
{
    using thoth::game::Direction;
    using thoth::game::ItemId;
    using thoth::game::MachineKind;
    using thoth::game::MachineStatus;
    using thoth::game::Tile;
    using thoth::game::TileId;

    thoth::game::Simulation sim(31);
    placeMachineAt(sim, ItemId::Generator, 0, 1, Direction::South);
    placeMachineAt(sim, ItemId::PowerPole, 0, 0, Direction::East);
    placeMachineAtOnTile(sim, ItemId::ElectricMiner, -1, 0, Direction::West, Tile{TileId::IronOre, 1});
    placeMachineAtOnTile(sim, ItemId::ElectricMiner, 1, 0, Direction::East, Tile{TileId::IronOre, 1});
    placeMachineAtOnTile(sim, ItemId::ElectricMiner, 0, -1, Direction::North, Tile{TileId::IronOre, 1});
    auto* generator = sim.machineAt(0, 1);
    auto* first = sim.machineAt(-1, 0);
    auto* second = sim.machineAt(1, 0);
    auto* third = sim.machineAt(0, -1);
    require(generator != nullptr && generator->inventory.add(ItemId::Coal, 1), "test should fuel generator");
    require(first != nullptr && second != nullptr && third != nullptr, "underpowered electric miners should exist");

    sim.step();

    const auto& networks = sim.powerNetworks();
    require(networks.size() == 1, "underpowered setup should still form one network");
    require(networks.front().supply == 2, "underpowered network should report generator supply");
    require(networks.front().demand == 3, "underpowered network should report full demand");
    require(!networks.front().powered, "network with supply below demand should be unpowered");
    require(first->progress == 0 && second->progress == 0 && third->progress == 0, "underpowered consumers should not progress");
    require(first->status == MachineStatus::MissingPower, "first underpowered miner should report missing power");
    require(second->status == MachineStatus::MissingPower, "second underpowered miner should report missing power");
    require(third->status == MachineStatus::MissingPower, "third underpowered miner should report missing power");
}

void testGuardTowerRequiresPowerAndDefeatsHostile()
{
    using namespace thoth::game;

    Simulation sim(20260611);
    auto* generator = placeMachineAt(sim, ItemId::Generator, 0, 0, Direction::East);
    placeMachineAt(sim, ItemId::PowerPole, 1, 0, Direction::East);
    auto* tower = placeMachineAt(sim, ItemId::GuardTower, 2, 0, Direction::East);
    require(generator != nullptr && tower != nullptr, "guard tower test machines should place");

    auto snapshot = sim.snapshot();
    snapshot.player.x = 20;
    snapshot.player.y = 20;
    snapshot.nextEntityId = 2;
    snapshot.entities = {Entity{1, EntityKind::Slime, 5, 0, 0, 2, Direction::West, 0}};
    for (auto& machine : snapshot.machines) {
        if (machine.kind == MachineKind::Generator) {
            machine.fuelTicks = 200;
        }
    }
    sim.restore(snapshot);

    for (int i = 0; i < 45; ++i) {
        sim.step();
    }

    require(sim.entities().empty(), "powered guard tower should defeat hostile in range");
    require(sim.productionTotals().creaturesDefeated == 1, "tower defeat should increment creature total");
    const auto* restoredTower = sim.machineAt(2, 0);
    require(restoredTower != nullptr && restoredTower->kind == MachineKind::GuardTower, "guard tower should persist");
    require(restoredTower->status == MachineStatus::Working || restoredTower->status == MachineStatus::MissingInput,
        "guard tower should report a defense status after firing");
}

void testArcTowerHasLongerPoweredRange()
{
    using namespace thoth::game;

    Simulation sim(20260611);
    auto* generator = placeMachineAt(sim, ItemId::Generator, 0, 0, Direction::East);
    placeMachineAt(sim, ItemId::PowerPole, 1, 0, Direction::East);
    auto* tower = placeMachineAt(sim, ItemId::ArcTower, 2, 0, Direction::East);
    require(generator != nullptr && tower != nullptr, "arc tower test machines should place");

    auto snapshot = sim.snapshot();
    snapshot.player.x = 20;
    snapshot.player.y = 20;
    snapshot.nextEntityId = 2;
    snapshot.entities = {Entity{1, EntityKind::Slime, 9, 0, 0, 2, Direction::West, 0}};
    for (auto& machine : snapshot.machines) {
        if (machine.kind == MachineKind::Generator) {
            machine.fuelTicks = 200;
        }
    }
    sim.restore(snapshot);

    for (int i = 0; i < 30; ++i) {
        sim.step();
    }

    require(sim.entities().empty(), "powered arc tower should defeat hostile at range seven");
    require(sim.productionTotals().creaturesDefeated == 1, "arc tower defeat should increment creature total");
    const auto* restoredTower = sim.machineAt(2, 0);
    require(restoredTower != nullptr && restoredTower->kind == MachineKind::ArcTower, "arc tower should persist");
}

void testOutpostBeaconRequiresPowerAndBiomeInput()
{
    using namespace thoth::game;

    Simulation sim(20260611);
    auto* generator = placeMachineAt(sim, ItemId::Generator, 16, -2, Direction::East);
    placeMachineAt(sim, ItemId::PowerPole, 17, -2, Direction::East);
    auto* outpost = placeMachineAt(sim, ItemId::OutpostBeacon, 18, -2, Direction::East);
    require(generator != nullptr && outpost != nullptr, "outpost test machines should place");
    require(outpost->inventory.add(ItemId::SandGlass, 1), "test should seed desert outpost input");

    auto snapshot = sim.snapshot();
    for (auto& machine : snapshot.machines) {
        if (machine.kind == MachineKind::Generator) {
            machine.fuelTicks = 200;
        }
    }
    sim.restore(snapshot);

    for (int i = 0; i < 80; ++i) {
        sim.step();
    }

    const auto* restoredOutpost = sim.machineAt(18, -2);
    require(restoredOutpost != nullptr && restoredOutpost->kind == MachineKind::OutpostBeacon,
        "outpost beacon should persist");
    require(restoredOutpost->progress == 80, "powered outpost should finish activation");
    require(restoredOutpost->inventory.count(ItemId::SandGlass) == 0, "outpost should consume biome input");
    require(sim.productionTotals().outpostsActivated == 1, "outpost activation should increment production total");
    require(sim.hasActivatedOutpostBiome(BiomeKind::Desert), "outpost activation should track desert coverage");
    require(sim.activatedOutpostBiomeCount() == 1, "one unique outpost biome should be covered");
    require(sim.activatedOutpostBiomes().size() == 1, "activated outpost list should expose unique biomes");

    const auto path = std::filesystem::temp_directory_path() / "thoth_outpost_roundtrip.txt";
    std::string error;
    require(thoth::game::saveSimulation(sim, path, &error), "outpost save should succeed: " + error);
    auto loaded = thoth::game::loadSimulation(path, &error);
    std::filesystem::remove(path);
    require(loaded.has_value(), "outpost load should succeed: " + error);
    require(loaded->productionTotals().outpostsActivated == 1, "outpost activation should survive save/load");
    require(loaded->hasActivatedOutpostBiome(BiomeKind::Desert), "outpost biome coverage should survive save/load");
    const auto* loadedOutpost = loaded->machineAt(18, -2);
    require(loadedOutpost != nullptr && loadedOutpost->progress == 80, "activated outpost should survive save/load");
}

void testRepairPylonRebuildsAdjacentWallGap()
{
    using namespace thoth::game;

    Simulation sim(20260611);
    auto* generator = placeMachineAt(sim, ItemId::Generator, 0, 0, Direction::East);
    placeMachineAt(sim, ItemId::PowerPole, 1, 0, Direction::East);
    auto* pylon = placeMachineAt(sim, ItemId::RepairPylon, 2, 0, Direction::East);
    require(generator != nullptr && pylon != nullptr, "repair pylon test machines should place");
    require(pylon->inventory.add(ItemId::Wall, 1), "test should seed repair wall item");

    auto snapshot = sim.snapshot();
    snapshot.tiles.push_back(TileSnapshot{2, -1, Tile{TileId::Wall, 0}});
    snapshot.tiles.push_back(TileSnapshot{3, 0, Tile{TileId::Floor, 0}});
    snapshot.tiles.push_back(TileSnapshot{2, 1, Tile{TileId::Wall, 0}});
    for (auto& machine : snapshot.machines) {
        if (machine.kind == MachineKind::Generator) {
            machine.fuelTicks = 200;
        }
    }
    sim.restore(snapshot);

    for (int i = 0; i < 60; ++i) {
        sim.step();
    }

    const auto* restoredPylon = sim.machineAt(2, 0);
    require(restoredPylon != nullptr && restoredPylon->kind == MachineKind::RepairPylon,
        "repair pylon should persist");
    require(sim.world().getTile(3, 0).id == TileId::Wall, "repair pylon should rebuild adjacent wall gap");
    require(restoredPylon->inventory.count(ItemId::Wall) == 0, "repair pylon should consume wall item");
}

void testPressureRelayMitigatesFactoryPressure()
{
    using namespace thoth::game;

    Simulation sim(20260611);
    auto* generator = placeMachineAt(sim, ItemId::Generator, 0, 0, Direction::East);
    placeMachineAt(sim, ItemId::PowerPole, 1, 0, Direction::East);
    auto* relay = placeMachineAt(sim, ItemId::PressureRelay, 2, 0, Direction::East);
    require(generator != nullptr && relay != nullptr, "pressure relay test machines should place");
    require(relay->inventory.add(ItemId::AdvancedSciencePack, 1), "test should seed relay input");

    auto snapshot = sim.snapshot();
    snapshot.productionTotals.sciencePacks = 10;
    for (auto& machine : snapshot.machines) {
        if (machine.kind == MachineKind::Generator) {
            machine.fuelTicks = 200;
        }
    }
    sim.restore(snapshot);
    require(sim.factoryPressureLevel() >= 120, "test should start above raid pressure");

    for (int i = 0; i < 120; ++i) {
        sim.step();
    }

    const auto* restoredRelay = sim.machineAt(2, 0);
    require(restoredRelay != nullptr && restoredRelay->kind == MachineKind::PressureRelay,
        "pressure relay should persist");
    require(sim.productionTotals().pressureWavesRepelled == 1, "relay cycle should increment pressure mitigation");
    require(sim.factoryPressureLevel() < 120, "relay mitigation should lower pressure below raid threshold");
    require(sim.factoryPressureText().find("raids possible") == std::string::npos,
        "pressure text should reflect mitigation");
}

void testPowerNetworkRecomputesAfterSaveLoad()
{
    using thoth::game::Direction;
    using thoth::game::ItemId;
    using thoth::game::Tile;
    using thoth::game::TileId;

    thoth::game::Simulation sim(32);
    placeMachineAt(sim, ItemId::Generator, 0, 1, Direction::South);
    placeMachineAt(sim, ItemId::PowerPole, 1, 1, Direction::East);
    placeMachineAtOnTile(sim, ItemId::ElectricMiner, 1, 0, Direction::East, Tile{TileId::IronOre, 1});
    auto* generator = sim.machineAt(0, 1);
    auto* miner = sim.machineAt(1, 0);
    require(generator != nullptr && generator->inventory.add(ItemId::Coal, 1), "test should fuel generator");
    sim.step();
    require(sim.powerNetworks().size() == 1, "power network should exist before save");
    require(miner != nullptr && miner->progress == 1, "powered miner should progress before save");

    const auto path = std::filesystem::temp_directory_path() / "thoth_power_roundtrip.txt";
    std::string error;
    require(thoth::game::saveSimulation(sim, path, &error), "power save should succeed: " + error);
    auto loaded = thoth::game::loadSimulation(path, &error);
    require(loaded.has_value(), "power load should succeed: " + error);
    std::filesystem::remove(path);

    require(loaded->powerNetworks().empty(), "loaded power networks should be transient until recomputed");
    loaded->step();
    require(loaded->powerNetworks().size() == 1, "loaded power network should recompute on step");
    require(loaded->powerNetworks().front().supply == 2, "recomputed network should preserve supply");
    require(loaded->powerNetworks().front().demand == 1, "recomputed network should preserve demand");
    const auto* loadedMiner = loaded->machineAt(1, 0);
    require(loadedMiner != nullptr && loadedMiner->progress == 2, "loaded powered miner should continue after recompute");
}

void testWorkbenchRequiredForMachineCrafting()
{
    using thoth::game::Command;
    using thoth::game::Direction;
    using thoth::game::ItemId;
    using thoth::game::MachineKind;
    using thoth::game::Tile;
    using thoth::game::TileId;

    thoth::game::Simulation sim(34);
    require(sim.player().inventory.add(ItemId::Wood, 14), "test should add workbench/chest wood");
    sim.queue(Command::craft("chest"));
    sim.step();
    require(sim.itemCount(ItemId::Chest) == 0, "chest should require adjacent workbench");
    require(sim.itemCount(ItemId::Wood) == 14, "blocked workbench craft should preserve inputs");

    require(sim.player().inventory.add(ItemId::Stone, 2), "test should add workbench stone");
    sim.queue(Command::craft("workbench"));
    sim.step();
    require(sim.itemCount(ItemId::Workbench) == 1, "hand crafting should make workbench");
    sim.world().setTile(1, 0, Tile{TileId::Grass, 0});
    sim.queue(Command::placeItem(Direction::East, ItemId::Workbench));
    sim.step();
    const auto* workbench = sim.machineAt(1, 0);
    require(workbench != nullptr && workbench->kind == MachineKind::Workbench, "workbench should place as a machine");

    sim.queue(Command::craft("chest"));
    sim.step();
    require(sim.itemCount(ItemId::Chest) == 1, "adjacent workbench should enable machine crafting");
}

void testTechChainUnlocksCircuitsAndLogistics()
{
    using thoth::game::Direction;
    using thoth::game::ItemId;
    using thoth::game::MachineKind;

    thoth::game::Simulation sim(35);
    placeMachineAt(sim, ItemId::Lab, 1, 0, Direction::East);
    auto* lab = sim.machineAt(1, 0);
    require(lab != nullptr && lab->kind == MachineKind::Lab, "tech-chain lab should exist");
    require(lab->inventory.add(ItemId::SciencePack, 7), "test should add science packs");

    for (int i = 0; i < 160; ++i) {
        sim.step();
    }

    require(sim.isTechCompleted("logistics_1"), "tech chain should complete logistics 1");
    require(sim.isRecipeUnlocked("splitter"), "logistics 1 should unlock splitters");
    require(sim.isRecipeUnlocked("pipe"), "logistics 1 should unlock pipes");
    require(sim.isTechCompleted("automation_control"), "tech chain should complete automation control");
    require(sim.isRecipeUnlocked("circuit_board"), "automation control should unlock circuit board");
    require(sim.isRecipeUnlocked("advanced_science_pack"), "automation control should unlock advanced science");
    require(sim.isRecipeUnlocked("circuit_inserter"), "automation control should unlock circuit inserter");
    require(sim.isRecipeUnlocked("offshore_pump"), "automation control should unlock offshore pumps");
    require(std::string(sim.activeTech()) == "logistic_network", "active tech should advance to logistic network");

    require(lab->inventory.add(ItemId::AdvancedSciencePack, 5), "test should add advanced science packs");
    for (int i = 0; i < 180; ++i) {
        sim.step();
    }

    require(sim.isTechCompleted("logistic_network"), "advanced science should complete logistic network");
    require(sim.isRecipeUnlocked("provider_chest"), "logistic network should unlock provider chest");
    require(sim.isRecipeUnlocked("requester_chest"), "logistic network should unlock requester chest");
    require(sim.isRecipeUnlocked("logistic_port"), "logistic network should unlock logistic port");
    require(sim.isRecipeUnlocked("logistic_drone"), "logistic network should unlock logistic drone");
    require(sim.isRecipeUnlocked("beacon_core"), "logistic network should unlock beacon core");
    require(sim.isRecipeUnlocked("archive_terminal"), "logistic network should unlock archive terminal");
    require(sim.isRecipeUnlocked("train_stop"), "logistic network should unlock train stop");
    require(sim.isRecipeUnlocked("rift_gate"), "logistic network should unlock rift gate");
}

void testCircuitInserterFilterThresholdAndSaveLoad()
{
    using thoth::game::CircuitComparator;
    using thoth::game::Command;
    using thoth::game::Direction;
    using thoth::game::ItemId;
    using thoth::game::MachineKind;

    thoth::game::Simulation sim(36);
    placeMachineAt(sim, ItemId::Chest, 0, 0, Direction::East);
    placeMachineAt(sim, ItemId::CircuitInserter, 1, 0, Direction::East);
    placeMachineAt(sim, ItemId::Chest, 2, 0, Direction::East);
    auto* source = sim.machineAt(0, 0);
    auto* inserter = sim.machineAt(1, 0);
    auto* target = sim.machineAt(2, 0);
    require(source != nullptr && target != nullptr && inserter != nullptr, "circuit inserter setup should exist");
    require(source->inventory.add(ItemId::Wood, 1), "test should add ignored source wood");
    require(source->inventory.add(ItemId::Coal, 2), "test should add filtered source coal");

    sim.player().x = 1;
    sim.player().y = 1;
    sim.queue(Command::configureCircuit(Direction::North, ItemId::Coal, CircuitComparator::LessThan, 1));
    sim.step();
    require(inserter->filterItem == ItemId::Coal, "configure circuit should set filter item");
    require(inserter->circuitComparator == CircuitComparator::LessThan, "configure circuit should set comparator");
    require(inserter->circuitThreshold == 1, "configure circuit should set threshold");

    for (int i = 0; i < 15; ++i) {
        sim.step();
    }
    require(target->inventory.count(ItemId::Coal) == 1, "circuit inserter should move matching item under threshold");
    require(target->inventory.count(ItemId::Wood) == 0, "circuit inserter should not move nonmatching item");

    for (int i = 0; i < 30; ++i) {
        sim.step();
    }
    require(target->inventory.count(ItemId::Coal) == 1, "circuit inserter should stop once threshold is reached");
    require(source->inventory.count(ItemId::Coal) == 1, "threshold stop should leave extra filtered item at source");

    const auto path = std::filesystem::temp_directory_path() / "thoth_circuit_inserter_roundtrip.txt";
    std::string error;
    require(thoth::game::saveSimulation(sim, path, &error), "circuit save should succeed: " + error);
    auto loaded = thoth::game::loadSimulation(path, &error);
    require(loaded.has_value(), "circuit load should succeed: " + error);
    std::filesystem::remove(path);

    const auto* loadedInserter = loaded->machineAt(1, 0);
    require(loadedInserter != nullptr && loadedInserter->filterItem == ItemId::Coal, "loaded circuit filter should persist");
    require(loadedInserter->circuitComparator == CircuitComparator::LessThan, "loaded circuit comparator should persist");
    require(loadedInserter->circuitThreshold == 1, "loaded circuit threshold should persist");
}

void testLogisticDeliveryPersistsInFlight()
{
    using thoth::game::Command;
    using thoth::game::Direction;
    using thoth::game::ItemId;
    using thoth::game::MachineKind;

    thoth::game::Simulation sim(37);
    placeMachineAt(sim, ItemId::Generator, 0, 1, Direction::South);
    placeMachineAt(sim, ItemId::PowerPole, 1, 1, Direction::East);
    placeMachineAt(sim, ItemId::LogisticPort, 1, 0, Direction::East);
    placeMachineAt(sim, ItemId::ProviderChest, 2, 0, Direction::East);
    placeMachineAt(sim, ItemId::RequesterChest, 3, 0, Direction::East);

    auto* generator = sim.machineAt(0, 1);
    auto* port = sim.machineAt(1, 0);
    auto* provider = sim.machineAt(2, 0);
    auto* requester = sim.machineAt(3, 0);
    require(generator != nullptr && generator->inventory.add(ItemId::Coal, 1), "test should fuel logistic generator");
    require(port != nullptr && port->inventory.add(ItemId::LogisticDrone, 1), "test should add logistic drone");
    require(provider != nullptr && provider->inventory.add(ItemId::IronPlate, 1), "test should add provider item");
    require(requester != nullptr && requester->kind == MachineKind::RequesterChest, "requester chest should exist");

    sim.player().x = 3;
    sim.player().y = 1;
    sim.queue(Command::configureRequest(Direction::North, ItemId::IronPlate, 1));
    sim.step();
    require(sim.powerNetworks().size() == 1 && sim.powerNetworks().front().powered, "logistic port should be powered");
    require(sim.logisticJobs().size() == 1, "powered logistic network should start one delivery job");
    require(provider->inventory.count(ItemId::IronPlate) == 0, "delivery job should reserve provider item");

    const auto path = std::filesystem::temp_directory_path() / "thoth_logistic_job_roundtrip.txt";
    std::string error;
    require(thoth::game::saveSimulation(sim, path, &error), "logistic save should succeed: " + error);
    auto loaded = thoth::game::loadSimulation(path, &error);
    require(loaded.has_value(), "logistic load should succeed: " + error);
    std::filesystem::remove(path);
    require(loaded->logisticJobs().size() == 1, "loaded logistic job should remain in flight");

    for (int i = 0; i < 30; ++i) {
        loaded->step();
    }
    const auto* loadedRequester = loaded->machineAt(3, 0);
    require(loadedRequester != nullptr, "loaded requester should exist");
    require(loadedRequester->inventory.count(ItemId::IronPlate) == 1, "loaded logistic job should complete delivery");
    require(loaded->logisticJobs().empty(), "completed delivery should clear job");
    require(loaded->productionTotals().logisticDeliveries == 1, "delivery should increment production total");
}

void testArchiveTerminalChargesWhenPowered()
{
    using thoth::game::Direction;
    using thoth::game::ItemId;
    using thoth::game::MachineKind;

    thoth::game::Simulation sim(38);
    placeMachineAt(sim, ItemId::Generator, 0, 1, Direction::South);
    placeMachineAt(sim, ItemId::PowerPole, 1, 1, Direction::East);
    placeMachineAt(sim, ItemId::ArchiveTerminal, 1, 0, Direction::East);

    auto* generator = sim.machineAt(0, 1);
    auto* terminal = sim.machineAt(1, 0);
    require(generator != nullptr && generator->inventory.add(ItemId::Coal, 4), "test should fuel archive generator");
    require(terminal != nullptr && terminal->kind == MachineKind::ArchiveTerminal, "archive terminal should exist");
    require(terminal->inventory.add(ItemId::BeaconCore, 1), "test should add beacon core");

    for (int i = 0; i < 365; ++i) {
        sim.step();
    }

    require(sim.productionTotals().archiveSignals == 1, "powered archive terminal should charge one signal");
    require(terminal->inventory.count(ItemId::BeaconCore) == 0, "archive terminal should consume beacon core");
}

void testSplitterAlternatesSideOutputs()
{
    using thoth::game::Direction;
    using thoth::game::ItemId;
    using thoth::game::MachineKind;

    thoth::game::Simulation sim(39);
    placeMachineAt(sim, ItemId::Chest, 1, -1, Direction::North);
    placeMachineAt(sim, ItemId::Chest, 1, 1, Direction::South);
    placeMachineAt(sim, ItemId::Splitter, 1, 0, Direction::East);

    auto* splitter = sim.machineAt(1, 0);
    auto* northChest = sim.machineAt(1, -1);
    auto* southChest = sim.machineAt(1, 1);
    require(splitter != nullptr && splitter->kind == MachineKind::Splitter, "splitter should exist");
    require(northChest != nullptr && southChest != nullptr, "splitter side chests should exist");

    splitter->carriedItem = ItemId::Coal;
    sim.step();
    require(northChest->inventory.count(ItemId::Coal) == 1, "splitter should send first item left");

    splitter->carriedItem = ItemId::Wood;
    sim.step();
    require(southChest->inventory.count(ItemId::Wood) == 1, "splitter should send second item right");
}

void testTrainStopsTransferItems()
{
    using thoth::game::Direction;
    using thoth::game::ItemId;
    using thoth::game::MachineKind;

    thoth::game::Simulation sim(40);
    placeMachineAt(sim, ItemId::TrainStop, 1, 0, Direction::East);
    placeMachineAt(sim, ItemId::TrainStop, 3, 0, Direction::East);

    auto* source = sim.machineAt(1, 0);
    auto* target = sim.machineAt(3, 0);
    require(source != nullptr && source->kind == MachineKind::TrainStop, "source train stop should exist");
    require(target != nullptr && target->kind == MachineKind::TrainStop, "target train stop should exist");
    require(source->inventory.add(ItemId::IronPlate, 1), "test should add train cargo");

    for (int i = 0; i < 95; ++i) {
        sim.step();
    }

    require(source->inventory.count(ItemId::IronPlate) == 0, "train stop should consume cargo");
    require(target->inventory.count(ItemId::IronPlate) == 1, "next train stop should receive cargo");
    require(sim.productionTotals().trainDeliveries == 1, "train transfer should increment delivery counter");
}

void testPumpPipeMovesWaterBarrels()
{
    using thoth::game::Direction;
    using thoth::game::ItemId;
    using thoth::game::MachineKind;
    using thoth::game::Tile;
    using thoth::game::TileId;

    thoth::game::Simulation sim(41);
    sim.world().setTile(0, 0, Tile{TileId::Water, 0});
    placeMachineAt(sim, ItemId::OffshorePump, 1, 0, Direction::East);
    placeMachineAt(sim, ItemId::Pipe, 2, 0, Direction::East);
    placeMachineAt(sim, ItemId::Chest, 3, 0, Direction::East);

    auto* pump = sim.machineAt(1, 0);
    const auto* pipe = sim.machineAt(2, 0);
    require(pump != nullptr && pump->kind == MachineKind::OffshorePump, "pump should exist");
    require(pipe != nullptr && pipe->kind == MachineKind::Pipe, "pipe should exist");

    for (int i = 0; i < 40; ++i) {
        sim.step();
    }

    const auto* chest = sim.machineAt(3, 0);
    require(chest != nullptr && chest->inventory.count(ItemId::WaterBarrel) >= 1, "pump and pipe should move water to chest");
    require(sim.productionTotals().waterBarrels >= 1, "pump should count produced water barrels");
}

void testRiftGateTeleportsToOuterDimensionBand()
{
    using thoth::game::Direction;
    using thoth::game::ItemId;
    using thoth::game::MachineKind;

    thoth::game::Simulation sim(42);
    placeMachineAt(sim, ItemId::Generator, 0, 1, Direction::South);
    placeMachineAt(sim, ItemId::PowerPole, 1, 1, Direction::East);
    placeMachineAt(sim, ItemId::RiftGate, 1, 0, Direction::East);

    auto* generator = sim.machineAt(0, 1);
    auto* gate = sim.machineAt(1, 0);
    require(generator != nullptr && generator->inventory.add(ItemId::Coal, 3), "test should fuel rift generator");
    require(gate != nullptr && gate->kind == MachineKind::RiftGate, "rift gate should exist");
    require(gate->inventory.add(ItemId::BeaconCore, 1), "test should add rift beacon core");

    for (int i = 0; i < 185; ++i) {
        sim.step();
    }

    require(sim.productionTotals().riftJumps == 1, "powered rift gate should complete one jump");
    require(sim.player().x >= 4096, "rift gate should move player to the outer dimension band");
}

void testBiomeMaterialsAndBiomeCrafting()
{
    using namespace thoth::game;

    Simulation sim(20260610);
    sim.world().setTile(1, 0, 0, Tile{TileId::Reeds, 2});
    sim.queue(Command::mine(Direction::East));
    sim.step();
    require(sim.itemCount(ItemId::ReedFiber) == 2, "mining reeds should add reed fiber by richness");
    require(sim.world().getTile(1, 0, 0).id == TileId::Mud, "mined reeds should leave marsh ground");

    require(sim.player().inventory.add(ItemId::Workbench, 1), "test should add workbench");
    require(sim.player().inventory.add(ItemId::Wood, 6), "test should add boat wood");
    sim.world().setTile(0, 1, 0, Tile{TileId::Grass, 0});
    sim.queue(Command::placeItem(Direction::South, ItemId::Workbench));
    sim.step();
    sim.queue(Command::craft("boat"));
    sim.step();
    require(sim.itemCount(ItemId::Boat) == 1, "boat should craft from wood plus reed fiber at workbench");
}

void testBoatTraversalAndExit()
{
    using namespace thoth::game;

    Simulation sim(20260610);
    sim.player().inventory.clear();
    require(sim.player().inventory.add(ItemId::Boat, 1), "test should add boat");
    sim.queue(Command::assignHotbar(0, ItemId::Boat));
    sim.step();

    sim.world().setTile(1, 0, 0, Tile{TileId::Water, 0});
    sim.world().setTile(2, 0, 0, Tile{TileId::DeepWater, 2});
    sim.world().setTile(3, 0, 0, Tile{TileId::Grass, 0});
    sim.queue(Command::interact(Direction::East));
    sim.step();
    require(sim.player().inBoat, "interact with selected boat should board water");
    require(sim.player().x == 1 && sim.player().y == 0, "boarding should move player onto water");

    sim.queue(Command::move(Direction::East));
    sim.step();
    require(sim.player().x == 2, "boat should traverse deep water");
    sim.queue(Command::move(Direction::East));
    sim.step();
    require(sim.player().x == 2, "boat movement should not enter land directly");
    sim.queue(Command::interact(Direction::East));
    sim.step();
    require(!sim.player().inBoat && sim.player().x == 3, "interact should exit boat onto land");
    require(sim.itemCount(ItemId::Boat) == 1, "exiting boat should return boat item");
}

void testHouseDoorAndLayerStairs()
{
    using namespace thoth::game;

    Simulation sim(20260610);
    sim.world().setTile(1, 0, 0, Tile{TileId::Door, 0});
    sim.queue(Command::move(Direction::East));
    sim.step();
    require(sim.player().x == 0, "closed door should block movement");
    sim.queue(Command::interact(Direction::East));
    sim.step();
    sim.queue(Command::move(Direction::East));
    sim.step();
    require(sim.player().x == 1, "open door should allow movement");

    sim.world().setTile(2, 0, 0, Tile{TileId::StairsUp, 0});
    sim.world().setTile(2, 0, 1, Tile{TileId::Floor, 0});
    sim.queue(Command::interact(Direction::East));
    sim.step();
    require(sim.player().x == 2 && sim.player().z == 1, "stairs up should move player to upper layer");

    sim.world().setTile(3, 0, 1, Tile{TileId::StairsDown, 0});
    sim.world().setTile(3, 0, 0, Tile{TileId::Floor, 0});
    sim.queue(Command::interact(Direction::East));
    sim.step();
    require(sim.player().x == 3 && sim.player().z == 0, "stairs down should return player to lower layer");
}

void testDungeonGenerationAndEntityCombatSaveLoad()
{
    using namespace thoth::game;

    World world(20260610);
    require(world.getTile(0, 0, -1).id == TileId::StairsUp, "dungeon layer should generate return stairs");
    const auto dungeonTile = world.getTile(8, 8, -1).id;
    require(dungeonTile == TileId::DungeonFloor || dungeonTile == TileId::Crystal, "dungeon room should be traversable or collectible");

    Simulation sim(20260610);
    auto snapshot = sim.snapshot();
    snapshot.nextEntityId = 2;
    snapshot.entities.push_back(Entity{1, EntityKind::Slime, 1, 0, 0, 2, Direction::West, 0});
    sim.restore(snapshot);

    const auto path = std::filesystem::temp_directory_path() / "thoth_entity_roundtrip.txt";
    std::string error;
    require(thoth::game::saveSimulation(sim, path, &error), "entity save should succeed: " + error);
    auto loaded = thoth::game::loadSimulation(path, &error);
    require(loaded.has_value(), "entity load should succeed: " + error);
    require(loaded->entities().size() == 1 && loaded->entities().front().z == 0, "entity save/load should preserve entity layer");

    loaded->queue(Command::attack(Direction::East));
    loaded->step();
    require(loaded->entities().empty(), "attack should defeat low-hp slime");
    require(loaded->itemCount(ItemId::Slime) == 1, "defeated slime should drop slime item");
    require(loaded->productionTotals().creaturesDefeated == 1, "combat should increment creature total");
}

void testSupplyContractProgression()
{
    using namespace thoth::game;

    Simulation sim(20260611);
    require(sim.totalSupplyContracts() == 8, "supply contract count should remain explicit");
    require(sim.completedSupplyContracts() == 0, "fresh simulation should have no completed contracts");
    require(sim.currentSupplyContractText().find("3 iron plates") != std::string::npos,
        "first contract should ask for iron plates");
    require(sim.currentDemoGoalText().find("build plates") != std::string::npos,
        "fresh demo goal should describe the full vertical slice");
    require(sim.objectiveMarkerText().find("starter ore") != std::string::npos,
        "fresh marker should point at the starter factory area");

    auto snapshot = sim.snapshot();
    snapshot.productionTotals.ironPlates = 3;
    snapshot.productionTotals.copperPlates = 3;
    snapshot.productionTotals.sciencePacks = 2;
    snapshot.productionTotals.poweredOre = 5;
    snapshot.productionTotals.logisticDeliveries = 3;
    snapshot.productionTotals.advancedSciencePacks = 1;
    snapshot.productionTotals.archiveSignals = 1;
    sim.restore(snapshot);

    require(sim.completedSupplyContracts() == 7, "seven completed counters should satisfy seven contracts");
    require(!sim.mainObjectiveComplete(), "main objective should wait for the final rift contract");
    require(sim.currentSupplyContractText().find("rift jump") != std::string::npos,
        "last contract should ask for the rift jump");
    require(sim.currentDemoGoalText().find("biome boss") != std::string::npos,
        "midgame demo goal should push toward boss preparation");

    snapshot = sim.snapshot();
    snapshot.productionTotals.riftJumps = 1;
    sim.restore(snapshot);
    require(sim.completedSupplyContracts() == sim.totalSupplyContracts(), "all counters should complete all contracts");
    require(sim.mainObjectiveComplete(), "all contracts including rift should complete the main objective");
    require(sim.currentSupplyContractText().find("contract complete") != std::string::npos,
        "completed contract text should show completion");
    require(sim.milestoneText().find("main objective complete") != std::string::npos,
        "milestone text should surface the completed main objective");
}

void testFactoryPressureSpawnsHostileProbe()
{
    using namespace thoth::game;

    Simulation sim(20260611);
    auto snapshot = sim.snapshot();
    snapshot.tick = 300;
    snapshot.nextEntityId = 2;
    snapshot.entities.push_back(Entity{1, EntityKind::Deer, 20, 20, 0, 2, Direction::South, 0});
    snapshot.productionTotals.sciencePacks = 10;
    snapshot.tiles = {
        TileSnapshot{0, -10, Tile{TileId::Floor, 0}},
        TileSnapshot{8, -6, Tile{TileId::Floor, 0}},
        TileSnapshot{10, 0, Tile{TileId::Floor, 0}},
        TileSnapshot{8, 6, Tile{TileId::Floor, 0}},
        TileSnapshot{0, 10, Tile{TileId::Floor, 0}},
        TileSnapshot{-8, 6, Tile{TileId::Floor, 0}},
        TileSnapshot{-10, 0, Tile{TileId::Floor, 0}},
        TileSnapshot{-8, -6, Tile{TileId::Floor, 0}},
    };
    sim.restore(snapshot);

    require(sim.factoryPressureLevel() >= 120, "science production should create pressure");
    require(sim.factoryPressureText().find("raids possible") != std::string::npos,
        "pressure text should warn when raids can spawn");
    sim.step();

    bool foundHostile = false;
    for (const auto& entity : sim.entities()) {
        foundHostile = foundHostile ||
            entity.kind == EntityKind::Slime ||
            entity.kind == EntityKind::Skeleton;
    }
    require(foundHostile, "factory pressure should spawn a hostile probe on cadence");
    require(sim.player().hp == 20, "pressure probe should not deal immediate spawn damage");
}

void testBiomeContractProgression()
{
    using namespace thoth::game;

    Simulation sim(20260611);
    auto progress = sim.biomeContractProgress();
    require(progress.size() == 11, "biome contracts should expose material, rift, and outpost coverage goals");
    require(sim.completedBiomeContracts() == 0, "fresh simulation should have no completed biome contracts");
    require(progress.front().biome == BiomeKind::Marsh, "first biome contract should begin in the marsh");
    require(sim.currentBiomeContractText().find("water barrels") != std::string::npos,
        "first biome contract should ask for water barrels");

    auto snapshot = sim.snapshot();
    snapshot.productionTotals.waterBarrels = 3;
    snapshot.productionTotals.riftJumps = 2;
    snapshot.productionTotals.outpostsActivated = 5;
    snapshot.productionTotals.outpostBiomeMask =
        biomeMaskForTest(BiomeKind::Marsh) |
        biomeMaskForTest(BiomeKind::Desert) |
        biomeMaskForTest(BiomeKind::Badlands) |
        biomeMaskForTest(BiomeKind::Snowfield) |
        biomeMaskForTest(BiomeKind::CrystalField);
    snapshot.player.inventory = {
        ItemStack{ItemId::SandGlass, 2},
        ItemStack{ItemId::Basalt, 6},
        ItemStack{ItemId::IceShard, 4},
        ItemStack{ItemId::Crystal, 3},
    };
    sim.restore(snapshot);

    progress = sim.biomeContractProgress();
    require(sim.completedBiomeContracts() == static_cast<int>(progress.size()),
        "stockpiled biome materials and rift jumps should complete all biome contracts");
    require(sim.currentBiomeContractText().find("biome contracts complete") != std::string::npos,
        "completed biome contract text should show completion");

    snapshot.productionTotals.outpostsActivated = 5;
    snapshot.productionTotals.outpostBiomeMask = biomeMaskForTest(BiomeKind::Desert);
    sim.restore(snapshot);
    require(sim.activatedOutpostBiomeCount() == 1, "duplicate same-biome outposts should count as one covered biome");
    require(sim.completedBiomeContracts() == static_cast<int>(progress.size()) - 4,
        "missing unique outpost biome coverage should block remaining contracts");
    require(sim.currentBiomeContractText().find("Marsh Outpost") != std::string::npos,
        "contract text should name the missing unique outpost biome");
}

} // namespace

int main()
{
    testRegistryValidation();
    testSciencePackRecipeRequiresCopperProgression();
    testMachineRegistryMetadata();
    testChunkCoordinates();
    testDeterministicTerrain();
    testChunkBoundaryMutation();
    testStarterResources();
    testEarlyBiomeTiles();
    testBiomeLairGeneration();
    testLairEnemyPressureSpawnsBiomeHostiles();
    testMarshBossSummonPersistenceAndReward();
    testGlassBossSummonPersistenceAndReward();
    testBadlandsBossSummonPersistenceAndReward();
    testFrostBossSummonPersistenceAndReward();
    testRiftBossRequiresArchiveAndRiftProgress();
    testSimulationMovementAndMining();
    testCraftingHotbarAndPlacement();
    testAssignHotbarCommand();
    testFacingCommandAndMachineTileProtection();
    testSaveLoadRoundTrip();
    testRichPersistedStateRoundTrip();
    testReplayDeterminismAcrossSaveLoad();
    testReplayDocumentRoundTrip();
    testPackagedOreToPlateReplay();
    testPackagedOreToScienceReplay();
    testPackagedFullFlowReplay();
    testBeltsMoveStraightAndSurviveSaveLoad();
    testBeltsMoveThroughTurns();
    testBeltsBlockWithoutDeletingItems();
    testBeltsPreserveItemOrder();
    testStarterAutomationLine();
    testAutomationLineAcrossChunkBoundary();
    testCommandOnlyStarterAutomationLoop();
    testInserterTransfersBetweenEndpoints();
    testUnfueledBurnerMinerStaysIdle();
    testDepositSelectedItemIntoMachine();
    testExplicitDepositAndWithdrawItemCommands();
    testQueuedBatchDepositAndWithdrawCommands();
    testWithdrawMachineOutputWithoutTakingInputs();
    testFurnaceBlockedOutputSurvivesSaveLoad();
    testCopperMiningAndSmeltingChain();
    testFurnaceRecipeConfigurationPersists();
    testFiniteResourceTilesDepleteThroughMiners();
    testInserterDoesNotExtractFurnaceInputs();
    testResearchLocksFastBeltRecipe();
    testAssemblerCraftsSciencePackThroughAutomation();
    testAssemblerRecipeConfigurationPersists();
    testLabResearchUnlocksRecipeAndPersists();
    testFastBeltsMoveItemsFaster();
    testPowerPoleNetworkGroupingAndSupplyDemand();
    testElectricMinerRequiresPowerAndProducesOre();
    testUnderpoweredNetworkStopsElectricMachinesDeterministically();
    testGuardTowerRequiresPowerAndDefeatsHostile();
    testArcTowerHasLongerPoweredRange();
    testOutpostBeaconRequiresPowerAndBiomeInput();
    testRepairPylonRebuildsAdjacentWallGap();
    testPressureRelayMitigatesFactoryPressure();
    testPowerNetworkRecomputesAfterSaveLoad();
    testWorkbenchRequiredForMachineCrafting();
    testTechChainUnlocksCircuitsAndLogistics();
    testCircuitInserterFilterThresholdAndSaveLoad();
    testLogisticDeliveryPersistsInFlight();
    testArchiveTerminalChargesWhenPowered();
    testSplitterAlternatesSideOutputs();
    testTrainStopsTransferItems();
    testPumpPipeMovesWaterBarrels();
    testRiftGateTeleportsToOuterDimensionBand();
    testBiomeMaterialsAndBiomeCrafting();
    testBoatTraversalAndExit();
    testHouseDoorAndLayerStairs();
    testDungeonGenerationAndEntityCombatSaveLoad();
    testSupplyContractProgression();
    testFactoryPressureSpawnsHostileProbe();
    testBiomeContractProgression();

    std::cout << "thoth_tests passed\n";
    return 0;
}
