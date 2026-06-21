# Thoth - Pivot Roadmap & Tasks

Locked 2026-06-21. New source of truth for the tactical pivot.

## Pivot Summary

Thoth keeps LOVE2D/Lua, the HD-2D isometric renderer, 90-degree snap rotation, and institutional horror. The game pivots away from expedition-RPG/rank combat toward deterministic, tile-based roguelite tactics closer to XCOM and Into the Breach: read the board, rotate the space, inspect enemy intent, spend AP, move units/enemies/terrain, then resolve visible consequences on tiles.

Current code is legacy baseline until replaced. Preserve useful systems only when they serve the new board game.

## Research Anchors

- Into the Breach: small deterministic battles, telegraphed attacks, collateral defense, enemy manipulation, low UI noise.
- XCOM: squad tactics, AP pacing, cover, flanking, line of sight, overwatch-style threat zones.
- Slay the Spire: mixed enemy intents where the player sees attack/buff/debuff/unknown categories before choosing.
- Invisible Inc: procedural tactical stealth, information gathering, readable guard intent, dependable planning.
- Gears Tactics: AP flexibility, cover-to-cover movement, player-drawn overwatch cones, large boss arenas.
- Mario + Rabbids: free movement inside a turn, dash/team movement, cover usage, loadout synergies.
- Spatial board games and tactics roguelikes: compact board states, forced movement, clear threat math, repeatable procgen validation.

## Required Research Protocol

Every new content/mechanic batch must start with web research. Do not implement from memory alone.

Completed research index: `docs/tactical-research-index.md`.

Required handoff format for each research-backed TODO:

```text
source pattern:
thoth transformation:
board verb:
zone fit:
counterplay:
preview/UI:
test/replay proof:
```

## Lock-in Decisions

- **Engine:** stay LOVE2D + Lua + g3d.
- **Rendering:** keep HD-2D isometric 3D tiles with billboarded or modelled units.
- **Camera:** keep 90-degree snap rotation on `[` and `]`; rotation is gameplay information, not only presentation.
- **Core combat:** deterministic. No hit/miss rolls in player-facing tactical resolution.
- **Hybrid definition:** allowed RNG lives in map generation, enemy roster, event rolls, rewards, and optional hidden/partial intent categories. It must not make a declared attack randomly miss or randomly hit.
- **Turn model:** use team turns with AP per unit as the first prototype: player spends AP across squad, confirms, enemy intents resolve, enemies reposition/declare next intents. Revisit alternating initiative only after the prototype.
- **Grid:** square logical grid rendered isometrically, with height, cover edges, blockers, hazards, destructible objects, and tile tags.
- **Cover:** XCOM-style directional cover and flanking, but deterministic. Cover blocks/reduces defined effects; flanking removes cover protection.
- **Enemy intent:** mixed forecast. Common enemies show exact tiles/effects. Elites may show category plus partial footprint. Bosses may have staged or rotating intent masks, but never pure surprise damage.
- **Failure pressure:** protect both squad and objectives. Objectives include civilians, enclaves, route machinery, archives, power/pressure nodes, exits, and extraction cargo.
- **Run structure:** roguelite campaigns with procedural boards, route choices, persistent unlocks, class loadouts, and boss variants.
- **Tone:** institutional horror preserved. Mechanics should feel like procedures, audits, gates, pressure systems, claims, and corrections acting on tiles.
- **Distribution:** itch.io + GitHub releases. No Steam unless the strategy changes later.

## Tactical Pillars

1. **The board tells the truth.** Movement, attacks, cover, hazards, LoS, hidden rooms, and objective damage are visible or inspectable before commitment.
2. **Rotation is planning.** Rotating reveals occluded cover edges, LoS, hidden route marks, back-facing weak points, and intent traces.
3. **Actions move state.** Good turns reposition units, enemies, objects, hazards, and future attacks. Damage alone should be the least interesting answer.
4. **Terrain is a tool.** Walls, shelves, valves, furnaces, desks, bridges, doors, pressure plates, and records can be damaged, pushed, sealed, raised, flooded, burned, or used as cover.
5. **Threats are promises.** Declared attacks resolve unless prevented by movement, block, stun, destruction, cover, line break, or objective sacrifice.
6. **Runs create stories.** Procedural boards and events create pressure, but tactical resolution stays deterministic.

## Full-Game Mechanic Backlog

These tasks define the content/mechanic catalog. Prototype only a narrow slice first, but design toward this breadth.

### Core Board Mechanics

### Intent & Counterplay Mechanics


### Cover, LoS, Visibility


### Objective Families


## Full-Game Content Catalog Backlog

### Zone Terrain Catalogs

### Class & Loadout Catalog

### Enemy Family Catalog

### Boss & Variant Catalog


### Procedural Board & Run Catalog


### UI & Readability Catalog


