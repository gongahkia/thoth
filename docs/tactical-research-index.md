# Tactical Research Index

Checked: 2026-06-22

Purpose: source-backed design constraints for Thoth's tactical pivot. These notes are pattern references only. They are not permission to copy names, factions, layouts, UI art, prose, or ability kits.

Use this file before any mechanic/content batch enters implementation. A borrowed pattern is acceptable only if the Thoth version changes fiction, rules, costs, UI language, and counterplay.

## Phase Decisions 2026-06-22

Source IDs cite the source index below. These are decisions taken for the Buried Archive vertical slice, not general permission to copy the referenced games.

| Decision | Source pattern citations | Thoth phase decision | Implementation evidence |
| --- | --- | --- | --- |
| XCOM-lite pivot, not tactical RPG legacy | S1, S2, S3, S4, S8, S13, S31 | Ship deterministic tile tactics with AP, cover, LoS, objectives, and declared outcomes. Reject hit-percentage attacks, random tactical damage, and post-commit combat RNG. RNG stays in route/board setup, enemy roster selection, and rewards. | `TODO.md` pitch/exit criteria; `docs/tactical-core-rules.md`; `src/game/tactics/state.lua`; `tests/run.lua` deterministic intent, AP, replay, and validator checks. |
| Fog-of-war plus hidden intent | S4, S8, S9, S11, S47 | Fog hides enemies and intent footprints outside visible tiles, but the hidden intent is authored before reveal. Reveal/rotation/light changes UI knowledge only; it does not reroll the action. | `tests/run.lua` fog summary, ghost markers, hidden intent reveal, and reveal-as-UI-data checks; `docs/tactical-intent-rules.md`; `src/game/tactics/los.lua`. |
| Overwatch cones and threat zones | S4, S6, S48 | Overwatch is an AP-spend board commitment with explicit watched tiles, source, reaction, trigger limit, and phase timing. Cone geometry is Thoth's operational form; the source pattern is reaction fire/area denial, not copied UI. | `src/game/tactics/state.lua` `commands.overwatchCone`; `tests/run.lua` overwatch cone, stun/mark reactions, trigger expiry, and overlay checks; `docs/tactical-ui-catalog.md`. |
| Directional cover and flanking | S4, S5, S19, S36, S47, S53 | Cover is stored as tile-edge authority. Flanking is deterministic edge invalidation plus previewed damage/cost rules; it never changes hidden hit odds. | `src/game/tactics/cover.lua`; `docs/tactical-los-cover-rules.md`; `tests/run.lua` flank preview, protected vector, flanking damage, and remove-cover mode checks. |
| Six-unit starter squad | S4, S40, S41, S42, S48, S49 | Vertical slice uses six distinct starter classes with board verbs and two readable loadout choices each. Class identity must describe actions on tiles, cover, objectives, LoS, or intent, not abstract RPG roles. | `src/game/tactics/class_catalog.lua`; `tests/run.lua` six-class roster audit, six HUD portraits/AP pools, AP economy, loadout unlock, and class replay fixture checks. |
| Buried Archive only for current slice | S1, S2, S9, S34, S35 | Salt Cistern and Ember Warrens stay future-zone content until they pass the same validator, replay, readability, screenshot, and release gates as Buried Archive boards. | `WORLD-LORE.md` vertical-slice header; `src/game/tactics/archive/future_zones.lua`; `tests/run.lua` future-zone archive/live-catalog separation. |

Phase guardrails:

- Exact citations do not prove a mechanic belongs in Thoth. They only justify the source pattern under review.
- Fan/community sources such as S5 and S11 are acceptable as mechanics summaries, but phase decisions should prefer official/manual/interview sources where available.
- Any mechanic added after this phase needs a `Thoth transformation` entry, preview/UI proof, and replay or validator proof before it leaves prototype status.

## Source Index

