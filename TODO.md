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

- [ ] B.3 Pearl Choir boss board: reflooding lanes, choir throats, moving waterline, pressure bell adds.
- [ ] B.4 Bell Diver boss board: hook lanes, bell-lung weak point, flood-toll countdown, low-ground punishment.
- [ ] B.5 Kiln Vicar boss board: vitrify target, halo vents, douse routes, ash-choke cover.
- [ ] B.6 Cinder Prioress boss board: furnace phases, glass crown reflectors, fuel-objective tradeoffs.
- [ ] B.7 Design 2 variants per boss by swapping arena modifier, add family, weak-point location, and objective pressure.
- [ ] B.8 Every boss must include one exact intent, one partial intent, one terrain mutation, one objective threat, and one non-damage counter.

### Procedural Board & Run Catalog

- [ ] P.1 Define board templates for kill-light, protect-heavy, extraction, repair, stealth, split-squad, holdout, and boss-route boards.
- [ ] P.2 Define board validator for reachability, LoS sanity, cover density, objective feasibility, enemy intent density, and exit access.
- [ ] P.3 Define difficulty budget weights for enemies, objectives, hazards, cover, reinforcements, redacted intent, and boss modifiers.
- [ ] P.4 Define route map node types: combat, repair, enclave, market, event, elite, boss, rest, cursed shortcut, high-reward extraction.
- [ ] P.5 Define event RNG rules that happen before/after boards, not during declared tactical resolution.
- [ ] P.6 Define seeded full-run export with board seeds, route choices, squad/loadout, event rolls, and replay hashes.
- [ ] P.7 Define 50 event prompts that alter route choice, board modifier, squad state, objective reward, or faction standing.

### UI & Readability Catalog

- [ ] U.1 Define icon language for AP, move, cover, flanked, LoS, exact intent, partial intent, hazard, objective, destructible HP, weak point, and extraction.
- [ ] U.2 Define overlay filters: movement, enemy intent, LoS, cover, objectives, hazards, hidden/revealed info.
- [ ] U.3 Define tile inspector copy template with one-line mechanics and one-line lore.
- [ ] U.4 Define preview contract: before commit, player sees AP cost, movement path, damage, push path, collision, cover change, objective change, and hazard result.
- [ ] U.5 Define four-rotation readability checks for every overlay.
- [ ] U.6 Define tutorial board sequence: movement, cover/flank, intent, forced movement, destructible terrain, objective pressure, redacted intent, boss weak point.
- [ ] U.7 Define screenshot-smoke target for tactical overlays.

### Implementation Gates

- [ ] G.1 No mechanic enters implementation without completed research handoff, preview/UI spec, and replay acceptance test.
- [ ] G.2 No procedural board type ships without validator results for at least 25 fixed seeds.
- [ ] G.3 No class loadout ships without one board where it is strong and one board where it is awkward.
- [ ] G.4 No enemy ships without an intent preview, a counterplay path, and a no-damage utility behavior.
- [ ] G.5 No boss ships without a phase chart, arena diagram, objective pressure, and replay proof.
- [ ] G.6 No borrowed pattern ships without documented Thoth transformation in `docs/tactical-research-index.md`.

## Prototype 0 - Tactical Board Proof

Goal: prove the new combat loop before touching broad content.

**Exit criteria:** one board is playable start to finish; no hit chance; all visible intents resolve deterministically; rotation improves planning; replay deterministic.

## Phase 1 - Core Tactical Engine

Goal: replace expedition/rank combat with the tile tactics engine.

- [ ] 1.1 Define `src/game/tactics/` modules for board, unit, AP, LoS, cover, intent, resolution, procgen, and replay.
- [ ] 1.2 Implement deterministic LoS with height, blockers, cover edges, and rotation-independent logic.
- [ ] 1.3 Implement cover classes: none, half, full, hard blocker, destructible, mobile cover.
- [ ] 1.4 Implement flanking rules and UI preview from any candidate tile.
- [ ] 1.5 Implement AP costs: move, dash, attack, interact, brace, overwatch, reload/cooldown, class special.
- [ ] 1.6 Implement action preview: affected tiles, pushed path, collision, objective damage, cover break, hazard chain.
- [ ] 1.7 Implement enemy activation, intent selection, intent preview, resolution, and next-turn declaration.
- [ ] 1.8 Implement board rewind/debug replay for deterministic QA only, not as a player feature yet.
- [ ] 1.9 Remove or quarantine legacy rank-combat code from player flow.

