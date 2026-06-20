# Merchant Balance Pass 6.14-6.15

Status: automated deterministic expedition evidence. TODO 6.14 and 6.15 remain open until manual/playtest sign-off.

Command:

```sh
make merchant-balance-pass
```

Scope:

- 10 deterministic expedition scenarios with Merchant in party.
- 10 matched deterministic expedition scenarios without Merchant.
- Real combat loop: `startExpedition`, `startCombat`, repeated `combatSkill`/`passTurn`, `finishCombat`, `endExpedition`.
- Coverage spans resolve levels 1, 3, and 5; dread 0, 4, 9, 13, 16, and 18; Archive, Cistern, and Warrens missions.

Completion criteria for this automated pass:

- All 20 scenarios complete their mission objective.
- No party wipe.
- No combat timeout.
- Merchant passive can trigger at dread-tier pack thresholds without blocking non-Merchant completions.

Result from 2026-06-20:

```text
merchant_balance_pass=ok
passes=20
merchant_passes=10
baseline_passes=10
failures=0
```

| id | kind | seed | mission | lvl | dread | turns | hp% min | stress max | loot | pack | cut |
|---|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---|
| archive_t1_entry | merchant | 7101 | archive_cleansing | 1 | 0 | 22 | 100 | 23 | 70+0r | 12 | - |
| archive_t1_entry | baseline | 8101 | archive_cleansing | 1 | 0 | 21 | 100 | 20 | 70+0r | 12 | - |
| archive_t1_pack | merchant | 7102 | archive_cleansing | 1 | 9 | 28 | 100 | 25 | 70+0r | 13 | pack |
| archive_t1_pack | baseline | 8102 | archive_cleansing | 1 | 9 | 22 | 100 | 11 | 70+0r | 12 | - |
| archive_t3_reeve | merchant | 7103 | archive_silence_reeve | 3 | 4 | 12 | 89 | 0 | 35+0r | 12 | - |
| archive_t3_reeve | baseline | 8103 | archive_silence_reeve | 3 | 4 | 10 | 100 | 0 | 35+0r | 12 | - |
| archive_t3_witness | merchant | 7104 | archive_witness_confession | 3 | 9 | 31 | 72 | 31 | 70+0r | 13 | pack |
| archive_t3_witness | baseline | 8104 | archive_witness_confession | 3 | 9 | 16 | 68 | 18 | 70+0r | 12 | - |
| archive_t3_regent | merchant | 7105 | archive_regent | 3 | 9 | 24 | 70 | 27 | 120+0r | 13 | pack |
| archive_t3_regent | baseline | 8105 | archive_regent | 3 | 9 | 16 | 75 | 22 | 120+0r | 12 | - |
| cistern_t3_choir | merchant | 7106 | cistern_silence_choir | 3 | 9 | 12 | 92 | 4 | 35+0r | 13 | pack |
| cistern_t3_choir | baseline | 8106 | cistern_silence_choir | 3 | 9 | 12 | 100 | 6 | 35+0r | 12 | - |
| cistern_t3_bell | merchant | 7107 | cistern_bell | 3 | 13 | 22 | 82 | 0 | 120+0r | 13 | pack |
| cistern_t3_bell | baseline | 8107 | cistern_bell | 3 | 13 | 17 | 93 | 7 | 120+0r | 12 | - |
| ember_t5_route | merchant | 7108 | ember_cleansing | 5 | 13 | 7 | 84 | 5 | 70+0r | 13 | pack |
| ember_t5_route | baseline | 8108 | ember_cleansing | 5 | 13 | 9 | 70 | 5 | 70+0r | 12 | - |
| ember_t5_vicar | merchant | 7109 | warrens_douse_vicar | 5 | 16 | 12 | 100 | 5 | 35+0r | 13 | pack |
| ember_t5_vicar | baseline | 8109 | warrens_douse_vicar | 5 | 16 | 10 | 100 | 0 | 35+0r | 12 | - |
| ember_t5_prioress | merchant | 7110 | ember_prioress | 5 | 18 | 12 | 80 | 11 | 120+0r | 13 | pack |
| ember_t5_prioress | baseline | 8110 | ember_prioress | 5 | 18 | 7 | 75 | 10 | 120+0r | 12 | - |

Notes:

- Merchant parties complete every scenario, but usually take more turns than matched baseline parties.
- Merchant pack-slot value appears at dread tier 2+ in the covered cases.
- This does not verify external feel, economy pacing across full campaigns, or human tactical variance.
