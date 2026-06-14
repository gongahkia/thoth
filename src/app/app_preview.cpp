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

void drawPreviewRectLines(Image& image, int x, int y, int width, int height, Color color)
{
    ImageDrawRectangle(&image, x, y, width, 1, color);
    ImageDrawRectangle(&image, x, y + height - 1, width, 1, color);
    ImageDrawRectangle(&image, x, y, 1, height, color);
    ImageDrawRectangle(&image, x + width - 1, y, 1, height, color);
}

std::array<std::uint8_t, 7> previewGlyph(char raw)
{
    char c = raw;
    if (c >= 'a' && c <= 'z') {
        c = static_cast<char>('A' + (c - 'a'));
    }

    switch (c) {
    case 'A':
        return {0b01110, 0b10001, 0b10001, 0b11111, 0b10001, 0b10001, 0b10001};
    case 'B':
        return {0b11110, 0b10001, 0b10001, 0b11110, 0b10001, 0b10001, 0b11110};
    case 'C':
        return {0b01111, 0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b01111};
    case 'D':
        return {0b11110, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b11110};
    case 'E':
        return {0b11111, 0b10000, 0b10000, 0b11110, 0b10000, 0b10000, 0b11111};
    case 'F':
        return {0b11111, 0b10000, 0b10000, 0b11110, 0b10000, 0b10000, 0b10000};
    case 'G':
        return {0b01111, 0b10000, 0b10000, 0b10111, 0b10001, 0b10001, 0b01111};
    case 'H':
        return {0b10001, 0b10001, 0b10001, 0b11111, 0b10001, 0b10001, 0b10001};
    case 'I':
        return {0b11111, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b11111};
    case 'J':
        return {0b00111, 0b00010, 0b00010, 0b00010, 0b10010, 0b10010, 0b01100};
    case 'K':
        return {0b10001, 0b10010, 0b10100, 0b11000, 0b10100, 0b10010, 0b10001};
    case 'L':
        return {0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b11111};
    case 'M':
        return {0b10001, 0b11011, 0b10101, 0b10101, 0b10001, 0b10001, 0b10001};
    case 'N':
        return {0b10001, 0b11001, 0b10101, 0b10011, 0b10001, 0b10001, 0b10001};
    case 'O':
        return {0b01110, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01110};
    case 'P':
        return {0b11110, 0b10001, 0b10001, 0b11110, 0b10000, 0b10000, 0b10000};
    case 'Q':
        return {0b01110, 0b10001, 0b10001, 0b10001, 0b10101, 0b10010, 0b01101};
    case 'R':
        return {0b11110, 0b10001, 0b10001, 0b11110, 0b10100, 0b10010, 0b10001};
    case 'S':
        return {0b01111, 0b10000, 0b10000, 0b01110, 0b00001, 0b00001, 0b11110};
    case 'T':
        return {0b11111, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100};
    case 'U':
        return {0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01110};
    case 'V':
        return {0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01010, 0b00100};
    case 'W':
        return {0b10001, 0b10001, 0b10001, 0b10101, 0b10101, 0b10101, 0b01010};
    case 'X':
        return {0b10001, 0b10001, 0b01010, 0b00100, 0b01010, 0b10001, 0b10001};
    case 'Y':
        return {0b10001, 0b10001, 0b01010, 0b00100, 0b00100, 0b00100, 0b00100};
    case 'Z':
        return {0b11111, 0b00001, 0b00010, 0b00100, 0b01000, 0b10000, 0b11111};
    case '0':
        return {0b01110, 0b10001, 0b10011, 0b10101, 0b11001, 0b10001, 0b01110};
    case '1':
        return {0b00100, 0b01100, 0b00100, 0b00100, 0b00100, 0b00100, 0b01110};
    case '2':
        return {0b01110, 0b10001, 0b00001, 0b00010, 0b00100, 0b01000, 0b11111};
    case '3':
        return {0b11110, 0b00001, 0b00001, 0b01110, 0b00001, 0b00001, 0b11110};
    case '4':
        return {0b00010, 0b00110, 0b01010, 0b10010, 0b11111, 0b00010, 0b00010};
    case '5':
        return {0b11111, 0b10000, 0b10000, 0b11110, 0b00001, 0b00001, 0b11110};
    case '6':
        return {0b01110, 0b10000, 0b10000, 0b11110, 0b10001, 0b10001, 0b01110};
    case '7':
        return {0b11111, 0b00001, 0b00010, 0b00100, 0b01000, 0b01000, 0b01000};
    case '8':
        return {0b01110, 0b10001, 0b10001, 0b01110, 0b10001, 0b10001, 0b01110};
    case '9':
        return {0b01110, 0b10001, 0b10001, 0b01111, 0b00001, 0b00001, 0b01110};
    case '-':
        return {0b00000, 0b00000, 0b00000, 0b11110, 0b00000, 0b00000, 0b00000};
    case '>':
        return {0b10000, 0b01000, 0b00100, 0b00010, 0b00100, 0b01000, 0b10000};
    case ':':
        return {0b00000, 0b00100, 0b00100, 0b00000, 0b00100, 0b00100, 0b00000};
    case '/':
        return {0b00001, 0b00001, 0b00010, 0b00100, 0b01000, 0b10000, 0b10000};
    case '_':
        return {0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b11111};
    case '.':
        return {0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b01100, 0b01100};
    case '+':
        return {0b00000, 0b00100, 0b00100, 0b11111, 0b00100, 0b00100, 0b00000};
    case ' ':
        return {};
    }
    return {0b01110, 0b10001, 0b00001, 0b00010, 0b00100, 0b00000, 0b00100};
}

