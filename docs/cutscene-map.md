# Cutscene Map

Combat cutscenes are transient render events. They do not enter save or replay snapshots.

| Event | Animation | Use |
| --- | --- | --- |
| `combat_start` | `intro` | normal encounter starts |
| `boss_start` | `boss_intro` | boss encounter starts |
| `ambush_start` | `ambush` | camp or surprise combat starts |
| `hero_skill` | `strike` | hero uses a skill |
| `enemy_skill` | `strike` | normal enemy uses a skill |
| `boss_skill` | `boss_strike` | boss uses a skill |
| `combat_win` | `victory` | normal encounter won |
| `boss_win` | `boss_victory` | boss encounter won |
| `combat_loss` | `defeat` | party loses normal encounter |
| `boss_loss` | `boss_defeat` | party loses boss encounter |
| `retreat` | `retreat` | party escapes combat |
| `retreat_blocked` | `blocked` | retreat attempt is blocked |
| `death_door` | `death_door` | hero reaches death's door |
| `death_save` | `death_save` | hero survives a deathblow check |
| `hero_death` | `hero_death` | hero dies |
| `resolve_virtue` | `resolve_virtue` | hero resolves positively |
| `resolve_affliction` | `resolve_affliction` | hero resolves negatively |
| `stress_break` | `stress_break` | stress causes collapse damage |
| `affliction_act` | `affliction_act` | afflicted hero acts out |
| `falter` | `falter` | dazed actor loses a turn |
| `hero_hold` | `hero_hold` | hero passes a turn |

Fallback text parsing exists for older status strings and tests, but new gameplay events should emit metadata through `Simulation:pushLog(message, meta)`.