| ID | Source | Extracted pattern | Thoth transformation |
| --- | --- | --- | --- |
| S1 | https://subsetgames.com/itb.html | Enemy attacks are telegraphed; objectives and friendly fire make the board the problem. | Stack procedures post exact harm before enforcement; the player redirects claims, bodies, cover, and objectives instead of gambling on hit chance. |
| S2 | https://media.gdcvault.com/gdc2019/presentations/Into%20the%20Breach%20Postmortem%20Final.pdf | Design constraints: readability, limited menus, low numbers, short turns, interesting choices. | Tile rules must be short enough for inspector text and replay fixtures; cut mechanics that need hidden math or long explanation. |
| S3 | https://www.gamedeveloper.com/design/-i-into-the-breach-i-dev-on-ui-design-sacrifice-cool-ideas-for-the-sake-of-clarity-every-time- | Clarity outranks novelty; unclear attack indicators force cuts. | Any Thoth mechanic must show source, target, path, timing, and counterplay in overlays before commitment. |
| S4 | https://www.feralinteractive.com/en/manuals/xcom2/latest/steam/ | Tactical actions include fire, reload, overwatch, hunker, hack, loot timers, and projected outcomes. | Keep AP actions operational: move, attack, brace, interact, reveal, repair, carry, overwatch, extract. No percentage-to-hit action preview. |
| S5 | https://www.ufopaedia.org/Cover_%28EU2012%29 | Cover and flanking are directional, with cover indicators changing when flanked. | Cover edges are tile data. Flanking invalidates a cover edge deterministically rather than changing aim odds. |
| S6 | https://www.gearsofwar.com/en-us/news/dev-blog-gameplay/ | Flexible AP and player-drawn overwatch cones create player-authored threat zones. | Threat zones are witness lanes, lamp cones, shield lines, and writ arcs with explicit AP spend and trigger limits. |
| S7 | https://www.gearsofwar.com/en-us/news/dev-blog-bosses/ | Bosses act as combat puzzles with telegraphed impact zones, adds, cover movement, and phase changes. | Boss procedures expose weak points through rotation, mutate terrain, threaten objectives, and keep at least one non-damage counter. |
| S8 | https://www.shacknews.com/article/89531/invisible-inc-programmer-discusses-design-stealth-and-procedurally-generated-stages | Stealth improved by removing random combat features, making guard intentions readable, and spending resources to gather information. | Exposure replaces hidden alarm rolls; scouting/reveal spends AP, light, or route authority to unredact intent and map marks. |
| S9 | https://gdcvault.com/play/1021919/Designing-Procedural-Stealth-for-Invisible | Novel procedural stealth creates hidden pitfalls and requires validation discipline. | Board generation must ship with validators, fixed seeds, replay hashes, and reject reasons. |
| S10 | https://www.ubisoft.com/en-us/game/mario-rabbids/sparks-of-hope | Free movement, dash, ally-assisted movement, cover, and sequencing inside a turn. | Movement preview can include dash, brace-vault, drag, and carry paths, but final position locks before attack/intent resolution. |
| S11 | https://slay-the-spire.fandom.com/wiki/Intent | Enemy intent categories communicate attack, defend, buff, debuff, escape, stunned, and unknown. | Thoth uses exact, category, and redacted notices; unknown means type withheld by seal/light/angle, not arbitrary surprise damage. |
| S12 | https://sinisterdesign.net/12-ways-to-improve-turn-based-rpg-combat-systems/ | Good tactical systems emphasize emergent complexity, clarity, determinism, and player tools. | Prefer few composable tile verbs over broad stat lists; every status must change board state or previewed choices. |
| S13 | https://theplayersaid.com/2024/06/06/best-3-games-with-deterministic-combat/ | Deterministic combat shifts focus to positioning and planning instead of dice outcomes. | After board load, RNG cannot decide tactical hits, misses, cover, or declared damage. |
| S14 | https://goldplatedgames.com/2018/12/12/review-868-hack/ | Compact grids can create depth through tight enemy sets, risk/reward collection, and positional pressure. | Prototype boards should be small, dense, and objective-led; extraction greed should spawn/route pressure before the next board, not random mid-resolution damage. |
| S15 | https://www.electrondance.com/hoplite/ | Movement-linked attacks and small maps create readable tactical pressure. | Class tools should make movement itself meaningful: shove, brace, vault, drag, line-break, seal-step. |
| S16 | https://data.europa.eu/apps/data-visualisation-guide/accessible-colour-palettes | Palettes need colorblind checks; visually similar colors fail under common simulations. | Tactical overlays must pair color with shape, icon, pattern, and tile outline; color-only meaning is rejected. |
| S17 | https://www.nceas.ucsb.edu/sites/default/files/2022-06/Colorblind%20Safe%20Color%20Schemes.pdf | Avoid red/green reliance, use tested palettes, and check with simulators. | Intent, cover, LoS, hazard, and objective overlays need safe hue pairs plus non-color redundancy. |
| S18 | https://interfaceingame.com/games/into-the-breach/ | Tactical games benefit from dense overlay references: combat, mission, environment, tutorial, and objective screens. | Screenshot-smoke tests should capture overlay states, not only menus. |
| S19 | https://media.gdcvault.com/gdc2018/presentations/Hess_Brian_PlotAndParcel.pdf | XCOM 2 procedural plots use object spacing, cover density, and LoS as level-quality constraints. | Thoth board grammar emits cover fields, sight breaks, and validation-facing component counts before the board ships. |
| S20 | https://procedural-generation.isaackarth.com/2017/05/04/priorities-in-generation-generalizing-from.html | Invisible Inc-style generation favors playable rooms, corridors, goals, exits, patrols, and gated paths over realistic interiors. | Thoth generators carve explicit tactical rooms, corridors, objective anchors, spawn pockets, and hazard gates first. |
| S21 | https://www.wired.com/story/into-the-breach-review-ftl-developers-new-game-subset-games/ | Compact deterministic boards keep tactical state readable and failures attributable to decisions. | Thoth board grammar starts small, exposes hazards/objectives/spawns, and keeps RNG before board load. |
| S22 | https://journal.stuffwithstuff.com/2014/12/21/rooms-and-mazes/ | Dungeon generators can connect every reachable cell while producing different room/corridor layouts. | Zone boards use the shared connected grammar, then vary local terrain rules. |
| S23 | https://www.gamedeveloper.com/design/level-design-in-procedural-generation | Procedural levels can preserve critical path, side-room risk/reward, and testing discipline. | Thoth zone generators keep the grammar path stable while swapping zone-specific objective pressure and hazard rewards. |
| S24 | https://www.gridsagegames.com/blog/2014/06/procedural-map-generation/ | Map generators should choose methods that fit gameplay; prefabs provide control over important spaces. | Thoth starts from controlled tactical grammar pieces and uses zone dressing for replay variety. |
| S25 | https://book.leveldesignbook.com/process/combat/encounter | Encounters need pacing across beginning, middle, and ending, with readable cause and effect. | Thoth encounter director emits visible enemy mix, objective pressure, reinforcement timing, and retreat route metadata. |
| S26 | https://keithburgun.net/solving-some-major-problems-in-turn-based-tactical-wargames/ | Reinforcements can provide time pressure while objective capture remains the tactical focus. | Thoth schedules visible reinforcement turns against objective clocks instead of hidden random spawns. |
| S27 | https://www.pcgamer.com/games/fps/starship-troopers-extermination-implements-a-total-overhaul-to-its-spawning-system-adding-a-left-4-dead-style-ai-director-we-realized-that-our-original-spawning-system-while-functional-was-starting-to-show-its-limit/ | Director-style systems evaluate battlefield state for consistent spawn timing and location. | Thoth uses a deterministic pre-board director to author pressure, not runtime surprise spawning. |
| S28 | https://thehexagarden.com/blog/lets-make-a-map-1 | Roguelite maps create agency through branching paths with visible risk/reward and node variety. | Thoth run maps expose route choices, enclave requests, events, elite/repair routes, and boss gates. |
| S29 | https://www.diva-portal.org/smash/get/diva2%3A1565751/FULLTEXT02 | Slay the Spire-style maps use connected node types like enemy, elite, shop/event/resource, and boss, where path choice balances risk and power. | Thoth node previews state tactical risk, run reward, and boss-gate requirements before commitment. |
| S30 | https://thom.ee/blog/what-makes-or-breaks-agency-in-roguelikes/ | Roguelike agency improves when randomness happens before decisions and choices remain meaningful across a run. | Thoth route/event data is visible pre-action; tactical resolution stays deterministic after board load. |
| S31 | https://www.gamedeveloper.com/design/randomness-in-games-why- | Pre-randomness varies conditions before action; post-randomness changes results after action and can frustrate skill expression. | Thoth event RNG rolls before/after boards and locks tactical resolution after board start. |
| S32 | https://www.gridsagegames.com/blog/2025/08/designing-for-mastery-in-roguelikes-w-roguelike-radio/ | Procedural runs can preserve mastery by telegraphing notable changes and offering control before or after major events. | Thoth event layers record timing and prompts so route/deployment choices remain inspectable. |
| S33 | https://beigemoth.blog/2019/03/20/towards-a-better-roguelike-types-of-randomness/ | Randomness should create challenges without stripping the player's core ability to act. | Thoth event modifiers alter run context, not declared tactical command resolution. |
| S34 | https://openresearch-repository.anu.edu.au/bitstreams/a77810ba-c05b-43c2-bedd-86a4491c3027/download | Hybrid roguelike generators can use grammar plus physical-space generation while checking completability. | Thoth validates grammar components and retreat/objective solvability before accepting a board. |
| S35 | https://www.iccs-meeting.org/archive/iccs2021/papers/127460103.pdf | Procedural puzzle generation can estimate difficulty with explicit metrics before accepting generated content. | Thoth computes a difficulty budget from pressure contributors and rejects over-budget boards. |
| S36 | https://80.lv/articles/environment-storytelling-in-xcom-2 | XCOM 2 procedural maps used cover parcel systems so randomized spaces still had cover and readable tactical anchors. | Thoth requires cover fields and intent-density caps in generated tactical boards. |
| S37 | https://stackoverflow.com/questions/3064317/conceptually-how-does-replay-work-in-a-game | Deterministic replay records seeds and inputs, then replays them through the same simulation. | Thoth seeded exports record run seed, board seeds, route choices, event rolls, and replay hashes. |
| S38 | https://www.gridsagegames.com/blog/2017/05/working-seeds/ | Roguelike world seeds can derive map seeds so maps reproduce regardless of visit order. | Thoth derives board seeds from run seed and chosen route ids. |
| S39 | https://bugnet.io/blog/how-to-fix-a-replay-system-that-desyncs | Replay systems should record seeds/inputs and verify with checksums to catch divergence. | Thoth exports per-board replay hashes and an export hash for QA comparison. |
| S40 | https://www.gearsofwar.com/en-us/game-guide/classes/ | Classes branch into subclasses and skill sets that tailor soldiers to battlefield needs. | Thoth classes branch into named board verbs so loadouts describe actions on tiles, cover, objectives, and intent. |
| S41 | https://www.feralinteractive.com/en/manuals/xcom2/latest/steam/ | Soldier classes expose battlefield roles through unique abilities and specializations. | Thoth rejects RPG role labels at loadout level; the catalog records inspectable verbs such as brace, dash, reveal, douse, and insure. |
| S42 | https://www.ubisoft.com/en-us/game/mario-rabbids/sparks-of-hope/news-updates/54KqtyUg25UlrGQ20LC0ga/mario-rabbids-sparks-of-hope-a-deep-dive-into-combat-and-hero-archetypes | Compact hero kits combine movement options, weapons, techniques, and external powers for tactical variety. | Thoth caps class tools at 3-5 and uses 2 loadout slots so squad choices stay readable before board load. |
| S43 | https://www.ubisoft.com/en-us/game/mario-rabbids/sparks-of-hope/news-updates/40b42GpGsG7tlY5c2ETei8/palette-prime-tutorial-spoilers-ahead | Skill builds alter movement range, extra dashes, cooldowns, weapon use, healing, barriers, and positioning plans. | Thoth traits must alter AP, movement, LoS, cooldowns, cover use, or objective handling instead of raw stat inflation only. |
| S44 | https://subsetgames.com/itb_ae.html | Advanced Edition expands tactical variety with new squads, weapons, missions, enemies, bosses, and pilot abilities. | Thoth run progression unlocks new class loadout options rather than raw permanent damage/HP boosts. |
| S45 | https://entaltostudios.com/5-essential-tips-to-make-your-roguelite-game-work/ | Horizontal progression expands possibilities through weapons, mechanics, characters, modifiers, and visible unlock goals. | Thoth rewards `class_option` unlocks from run milestones and rejects stat-bearing class rewards. |
| S46 | https://www.gamedeveloper.com/design/game-design-deep-dive-i-darkest-dungeon-s-i-affliction-system | Stress consequences can create strong character texture but may also take agency away through autonomous behavior. | Thoth injuries/debts keep the psychological pressure and roster management, but encode deterministic tactical constraints instead of random turn loss. |
| S47 | https://www.feralinteractive.com/en/manuals/xcom2/latest/steam/ | Wounds, carry/evac, AP, movement, hazards, LoS, cover, and effects are visible tactical state. | Thoth consequence domains target AP, movement, LoS, cooldown, cover, objective repair, carry, and reveal rules. |
| S48 | https://www.gearsofwar.com/en-us/games/gears-tactics/ | Squad tactics scale through customizable squads, equipment, fast turn-based battles, and boss fights that change battle scale. | Thoth squad size changes AP, deployment slots, enemy budget, board footprint, objective anchors, spawn pockets, and retreat routes. |
| S49 | https://www.ubisoft.com/en-us/game/mario-rabbids/sparks-of-hope/news-updates/5h386nVuiWuW3OcxFDJgih/mario-rabbids-sparks-of-hope-a-tactical-game-for-everyone | Three-hero teams combine special abilities and external powers for battle synergies. | Thoth keeps small squad sizes readable and scales board variance only within 2-6 units. |
| S50 | https://subsetgames.com/itb.html | Telegraphed enemy attacks make every enemy action analyzable and counterable before resolution. | Thoth enemy archetypes require preview text, exact intent metadata, and counterplay before common enemies enter a family. |
| S51 | https://www.feralinteractive.com/en/manuals/xcom2/latest/steam/ | Tactical actions include movement, line of sight, cover, overwatch, hunker, hack, interact, carry, evac, and class-role actions. | Thoth maps enemy variety to board verbs: move, shoot, lob, push, pull, block, summon, repair, sabotage, watch, and break terrain. |
| S52 | https://www.gearsofwar.com/dev-blog-bosses/ | Boss fights work as combat puzzles with marked impact zones, armored weak windows, adds, cover pressure, mines, and phase escalation. | Thoth boss phases require tile patterns, rotating weak points, terrain conversion, objective pressure, visible clocks, counterplay, and preview text. |
| S53 | https://book.leveldesignbook.com/process/combat/cover | Cover objects block sightlines or shield units, and their implementation changes how players use combat spaces. | Thoth destructible location rules expose HP, LoS/cover state, break effects, repair counterplay, and previews for shelves, bridges, valves, kilns, doors, floors, and machinery. |
| S54 | https://www.w3.org/WAI/WCAG22/Techniques/css/C39 | Interaction-triggered motion should be suppressible when reduced motion is enabled. | Thoth reduced motion replaces tactical animation with static cues for rotation, destruction, knockback, and explosions. |
| S55 | https://developer.mozilla.org/en-US/docs/Web/CSS/Guides/Media_queries/Using_for_accessibility | Reduced motion should minimize non-essential movement while preserving essential information. | Thoth motion plans preserve tile coordinates, terrain state, final unit tile, and affected blast tiles through non-animated equivalents. |
| S56 | https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/107 | Games should provide alternate input mechanisms, analog and digital navigation, remappable actions, and avoid unnecessary input complexity. | Thoth controller flow uses single-press staged actions for selecting units, tiles, actions, targets, and previews. |
| S57 | https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/112 | UI navigation should be consistent, predictable, and fully operable with controller and digital input. | Thoth maps tactical controller prompts to consistent select, back, inspect, focus, rotate, and cursor controls. |

