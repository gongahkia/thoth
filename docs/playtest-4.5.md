# Phase 4.5 Playtest

Date: 2026-06-19

Fixture: `tests/run.lua`, deterministic seed `1`.

Covered flow:

- Fresh game handoff to estate.
- Recruit and assign a Thief into the Warden / Duelist / Apothecary / Thief party.
- Start `archive_scout`.
- Camp, use watch order, and leave camp without ambush.
- Complete scout objective and return to estate.
- Send reserve hero to recovery.
- Start second mission `archive_cleansing`.

Verification:

- `make check` covers the fixture.
