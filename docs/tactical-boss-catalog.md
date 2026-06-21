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

## B.5 Kiln Vicar

source pattern:
Boss puzzles use visible target selection, terrain blockers, support objects, and counter routes that trade AP for safety.

thoth transformation:
Kiln Vicar vitrifies the most exposed unit or objective unless halo vents are doused or ash-choke cover breaks LoS.

board verb:
Vitrify, douse halo vents, route water through heat, shelter in ash choke.

zone fit:
Ember Warrens already uses kiln heat, halo vents, douse chains, glass hazards, and ash-choke cover.

counterplay:
Break LoS with ash choke, douse halo vents, route water through a heat lane, or move the exposed target behind cover.

preview/UI:
Show selected vitrify target, halo vent state, douse route AP cost, glass reflection path, and ash-choke cover tradeoff.

test/replay proof:
`tests/run.lua` verifies the Kiln Vicar board defines vitrify targeting, halo vents, douse routes, and ash-choke cover.

## B.6 Cinder Prioress

source pattern:
Phased boss arenas use terrain mutation, reflection-like lane control, and objective tradeoffs to make damage windows secondary.

thoth transformation:
Cinder Prioress advances furnace phases, uses glass crown reflectors to bend line intents, and pressures fuel objectives with explicit tradeoffs.

board verb:
Phase furnace, reflect through glass crown, protect or sacrifice fuel, rotate for rear weak point.

zone fit:
Ember Warrens uses furnace doors, fuel carts, glass screens, white-coal pressure, and reflected heat lanes.

counterplay:
Break or rotate around crown reflectors, destroy fuel to slow phase escalation, guard fuel for reward, or douse heat before cinder phase.

preview/UI:
Show active furnace phase, next mutation, reflector angle, fuel choice benefit/cost, and objective integrity projection.

test/replay proof:
`tests/run.lua` verifies the Cinder Prioress board defines furnace phases, glass crown reflectors, and fuel-objective tradeoffs.

## B.7 Boss Variants

source pattern:
Boss variants change arena rule, add mix, weak-point exposure, and objective pressure without hiding declared tactical outcomes.

thoth transformation:
Each Thoth boss gets two variants that preserve the core procedure while swapping arena modifier, add family, weak-point location, and objective pressure.

board verb:
Swap arena, change adds, move weak point, retune objective pressure.

zone fit:
Archive variants alter claims and audit cover; cistern variants alter waterline and hook pressure; warrens variants alter vents, ash, glass, and fuel.

counterplay:
Inspect variant card before board entry, rotate for the new weak-point location, block the changed add family, and plan around the listed objective pressure.

preview/UI:
Show variant id, arena modifier, add family, weak-point location, and objective pressure beside the boss phase card.

test/replay proof:
`tests/run.lua` verifies every boss in `BossCatalog.allBosses()` defines exactly two variants with arena modifier, add family, weak-point location, and objective pressure.

## B.8 Boss Tactical Contract

source pattern:
Readable boss encounters need exact promises, partial masked warnings, terrain change, objective pressure, and non-damage counters.

thoth transformation:
Every BossCatalog entry carries a tactical contract with one exact intent, one partial intent, one terrain mutation, one objective threat, and one zero-damage counter.

board verb:
Declare exact intent, mask partial intent, mutate terrain, threaten objective, answer without damage.

zone fit:
Archive contracts use audits and claims; cistern contracts use floods and hooks; warrens contracts use vitrify, furnace, ash, and glass.

counterplay:
Use the listed non-damage counter, break LoS, rotate for weak point, protect objective, or alter terrain before declared resolution.

preview/UI:
Boss phase card must show exact intent, partial category hint, next terrain mutation, objective threat, and non-damage counter prompt.

test/replay proof:
`tests/run.lua` verifies every boss in `BossCatalog.allBosses()` defines the full tactical contract and every non-damage counter has `damage = 0`.