## Mechanic Handoffs

### H1 Exact Intent

source pattern: Into the Breach telegraphs attacks and objectives; Slay the Spire exposes next-action categories.

thoth transformation: Stack enemies post a notice with source tile, target tile, path, timing, effect, objective impact, and legal counter.

board verb: forecast, redirect, block, interrupt.

zone fit: all zones; Archive audit lines, Cistern flood lanes, Warrens heat lanes.

counterplay: move target, shove source, block path, raise cover, break LoS, stun, seal, sacrifice objective integrity.

preview/UI: arrow/path overlay, target tile outline, damage/effect chip, objective integrity delta, "posted notice" inspector line.

test/replay proof: fixed seed with one enemy declaring and resolving the same intent after identical command streams.

### H2 Category And Redacted Intent

source pattern: Slay the Spire uses attack/defend/buff/debuff/escape/stunned/unknown categories.

thoth transformation: Redaction hides footprint or magnitude until angle, light, witness tile, or class reveal exposes it.

board verb: hide, reveal, inspect, unseal.

zone fit: Archive back-face seals, Cistern submerged grates, Warrens smoke/ash screens.

counterplay: rotate, spend reveal AP, move to witness tile, use Lamplighter/Arcanist tool, clear mist/smoke.

preview/UI: category icon remains visible; missing footprint uses hatched tiles and "redacted by seal/light/angle" copy.

test/replay proof: fixture where reveal action changes UI data only, not already-authored logical intent.

### H3 Directional Cover And Flanking

source pattern: XCOM-style cover is directional and flanking invalidates cover benefits.

thoth transformation: Cover is a contested authority edge; flanking means the procedure recognizes the unit from an uncovered side.

board verb: cover, flank, invalidate, brace.

zone fit: Archive desks/shelves, Cistern valve blocks, Warrens kiln walls/glass screens.

counterplay: reposition, rotate preview, raise mobile cover, brace, smoke, destroy attacker LoS.

preview/UI: edge shields on tile sides, flanked edge turns warning pattern, attack preview states cover result before commit.

test/replay proof: unit attacked from protected and flanking vectors resolves different deterministic cover states.

### H4 Player-Authored Threat Zones

source pattern: Gears Tactics lets players spend actions into defined overwatch cones.

thoth transformation: Units lay witness lanes, lamp cones, shield-line holds, and writ arcs that fire only on declared triggers.

board verb: watch, deny, trigger, spend.

zone fit: Lamplighter routes, Warden shield lines, Merchant writ guards, Archive clerk lanes.

counterplay: path around cone, block LoS, bait trigger with object/enemy, smoke, seal watch source.

preview/UI: cone/line/arc overlay with AP count, trigger count, source unit, and ignored tile classes.

test/replay proof: fixture where enemy crossing watched tile triggers once per declared limit.

### H5 Information-Gathering Stealth And Exposure

source pattern: Invisible Inc spends resources to gather information in generated stealth spaces with readable guard intent.

thoth transformation: Exposure is a local board clock raised by noisy trespass, broken seals, visible theft, and ignored notices.

board verb: scout, peek, expose, quiet, escalate.

zone fit: all zones; strongest in Archive survey rooms and Cistern route bargains.

counterplay: spend AP to scout, take quiet route, repair seal, douse light, leave loot, use Thief/Lamplighter reveal.

preview/UI: exposure meter, next threshold modifier, visible causes, route node consequences.

test/replay proof: same command stream yields same exposure ticks and same next-board modifier.

### H6 Free Movement, Dash, And Assisted Movement

source pattern: Mario + Rabbids uses movement freedom, dash, team jump, cover, and turn sequencing.

thoth transformation: Movement preview composes route steps: walk, dash, brace-vault, drag, carry, shove, then locks final position before attack.

board verb: move, dash, vault, drag, carry.

zone fit: Cistern sluice walks, Warrens heat lanes, Archive shelf corridors.

counterplay: hostile cover, overwatch cones, hazard cost, carry integrity loss, blocked vault edge.

preview/UI: ghost path with AP segments, hazard ticks, cover gained/lost, carry integrity delta.

test/replay proof: fixture where path order determines deterministic dash/carry/hazard results.

### H7 Forced Movement And Collateral Defense

source pattern: Into the Breach turns enemy displacement and collateral objectives into the main puzzle.

thoth transformation: Shove/pull/swap misfiles bodies through claim lanes, into cover, across hazards, or away from route machinery.

board verb: shove, pull, swap, collide, misfile.

zone fit: Archive filing lanes, Cistern undertow, Warrens bellows cones.

counterplay: brace, anchor, edge blockers, objective buffers, LoS break, terrain destruction.

preview/UI: push path, collision tile, impact damage, objective integrity delta, friendly-fire marker.

test/replay proof: fixture where identical shove path produces identical collision and objective result.

### H8 Terrain Conversion And Objective Clocks

