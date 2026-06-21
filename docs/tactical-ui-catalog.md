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
