#pragma once

#include "thoth/game/inventory.hpp"
#include "thoth/game/registry.hpp"
#include "thoth/game/world.hpp"

#include <array>
#include <cstddef>
#include <cstdint>
#include <optional>
#include <string>
#include <string_view>
#include <unordered_map>
#include <vector>

namespace thoth::game {

enum class Direction : std::uint8_t {
    North,
    East,
    South,
    West,
};

enum class CommandType : std::uint8_t {
    Face,
    Move,
    Mine,
    Place,
    PlaceGhost,
    CancelGhost,
    Craft,
    SelectHotbar,
    AssignHotbar,
    ConfigureMachineRecipe,
    DepositSelected,
    DepositItem,
    WithdrawItem,
    ConfigureCircuit,
    ConfigureRequest,
    Interact,
    Attack,
    SelectArchiveChoice,
    TogglePlanningMode,
};

enum class MachineStatus : std::uint8_t {
    Idle,
    MissingInput,
    MissingFuel,
    MissingPower,
    Working,
    OutputBlocked,
};

enum class CircuitComparator : std::uint8_t {
    Always,
    LessThan,
    GreaterOrEqual,
};

enum class GameMode : std::uint8_t {
    Survival,
    Planning,
};

inline constexpr int kHotbarSlots = 10;

struct Player {
    int x = 0;
    int y = 0;
    int z = 0;
    Direction facing = Direction::South;
    Inventory inventory;
    std::array<ItemId, kHotbarSlots> hotbar{};
    int selectedHotbar = 0;
    bool inBoat = false;
    int hp = 20;
};

struct Machine {
    std::uint32_t id = 0;
    MachineKind kind = MachineKind::Chest;
    int x = 0;
    int y = 0;
    int z = 0;
    Direction direction = Direction::South;
    Inventory inventory;
    int progress = 0;
    int fuelTicks = 0;
    ItemId carriedItem = ItemId::None;
    ItemId outputItem = ItemId::None;
    std::string recipeKey;
    bool recipeLocked = false;
    ItemId filterItem = ItemId::None;
    CircuitComparator circuitComparator = CircuitComparator::Always;
    int circuitThreshold = 0;
    ItemId requestItem = ItemId::None;
    int requestThreshold = 0;
    MachineStatus status = MachineStatus::Idle;
    int durability = 0;
    ItemId socketedRelic = ItemId::None;
};

// Prototype power rules:
// - Power poles connect to poles within Manhattan distance <= 4.
// - Generators and electric consumers connect to any pole within Manhattan distance <= 2.
// - If a network's supply is below demand, all electric consumers in that network stop.
struct PowerNetwork {
    std::uint32_t id = 0;
    int supply = 0;
    int demand = 0;
    bool powered = false;
    std::vector<std::uint32_t> poleIds;
    std::vector<std::uint32_t> generatorIds;
    std::vector<std::uint32_t> consumerIds;
};

struct LogisticJob {
    std::uint32_t portId = 0;
    std::uint32_t sourceId = 0;
    std::uint32_t targetId = 0;
    ItemId item = ItemId::None;
    int ticksRemaining = 0;
    int totalTicks = 0;
};

struct GhostBuild {
    std::uint32_t id = 0;
    ItemId item = ItemId::None;
    TileId tile = TileId::Floor;
    bool machine = false;
    int x = 0;
    int y = 0;
    int z = 0;
    Direction direction = Direction::South;
    int progress = 0;
    bool fulfilled = false;
    std::string blockedReason;
};

struct ConstructionJob {
    std::uint32_t ghostId = 0;
    std::uint32_t portId = 0;
    std::uint32_t sourceId = 0;
    ItemId item = ItemId::None;
    int ticksRemaining = 0;
    int totalTicks = 0;
};

struct ProductionTotals {
    int ironPlates = 0;
    int copperPlates = 0;
    int sciencePacks = 0;
    int advancedSciencePacks = 0;
    int logisticDeliveries = 0;
    int poweredOre = 0;
    int archiveSignals = 0;
    int trainDeliveries = 0;
    int waterBarrels = 0;
    int riftJumps = 0;
    int creaturesDefeated = 0;
    int dungeonChestsOpened = 0;
    int bossesDefeated = 0;
    int outpostsActivated = 0;
    int pressureWavesRepelled = 0;
    int bossRelicsClaimed = 0;
    int outpostBiomeMask = 0;
    int outpostDeliveries = 0;
    int outpostDeliveryBiomeMask = 0;
    int scrapRecovered = 0;
    int scrapRecycled = 0;
    int pressureEnemiesDefeated = 0;
    int pressureWaveRewardsClaimed = 0;
    int riftStormsTriggered = 0;
    int riftStormsSurvived = 0;
    int scoutDispatches = 0;
    int scoutMaterialsRecovered = 0;
    int scoutedBiomeMask = 0;
};

struct OutpostRouteState {
    BiomeKind biome = BiomeKind::Grassland;
    int deliveredInWindow = 0;
    int requiredPerWindow = 2;
    int stability = 0;
    std::uint64_t windowStartTick = 0;
    std::uint64_t lastDeliveryTick = 0;
};

struct RiftStormState {
    int severity = 0;
    int ticksRemaining = 0;
    int cooldownTicks = 0;
};

struct ArchiveChoice {
    std::string key;
    std::string label;
    std::string recipeKey;
    ItemId fragment = ItemId::ArchiveFragment;
    int fragmentCost = 0;
    int scienceCost = 0;
    bool unlocked = false;
    bool affordable = false;
};

struct FactoryDashboardPanel {
    std::string key;
    std::string label;
    std::string status;
    std::string detail;
    int current = 0;
    int target = 0;
    bool urgent = false;
};

struct PressureHotspot {
    int x = 0;
    int y = 0;
    int z = 0;
    int pressure = 0;
    int mitigation = 0;
    bool nextWaveAnchor = false;
};

struct ExpeditionBoardEntry {
    std::string key;
    std::string label;
    int current = 0;
    int required = 0;
    bool unlocked = false;
    bool complete = false;
};

struct RegionInfo {
    int originX = 0;
    int originY = 0;
    int z = 0;
    BiomeKind biome = BiomeKind::Grassland;
    std::string name;
    std::string hazard;
    std::string reward;
    std::optional<LairKind> lair;
};

struct ProductionRatePanel {
    std::string key;
    std::string label;
    int currentPerMinute = 0;
    int targetPerMinute = 0;
    bool blocked = false;
    std::string detail;
};

struct BiomeContractProgress {
    BiomeKind biome = BiomeKind::Grassland;
    std::string label;
    int current = 0;
    int required = 0;
    bool complete = false;
};

struct BiomeHazardState {
    BiomeKind biome = BiomeKind::Grassland;
    std::string label;
    int level = 0;
    std::string effect;
    std::string mitigation;
};

struct PressureEventCard {
    std::string key;
    std::string label;
    int severity = 0;
    int spawnCount = 0;
    std::string effect;
    std::string counterplay;
};

enum class AchievementId : std::uint8_t {
    FirstIronPlate,
    FirstSciencePack,
    LogisticsOne,
    FirstCreatureDefeated,
    FirstBossDefeated,
    FirstPressureReward,
    FirstRiftJump,
    FirstOutpost,
    FirstScoutDispatch,
    ScoutRecovery,
};

struct AchievementProgress {
    AchievementId id = AchievementId::FirstIronPlate;
    std::string key;
    std::string title;
    std::string description;
    int current = 0;
    int required = 1;
    bool unlocked = false;
};

enum class TutorialAction : std::uint8_t {
    Move,
    Mine,
    Craft,
    Place,
    Deposit,
};

struct TutorialStepProgress {
    TutorialAction action = TutorialAction::Move;
    std::string label;
    bool complete = false;
};

struct TutorialState {
    bool active = false;
    bool completed = true;
    int actionMask = 0;
    int realSpawnX = 0;
    int realSpawnY = 0;
    int realSpawnZ = 0;
};

enum class EntityKind : std::uint8_t {
    Deer,
    Chicken,
    Crab,
    Fish,
    Slime,
    GlassSkitter,
    SunScarab,
    Skeleton,
    CaveCrawler,
    FrostCrawler,
    NullWisp,
    DungeonSentinel,
    RiftStalker,
    MarshBroodheart,
    GlassMaw,
    BadlandsWarden,
    FrostNullifier,
    RiftSignalTyrant,
};

struct BossExamProgress {
    EntityKind boss = EntityKind::MarshBroodheart;
    BiomeKind biome = BiomeKind::Grassland;
    std::string label;
    int current = 0;
    int required = 0;
    bool complete = false;
};

struct OutpostDeliveryProgress {
    BiomeKind biome = BiomeKind::Grassland;
    std::string label;
    int current = 0;
    int required = 0;
    bool complete = false;
};

struct OutpostRouteProgress {
    BiomeKind biome = BiomeKind::Grassland;
    std::string label;
    int current = 0;
    int required = 0;
    int stability = 0;
    bool active = false;
    bool stable = false;
};

struct Entity {
    std::uint32_t id = 0;
    EntityKind kind = EntityKind::Deer;
    int x = 0;
    int y = 0;
    int z = 0;
    int hp = 1;
    Direction facing = Direction::South;
    int cooldown = 0;
    bool pressureSpawn = false;
};

struct Command {
    CommandType type = CommandType::Move;
    Direction direction = Direction::South;
    Direction orientation = Direction::South;
    TileId tile = TileId::Floor;
    ItemId item = ItemId::None;
    int hotbarIndex = 0;
    CircuitComparator comparator = CircuitComparator::Always;
    int amount = 0;
    std::string recipeKey;

