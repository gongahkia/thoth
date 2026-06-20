# Cutscene Map

Combat cutscenes are transient render events. They do not enter save or replay snapshots.

Each mapped event expands into a render-only scene profile:

- `mood`: palette/atmosphere family.
- `focus`: which side or actor receives stage emphasis.
- `beat`: animation grammar for figures and impact shapes.
- `camera`: local shake/lift/sink behavior inside the cutscene panel.

| Event | Animation | Mood | Beat | Use |
| --- | --- | --- | --- | --- |
| `combat_start` | `intro` | `threat` | `arrival` | normal encounter starts |
| `boss_start` | `boss_intro` | `boss` | `reveal` | boss encounter starts |
| `ambush_start` | `ambush` | `panic` | `snap` | camp or surprise combat starts |
| `hero_skill` | `strike` | `action` | `strike` | hero uses a skill |
| `enemy_skill` | `strike` | `action` | `strike` | normal enemy uses a skill |
| `boss_skill` | `boss_strike` | `boss` | `smite` | boss uses a skill |
| `combat_win` | `victory` | `resolve` | `triumph` | normal encounter won |
| `boss_win` | `boss_victory` | `seal` | `triumph` | boss encounter won |
| `merchant_unlock` | `merchant_unlock` | `ledger` | `arrival` | Merchant ledger event fires |
| `combat_loss` | `defeat` | `doom` | `collapse` | party loses normal encounter |
| `boss_loss` | `boss_defeat` | `doom` | `collapse` | party loses boss encounter |
| `retreat` | `retreat` | `flight` | `exit` | party escapes combat |
| `retreat_blocked` | `blocked` | `panic` | `block` | retreat attempt is blocked |
| `death_door` | `death_door` | `threshold` | `threshold` | hero reaches death's door |
| `death_save` | `death_save` | `resolve` | `revive` | hero survives a deathblow check |
| `hero_death` | `hero_death` | `doom` | `fall` | hero dies |
| `resolve_virtue` | `resolve_virtue` | `virtue` | `resolve` | hero resolves positively |
| `resolve_affliction` | `resolve_affliction` | `affliction` | `fracture` | hero resolves negatively |
| `stress_break` | `stress_break` | `affliction` | `break` | stress causes collapse damage |
| `affliction_act` | `affliction_act` | `affliction` | `lash` | afflicted hero acts out |
| `falter` | `falter` | `dazed` | `stagger` | dazed actor loses a turn |
| `hero_hold` | `hero_hold` | `guard` | `hold` | hero passes a turn |
| fallback `campaign sealed` | `campaign_victory` | `seal` | `seal` | final campaign win |
| fallback death/danger text | `danger` | `doom` | `omen` | legacy danger log text |

Fallback text parsing exists for older status strings and tests, but new gameplay events should emit metadata through `Simulation:pushLog(message, meta)`.
