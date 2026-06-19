# Dev Log

## 2026-06-20

Learned:

- Asset audit scope must include generated manifests, READMEs, preview captures, and metadata-only files, not just imported binaries.
- Credits parsing consumes every Markdown table row in `docs/asset-licenses.md`, so tests should assert representative coverage instead of fixed row counts.
- `make check` packages docs and excludes `assets/previews/*`, while license coverage still needs tracked preview files audited.

Risk introduced:

- `tests/assets.lua` now depends on `git ls-files assets`; it verifies tracked assets in a checkout, but requires `git` in the test environment.