    [[nodiscard]] static Command face(Direction direction);
    [[nodiscard]] static Command move(Direction direction);
    [[nodiscard]] static Command mine(Direction direction);
    [[nodiscard]] static Command placeItem(Direction direction, ItemId item);
    [[nodiscard]] static Command placeItem(Direction direction, ItemId item, Direction orientation);
    [[nodiscard]] static Command placeTile(Direction direction, TileId tile);
    [[nodiscard]] static Command placeGhost(Direction direction, ItemId item);
    [[nodiscard]] static Command placeGhost(Direction direction, ItemId item, Direction orientation);
    [[nodiscard]] static Command cancelGhost(Direction direction);
    [[nodiscard]] static Command craft(std::string recipeKey);
    [[nodiscard]] static Command selectHotbar(int index);
    [[nodiscard]] static Command assignHotbar(int index, ItemId item);
    [[nodiscard]] static Command configureMachineRecipe(Direction direction, std::string recipeKey);
    [[nodiscard]] static Command depositSelected(Direction direction);
    [[nodiscard]] static Command depositItem(Direction direction, ItemId item);
    [[nodiscard]] static Command withdrawItem(Direction direction, ItemId item);
    [[nodiscard]] static Command configureCircuit(Direction direction, ItemId filterItem, CircuitComparator comparator, int threshold);
    [[nodiscard]] static Command configureRequest(Direction direction, ItemId requestItem, int threshold);
    [[nodiscard]] static Command interact(Direction direction);
    [[nodiscard]] static Command attack(Direction direction);
    [[nodiscard]] static Command selectArchiveChoice(Direction direction, int choiceIndex);
    [[nodiscard]] static Command togglePlanningMode();
};

struct PlayerSnapshot {
    int x = 0;
    int y = 0;
    int z = 0;
    Direction facing = Direction::South;
    int selectedHotbar = 0;
    std::array<ItemId, kHotbarSlots> hotbar{};
    std::vector<ItemStack> inventory;
    bool inBoat = false;
    int hp = 20;
};

struct SimulationSnapshot {
    std::uint64_t seed = 0;
    std::uint64_t tick = 0;
    PlayerSnapshot player;
    std::vector<TileSnapshot> tiles;
    std::uint32_t nextMachineId = 1;
    std::uint32_t nextEntityId = 1;
    std::uint32_t nextGhostId = 1;
    std::vector<Machine> machines;
    std::vector<Entity> entities;
    std::vector<LogisticJob> logisticJobs;
    std::vector<GhostBuild> ghostBuilds;
    std::vector<ConstructionJob> constructionJobs;
    ProductionTotals productionTotals;
    std::vector<OutpostRouteState> outpostRoutes;
    RiftStormState riftStorm;
    std::string activeTech = "logistics_1";
    int researchProgress = 0;
    std::vector<std::string> completedTechs;
    std::vector<std::string> unlockedRecipes;
    std::vector<std::string> archiveUnlocks;
    std::vector<AchievementId> unlockedAchievements;
    TutorialState tutorial;
    GameMode gameMode = GameMode::Survival;
};

class Simulation {
public:
    explicit Simulation(std::uint64_t seed);
    [[nodiscard]] static Simulation newGame(std::uint64_t seed, bool startInTutorial);
    [[nodiscard]] static Simulation newPlanningGame(std::uint64_t seed);

