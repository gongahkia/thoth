# UI Screen Sketches

Phase 2 design pass for the player-facing UI layer.

The TODO line says "10 screens" but names 11. This file covers all 11 named screens: title, new game, estate, party, equipment, trinkets, expedition HUD, pause, settings, game over, and credits.

## Global Rules

- Target baseline: 1280x720 from `conf.lua`; all panels must clamp to usable bounds on smaller resizable windows.
- Persistent visual stack: render3d world or animated scene behind UI, top status strip for game state, bottom command strip for current decisions, right side detail rail where useful.
- Input parity: every mouse target needs keyboard focus order; later controller work maps d-pad/left stick to the same focus graph.
- Save model: title and pause call `Save.read` / `Save.write`; gameplay screens dispatch `Simulation.commands`.
- Color roles: charcoal base, bone text, brass focus, red danger, green recovery, blue settings/system, violet journal/lore.
- Do not hide game-critical actions behind hover-only tooltips.

## App States

| UI state | Primary data | Primary commands |
|---|---|---|
| `title` | save probe, settings | new game, continue, settings, quit |
| `new_game` | seed, timer/difficulty defaults | create `Simulation.new(seed)` |
| `squad_loadout` | six slice classes, starter loadouts | confirm one distinct unit per class |
| `estate` | `sim.estate`, mission board, roster | recruit, recover, train, upgrade, buy, launch |
| `party` | roster, `sim.party`, mission | `assignParty`, buy provisions |
| `equipment` | selected hero, gear, skills | `upgradeSkill`, `upgradeGear`, treatment |
| `trinkets` | estate trinkets, sets, selected hero | `equipTrinket`, `unequipTrinket`, buy/sell |
| `expedition_hud` | `sim.expedition`, party, world | move, interact, camp, torch, ration, retreat |
| `pause` | active simulation/save/settings | resume, save, settings, quit title |
| `settings` | audio/input/accessibility values | apply settings, keybind capture |
| `game_over` | campaign outcome snapshot | restart, title, credits |
| `credits` | `docs/asset-licenses.md` | scroll, title |

## Flow

```text
title -> squad_loadout -> expedition_hud -> estate
title -> continue -> estate|expedition_hud|game_over
any gameplay state -> pause -> settings
estate -> equipment|trinkets|credits
expedition_hud -> combat/curio/camp overlays -> expedition_hud|estate|game_over
```

## Title

Purpose: boot gate, save discovery, quit path.

```text
+------------------------------------------------------------------------------+
| animated dungeon/estate background from render3d                              |
|                                                                              |
|  THOTH                                                                       |
|  account the dead                                                            |
|                                                                              |
|  > New Game                                                                  |
|    Continue                save date/week if present                          |
|    Settings                                                                  |
|    Credits                                                                   |
|    Quit                                                                      |
|                                                                              |
| bottom-left: version/build      bottom-right: keyboard/controller glyphs      |
+------------------------------------------------------------------------------+
```

Notes:
- Primary focus starts on Continue when a save exists, otherwise New Game.
- Continue disabled state must still explain "no save" in the status line.
- Title background should reuse current world/cutscene rendering rather than a flat menu.

## New Game

Purpose: create a campaign with explicit seed and campaign rules.

```text
+------------------------------------------------------------------------------+
| THOTH / New Game                                                             |
|                                                                              |
|  Campaign                                                                    |
|  +------------------------------+   +--------------------------------------+  |
|  | seed: 20260618               |   | twin timer                           |  |
|  | timer: standard              |   | weeks 14 / dread 18 / deaths 8       |  |
|  | difficulty: standard         |   | factions: Stack, Salt, Ember         |  |
|  +------------------------------+   +--------------------------------------+  |
|                                                                              |
|  Starting estate preview                                                     |
|  roster slots / recruit slots / starting gold / first mission board          |
|                                                                              |
|  [ Start Campaign ]      [ Back ]                                            |
+------------------------------------------------------------------------------+
```

Notes:
- Seed edit is optional first pass; if omitted, display generated seed before launch.
- Start creates `Simulation.new(seed)` and enters estate.
- Back returns to title without mutating existing save.

## Squad Loadout

Purpose: choose the first tactical squad before mission 1.

```text
+------------------------------------------------------------------------------+
| Squad Loadout                                           mission 1 / 6 of 6    |
|------------------------------------------------------------------------------|
| [x] Warden        cover and objective guard       line_guard / claim_anchor   |
| [x] Duelist       flank and reposition            red_line / patron_shadow    |
| [x] Apothecary    repair and rescue support       field_triage / smoke_binder |
| [x] Thief         route and extraction utility    ghost_route / courier_cut   |
| [x] Arcanist      seal and intent control         seal_reader / line_bender   |
| [x] Lamplighter   route light and overwatch       beacon_runner / cone_keeper |
|                                                                              |
| [Back]                                                     [Start Mission]    |
+------------------------------------------------------------------------------+
```