void drawPreviewText(Image& image, std::string_view text, int x, int y, int scale, Color color)
{
    constexpr int glyphWidth = 5;
    constexpr int glyphHeight = 7;
    constexpr int glyphAdvance = 6;
    int cursorX = x;
    int cursorY = y;

    for (const char raw : text) {
        if (raw == '\n') {
            cursorX = x;
            cursorY += (glyphHeight + 2) * scale;
            continue;
        }

        const auto glyph = previewGlyph(raw);
        for (int row = 0; row < glyphHeight; ++row) {
            for (int column = 0; column < glyphWidth; ++column) {
                const bool filled = ((glyph[row] >> (glyphWidth - 1 - column)) & 1U) != 0;
                if (filled) {
                    ImageDrawRectangle(
                        &image,
                        cursorX + column * scale,
                        cursorY + row * scale,
                        scale,
                        scale,
                        color);
                }
            }
        }
        cursorX += glyphAdvance * scale;
    }
}

void drawPreviewSprite(
    Image& target,
    const Color* atlasPixels,
    SpriteId id,
    int x,
    int y,
    int scale,
    SpriteDrawOptions options = {})
{
    const int atlasWidth = kSpriteAtlasColumns * kSpritePixels;
    const int originX = spriteOriginX(id);
    const int originY = spriteOriginY(id);
    for (int sy = 0; sy < kSpritePixels; ++sy) {
        for (int sx = 0; sx < kSpritePixels; ++sx) {
            const int sourceX = options.flipX ? (kSpritePixels - 1 - sx) : sx;
            const int sourceY = options.flipY ? (kSpritePixels - 1 - sy) : sy;
            const auto color = multiplyTint(atlasPixels[(originY + sourceY) * atlasWidth + originX + sourceX], options.tint);
            if (color.a == 0) {
                continue;
            }
            ImageDrawRectangle(&target, x + sx * scale, y + sy * scale, scale, scale, color);
        }
    }
}

thoth::game::TileId previewTileIdInBounds(
    const thoth::game::World& world,
    thoth::game::TileId fallback,
    int x,
    int y,
    int minX,
    int maxX,
    int minY,
    int maxY)
{
    if (x < minX || x > maxX || y < minY || y > maxY) {
        return fallback;
    }
    return world.getTile(x, y).id;
}

TileVariantEdges previewTileVariantEdgesAt(
    const thoth::game::World& world,
    thoth::game::TileId center,
    int x,
    int y,
    int minX,
    int maxX,
    int minY,
    int maxY)
{
    return tileVariantEdges(
        center,
        previewTileIdInBounds(world, center, x, y - 1, minX, maxX, minY, maxY),
        previewTileIdInBounds(world, center, x + 1, y, minX, maxX, minY, maxY),
        previewTileIdInBounds(world, center, x, y + 1, minX, maxX, minY, maxY),
        previewTileIdInBounds(world, center, x - 1, y, minX, maxX, minY, maxY),
        previewTileIdInBounds(world, center, x - 1, y - 1, minX, maxX, minY, maxY),
        previewTileIdInBounds(world, center, x + 1, y - 1, minX, maxX, minY, maxY),
        previewTileIdInBounds(world, center, x + 1, y + 1, minX, maxX, minY, maxY),
        previewTileIdInBounds(world, center, x - 1, y + 1, minX, maxX, minY, maxY));
}

