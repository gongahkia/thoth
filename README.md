[![](https://img.shields.io/badge/thoth_1.0.0-passing-%23004D00)](https://github.com/gongahkia/thoth/releases/tag/1.0.0)
[![](https://img.shields.io/badge/thoth_2.0.0-passing-%23228B22)](https://github.com/gongahkia/thoth/releases/tag/2.0.0)
[![](https://img.shields.io/badge/thoth_3.0.0-passing-%2332CD32)](https://github.com/gongahkia/thoth/releases/tag/3.0.0)
[![](https://img.shields.io/badge/thoth_4.0.0-passing-%233CB371)](https://github.com/gongahkia/thoth/releases/tag/4.0.0)
![](https://github.com/gongahkia/thoth/actions/workflows/ci.yml/badge.svg)

<h1 align='center'><code>Thoth</code></h1>
<div align='center'>
<p>
  <i>Functional lua pocket knife.</i>
</p>
<img src='https://github.com/gongahkia/thoth/assets/117062305/276628d5-aefa-442c-ad3e-5df51b4357b3' width=50% height=50%></img>
</div>

## Rationale

`Thoth` is a [Lua](https://www.lua.org/) library for [deterministic](https://dictionary.cambridge.org/dictionary/english/deterministic) [real-time systems](https://www.intel.com/content/www/us/en/learn/what-is-a-real-time-system.html), served in [2 layers](#thoth-provides).

## Installation

```console
$ luarocks install thoth
$ git clone https://github.com/gongahkia/thoth && cd thoth
$ make test
```

## `Thoth` provides....

<details>
<summary><b>Core Library</b></summary>

#### Data Structures
- **stacks** - LIFO stack helpers with `push`, `pop`, `peek`, and `size`
- **queues** - FIFO queue helpers with `push`, `pop`, `peek`, and `size`
- **deques** - Double-ended queue with front/back insertion, removal, and inspection
- **ringbuffers** - Fixed-capacity circular buffer with overwrite-on-full semantics
- **links** - Singly-linked list with insert, delete, search, and size helpers
- **sets** - Set container with membership tests plus union, intersection, and difference
- **orderedmaps** - Insertion-ordered key/value map with stable key iteration
- **trees** - Binary search tree with insert, search, delete, and inorder traversal
- **heaps** - Min heap, max heap, priority queue, and heap-sort helpers
- **tries** - Prefix tree with autocomplete, longest-common-prefix, delete, and wildcard pattern search
- **graphs** - Directed/undirected weighted graphs with BFS, DFS, shortest paths, connectivity checks, cycle detection, and topological sort
- **unionfind** - Disjoint-set / union-find structure for grouping and connectivity queries

#### Mathematics
- **math** - Clamp, Fibonacci, lerp, range scaling, smoothing, angle conversion, and random range helpers
- **math2d** / **math2D** - 2D vector math, normalization, scaling, angles, and Euclidean/Manhattan distance helpers

#### String Manipulation
- **stringify** - String trimming, splitting, joining, padding, centering, truncation, wrapping, replacement, similarity checks, template interpolation, and case conversion

#### Table Operations  
- **tables** - Count, shallow copy, `map`, `filter`, `reduce`, `push`/`pop`, and `shift`/`unshift` helpers

#### Validation
- **validate** - Primitive and collection validators, range/pattern checks, schema validation, contract wrappers, and validator builders

#### Serialization
- **serialize** - Deep copy, JSON encode/decode, Lua table serialization, file save/load helpers, and sandboxed Lua loading

#### Caching & Memoization
- **cache** - Simple caches, LRU caches, TTL caches, memoization, and LRU-bounded memoization

#### Event System
- **events** - Event emitter, event bus, deferred event queue, cancellable event objects, signal helper, and global publish/subscribe shortcuts

#### Performance & Profiling
- **performance** - Timers, benchmarks, function comparisons, profiler, memory measurement, FPS counter, and formatting helpers

#### Platform Utilities
- **config** - Shallow config merging, environment variable lookup, and `.env` file loading
- **datetime** - Unix timestamp helpers, ISO-8601 formatting, table conversion, and second-based time arithmetic
- **logging** - Leveled structured logger with pluggable sink functions
- **path** - Path join, normalize, basename, dirname, and extension helpers

</details>

<details>
<summary><b>Game Runtime & Adapters</b></summary>

#### Runtime
- **thoth.game.runtime** - Adapter-driven game loop with fixed-step simulation, per-frame update/draw phases, ordered systems, shared context, deterministic RNG, metrics/trace collection, debug HUD rendering, recording/replay, snapshots, and rollback support
- **thoth.game.frame** - Deterministic accumulator scheduler exposing fixed-step counts and interpolation alpha
- **thoth.game.random** - Seeded deterministic random generator with save/restore state and choice helpers
- **thoth.game.state** - Stack-based scene/state manager with enter/exit/update/draw/dispatch hooks plus snapshot/restore support
- **thoth.game.tasks** - Coroutine scheduler with spawned jobs, delayed jobs, repeating jobs, cancellation, inspection, and observer hooks
- **thoth.game.tween** - Tween, timer, and timeline primitives with easing, pause/resume, completion callbacks, and timeline inspection

#### Input & Gameplay Primitives
- **thoth.game.input** - Action-based input manager with keyboard, mouse, gamepad, touch, and axis bindings; deadzones/curves/scaling; layered contexts; import/export; and frame capture/apply for replay
- **thoth.game.animation** - Lightweight state-machine animation controller with enter/exit hooks and conditional transitions
- **thoth.game.behavior** - Behavior-tree helpers for conditions, actions, sequences, selectors, inversion, and repeat-until-failure flows
- **thoth.game.ecs** - Minimal table-oriented ECS helpers for querying, grouping, batch updates, and removals
- **thoth.game.camera** - 2D camera with viewport, zoom, bounds, target following, shake, and world/screen conversion
- **thoth.game.collision** - Rect/circle helpers plus point tests, overlap tests, segment intersection, and simple raycasts

#### World & Navigation
- **thoth.game.tilemap** - Layered tilemap storage with cell/world conversions, mutation helpers, and walkability checks
- **thoth.game.navigation** - Tilemap-to-grid and tilemap-to-waypoint-graph helpers built on top of pathfinding + core graphs
- **thoth.game.pathfinding** - A* pathfinding for weighted graphs and grids with custom heuristics, costs, and optional diagonal movement
- **thoth.game.spatial** - Spatial hash and quadtree broad-phase helpers with range, nearest-neighbor, update, and clear operations

#### Engine Adapters
- **thoth.adapters.love2d** - Love2D adapter for lifecycle registration, keyboard/mouse/touch/gamepad/window polling, and optional debug draw support
- **thoth.adapters.defold** - Defold adapter for runtime lifecycle registration, input-event bridging, and axis state tracking
- **thoth.adapters.solar2d** - Solar2D adapter for frame, key, touch, and axis event integration
- **thoth.adapters.contract** - Adapter capability contract, validation helpers, support assertions, and a null/headless adapter for tests or offline simulation

</details>

## Usage

```lua
-- eg usage
local s = require("thoth.core.stringify")
print(s.Lstrip("###watermelon", "#"))

-- or load all modules at once
local thoth = require("thoth")
print(thoth.core.stringify.Lstrip("###watermelon", "#"))

-- runtime + adapter usage
local runtime = thoth.game.runtime.new(thoth.adapters.love2d.new(love))
runtime.input:bind("jump", "space")
```
