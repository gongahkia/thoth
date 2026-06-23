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
Thoth tutorial sequence starts with a single-screen 6x6 onboarding board, then teaches movement, cover/flank, intent, forced movement, destructible terrain, objective pressure, redacted intent, and boss weak point.

board verb:
Teach, preview, commit, verify.

zone fit:
Sequence starts with generic board verbs and ends with Thoth-specific redaction and rotation weak points.

counterplay:
Each tutorial exit check confirms the player used the intended counter before adding complexity.

preview/UI:
Tutorial catalog defines id, taught concept, board sketch, and exit check.

test/replay proof:
`tests/run.lua` verifies all nine tutorial steps exist and each defines taught concept, board sketch, and exit check.

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
Thoth defines a tactical HUD contract for selected unit AP, move preview, action preview, enemy intents, objective risk, turn order, and a six-unit roster rail with portraits, AP pools, and selected-unit state.

board verb:
Select, preview, inspect, order, commit.

zone fit:
All zones use the same HUD fields while objective risk and enemy intent copy stays zone-specific.

counterplay:
The player can compare AP, movement, action result, intent pressure, objective integrity, and upcoming units before spending AP.

preview/UI:
`UICatalog.tacticalHudSummary()` returns `selectedUnitAp`, `movePreview`, `actionPreview`, `enemyIntents`, `objectiveRisk`, and `turnOrder`. `Render.tacticalSquadHudRows()` derives six portrait/AP rows from the live runtime summary. `Render.tacticalHudLayoutAudit(1920, 1080, 6)` verifies the roster rail, objective panel, top HUD, and action bar do not overlap the reserved board rectangle.

test/replay proof:
`tests/run.lua` verifies the HUD contract fields, builds a deterministic summary from a tactical state with selected AP, move/action previews, enemy exact intent, objective integrity, and turn order, then checks the live six-unit route HUD rows and 1080p non-overlap layout. `make tactical-smoke` prints the same 1080p HUD layout audit.

## U.8A Intent Legend Overlay

source pattern:
Readable deterministic tactics expose declared enemy plans as a scanline, then let players inspect the affected board cells directly.

thoth transformation:
Thoth renders a bottom intent legend from every declared enemy intent. Hovering a legend item highlights revealed target tiles and the source enemy while feeding the tile inspector.

preview/UI:
`Render.tacticalIntentLegendEntries()` derives legend rows from committed enemy intents. `Render.drawTacticalIntentLegend()` creates hover hitboxes; `Input.updateTacticalIntentHover()` activates target/source highlighting.

test/replay proof:
`tests/run.lua` verifies legend source and target extraction plus hover state. `make tactical-smoke` verifies the live route exposes two legend rows and at least one target tile.

## U.9 Tile Inspector Facts

source pattern:
Readable tactics UI exposes tactical tile facts, projected effects, and short tooltip-style explanations at the point of decision.

thoth transformation:
Thoth tile inspector exposes terrain, tile tags, cover edges, LoS, hazards with timers, destructible terrain HP, hidden info state, squad vision sources, and current intent traces from a deterministic state summary.

board verb:
Inspect, reveal, compare, counter.

zone fit:
Archive, Cistern, and Warrens feed the same inspector fields with local terrain, hazard, reveal, and intent data.

counterplay:
The player can inspect whether a tile blocks movement/LoS, grants cover, carries hazard cost, hides rotation facts, can be broken, or is targeted before spending AP.

preview/UI:
`UICatalog.tileInspectorSummary()` returns `terrain`, `cover`, `los`, `hazards`, `destructibleHp`, `hiddenInfo`, `visionSources`, and `intentTraces`. `Input.updateTacticalHover()` updates `app.tacticalHover` and `app.tacticalInspector`; `Render.tacticalTileInspectorLines()` formats the facts for the lower-right tactical panel.

test/replay proof:
`tests/run.lua` verifies the tile inspector contract fields and builds a deterministic summary from a tile with terrain, tags, cover, LoS, active hazard timer, destructible HP, hidden rotation mark, reveal metadata, squad vision sources, and exact enemy intent trace. It also verifies mouse hover populates the rendered inspector summary.

## U.10 Rotation-Aware Overlay Audit

