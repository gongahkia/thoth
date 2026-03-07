# Add tilemap and navigation helpers around pathfinding

## Summary

`thoth.game.pathfinding` already provides A* over graphs and grids, but higher-level world helpers are still missing. Add tilemap utilities and richer navigation helpers so pathfinding is easier to apply in real games.

## Scope

- Add tilemap data structures and helper functions for layers, coordinates, and walkability.
- Add navigation helpers that can derive traversable graphs from tilemaps.
- Consider a navmesh- or waypoint-oriented API that composes with the existing A* implementation.
- Keep file-format loading optional, but design the in-memory API to support future importers.
- Provide examples that combine tilemaps with pathfinding and spatial queries.

## Acceptance criteria

- A caller can build a tilemap-backed navigation representation without bespoke glue code.
- Navigation helpers compose with `thoth.game.pathfinding` rather than replacing it.
- Tests cover coordinate conversion, obstacle handling, and navigation graph generation.
- The showcase example can use these helpers for navigation or level data.
