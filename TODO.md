# TODO

## Terrain

- Expose watershed, basin, ridge, and mountain-range ids on sampled cells for discovery/debug overlays.
- Keep terrain-first sequencing: no ruins, lore objects, quests, or collectibles until landforms are coherent.

## Exploration

- Add named terrain discovery: mountain ranges, watersheds, basins, coasts, ridges, passes, rain shadows.
- Add player survey tools that mark sampled terrain history without adding quests/combat/survival.
- Add smooth nested-scale transitions with persistent labels between local, region, and continent views.
- Add optional impossible-topology experiments: wrapped valleys, recursive insets, scale doors, and folded map edges.
- Reintroduce region/continent scale as diegetic transitions instead of runtime map zoom.

## Rendering

- Improve pseudo-3D terrain mesh density and biome palette.
- Delay major visual polish until hydrology and erosion outputs are stable enough to inspect.
- Add optional debug topographic map outside the default runtime view.
- Add screenshot/export command for generated maps and seed metadata.
- Add debug panels for plate vectors, drainage arrows, erosion deltas, and biome classifier inputs.

## Engineering

- Add chunk cache bounds and performance counters.
- Add save/load for seed, player position, discovered annotations, and display settings.
- Add headless terrain benchmark over many chunks and scales.
- Add regression seeds for ugly terrain, all-water/all-land maps, broken seams, and river discontinuities.
