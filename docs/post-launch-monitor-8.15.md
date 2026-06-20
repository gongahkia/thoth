# Post-Launch Monitor 8.15

Status: monitoring plan. Do not remove TODO 8.15 until the first launch week has been monitored and critical bugs are fixed or explicitly ruled out.

## First-Week Cadence

- Day 0: verify itch downloads, GitHub release assets, and launch links.
- Day 1: triage all crash, install, and save/load reports.
- Day 3: review balance/feel reports for severe blockers.
- Day 7: publish hotfix decision.

## Critical Bug Criteria

- Game cannot launch on a supported platform.
- New game cannot start.
- Save/load corrupts progress.
- Combat softlocks.
- Release artifact missing required files.
- Accessibility setting prevents normal navigation.

## Hotfix Requirements

- Reproduce or mark `No access.`
- Add or update deterministic test where possible.
- Run `make check`.
- Run `make package-title-smoke`.
- Tag hotfix if released.
- Record affected versions and fix commit.

## Incident Table

| Date | Source | Issue | Severity | Decision | Fix/version |
|---|---|---|---|---|---|
| TBD | TBD | TBD | TBD | TBD | TBD |

## Completion Evidence Required

- First-week review date recorded.
- All critical reports triaged.
- Hotfix released within 7 days if required.
- No remaining launch blockers.