source pattern: Tactics bosses and compact board games use visible clocks, area denial, and risk/reward timing.

thoth transformation: Flood, drain, burn, ash, glass, collapse, seal, and open states advance on declared turns or interact AP.

board verb: convert, flood, drain, burn, douse, glassify, collapse.

zone fit: Cistern waterline clocks, Warrens douse chains, Archive falling shelves.

counterplay: interact valve/kiln/seal, move objective, spend repair AP, block lane, accept lower loot.

preview/UI: countdown badge on tile/object, next-state ghost, route/objective risk line.

test/replay proof: fixture advances turns and verifies same terrain sequence from same seed.

### H9 Boss Procedure Boards

source pattern: Gears Tactics bosses are phased combat puzzles with marked impact zones, adds, cover pressure, and exposed damage windows.

thoth transformation: Bosses are zone procedures with exact intent, partial intent, terrain mutation, objective threat, and rotation-exposed weak point.

board verb: phase, expose, mutate, threaten, counter.

zone fit: Codex Reeve, Vault Regent, Pearl Choir, Bell Diver, Kiln Vicar, Cinder Prioress.

counterplay: rotate for weak point, douse/drain/seal, break add support, move objective, force boss friendly fire.

preview/UI: phase card, current notice, next mutation, weak-point condition, objective integrity projection.

test/replay proof: boss phase fixture with deterministic phase thresholds and weak-point visibility state.

### H10 Procedural Board Validation

source pattern: Invisible Inc procedural stealth required heavy validation; tactics roguelikes show compact random spaces can still produce unfair spikes.

thoth transformation: Generators emit board seed, route type, objective anchors, validation report, and replay hash before play.

board verb: generate, validate, reject, export.

zone fit: all procedural boards.

counterplay: player sees route risk; invalid boards never enter player flow.

preview/UI: debug validator output for development; player route card shows risk/reward, not raw seed math.

test/replay proof: 25 fixed seeds per board type pass reachability, LoS, cover density, objective feasibility, enemy intent density, and exit access.

### H11 Tactical Overlay Accessibility

source pattern: Tactical clarity relies on visible overlays; accessible palettes must survive colorblind simulation.

thoth transformation: Intent, cover, LoS, hazard, objective, destructible HP, weak point, and extraction overlays use color plus icon, shape, hatch, outline, and inspector text.

board verb: inspect, filter, preview, verify.

zone fit: all zones and all four camera rotations.

counterplay: player can filter overlays and inspect tile facts before commit.

preview/UI: separate filters for movement, intent, LoS, cover, objectives, hazards, hidden/revealed info.

test/replay proof: screenshot-smoke captures every overlay in four rotations and checks non-empty render layers.

### H12 Compact Board Pressure

source pattern: 868-HACK and Hoplite create depth from small boards, limited verbs, positional pressure, and risk/reward pickups.

thoth transformation: Prototype boards stay compact and force objective tradeoffs: proof, route repair, survivor extraction, squad safety, or dread reduction.

board verb: compress, pressure, extract, repair, abandon.

zone fit: Prototype 0 and early Buried Archive.

counterplay: leave loot, repair route, block spawn, use movement tool, evacuate early.

preview/UI: objective stack shows which losses are acceptable and which end the board.

test/replay proof: one playable board fixture with deterministic win/loss outcomes for extract, repair, and abandon paths.

### H13 Board Grammar Components

source pattern: XCOM 2 procedural plot guidance names object spacing, cover density, and LoS as map-quality constraints; Invisible Inc-style generation arranges rooms, corridors, goals, exits, guards, and gated paths for playability; Into the Breach keeps deterministic boards compact and inspectable.

thoth transformation: Board grammar emits rooms, corridors, height bands, cover fields, sight breaks, objective anchors, hazard lanes, and spawn pockets as first-class metadata before validation or zone dressing.

board verb: carve, connect, elevate, cover, break sight, anchor, threaten, spawn.

zone fit: all zones; Archive uses shelves and audit lanes, Cistern uses valves and pressure lanes, Warrens uses kilns and heat lanes.

counterplay: route around hazards, use or destroy cover, break LoS, block spawns, protect/evacuate objective anchors.

preview/UI: debug overlays can toggle grammar components; player overlays expose objective, cover, LoS, hazard, and spawn-risk facts.

test/replay proof: fixed seed generation validates every grammar component and serializes identically from the same seed.

### H14 Zone Generators

source pattern: procedural dungeon generators can reuse connected room/corridor methods, preserve critical path pressure, and rely on controlled pieces where gameplay needs precision.

thoth transformation: Buried Archive, Salt Cistern, and Ember Warrens generators reuse the same board grammar while changing material, hazard kind, objective kind, and sight-break object.

board verb: localize, dress, threaten, validate.

zone fit: Archive audit-static shelves, Cistern floodgate/sluice pressure, Warrens kiln/burn pressure.

counterplay: same readable board skeleton, different hazard/objective answers per zone.

preview/UI: route preview can show generator id, zone, hazard, and objective kind before board load.

test/replay proof: each zone generator validates and serializes deterministically for a fixed seed.

### H15 Encounter Director

source pattern: encounter design needs pacing, readable cause/effect, objective pressure, and reinforcement timing that does not feel arbitrary.

thoth transformation: Encounter director writes enemy mix, intent density, objective pressure, reinforcement timing, and retreat routes before tactical play starts.

board verb: compose, pressure, reinforce, retreat, preview.

zone fit: Archive, Cistern, and Warrens use their own enemy families and shared director fields.

counterplay: inspect enemy mix, objective clock, visible reinforcement warning, and retreat route before commitment.

preview/UI: route/debug preview lists director id, enemy family, intent cap, objective pressure, reinforcement turn, and retreat path.

test/replay proof: directed zone boards serialize identically from a fixed seed and include all director fields.

### H16 Run Map Graph

source pattern: branching roguelite maps create agency by showing connected node choices, risk/reward tradeoffs, event/resource pressure, and boss endpoints.

thoth transformation: Run maps emit route choices, risk/reward previews, enclave requests, event nodes, repair/elite branches, and boss gates as inspectable graph data.

board verb: route, preview, request, gate, choose.

zone fit: all zones supply local enclave, hazard, and boss metadata.

counterplay: accept or avoid pressure based on visible risk/reward before the next tactical board is generated.

preview/UI: map node preview lists kind, risk, reward, detail, event id, enclave request, and boss gate requirement.

test/replay proof: fixed seed run map validates all required node kinds and serializes identically.

### H17 Event RNG Layer

source pattern: pre-action randomness creates varied conditions to assess; post-action randomness inside committed resolution reduces agency.

thoth transformation: Event layer rolls pre-board and post-board complications, records prompts and altered systems, and disables tactical resolution RNG after board start.

board verb: roll, preview, lock, resolve, record.

zone fit: all zones can apply route, board, squad, reward, and faction events outside tactical resolution.

counterplay: read event timing and prompt before deployment or after extraction; no random event changes declared tactical hit/damage/cover outcomes.

preview/UI: event card lists timing, event id, altered system, prompt, rule id, and RNG-lock state.

test/replay proof: fixed seed event layer validates pre/post timings and serializes identically.

### H18 Difficulty Budget

source pattern: procedural tactical/puzzle content needs completability checks, explicit difficulty estimation, and readable cover/LoS anchors before acceptance.

thoth transformation: Board budget scores enemies, objectives, hazards, cover, reinforcements, redacted intent, and boss modifiers, then rejects over-budget, unsolvable, or unreadable boards.

board verb: score, reject, regenerate, report.

zone fit: all zone generators feed the same budget axes with local hazards/objectives/enemies.

counterplay: invalid boards never enter player flow; accepted boards keep objective, cover, retreat, and intent-density data inspectable.

preview/UI: debug report shows total, max, contributors, grammar report, and reject reasons.

test/replay proof: fixed directed board accepts by default, rejects under low max, and rejects intent density overflow.

### H19 Seeded Run Replay Export

source pattern: deterministic replay records seeds, player choices/inputs, and checksums so a run can be reproduced and divergence can be detected.

thoth transformation: Seeded run export records run seed, board seeds, route choices, squad loadout, event rolls, replay hashes, and export hash.

board verb: seed, choose, roll, hash, export.

zone fit: all route maps and generated boards use the same export schema.

counterplay: QA can replay exact route/board/event sequence and compare hashes.

