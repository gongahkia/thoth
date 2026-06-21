# Tactical UI Catalog

## U.1 Icon Language

source pattern:
Readable tactics UI pairs color with shape, pattern, outline, and short inspector text.

thoth transformation:
Thoth defines icon language for AP, move, cover, flanked, LoS, exact intent, partial intent, hazard, objective, destructible HP, weak point, and extraction.

board verb:
Mark, label, outline, distinguish.

zone fit:
All zones use the same icon ids while local overlays provide terrain-specific copy.

counterplay:
Icons must stay readable without color alone, so every entry has shape and pattern redundancy.

preview/UI:
Each icon entry defines icon text, shape, color role, pattern, and label.

test/replay proof:
`tests/run.lua` verifies all 12 icon ids exist and each defines redundant non-color UI language.

## U.2 Overlay Filters

source pattern:
Dense tactical UI stays readable when players can isolate movement, intent, LoS, cover, objectives, hazards, and revealed information.

thoth transformation:
Thoth defines overlay filters for movement, enemy intent, LoS, cover, objectives, hazards, and hidden/revealed info.

board verb:
Filter, show, hide, inspect.

zone fit:
All zones use the same filters while terrain-specific facts enter the shown data.

counterplay:
Player can inspect one tactical question at a time before committing AP.

preview/UI:
Each filter defines an icon id, shown information, and hidden noise.

test/replay proof:
`tests/run.lua` verifies all seven overlay filters exist and each defines icon, shown data, and hidden data.

## U.3 Tile Inspector Copy

source pattern:
Readable tactics UI uses short tile facts instead of long rule text.

thoth transformation:
Thoth tile inspector has one mechanics line and one lore line, both filled from required tokens.

board verb:
Inspect, summarize, counter.

zone fit:
Each zone supplies tone and lore while the mechanics template stays shared.

counterplay:
Mechanics line includes effect, AP cost, and counterplay in one glance.

preview/UI:
Template fields are title, mechanics line, lore line, one-line caps, and required tokens.

test/replay proof:
`tests/run.lua` verifies the inspector template defines one mechanics line, one lore line, one-line caps, and all required tokens.

## U.4 Preview Contract

source pattern:
Tactical clarity requires consequence preview before command commitment.

thoth transformation:
Thoth preview contract exposes AP cost, movement path, damage, push path, collision, cover change, objective change, and hazard result before commit.

board verb:
Preview, compare, commit.

zone fit:
All zone mechanics must write their consequences into these preview fields.

counterplay:
The player sees state deltas before spending AP.

preview/UI:
The contract is gated at `before_commit`; every required field is visible and has a source.

test/replay proof:
`tests/run.lua` verifies the before-commit gate and all eight preview fields.

## U.5 Four-Rotation Readability

source pattern:
Isometric tactics overlays must remain readable as the camera rotates.

thoth transformation:
Thoth checks every overlay at 0, 90, 180, and 270 degrees for visibility, upright labels, stable logical tiles, distinct screen projection, non-color redundancy, and occlusion.

board verb:
Rotate, compare, audit.

zone fit:
Every overlay filter uses the same rotation checks across all zone boards.

counterplay:
Rotation should reveal planning facts without corrupting overlay meaning.

preview/UI:
Readability contract lists four rotations, applicable overlays, and required checks.

test/replay proof:
`tests/run.lua` verifies all overlay filters are covered by the four-rotation readability contract and each check defines a rule.

## U.6 Tutorial Board Sequence

source pattern:
Tactics tutorials work best when each board isolates one board verb before combining systems.

thoth transformation:
Thoth tutorial sequence teaches movement, cover/flank, intent, forced movement, destructible terrain, objective pressure, redacted intent, and boss weak point.

board verb:
Teach, preview, commit, verify.

zone fit:
Sequence starts with generic board verbs and ends with Thoth-specific redaction and rotation weak points.

counterplay:
Each tutorial exit check confirms the player used the intended counter before adding complexity.

preview/UI:
Tutorial catalog defines id, taught concept, board sketch, and exit check.

test/replay proof:
`tests/run.lua` verifies all eight tutorial steps exist and each defines taught concept, board sketch, and exit check.

## U.7 Screenshot-Smoke Target

source pattern:
Tactical UI should capture overlay states, not only menus, in smoke evidence.

thoth transformation:
Thoth defines a tactical overlay screenshot-smoke target covering every overlay filter across four rotations at a fixed viewport.

board verb:
Capture, compare, assert.

zone fit:
Smoke target uses a fixture with all overlay layers so zone-specific render regressions become visible.

counterplay:
QA can catch blank overlays, missing icons, color-only cues, text overlap, and rotation-coordinate drift.

preview/UI:
Target defines fixture, viewport, overlays, rotations, and assertions.

test/replay proof:
`tests/run.lua` verifies the screenshot-smoke target covers every overlay filter, four rotations, viewport, fixture, and assertions.

## U.8 Tactical HUD

source pattern:
Readable tactics HUDs expose active unit resources, previews, intent, objectives, and turn order without requiring external notes.

thoth transformation:
Thoth defines a tactical HUD contract for selected unit AP, move preview, action preview, enemy intents, objective risk, and turn order.

board verb:
Select, preview, inspect, order, commit.

zone fit:
All zones use the same HUD fields while objective risk and enemy intent copy stays zone-specific.

counterplay:
The player can compare AP, movement, action result, intent pressure, objective integrity, and upcoming units before spending AP.

preview/UI:
`UICatalog.tacticalHudSummary()` returns `selectedUnitAp`, `movePreview`, `actionPreview`, `enemyIntents`, `objectiveRisk`, and `turnOrder`.

test/replay proof:
`tests/run.lua` verifies the HUD contract fields and builds a deterministic summary from a tactical state with selected AP, move/action previews, enemy exact intent, objective integrity, and turn order.
