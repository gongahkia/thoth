# Tactical Boss Catalog

## B.1 Codex Reeve

source pattern:
Into the Breach-style board promises plus XCOM-like AP pressure and boss weak-point phases.

thoth transformation:
Codex Reeve posts archive audit lines that disable AP on named tiles until the Open Register weak point is broken.

board verb:
Audit, disable AP, break register, rotate to read back seals.

zone fit:
Buried Archive uses claim desks, witness diagonals, audit lenses, and reverse-face seals.

counterplay:
Block audit lines, move off AP disable tiles, break the Open Register, or rotate to reveal back-seal planning facts.

preview/UI:
Show audit lines, AP penalty tiles, Open Register HP, and four rotation-revealed back seals.

test/replay proof:
`tests/run.lua` verifies the Codex Reeve board defines audit lines, AP disable tiles, Open Register weak point, and rotation back seals.

## B.2 Vault Regent

source pattern:
Boss puzzle boards use telegraphed beams, cover pressure, objective collateral, and destructible support objects.

thoth transformation:
Vault Regent turns archive law into claim beams, named collateral, legal cover, and writ pillars that must be broken to open attack lanes.

board verb:
Claim, name collateral, shelter behind legal cover, destroy writ pillars.

zone fit:
Buried Archive supports claim lanes, seal walls, witness names, and desks that act as official cover.

counterplay:
Brace named collateral, flank legal cover from rear seals, destroy writ pillars, or force the Regent's claim beam into enemy cover.

preview/UI:
Show claim beam footprint, collateral names, cover authority edge, writ pillar HP, and the cover removed by each pillar.

test/replay proof:
`tests/run.lua` verifies the Vault Regent board defines claim beams, name collateral, legal cover, and destructible writ pillars.

## B.3 Pearl Choir

source pattern:
Boss boards combine telegraphed hazard lanes, phase clocks, adds, and objective-safe counter windows.

thoth transformation:
Pearl Choir refloods drained cistern lanes unless choir throats are silenced before the moving waterline reaches overflow.

board verb:
Reflood, silence throats, move waterline, ring pressure bells, spawn adds.

zone fit:
Salt Cistern already uses valves, flood lanes, pressure bells, pearl cysts, and waterline height.

counterplay:
Silence low and high choir throats, drain lanes before chorus, reposition off low ground, or block pressure bell add spawns.

preview/UI:
Show reflood countdowns, throat status, current/next waterline, low-ground hostility, and add spawn triggers.

test/replay proof:
`tests/run.lua` verifies the Pearl Choir board defines reflooding lanes, choir throats, moving waterline, and pressure bell adds.

## B.4 Bell Diver

source pattern:
Boss boards use declared pull lanes, visible clocks, exposed weak points, and terrain bands that punish late positioning.

thoth transformation:
Bell Diver hooks units through cistern lanes while a flood-toll countdown threatens low ground unless the Bell Lung is broken.

board verb:
Hook, pull, break Bell Lung, count flood toll, punish low ground.

zone fit:
Salt Cistern uses pressure bells, undertow tiles, hook-like currents, low ground, and route machinery.

counterplay:
Block hook lanes, leave low ground before toll expiry, break the Bell Lung, or sacrifice cover to stop a pull path.

preview/UI:
Show hook lane pull distance, Bell Lung reveal condition, toll countdown, next flooded low-ground band, and objective-carrier risk.

test/replay proof:
`tests/run.lua` verifies the Bell Diver board defines hook lanes, Bell Lung weak point, flood-toll countdown, and low-ground punishment.
