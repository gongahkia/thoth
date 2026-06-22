# Thoth - Phase 1B Roadmap (XCOM-lite Vertical Slice)

Locked 2026-06-22. Strategy-leaning XCOM-lite. Buried Archive vertical slice.
Format: todo.txt. Priority A-E. +project @context tags. Pick any line, execute, mark `x` and date when done.

## Pitch

Deterministic XCOM-lite tactics in the Great Stack. Squad of six audits a Buried Archive where filing lanes, audit beams, and redaction fog enforce institutional procedures on tiles. No hit rolls. Rotate the board to read it. Six missions, one zone, archival horror preserved as records.

## Slice exit criteria

- 6-unit squad selectable from 6 distinct classes with distinct board verbs.
- 6 procedural missions in Buried Archive end-to-end completable, deterministic, replayable.
- Fog-of-war, overwatch cones, flanking, and hidden intent until LoS all wired, previewed, tested.
- Procgen validator passes 25+ fixed seeds with a reject log artifact.
- Tutorial board teaches rotation + intent + overwatch without external docs.
- Storefront copy (itch alpha page, README pitch, market audit) reflects the actual game.
- Legacy expedition/RPG code removed from the source tree.

## Task list (todo.txt)

(A) 2026-06-22 Delete src/game/simulation.lua and remove every require/usage from main.lua and tests +legacy-cleanup @engine
(A) 2026-06-22 Delete src/game/world.lua and remove every require/usage from main.lua and tests +legacy-cleanup @engine
(A) 2026-06-22 Strip the tacticalMode guard branches in main.lua now that only the tactical path remains; collapse update/draw to a single code path +legacy-cleanup @engine
(A) 2026-06-22 Run make test and make package-build to confirm the legacy/i18n removal does not break the playable tactical path or dist/thoth.love +legacy-cleanup @tests
(A) 2026-06-22 Add per-unit vision radius to src/game/tactics/state.lua units table (default 8 tiles), extend src/game/tactics/los.lua with computeVisibleTiles(unit) returning a set, and aggregate squad visibility into a board-wide fog grid +xcom-primitives @engine
(A) 2026-06-22 Render fog-of-war in src/app/render.lua: dim unseen tiles, hide enemy units and intent arrows outside squad vision, persist last-seen ghost markers for previously-visible enemies +xcom-primitives @ui
(A) 2026-06-22 Gate enemy intent reveal in src/game/tactics/intent.lua: enemies outside any squad unit's vision expose category only; entering vision reveals full footprint deterministically that turn +xcom-primitives @engine
(A) 2026-06-22 Add deterministic overwatch state to src/game/tactics/state.lua: unit declares a cone (origin, facing, arc, range), spends AP, triggers a declared reaction (shoot/stun/mark) on the first enemy entering the cone during enemy phase +xcom-primitives @engine
(A) 2026-06-22 Render overwatch cones in src/app/render.lua with a distinct overlay color, animate trigger resolution, and add a preview tile-by-tile when the player is selecting cone direction +xcom-primitives @ui
(A) 2026-06-22 Formalize flanking in src/game/tactics/cover.lua: when an attacker's tile is behind a defender's cover edge, apply a configurable bonus (default +50% damage or remove cover entirely), expose via resolution.lua preview +xcom-primitives @engine
(A) 2026-06-22 Add unit tests in tests/run.lua for: vision computation, fog persistence on enemy exit, overwatch trigger order vs enemy intent resolution, flanking bonus determinism, hidden-intent reveal on first LoS +xcom-primitives @tests
(B) 2026-06-22 Wire 6 classes (Warden, Duelist, Apothecary, Thief, Arcanist, Lamplighter) from src/game/tactics/class_catalog.lua into the live unit factory in tactical_runtime.lua; each must instantiate with its board verbs callable from input bar +slice-content @data
(B) 2026-06-22 Implement Warden board verbs (line_guard, brace, shove) end-to-end with AP costs, previews, and replay-deterministic resolution +slice-content @engine
(B) 2026-06-22 Implement Duelist board verbs (red_line dash strike, position swap) end-to-end +slice-content @engine
(B) 2026-06-22 Implement Apothecary board verbs (field_triage stabilize, smoke_binder area smoke that modifies LoS) end-to-end +slice-content @engine
(B) 2026-06-22 Implement Thief board verbs (ghost_route stealth lane, courier_cut extract) end-to-end; integrate with fog-of-war so stealth is mechanically meaningful +slice-content @engine
(B) 2026-06-22 Implement Arcanist board verbs (seal_reader reveal, line_bender LoS bend, intent_breaker interrupt) end-to-end +slice-content @engine
(B) 2026-06-22 Implement Lamplighter board verbs (beacon_runner, cone_keeper overwatch upgrade, ash_lamp intent reduction) end-to-end; integrate with the new overwatch system +slice-content @engine
(B) 2026-06-22 Add class-loadout selection screen so the player picks 6 units from the 6 classes (allowing duplicates or not - decide and document) before mission 1 +slice-content @ui
(B) 2026-06-22 Wire 10 common Archive enemies (hollow_guard, ink_wretch, bone_scribe, gutter_thing, pale_censer, page_scout, writ_bailiff, seal_clerk, ledger_hound, drawer_mite) into the procgen spawn pool; each must declare a distinct intent type +slice-content @data
(B) 2026-06-22 Wire 3 elite Archive enemies (codex_advocate, shelf_knight, writ_cantor) into procgen with elite-tier intent footprints (partial reveal until rotation/class gate) +slice-content @data
(B) 2026-06-22 Wire 1 Archive alpha (shelf_warden) as a mid-run elite spawn with deterministic terrain interaction +slice-content @data
(B) 2026-06-22 Wire Vault Regent boss in src/game/tactics/boss_catalog.lua: phase chart, arena diagram, staged intent masks rotating per turn, weak-point exposure tied to rotation +slice-content @data
(B) 2026-06-22 Define 6 mission variants in run_catalog.lua/procgen.lua for the Buried Archive route: entry_audit, shelf_protection, proof_extract, ledger_repair, sealed_shortcut, vault_regent_final; each must have a distinct objective family +slice-content @data
(B) 2026-06-22 Tune AP economy in src/game/tactics/ap.lua for a 6-unit squad so a turn averages 18-24 AP total; verify against playtest replay +slice-content @engine
(B) 2026-06-22 Scale UI in src/app/render.lua to show 6 unit portraits, AP pools, and selection state without overlapping the board view at 1080p +slice-content @ui
(C) 2026-06-22 Build tile inspector in src/app/render.lua + src/app/input.lua: cursor hover shows tile tags, cover edges, hazard timers, intent footprints reaching that tile, vision sources, terrain HP +readability @ui
(C) 2026-06-22 Build intent legend overlay: bottom-bar list of every declared enemy intent this turn with icon, target tiles highlighted on hover, source enemy highlighted +readability @ui
(C) 2026-06-22 Add rotation compass + stable tile-ID ghost arrows so the player can keep their bearings across 90-degree rotations +readability @ui
(C) 2026-06-22 Build a tutorial board (single-screen, 6x6, scripted enemy intents) that teaches: select unit, move, rotate camera, declare overwatch, end turn, react to revealed intent - all without text walls +readability @engine
(C) 2026-06-22 Add accessibility settings panel: high-contrast tile mode, intent-icon size scaling, colorblind-safe cover edge palette, optional intent-text duplication +readability @ui
(C) 2026-06-22 Procgen validator: write tools/validator.lua that loads 25 fixed seeds, generates a board per seed, runs sanity checks (objective reachable, squad spawn safe, no unsolvable enemy placement), and emits a reject log to dist/validator-report.json +procgen-validator @tests
(C) 2026-06-22 Integrate validator into Makefile (make validate) and CI; fail the build if reject count exceeds budget +procgen-validator @build
(C) 2026-06-22 Document the validator invariants in docs/tactical-procgen-grammar.md and add fixture seeds to tests/run.lua replay determinism suite +procgen-validator @docs
(D) 2026-06-22 Rewrite docs/market-audit.md to describe the XCOM-lite tactical pivot, target audience (ITB+XCOM crossover, institutional-horror fans), and competitive set; remove every reference to expedition/rank combat +docs @docs
(D) 2026-06-22 Rewrite README.md pitch paragraph to match the new market-audit; add a one-screenshot/one-gif hero block once the tile inspector lands +docs @docs
(D) 2026-06-22 Refresh docs/itch-alpha-page.md, docs/press-kit.md, docs/itch-beta-page.md, docs/itch-final-page.md to reflect XCOM-lite framing, 6-class slice, and current screenshots +docs @docs
(D) 2026-06-22 Update WORLD-LORE.md to mark Salt Cistern and Ember Warrens as future-zone content, with a clear "vertical slice = Buried Archive only" header +docs @docs
(D) 2026-06-22 Update docs/tactical-research-index.md to record decisions taken this phase (XCOM-lite, fog/overwatch/flank/hidden-intent, 6-unit squad) with citations to source patterns +docs @docs
(D) 2026-06-22 Update docs/dev-log.md with the 2026-06-22 pivot decisions and link to this TODO +docs @docs
(E) 2026-06-22 Capture new preview PNGs at 1280x720 showing fog-of-war, overwatch cone, and intent legend for itch.io storefront update +release @build
(E) 2026-06-22 Cut a new dist/thoth.love build, smoke-test on macOS, and tag a vertical-slice-rc1 git tag once all (A) and (B) tasks are complete +release @build
(E) 2026-06-22 Draft itch.io devlog post for the vertical slice release; include the rewritten pitch line and a 30-second gameplay GIF +release @docs

