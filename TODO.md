# Thoth RPG Rewrite Todo

## Current Repo State

- Runtime is Lua/LOVE 11.5 with headless LuaJIT tests.
- The active game is now an original isometric expedition RPG inspired by stress-heavy dungeon crawlers.
- Keep the LOVE shell, deterministic command queue, save/replay format, chunked world, and isometric projection/cache renderer.
- Tests remain the first quality gate; formatter/linter adoption waits until tools are installed or vendored.

## V1 Target

- Playable vertical slice in the Buried Archive.
- Four-hero default roster: Warden, Duelist, Mender, Arcanist.
- Expedition loop: move, scout rooms, manage light/provisions, resolve curios, camp once, fight rank-based encounters, return to estate.
- Combat loop: four party ranks, enemy ranks, initiative, HP, stress, bleed/daze, resolve checks, afflictions, one virtue, retreat, permadeath.
- Estate loop: carry gold/heirlooms home and recover stressed heroes.

## Done

- Replaced automation registry with RPG data for tiles, items, hero classes, skills, enemies, afflictions, curios, encounters, location, and camp skills.
- Replaced simulation with deterministic estate, expedition, curio, camping, stress, resolve, and rank combat state.
- Preserved chunked `World` snapshots and isometric render projection/cache APIs.
- Bumped save/replay headers to v2 and made old versions fail explicitly.
- Replaced active tests and benchmark with RPG coverage.

## Next

- Add more expedition layouts after the V1 loop is stable.
- Add richer hero recovery choices and roster recruitment.
- Add more enemy behaviors after combat readability is verified.
- Add authored visual/audio cues for RPG actions when assets are available.