void drawPreviewTileVariantEdges(
    Image& image,
    thoth::game::TileId id,
    const TileVariantEdges& edges,
    int x,
    int y,
    int tileSize,
    int visualHeight)
{
    if (!hasTileVariantEdges(edges)) {
        return;
    }

    y -= visualHeight;
    const int edge = std::max(1, tileSize / 10);
    const int corner = std::max(edge + 1, tileSize / 5);
    const Color edgeColor = tileVariantEdgeColor(id);
    const Color cornerColor = tileVariantCornerColor(id);

    if (edges.north) {
        ImageDrawRectangle(&image, x, y, tileSize, edge, edgeColor);
    }
    if (edges.east) {
        ImageDrawRectangle(&image, x + tileSize - edge, y, edge, tileSize, edgeColor);
    }
    if (edges.south) {
        ImageDrawRectangle(&image, x, y + tileSize - edge, tileSize, edge, edgeColor);
    }
    if (edges.west) {
        ImageDrawRectangle(&image, x, y, edge, tileSize, edgeColor);
    }

    if (edges.northWest) {
        ImageDrawRectangle(&image, x, y, corner, corner, cornerColor);
    }
    if (edges.northEast) {
        ImageDrawRectangle(&image, x + tileSize - corner, y, corner, corner, cornerColor);
    }
    if (edges.southEast) {
        ImageDrawRectangle(&image, x + tileSize - corner, y + tileSize - corner, corner, corner, cornerColor);
    }
    if (edges.southWest) {
        ImageDrawRectangle(&image, x, y + tileSize - corner, corner, corner, cornerColor);
    }
}

int previewLiftPixels(const RenderVisualProfile& profile, int tileSize)
{
    return (profile.liftPixels * tileSize) / kTilePixels;
}

void drawPreviewProfileShadow(Image& image, const RenderVisualProfile& profile, int x, int y, int tileSize, Color color)
{
    if (profile.shadowWidthPixels <= 0 || profile.shadowHeightPixels <= 0) {
        return;
    }

    const int width = std::max(2, (profile.shadowWidthPixels * tileSize) / kTilePixels);
    const int height = std::max(1, (profile.shadowHeightPixels * tileSize) / kTilePixels);
    ImageDrawRectangle(
        &image,
        x + (tileSize / 2) - (width / 2),
        y + tileSize - std::max(1, height / 2),
        width,
        height,
        color);
}

void drawPreviewTileDepthBase(Image& image, const RenderVisualProfile& profile, int x, int y, int tileSize, int visualHeight)
{
    if (visualHeight <= 0) {
        return;
    }

    drawPreviewProfileShadow(image, profile, x, y, tileSize, Color{0, 0, 0, 78});
    if (!profile.frontFace) {
        return;
    }

    const int faceTop = y + tileSize - visualHeight;
    ImageDrawRectangle(
        &image,
        x + std::max(1, tileSize / 12),
        faceTop,
        tileSize - std::max(2, tileSize / 6),
        visualHeight,
        profile.frontFaceColor);
}

void drawPreviewMachineDepthBase(
    Image& image,
    thoth::game::MachineKind kind,
    const RenderVisualProfile& profile,
    int x,
    int y,
    int tileSize,
    int visualHeight)
{
    if (visualHeight <= 0) {
        return;
    }

    drawPreviewProfileShadow(image, profile, x, y, tileSize, Color{0, 0, 0, 86});
    if (visualHeight <= 1) {
        return;
    }

    const auto base = machineColor(kind);
    const Color face{
        static_cast<unsigned char>((static_cast<int>(base.r) * 94) / 255),
        static_cast<unsigned char>((static_cast<int>(base.g) * 94) / 255),
        static_cast<unsigned char>((static_cast<int>(base.b) * 94) / 255),
        214};
    ImageDrawRectangle(
        &image,
        x + std::max(1, tileSize / 6),
        y + tileSize - visualHeight,
        tileSize - std::max(2, tileSize / 3),
        visualHeight,
        face);
}

void drawPreviewLine(Image& image, int x, int& y, std::string_view text, int scale, Color color)
{
    drawPreviewText(image, text, x, y, scale, color);
    y += (7 * scale) + 8;
}

bool previewMachineIssue(thoth::game::MachineStatus status)
{
    using thoth::game::MachineStatus;
    return status == MachineStatus::MissingInput ||
        status == MachineStatus::MissingFuel ||
        status == MachineStatus::MissingPower ||
        status == MachineStatus::OutputBlocked;
}

std::string previewMachineIssueBadgeText(thoth::game::MachineStatus status)
{
    using thoth::game::MachineStatus;
    switch (status) {
    case MachineStatus::MissingInput:
        return "i";
    case MachineStatus::MissingFuel:
        return "f";
    case MachineStatus::MissingPower:
        return "p";
    case MachineStatus::OutputBlocked:
        return "b";
    case MachineStatus::Idle:
    case MachineStatus::Working:
        break;
    }
    return "";
}

int renderAnimationPhase(std::uint64_t tick, int x, int y, int period)
{
    if (period <= 0) {
        return 0;
    }
    const auto offset = thoth::core::hashCoordinates(0xa7c0518e5ULL, x, y) % static_cast<std::uint64_t>(period);
    return static_cast<int>((tick + offset) % static_cast<std::uint64_t>(period));
}

