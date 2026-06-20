# Dev Log

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
