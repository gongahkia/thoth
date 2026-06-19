# Thoth RPG Rewrite Todo

## Current Repo State

- Runtime is Lua/LOVE 11.5 with headless LuaJIT tests.
- The active game is now an original isometric expedition RPG inspired by stress-heavy dungeon crawlers.
- Keep the LOVE shell, deterministic command queue, save/replay format, chunked world, and isometric projection/cache renderer.
- Tests remain the first quality gate; formatter/linter adoption waits until tools are installed or vendored.

## V1 Target

- Playable vertical slice across the Buried Archive, Salt Cistern, and Ember Warrens.
- Four-hero default roster with eight recruitable classes: Warden, Duelist, Mender, Arcanist, Harrier, Chirurgeon, Exile, Lamplighter.
- Expedition loop: choose mission tiers, move, scout rooms, manage light/provisions/hunger, resolve curios and traps, gather/activate quest objects, camp, fight rank-based encounters, return to estate before campaign limits collapse.
- Combat loop: four party ranks, enemy ranks, initiative, enemy skills, HP, stress, bleed/daze/mark, Death's Door, resolve checks, active afflictions/virtues, retreat, fallen-trinket recovery, permadeath.
- Estate loop: carry gold/heirlooms home, recruit/dismiss heroes, assign party ranks, provision expeditions, buy/equip/sell trinkets, train skills/gear, upgrade buildings, treat or lock quirks, assign stress recovery activities.

## Done

- Replaced automation registry with RPG data for tiles, items, hero classes, skills, enemies, afflictions, curios, encounters, location, and camp skills.
- Replaced simulation with deterministic estate, expedition, curio, camping, stress, resolve, and rank combat state.
- Added estate roster recruitment/dismissal, rank assignment, provisioning, trinket market/equip/sale, quirks, upgrades, and mission rewards.
- Added enemy skill AI, Death's Door, hero statuses, hunger checks, low-light pressure, room scouting, camp respite skills, mission objectives, and resolve-tier mission pressure.
- Added multiple dungeon locations, location-specific enemies/bosses/curios, gather/activate missions, diseases and treatment, combat target hitboxes, fallen-trinket recovery, estate mouse controls, exact roster controls, loot capacity, estate week cadence, campaign collapse limits, town events, selectable stress recovery activities, quirk growth/locking, virtue variety, and persistent campaign pressure.
- Preserved chunked `World` snapshots and isometric render projection/cache APIs.
- Bumped save/replay headers to v2 and made old versions fail explicitly.
- Replaced active tests and benchmark with RPG coverage.
- Expanded replay coverage for estate, provisioning, mission, and camp commands.

## Next

- Add more room layouts, boss variants, and endgame consequences.
- Add richer estate UX for filtering/sorting the roster and comparing hero progression.
- Add more diseases, trinkets, town events, and location-specific provision tuning.
- Add authored visual/audio cues for RPG actions when assets are available.