preview/UI: debug export view lists schema version, route choices, board seeds, event ids, and hashes.

test/replay proof: fixed seed export validates required fields, serializes identically, and changes hash when route choices change.

### H20 Board-Verb Classes

source pattern: XCOM and Gears Tactics classes expose battlefield specialties through class abilities, subclasses, and skill branches; Mario + Rabbids emphasizes movement verbs such as dash, team jump, and cover use.

thoth transformation: Class identity is stored as verbs that change the board: brace, dash, reveal, smoke, disarm, douse, break terrain, project overwatch, convert debt, and insure objectives.

board verb: brace, dash, reveal, cleanse, disarm, repair, throw, project, insure.

zone fit: Archive rewards reveal, brace, shove, and seal-pass verbs; Cistern rewards douse, rescue, route, and hazard verbs; Warrens rewards break terrain, smoke, heat control, and objective insurance.

counterplay: every loadout verb has a cost, tile condition, LoS condition, cooldown, debt, exposure, or positioning weakness.

preview/UI: class sheet lists board verbs, loadouts list one `boardVerb`, and inspector text states the tile/objective/intent state changed before commit.

test/replay proof: `ClassCatalog.auditBoardVerbs()` rejects missing verbs or legacy loadout `role`; `tests/run.lua` verifies every class and loadout uses board verbs.

### H21 Loadout Slot Budget

source pattern: XCOM and Gears Tactics keep class identity readable through bounded abilities and class branches; Mario + Rabbids combines each hero's weapon, technique, movement verbs, and Spark choices into a readable pre-battle kit.

thoth transformation: Every class declares 2 loadout slots, 3-5 catalog tools, and at least one terrain interaction; loadouts must spend exactly those 2 slots using tools from the class catalog.

board verb: choose, equip, share, constrain, preview.

zone fit: all zones; Archive stresses reveal/cover slots, Cistern stresses rescue/douse slots, Warrens stresses heat/terrain/objective slots.

counterplay: slot caps force tradeoffs; enemies and objectives can punish missing reveal, missing hazard control, missing cover break, or missing extraction support.

preview/UI: class loadout screen shows `loadoutSlots`, available tools, chosen two-slot loadout, terrain interaction, and missing counter category.

test/replay proof: `ClassCatalog.auditLoadoutShape()` rejects non-2-slot loadouts, tool catalogs outside 3-5, missing terrain interactions, and loadout tools absent from the class catalog.

### H22 Trait Domain Contract

source pattern: XCOM and Gears Tactics advancement branches change battlefield actions and support options; Mario + Rabbids skill builds alter movement, cooldowns, weapon/technique use, healing, barriers, and positioning.

thoth transformation: Character traits are deterministic modifiers in required tactical domains: AP, movement, LoS, cooldown, cover, and objective repair.

board verb: modify, preview, constrain, refund, tax.

zone fit: Archive stresses LoS/reveal/cover traits, Cistern stresses movement/carry/objective traits, Warrens stresses cooldown/cover/objective-repair traits.

counterplay: traits carry paired upsides and downsides, so a squad can be strong in one domain and exposed in another.

preview/UI: recruit sheet groups traits by domain and shows AP/movement/LoS/cooldown/cover/objective deltas before squad lock.

test/replay proof: `ClassCatalog.auditTraitDomains()` rejects missing required domains, duplicate trait ids, and missing trait metadata.

### H23 Run Loadout Unlocks

source pattern: Into the Breach Advanced Edition expands replay variety with new squads, weapons, missions, enemies, bosses, and pilot abilities; roguelite horizontal progression works best when it changes choices rather than only increasing stats.

thoth transformation: Loadouts unlock as `class_option` rewards from run milestones such as objective protection, clean extraction, hazard cleansing, elite kills, boss notices, and ledger events.

board verb: unlock, choose, branch, preview, specialize.

zone fit: Archive unlocks reveal, brace, and recovery loadouts; Cistern unlocks hazard, extraction, and route loadouts; Warrens unlocks heat, smoke, and objective-insurance loadouts.

counterplay: each unlock adds a new answer and an opportunity cost, not unconditional damage, HP, or aim growth.

preview/UI: route reward preview shows class, loadout id, board verb, source milestone, and what counter category it covers.

test/replay proof: `ClassCatalog.auditLoadoutUnlocks()` rejects missing unlock metadata, non-`class_option` rewards, stat payloads, and classes with no run-sourced loadout unlock.

### H24 Injury And Debt Consequences

source pattern: Darkest Dungeon uses stress afflictions for roster pressure; XCOM exposes wounds, AP, movement, hazards, cover, LoS, carry, evac, and status effects as tactical state.

thoth transformation: Injuries and debts become deterministic domain constraints on AP, movement, LoS, cooldown, cover, objective repair, carry, reveal, event pressure, or stress.

board verb: constrain, tax, cap, delay, expose.

zone fit: Archive stresses LoS/reveal/debt paperwork, Cistern stresses carry/movement/objective repair, Warrens stresses cover/cooldown/hazard pressure.

counterplay: choose recovery, loadout tools, route risk, or squad composition around known constraints; never lose a turn to a hidden roll.

preview/UI: roster and board inspector show consequence id, type, domain, exact constraint, and `noRandomActionLoss`.

test/replay proof: `ClassCatalog.auditInjuryDebtConstraints()` rejects missing domains, duplicate ids, missing injury/debt types, and any random action/turn-loss field.

### H25 Squad Size Scaling

source pattern: Gears Tactics emphasizes squad outfitting, fast turn-based battles, and bosses that change scale; Mario + Rabbids keeps battle teams small and synergy-heavy.

thoth transformation: Squad sizes 2-6 receive deterministic AP, deployment slots, enemy budget multipliers, reinforcement caps, board dimensions, objective anchors, spawn pockets, retreat routes, and variance budgets.

board verb: deploy, scale, split, reinforce, retreat.

zone fit: all zones use the same scaling shell; Archive adds claim lanes, Cistern adds water pressure lanes, Warrens adds heat and ash lanes.

counterplay: smaller squads get compact boards and lower enemy budget; larger squads get more space but more fronts, anchors, hazards, and reinforcements.

preview/UI: route preview shows squad size, AP budget, board scale, objective pressure, enemy multiplier, deployment pattern, and variance rules.

test/replay proof: `ClassCatalog.auditSquadScaling()` rejects missing 2-6 sizes, non-monotonic board/enemy/reinforcement scaling, missing board variance rules, and out-of-bounds squad sizes.

### H26 Common Enemy Archetypes

source pattern: Into the Breach makes enemy actions telegraphed and counterable; XCOM 2 exposes tactical action roles such as movement, LoS, cover, overwatch, hack/interact, carry, and class-role actions.

thoth transformation: Common enemies are tagged with 11 required archetypes: mover, shooter, artillery, pusher, puller, blocker, summoner, repairer, saboteur, overwatch, and terrain-breaker.

board verb: move, shoot, lob, push, pull, block, summon, repair, sabotage, watch, break.

zone fit: Archive expresses paperwork/claim versions; Cistern expresses flood/pressure versions; Warrens expresses heat/ash/glass versions.

counterplay: every archetype declares counterplay such as body block, LoS break, footprint escape, brace, spawn blocking, source isolation, repair, smoke, or terrain stabilization.

preview/UI: enemy inspector shows archetype, exact intent, zone verb, preview footprint/path, and counterplay line.

test/replay proof: `EnemyCatalog.auditArchetypes()` rejects missing archetypes, missing archetype metadata, invalid common enemy references, missing exact intent, missing zone verbs, out-of-range family counts, and uncovered required archetypes.

### H27 Basic Enemy Exact Intents

source pattern: Into the Breach telegraphs enemy attacks before resolution; Thoth's own exact-intent rules require source, target footprint, trace, damage/effect, collision, objective impact, and counterplay.

thoth transformation: Common enemy catalog entries hydrate exact intent blueprints with source, category, target rule, target pattern, path pattern, deterministic damage/effect, objective impact, counterplay, preview, and forced-movement collision where needed; runtime enemies now choose between visible target replan, critical-objective finisher, wounded guard, and baseline attack intent without RNG.

board verb: declare, preview, trace, counter, resolve.

zone fit: Archive exact intents target claim lines and records; Cistern exact intents target water pressure, valves, pools, and exits; Warrens exact intents target heat lanes, glass lines, fuel, and objectives.