Notes:
- Duplicate classes are disabled for mission 1; the first slice ships one tactical role implementation per class.
- Start is disabled unless all six distinct slice classes are selected.

## Estate Hub

Purpose: campaign operating room.

```text
+------------------------------------------------------------------------------+
| week / gold / heirlooms / renown / dread / boss kills / current event         |
|------------------------------------------------------------------------------|
| Buildings            Mission Board                  Journal / Campaign       |
| [stagecoach 0]       [archive scout] [cleanse]       latest documents        |
| [guild 0]            [gather]        [boss]          timer/faction copy      |
| [forge 0]                                                                    |
| [infirmary 0]        Recruits                         Party Snapshot         |
|                      [recruit] [recruit] [recruit]    R1 R2 R3 R4            |
|------------------------------------------------------------------------------|
| bottom command strip: Party / Equipment / Trinkets / Journal / Launch         |
+------------------------------------------------------------------------------+
```

Notes:
- This replaces the current all-in-one `Render.drawEstatePanel` with clear tabs.
- Existing click actions remain valid: recruit, market, recover, train, gear, party assignment.
- Mission cards should expose location, kind, difficulty, objective, provision kit, and reward pressure.

## Party Formation

Purpose: select ranks and provisions before launch.

```text
+------------------------------------------------------------------------------+
| Party Formation                                          selected mission     |
|------------------------------------------------------------------------------|
| Roster                         Rank Line                 Provision Cart       |
| [hero row]                     +----+----+----+----+     torch  [-] 4 [+]     |
| [hero row]                     | R1 | R2 | R3 | R4 |     ration [-] 8 [+]     |
| [hero row]                     +----+----+----+----+     shovel [-] 1 [+]     |
| filters: all/rest/stress       party stats summary       pack 7/12            |
|                                                                              |
| [Auto Fill] [Clear] [Launch Expedition] [Back]                                |
+------------------------------------------------------------------------------+
```

Notes:
- Drag/drop is preferred, but keyboard must support pick hero -> choose rank.
- Launch is disabled until four living non-recovering heroes are assigned.
- Provision controls call `buyProvision` until later cart decrement support exists.

## Equipment

Purpose: hero upgrade/treatment workspace.

```text
+------------------------------------------------------------------------------+
| Equipment                                                    estate resources |
|------------------------------------------------------------------------------|
| Hero list                 Selected Hero                                       |
| [R1 name/class/stress]    name / class / level / xp / hp / stress             |
| [R2 ...]                  weapon [upgrade]    armor [upgrade]                 |
| [bench ...]               skills: [1 train] [2 train] [3 train] [4 train]     |
|                           quirks/diseases: [treat] [lock]                    |
|                           recovery activities: [abbey] [physic] [debt]       |
|                                                                              |
| [Back] [Party] [Trinkets]                                                     |
+------------------------------------------------------------------------------+
```

Notes:
- Uses `upgradeSkill`, `upgradeGear`, `recoverHero`, `treatQuirk`, `lockQuirk`, `treatDisease`, and `dismissHero`.
- Disabled rows must show the blocking reason: gold, recovery, party rank, roster minimum.
- Equipment screen owns hero detail; estate screen only summarizes.

## Trinkets

Purpose: inventory, market, set comprehension, assignment.

```text
+------------------------------------------------------------------------------+
| Trinkets                                                   gold / heirlooms   |
|------------------------------------------------------------------------------|
| Inventory Grid                         Selected Hero Slots                    |
| [trinket x2] [trinket x1]              slot 1: [item or empty]                |
| [set piece]  [set piece]               slot 2: [item or empty]                |
|                                        [equip] [unequip] [sell]               |
| Set Bonus Preview                                                            |
| set name: 2pc effect / 4pc effect / owned 2 of 4                              |
|------------------------------------------------------------------------------|
| Market: [offer price] [offer price] [offer price]                             |
+------------------------------------------------------------------------------+
```

Notes:
- Tooltip content comes from `Registry.trinkets` and `Registry.trinketSets`.
- Set visualization must show owned, equipped, and missing pieces separately.
- Equip flow: choose hero, choose trinket, choose slot; keyboard focus must not require drag.

## Expedition HUD

Purpose: moment-to-moment exploration.

