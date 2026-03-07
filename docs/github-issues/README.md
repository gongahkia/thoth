# GitHub issue drafts for the next `thoth` roadmap

These drafts synthesize the requested improvements into a sequenced set of GitHub issues.

## Recommended order

1. `00-roadmap-deterministic-cross-engine-runtime.md`
2. `01-runtime-determinism-foundation.md`
3. `02-input-recording-and-replay.md`
4. `03-runtime-snapshots-save-load-and-rollback.md`
5. `04-capability-based-adapter-contract.md`
6. `05-input-and-platform-coverage.md`
7. `06-runtime-observability-and-debug-hud.md`
8. `07-showcase-example-game.md`
9. `08-gameplay-primitives-camera-collision-animation.md`
10. `09-tilemaps-and-navigation-helpers.md`
11. `10-ecs-query-helpers-and-behavior-trees.md`
12. `11-core-containers-expansion.md`
13. `12-platform-neutral-utilities.md`
14. `13-api-style-unification.md`
15. `14-developer-ergonomics.md`
16. `15-testing-hardening-and-property-coverage.md`

## Dependency notes

- `01` should land before `02`, `03`, and `06`.
- `04` should land before `05`.
- `01` through `06` should exist before `07` so the showcase demonstrates the new runtime direction.
- `08`, `09`, `10`, `11`, and `12` can run in parallel once the API direction in `13` is agreed.
- `14` and `15` are cross-cutting and should accompany the implementation work rather than wait until the end.

## Publishing

Use `scripts/create_github_issues.sh --dry-run` to preview the issue titles.

Use `scripts/create_github_issues.sh` to publish them to the repository discovered from `origin`.

The publish script requires a valid `gh` authentication session.
