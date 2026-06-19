# Thoth RPG Rewrite Todo

## Current Repo State

- Runtime is Lua/LOVE 11.5 with headless LuaJIT tests.
- The active game is now an original isometric expedition RPG inspired by stress-heavy dungeon crawlers.
- Keep the LOVE shell, deterministic command queue, save/replay format, chunked world, and isometric projection/cache renderer.
- Tests remain the first quality gate; formatter/linter adoption waits until tools are installed or vendored.

## V1 Target

- Playable vertical slice in the Buried Archive.
- Four-hero default roster: Warden, Duelist, Mender, Arcanist.
- Expedition loop: move, scout rooms, manage light/provisions/hunger, resolve curios and traps, camp, fight rank-based encounters, return to estate.
- Combat loop: four party ranks, enemy ranks, initiative, enemy skills, HP, stress, bleed/daze/mark, Death's Door, resolve checks, active afflictions, one virtue, retreat, permadeath.
- Estate loop: carry gold/heirlooms home, recruit heroes, assign party ranks, provision expeditions, equip trinkets, train skills/gear, upgrade buildings, treat quirks, recover stressed heroes.

## Done

- Replaced automation registry with RPG data for tiles, items, hero classes, skills, enemies, afflictions, curios, encounters, location, and camp skills.
- Replaced simulation with deterministic estate, expedition, curio, camping, stress, resolve, and rank combat state.
- Added estate roster recruitment, rank assignment, provisioning, trinkets, quirks, upgrades, and mission rewards.
- Added enemy skill AI, Death's Door, hero statuses, hunger checks, low-light pressure, room scouting, camp respite skills, and mission objectives.
- Preserved chunked `World` snapshots and isometric render projection/cache APIs.
- Bumped save/replay headers to v2 and made old versions fail explicitly.
- Replaced active tests and benchmark with RPG coverage.
- Expanded replay coverage for estate, provisioning, mission, and camp commands.

## Next

- Add additional map layouts/locations beyond the Buried Archive.
- Add richer combat targeting UI and explicit estate controls for every command surface.
- Add more hero classes, enemy factions, bosses, quirks, virtues, diseases, and trinkets.
- Add authored visual/audio cues for RPG actions when assets are available.