    void queue(Command command);
    void step();

    [[nodiscard]] World& world();
    [[nodiscard]] const World& world() const;
    [[nodiscard]] Player& player();
    [[nodiscard]] const Player& player() const;
    [[nodiscard]] std::uint64_t tick() const;
    [[nodiscard]] int itemCount(ItemId item) const;
    [[nodiscard]] ItemId selectedItem() const;
    [[nodiscard]] const std::vector<Machine>& machines() const;
    [[nodiscard]] const Machine* machineAt(int x, int y) const;
    [[nodiscard]] const Machine* machineAt(int x, int y, int z) const;
    [[nodiscard]] Machine* machineAt(int x, int y);
    [[nodiscard]] Machine* machineAt(int x, int y, int z);
    [[nodiscard]] const std::vector<Entity>& entities() const;
    [[nodiscard]] const Entity* entityAt(int x, int y, int z) const;
    [[nodiscard]] bool isRecipeUnlocked(std::string_view recipeKey) const;
    [[nodiscard]] bool isTechCompleted(std::string_view techKey) const;
    [[nodiscard]] std::string_view activeTech() const;
    [[nodiscard]] int researchProgress() const;
    [[nodiscard]] int researchGoal() const;
    [[nodiscard]] const std::vector<PowerNetwork>& powerNetworks() const;
    [[nodiscard]] const std::vector<LogisticJob>& logisticJobs() const;
    [[nodiscard]] const std::vector<GhostBuild>& ghostBuilds() const;
    [[nodiscard]] const std::vector<ConstructionJob>& constructionJobs() const;
    [[nodiscard]] const ProductionTotals& productionTotals() const;
    [[nodiscard]] GameMode gameMode() const;
    [[nodiscard]] bool canCraft(std::string_view recipeKey) const;
    [[nodiscard]] std::vector<ArchiveChoice> archiveChoices() const;
    [[nodiscard]] std::string archiveResearchText() const;
    [[nodiscard]] std::string constructionText() const;
    [[nodiscard]] int completedSupplyContracts() const;
    [[nodiscard]] int totalSupplyContracts() const;
    [[nodiscard]] std::string currentSupplyContractText() const;
    [[nodiscard]] int factoryPressureLevel() const;
    [[nodiscard]] int ticksUntilNextPressureWave() const;
    [[nodiscard]] std::string factoryPressureText() const;
    [[nodiscard]] std::string pressureWaveAlertText() const;
    [[nodiscard]] PressureEventCard nextPressureEvent() const;
    [[nodiscard]] std::string pressureEventDeckText() const;
    [[nodiscard]] std::vector<PressureHotspot> pressureHotspots() const;
    [[nodiscard]] std::string pressureMapText() const;
    [[nodiscard]] const RiftStormState& riftStorm() const;
    [[nodiscard]] std::string riftStormText() const;
    [[nodiscard]] std::vector<FactoryDashboardPanel> factoryDashboard() const;
    [[nodiscard]] std::string factoryDashboardText() const;
    [[nodiscard]] std::vector<ExpeditionBoardEntry> postVictoryExpeditionBoard() const;
    [[nodiscard]] int completedPostVictoryExpeditions() const;
    [[nodiscard]] std::string postVictoryExpeditionText() const;
    [[nodiscard]] bool mainObjectiveComplete() const;
    [[nodiscard]] bool hasActivatedOutpostBiome(BiomeKind biome) const;
    [[nodiscard]] int activatedOutpostBiomeCount() const;
    [[nodiscard]] std::vector<BiomeKind> activatedOutpostBiomes() const;
    [[nodiscard]] bool hasCompletedOutpostDeliveryBiome(BiomeKind biome) const;
    [[nodiscard]] int outpostDeliveryBiomeCount() const;
    [[nodiscard]] std::vector<OutpostDeliveryProgress> outpostDeliveryProgress() const;
    [[nodiscard]] int completedOutpostDeliveryContracts() const;
    [[nodiscard]] std::string currentOutpostDeliveryText() const;
    [[nodiscard]] std::vector<OutpostRouteProgress> outpostRoutes() const;
    [[nodiscard]] int stableOutpostRouteCount() const;
    [[nodiscard]] std::string outpostRouteText() const;
    [[nodiscard]] bool hasScoutedBiome(BiomeKind biome) const;
    [[nodiscard]] int scoutedBiomeCount() const;
    [[nodiscard]] std::vector<BiomeKind> scoutedBiomes() const;
    [[nodiscard]] std::string scoutAutomationText() const;
    [[nodiscard]] int completedBiomeContracts() const;
    [[nodiscard]] std::vector<BiomeContractProgress> biomeContractProgress() const;
    [[nodiscard]] std::string currentBiomeContractText() const;
    [[nodiscard]] std::vector<BiomeHazardState> biomeHazards() const;
    [[nodiscard]] std::string currentBiomeHazardText() const;
    [[nodiscard]] std::vector<BossExamProgress> bossExamProgress() const;
    [[nodiscard]] std::string currentBossExamText() const;
    [[nodiscard]] RegionInfo regionInfoAt(int x, int y, int z) const;
    [[nodiscard]] std::vector<RegionInfo> latestScoutReports() const;
    [[nodiscard]] std::string regionText() const;
    [[nodiscard]] std::vector<ProductionRatePanel> productionRatePanels() const;
    [[nodiscard]] std::string productionRateText() const;
    [[nodiscard]] std::string currentDemoGoalText() const;
    [[nodiscard]] std::string objectiveMarkerText() const;
    [[nodiscard]] std::string milestoneText() const;
    [[nodiscard]] std::string playtestTelemetryText() const;
    [[nodiscard]] std::vector<AchievementProgress> achievementProgress() const;
    [[nodiscard]] const std::vector<AchievementId>& unlockedAchievements() const;
    [[nodiscard]] int unlockedAchievementCount() const;
    [[nodiscard]] const TutorialState& tutorialState() const;
    [[nodiscard]] std::vector<TutorialStepProgress> tutorialProgress() const;
    [[nodiscard]] bool tutorialExitReady() const;
    [[nodiscard]] std::array<int, 3> realWorldSpawn() const;
    [[nodiscard]] bool isMachinePowered(std::uint32_t machineId) const;
    [[nodiscard]] SimulationSnapshot snapshot() const;
    void restore(const SimulationSnapshot& snapshot);
    [[nodiscard]] static Simulation fromSnapshot(const SimulationSnapshot& snapshot);

private:
    void apply(const Command& command);
    void move(Direction direction);
    void mine(Direction direction);
    void place(Direction direction, TileId tile, ItemId item, Direction orientation);
    void placeMachine(Direction direction, ItemId item, Direction orientation);
    void placeGhost(Direction direction, ItemId item, Direction orientation);
    void cancelGhost(Direction direction);
    void depositSelected(Direction direction);
    void depositItem(Direction direction, ItemId item);
    void withdrawItem(Direction direction, ItemId item);
    void craft(std::string_view recipeKey);
    void selectHotbar(int index);
    void assignHotbarSlot(int index, ItemId item);
    void configureMachineRecipe(Direction direction, std::string_view recipeKey);
    void configureCircuit(Direction direction, ItemId filterItem, CircuitComparator comparator, int threshold);
    void configureRequest(Direction direction, ItemId requestItem, int threshold);
    void selectArchiveChoice(Direction direction, int choiceIndex);
    void togglePlanningMode();
    void interact(Direction direction);
    void attack(Direction direction);
    [[nodiscard]] bool trySummonMarshBoss(int x, int y, int z);
    [[nodiscard]] bool trySummonGlassBoss(int x, int y, int z);
    [[nodiscard]] bool trySummonBadlandsBoss(int x, int y, int z);
    [[nodiscard]] bool trySummonFrostBoss(int x, int y, int z);
    [[nodiscard]] bool trySummonRiftBoss(int x, int y, int z);
    void updateMachines();
    void updateEntities();
    void ensureLocalEntities();
    void ensureLairEntities();
    void ensureFactoryPressureEntity();
    void updatePowerNetworks();
    void updateMiners();
    void updateElectricMiners();
    void updateBelts();
    void updateSplitters();
    void updateInserters();
    void updateFurnaces();
    void updateAssemblers();
    void updateLabs();
    void updateLogistics();
    void updateConstructionJobs(const std::vector<std::uint32_t>& poweredPorts);
    void updateScoutAutomation(const std::vector<std::uint32_t>& poweredPorts);
    void updateTrainStops();
    void updateFluidPumps();
    void updatePipes();
    void updateArchiveTerminals();
    void updateRiftGates();
    void updateOutpostBeacons();
    void updateGuardTowers();
    void updateRepairPylons();
    void updatePressureRelays();
    void updateArcTowers();
    void updateRiftStorms();
    void updateBiomeHazards();
    void updateBossPhases();
    void updateAchievements();
    void beginTutorial();
    void completeTutorial();
    void recordTutorialAction(TutorialAction action);
    [[nodiscard]] TutorialState findRealWorldSpawn() const;
    [[nodiscard]] bool hasNearbyStarterResources(const World& world, int x, int y) const;
    void removeTutorialLayerState();
    void startRiftStorm(int severity);
    [[nodiscard]] int currentRiftStormSeverity() const;
    [[nodiscard]] int riftStormChargeBonus(const Machine& machine) const;
    [[nodiscard]] bool riftStormActive() const;
    [[nodiscard]] PressureEventCard pressureEventForTick(std::uint64_t waveTick) const;
    [[nodiscard]] std::vector<EntityKind> pressureEventSpawns(const PressureEventCard& card) const;
    [[nodiscard]] PressureHotspot nextPressureAnchor() const;
    [[nodiscard]] int localPressureAt(int x, int y, int z) const;
    [[nodiscard]] int pressureMitigationAt(int x, int y, int z) const;
    [[nodiscard]] int outpostRouteStability(BiomeKind biome) const;
    [[nodiscard]] bool archiveRecipeUnlocked(std::string_view recipeKey) const;
    [[nodiscard]] bool unlockArchiveRecipe(std::string_view recipeKey);
    [[nodiscard]] bool tryArchiveUnlock(Machine& machine);
    [[nodiscard]] bool canPlaceGhostBuild(const GhostBuild& ghost, std::string* blockedReason = nullptr) const;
    [[nodiscard]] bool completeGhostBuild(GhostBuild& ghost);
    [[nodiscard]] bool bossExamComplete(EntityKind boss) const;
    [[nodiscard]] bool spawnEntityNear(int x, int y, int z, EntityKind kind, int range);
    [[nodiscard]] bool canPlaceMachine(MachineKind kind, int x, int y) const;
    [[nodiscard]] bool canPlaceMachine(MachineKind kind, int x, int y, int z) const;
    [[nodiscard]] bool acceptItemAt(int x, int y, ItemId item);
    [[nodiscard]] bool acceptItemAt(int x, int y, int z, ItemId item);
    [[nodiscard]] bool acceptItem(Machine& machine, ItemId item);
    [[nodiscard]] ItemId extractItemAt(int x, int y, ItemId filterItem = ItemId::None);
    [[nodiscard]] ItemId extractItemAt(int x, int y, int z, ItemId filterItem = ItemId::None);
    [[nodiscard]] ItemId extractItem(Machine& machine, ItemId filterItem = ItemId::None);
    [[nodiscard]] bool returnItem(Machine& machine, ItemId item);
    [[nodiscard]] bool outputItem(Machine& machine, ItemId item);
    [[nodiscard]] bool refuel(Machine& machine);
    [[nodiscard]] bool isMachineItem(ItemId item) const;
    [[nodiscard]] bool isBelt(MachineKind kind) const;
    [[nodiscard]] bool isPipe(MachineKind kind) const;
    [[nodiscard]] bool isPowerPole(MachineKind kind) const;
    [[nodiscard]] bool isPowerConsumer(MachineKind kind) const;
    [[nodiscard]] bool isLogisticStorage(MachineKind kind) const;
    [[nodiscard]] BiomeKind scoutTargetBiome(const Machine& port) const;
    [[nodiscard]] int machineMaxDurability(MachineKind kind) const;
    [[nodiscard]] int tileMaxDurability(TileId id) const;
    [[nodiscard]] bool isDamageableStructureTile(TileId id) const;
    [[nodiscard]] bool damageStructureAt(int x, int y, int z, int amount);
    [[nodiscard]] bool damageAdjacentStructure(Entity& entity, int amount);
    [[nodiscard]] int powerDemand(MachineKind kind) const;
    [[nodiscard]] bool hasAdjacentWater(int x, int y) const;
    [[nodiscard]] bool hasAdjacentWater(int x, int y, int z) const;
    [[nodiscard]] Machine* machineById(std::uint32_t id);
    [[nodiscard]] const Machine* machineById(std::uint32_t id) const;
    [[nodiscard]] bool isRecipeInput(std::string_view recipeKey, ItemId item) const;
    [[nodiscard]] bool isAdjacentToWorkbench() const;
    [[nodiscard]] bool canCraftAtCurrentStation(const RecipeDef& recipe) const;
    [[nodiscard]] bool circuitConditionAllows(const Machine& inserter, const Machine* target) const;
    [[nodiscard]] int countMachineItem(const Machine& machine, ItemId item) const;
    [[nodiscard]] int totalItemCount(ItemId item) const;
    [[nodiscard]] std::vector<std::uint32_t> poweredLogisticPortIds() const;
    [[nodiscard]] bool isWaterTile(TileId id) const;
    [[nodiscard]] bool isHostile(EntityKind kind) const;
    [[nodiscard]] int playerAttackDamage(const Entity& entity) const;
    [[nodiscard]] int achievementCurrent(AchievementId id) const;
    [[nodiscard]] bool isAchievementUnlocked(AchievementId id) const;
    [[nodiscard]] ItemId entityDrop(EntityKind kind) const;
    [[nodiscard]] int entityDropCount(EntityKind kind) const;
    [[nodiscard]] int entityMaxHp(EntityKind kind) const;
    void defeatEntity(std::size_t entityIndex);
    [[nodiscard]] std::optional<EntityKind> localEntityKindForTile(int x, int y, int z) const;
    [[nodiscard]] int activeTechGoal() const;
    [[nodiscard]] std::string nextIncompleteTech() const;
    void rebuildMachineCellIndex();
    void completeActiveTech();
    void recordProduced(ItemId item, MachineKind producer);
    void addItem(ItemId item, int count);
    [[nodiscard]] bool consumeItem(ItemId item, int count);
    void assignHotbar(ItemId item);

