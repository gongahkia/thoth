#include "thoth/game/registry.hpp"
#include "thoth/game/save.hpp"
#include "thoth/game/simulation.hpp"
#include "thoth/game/world.hpp"

#include "raylib.h"

#include <algorithm>
#include <array>
#include <cstdint>
#include <filesystem>
#include <string>
#include <vector>

namespace {

constexpr int kScreenWidth = 1280;
constexpr int kScreenHeight = 720;
constexpr int kTilePixels = 24;
constexpr double kFixedDelta = 1.0 / 60.0;
const std::filesystem::path kSavePath = "thoth_save.txt";

Color toColor(thoth::game::Rgb rgb)
{
    return Color{rgb.r, rgb.g, rgb.b, 255};
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

void queueInput(thoth::game::Simulation& sim, std::string& status)
{
    using thoth::game::Command;

    auto direction = facingFromInput(sim.player().facing);
    if (direction != sim.player().facing || IsKeyDown(KEY_W) || IsKeyDown(KEY_A) ||
        IsKeyDown(KEY_S) || IsKeyDown(KEY_D) || IsKeyDown(KEY_UP) ||
        IsKeyDown(KEY_DOWN) || IsKeyDown(KEY_LEFT) || IsKeyDown(KEY_RIGHT)) {
        sim.queue(Command::move(direction));
    }

    if (IsKeyPressed(KEY_SPACE)) {
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
        sim.queue(Command::placeItem(sim.player().facing, sim.selectedItem()));
    }

    if (IsKeyPressed(KEY_C)) {
        sim.queue(Command::craft("chest"));
    }
    if (IsKeyPressed(KEY_F)) {
        sim.queue(Command::craft("furnace"));
    }

    if (IsKeyPressed(KEY_F5)) {
        std::string error;
        status = thoth::game::saveSimulation(sim, kSavePath, &error) ? "saved thoth_save.txt" : "save failed: " + error;
    }

    if (IsKeyPressed(KEY_F9)) {
        std::string error;
        auto loaded = thoth::game::loadSimulation(kSavePath, &error);
        if (loaded) {
            sim = *loaded;
            status = "loaded thoth_save.txt";
        } else {
            status = "load failed: " + error;
        }
    }
}

void drawWorld(thoth::game::Simulation& sim)
{
    const auto& player = sim.player();
    const int halfTilesX = (kScreenWidth / kTilePixels) / 2 + 3;
    const int halfTilesY = (kScreenHeight / kTilePixels) / 2 + 3;

    for (int y = player.y - halfTilesY; y <= player.y + halfTilesY; ++y) {
        for (int x = player.x - halfTilesX; x <= player.x + halfTilesX; ++x) {
            const auto tile = sim.world().getTile(x, y);
            const auto& def = thoth::game::tileDef(tile.id);
            DrawRectangle(
                x * kTilePixels,
                y * kTilePixels,
                kTilePixels,
                kTilePixels,
                toColor(def.color));
            DrawRectangleLines(
                x * kTilePixels,
                y * kTilePixels,
                kTilePixels,
                kTilePixels,
                Color{0, 0, 0, 28});
        }
    }

    DrawRectangle(
        player.x * kTilePixels + 4,
        player.y * kTilePixels + 4,
        kTilePixels - 8,
        kTilePixels - 8,
        Color{235, 238, 230, 255});
}

void drawHud(const thoth::game::Simulation& sim, const std::string& status)
{
    const auto& player = sim.player();
    std::vector<std::string> lines = {
        "Thoth C++/raylib pivot prototype",
        "WASD/Arrows: move  Space: mine  P: place selected  C/F: craft chest/furnace",
        "pos=(" + std::to_string(player.x) + "," + std::to_string(player.y) + ") tick=" +
            std::to_string(sim.tick()) + " chunks=" + std::to_string(sim.world().loadedChunkCount()),
        "wood=" + std::to_string(sim.itemCount(thoth::game::ItemId::Wood)) +
            " stone=" + std::to_string(sim.itemCount(thoth::game::ItemId::Stone)) +
            " iron_ore=" + std::to_string(sim.itemCount(thoth::game::ItemId::IronOre)) +
            " coal=" + std::to_string(sim.itemCount(thoth::game::ItemId::Coal)),
        "F5/F9: save/load  status=" + status};

    std::string hotbar = "hotbar:";
    for (int i = 0; i < thoth::game::kHotbarSlots; ++i) {
        const auto item = player.hotbar[static_cast<std::size_t>(i)];
        hotbar += (i == player.selectedHotbar ? " [" : " ");
        hotbar += std::to_string((i + 1) % 10);
        hotbar += ":";
        hotbar += std::string(thoth::game::toString(item));
        if (i == player.selectedHotbar) {
            hotbar += "]";
        }
    }
    lines.push_back(hotbar);

    DrawRectangle(12, 12, 980, 132, Color{20, 24, 25, 214});
    for (int i = 0; i < static_cast<int>(lines.size()); ++i) {
        DrawText(lines[static_cast<std::size_t>(i)].c_str(), 24, 24 + (i * 20), 16, RAYWHITE);
    }
}

} // namespace

int main()
{
    InitWindow(kScreenWidth, kScreenHeight, "Thoth - C++ raylib automation sandbox");
    SetTargetFPS(60);

    thoth::game::Simulation sim(1337);
    std::string status = "ready";
    Camera2D camera{};
    camera.offset = Vector2{kScreenWidth * 0.5f, kScreenHeight * 0.5f};
    camera.zoom = 1.0f;

    double accumulator = 0.0;

    while (!WindowShouldClose()) {
        queueInput(sim, status);
        accumulator = std::min(accumulator + static_cast<double>(GetFrameTime()), 0.25);
        while (accumulator >= kFixedDelta) {
            sim.step();
            accumulator -= kFixedDelta;
        }

        camera.target = Vector2{
            (sim.player().x * kTilePixels) + (kTilePixels * 0.5f),
            (sim.player().y * kTilePixels) + (kTilePixels * 0.5f)};

        BeginDrawing();
        ClearBackground(Color{16, 18, 18, 255});
        BeginMode2D(camera);
        drawWorld(sim);
        EndMode2D();
        drawHud(sim, status);
        EndDrawing();
    }

    CloseWindow();
    return 0;
}