## Notes for the executing agent

- All combat resolution must remain deterministic: no hit/miss rolls, no random damage. RNG is allowed only in map generation, enemy roster selection, and reward rolls.
- Fog-of-war and hidden intent are perfect-information-out-of-sight, not hidden math: when a tile becomes visible, the full intent footprint must resolve as the enemy committed when it was declared.
- Use src/core/rng.lua (seeded) for any procgen call so replays remain bit-identical.
- Run `make check` and `make test` before marking any (A) or (B) task complete.
- When adding a class verb, add a corresponding row in tests/run.lua that exercises its preview, AP cost, and resolution determinism.
- When deleting legacy code, search the whole repo (rg) for the symbol/path before removing; do not leave dead requires.
- Mark completed tasks per todo.txt convention: `x 2026-MM-DD ...rest of line preserved...`.

## Risks carried over

- R1 Readability collapse - mitigated by the (C) readability cluster.
- R2 Procgen unfairness - mitigated by (C) validator cluster.
- R3 Rotation confusion - mitigated by compass + ghost arrows task.
- R4 Scope explosion - this TODO is the budget; do not add tasks without removing equivalent ones.
- R5 Cover math opacity - flanking task must include a preview from each tile.
- R6 Legacy drag - (A) legacy-cleanup tasks resolve this; do not stop at "quarantine."