**Exit criteria:** tactical missions use tile/AP/intent resolution; legacy rank combat no longer blocks the new loop; tests cover LoS, cover, push, destructible terrain, and replay determinism.

## Phase 2 - Procedural Boards & Roguelite Runs

Goal: make runs varied without sacrificing readability.

- [ ] 2.1 Build board grammar: rooms, corridors, height bands, cover fields, sight breaks, objective anchors, hazard lanes, spawn pockets.
- [ ] 2.2 Add zone generators for Buried Archive, Salt Cistern, and Ember Warrens.
- [ ] 2.3 Add encounter director: enemy mix, intent density, objective pressure, reinforcement timing, and retreat routes.
- [ ] 2.4 Add run map: route choices, risk/reward previews, enclave requests, boss gates, and event nodes.
- [ ] 2.5 Add RNG event layer for pre/post mission complications; tactical combat remains deterministic after board start.
- [ ] 2.6 Add difficulty budget so generated boards can be rejected if unsolvable or unreadable.
- [ ] 2.7 Add seeded-run replay export.

**Exit criteria:** seeded roguelite run generates multiple valid boards, route choices matter, and all tactical outcomes remain deterministic after mission load.

## Phase 3 - Classes, Loadouts, Units

Goal: make variable squads and class loadouts the main progression layer.

- [ ] 3.1 Redefine classes around board verbs, not RPG roles.
- [ ] 3.2 Each class ships with 2 loadout slots, 3-5 weapons/tools, and at least one terrain interaction.
- [ ] 3.3 Add character traits that alter AP, movement, LoS, cooldowns, cover use, or objective handling.
- [ ] 3.4 Add loadout unlocks through runs, not permanent stat inflation only.
- [ ] 3.5 Add injury/debt consequences that change tactical constraints without random turn loss.
- [ ] 3.6 Add squad-size variance rules and board scaling.

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

- [ ] 4.1 Build enemy archetypes: mover, shooter, artillery, pusher, puller, blocker, summoner, repairer, saboteur, overwatch, terrain-breaker.
- [ ] 4.2 Add exact intents for basic enemies.
- [ ] 4.3 Add partial/masked intents for elites.
- [ ] 4.4 Add boss phases built around tile patterns, rotating weak points, terrain conversion, and objective pressure.
- [ ] 4.5 Add friendly fire and enemy-vs-objective collision rules.
- [ ] 4.6 Add destructible location rules for shelves, bridges, valves, kilns, doors, floors, and machinery.
- [ ] 4.7 Add visible reinforcement rules and spawn blocking.

**Exit criteria:** every zone has one enemy family, one elite, and one boss prototype using deterministic intents and terrain interaction.

## Phase 5 - UI, Readability, Accessibility

Goal: make dense tactics legible.

- [ ] 5.1 Add tactical HUD: selected unit AP, move preview, action preview, enemy intents, objective risk, turn order.
- [ ] 5.2 Add tile inspector for terrain, cover, LoS, hazards, destructible HP, hidden info, and current intent traces.
- [ ] 5.3 Add rotation-aware overlays that stay readable at all four camera snaps.
- [ ] 5.4 Add colorblind-safe intent/cover/hazard palette.
- [ ] 5.5 Add reduced-motion equivalents for rotation, destruction, knockback, and explosions.
- [ ] 5.6 Add controller path for selecting units, tiles, actions, targets, and previews.
- [ ] 5.7 Add tutorial boards for movement, cover/flanking, intent, push/pull, destruction, and objectives.

**Exit criteria:** a new player can solve tutorial boards without reading external docs; all key tactical data is inspectable.

## Phase 6 - Content Vertical Slice

Goal: ship one replayable tactical slice.

- [ ] 6.1 One Buried Archive route with 5-7 procedural board variants.
- [ ] 6.2 Four starter classes with 2 loadouts each.
- [ ] 6.3 Three objective types: protect, extract, disable.
- [ ] 6.4 One elite and one boss.
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
