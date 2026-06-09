#pragma once

#include <cstdint>

namespace thoth::core {

class DeterministicRandom {
public:
    explicit DeterministicRandom(std::uint64_t seed);

    [[nodiscard]] std::uint32_t nextU32();
    [[nodiscard]] int range(int minInclusive, int maxInclusive);
    [[nodiscard]] float unit();
    [[nodiscard]] std::uint64_t state() const;

private:
    std::uint64_t state_;
};

[[nodiscard]] std::uint64_t mix64(std::uint64_t value);
[[nodiscard]] std::uint64_t hashCoordinates(std::uint64_t seed, int x, int y);

} // namespace thoth::core
