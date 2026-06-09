#include "thoth/game/simulation.hpp"

#include <algorithm>
#include <chrono>
#include <cstddef>
#include <cstdlib>
#include <cstdint>
#include <iomanip>
#include <iostream>
#include <limits>
#include <utility>
#include <vector>

namespace {

constexpr int kDefaultTicks = 900;
constexpr int kDefaultBurnerLines = 48;
constexpr int kDefaultPoweredLines = 16;
constexpr int kMaxTicks = 1000000;
constexpr int kMaxFactoryLines = 10000;
constexpr double kDefaultMaxUsPerTick = 5000.0;
constexpr double kDefaultMaxUsPerMachineTick = 10.0;

int positiveEnvInt(const char* name, int fallback, int maximum)
{
    const char* raw = std::getenv(name);
    if (raw == nullptr || raw[0] == '\0') {
        return fallback;
    }

    char* end = nullptr;
    const long parsed = std::strtol(raw, &end, 10);
    if (end == raw || *end != '\0' || parsed <= 0 || parsed > maximum ||
        parsed > std::numeric_limits<int>::max()) {
        return fallback;
    }

    return static_cast<int>(parsed);
}

double positiveEnvDouble(const char* name, double fallback)
{
    const char* raw = std::getenv(name);
    if (raw == nullptr || raw[0] == '\0') {
        return fallback;
    }

    char* end = nullptr;
    const double parsed = std::strtod(raw, &end);
    if (end == raw || *end != '\0' || parsed <= 0.0) {
        return fallback;
    }
    return parsed;
}

struct BenchmarkConfig {
    int ticks = kDefaultTicks;
    int burnerLines = kDefaultBurnerLines;
    int poweredLines = kDefaultPoweredLines;
    double maxUsPerTick = kDefaultMaxUsPerTick;
    double maxUsPerMachineTick = kDefaultMaxUsPerMachineTick;
};

BenchmarkConfig benchmarkConfig()
{
    BenchmarkConfig config;
    config.ticks = positiveEnvInt("THOTH_BENCHMARK_TICKS", kDefaultTicks, kMaxTicks);
    config.burnerLines =
        positiveEnvInt("THOTH_BENCHMARK_BURNER_LINES", kDefaultBurnerLines, kMaxFactoryLines);
    config.poweredLines =
        positiveEnvInt("THOTH_BENCHMARK_POWERED_LINES", kDefaultPoweredLines, kMaxFactoryLines);
    config.maxUsPerTick = positiveEnvDouble("THOTH_BENCHMARK_MAX_US_PER_TICK", kDefaultMaxUsPerTick);
    config.maxUsPerMachineTick =
        positiveEnvDouble("THOTH_BENCHMARK_MAX_US_PER_MACHINE_TICK", kDefaultMaxUsPerMachineTick);
    return config;
}

thoth::game::Machine& addMachine(
    thoth::game::SimulationSnapshot& snapshot,
    std::uint32_t& nextId,
    thoth::game::MachineKind kind,
    int x,
    int y,
    thoth::game::Direction direction)
{
    thoth::game::Machine machine;
    machine.id = nextId++;
    machine.kind = kind;
    machine.x = x;
    machine.y = y;
    machine.direction = direction;
    snapshot.machines.push_back(std::move(machine));
    return snapshot.machines.back();
}

void addTile(thoth::game::SimulationSnapshot& snapshot, int x, int y, thoth::game::TileId id, int data = 0)
{
    snapshot.tiles.push_back(thoth::game::TileSnapshot{x, y, thoth::game::Tile{id, data}});
}

thoth::game::Simulation makeBenchmarkSimulation(const BenchmarkConfig& config)
{
    using thoth::game::Direction;
    using thoth::game::ItemId;
    using thoth::game::MachineKind;
    using thoth::game::TileId;

    thoth::game::SimulationSnapshot snapshot;
    snapshot.seed = 20260609;
    snapshot.player.hotbar.fill(ItemId::None);
    const auto burnerCount = static_cast<std::size_t>(config.burnerLines);
    const auto poweredCount = static_cast<std::size_t>(config.poweredLines);
    snapshot.machines.reserve((burnerCount * 7U) + (poweredCount * 4U));
    snapshot.tiles.reserve((burnerCount * 7U) + (poweredCount * 4U));

    std::uint32_t nextId = 1;

    for (int line = 0; line < config.burnerLines; ++line) {
        const int y = line * 3;
        for (int x = 1; x <= 6; ++x) {
            addTile(snapshot, x, y, TileId::Floor);
        }
        addTile(snapshot, 0, y, TileId::IronOre, 500);

        auto& miner = addMachine(snapshot, nextId, MachineKind::BurnerMiner, 0, y, Direction::East);
        const auto minerFueled = miner.inventory.add(ItemId::Coal, 120);
        (void)minerFueled;
        addMachine(snapshot, nextId, MachineKind::Belt, 1, y, Direction::East);
        addMachine(snapshot, nextId, MachineKind::Inserter, 2, y, Direction::East);
        auto& furnace = addMachine(snapshot, nextId, MachineKind::Furnace, 3, y, Direction::East);
        const auto furnaceFueled = furnace.inventory.add(ItemId::Coal, 120);
        (void)furnaceFueled;
        addMachine(snapshot, nextId, MachineKind::Inserter, 4, y, Direction::East);
        addMachine(snapshot, nextId, MachineKind::Belt, 5, y, Direction::East);
        addMachine(snapshot, nextId, MachineKind::Chest, 6, y, Direction::South);
    }

    const int powerStartY = (config.burnerLines * 3) + 12;
    for (int line = 0; line < config.poweredLines; ++line) {
        const int y = powerStartY + (line * 3);
        addTile(snapshot, -2, y, TileId::Floor);
        addTile(snapshot, -1, y, TileId::Floor);
        addTile(snapshot, 0, y, TileId::IronOre, 500);
        addTile(snapshot, 1, y, TileId::Floor);

        auto& generator = addMachine(snapshot, nextId, MachineKind::Generator, -2, y, Direction::East);
        const auto generatorFueled = generator.inventory.add(ItemId::Coal, 240);
        (void)generatorFueled;
        addMachine(snapshot, nextId, MachineKind::PowerPole, -1, y, Direction::South);
        addMachine(snapshot, nextId, MachineKind::ElectricMiner, 0, y, Direction::East);
        addMachine(snapshot, nextId, MachineKind::Chest, 1, y, Direction::South);
    }

    snapshot.nextMachineId = nextId;
    return thoth::game::Simulation::fromSnapshot(snapshot);
}

struct FactoryOutput {
    int ironPlates = 0;
    int ironOre = 0;
};

FactoryOutput countFactoryOutput(const thoth::game::Simulation& simulation)
{
    FactoryOutput output;
    for (const auto& machine : simulation.machines()) {
        if (machine.kind != thoth::game::MachineKind::Chest) {
            continue;
        }
        output.ironPlates += machine.inventory.count(thoth::game::ItemId::IronPlate);
        output.ironOre += machine.inventory.count(thoth::game::ItemId::IronOre);
    }
    return output;
}

} // namespace