counterplay: LoS break, cover raise, footprint escape, brace, block landing, spawn block, interrupt source, isolate repair target, repair objective, smoke lane, stabilize terrain, press a wounded enemy, or block a critical objective.

preview/UI: common enemy inspector shows exact category, target pattern, path pattern, damage, effect, objective impact, collision if any, and counterplay list before deployment.

test/replay proof: `EnemyCatalog.auditExactBasicIntents()` rejects missing exact intent mode, missing exact preview fields, missing objective impact, missing counterplay, nondeterministic flags, forced movement without collision, and incomplete common-family coverage; runtime tests verify visible-move replan, smoke-held target memory, critical-objective finisher, and wounded guard intent.

### H28 Elite Partial And Masked Intents

source pattern: Slay the Spire-style intent symbols expose action categories while Into the Breach-style tactics require counterplay before resolution.

thoth transformation: Elites keep category-visible partial intents for encounter generation and add hidden-footprint masked intent blueprints gated by weak points, reveal classes, reveal actions, and zone counterplay.

board verb: mask, reveal, expose, counter, resolve.

zone fit: Archive masks footprints behind seals; Cistern masks footprints below waterlines; Warrens masks footprints through ash/glass reflection.

counterplay: expose weak point, unseal intent, sound depth, clear ash/glass, break seal line, drain pressure source, douse, or shatter reflector.

preview/UI: elite inspector shows category icon, mask kind, hidden-footprint cue, weak point gate, reveal action, and counterplay line without exposing private tiles until reveal.

test/replay proof: `EnemyCatalog.auditEliteMaskedIntents()` rejects missing category partials, missing hidden-footprint masks, category mismatch, missing reveal gates, weak-point mismatch, missing zone counterplay, and incomplete elite-family coverage.

### H29 Boss Phase Procedures

source pattern: Gears Tactics boss fights use marked impact zones, weak windows, adds, cover pressure, mines, and escalating phases; Into the Breach keeps dangerous enemy actions telegraphed.

thoth transformation: Every boss receives a three-step phase procedure with tile pattern, rotating weak point, terrain conversion, objective pressure, visible clock, counterplay, and phase preview text.

board verb: pattern, rotate, expose, convert, pressure, counter.

zone fit: Archive phases use audit and claim lanes; Cistern phases use reflood and hook lanes; Warrens phases use vitrify, halo, ash, furnace, glass, and fuel lanes.

counterplay: break weak point, rotate camera, block lanes, douse vents, drain water, brace collateral, contest claims, protect or sacrifice fuel, or trigger the listed non-damage counter.

preview/UI: boss phase card shows phase id, tile pattern, weak-point rotation, terrain conversion, objective pressure, visible turn clock, counterplay, and preview text.

test/replay proof: `BossCatalog.auditPhaseProcedures()` rejects missing phase charts, missing tile patterns, missing rotating weak points, missing terrain conversion, missing objective pressure, missing visible clocks, missing counterplay/preview, and weak-point rotation coverage below two rotations.

### H30 Friendly Fire And Objective Collision

source pattern: Into the Breach makes friendly fire and collateral objective defense central by telegraphing displacement and attacks before resolution.

thoth transformation: Forced movement has explicit collision rules for blocked tiles, occupied tiles, objective tiles, and threat zones after a successful displacement step.

board verb: shove, pull, collide, damage, trigger.

zone fit: Archive misfile lanes push bodies into machinery; Cistern undertow pulls carriers across pumps; Warrens heat and ash lanes shove units into fuel or glass pressure.

counterplay: brace, block landing, anchor target, move objective carrier, repair objective, break LoS, or redirect forced movement into enemies.

preview/UI: push/pull preview shows destination, blocked or occupied collision, friendly-fire marker, objective integrity delta, and threat-zone trigger.

test/replay proof: `State.collisionRules()` exposes deterministic policy metadata, and `tests/run.lua` verifies objective collision, enemy friendly fire, blocked-tile collision, and threat-zone-after-step policy.

### H31 Destructible Location Rules

source pattern: Cover and environmental objects shape combat routes by blocking sightlines, shielding units, and changing how players use space.

thoth transformation: Shelves, bridges, valves, kilns, doors, floors, and machinery each get deterministic HP/integrity, AP cost, source object or mechanic, break effect, repair counterplay, and preview text.

board verb: break, open, drain, douse, lower, repair, route.

zone fit: Archive owns shelves, sealed doors, and ledger bridges; Cistern owns valves and machinery cores; Warrens owns kilns and fragile/glass floors.

counterplay: shove shelf, use hinge, lower bridge, turn valve, repair floodgate, douse kiln, route around glass, repair machinery, or shield objective with cover.

preview/UI: tile inspector shows kind, HP/integrity, AP cost, source object, LoS/cover state, break effect, repair counterplay, and deterministic outcome.

test/replay proof: `ZoneCatalog.auditDestructibleLocations()` rejects missing shelf/bridge/valve/kiln/door/floor/machinery rules, missing source metadata, nondeterministic rules, and missing source object/mechanic links.

### H32 Visible Reinforcement And Spawn Blocking

source pattern: Reinforcements can create time pressure when their timing and relationship to objectives are readable; director systems should author consistent spawn pressure instead of surprise runtime spawns.

thoth transformation: Encounter directors emit visible reinforcement timing, warning turn, spawn pocket, blockable flag, spawn block rule, cap, and blocked outcome before board start.

board verb: warn, spawn, block, delay, cap.

zone fit: Archive uses audited entry pockets, Cistern uses pressure bell pockets, Warrens uses heat/fuel edge pockets.

counterplay: occupy or block all spawn tiles, break the summoner/source, retreat before turn, spend AP to seal pocket, or accept delayed pressure.

preview/UI: route/debug preview shows reinforcement turn, warning turn, spawn pocket, enemy id, blockable state, block condition, on-blocked result, and cap.

test/replay proof: `Procgen.auditReinforcementRules()` rejects missing visible warning timing, invalid spawn pocket links, missing blockable metadata, missing spawn block rules, hidden block rules, and missing reinforcement schedules.

### H33 Tactical HUD Contract

source pattern: Into the Breach interface references show combat, in-game, overlay, mission, stats, and tutorial screens as separate readable tactical surfaces.

thoth transformation: The tactical HUD exposes selected unit AP, move preview, action preview, enemy intents, objective risk, and turn order from one deterministic summary.

board verb: select, preview, inspect, order, commit.

zone fit: All zones use the same HUD fields; Archive claim pressure, Cistern water pressure, and Warrens heat pressure feed objective risk and intent copy.

counterplay: compare AP, route, action result, enemy notice, objective integrity, and upcoming turns before spending AP.

preview/UI: HUD contract requires `selectedUnitAp`, `movePreview`, `actionPreview`, `enemyIntents`, `objectiveRisk`, and `turnOrder`.

test/replay proof: `UICatalog.tacticalHudSummary()` is tested with a selected unit, move/action previews, enemy exact intent, objective integrity, and deterministic unit order.

### H34 Tile Inspector Facts

source pattern: XCOM 2 exposes selected-unit AP, cover, effects, LoS, hazard warnings, waypoint paths, cover icons, and action outcomes in tactical UI; Into the Breach UI analysis emphasizes animated tooltips and clarity over long explanation.

thoth transformation: Tile inspector turns each inspected coordinate into deterministic fields for terrain, cover, LoS, hazards, destructible HP, hidden/revealed state, and current intent traces.

board verb: inspect, reveal, compare, counter.

zone fit: Archive claim marks, Cistern brine/mist, and Warrens burn/glass all feed the same inspector contract without custom UI schemas.

counterplay: inspect blockers, cover edge, LoS status, hazard tick, breakable HP, reveal requirement, and enemy source/target/path trace before spending AP.

preview/UI: inspector contract requires `terrain`, `cover`, `los`, `hazards`, `destructibleHp`, `hiddenInfo`, and `intentTraces`.

test/replay proof: `UICatalog.tileInspectorSummary()` is tested against a tile with normalized terrain, cover edge, selected-unit LoS, active hazard, destructible blocker HP, hidden rotation mark, reveal metadata, and exact enemy target trace.

### H35 Rotation-Aware Overlay Projection

source pattern: XCOM 2 exposes tactical camera rotation as a core control and uses map icons for AP range, LoS, hazards, and cover; Into the Breach interface references separate combat overlays and tutorial surfaces for readable tactical state.