```text
+------------------------------------------------------------------------------+
| location / mission progress / torch / pack / status / view rotation           |
|------------------------------------------------------------------------------|
|                                                                              |
|                       render3d world viewport                                 |
|                                                                              |
|                                                           Party rail          |
|                                                           R1 hp stress        |
|                                                           R2 hp stress        |
|                                                           R3 hp stress        |
|                                                           R4 hp stress        |
|------------------------------------------------------------------------------|
| Interact [Space]  Camp [C]  Torch [T]  Ration [H]  Retreat [R]  Pause [Esc]  |
+------------------------------------------------------------------------------+
```

Notes:
- Current `drawHud`, `drawSidePanel`, and `drawWorld` map naturally to this state.
- Interaction strip changes label based on current tile: exit, curio, door, combat, empty.
- Movement and camera rotation stay available while command focus is not in a modal.

## Pause

Purpose: deterministic interruption point.

```text
+------------------------------------------------------------------------------+
| dim current gameplay frame                                                    |
|                                                                              |
|                         Paused                                               |
|                         [Resume]                                             |
|                         [Save]                                               |
|                         [Settings]                                           |
|                         [Quit to Title]                                      |
|                                                                              |
|                         last save/status line                                |
+------------------------------------------------------------------------------+
```

Notes:
- Resume clears pause without advancing simulation.
- Save calls `Save.write`.
- Quit to title uses 2.15 confirmation when expedition/combat is active.

## Settings

Purpose: audio, input, accessibility, and persistence later.

```text
+------------------------------------------------------------------------------+
| Settings                                                                     |
|------------------------------------------------------------------------------|
| Audio                         Input                                           |
| master volume [------|---]    Move up     [W]                                |
| music volume  [----|-----]    Move down   [S]                                |
| sfx volume    [-------|--]    Interact    [Space]                            |
|                                                                              |
| Accessibility                 Display                                        |
| high contrast [ ]             screen shake [ ]                               |
| colorblind    [off v]         reduced motion [ ]                             |
| subtitles     [x]             font scale [100% v]                            |
|                                                                              |
| [Apply] [Reset Defaults] [Back]                                               |
+------------------------------------------------------------------------------+
```

Notes:
- First implementation can store settings in app memory; 7.11 persists separate settings file.
- Keybind capture must reserve Esc for cancel.
- Settings is reachable from title and pause.

## Game Over

Purpose: clear terminal campaign summary.

```text
+------------------------------------------------------------------------------+
| Game Over / Campaign Sealed                                                   |
|------------------------------------------------------------------------------|
| reason / ending route / week / dread / renown / fallen count                  |
|                                                                              |
| Party fate                         Faction state                              |
| [hero summary]                     Stack  state                               |
| [hero summary]                     Salt   state                               |
| [graveyard]                        Ember  state                               |
|                                                                              |
| unlocked documents / final narration                                          |
|                                                                              |
| [Restart] [Title] [Credits]                                                   |
+------------------------------------------------------------------------------+
```

Notes:
- Trigger on `sim.estate.campaign.lost` or `victory`.
- Summary reads snapshot only; restart creates a fresh sim.
- Ending copy comes from `Simulation:endingScreenCopy(routeKey)`.

## Credits

Purpose: license-safe attribution and project credits.

```text
+------------------------------------------------------------------------------+
| Credits                                                                      |
|------------------------------------------------------------------------------|
| project title / team                                                          |
|                                                                              |
| Asset Attributions                                                            |
| sprite/audio/source/license/notes from docs/asset-licenses.md                 |
|                                                                              |
| Libraries                                                                     |
| g3d license                                                                   |
| LOVE                                                                          |
|                                                                              |
| [Back]                                                     scroll indicator   |
+------------------------------------------------------------------------------+
```

Notes:
- Credits screen should eventually be generated from `docs/asset-licenses.md`.
- Must be accessible from title and game-over.
- No attribution text should be hardcoded in multiple places.

## Supporting Overlays

These are not in the 2.1 parenthetical list, but later Phase 2 tasks need them.

```text
combat: bottom skill strip, turn order, ally/enemy ranks, target picker
curio: modal with safe / greedy / repair / leave and result reveal
camp: respite budget, 7 camp skills, hero assignment, finish camp
journal: document list, graveyard epitaphs, selected entry reader
tutorial: anchored overlay over the active screen, never blocks critical status
toast: achievement/debug unlock notification, top-right stack
```

## Implementation Order

1. Add app-level `uiState` and title/new-game/pause/settings routing before changing simulation.
2. Split estate panel into estate, party, equipment, and trinket render/input modules.
3. Reuse existing hitbox arrays first; add a generic focus table before keyboard/controller pass.
4. Keep combat, camp, curio, and tutorial as modal overlays over the active gameplay screen.
5. Add smoke flags for title, estate, expedition, settings, and game-over once screens exist.
