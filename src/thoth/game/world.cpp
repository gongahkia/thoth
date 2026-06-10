#include "thoth/game/world.hpp"

#include "thoth/core/deterministic_random.hpp"

#include <algorithm>
#include <cstdlib>

namespace thoth::game {

namespace {

constexpr int kRiftOffset = 4096;

bool inside(int value, int min, int max)
{
    return value >= min && value <= max;
}

struct PatchHit {
    bool hit = false;
    std::uint64_t hash = 0;
    int distanceSquared = 0;
    int radius = 0;
};

enum class BiomeKind {
    Grassland,
    Desert,
    Snowfield,
    Marsh,
};

int resourceRichness(std::uint64_t seed, int x, int y)
{
    const auto richness = thoth::core::hashCoordinates(seed ^ 0x51c3a5edULL, x, y);
    const int distanceBonus = std::min(8, (std::abs(x) + std::abs(y)) / 64);
    return 4 + static_cast<int>(richness % 5U) + distanceBonus;
}

PatchHit findPatch(std::uint64_t seed, int x, int y, int cellSize, int chance, int minRadius, int maxRadius)
{
    PatchHit best;
    best.distanceSquared = 1'000'000'000;
    const int cellX = floorDiv(x, cellSize);
    const int cellY = floorDiv(y, cellSize);
    const int jitter = std::max(1, cellSize / 3);
    const int radiusRange = std::max(1, maxRadius - minRadius + 1);

    for (int cy = cellY - 1; cy <= cellY + 1; ++cy) {
        for (int cx = cellX - 1; cx <= cellX + 1; ++cx) {
            const auto hash = thoth::core::hashCoordinates(seed, cx, cy);
            if (static_cast<int>(hash % 1000U) >= chance) {
                continue;
            }
            const int centerX = (cx * cellSize) + (cellSize / 2) +
                static_cast<int>((hash >> 12U) % static_cast<std::uint64_t>((jitter * 2) + 1)) - jitter;
            const int centerY = (cy * cellSize) + (cellSize / 2) +
                static_cast<int>((hash >> 28U) % static_cast<std::uint64_t>((jitter * 2) + 1)) - jitter;
            const int radius = minRadius + static_cast<int>((hash >> 44U) % static_cast<std::uint64_t>(radiusRange));
            const int dx = x - centerX;
            const int dy = y - centerY;
            const int distanceSquared = (dx * dx) + (dy * dy);
            if (distanceSquared > radius * radius || distanceSquared >= best.distanceSquared) {
                continue;
            }
            const auto edge = thoth::core::hashCoordinates(seed ^ 0x7061746368ULL, x, y);
            if (distanceSquared > (radius - 1) * (radius - 1) && (edge % 1000U) < 460U) {
                continue;
            }
            best = PatchHit{true, hash, distanceSquared, radius};
        }
    }
    return best;
}

bool sparsePatchDetail(std::uint64_t seed, int x, int y, int threshold)
{
    return static_cast<int>(thoth::core::hashCoordinates(seed, x, y) % 1000U) < threshold;
}

void selectBiome(PatchHit hit, BiomeKind candidate, PatchHit& bestHit, BiomeKind& biome)
{
    if (hit.hit && (!bestHit.hit || hit.distanceSquared < bestHit.distanceSquared)) {
        bestHit = hit;
        biome = candidate;
    }
}

BiomeKind biomeAt(std::uint64_t seed, int x, int y)
{
    if (inside(x, 10, 24) && inside(y, -12, 8)) {
        return BiomeKind::Desert;
    }
    if (inside(x, -24, -10) && inside(y, -10, 10)) {
        return BiomeKind::Snowfield;
    }
    if (inside(x, -8, 8) && inside(y, 8, 22)) {
        return BiomeKind::Marsh;
    }

    PatchHit bestHit;
    BiomeKind biome = BiomeKind::Grassland;
    selectBiome(findPatch(seed ^ 0x646573657274ULL, x, y, 68, 165, 11, 22), BiomeKind::Desert, bestHit, biome);
    selectBiome(findPatch(seed ^ 0x736e6f776669656cULL, x, y, 72, 150, 12, 24), BiomeKind::Snowfield, bestHit, biome);
    selectBiome(findPatch(seed ^ 0x6d61727368ULL, x, y, 58, 145, 10, 19), BiomeKind::Marsh, bestHit, biome);
    return biome;
}

int treeDetailThreshold(BiomeKind biome)
{
    switch (biome) {
    case BiomeKind::Desert:
        return 220;
    case BiomeKind::Snowfield:
        return 420;
    case BiomeKind::Marsh:
        return 740;
    case BiomeKind::Grassland:
        return 560;
    }
    return 560;
}

TileId baseTerrain(BiomeKind biome, std::uint64_t terrain)
{
    const int roll = static_cast<int>(terrain % 1000U);
    switch (biome) {
    case BiomeKind::Desert:
        return roll < 880 ? TileId::Sand : TileId::Dirt;
    case BiomeKind::Snowfield:
        return roll < 850 ? TileId::Snow : TileId::Grass;
    case BiomeKind::Marsh:
        if (roll < 720) {
            return TileId::Mud;
        }
        return roll < 900 ? TileId::Grass : TileId::Dirt;
    case BiomeKind::Grassland:
        return roll < 230 ? TileId::Dirt : TileId::Grass;
    }
    return TileId::Grass;
}

} // namespace

int floorDiv(int value, int divisor)
{
    int quotient = value / divisor;
    const int remainder = value % divisor;
    if (remainder != 0 && ((remainder < 0) != (divisor < 0))) {
        --quotient;
    }
    return quotient;
}

int floorMod(int value, int divisor)
{
    const int result = value % divisor;
    return result < 0 ? result + std::abs(divisor) : result;
}

World::World(std::uint64_t seed)
    : seed_(seed)
{
}

std::uint64_t World::seed() const
{
    return seed_;
}

Tile World::getTile(int x, int y)
{
    const auto& chunk = chunkForTile(x, y);
    return chunk.tiles[static_cast<std::size_t>(floorMod(y, kChunkSize) * kChunkSize + floorMod(x, kChunkSize))];
}

const Tile World::getTile(int x, int y) const
{
    const auto& chunk = chunkForTile(x, y);
    return chunk.tiles[static_cast<std::size_t>(floorMod(y, kChunkSize) * kChunkSize + floorMod(x, kChunkSize))];
}

void World::setTile(int x, int y, Tile tile)
{
    auto& chunk = chunkForTile(x, y);
    chunk.tiles[static_cast<std::size_t>(floorMod(y, kChunkSize) * kChunkSize + floorMod(x, kChunkSize))] = tile;
}

bool World::isWalkable(int x, int y)
{
    return game::isWalkable(getTile(x, y).id);
}

std::size_t World::loadedChunkCount() const
{
    return chunks_.size();
}

std::vector<TileSnapshot> World::loadedTiles() const
{
    std::vector<TileSnapshot> tiles;
    tiles.reserve(chunks_.size() * kChunkSize * kChunkSize);

    for (const auto& entry : chunks_) {
        const auto& chunk = entry.second;
        for (int localY = 0; localY < kChunkSize; ++localY) {
            for (int localX = 0; localX < kChunkSize; ++localX) {
                const int x = (chunk.cx * kChunkSize) + localX;
                const int y = (chunk.cy * kChunkSize) + localY;
                const auto tile = chunk.tiles[static_cast<std::size_t>(localY * kChunkSize + localX)];
                tiles.push_back(TileSnapshot{x, y, tile});
            }
        }
    }

    std::sort(tiles.begin(), tiles.end(), [](const TileSnapshot& left, const TileSnapshot& right) {
        if (left.y == right.y) {
            return left.x < right.x;
        }
        return left.y < right.y;
    });
    return tiles;
}

void World::clearLoadedChunks()
{
    chunks_.clear();
}

Chunk& World::chunkForTile(int x, int y)
{
    const int cx = floorDiv(x, kChunkSize);
    const int cy = floorDiv(y, kChunkSize);
    const auto key = chunkKey(cx, cy);
    auto it = chunks_.find(key);
    if (it == chunks_.end()) {
        it = chunks_.emplace(key, generateChunk(cx, cy)).first;
    }
    return it->second;
}

const Chunk& World::chunkForTile(int x, int y) const
{
    const int cx = floorDiv(x, kChunkSize);
    const int cy = floorDiv(y, kChunkSize);
    const auto key = chunkKey(cx, cy);
    auto it = chunks_.find(key);
    if (it == chunks_.end()) {
        it = chunks_.emplace(key, generateChunk(cx, cy)).first;
    }
    return it->second;
}

Chunk World::generateChunk(int cx, int cy) const
{
    Chunk chunk;
    chunk.cx = cx;
    chunk.cy = cy;

    for (int localY = 0; localY < kChunkSize; ++localY) {
        for (int localX = 0; localX < kChunkSize; ++localX) {
            const int worldX = (cx * kChunkSize) + localX;
            const int worldY = (cy * kChunkSize) + localY;
            chunk.tiles[static_cast<std::size_t>(localY * kChunkSize + localX)] = generateTile(worldX, worldY);
        }
    }

    return chunk;
}

Tile World::generateTile(int x, int y) const
{
    if ((x == -5 || x == -4 || x == -3) && inside(y, -3, 3)) {
        return Tile{TileId::Tree, 1};
    }
    if (inside(x, -2, 3) && y == 4) {
        return Tile{TileId::Stone, 1};
    }
    if (x == 4 && inside(y, -2, 2)) {
        return Tile{TileId::IronOre, 6};
    }
    if (x == 6 && inside(y, -2, 2)) {
        return Tile{TileId::CoalOre, 6};
    }
    if (x == 8 && inside(y, -2, 2)) {
        return Tile{TileId::CopperOre, 6};
    }
    if (inside(x, -2, 9) && inside(y, -3, 3)) {
        return Tile{TileId::Grass, 0};
    }

    if (std::abs(x) >= kRiftOffset - 256) {
        const auto rift = thoth::core::hashCoordinates(seed_ ^ 0x72696674ULL, x / 2, y / 2);
        if (static_cast<int>(rift % 1000U) < 130) {
            return Tile{TileId::Water, 0};
        }
        if (static_cast<int>((rift >> 10U) % 1000U) < 180) {
            return Tile{TileId::CopperOre, resourceRichness(seed_ ^ 0x72696674ULL, x, y) + 4};
        }
        if (static_cast<int>((rift >> 20U) % 1000U) < 180) {
            return Tile{TileId::IronOre, resourceRichness(seed_ ^ 0x72696674ULL, x, y) + 4};
        }
        if (static_cast<int>((rift >> 30U) % 1000U) < 120) {
            return Tile{TileId::CoalOre, resourceRichness(seed_ ^ 0x72696674ULL, x, y) + 4};
        }
        if (static_cast<int>((rift >> 40U) % 1000U) < 520) {
            return Tile{TileId::Stone, 2};
        }
        return Tile{TileId::Dirt, 0};
    }

    const auto biome = biomeAt(seed_, x, y);

    const auto water = findPatch(seed_ ^ 0x7761746572ULL, x, y, 22, 180, 3, 6);
    if (water.hit) {
        return Tile{TileId::Water, 0};
    }

    const auto iron = findPatch(seed_ ^ 0x69726f6eULL, x, y, 30, 110, 3, 5);
    if (iron.hit) {
        return Tile{TileId::IronOre, resourceRichness(seed_, x, y)};
    }
    const auto copper = findPatch(seed_ ^ 0x636f70706572ULL, x, y, 30, 105, 3, 5);
    if (copper.hit) {
        return Tile{TileId::CopperOre, resourceRichness(seed_, x, y)};
    }
    const auto coal = findPatch(seed_ ^ 0x636f616cULL, x, y, 28, 105, 3, 5);
    if (coal.hit) {
        return Tile{TileId::CoalOre, resourceRichness(seed_, x, y)};
    }

    if (biome == BiomeKind::Marsh &&
        sparsePatchDetail(seed_ ^ 0x626f677761746572ULL, x, y, 150)) {
        return Tile{TileId::Water, 0};
    }

    const auto stone = findPatch(seed_ ^ 0x73746f6e65ULL, x, y, 18, 210, 2, 4);
    if (stone.hit && sparsePatchDetail(seed_ ^ 0x726f636bULL, x, y, 780)) {
        return Tile{TileId::Stone, 1};
    }

    const auto trees = findPatch(seed_ ^ 0x7472656573ULL, x, y, 18, 260, 3, 6);
    if (trees.hit && sparsePatchDetail(seed_ ^ 0x67726f7665ULL, x, y, treeDetailThreshold(biome))) {
        return Tile{TileId::Tree, 1};
    }

    const auto terrain = thoth::core::hashCoordinates(seed_ ^ 0x62617365ULL, floorDiv(x, 5), floorDiv(y, 5));
    return Tile{baseTerrain(biome, terrain), 0};
}

std::uint64_t World::chunkKey(int cx, int cy)
{
    return (static_cast<std::uint64_t>(static_cast<std::uint32_t>(cx)) << 32U) |
        static_cast<std::uint32_t>(cy);
}

} // namespace thoth::game
