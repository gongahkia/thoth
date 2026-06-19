# Modding Hooks

Status: opt-in Lua table overrides.

## Registry Overrides

Load registry overrides before creating a `Simulation`.

```lua
package.path = "./?.lua;./?/init.lua;./src/?.lua;./src/?/init.lua;" .. package.path

local Defs = require("src.game.defs")

assert(Defs.applyRegistryOverrides({
    items = {
        mod_ledger_coin = {
            name = "Ledger Coin",
            stack = 9,
            value = 3,
            taxonomy = "salvage",
        },
    },
    itemOrder = { "mod_ledger_coin" },
}))
```

Rules:

- Map categories, such as `items`, `trinkets`, `skills`, and `panelCopy`, merge by key.
- Order categories ending in `Order`, such as `itemOrder`, append unique string IDs.
- Existing keys can be replaced by assigning the same key in a map category.
- Unknown categories return `false, err`.
- Overrides are process-local and should be loaded before saves, replays, or simulations.

Constraints:

- Keep new IDs namespaced, for example `mod_<name>_<thing>`.
- Add matching order entries for player-facing registries.
- Add referenced dependencies in the same override batch, for example a new skill and its class entry.
- Asset overrides still need license entries in `docs/asset-licenses.md`.
