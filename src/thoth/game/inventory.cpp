#include "thoth/game/inventory.hpp"

#include <algorithm>

namespace thoth::game {

bool Inventory::add(ItemId item, int count)
{
    if (item == ItemId::None || count <= 0) {
        return false;
    }

    for (auto& stack : stacks_) {
        if (stack.item == item) {
            stack.count += count;
            return true;
        }
    }

    stacks_.push_back(ItemStack{item, count});
    return true;
}

bool Inventory::consume(ItemId item, int count)
{
    if (!canConsume(item, count)) {
        return false;
    }

    for (auto& stack : stacks_) {
        if (stack.item == item) {
            stack.count -= count;
            break;
        }
    }

    stacks_.erase(
        std::remove_if(stacks_.begin(), stacks_.end(), [](const ItemStack& stack) {
            return stack.count <= 0;
        }),
        stacks_.end());
    return true;
}

bool Inventory::canConsume(ItemId item, int count) const
{
    if (item == ItemId::None || count <= 0) {
        return true;
    }
    return this->count(item) >= count;
}

bool Inventory::canConsumeAll(const std::vector<ItemStack>& stacks) const
{
    for (const auto& stack : stacks) {
        if (!canConsume(stack.item, stack.count)) {
            return false;
        }
    }
    return true;
}

bool Inventory::consumeAll(const std::vector<ItemStack>& stacks)
{
    if (!canConsumeAll(stacks)) {
        return false;
    }

    for (const auto& stack : stacks) {
        if (!consume(stack.item, stack.count)) {
            return false;
        }
    }
    return true;
}

int Inventory::count(ItemId item) const
{
    for (const auto& stack : stacks_) {
        if (stack.item == item) {
            return stack.count;
        }
    }
    return 0;
}

std::vector<ItemStack> Inventory::stacks() const
{
    std::vector<ItemStack> stable;
    for (const auto& def : itemDefs()) {
        const int amount = count(def.id);
        if (amount > 0) {
            stable.push_back(ItemStack{def.id, amount});
        }
    }
    return stable;
}

void Inventory::clear()
{
    stacks_.clear();
}

} // namespace thoth::game