bool isBeltMachine(thoth::game::MachineKind kind)
{
    return kind == thoth::game::MachineKind::Belt ||
        kind == thoth::game::MachineKind::FastBelt ||
        kind == thoth::game::MachineKind::Splitter ||
        kind == thoth::game::MachineKind::Pipe;
}

Color activityPulseColor(thoth::game::MachineKind kind)
{
    using thoth::game::MachineKind;
    switch (kind) {
    case MachineKind::BurnerMiner:
    case MachineKind::Furnace:
    case MachineKind::Generator:
        return Color{255, 158, 72, 255};
    case MachineKind::ElectricMiner:
    case MachineKind::PowerPole:
    case MachineKind::LogisticPort:
    case MachineKind::OffshorePump:
    case MachineKind::GuardTower:
    case MachineKind::OutpostBeacon:
    case MachineKind::RepairPylon:
    case MachineKind::PressureRelay:
    case MachineKind::ArcTower:
        return Color{118, 210, 255, 255};
    case MachineKind::ArchiveTerminal:
    case MachineKind::RiftGate:
        return Color{202, 164, 255, 255};
    case MachineKind::TrainStop:
        return Color{200, 200, 210, 255};
    case MachineKind::Assembler:
        return Color{118, 230, 164, 255};
    case MachineKind::Lab:
        return Color{180, 132, 238, 255};
    case MachineKind::Inserter:
    case MachineKind::CircuitInserter:
        return Color{196, 236, 226, 255};
    case MachineKind::Belt:
    case MachineKind::FastBelt:
    case MachineKind::Splitter:
    case MachineKind::Pipe:
    case MachineKind::Chest:
    case MachineKind::ProviderChest:
    case MachineKind::RequesterChest:
    case MachineKind::Workbench:
        break;
    }
    return Color{210, 220, 214, 255};
}

bool hasMachineActivityPulse(const thoth::game::Machine& machine)
{
    using thoth::game::MachineKind;
    using thoth::game::MachineStatus;
    if (isBeltMachine(machine.kind) ||
        machine.kind == MachineKind::Chest ||
        machine.kind == MachineKind::ProviderChest ||
        machine.kind == MachineKind::RequesterChest ||
        machine.kind == MachineKind::Workbench) {
        return false;
    }
    return machine.status == MachineStatus::Working ||
        machine.progress > 0 ||
        machine.fuelTicks > 0 ||
        machine.carriedItem != thoth::game::ItemId::None ||
        machine.outputItem != thoth::game::ItemId::None;
}

unsigned char pulseAlpha(std::uint64_t tick, int x, int y, int baseAlpha, int rangeAlpha)
{
    constexpr int period = 32;
    const int phase = renderAnimationPhase(tick, x, y, period);
    const int triangle = phase < (period / 2) ? phase : period - phase;
    return static_cast<unsigned char>(std::clamp(baseAlpha + ((triangle * rangeAlpha) / (period / 2)), 0, 255));
}

void drawPreviewBeltMotionOverlay(
    Image& image,
    const thoth::game::Machine& machine,
    std::uint64_t tick,
    int px,
    int py,
    int tileSize)
{
    if (!isBeltMachine(machine.kind)) {
        return;
    }

    const int period = machine.kind == thoth::game::MachineKind::FastBelt ? 6 : 8;
    const int phase = renderAnimationPhase(tick / (machine.kind == thoth::game::MachineKind::FastBelt ? 2U : 4U), machine.x, machine.y, period);
    const int travel = std::max(1, tileSize - 14);
    const int along = -travel / 2 + ((travel * phase) / std::max(1, period - 1));
    const int cx = px + (tileSize / 2) + thoth::game::dx(machine.direction) * along;
    const int cy = py + (tileSize / 2) + thoth::game::dy(machine.direction) * along;
    const int normX = -thoth::game::dy(machine.direction);
    const int normY = thoth::game::dx(machine.direction);
    const int span = std::max(5, tileSize / 4);
    const int thickness = std::max(2, tileSize / 12);
    const Color color = machine.kind == thoth::game::MachineKind::FastBelt ?
        Color{255, 248, 190, 205} :
        Color{40, 32, 24, 190};

    if (normX != 0) {
        ImageDrawRectangle(&image, cx - (span / 2), cy - (thickness / 2), span, thickness, color);
    } else if (normY != 0) {
        ImageDrawRectangle(&image, cx - (thickness / 2), cy - (span / 2), thickness, span, color);
    }
}

void drawPreviewMachineActivityOverlay(
    Image& image,
    const thoth::game::Machine& machine,
    std::uint64_t tick,
    int px,
    int py,
    int tileSize)
{
    if (!hasMachineActivityPulse(machine)) {
        return;
    }

    auto color = activityPulseColor(machine.kind);
    color.a = pulseAlpha(tick, machine.x, machine.y, 82, 84);
    const int inset = std::max(4, tileSize / 8);
    const int diode = std::max(5, tileSize / 8);
    const int railHeight = std::max(3, tileSize / 15);
    ImageDrawRectangle(&image, px + inset, py + tileSize - inset - diode, diode, diode, color);
    ImageDrawRectangle(
        &image,
        px + inset + diode + 3,
        py + tileSize - inset - railHeight,
        tileSize - (inset * 2) - diode - 3,
        railHeight,
        color);
}

