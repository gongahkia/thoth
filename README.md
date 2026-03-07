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



## Installation

```console
$ luarocks install thoth
$ git clone https://github.com/gongahkia/thoth
$ cd thoth
$ make test
```

## `Thoth` provides....

<details>
<summary><b>Core Library</b></summary>

#### Data Structures
- **stacks** - LIFO stack with push/pop/peek operations
- **queues** - FIFO queue with enqueue/dequeue functionality  
- **links** - Singly-linked list implementation
- **trees** - Binary search tree with insert/search/delete
- **heaps** - Min/max heaps and priority queues with O(log n) operations
- **tries** - Prefix tree for autocomplete and pattern matching with wildcard support
- **graphs** - Directed/undirected weighted graphs with BFS, DFS, Dijkstra pathfinding

#### Mathematics
- **math** - Common utilities: clamp, lerp, smoothstep, angle conversions, random ranges
- **math2D** - 2D vector operations: add, subtract, scale, normalize, distance calculations (Euclidean & Manhattan)

#### String Manipulation
- **stringify** - Comprehensive string utilities: strip, split, pad, truncate, word wrap, Levenshtein distance, template interpolation, case conversion

#### Table Operations  
- **tables** - Functional programming helpers: map, filter, reduce, push/pop, shift/unshift

#### Validation
- **validate** - Runtime type checking, schema validation, contract programming with pre/postconditions

#### Serialization
- **serialize** - JSON and Lua table encoding/decoding with file I/O, deep copy with circular reference handling

#### Caching & Memoization
- **cache** - Multiple cache implementations:
  - Simple unbounded cache
  - LRU (Least Recently Used) cache with bounded capacity
  - TTL (Time-To-Live) cache with expiration
  - Function memoization with LRU eviction

#### Event System
- **events** - Full event-driven architecture:
  - EventEmitter with on/once/off/emit
  - Global EventBus for publish/subscribe
  - EventQueue for deferred/batched processing
  - Signal system for simplified single-listener patterns

#### Performance & Profiling
- **performance** - Benchmarking and profiling tools:
  - Timer for execution measurement
  - Benchmark runner with statistics
  - Function comparison utilities
  - Call-level profiler
  - Memory usage tracking
  - FPS counter

</details>

<details>
<summary><b>Game Runtime & Adapters</b></summary>

#### Runtime
- **thoth.game.runtime** - Fixed + variable timestep runtime with ordered systems, tasks, tween timeline, and state manager integration
- **thoth.game.frame** - Deterministic frame scheduler with accumulator and interpolation alpha
- **thoth.game.state** - Stack-based scene/state manager with lifecycle callbacks
- **thoth.game.tasks** - Coroutine task scheduler with delayed and repeating jobs

#### Input, Motion & Space
- **thoth.game.input** - Action-based input manager with digital + axis bindings
- **thoth.game.tween** - Tween/timer/timeline utilities with easing
- **thoth.game.pathfinding** - A* pathfinding for graph and grid use cases
- **thoth.game.spatial** - Spatial hash and quadtree broad-phase helpers

#### Engine Adapters
- **thoth.adapters.love2d** - Love2D adapter for lifecycle hooks + input polling
- **thoth.adapters.defold** - Defold adapter for runtime updates + input event bridging
- **thoth.adapters.solar2d** - Solar2D adapter for frame/input bridge integration
- **thoth.adapters.contract** - Adapter contract validation + null adapter for tests/headless usage

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
