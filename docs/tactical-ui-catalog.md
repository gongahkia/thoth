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
