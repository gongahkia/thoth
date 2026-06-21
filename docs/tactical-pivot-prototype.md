# Tactical Pivot Prototype

Checked: 2026-06-21

Scope: Prototype 0 state-layer proof for the deterministic tactics pivot. This documents what is proven in code now and what remains cut from the interactive player flow.

## Results

- Separate tactical state module: `src/game/tactics/state.lua`.
- Square-grid board data: width, height, tile identity, material, height, cover edges, movement blockers, LoS blockers, destructible HP, hazards, objective data, reveal state, rotation marks, tags, and destroyed state.
- Deterministic AP controls: selectable units, AP spend validation, turn-side AP reset, move AP costs, and support for 3-5 player units.
- Deterministic tactical verbs: move, shove, pull, direct attack, AoE, overwatch/threat zones, and terrain destruction.
- Mixed enemy intent: exact, category-only, hidden-footprint, and boss-stage previews.
- Objective proof: protect route machinery integrity plus evacuate at least one unit.
- Replay proof: `tests/replays.lua` runs the same tactical command stream twice from fresh state and compares serialized snapshots.
- Renderer proof: `Render.tacticalOverlayEntries` and render smoke cover movement, LoS, cover, flank, intent, and hazard overlays.
- Rotation proof: tests verify tactical overlay screen position changes with rotation while logical coordinates round-trip unchanged.

## Verification

- `make test`
- `luajit tests/replays.lua`
- `make render-smoke`

Current observed counts after this pass:

- Unit harness: 180 tests.
- Replay fixtures: 4 legacy replay fixtures plus 1 tactical replay fixture.
- Render smoke tactical overlays: total 7, movement 2, LoS 1, cover 1, flank 1, intent 1, hazard 1.

## Cuts

- No interactive tactical mission UI is wired into normal player flow yet.
- No full LoS solver exists yet; LoS is represented as overlay/input data, not computed from blockers and height.
- Cover and flanking are represented in schema/overlays, but direct attacks do not yet apply cover/flank resolution.
- No procedural tactical board generator or validator exists yet.
- No tactical AI intent selection exists yet; intents are declared by command/test fixtures.
- No tactical save migration is wired beyond isolated state snapshots.
- No art pass exists for overlay icons, patterns, or colorblind-safe production UI.

## Next Work

- Build `src/game/tactics/` modules around board, unit, AP, LoS, cover, intent, resolution, procgen, and replay.
- Add deterministic LoS and cover/flank resolution before broad content.
- Wire one command-stream board into an interactive tactical mission shell before expanding class/enemy catalogs.
