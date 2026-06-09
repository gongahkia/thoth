#include "thoth/core/deterministic_random.hpp"

#include <algorithm>
#include <limits>

namespace thoth::core {

std::uint64_t mix64(std::uint64_t value)
{
    value += 0x9e3779b97f4a7c15ULL;
    value = (value ^ (value >> 30U)) * 0xbf58476d1ce4e5b9ULL;
    value = (value ^ (value >> 27U)) * 0x94d049bb133111ebULL;
    return value ^ (value >> 31U);
}

std::uint64_t hashCoordinates(std::uint64_t seed, int x, int y)
{
    auto value = seed;
    value ^= mix64(static_cast<std::uint64_t>(static_cast<std::uint32_t>(x)) << 1U);
    value ^= mix64(static_cast<std::uint64_t>(static_cast<std::uint32_t>(y)) << 33U);
    return mix64(value);
}

DeterministicRandom::DeterministicRandom(std::uint64_t seed)
    : state_(seed)
{
}

std::uint32_t DeterministicRandom::nextU32()
{
    state_ = mix64(state_);
    return static_cast<std::uint32_t>(state_ >> 32U);
}

int DeterministicRandom::range(int minInclusive, int maxInclusive)
{
    if (minInclusive > maxInclusive) {
        std::swap(minInclusive, maxInclusive);
    }
    const auto span = static_cast<std::uint32_t>(maxInclusive - minInclusive + 1);
    return minInclusive + static_cast<int>(nextU32() % span);
}

float DeterministicRandom::unit()
{
    constexpr auto denominator = static_cast<float>(std::numeric_limits<std::uint32_t>::max());
    return static_cast<float>(nextU32()) / denominator;
}

std::uint64_t DeterministicRandom::state() const
{
    return state_;
}

} // namespace thoth::core
