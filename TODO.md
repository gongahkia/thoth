# TODO

## Next Deepening Priority

1. Pseudo-3D readability: river strips, slope silhouettes, landmark billboards, and fog tuning after hydrology stats stabilize.

## Terrain

- Add thermal erosion and sediment deposition passes with visible talus slopes, alluvial fans, deltas, and floodplains.
- Add plate age, oceanic subduction bias, rift valleys, volcanic island arcs, shield regions, and cratons.
- Calibrate generated elevation, water ratio, river density, and biome ratios against rough Earth-like ranges.
- Improve lake grouping, outlet labeling, spillover routing, and deltas.
- Expose watershed, basin, ridge, and mountain-range ids on sampled cells for discovery/debug overlays.
- Keep terrain-first sequencing: no ruins, lore objects, quests, or collectibles until landforms are coherent.

## Exploration

- Add named terrain discovery: mountain ranges, watersheds, basins, coasts, ridges, passes, rain shadows.
- Add player survey tools that mark sampled terrain history without adding quests/combat/survival.
- Add smooth nested-scale transitions with persistent labels between local, region, and continent views.
- Add optional impossible-topology experiments: wrapped valleys, recursive insets, scale doors, and folded map edges.
- Reintroduce region/continent scale as diegetic transitions instead of runtime map zoom.

## Rendering

- Improve pseudo-3D terrain mesh density, horizon fog, river strips, and biome palette.
- Delay major visual polish until hydrology and erosion outputs are stable enough to inspect.
- Add optional debug topographic map outside the default runtime view.
- Add screenshot/export command for generated maps and seed metadata.
- Add debug panels for plate vectors, drainage arrows, erosion deltas, and biome classifier inputs.

## Engineering

- Add chunk cache bounds and performance counters.
- Add save/load for seed, player position, discovered annotations, and display settings.
- Add headless terrain benchmark over many chunks and scales.
- Add regression seeds for ugly terrain, all-water/all-land maps, broken seams, and river discontinuities.