void drawPreviewTileGroundBase(Image& image, thoth::game::Tile tile, int x, int y, int tileSize)
{
    ImageDrawRectangle(&image, x, y, tileSize, tileSize, toColor(thoth::game::tileDef(tile.id).color));
}

void drawPreviewTileVisual(
    Image& image,
    const Color* atlasPixels,
    thoth::game::Tile tile,
    const TileVariantEdges& edges,
    int worldX,
    int worldY,
    int x,
    int y,
    int tileSize,
    int scale,
    const RenderVisualProfile& profile)
{
    const int visualHeight = previewLiftPixels(profile, tileSize);
    drawPreviewTileDepthBase(image, profile, x, y, tileSize, visualHeight);
    drawPreviewSprite(image, atlasPixels, tileSprite(tile.id), x, y - visualHeight, scale, tileSpriteOptions(tile.id, worldX, worldY));
    drawPreviewTileVariantEdges(image, tile.id, edges, x, y, tileSize, visualHeight);
    if (tile.data > 0) {
        ImageDrawRectangle(&image, x + tileSize - 13, y + 3 - visualHeight, 10, 10, Color{10, 12, 12, 190});
        drawPreviewText(image, std::to_string(tile.data), x + tileSize - 11, y + 5 - visualHeight, 1, RAYWHITE);
    }
}

enum class PreviewRenderKind {
    RaisedTile,
    Machine,
    Player,
};

struct PreviewRenderCommand {
    PreviewRenderKind kind = PreviewRenderKind::RaisedTile;
    int sortY = 0;
    int sortX = 0;
    int priority = 0;
    int px = 0;
    int py = 0;
    int worldX = 0;
    int worldY = 0;
    thoth::game::Tile tile{};
    TileVariantEdges edges{};
    RenderVisualProfile profile{};
    const thoth::game::Machine* machine = nullptr;
};

int previewSortY(int worldY, const RenderVisualProfile& profile, int tileSize)
{
    return ((worldY + 1) * tileSize) + ((profile.sortOffsetY * tileSize) / kTilePixels);
}