source pattern:
Isometric tactics UI uses camera rotation as a planning tool, so overlays must move on screen while preserving logical tile identity.

thoth transformation:
Thoth projects tactical overlay entries at all four camera snaps and records screen position, logical stability, upright label orientation, icon/pattern readability, and occlusion offsets. The tactical HUD renders a rotation compass without ghost-arrow transition lines.

board verb:
Rotate, inspect, compare, preserve.

zone fit:
All zone overlays share the same projection audit while local rotation marks and hidden facts remain state-driven.

counterplay:
The player can rotate to inspect occluded plans without losing which tile an intent, hazard, cover edge, or LoS marker belongs to.

preview/UI:
`Render.tacticalOverlayRotationAudit()` returns four rotation buckets with projected entries, stable logical coordinates, readable symbols, and occlusion metadata. `Render.rotationCompass()` maps world directions to the current 90-degree view. `Render.tacticalGhostArrowEntries()` returns no entries, keeping rotation transitions free of ghost-arrow lines.

test/replay proof:
`tests/run.lua` verifies the audit covers four snaps, preserves entry count and logical tile coordinates, keeps labels upright, keeps icon/pattern metadata, exposes occlusion offsets, changes screen positions across rotations, maps the 90-degree compass, and keeps ghost arrows hidden. `make tactical-smoke` verifies compass output and zero ghost-arrow output.

## U.11 Enemy Intent Cards And Badges

source pattern:
Enemy intent has to be readable from the board first, with roster/detail panels reinforcing the same promise.

thoth transformation:
Thoth renders intent badges over visible enemies and matching Threat cards in the right HUD. Both surfaces use the same category, damage, source tile, target tiles, and hidden/category-only state as the bottom intent legend.

board verb:
Read, hover, target, counter.

preview/UI:
`Runtime.summary()` exposes visible enemy intent category, label, damage, target tiles, and hidden state. `Render.tacticalEnemyHudRows()` formats Threat cards; `Render.drawTacticalEnemyIntentBadges()` anchors board badges and registers the same `tacticalIntentButtons` hover hitboxes used by the bottom legend.

test/replay proof:
`tests/run.lua` verifies enemy card rows expose visible intent data. `make tactical-smoke` verifies nonzero enemy cards and intent badges.

## U.12 Unified Expanse Terrain

source pattern:
Large isometric spaces need readable traversal structure: raised walks, stairs, bridges, destructible set pieces, sightlines, cover fields, and visible destination scale.

thoth transformation:
The Buried Archive tactical route starts as one 32x24 expanse. Later route regions are stitched into the same board as dormant regions; route advancement wakes the next region without replacing the tactical state. Height, ascent/descent routes, XCOM-style cover fields, sightlines, and destructible LoS blockers are board facts, synced into render-world tile metadata, and raised in the 3D tile model.

board verb:
Traverse, climb, descend, take cover, break, reveal.

preview/UI:
Height-tagged terrain rejects impossible climbs/drops unless a stair is present. Movement preview exposes climb/descend deltas. Destructible structures can collapse to lower height and rubble, including sightline columns that open LoS after breaking. The tile inspector exposes terrain height, destructible HP, sightline height delta, high/low ground, effective cover, flank, and damage reduction.

test/replay proof:
`tests/run.lua` verifies the 32x24 expanse, dormant region enemies, state-preserving route advancement, bridge collapse, ascent/descent grammar, high-ground sightlines, breakable LoS columns, height movement gates, movement climb preview, and elevation-aware inspector copy. `make tactical-smoke` verifies board size, height tiles, destructible terrain, vertical route, descent, sightline, and high-cover counts.

## U.13 Colorblind-Safe Tactical Palette

source pattern:
Accessible visual systems avoid red/green dependence, vary lightness, and pair color with texture, symbols, or annotation.

thoth transformation:
Thoth defines a shared intent/cover/hazard palette using distinct vermillion, blue, and yellow roles plus icon, pattern, and shape redundancy. The settings panel exposes tactical accessibility controls for high-contrast tiles, intent icon scale, cover edge palette, and duplicated intent text.

board verb:
Mark, distinguish, verify, inspect.

zone fit:
All zones use the same role colors while local hazard, cover, and intent labels stay data-driven.

