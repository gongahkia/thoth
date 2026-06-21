# Tactical Research Index

Checked: 2026-06-21

Purpose: source-backed design constraints for Thoth's tactical pivot. These notes are pattern references only. They are not permission to copy names, factions, layouts, UI art, prose, or ability kits.

Use this file before any mechanic/content batch enters implementation. A borrowed pattern is acceptable only if the Thoth version changes fiction, rules, costs, UI language, and counterplay.

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

## Rejection Rules

- Reject hidden hit/miss RNG after board load.
- Reject mechanics that cannot show source, target, timing, and counterplay before commitment.
- Reject color-only tactical information.
- Reject copied names, factions, bosses, plot beats, layouts, prose, art direction, or exact ability loops.
- Reject mechanics that only tune damage/HP without changing movement, position, cover, LoS, terrain, objective state, or future intent.
- Reject fake intent unless there is a previewed reveal/counterplay rule.
- Reject any mechanic unreadable in all four rotations.
