# thoth v4 migration guide

`thoth` v4 removes all `src.*` entrypoints.

Use the following import map:

| legacy import | v4 import |
| --- | --- |
| `src.cache` | `thoth.core.cache` |
| `src.events` | `thoth.core.events` |
| `src.graphs` | `thoth.core.graphs` |
| `src.heaps` | `thoth.core.heaps` |
| `src.links` | `thoth.core.links` |
| `src.math` | `thoth.core.math` |
| `src.math2D` | `thoth.core.math2D` |
| `src.performance` | `thoth.core.performance` |
| `src.queues` | `thoth.core.queues` |
| `src.serialize` | `thoth.core.serialize` |
| `src.stacks` | `thoth.core.stacks` |
| `src.stringify` | `thoth.core.stringify` |
| `src.tables` | `thoth.core.tables` |
| `src.trees` | `thoth.core.trees` |
| `src.tries` | `thoth.core.tries` |
| `src.validate` | `thoth.core.validate` |
| `src.Love2DAnimation` | `thoth.game.tween` + `thoth.adapters.love2d` |
| `src.Love2DCollision` | `thoth.game.spatial` |
| `src.Love2DDraw` | framework-native rendering + `thoth.adapters.love2d` |
| `src.Love2DEcs` | `thoth.game.runtime` |
| `src.Love2DInput` | `thoth.game.input` + `thoth.adapters.love2d` |
| `src.Love2DPointIn` | `thoth.game.spatial` |
| `src.Love2DStates` | `thoth.game.state` + `thoth.game.runtime` |

## namespace quick reference

- `thoth.core.*`: data structures, algorithms, serialization, validation, utilities
- `thoth.game.*`: runtime, input, tasks, tweening, spatial, pathfinding
- `thoth.adapters.*`: framework integration adapters