counterplay:
The player can distinguish enemy intent, cover, and hazards through color, icon, pattern, and shape even under colorblind display modes.

preview/UI:
`UICatalog.accessiblePalette()` returns role metadata, supported simulation modes, review checks, RGBA colors, hex values, icons, patterns, and shapes; render overlay defaults consume the same role data. `Settings.accessibilityControls()` groups tactical readability settings, and `Render.tacticalAccessibility()` applies them to tactical tile colors, cover entries, intent icon scale, and intent text.

test/replay proof:
`tests/run.lua` verifies palette roles, modes, checks, simulated color separation for off/deuteranopia/protanopia/tritanopia, render overlay color/icon/pattern alignment, tactical settings persistence, tile contrast transforms, intent scale/text metadata, and settings-panel hitboxes. `make settings-smoke` verifies the tactical accessibility controls are present.

## U.14 Reduced-Motion Tactical Equivalents

source pattern:
Reduced-motion interfaces suppress non-essential interaction motion while preserving the information the motion conveyed.

thoth transformation:
Thoth defines reduced-motion equivalents for rotation, destruction, knockback, and explosions, replacing motion with static labels, markers, arrows, footprints, and state deltas.

board verb:
Snap, mark, indicate, preserve.

zone fit:
All zones use the same equivalents while local terrain, forced movement, and blast data provide the cue text.

counterplay:
The player still sees view angle, destroyed terrain state, forced-movement path, collision, blast footprint, and damage/objective deltas without camera tween, shake, slide, or expanding blast motion.

preview/UI:
`Render.motionPlan()` returns animated or reduced plans for `rotation`, `destruction`, `knockback`, and `explosion`; reduced plans use `animation = "none"` and name the static equivalent.

test/replay proof:
`tests/run.lua` verifies all four equivalents, reduced and animated plans, preserved tile metadata, UI pulse suppression, and reduced-motion camera rotation snap.

## U.15 Tactical Controller Path

source pattern:
Accessible game UI supports analog and digital navigation, single-press actions, consistent prompts, remapping, and predictable focus.

thoth transformation:
Thoth defines a controller path for selecting units, selecting tiles, choosing actions, selecting targets, and confirming previews.

board verb:
Focus, select, inspect, target, confirm, cancel.

zone fit:
All zone boards share the same controller path while local objectives, hazards, and intents feed preview text.

counterplay:
The player can inspect a unit, tile, action, target, and before-commit preview with controller-only input and cancel before queuing the command.

preview/UI:
`UICatalog.controllerPath()` defines principles, bindings, and stages; `Input.tacticalGamepadMap()` exposes select, back, inspect, focus, rotation shoulders, and analog/digital cursor controls.

test/replay proof:
`tests/run.lua` verifies joystick module enablement, button/axis mapping, tactical gamepad map fields, controller path bindings, five required stages, stage input/output/preview metadata, and cancel-before-commit support.

## U.16 Tutorial Board Fixtures

source pattern:
Readable tactics tutorials isolate one board verb at a time and use tutorial/combat UI surfaces to keep the player inside the tactical context.

thoth transformation:
Thoth defines concrete tutorial board fixtures for single-screen onboarding, movement, cover/flanking, intent, push/pull, destruction, and objectives.

board verb:
Select, move, rotate, watch, end, react, flank, inspect, push, pull, break, protect.

zone fit:
The fixtures use generic tactical data, then map cleanly onto Archive, Cistern, and Warrens mechanics through hazards, cover, intent, destructible terrain, and objectives.

counterplay:
Each board teaches one counter before combining systems. The onboarding fixture combines six cue-sized actions on one 6x6 board: select, move, rotate, declare overwatch, end turn, and react to a revealed hidden intent.

preview/UI:
`UICatalog.tutorialBoards()` returns instantiable board specs with board data, units, objectives/intents when needed, actions, overlays, and exit checks.

test/replay proof:
`tests/run.lua` verifies all seven tutorial boards exist, instantiate as `TacticsState`, expose actions/overlays/exit checks, and cover single-screen onboarding, movement, cover/flank, exact intent, push plus pull, destructible cover, and objective pressure. It also verifies the onboarding board is 6x6, scripted, cue-driven, and reveals its hidden footprint through existing intent preview rules.
