[![](https://img.shields.io/badge/thoth_1.0.0-passing-%23004D00)](https://github.com/gongahkia/thoth/releases/tag/1.0.0) 
[![](https://img.shields.io/badge/thoth_2.0.0-passing-%23228B22)](https://github.com/gongahkia/thoth/releases/tag/2.0.0) 
[![](https://img.shields.io/badge/thoth_3.0.0-passing-%2332CD32)](https://github.com/gongahkia/thoth/releases/tag/3.0.0) 

<h1 align='center'><code>thoth</code></h1>
<div align='center'>
<p>
  <i>Functional lua pocket knife.</i>
</p>
<img src='https://github.com/gongahkia/thoth/assets/117062305/276628d5-aefa-442c-ad3e-5df51b4357b3' width=50% height=50%></img>
</div>

## installation

```console
$ git clone https://github.com/gongahkia/thoth
$ cd thoth
$ make clean
```

## `thoth` provides....

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
<summary><b>Love2D Game Development</b></summary>

#### Animation & Tweening
- **Love2DAnimation** - Sprite sheets, frame-based animation, property tweening with 12+ easing functions (linear, quad, cubic, sine, elastic, bounce)

#### Collision Detection
- **Love2DCollision** - Circle, rectangle, and convex polygon collision using SAT (Separating Axis Theorem)

#### Rendering
- **Love2DDraw** - Simple shape and text rendering helpers

#### Point Testing
- **Love2DPointIn** - Point-in-circle and point-in-rectangle containment checks

#### Input Handling
- **Love2DInput** - Keyboard and mouse input management with frame-based event detection, text input capture

#### Entity-Component System
- **Love2DEcs** - Full ECS architecture with entity queries, component management, and system processing

#### State Management
- **Love2DStates** - Game state/scene management with transitions, state stacking (push/pop), and lifecycle callbacks

</details>

## usage

```lua
-- eg usage
local s = require("src.stringify")
print(s.Lstrip("###watermelon", "#"))

-- or load all modules at once
local thoth = require("init")
print(thoth.stringify.Lstrip("###watermelon", "#"))
```
