#pragma once

#include "thoth/game/registry.hpp"
#include "thoth/game/replay.hpp"
#include "thoth/game/simulation.hpp"
#include "thoth/game/world.hpp"

#include "raylib.h"

#include <array>
#include <chrono>
#include <cstddef>
#include <cstdint>
#include <filesystem>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

namespace thoth::app {

inline constexpr int kScreenWidth = 1280;
inline constexpr int kScreenHeight = 720;
inline constexpr int kTilePixels = 32;
inline constexpr int kMoveRepeatFrames = 10;
inline constexpr float kPlayerVisualLerp = 0.24f;
inline constexpr int kAudioSampleRate = 22050;
inline constexpr double kFixedDelta = 1.0 / 60.0;
inline constexpr double kPi = 3.14159265358979323846;
inline constexpr int kCraftMenuX = 12;
inline constexpr int kCraftMenuY = 488;
inline constexpr int kCraftMenuWidth = 1256;
inline constexpr int kCraftMenuColumns = 6;
inline constexpr int kCraftCardHeight = 38;
inline constexpr int kCraftCardGap = 6;
inline constexpr int kMachinePanelX = 462;
inline constexpr int kMachinePanelY = 190;
inline constexpr int kMachinePanelWidth = 364;
inline constexpr int kInventoryPanelX = 12;
inline constexpr int kInventoryPanelY = 190;
inline constexpr int kInventoryPanelWidth = 430;
inline constexpr int kInventorySlotSize = 58;
inline constexpr int kInventorySlotGap = 8;

inline const std::filesystem::path kSavePath = "thoth_save.txt";
inline const std::filesystem::path kDemoReplayPath = "assets/replays/ore_to_plate.thothreplay";
inline const std::filesystem::path kScienceReplayPath = "assets/replays/science_research.thothreplay";
inline const std::filesystem::path kFullFlowReplayPath = "assets/replays/full_flow.thothreplay";
inline const std::filesystem::path kAuthoredSpriteAtlasPath = "assets/sprites/thoth_atlas.art";
inline const std::filesystem::path kSpriteAtlasPath = "assets/sprites/thoth_atlas.png";
inline const std::filesystem::path kGeneratedSpriteAtlasPath = "assets/sprites/thoth_generated_atlas.png";
inline const std::filesystem::path kAuthoredAudioCuePath = "assets/audio/thoth_cues.sfx";
inline const std::filesystem::path kAudioAssetDir = "assets/audio";
inline const std::filesystem::path kGeneratedAudioAssetDir = "assets/audio/generated";
inline const std::filesystem::path kMediaPreviewPath = "assets/previews/thoth_full_flow_preview.png";
inline const std::filesystem::path kWindowSmokePath = "assets/previews/thoth_window_smoke.png";
inline const std::filesystem::path kPlaytestTelemetryPath = "assets/previews/thoth_playtest_telemetry.json";
inline const std::filesystem::path kProfilePath = "thoth_profile.txt";

struct AppState {
    std::string status = "ready";
    thoth::game::Direction buildDirection = thoth::game::Direction::South;
    bool paused = false;
    bool debug = false;
    bool craftMenuOpen = false;
    bool inventoryOpen = false;
    int craftSelection = 0;
    int machineTransferAmount = 1;
    int audioAuditionIndex = 0;
    int feedbackTicks = 0;
    int productionCueCooldown = 0;
    int machineIssueCueCooldown = 0;
    int lastFactoryIronPlates = -1;
    int lastFactoryCopperPlates = -1;
    int lastFactorySciencePacks = -1;
    int lastFuelIssues = -1;
    int lastPowerIssues = -1;
    int lastBlockedIssues = -1;
    int lastAchievementUnlockCount = -1;
    int tutorialActionCount = 0;
    int simStepsLastFrame = 0;
    int movementCooldownFrames = 0;
    float renderPlayerX = 0.0f;
    float renderPlayerY = 0.0f;
    bool renderPlayerReady = false;
    double lastTickUs = 0.0;
    double averageTickUs = 0.0;
    Color feedbackColor = Color{255, 255, 255, 0};
    std::string feedbackText;
    std::string audioSource = "none";
    bool tutorialVisible = true;
    bool tutorialSeenProfile = false;
    bool tutorialManualOpen = false;
};

struct CraftMenuEntry {
    std::string_view recipeKey;
    std::string_view hotkey;
};

struct MachinePanelButton {
    Rectangle rect{};
    thoth::game::ItemId item = thoth::game::ItemId::None;
    bool deposit = true;
};

struct RecipePanelButton {
    Rectangle rect{};
    std::string_view recipeKey;
};

enum class MachineConfigAction {
    Circuit,
    Request,
};

struct MachineConfigButton {
    Rectangle rect{};
    MachineConfigAction action = MachineConfigAction::Circuit;
    thoth::game::ItemId item = thoth::game::ItemId::None;
    thoth::game::CircuitComparator comparator = thoth::game::CircuitComparator::Always;
    int threshold = 0;
    std::string_view label;
};

struct TransferAmountButton {
    Rectangle rect{};
    int amount = 1;
};

struct InventoryButton {
    Rectangle rect{};
    thoth::game::ItemId item = thoth::game::ItemId::None;
    int hotbarIndex = -1;
    bool hotbar = false;
};

struct FirstLinePartGuide {
    thoth::game::ItemId item = thoth::game::ItemId::None;
    thoth::game::MachineKind machine = thoth::game::MachineKind::Chest;
    std::string_view recipeKey;
    std::string_view label;
    std::string_view hotkey;
};

struct AudioBank {
    bool ready = false;
    int externalSounds = 0;
    std::string source = "none";
    Sound mine{};
    Sound place{};
    Sound craft{};
    Sound invalid{};
    Sound save{};
    Sound load{};
    Sound tick{};
    Sound produce{};
};

struct ToneSpec {
    const char* filename = "";
    float frequency = 0.0f;
    float endFrequency = 0.0f;
    float seconds = 0.0f;
    float volume = 0.0f;
};

struct AudioCueSpec {
    std::string filename;
    float frequency = 0.0f;
    float endFrequency = 0.0f;
    float seconds = 0.0f;
    float volume = 0.0f;
};

inline constexpr std::array<ToneSpec, 8> kToneSpecs = {
    ToneSpec{"mine.wav", 178.0f, 74.0f, 0.09f, 0.16f},
    ToneSpec{"place.wav", 320.0f, 230.0f, 0.064f, 0.13f},
    ToneSpec{"craft.wav", 500.0f, 780.0f, 0.105f, 0.12f},
    ToneSpec{"invalid.wav", 132.0f, 62.0f, 0.135f, 0.13f},
    ToneSpec{"save.wav", 560.0f, 920.0f, 0.145f, 0.10f},
    ToneSpec{"load.wav", 360.0f, 620.0f, 0.13f, 0.10f},
    ToneSpec{"tick.wav", 900.0f, 900.0f, 0.032f, 0.055f},
    ToneSpec{"produce.wav", 470.0f, 880.0f, 0.12f, 0.11f},
};

inline constexpr int kSpritePixels = 16;
inline constexpr int kSpriteAtlasColumns = 8;

enum class SpriteId : int {
    TileGrass,
    TileDirt,
    TileSand,
    TileSnow,
    TileMud,
    TileWater,
    TileTree,
    TileStone,
    TileIronOre,
    TileCopperOre,
    TileCoalOre,
    TileFloor,
    ItemWood,
    ItemStone,
    ItemCoal,
    ItemIronOre,
    ItemIronPlate,
    ItemCopperOre,
    ItemCopperPlate,
    ItemSciencePack,
    MachineBelt,
    MachineFastBelt,
    MachineInserter,
    MachineBurnerMiner,
    MachineFurnace,
    MachineChest,
    MachineWorkbench,
    MachineAssembler,
    MachineLab,
    MachineGenerator,
    MachinePowerPole,
    MachineElectricMiner,
    Player,
    Count,
};

inline constexpr int kSpriteAtlasRows =
    (static_cast<int>(SpriteId::Count) + kSpriteAtlasColumns - 1) / kSpriteAtlasColumns;

struct VisualAtlas {
    Texture2D texture{};
    bool ready = false;
    bool generated = true;
    std::string source = "none";
};

struct SpriteDrawOptions {
    bool flipX = false;
    bool flipY = false;
    Color tint = WHITE;
};

struct FlowStack {
    thoth::game::ItemId item = thoth::game::ItemId::None;
    int available = 0;
    int required = 0;
};

extern const VisualAtlas* gVisualAtlas;

std::optional<std::filesystem::path> findBundledPath(const std::filesystem::path& relativePath);
Color toColor(thoth::game::Rgb rgb);
Color multiplyTint(Color color, Color tint);
int spriteOriginX(SpriteId id);
int spriteOriginY(SpriteId id);
SpriteDrawOptions tileSpriteOptions(thoth::game::TileId id, int x, int y);
Image makeGeneratedAtlasImage();
bool makeAuthoredAtlasImage(Image& image, std::string* error);
bool saveGeneratedAtlas(const std::filesystem::path& path, std::string* error);
bool saveAuthoredAtlas(const std::filesystem::path& path, std::string* error);
bool saveGeneratedAudioCues(const std::filesystem::path& directory, std::string* error);
bool saveAuthoredAudioCues(const std::filesystem::path& directory, std::string* error);
bool validateBundledAssets(std::string* error);
VisualAtlas loadVisualAtlas();
void unloadVisualAtlas(VisualAtlas& atlas);
SpriteId tileSprite(thoth::game::TileId id);
SpriteId itemSprite(thoth::game::ItemId item);
SpriteId placementSprite(thoth::game::ItemId item);
SpriteId machineSprite(thoth::game::MachineKind kind);
bool drawSprite(SpriteId id, Rectangle destination, SpriteDrawOptions options);
bool drawSprite(SpriteId id, Rectangle destination, Color tint = WHITE);
bool drawSpriteCentered(SpriteId id, int centerX, int centerY, int size, Color tint = WHITE);
AudioBank loadAudioBank();
void unloadAudioBank(AudioBank& audio);
void playCue(const AudioBank& audio, const Sound& sound);
int audioCueIndex(int index);
std::string_view audioCueName(int index);
const Sound& audioCueSound(const AudioBank& audio, int index);
Color machineColor(thoth::game::MachineKind kind);
Color itemColor(thoth::game::ItemId item);
Color statusColor(thoth::game::MachineStatus status);

bool validateFullFlowReplay(
    const thoth::game::Simulation& simulation,
    const thoth::game::ReplayDocument& document,
    std::string* error);
bool validatePackagedReplays(std::string* error);
int runCommandLineMode(int argc, char** argv);

bool saveMediaPreview(const std::filesystem::path& path, std::string* error);
bool saveWindowSmokeScreenshot(const std::filesystem::path& path, std::string* error);

void stepSimulationTimed(thoth::game::Simulation& sim, AppState& state);
void setFeedback(AppState& state, std::string text, Color color);
void loadAppProfile(AppState& state);
void markTutorialSeen(AppState& state);
void recordTutorialAction(AppState& state);
int runInteractiveApp();

std::string shortItemName(thoth::game::ItemId item);
std::string machineGlyph(thoth::game::MachineKind kind);
float machineProgressRatio(const thoth::game::Machine& machine);
void drawDirectionArrow(Vector2 center, thoth::game::Direction direction, float length, Color color);
void drawItemIcon(int centerX, int centerY, thoth::game::ItemId item, int radius);
thoth::game::Direction rotateClockwise(thoth::game::Direction direction);
std::string stacksText(const thoth::game::Inventory& inventory);
int machineCount(const thoth::game::Simulation& sim, thoth::game::MachineKind kind);
const thoth::game::Machine* machineById(const thoth::game::Simulation& sim, std::uint32_t id);
const thoth::game::Machine* facedMachine(const thoth::game::Simulation& sim);
int beltItemCount(const thoth::game::Simulation& sim);
int blockedMachineCount(const thoth::game::Simulation& sim);
int machineStatusCount(const thoth::game::Simulation& sim, thoth::game::MachineStatus status);
int itemCountInMachines(const thoth::game::Simulation& sim, thoth::game::MachineKind kind, thoth::game::ItemId item);
int itemCountInFactory(const thoth::game::Simulation& sim, thoth::game::ItemId item);
void syncProductionCounters(const thoth::game::Simulation& sim, AppState& state);
void updateProductionFeedback(const thoth::game::Simulation& sim, AppState& state, const AudioBank& audio);
void syncMachineIssueCounters(const thoth::game::Simulation& sim, AppState& state);
void updateMachineIssueFeedback(const thoth::game::Simulation& sim, AppState& state, const AudioBank& audio);
void syncAchievementCounters(const thoth::game::Simulation& sim, AppState& state);
void updateAchievementFeedback(const thoth::game::Simulation& sim, AppState& state, const AudioBank& audio);
std::string checklistMark(bool complete);
bool hasPlacedFirstLine(const thoth::game::Simulation& sim);
bool hasFirstLineParts(const thoth::game::Simulation& sim);
std::vector<std::string> firstLineChecklist(const thoth::game::Simulation& sim);
bool hasItemOrMachine(const thoth::game::Simulation& sim, thoth::game::ItemId item, thoth::game::MachineKind machine);
std::vector<std::string> scienceChecklist(const thoth::game::Simulation& sim);
std::vector<std::string> powerChecklist(const thoth::game::Simulation& sim);
std::vector<std::string> supplyContractChecklist(const thoth::game::Simulation& sim);
std::vector<std::string> biomeContractChecklist(const thoth::game::Simulation& sim);
std::string statusStatsText(const thoth::game::Simulation& sim);
bool isMachineIssue(thoth::game::MachineStatus status);
std::string machineIssueBadgeText(thoth::game::MachineStatus status);
std::string machineIssueSummaryText(const thoth::game::Simulation& sim);
const std::vector<CraftMenuEntry>& craftMenuEntries();
std::vector<MachinePanelButton> machinePanelButtons(const thoth::game::Simulation& sim);
std::vector<TransferAmountButton> transferAmountButtons();
std::vector<RecipePanelButton> machineRecipeButtons(const thoth::game::Simulation& sim);
std::vector<MachineConfigButton> machineConfigButtons(const thoth::game::Simulation& sim);
std::vector<InventoryButton> inventoryButtons(const thoth::game::Simulation& sim);
std::vector<InventoryButton> inventoryHotbarButtons();
int craftMenuRowCount();
int craftCardWidth();
Rectangle craftCardRect(int index);
void clampCraftSelection(AppState& state);
bool canCraftRecipe(const thoth::game::Simulation& sim, std::string_view recipeKey);
void queueCraft(
    thoth::game::Simulation& sim,
    AppState& state,
    const AudioBank& audio,
    std::string recipeKey);
void queueSelectedCraft(thoth::game::Simulation& sim, AppState& state, const AudioBank& audio);
std::string recipeCostText(const thoth::game::Simulation& sim, const thoth::game::RecipeDef& recipe);
std::string recipeMachineCostText(const thoth::game::Inventory& inventory, const thoth::game::RecipeDef& recipe);
std::string powerNetworkDetail(const thoth::game::Simulation& sim, const thoth::game::Machine& machine);
std::string targetNameAt(const thoth::game::Simulation& sim, int x, int y);
std::string outputTargetText(const thoth::game::Simulation& sim, const thoth::game::Machine& machine);
thoth::game::ItemId furnaceOreInput(const thoth::game::RecipeDef& recipe);
std::string depositActionText(const thoth::game::Simulation& sim, thoth::game::ItemId item);
std::string machineHintText(const thoth::game::Simulation& sim, const thoth::game::Machine& machine);
const thoth::game::RecipeDef* activePanelRecipe(const thoth::game::Machine& machine);
std::string machineProcessChipText(const thoth::game::Simulation& sim, const thoth::game::Machine& machine);
std::string machineActionChipText(const thoth::game::Simulation& sim, const thoth::game::Machine& machine);
int machineAvailableCountForPanel(const thoth::game::Machine& machine, thoth::game::ItemId item);
int effectiveMachineTransferAmount(
    const thoth::game::Simulation& sim,
    const thoth::game::Machine& machine,
    const MachinePanelButton& button,
    int requestedAmount);
std::string firstLinePlacementHint(const thoth::game::Simulation& sim);
std::string firstLineFuelHint(const thoth::game::Simulation& sim);
std::string firstLineBlockerHint(const thoth::game::Simulation& sim);
std::string tutorialNextStepText(const thoth::game::Simulation& sim);
std::string factoryStatsText(const thoth::game::Simulation& sim);
std::string powerStatsText(const thoth::game::Simulation& sim);
std::string objectiveText(const thoth::game::Simulation& sim);
std::string placementBlockReason(const thoth::game::Simulation& sim, thoth::game::ItemId item);
bool canPreviewPlace(const thoth::game::Simulation& sim, thoth::game::ItemId item);
bool selectedBuildToolActive(const thoth::game::Simulation& sim);
std::string facedMachineText(const thoth::game::Simulation& sim);
std::string directionText(thoth::game::Direction direction);
void updatePlayerVisual(const thoth::game::Simulation& sim, AppState& state);
std::string placementPreviewText(
    const thoth::game::Simulation& sim,
    thoth::game::ItemId item,
    thoth::game::Direction buildDirection);
bool canMineFacing(const thoth::game::Simulation& sim);
bool isResourceTile(thoth::game::TileId id);

void queueInput(thoth::game::Simulation& sim, AppState& state, const AudioBank& audio);
std::optional<thoth::game::Simulation> loadPackagedReplay(
    const std::filesystem::path& replayPath,
    std::string* error);

void drawPlacementPreview(const thoth::game::Simulation& sim, thoth::game::Direction buildDirection);
void drawBuildGridOverlay(const thoth::game::Simulation& sim);
bool machineShowsDirection(thoth::game::MachineKind kind);
Color resourceRichnessColor(thoth::game::TileId id);
int renderAnimationPhase(std::uint64_t tick, int x, int y, int period);
bool isBeltMachine(thoth::game::MachineKind kind);
Color activityPulseColor(thoth::game::MachineKind kind);
bool hasMachineActivityPulse(const thoth::game::Machine& machine);
unsigned char pulseAlpha(std::uint64_t tick, int x, int y, int baseAlpha, int rangeAlpha);
void drawWorld(thoth::game::Simulation& sim, const AppState& state);
void appendWrapped(std::vector<std::string>& lines, const std::string& text, std::size_t width);
void drawPanel(int x, int y, int width, const std::string& title, const std::vector<std::string>& lines);
void drawCraftMenu(const thoth::game::Simulation& sim, const AppState& state);
std::string transferAmountLabel(int amount);
thoth::game::ItemId resourceOutputItem(thoth::game::TileId tile);
std::vector<FlowStack> recipeInputFlow(const thoth::game::Machine& machine, const thoth::game::RecipeDef& recipe);
void drawMachinePanel(const thoth::game::Simulation& sim, const AppState& state);
void drawInventoryPanel(const thoth::game::Simulation& sim, const AppState& state);
void drawHotbar(const thoth::game::Simulation& sim);
void drawHud(const thoth::game::Simulation& sim, const AppState& state);

} // namespace thoth::app
