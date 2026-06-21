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

## U.9 Tile Inspector Facts

source pattern:
Readable tactics UI exposes tactical tile facts, projected effects, and short tooltip-style explanations at the point of decision.

thoth transformation:
Thoth tile inspector exposes terrain, cover, LoS, hazards, destructible HP, hidden info state, and current intent traces from a deterministic state summary.

board verb:
Inspect, reveal, compare, counter.

zone fit:
Archive, Cistern, and Warrens feed the same inspector fields with local terrain, hazard, reveal, and intent data.

counterplay:
The player can inspect whether a tile blocks movement/LoS, grants cover, carries hazard cost, hides rotation facts, can be broken, or is targeted before spending AP.

preview/UI:
`UICatalog.tileInspectorSummary()` returns `terrain`, `cover`, `los`, `hazards`, `destructibleHp`, `hiddenInfo`, and `intentTraces`.

test/replay proof:
`tests/run.lua` verifies the tile inspector contract fields and builds a deterministic summary from a tile with terrain, cover, LoS, active hazard, destructible HP, hidden rotation mark, reveal metadata, and exact enemy intent trace.

## U.10 Rotation-Aware Overlay Audit

source pattern:
Isometric tactics UI uses camera rotation as a planning tool, so overlays must move on screen while preserving logical tile identity.

thoth transformation:
Thoth projects tactical overlay entries at all four camera snaps and records screen position, logical stability, upright label orientation, icon/pattern readability, and occlusion offsets.

board verb:
Rotate, inspect, compare, preserve.

zone fit:
All zone overlays share the same projection audit while local rotation marks and hidden facts remain state-driven.

counterplay:
The player can rotate to inspect occluded plans without losing which tile an intent, hazard, cover edge, or LoS marker belongs to.

preview/UI:
`Render.tacticalOverlayRotationAudit()` returns four rotation buckets with projected entries, stable logical coordinates, readable symbols, and occlusion metadata.

test/replay proof:
`tests/run.lua` verifies the audit covers four snaps, preserves entry count and logical tile coordinates, keeps labels upright, keeps icon/pattern metadata, exposes occlusion offsets, and changes screen positions across rotations.

## U.11 Colorblind-Safe Tactical Palette

source pattern:
Accessible visual systems avoid red/green dependence, vary lightness, and pair color with texture, symbols, or annotation.

thoth transformation:
Thoth defines a shared intent/cover/hazard palette using distinct vermillion, blue, and yellow roles plus icon, pattern, and shape redundancy.

board verb:
Mark, distinguish, verify, inspect.

zone fit:
All zones use the same role colors while local hazard, cover, and intent labels stay data-driven.

counterplay:
The player can distinguish enemy intent, cover, and hazards through color, icon, pattern, and shape even under colorblind display modes.

preview/UI:
`UICatalog.accessiblePalette()` returns role metadata, supported simulation modes, review checks, RGBA colors, hex values, icons, patterns, and shapes; render overlay defaults consume the same role data.

test/replay proof:
`tests/run.lua` verifies palette roles, modes, checks, simulated color separation for off/deuteranopia/protanopia/tritanopia, and render overlay color/icon/pattern alignment.
