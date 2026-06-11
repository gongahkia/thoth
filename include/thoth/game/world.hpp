#pragma once

#include "thoth/game/registry.hpp"

#include <array>
#include <cstddef>
#include <cstdint>
#include <optional>
#include <string_view>
#include <unordered_map>
#include <vector>

namespace thoth::game {

inline constexpr int kChunkSize = 32;

enum class BiomeKind : std::uint8_t {
    Grassland,
    Desert,
    Snowfield,
    Marsh,
    Badlands,
    CrystalField,
    Rift,
};

enum class LairKind : std::uint8_t {
    MarshHive,
    BadlandsFoundry,
    CrystalVault,
};

struct Tile {
    TileId id = TileId::Grass;
    int data = 0;
};

struct Chunk {
    int cx = 0;
    int cy = 0;
    int z = 0;
    std::array<Tile, kChunkSize * kChunkSize> tiles{};
};

struct TileSnapshot {
    int x = 0;
    int y = 0;
    Tile tile{};
    int z = 0;
};

class World {
public:
    explicit World(std::uint64_t seed);

    [[nodiscard]] std::uint64_t seed() const;
    [[nodiscard]] Tile getTile(int x, int y);
    [[nodiscard]] Tile getTile(int x, int y, int z);
    [[nodiscard]] const Tile getTile(int x, int y) const;
    [[nodiscard]] const Tile getTile(int x, int y, int z) const;
    void setTile(int x, int y, Tile tile);
    void setTile(int x, int y, int z, Tile tile);
    [[nodiscard]] bool isWalkable(int x, int y);
    [[nodiscard]] bool isWalkable(int x, int y, int z);
    [[nodiscard]] bool isWalkable(int x, int y) const;
    [[nodiscard]] bool isWalkable(int x, int y, int z) const;
    [[nodiscard]] BiomeKind biomeAt(int x, int y, int z = 0) const;
    [[nodiscard]] std::optional<LairKind> lairAt(int x, int y, int z = 0) const;
    [[nodiscard]] std::size_t loadedChunkCount() const;
    [[nodiscard]] std::vector<TileSnapshot> loadedTiles() const;
    void clearLoadedChunks();

private:
    [[nodiscard]] Chunk& chunkForTile(int x, int y, int z);
    [[nodiscard]] const Chunk& chunkForTile(int x, int y, int z) const;
    [[nodiscard]] Chunk generateChunk(int cx, int cy, int z) const;
    [[nodiscard]] Tile generateTile(int x, int y, int z) const;
    [[nodiscard]] static std::uint64_t chunkKey(int cx, int cy, int z);

    std::uint64_t seed_;
    mutable std::unordered_map<std::uint64_t, Chunk> chunks_;
};

[[nodiscard]] int floorDiv(int value, int divisor);
[[nodiscard]] int floorMod(int value, int divisor);
[[nodiscard]] std::string_view toString(BiomeKind biome);
[[nodiscard]] std::string_view toString(LairKind lair);

} // namespace thoth::game
