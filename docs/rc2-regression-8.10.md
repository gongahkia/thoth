# RC2 Regression Sweep 8.10

Status: checklist. Do not remove TODO 8.10 until RC2 is built and the final regression sweep passes.

## Required Commands

```sh
make check
make package-title-smoke
```

## Manual Flow

- Clean title launch.
- New game.
- Estate roster and provisions.
- Start Archive scout.
- Trigger entry combat.
- Use one skill.
- Retreat.
- Save/load or relaunch continue.
- Settings open, adjust, close.
- Credits open and return.
- Replay viewer opens from title if replay fixture exists.

## Pass/Fail Table

| Area | Result | Evidence |
|---|---|---|
| automated checks | TBD | `make check` output |
| package title smoke | TBD | `make package-title-smoke` output |
| new game | TBD | tester notes |
| estate flow | TBD | tester notes |
| expedition flow | TBD | tester notes |
| combat flow | TBD | tester notes |
| save/load | TBD | tester notes |
| settings | TBD | tester notes |
| credits | TBD | tester notes |
| replay viewer | TBD | tester notes |

## Completion Evidence Required

- RC2 artifact names and checksums.
- All automated commands pass.
- Manual flow passes on at least one clean local install.
- Any release blockers fixed before 1.0 tag.
