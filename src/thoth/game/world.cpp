#include "thoth/game/world.hpp"

#include "thoth/core/deterministic_random.hpp"

#include <algorithm>
#include <cstdlib>

namespace thoth::game {

namespace {

bool inside(int value, int min, int max)
{
    return value >= min && value <= max;
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
    if (inside(x, -2, 2) && inside(y, -2, 2)) {
        return Tile{TileId::Grass, 0};
    }
    if (x == -4 && inside(y, -2, 2)) {
        return Tile{TileId::Tree, 1};
    }
    if (x == 4 && inside(y, -2, 2)) {
        return Tile{TileId::IronOre, 1};
    }
    if (x == 6 && inside(y, -2, 2)) {
        return Tile{TileId::CoalOre, 1};
    }

    const auto terrain = thoth::core::hashCoordinates(seed_, x, y);
    const auto feature = thoth::core::hashCoordinates(seed_ ^ 0xa51cedULL, x / 3, y / 3);
    const int terrainRoll = static_cast<int>(terrain % 1000U);
    const int featureRoll = static_cast<int>(feature % 1000U);

    if (terrainRoll < 65) {
        return Tile{TileId::Water, 0};
    }
    if (featureRoll < 35) {
        return Tile{TileId::IronOre, 1};
    }
    if (featureRoll >= 35 && featureRoll < 70) {
        return Tile{TileId::CoalOre, 1};
    }
    if (terrainRoll > 900) {
        return Tile{TileId::Tree, 1};
    }
    if (terrainRoll > 760) {
        return Tile{TileId::Stone, 1};
    }
    if (terrainRoll > 650) {
        return Tile{TileId::Dirt, 0};
    }
    return Tile{TileId::Grass, 0};
}

std::uint64_t World::chunkKey(int cx, int cy)
{
    return (static_cast<std::uint64_t>(static_cast<std::uint32_t>(cx)) << 32U) |
        static_cast<std::uint32_t>(cy);
}

} // namespace thoth::game