void drawPreviewGrid(
    Image& image,
    const Color* atlasPixels,
    const thoth::game::Simulation& sim,
    int originX,
    int originY,
    int tileSize)
{
    int minX = sim.player().x;
    int maxX = sim.player().x;
    int minY = sim.player().y;
    int maxY = sim.player().y;
    for (const auto& machine : sim.machines()) {
        minX = std::min(minX, machine.x);
        maxX = std::max(maxX, machine.x);
        minY = std::min(minY, machine.y);
        maxY = std::max(maxY, machine.y);
    }
    --minX;
    ++maxX;
    --minY;
    ++maxY;

    const int scale = std::max(1, tileSize / kSpritePixels);
    std::vector<PreviewRenderCommand> commands;
    commands.reserve(static_cast<std::size_t>((maxX - minX + 1) * (maxY - minY + 1)) + sim.machines().size() + 1);
    for (int y = minY; y <= maxY; ++y) {
        for (int x = minX; x <= maxX; ++x) {
            const int px = originX + (x - minX) * tileSize;
            const int py = originY + (y - minY) * tileSize;
            const auto tile = sim.world().getTile(x, y);
            const auto edges = previewTileVariantEdgesAt(sim.world(), tile.id, x, y, minX, maxX, minY, maxY);
            const auto profile = tileVisualProfile(tile.id);
            if (profile.liftPixels <= 0) {
                ImageDrawRectangle(&image, px, py, tileSize, tileSize, Color{18, 22, 22, 255});
                drawPreviewTileVisual(image, atlasPixels, tile, edges, x, y, px, py, tileSize, scale, profile);
                drawPreviewRectLines(image, px, py, tileSize, tileSize, Color{0, 0, 0, 72});
            } else {
                drawPreviewTileGroundBase(image, tile, px, py, tileSize);
                drawPreviewRectLines(image, px, py, tileSize, tileSize, Color{0, 0, 0, 72});
                PreviewRenderCommand command;
                command.kind = PreviewRenderKind::RaisedTile;
                command.sortY = previewSortY(y, profile, tileSize);
                command.sortX = px;
                command.priority = 0;
                command.px = px;
                command.py = py;
                command.worldX = x;
                command.worldY = y;
                command.tile = tile;
                command.edges = edges;
                command.profile = profile;
                commands.push_back(command);
            }
        }
    }

    for (const auto& machine : sim.machines()) {
        const int px = originX + (machine.x - minX) * tileSize;
        const int py = originY + (machine.y - minY) * tileSize;
        const auto profile = machineVisualProfile(machine.kind);
        PreviewRenderCommand command;
        command.kind = PreviewRenderKind::Machine;
        command.sortY = previewSortY(machine.y, profile, tileSize);
        command.sortX = px;
        command.priority = 2;
        command.px = px;
        command.py = py;
        command.profile = profile;
        command.machine = &machine;
        commands.push_back(command);
    }

    const int playerX = originX + (sim.player().x - minX) * tileSize;
    const int playerY = originY + (sim.player().y - minY) * tileSize;
    const auto playerProfile = playerVisualProfile();
    PreviewRenderCommand playerCommand;
    playerCommand.kind = PreviewRenderKind::Player;
    playerCommand.sortY = previewSortY(sim.player().y, playerProfile, tileSize);
    playerCommand.sortX = playerX;
    playerCommand.priority = 3;
    playerCommand.px = playerX;
    playerCommand.py = playerY;
    playerCommand.profile = playerProfile;
    commands.push_back(playerCommand);

    std::stable_sort(commands.begin(), commands.end(), [](const PreviewRenderCommand& left, const PreviewRenderCommand& right) {
        if (left.sortY != right.sortY) {
            return left.sortY < right.sortY;
        }
        if (left.priority != right.priority) {
            return left.priority < right.priority;
        }
        return left.sortX < right.sortX;
    });

    for (const auto& command : commands) {
        if (command.kind == PreviewRenderKind::RaisedTile) {
            drawPreviewTileVisual(
                image,
                atlasPixels,
                command.tile,
                command.edges,
                command.worldX,
                command.worldY,
                command.px,
                command.py,
                tileSize,
                scale,
                command.profile);
            drawPreviewRectLines(image, command.px, command.py, tileSize, tileSize, Color{0, 0, 0, 72});
            continue;
        }
        if (command.kind == PreviewRenderKind::Machine && command.machine != nullptr) {
            const auto& machine = *command.machine;
            const int visualHeight = previewLiftPixels(command.profile, tileSize);
            const int visualY = command.py - visualHeight;
            drawPreviewMachineDepthBase(image, machine.kind, command.profile, command.px, command.py, tileSize, visualHeight);
            drawPreviewSprite(image, atlasPixels, machineSprite(machine.kind), command.px, visualY, scale);
            drawPreviewMachineActivityOverlay(image, machine, sim.tick(), command.px, visualY, tileSize);
            drawPreviewBeltMotionOverlay(image, machine, sim.tick(), command.px, visualY, tileSize);
            drawPreviewRectLines(image, command.px + 2, visualY + 2, tileSize - 4, tileSize - 4, statusColor(machine.status));

            const int cx = command.px + tileSize / 2;
            const int cy = visualY + tileSize / 2;
            ImageDrawLine(
                &image,
                cx,
                cy,
                cx + thoth::game::dx(machine.direction) * (tileSize / 3),
                cy + thoth::game::dy(machine.direction) * (tileSize / 3),
                Color{248, 248, 232, 230});

            if (previewMachineIssue(machine.status)) {
                const auto badge = previewMachineIssueBadgeText(machine.status);
                ImageDrawRectangle(&image, command.px + tileSize - 16, visualY + 2, 14, 12, Color{12, 14, 14, 210});
                drawPreviewText(image, badge, command.px + tileSize - 12, visualY + 5, 1, statusColor(machine.status));
            }
            continue;
        }
        if (command.kind == PreviewRenderKind::Player) {
            const int playerHeight = previewLiftPixels(command.profile, tileSize);
            drawPreviewProfileShadow(image, command.profile, command.px, command.py, tileSize, Color{0, 0, 0, 82});
            drawPreviewSprite(image, atlasPixels, SpriteId::Player, command.px, command.py - playerHeight, scale);
            drawPreviewRectLines(image, command.px + 5, command.py + 5 - playerHeight, tileSize - 10, tileSize - 10, Color{246, 248, 232, 255});
        }
    }
}

void drawPreviewSpriteStrip(Image& image, const Color* atlasPixels, int x, int y)
{
    const std::array<SpriteId, 14> sprites = {
        SpriteId::TileIronOre,
        SpriteId::MachineBurnerMiner,
        SpriteId::MachineBelt,
        SpriteId::MachineInserter,
        SpriteId::MachineFurnace,
        SpriteId::MachineChest,
        SpriteId::MachineAssembler,
        SpriteId::MachineLab,
        SpriteId::MachineGenerator,
        SpriteId::MachinePowerPole,
        SpriteId::MachineElectricMiner,
        SpriteId::ItemIronPlate,
        SpriteId::ItemSciencePack,
        SpriteId::Player,
    };
    constexpr int scale = 2;
    constexpr int spriteSize = kSpritePixels * scale;
    constexpr int gap = 8;
    for (std::size_t i = 0; i < sprites.size(); ++i) {
        const int px = x + static_cast<int>(i) * (spriteSize + gap);
        drawPreviewSprite(image, atlasPixels, sprites[i], px, y, scale);
        drawPreviewRectLines(image, px, y, spriteSize, spriteSize, Color{0, 0, 0, 110});
    }
}

