#pragma once

#include "thoth/game/registry.hpp"

#include <vector>

namespace thoth::game {

class Inventory {
public:
    [[nodiscard]] bool add(ItemId item, int count);
    [[nodiscard]] bool consume(ItemId item, int count);
    [[nodiscard]] bool canConsume(ItemId item, int count) const;
    [[nodiscard]] bool canConsumeAll(const std::vector<ItemStack>& stacks) const;
    [[nodiscard]] bool consumeAll(const std::vector<ItemStack>& stacks);
    [[nodiscard]] int count(ItemId item) const;
    [[nodiscard]] std::vector<ItemStack> stacks() const;
    void clear();

private:
    std::vector<ItemStack> stacks_;
};

} // namespace thoth::game
