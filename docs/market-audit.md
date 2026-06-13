# Thoth Market Audit

Date: 2026-06-11

This audit treats Thoth as a Steam-demo vertical slice: a compact deterministic automation-survival game where the player builds a starter factory, pushes into biome lairs, defeats prepared bosses, and stabilizes a rift.

## Positioning

Thoth should not compete on raw factory scale. Factorio already owns deep 2D logistics, research, trains, circuits, pollution, defense, and a rocket endpoint. Satisfactory owns first-person scale, spectacle, traversal, and massive open-world factories. Dyson Sphere Program owns the interstellar fantasy and macro-scale automation. shapez 2 owns pure readable automation puzzles without survival pressure.

Thoth's defensible lane is smaller and sharper:

- Deterministic top-down automation that can be tested, replayed, saved, and audited.
- A block-world expedition loop closer to Core Keeper than to a pure factory sandbox.
- Factory-prepared lair bosses where combat rewards change the factory plan.
- Defense pressure that asks for better automation instead of twitch combat.

## Competitive Lessons

| Game | What It Proves | Risk For Thoth | Useful Response |
| --- | --- | --- | --- |
| Factorio | Factory games need strong logistics, power, research, pressure, and a visible endpoint. | Thoth looks shallow if contracts are only counters. | Make each contract force a new factory shape: powered mining, remote outposts, pressure control, rift prep. |
| Satisfactory | Exploration works when new materials, outposts, and traversal visibly expand factory scale. | Flat biomes can feel decorative. | Give every biome a lair, boss, resource pressure, and machine/relic payoff. |
| Dyson Sphere Program | Big automation fantasy benefits from long-range resource logistics and escalating scope. | Thoth cannot match cosmic scale. | Use the rift as a compact "outer band" escalation with dense resources and pressure. |
| Mindustry | Factory + tower defense is compelling when turrets require ammo/power/support and waves threaten infrastructure. | Guard towers alone are too passive. | Add repair, pressure mitigation, stronger towers, and wave warnings tied to factory output. |
| shapez 2 | Clear production goals make automation immediately readable. | Thoth's first minutes can feel like a sandbox with no promise. | Always show one concrete demo goal and the next production/lair objective. |
| Core Keeper | Biomes, bosses, relics, and base growth make exploration sticky. | Bosses are forgettable if they only drop generic items. | Boss relics should unlock or cheapen factory tools. |
| The Riftbreaker | Base-building, outposts, research, and enemy pressure can combine into a strong action-production loop. | Combat can overwhelm the automation identity. | Keep pressure deterministic and solveable through machines. |

## Product Gaps

- The first 10 minutes still rely on the player accepting the premise before the game proves its hook.
- The lair ladder now has authored anchors plus seeded procedural repeats, but generated lair density and cache readability need playtest tuning.
- Boss rewards now socket into factory-relevant support machines, but reward costs and pacing still need a continuous-run balance pass.
- Defense now has factory-anchored waves, pressure hotspot maps, infrastructure-targeting pressure enemies, ammo-fed towers, repair pylons, pressure relays, and arc towers, but wave cadence and structure-damage tuning still need live playtesting.
- Rift travel now feeds repeatable post-victory expeditions, scout reports, archive-fragment alternates, and route-stability goals, but rift-band resources and late factory tools need more distinct verbs.
- Construction ghosts, planning mode, and drone build jobs give the factory loop a blueprint layer, but the UI still needs live usability tuning.
- Documentation explains the codebase well, but the product promise needs sharper wording for real-player evaluation.

## Expansion Thesis

For the next Steam-demo pass, prioritize content that changes player behavior:

- Tune authored plus generated lairs so every biome has a repeatable expedition target without overwhelming the starter ring.
- Keep boss relics tied to factory and defense capability, and tune summon costs so bosses happen throughout the run instead of all at the end.
- Lean on stable remote outpost routes, named scout regions, and local-biome scouting so exploration requires logistics, not only inventory stockpiles.
- Keep combat pressure solved by building a better factory: walls, ammo logistics, powered towers, repair, pressure control, and route planning.
- Keep production-rate, construction, archive, pressure, and region panels readable enough that the demo is legible from minute one.

## Sources

- Factorio official content page: https://factorio.com/game/content
- Satisfactory Steam page: https://store.steampowered.com/app/526870/Satisfactory/
- Dyson Sphere Program Steam page: https://store.steampowered.com/app/1366540/Dyson_Sphere_Program/
- Mindustry Steam page: https://store.steampowered.com/app/1127400/Mindustry/
- shapez 2 Steam page: https://store.steampowered.com/app/2162800/shapez_2__Factory/
- Core Keeper Steam page: https://store.steampowered.com/app/1621690/Core_Keeper/
- The Riftbreaker Steam page: https://store.steampowered.com/app/780310/The_Riftbreaker/