bool saveMediaPreview(const std::filesystem::path& path, std::string* error)
{
    const auto replayPath = findBundledPath(kFullFlowReplayPath);
    if (!replayPath.has_value()) {
        if (error != nullptr) {
            *error = "full-flow replay not found: " + kFullFlowReplayPath.generic_string();
        }
        return false;
    }

    std::string localError;
    auto document = thoth::game::loadReplayDocument(*replayPath, &localError);
    if (!document.has_value()) {
        if (error != nullptr) {
            *error = "failed to load full-flow replay: " + localError;
        }
        return false;
    }
    auto simulation = thoth::game::runReplayDocument(*document);
    if (!validateFullFlowReplay(simulation, *document, &localError)) {
        if (error != nullptr) {
            *error = "full-flow replay failed validation: " + localError;
        }
        return false;
    }

    Image atlas{};
    if (!makeAuthoredAtlasImage(atlas, error)) {
        return false;
    }
    Color* atlasPixels = LoadImageColors(atlas);
    if (atlasPixels == nullptr) {
        UnloadImage(atlas);
        if (error != nullptr) {
            *error = "failed to read authored atlas pixels";
        }
        return false;
    }

    Image preview = GenImageColor(960, 540, Color{14, 18, 20, 255});
    drawPreviewText(preview, "Thoth full-flow replay preview", 28, 24, 3, Color{232, 238, 232, 255});
    drawPreviewText(preview, "mining -> first automation -> science -> research -> electric mining", 30, 55, 2, Color{154, 172, 168, 255});

    ImageDrawRectangle(&preview, 22, 82, 406, 360, Color{24, 30, 30, 255});
    drawPreviewRectLines(preview, 22, 82, 406, 360, Color{54, 66, 64, 255});
    drawPreviewGrid(preview, atlasPixels, simulation, 34, 98, 48);

    ImageDrawRectangle(&preview, 452, 82, 470, 360, Color{24, 30, 30, 255});
    drawPreviewRectLines(preview, 452, 82, 470, 360, Color{54, 66, 64, 255});
    int y = 104;
    drawPreviewLine(preview, 476, y, "Deterministic artifact", 2, Color{232, 238, 232, 255});
    drawPreviewLine(preview, 476, y, "replay: " + kFullFlowReplayPath.generic_string(), 1, Color{170, 188, 184, 255});
    drawPreviewLine(preview, 476, y, "tick: " + std::to_string(simulation.tick()) +
        " / machines: " + std::to_string(simulation.machines().size()), 1, RAYWHITE);

    const auto* firstChest = simulation.machineAt(5, 0);
    const auto* poweredChest = simulation.machineAt(3, 4);
    const int plates = firstChest == nullptr ? 0 : firstChest->inventory.count(thoth::game::ItemId::IronPlate);
    const int poweredOre = poweredChest == nullptr ? 0 : poweredChest->inventory.count(thoth::game::ItemId::IronOre);
    drawPreviewLine(preview, 476, y, "first line iron plates: " + std::to_string(plates), 1, Color{198, 205, 196, 255});
    drawPreviewLine(preview, 476, y, "powered miner iron ore: " + std::to_string(poweredOre), 1, Color{171, 132, 96, 255});
    drawPreviewLine(preview, 476, y, "logistics_1: " +
        std::string(simulation.isTechCompleted("logistics_1") ? "complete" : "incomplete"), 1, Color{118, 210, 255, 255});

    int supply = 0;
    int demand = 0;
    int poweredNetworks = 0;
    for (const auto& network : simulation.powerNetworks()) {
        supply += network.supply;
        demand += network.demand;
        if (network.powered) {
            ++poweredNetworks;
        }
    }
    drawPreviewLine(preview, 476, y, "power: supply " + std::to_string(supply) +
        " demand " + std::to_string(demand) +
        " powered networks " + std::to_string(poweredNetworks), 1, Color{124, 218, 255, 255});
    y += 8;
    drawPreviewLine(preview, 476, y, "Review hooks", 2, Color{232, 238, 232, 255});
    drawPreviewLine(preview, 476, y, "make cpp-validate-assets", 1, Color{206, 220, 214, 255});
    drawPreviewLine(preview, 476, y, "make cpp-validate-replays", 1, Color{206, 220, 214, 255});
    drawPreviewLine(preview, 476, y, "F10 loads this replay, F11 auditions cues", 1, Color{206, 220, 214, 255});

    ImageDrawRectangle(&preview, 22, 462, 900, 54, Color{24, 30, 30, 255});
    drawPreviewRectLines(preview, 22, 462, 900, 54, Color{54, 66, 64, 255});
    drawPreviewSpriteStrip(preview, atlasPixels, 36, 473);

    if (path.has_parent_path()) {
        std::error_code ec;
        std::filesystem::create_directories(path.parent_path(), ec);
        if (ec) {
            UnloadImageColors(atlasPixels);
            UnloadImage(atlas);
            UnloadImage(preview);
            if (error != nullptr) {
                *error = "failed to create preview directory: " + ec.message();
            }
            return false;
        }
    }

    const bool saved = ExportImage(preview, path.string().c_str());
    UnloadImageColors(atlasPixels);
    UnloadImage(atlas);
    UnloadImage(preview);
    if (!saved && error != nullptr) {
        *error = "failed to export media preview";
    }
    return saved;
}

