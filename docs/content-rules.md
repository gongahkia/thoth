# Content Rules

## Registry Prefixes

- `global_`: cross-zone rules, taxonomies, tests, and UI copy.
- `archive_`: Buried Archive missions, rooms, encounters, curios, narration, and documents.
- `cistern_`: Salt Cistern missions, rooms, encounters, curios, narration, and documents.
- `ember_`: Ember Warrens missions, rooms, encounters, curios, narration, and documents.
- `estate_`: Estate fixtures, town events, campaign pressure, ending, and panel copy.
- `encounter_`: global encounter simulation rules.
- `nar_`: internal narration line IDs for localization.

## Review Checklist

- Names, procedures, enemies, mission structures, and visual motifs must be original to Thoth.
- A reference can inform pacing or UX only; it cannot supply names, plot beats, faction identity, boss procedures, room set pieces, or prose.
- Reject content that is recognizable after swapping nouns back to a source work.
- Every task must name its Thoth function: route pressure, resource tradeoff, faction consequence, weak-point behavior, or UI clarity.
- New copy must pass the acceptance questions in `WORLD-LORE.md`.

## Gore Ceiling

- Body horror stays readable, brief, and mechanical.
- Prefer condition, consequence, and procedure over anatomy detail.
- No eroticized violence, torture spectacle, lingering mutilation, or shock-only description.
- Injuries should tell the player what changed: hand, lung, eye, nerve, salt, glass, ash, pressure.
- Combat narration can be grim; UI copy stays operational.

## Taxonomy Source

Runtime taxonomies live in `Registry.contentRules`:

- Items: `salvage`, `medicine`, `light`, `key`, `ritual_reagent`.
- Enemies: `scout`, `guard`, `caster`, `trapper`, `swarm`, `elite`, `support`, `alpha`, `boss`.
- Missions: `survey`, `extract`, `repair`, `seal`, `rescue`, `cleanse`, `activate`, `boss`.
- Curio outcomes: `safe_use`, `greedy_use`, `repair_use`, `leave_alone`.
