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