### Implementation Gates


## Prototype 0 - Tactical Board Proof

Goal: prove the new combat loop before touching broad content.

**Exit criteria:** one board is playable start to finish; no hit chance; all visible intents resolve deterministically; rotation improves planning; replay deterministic.

## Phase 1 - Core Tactical Engine

Goal: replace expedition/rank combat with the tile tactics engine.

**Exit criteria:** tactical missions use tile/AP/intent resolution; legacy rank combat no longer blocks the new loop; tests cover LoS, cover, push, destructible terrain, and replay determinism.

## Phase 2 - Procedural Boards & Roguelite Runs

Goal: make runs varied without sacrificing readability.

**Exit criteria:** seeded roguelite run generates multiple valid boards, route choices matter, and all tactical outcomes remain deterministic after mission load.

## Phase 3 - Classes, Loadouts, Units

Goal: make variable squads and class loadouts the main progression layer.


Initial class direction:

- Warden: mobile cover, brace, shove, shield-line denial.
- Duelist: flank conversion, dash strikes, position swaps.
- Apothecary: area stabilizers, smoke, cleanse hazards, rescue objectives.
- Arcanist: LoS bending, reveal marks, intent disruption.
- Thief: stealth lanes, trap disarm, loot/extract under pressure.
- Chirurgeon: repair bodies and machinery; convert injuries into temporary constraints.
- Exile: terrain break, throw, slam, self-risk AP spikes.
- Lamplighter: reveal, overwatch cones, light authority, route beacons.
- Merchant: objective insurance, debt trades, salvage drones, risk conversion.

**Exit criteria:** at least 6 classes have distinct board verbs and deterministic counters; squad composition changes how boards are solved.

## Phase 4 - Enemy Families & Boss Design

Goal: make enemies readable, varied, and board-native.


**Exit criteria:** every zone has one enemy family, one elite, and one boss prototype using deterministic intents and terrain interaction.

## Phase 5 - UI, Readability, Accessibility

Goal: make dense tactics legible.


**Exit criteria:** a new player can solve tutorial boards without reading external docs; all key tactical data is inspectable.

## Phase 6 - Content Vertical Slice

Goal: ship one replayable tactical slice.

- [x] 6.1 One Buried Archive route with 5-7 procedural board variants.
- [x] 6.2 Four starter classes with 2 loadouts each.
- [x] 6.3 Three objective types: protect, extract, disable.
- [x] 6.4 One elite and one boss.
- [ ] 6.5 One run map with route rewards and complications.
- [ ] 6.6 One public alpha package and feedback form.

**Exit criteria:** players can complete multiple runs with different boards, squad choices, and route outcomes.

## Phase 7 - Full Roguelite Scope

Goal: expand to full game breadth after the slice proves itself.

- [ ] 7.1 Three zones with distinct terrain grammars and enemy families.
- [ ] 7.2 9 classes with loadout unlocks and run-level choices.
- [ ] 7.3 30+ tactical objectives across protect/extract/disable/repair/survive/boss boards.
- [ ] 7.4 Boss variant system with generated arena modifiers.
- [ ] 7.5 Meta progression that unlocks options, not raw power dominance.
- [ ] 7.6 Run ending routes: seal, repair, extraction collapse, quiet failure.

**Exit criteria:** full roguelite campaign loop is playable and replayable.

## Crosscutting Tasks

- [ ] C.1 Every tactical mechanic gets deterministic unit tests and at least one replay fixture.
- [ ] C.2 Every new board overlay gets screenshot/smoke coverage.
- [ ] C.3 Every procgen board has a seed, difficulty budget, and validation report.
- [ ] C.4 Every asset addition updates `docs/asset-licenses.md`.
- [ ] C.5 Weekly dev log records one design decision, one cut, one risk.
- [ ] C.6 CI must run headless tactical tests, replay tests, asset checks, package checks, and smoke tests.

## Known Risks

- **R1 Readability collapse:** cover, LoS, height, intent, hazards, and rotation can overload the player. Mitigation: tile inspector, overlay filters, tutorial boards, and strict icon budget.
- **R2 Procgen unfairness:** deterministic tactics can become impossible if generation creates unsolvable boards. Mitigation: board validator and reject budget.
- **R3 Rotation confusion:** rotating for information can obscure coordinate planning. Mitigation: stable tile IDs, ghost arrows, compass, and rotation-independent previews.
- **R4 Scope explosion:** XCOM breadth plus Into the Breach precision is expensive. Mitigation: prove 1-board prototype before broad content.
- **R5 Cover math opacity:** XCOM-style cover can feel arbitrary. Mitigation: deterministic preview from each tile, no hidden aim math.
- **R6 Legacy drag:** old systems may bias the pivot back toward RPG dungeon crawling. Mitigation: quarantine legacy rank combat and write new tactical modules first.
