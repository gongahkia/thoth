# TODO

## Terrain

- Replace the current chunk-local drainage pass with a multi-chunk river solver so large rivers persist across distant chunk boundaries.
- Add thermal erosion and sediment deposition passes with visible talus slopes, alluvial fans, deltas, and floodplains.
- Add plate age, oceanic subduction bias, rift valleys, volcanic island arcs, shield regions, and cratons.
- Calibrate generated elevation, water ratio, river density, and biome ratios against rough Earth-like ranges.
- Add lake basin filling and spillover routing.

## Exploration

- Add named terrain discovery: mountain ranges, watersheds, basins, coasts, ridges, passes, rain shadows.
- Add player survey tools that mark sampled terrain history without adding quests/combat/survival.
- Add smooth nested-scale transitions with persistent labels between local, region, and continent views.
- Add optional impossible-topology experiments: wrapped valleys, recursive insets, scale doors, and folded map edges.

## Rendering

- Improve topographic contours, river antialiasing, labels, and biome palette.
- Add screenshot/export command for generated maps and seed metadata.
- Add debug panels for plate vectors, drainage arrows, erosion deltas, and biome classifier inputs.

## Engineering

- Add chunk cache bounds and performance counters.
- Add save/load for seed, player position, discovered annotations, and display settings.
- Add headless terrain benchmark over many chunks and scales.