int main()
{
    const auto config = benchmarkConfig();
    auto simulation = makeBenchmarkSimulation(config);
    const auto machineCount = simulation.machines().size();

    std::vector<long long> tickSamplesUs;
    tickSamplesUs.reserve(static_cast<std::size_t>(config.ticks));
    long long elapsedUs = 0;
    for (int tick = 0; tick < config.ticks; ++tick) {
        const auto startedAt = std::chrono::steady_clock::now();
        simulation.step();
        const auto finishedAt = std::chrono::steady_clock::now();
        const auto tickUs =
            std::chrono::duration_cast<std::chrono::microseconds>(finishedAt - startedAt).count();
        tickSamplesUs.push_back(tickUs);
        elapsedUs += tickUs;
    }

    const auto output = countFactoryOutput(simulation);
    const double usPerTick = static_cast<double>(elapsedUs) / static_cast<double>(config.ticks);
    const double usPerMachineTick = usPerTick / static_cast<double>(machineCount);
    const auto machineTicks =
        static_cast<unsigned long long>(machineCount) * static_cast<unsigned long long>(config.ticks);
    auto sortedSamples = tickSamplesUs;
    std::sort(sortedSamples.begin(), sortedSamples.end());
    const auto maxTickUs = sortedSamples.empty() ? 0LL : sortedSamples.back();
    const auto p95Index = sortedSamples.empty() ? std::size_t{0} :
        std::min<std::size_t>(sortedSamples.size() - 1U, ((sortedSamples.size() * 95U) + 99U) / 100U - 1U);
    const auto p95TickUs = sortedSamples.empty() ? 0LL : sortedSamples[p95Index];

    std::cout << "thoth_simulation_benchmark\n"
              << "  ticks: " << config.ticks << '\n'
              << "  burner_lines: " << config.burnerLines << '\n'
              << "  powered_lines: " << config.poweredLines << '\n'
              << "  machines: " << machineCount << '\n'
              << "  machine_ticks: " << machineTicks << '\n'
              << "  iron_plates_in_chests: " << output.ironPlates << '\n'
              << "  electric_ore_in_chests: " << output.ironOre << '\n'
              << "  elapsed_ms: " << std::fixed << std::setprecision(3)
              << static_cast<double>(elapsedUs) / 1000.0 << '\n'
              << "  us_per_tick: " << usPerTick << '\n'
              << "  p95_us_per_tick: " << static_cast<double>(p95TickUs) << '\n'
              << "  max_observed_us_per_tick: " << static_cast<double>(maxTickUs) << '\n'
              << "  max_us_per_tick: " << config.maxUsPerTick << '\n'
              << "  us_per_machine_tick: " << usPerMachineTick << '\n'
              << "  max_us_per_machine_tick: " << config.maxUsPerMachineTick << '\n';

    if (output.ironPlates <= 0 || output.ironOre <= 0) {
        std::cerr << "benchmark factory failed to produce expected outputs\n";
        return 1;
    }

    if (usPerTick > config.maxUsPerTick) {
        std::cerr << "benchmark exceeded tick-cost guardrail: " << usPerTick
                  << " us_per_tick > " << config.maxUsPerTick << " max_us_per_tick\n";
        return 1;
    }

    if (usPerMachineTick > config.maxUsPerMachineTick) {
        std::cerr << "benchmark exceeded per-machine tick guardrail: " << usPerMachineTick
                  << " us_per_machine_tick > " << config.maxUsPerMachineTick
                  << " max_us_per_machine_tick\n";
        return 1;
    }

    return 0;
}