bool saveWindowSmokeScreenshot(const std::filesystem::path& path, std::string* error)
{
    const auto replayPath = findBundledPath(kFullFlowReplayPath);
    if (!replayPath.has_value()) {
        if (error != nullptr) {
            *error = "full-flow replay not found: " + kFullFlowReplayPath.generic_string();
        }
        return false;
    }

    std::string localError;
    auto document = thoth::game::loadReplayDocument(*replayPath, &localError);
    if (!document.has_value()) {
        if (error != nullptr) {
            *error = "failed to load full-flow replay: " + localError;
        }
        return false;
    }
    auto simulation = thoth::game::runReplayDocument(*document);
    if (!validateFullFlowReplay(simulation, *document, &localError)) {
        if (error != nullptr) {
            *error = "full-flow replay failed validation: " + localError;
        }
        return false;
    }

    if (path.has_parent_path()) {
        std::error_code ec;
        std::filesystem::create_directories(path.parent_path(), ec);
        if (ec) {
            if (error != nullptr) {
                *error = "failed to create window smoke directory: " + ec.message();
            }
            return false;
        }
    }

    InitWindow(kScreenWidth, kScreenHeight, "Thoth - window smoke");
    if (!IsWindowReady()) {
        CloseWindow();
        if (error != nullptr) {
            *error = "failed to initialize raylib window for smoke screenshot";
        }
        return false;
    }
    SetTargetFPS(60);

    AppState state;
    state.status = "window smoke: full-flow replay";
    state.debug = false;
    state.craftMenuOpen = false;
    state.inventoryOpen = false;
    auto visuals = loadVisualAtlas();
    gVisualAtlas = &visuals;
    auto audio = loadAudioBank();
    state.audioSource = audio.source;
    syncProductionCounters(simulation, state);
    syncMachineIssueCounters(simulation, state);
    updatePlayerVisual(simulation, state);

    Camera2D camera{};
    camera.offset = Vector2{kScreenWidth * 0.5f, kScreenHeight * 0.5f};
    camera.target = Vector2{
        (state.renderPlayerX * static_cast<float>(kTilePixels)) + (static_cast<float>(kTilePixels) * 0.5f),
        (state.renderPlayerY * static_cast<float>(kTilePixels)) + (static_cast<float>(kTilePixels) * 0.5f)};
    camera.zoom = 1.0f;

    bool saved = false;
    Image screenshot{};
    for (int frame = 0; frame < 3; ++frame) {
        BeginDrawing();
        ClearBackground(Color{16, 18, 18, 255});
        BeginMode2D(camera);
        drawWorld(simulation, state);
        EndMode2D();
        drawHud(simulation, state);
        if (frame == 2) {
            screenshot = LoadImageFromScreen();
        }
        EndDrawing();
    }

    std::string saveError;
    if (screenshot.data == nullptr || screenshot.width <= 0 || screenshot.height <= 0) {
        saveError = "failed to capture window smoke screenshot";
    } else if (screenshot.width != kScreenWidth || screenshot.height != kScreenHeight) {
        saveError = "window smoke screenshot size mismatch: expected " + std::to_string(kScreenWidth) + "x" + std::to_string(kScreenHeight) +
            ", got " + std::to_string(screenshot.width) + "x" + std::to_string(screenshot.height);
    } else {
        saved = ExportImage(screenshot, path.string().c_str());
        if (!saved) {
            saveError = "failed to save window smoke screenshot";
        }
    }
    if (screenshot.data != nullptr) {
        UnloadImage(screenshot);
    }

    gVisualAtlas = nullptr;
    unloadVisualAtlas(visuals);
    unloadAudioBank(audio);
    CloseWindow();

    if (!saved && error != nullptr) {
        *error = saveError.empty() ? "failed to save window smoke screenshot" : saveError;
    }
    return saved;
}


} // namespace thoth::app
