# Dev Log

## 2026-06-22 XCOM-Lite Vertical Slice Pivot

Source of truth:

- [Phase 1B roadmap](../TODO.md)
- `docs/tactical-research-index.md` phase decision table
- `WORLD-LORE.md` vertical-slice boundary

Decision:

- Reposition Thoth as deterministic XCOM-lite tactics in the Great Stack, not tactical RPG/expedition legacy.
- Current playable slice is Buried Archive only. Salt Cistern and Ember Warrens remain future-zone content until they pass the same validator, replay, screenshot, and release gates.
- Core tactical contract: six distinct squad classes, six procedural Buried Archive missions, AP actions, cover, LoS, flanking, fog-of-war, overwatch cones, hidden intent, objective pressure, and no hit-roll RNG.
- Hidden intent is authored before reveal; fog, rotation, light, and class tools expose information without rerolling enemy plans.
- Storefront/docs language must describe the current six-unit tactical slice and use current tactical media.

Risk:

- Scope pressure now moves to release polish: screenshots, package, tag, and devlog must not imply multi-zone campaign content.
- Source citations justify patterns only; implementation evidence remains tests, validator output, replay fixtures, and smoke captures.

## 2026-06-21 Tactical Scope Audit

Decision:

- Keep Phase 7 completion tied to inspectable data contracts: objective families, boss variants, option unlocks, ending routes, replay fixtures, procgen reports, asset checks, and CI smoke gates.

Cut:

- Do not keep completed roadmap rows in `TODO.md`; completion evidence lives in tactical docs, tests, CI, and git history.

Risk:

- Broad crosscutting rows can look complete while future additions bypass the gates; keep asset, replay, validator, and CI checks mandatory for new tactical work.

## 2026-06-20

Learned:

- Asset audit scope must include generated manifests, READMEs, preview captures, and metadata-only files, not just imported binaries.
- Credits parsing consumes every Markdown table row in `docs/asset-licenses.md`, so tests should assert representative coverage instead of fixed row counts.
- `make check` packages docs and excludes `assets/previews/*`, while license coverage still needs tracked preview files audited.

Risk introduced:

- `tests/assets.lua` now depends on `git ls-files assets`; it verifies tracked assets in a checkout, but requires `git` in the test environment.

## 2026-06-20 Phase 7 CI Check

- Latest remote `Thoth Lua CI` run: success, run `27834182764`, branch `main`, commit `f8cb13e`.
- Local `phase1-engine-port` has no remote branch/run; current verification for local commits is `make check` pass.
- Risk: phase-completion tags created locally need a push before GitHub Actions can verify those exact refs.

## 2026-06-20 Release Prep

Learned:

- Deterministic balance scenarios are useful for regression pressure, but they do not replace manual Merchant feel/playthrough sign-off.
- `--preview-capture` can produce store-page review screenshots from smoke states without touching package contents.
- RC and post-launch tasks need intake forms plus triage tables before feedback arrives, otherwise the launch week becomes ad hoc.

Risk introduced:

- Final preview PNGs are smoke-state captures at 1280x720; they are suitable for draft review but not a substitute for final trailer footage or 1080p/4K press kit exports.