thoth transformation: Overlay entries keep stable logical coordinates while each camera snap gets projected screen coordinates, upright labels, icon/pattern readability, and occlusion-offset metadata.

board verb: rotate, preserve, inspect, compare.

zone fit: Archive back-face seals, Cistern mist lines, and Warrens glass/burn facts can rotate into view without changing underlying board coordinates.

counterplay: rotate to inspect occluded cover, LoS, hazards, intent traces, hidden marks, and objective risk without losing tile identity.

preview/UI: rotation audit requires four snap buckets, stable `x/y`, `screenX/screenY`, upright label orientation, icon, pattern, readability flag, and occlusion offsets.

test/replay proof: `Render.tacticalOverlayRotationAudit()` is tested for four rotations, stable entry count, stable logical tile roundtrip, upright labels, readable icon/pattern metadata, occlusion offsets, and distinct screen projections.

### H36 Colorblind-Safe Tactical Palette

source pattern: Accessible color guidance warns against red/green reliance, recommends varying lightness, using tested palettes, checking simulations, and not conveying information by color alone.

thoth transformation: Intent, cover, and hazard overlays use a shared colorblind-safe role palette plus icon, pattern, and shape redundancy consumed by render defaults. Tactical accessibility settings add high-contrast tile mode, intent icon scale, cover edge palette selection, and optional intent text duplication.

board verb: mark, distinguish, inspect, verify.

zone fit: Archive notices, Cistern hazard lanes, and Warrens burn/glass pressure use the same role palette while retaining local labels.

counterplay: players can separate enemy intent, cover, and hazard cues under default, deuteranopia, protanopia, and tritanopia modes before committing AP.

preview/UI: palette contract defines `intent`, `cover`, and `hazard` roles with RGBA, hex, icon, pattern, shape, visibility, simulation modes, and review checks. `Settings.accessibilityControls()` exposes the tactical panel controls, while `Render.tacticalAccessibility()` feeds overlay metadata and tile color transforms.

test/replay proof: `UICatalog.accessiblePalette()`, `Render.tacticalOverlayEntries()`, `Render.tileAccessibleColor()`, and settings persistence are tested for role metadata, simulation separation, render color/icon/pattern alignment, high-contrast tile changes, intent scale/text metadata, and settings-panel hitboxes.

### H37 Reduced-Motion Tactical Equivalents

source pattern: W3C guidance for interaction-triggered motion allows users to suppress motion animations; MDN guidance frames reduced motion as minimizing non-essential movement while preserving needed information.

thoth transformation: Rotation, destruction, knockback, and explosion effects each define an animated plan and a reduced static equivalent that preserves the gameplay fact conveyed by motion.

board verb: snap, mark, indicate, preserve.

zone fit: Archive shelf breaks, Cistern hook pulls, Warrens blasts, and camera-rotation reveals use the same reduced-motion plan surface.

counterplay: players can inspect view angle, destroyed tile state, forced-movement path, collision text, blast footprint, affected tiles, and damage deltas without tween, slide, shake, or expanding burst.

preview/UI: `Render.motionPlan()` emits reduced plans with `animation = "none"`, static equivalent text, cue id, preserved state domain, source/target, and affected tiles.

test/replay proof: `Render.reducedMotionEquivalents()`, `Render.motionPlan()`, UI pulse suppression, and reduced-motion rotation snap are tested for all four required effect families.

### H38 Tactical Controller Path

source pattern: Xbox accessibility guidance recommends alternate input mechanisms, analog and digital UI navigation, single-press operation, remappable actions, consistent focus order, and predictable controller prompts.

thoth transformation: Tactical controller flow is staged as select unit, select tile, select action, select target, and confirm preview, with D-pad/left-stick cursor movement, A contextual activation, X inspect, back/cancel, and shoulder rotation available before commit.

board verb: focus, select, inspect, target, confirm, cancel.

zone fit: Archive, Cistern, and Warrens boards use the same controller path while local tile facts and intent traces populate previews.

counterplay: controller-only players can reach the same selected AP, tile inspector, move preview, action preview, target preview, and before-commit preview as mouse/keyboard players; axis debounce prevents runaway cursor commits.

preview/UI: `UICatalog.controllerPath()` defines principles, bindings, and five stages; `Input.tacticalGamepadMap()` exposes select, back, inspect, focus, shoulder rotation, and analog/digital cursor inputs; the runtime cursor can inspect without moving or activate the tile context.

test/replay proof: Tests verify joystick module enablement, gamepad button/axis mapping, tactical map bindings, controller path stages, stage input/output/preview metadata, cancel-before-commit support, runtime D-pad/axis cursor movement, X inspect, A contextual activation, and controller smoke replay.

### H39 Tutorial Board Fixtures

source pattern: Into the Breach interface references include combat, tutorial, mission, environment, and objective surfaces; XCOM 2 onboarding points new players toward tutorialized tactical play.

thoth transformation: Tutorial boards and the live tutorial smoke now start with a single-screen 6x6 onboarding board that combines select, move, rotate, overwatch, end turn, and revealed-intent reaction before the isolated AP/cursor movement, posted intent, cover/flanking, push/pull, objective pressure, and rotation pages.

board verb: select, move, rotate, overwatch, end turn, react, flank, inspect, push, pull, break, protect.

zone fit: Generic tutorial fixtures map to Archive paperwork cover, Cistern hazards, and Warrens destruction/objective pressure without requiring zone-specific UI schemas.

counterplay: each board teaches deterministic answers: inspect before commit, safe AP route, protected edge versus flank, leave exact footprint, preview push/pull collision, block objective damage, declare overwatch before ending turn, react to a revealed hidden footprint, or rotate to read tile truth.

preview/UI: `Render.tutorialSteps()` exposes tactical onboarding pages backed by `UICatalog.tutorialBoards()` fixtures and rotation readability checks; `--tutorial-smoke` boots tactical mode before drawing tutorial controls and reports the 6x6 onboarding script.

test/replay proof: Tests instantiate every tutorial board as `TacticsState` and verify fixture metadata plus the 6x6 cue-driven onboarding script, hidden intent reveal, movement, cover, exact intent, push/pull, destructible cover, objective pressure, live tactical tutorial steps, and tactical-mode tutorial smoke.

### H40 Buried Archive Vertical Slice Route

source pattern: Into the Breach keeps compact deterministic boards readable; XCOM 2 procedural plot guidance stresses cover density, object spacing, and LoS constraints; Invisible Inc-style generation prioritizes goals, exits, patrol pressure, and fixed validation over realism.

thoth transformation: The Buried Archive vertical-slice route ships as six ordered procedural variants with visible route metadata, deterministic seeds, archive dressing, encounter director pressure, validator evidence, and replay-stable serialization.

board verb: route, generate, pressure, validate, replay.

zone fit: Archive entry audit, shelf protection, proof extraction, ledger repair, sealed shortcut, and elite claim boards all use archive material, audit-static lanes, rolling shelves, and Archive enemy families.

counterplay: read template, node kind, reward, complication, objective anchor, reinforcement warning, spawn block rule, and retreat path before deployment.

preview/UI: `Procgen.archiveRoute()` gives ordered route metadata; `Procgen.archiveRouteVariants()` gives card fields; generated boards carry `archiveRoute` metadata for tactical preview and QA export; `TacticalRuntime.new()` now defaults to the route start variant instead of the fixed prototype board.

test/replay proof: tests verify 5-7 variants, template/node pressure coverage, grammar validation, reinforcement audit, accepted budget, `TacticsState` instantiation, deterministic fixed-seed serialization, runtime route metadata, and tactical smoke route/variant output.

### H41 Starter Classes And Loadouts

source pattern: XCOM, Gears Tactics, and Mario + Rabbids keep class identity readable through bounded ability branches, movement verbs, equipment choices, and pre-battle role clarity.

thoth transformation: The vertical slice exposes Warden, Duelist, Apothecary, and Thief as starter classes, each with two slice loadouts drawn from the full class catalog and backed by board verbs, two-slot tools, preview copy, and strong/awkward board fixtures.

board verb: equip, preview, counter, specialize.

zone fit: Archive route boards test cover/objective guard, dash/flank, repair/smoke support, and route/extraction utility against shelf, audit, proof, repair, shortcut, and elite claim pressure.

