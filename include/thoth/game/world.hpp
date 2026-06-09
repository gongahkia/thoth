#pragma once

#include "thoth/game/registry.hpp"

#include <array>
#include <cstddef>
#include <cstdint>
#include <unordered_map>
#include <vector>

namespace thoth::game {

inline constexpr int kChunkSize = 32;

struct Tile {
    TileId id = TileId::Grass;
    int data = 0;
};

struct Chunk {
    int cx = 0;
    int cy = 0;
    std::array<Tile, kChunkSize * kChunkSize> tiles{};
};

struct TileSnapshot {
    int x = 0;
    int y = 0;
    Tile tile{};
};

class World {
public:
    explicit World(std::uint64_t seed);

    [[nodiscard]] std::uint64_t seed() const;
    [[nodiscard]] Tile getTile(int x, int y);
    [[nodiscard]] const Tile getTile(int x, int y) const;
    void setTile(int x, int y, Tile tile);
    [[nodiscard]] bool isWalkable(int x, int y);
    [[nodiscard]] std::size_t loadedChunkCount() const;
    [[nodiscard]] std::vector<TileSnapshot> loadedTiles() const;
    void clearLoadedChunks();

private:
    [[nodiscard]] Chunk& chunkForTile(int x, int y);
    [[nodiscard]] const Chunk& chunkForTile(int x, int y) const;
    [[nodiscard]] Chunk generateChunk(int cx, int cy) const;
    [[nodiscard]] Tile generateTile(int x, int y) const;
    [[nodiscard]] static std::uint64_t chunkKey(int cx, int cy);

    std::uint64_t seed_;
    mutable std::unordered_map<std::uint64_t, Chunk> chunks_;
};

[[nodiscard]] int floorDiv(int value, int divisor);
[[nodiscard]] int floorMod(int value, int divisor);

} // namespace thoth::game