    World world_;
    Player player_;
    std::uint64_t tick_ = 0;
    std::uint32_t nextMachineId_ = 1;
    std::uint32_t nextEntityId_ = 1;
    std::uint32_t nextGhostId_ = 1;
    std::vector<Machine> machines_;
    std::vector<Entity> entities_;
    std::unordered_map<std::uint64_t, std::size_t> machineCellIndex_;
    std::vector<Command> commandQueue_;
    std::string activeTech_ = "logistics_1";
    int researchProgress_ = 0;
    std::vector<std::string> completedTechs_;
    std::vector<std::string> unlockedRecipes_;
    std::vector<PowerNetwork> powerNetworks_;
    std::vector<std::uint32_t> poweredMachineIds_;
    std::vector<LogisticJob> logisticJobs_;
    std::vector<GhostBuild> ghostBuilds_;
    std::vector<ConstructionJob> constructionJobs_;
    ProductionTotals productionTotals_;
    std::vector<OutpostRouteState> outpostRoutes_;
    RiftStormState riftStorm_;
    std::vector<std::string> archiveUnlocks_;
    std::vector<AchievementId> unlockedAchievements_;
    TutorialState tutorialState_;
    GameMode gameMode_ = GameMode::Survival;
};

[[nodiscard]] int dx(Direction direction);
[[nodiscard]] int dy(Direction direction);
[[nodiscard]] std::string_view toString(MachineStatus status);
[[nodiscard]] std::string_view toString(CircuitComparator comparator);
[[nodiscard]] std::string_view toString(GameMode mode);
[[nodiscard]] std::string_view toString(AchievementId id);
[[nodiscard]] CircuitComparator circuitComparatorFromKey(std::string_view key);
[[nodiscard]] GameMode gameModeFromKey(std::string_view key);
[[nodiscard]] std::optional<AchievementId> achievementIdFromKey(std::string_view key);

} // namespace thoth::game