counterplay: choose between two visible loadouts per starter class based on route pressure; missing cover, mobility, repair, smoke, or extraction support remains a known risk.

preview/UI: `ClassCatalog.starterClassIds()` gives the four starter ids; `ClassCatalog.starterLoadouts(classId)` gives two loadout cards with board verb, tools, preview, availability, and fixture metadata.

test/replay proof: tests verify exactly four starter classes, exact starter order, exactly two starter loadouts per class, valid catalog references, tool counts, previews, strong/awkward fixtures, and advanced-class exclusion.

### H42 Vertical Slice Objective Types

source pattern: XCOM objective timers, Into the Breach protected-grid pressure, and compact deterministic tactics all benefit when the objective family and failure state are visible before action.

thoth transformation: The slice reduces objective breadth to protect, extract, and disable, each mapped to one Archive kind, one command, one route fixture, preview text, counterplay, success state, and failure state.

board verb: protect, carry, extract, disable.

zone fit: Archive shelves test protect pressure, proof caches test extraction pressure, and audit lenses test disable pressure inside sealed shortcuts.

counterplay: brace or repair integrity, clear and carry cargo to an exit, or reach and disable a target before its pressure clock resolves.

preview/UI: `State.objectiveTypes()` returns the three slice cards; generated Archive route fixtures expose matching objective families for protect, extract, and disable.

test/replay proof: tests audit the three objective types, verify command metadata, instantiate matching Archive route boards, and apply protect/extract/disable commands to deterministic result states.

### H43 Slice Elite And Boss

source pattern: Elite enemies can withhold exact footprints while preserving counterplay through intent category, weak points, and reveal gates; boss fights need visible phase clocks, terrain pressure, objective stakes, and non-damage counters.

thoth transformation: The slice selects Shelf Knight as the single Archive elite and Vault Regent as the single Archive boss, then binds the elite to the Archive elite route and the boss to the boss-gate route.

board verb: mask, reveal, claim, brace, break.

zone fit: Shelf Knight uses shelf-wall and rear-binding pressure; Vault Regent uses claim beams, named collateral, legal cover, and writ pillars.

counterplay: expose the elite weak point to reveal masked footprint, brace collateral, destroy writ pillars, and contest claim phases before visible clocks resolve.

preview/UI: `EnemyCatalog.sliceEliteSpec()` and `BossCatalog.sliceBossSpec()` expose selected ids, route fixtures, roles, and previews for route cards.

test/replay proof: tests audit the selected elite and boss, verify elite masked intent and weak point metadata, assert the elite appears in the generated Archive elite board, and verify the boss tactical contract and visible three-phase procedure.

### H44 Archive Slice Run Map

source pattern: Slay the Spire-style and roguelite maps create agency through visible branches, rewards, elite detours, events, and boss gates; pre-action randomness should produce assessable conditions before commitment.

thoth transformation: The Archive slice map is one deterministic branch graph with reward and complication payloads on route nodes, fixed board variant ids, fixed board seeds, one event node, one elite node, and one boss gate.

board verb: branch, preview, reward, complicate, gate.

zone fit: Archive route nodes use proof caches, custodian annex pressure, ledger repair, sealed shortcuts, Shelf Knight elite pressure, and Vault Regent boss gate.

counterplay: compare reward value against visible route costs before choosing a node; no tactical result is randomized after board start.

preview/UI: `RunCatalog.generateArchiveSliceMap(seed)` exposes choices, rewards, complications, board variants, board seeds, elite pressure, event modifier, and boss gate data; `TacticalRuntime.advanceRoute()` loads the next ordered Archive board after a cleared tactical node.

test/replay proof: tests validate the map, require reward/complication payloads, require all six Archive board variants, cover combat/enclave/event/repair/elite/boss/shortcut/extraction nodes, bind the selected boss, verify deterministic serialization, and assert runtime board-clear advancement plus final route completion.

### H45 Phase 6 Public Alpha Package

source pattern: Public alpha releases need a reproducible build artifact, page copy, feedback intake, and verification steps so players and triage see the same slice.

thoth transformation: The Phase 6 package binds `dist/thoth.love`, itch alpha page copy, a `phase6-alpha` upload channel, and the GitHub `Alpha feedback` issue form to the Buried Archive tactical slice.

board verb: package, publish, report, triage.

zone fit: The public package frames route-map pressure, six Archive board variants, starter loadouts, protect/extract/disable objectives, Shelf Knight elite pressure, and Vault Regent boss pressure as the feedback surface.

counterplay: Players can report route node, board variant, objective type, loadout, enemy intent, complication, and whether visible counterplay was clear.

preview/UI: `docs/itch-alpha-page.md` carries public page copy; `.github/ISSUE_TEMPLATE/alpha_feedback.yml` carries the tactical feedback form; `docs/phase6-alpha-package.md` carries packaging commands and status; Makefile release smoke and benchmark paths now point at tactical route runtime, with rank combat kept behind `legacy-combat-smoke`.

test/replay proof: tests verify package manifest/page/form contents; package verification uses `make package-build` and `luajit tests/package.lua dist/thoth.love`; `make smoke`, `make benchmark-smoke`, `make tactical-smoke`, and `make legacy-combat-smoke` prove tactical release paths and explicit legacy quarantine.

### H46 Full Scope Zone Terrain And Enemy Families

source pattern: Into the Breach constrains tactics around shown attacks, low UI load, and enemy manipulation; Gears Tactics uses cover, flanking, and player-authored overwatch cones; Invisible Inc warns that procedural stealth/tactics needs validation discipline; Mario + Rabbids shows readable small-squad movement and cover synergies.

thoth transformation: The full scope keeps three zones with shared validation but distinct terrain grammars and enemy families: Buried Archive claim/shelf/audit procedures, Salt Cistern flood/valve/pressure procedures, and Ember Warrens heat/ash/glass procedures.

board verb: localize, threaten, validate, counter.

zone fit: Archive enemies file, seal, summon, and audit; Cistern enemies flood, drain, pull, and pressure; Warrens enemies burn, douse, reflect, and vitrify.

counterplay: use zone-local terrain answers before killing: rotate for Archive back seals, turn Cistern valves or drain grates, and douse or shatter Warrens heat/glass sources.

preview/UI: `ZoneCatalog` exposes tile mechanics, objects, and rotation facts per zone; `EnemyCatalog` exposes common, elite, alpha, exact-intent, and masked-intent data per family.

test/replay proof: tests verify each full-scope zone has 12 mechanics, 8 objects, 4 rotation facts, distinct prefixes, zone-local enemy verb fields, and 3 elites with local counterplay metadata.

### H47 Full Scope Classes And Run Loadout Choices

source pattern: Gears Tactics uses class/subclass skills to tailor soldiers for battle; XCOM classes unlock unique abilities and specializations; Mario + Rabbids combines hero kits with selectable tactical powers; Into the Breach Advanced Edition expands run variety through squads, weapons, pilots, and mission/enemy content.

thoth transformation: The full class roster is nine board-verb classes, each with three two-tool loadouts, no stat-only unlocks, and at least two run-sourced class-option choices.

board verb: choose, unlock, specialize, counter.

zone fit: Warden, Duelist, Apothecary, Arcanist, Thief, Chirurgeon, Exile, Lamplighter, and Merchant cover Archive claim/reveal, Cistern movement/repair, and Warrens heat/terrain/objective pressure.

counterplay: run rewards widen tactical answers instead of raising raw power; missing loadout categories leave visible gaps against hazards, LoS, objective pressure, extraction, or redacted intent.

preview/UI: `ClassCatalog` exposes class ids through table keys, loadouts, two-slot tool refs, terrain interactions, unlock scopes, reward ids, and preview copy.

test/replay proof: tests verify exactly nine planned classes, three loadouts each, two tool slots, unique loadout ids, non-stat class-option unlocks, and at least two run-sourced unlock choices per class.

## Rejection Rules

- Reject hidden hit/miss RNG after board load.
- Reject mechanics that cannot show source, target, timing, and counterplay before commitment.
- Reject color-only tactical information.
- Reject copied names, factions, bosses, plot beats, layouts, prose, art direction, or exact ability loops.
- Reject mechanics that only tune damage/HP without changing movement, position, cover, LoS, terrain, objective state, or future intent.
- Reject fake intent unless there is a previewed reveal/counterplay rule.
- Reject any mechanic unreadable in all four rotations.
