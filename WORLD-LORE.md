# Thoth World Lore

North star for content, naming, tone, and future implementation. Mechanics in code remain source of truth.

## Research Anchors

- [British Museum: Library of Ashurbanipal](https://www.britishmuseum.org/blog/library-fit-king): archive as power, omen-reading, medicine, ritual, law, royal control, and preserved fragments after fire.
- [Kodansha: BLAME!](https://kodansha.us/series/blame/volume-1/): inspiration for overwhelming post-apocalyptic architecture, sparse survivors, hostile automatic systems, and scale that makes people feel temporary.
- [Pokemon Legends: Arceus gameplay](https://legends.arceus.pokemon.com/en-us/gameplay/): inspiration for visible roaming threats, observation, camps, alpha-like danger, and behavior-led exploration.
- [Darkest Dungeon affliction design](https://www.gamedeveloper.com/design/game-design-deep-dive-i-darkest-dungeon-s-i-affliction-system): inspiration for stress as clear feedback with unpredictable human reactions.
- [Fear & Hunger: Termina](https://mirohaver.itch.io/fear-hunger-termina): inspiration for open-ended routes, ruthless resource pressure, and body-target combat pressure; do not import explicit content.
- [World History Encyclopedia: Ereshkigal](https://www.worldhistory.org/Ereshkigal/): inspiration for gates, underworld custody, dead kept where they belong, and the living trespassing where they should not.
- [Into the Breach](https://subsetgames.com/itb.html): inspiration for deterministic tile tactics, telegraphed enemy attacks, collateral defense, and compact tactical boards.
- [Into the Breach Design Postmortem](https://media.gdcvault.com/gdc2019/presentations/Into%20the%20Breach%20Postmortem%20Final.pdf): inspiration for following design constraints, reducing random chance, visible threat promises, and low-number readability.
- [XCOM cover/flanking](https://xcom.fandom.com/wiki/Cover): inspiration for directional cover, flanking, destructible protection, and tile-based squad risk.
- [Slay the Spire enemy intents](https://slay-the-spire.fandom.com/wiki/Intent): inspiration for mixed enemy intent categories: attack, defend, buff, debuff, escape, stunned, and unknown.
- [Invisible Inc design interview](https://www.shacknews.com/article/89531/invisible-inc-programmer-discusses-design-stealth-and-procedurally-generated-stages): inspiration for procedural tactical stealth, information gathering, readable guard intent, dependable planning, and generated layouts.
- [Invisible Inc procedural stealth talk](https://gdcvault.com/play/1021919/Designing-Procedural-Stealth-for-Invisible): inspiration for the hidden costs of novel procedural mechanics and validation discipline.
- [Gears Tactics gameplay pillars](https://www.gearsofwar.com/en-us/news/dev-blog-gameplay/): inspiration for AP flexibility, cover-to-cover movement, and player-authored overwatch cones.
- [Mario + Rabbids Sparks of Hope](https://www.ubisoft.com/en-us/game/mario-rabbids/sparks-of-hope): inspiration for free movement inside turn-based tactics, dashes, team jumps, cover, and loadout synergies.

These are reference directions, not content to copy.

## Core Premise

The world ended by administration, not by a single war.

Before the Estate, the old cities built the Great Stack: an archive-city meant to preserve law, medical record, lineage, land claim, illness, confession, debt, and death. Its keepers believed that if every life could be indexed, every disaster could be predicted and contained.

Then the Stack kept working after its builders failed.

It expanded downward and outward through old courts, cisterns, kilns, tombs, hospitals, temples, and housing blocks. It absorbed districts as "records." It preserved bodies as evidence, water as testimony, ash as correction, and names as collateral. The living now survive in pockets along its exterior. The Estate is one such pocket: a fortified survey town that sends expeditions into the Stack for salvage, maps, medicine, fuel, proof of ownership, and leverage over other survivors.

The party are not clean heroes. They are compromised salvagers working inside a colonial survey economy. They may protect survivors and repair damage, but the Estate still profits from extraction.

The pivot makes the Stack a tactical board before it is a dungeon. Every room is a procedure made visible: claims become cover lines, audits become threat cones, valves become flood lanes, shelves become destructible blockers, and sealed names become tile permissions. The party wins by reading what the room is about to do, then moving people, threats, and terrain until the least-bad outcome is acceptable.

## Tone Pillars

- Scale is hostile. Rooms should feel like small usable fragments of an architecture that continues far beyond the screen.
- The horror is institutional before it is monstrous. The Stack harms by filing, sorting, correcting, preserving, and enforcing.
- Body horror is readable and purposeful. Flesh is indexed, salted, vitrified, sutured, pressed, drained, or used as record media.
- Violence should stay tense and physical without becoming splatter-first.
- No explicit sexual violence.
- The player should feel practical pressure, not random cruelty. Hunger, torch, injury, scouting, and pack limits should explain why bad choices happen.
- Tactical cruelty must be declared before it resolves. The room may be unfair in motive, not unclear in rules.
- The Estate should be useful and morally compromised. It is home, employer, exploiter, hospital, creditor, and cage.
- Survivors inside the Stack are people, not loot dressing. Content should create friction between extraction and repair.
- Mystery should come from missing context and vast systems, not from incoherent proper nouns.
- Board readability is tone. A clean threat preview should feel like a bureaucratic notice: cold, exact, and hard to ignore.

## What Thoth Is Not

- Not a direct BLAME! setting. No NetSphere, Safeguards, Silicon Life, Killy analog, or gun-centered quest.
- Not Fear & Hunger content transplanted into Lua. No coin-flip lethality as the main identity, no explicit sexual horror, no copied gods, no copied limb system.
- Not Pokemon with collectible monsters. The useful lesson is field behavior and observation.
- Not Darkest Dungeon with renamed classes. Stress and ranks are mechanical lineage, but lore, factions, enemies, and architecture must be original.
- Not heroic archaeology. The party are taking things from inhabited ruins.
- Not an XCOM clone with hit percentages. Cover and flanking are useful; random tactical hit/miss is not the direction.
- Not an Into the Breach clone with mechs and cities. The useful lesson is deterministic consequence, not the setting or unit fantasy.

## Tactical North Star

The new combat identity:

- Turn-based, tile-based, deterministic, AP-driven squad tactics.
- Square logical boards rendered as rotatable isometric spaces.
- Variable squad size and class loadouts.
- Attacks, hazards, cover, line of sight, hidden information, objectives, and enemy intent are represented directly on tiles.
- Enemy intents mix exact forecasts, category forecasts, and limited unknowns. Unknown means "the type is withheld," not "damage appears from nowhere."
- Player actions should move board state: push, pull, swap, block, brace, reveal, destroy, raise cover, drop cover, flood, burn, seal, open, extract.
- Runs are roguelite: procedural boards, route choices, event variance, unlocks, boss variants, and persistent records.

Hybrid randomness in this world:

- Allowed: route generation, enemy families, event offers, board modifiers, rewards, boss variants, and partial intent masks.
- Not allowed: declared attacks randomly missing, hidden damage after the player committed, or cover secretly changing math after preview.

Rotation as fiction:

- The Stack was built to be read from official angles. Surveyors rotate the view to expose filing marks, blind ledgers, witness lanes, and cover faces.
- A tile may be physically visible from one angle but tactically understood only after another angle reveals its seal, edge, line, or shadow.
- Rotation never changes the board's logical state. It changes what the player can inspect.

## Research-To-Originality Rules

Research is mandatory for new tactical systems, but references are pattern sources only.

- Reference games may supply constraints, UI patterns, pacing lessons, and mechanic categories.
- References may not supply names, factions, enemy identities, plot beats, boss procedures, board layouts, prose, or exact ability kits.
- Every source-inspired idea must answer: what does the Stack think this tile/action means?
- Every mechanic must be rewritten through Thoth's language: procedure, claim, seal, debt, light, water, ash, glass, bone, vellum, route, witness, and repair.
- Every borrowed pattern needs a different cost structure, counterplay path, and board role.
- If the mechanic is still recognizable after replacing Thoth nouns with source-game nouns, cut or redesign it.
- Use web research to widen the design space; use WORLD-LORE to narrow it back into Thoth.

## Board Content Bible

### Buried Archive Boards

Archive boards are about being seen, named, filed, and claimed.

- Cover forms: shelf ranks, witness desks, docket carts, seal pillars, ledger stacks, rib shelves, archive shutters.
- LoS forms: audit beams, claim lanes, clerk sight lines, back-face seals, witness holes, indexing slits.
- Hazard forms: falling shelves, paper swarms, name-lock tiles, ink spread, misfile pits, redaction fog.
- Objective forms: records, witnesses, bound dead, Open Register, debt seals, claim engines, intake doors.
- Destructible forms: shelves become debris cover; ledgers burst into redaction fog; seal pillars break claim lanes.
- Rotation secrets: rear stamps, hidden witness lanes, back-side weak points, false cover marks.
- Board question: can the party break the procedure without becoming the record?

### Salt Cistern Boards

Cistern boards are about pressure, waterline, preservation, and drowning access.

- Cover forms: valve blocks, bulkheads, pump housings, salt barricades, reed screens, floating debris.
- LoS forms: salt mist, water glare, pressure-glass windows, submerged sight breaks, raised sluice walks.
- Hazard forms: flood lanes, undertow pulls, brine pools, pressure bells, pearl cyst bursts, drain suction.
- Objective forms: valves, pump hearts, enclave shelters, children/witnesses, drinkable water nodes, sluice keys.
- Destructible forms: valve wheels change flood direction; bulkheads release water; cysts create or block lanes.
- Rotation secrets: waterline marks, hidden drain grates, rear valve labels, submerged pressure cracks.
- Board question: can the party control the route without deciding who drowns?

### Ember Warrens Boards

Warrens boards are about purification, heat, glass, fuel, and whether erasure is mercy.

- Cover forms: kiln walls, ash heaps, clinker barricades, glass screens, fuel carts, fired-clay pews.
- LoS forms: bellows cones, smoke veils, heat shimmer, glass reflectors, furnace slits, halo lenses.
- Hazard forms: heat lanes, ash choke, ignition tiles, vitrification beams, white-coal pressure, cinder collapse.
- Objective forms: fuel stores, douse valves, ash names, false vows, furnace gates, trapped witnesses.
- Destructible forms: glass reflects until shattered; fuel carts ignite; kiln doors seal or vent heat.
- Rotation secrets: mirror angles, back-side vents, hidden douse lines, ash-covered weak points.
- Board question: can the party free the dead without burning the living proof?

## Unique Mechanic Seeds

Use these as starting points for research-backed tasks; each still needs implementation design and tests.

- Rotation-revealed back seals: a tile looks like cover from one angle, but another angle reveals it is a claim conduit.
- Redacted intent: enemy category is visible; exact tiles require light, rotation, Arcanist reading, or Lamplighter beacon.
- Filing lane: a visible line disables AP on its next pulse unless blocked with cover, body, seal, or enemy.
- Evidence cover: destroying cover creates proof fragments that can be extracted, ignored, or used as hazardous debris.
- Movable objective: the player can drag a route machine or witness, but each move lowers integrity or raises exposure.
- Enemy repairer: some enemies restore cover, seals, or hazards unless shoved, pinned, or line-broken.
- Angle weak point: elite/boss weak point is targetable only when rotation reveals the procedural back face.
- Claim mirror: glass terrain reflects LoS and intent previews until cracked or smoked.
- Waterline clock: Cistern boards gain or lose rows of traversable ground on declared turns.
- Douse chain: Ember hazards can be converted to smoke cover, then ash choke, then safe floor through repeated actions.
- Name collateral: some attacks target a record/objective paired with a hero, forcing a squad-vs-objective choice.
- Debt AP: Merchant tools can borrow AP now and add future route/event debt.
- Witness tile: standing on it reveals intent but also makes the unit a legal target.
- Seal inversion: repairing a seal blocks enemy intent but also closes an extraction or loot route.
- Hostile cover: some cover protects from damage while increasing redaction, heat, or pressure exposure.

## World Structure

### The Great Stack

The Great Stack is an automatic archive-city built from civil infrastructure and ritual architecture. Its oldest layers are buried under newer ones. It has no single ruler that people can bargain with. It has procedures.

Known behaviors:

- It classifies living beings as claimants, witnesses, contaminants, debtors, trespassers, remains, or clerks.
- It creates routes when a procedure requires witnesses.
- It seals routes when a record is considered complete.
- It preserves useful bodies and discards unclassifiable ones.
- It treats light as inspection authority, not safety.
- It treats names as keys.
- It treats water, salt, ash, and bone as storage media.
- It declares procedures before enforcing them when the target is officially recorded.
- It hides procedures when the party lacks angle, light, name, or witness authority.

The Stack is not fully sentient in a human way. It behaves like law, infrastructure, and immune system fused together.

Tactical implication: the Stack is strongest when it has line of sight, cover of law, and a declared procedure. The party survives by breaking those three conditions.

### The Estate

The Estate is a survivor town on the upper edge of the Stack. It grew around a breach, then became wealthy by selling maps and recovered records. Its official language calls expeditions surveys. Its workers call them digs. Survivors inside the Stack call them raids.

The Estate has four faces:

- Shelter: recruits eat, heal, train, and bury their dead there.
- Office: missions are contracts written by people who rarely enter the Stack.
- Market: recovered relics become trinkets, medicines, and status goods.
- Debt engine: heroes are paid enough to return, rarely enough to leave.

Estate content should never make extraction feel consequence-free. Rewards can be real, but somebody pays.

### Survivor Enclaves

Enclaves are small groups inside or near the Stack. They may know routes, rituals, repairs, and old names better than the Estate. They are not automatically noble. Some trade people, hide infections, worship procedures, or sell false maps. Still, they are the main counterweight to Estate propaganda.

Use enclaves to create choices:

- Extract the item or repair the route.
- Kill the threat or learn why it guards the room.
- Take the heirloom or leave it as a seal.
- Report the enclave or hide it from the Estate.

## Factions

### Estate Survey Office

Public role: mission board, permits, maps, rewards.

True function: turns the Stack into property. It pays for archive pages, valve records, ash names, and proof that old claims can become new titles.

Visual language: stamps, brass tags, folded maps, sealed ledgers, numbered doors.

Good content uses:

- Mission objectives that sound official but have moral cost.
- Town events that demand quotas.
- Rewards that imply resale of recovered proof.

Bad content uses:

- Making the Office openly cartoon-evil.
- Giving it perfect knowledge of the Stack.

### Lamplighter Crews

Public role: route markers, torch supply, rescue signals.

True function: keep survey routes open long enough for extraction. Many Lamplighters are former debtors. They know the most about visible threats and alpha routes.

Visual language: white flares, waxed cloth, soot masks, signal bells, broken route icons.

Content hooks:

- Camp upgrades.
- Scout bonuses.
- Rescue events.
- Maps that reveal safe routes but expose enclaves.

### Archive Custodians

Public role: none. The Estate treats them as undead hazards.

True function: Stack maintenance bodies made from clerks, bailiffs, debtors, and preserved witnesses. Some are automatic. Some remember enough to suffer.

Visual language: vellum skin, bone clasps, red wax, ledger cords, stamped faces, rib shelves.

Content hooks:

- Weak points that disable procedures.
- Enemies that raise noise by "calling audit."
- Curios that ask for names instead of keys.

### Cistern Keepers

Public role: rumored drowned maintenance cults.

True function: descendants of workers who learned to survive by controlling water, salt, and pressure. They decide which routes flood and which enclaves drink.

Visual language: valve masks, salt-crusted robes, reed filters, pearl cysts, water bells.

Content hooks:

- Noncombat valve bargains.
- Water-route shortcuts.
- Disease cures with faction cost.
- Flooding as both hazard and defense.

### Ember Penitents

Public role: ash-mad cultists.

True function: people who believe burning records is the only way to free the dead from the Stack. Some are right. Some burn living witnesses too.

Visual language: kiln halos, glass scars, ash veils, white coal, fused prayer plates.

Content hooks:

- Repair versus purge objectives.
- Heat fatigue.
- Enemies that cauterize or vitrify.
- Trinkets with strong benefits and injury risk.

### Survivor Enclaves

Public role: squatters, scavengers, missing persons.

True function: alternate futures. They can become allies, casualties, informants, or enemies depending on player action.

Visual language: patched Stack materials, reused signs, quiet cooking fires, hand maps over official maps.

Content hooks:

- Faction meter.
- Debt-based rescue.
- Contradictory mission briefs.
- Local names for enemy types.

## Current Zone Identities

### Buried Archive

Core idea: dead records still enforcing living debt.

Primary materials: paper, wax, bone, vellum, black water, brass.

Architecture:

- Intake halls.
- Evidence wells.
- shelf corridors.
- misfiled morgues.
- debt chancels.
- boss gates treated as legal thresholds.

Threat fantasy:

- The Archive wants to know who entered, why, and what they owe.
- Enemies should feel like procedures with bodies attached.
- Weak points are record organs: crown, clasp, ledger, seal, chain, register.

Mission verbs:

- recover, redact, seal, audit, witness, extract, misfile, remand.

Avoid:

- generic library ghosts.
- too many book puns.
- making every enemy a scribe.

Sample names:

- Audit Hound.
- Vellum Leech.
- Staple Saint.
- Footnote Snare.
- Shelf Warden.
- Regent in Red.

Sample voice:

- "The shelves do not remember mercy. They remember order."
- "Every door here asks for a name. None ask permission."
- "The dead are filed cleanly. The living make a mess."

Sub-areas by tier:

- Tier I (Intake Branch): intake desks, debt chancels, scout-friendly shelf corridors.
- Tier II (Misfile Court): misfiled morgues, witness drawers, the Codex Reeve's audit floor.
- Tier III (Sealed Register): debt vaults, regent's gate, the Open Register weak-point chain.

### Salt Cistern

Core idea: water infrastructure as underworld border.

Primary materials: brine, salt, pearl, bronze valves, drowned cloth, black mold.

Architecture:

- pump forests.
- sluice walks.
- valve loops.
- drowned markets.
- filter shrines.
- submerged shortcuts.

Threat fantasy:

- The Cistern decides what gets preserved, diluted, or drowned.
- Enemies are waterlogged workers, pressure-grown parasites, and keepers of access.
- Salt can purify, preserve, or ruin.

Mission verbs:

- sound, drain, flood, filter, open, spare, drown, recover.

Avoid:

- pirate or sea-monster drift.
- making every enemy a fish.
- treating water as just blue floor damage.

Sample names:

- Valve Thrall.
- Brine Midwife.
- Sluice Eel.
- Salt Choir.
- Pearl Cyst.
- Depth Bailiff.

Sample voice:

- "The water is older than the claim. It does not recognize the seal."
- "The valves turn like throats swallowing names."
- "Salt keeps what rot would have taken."

Sub-areas by tier:

- Tier I (Pump Forest): pump halls, sluice walks, scoutable valve loops.
- Tier II (Drowned Market): submerged enclave streets, brine intakes, the Pearl Choir's cyst chamber.
- Tier III (Deep Sluice): bell diver gate, flood-toll, the Bell Lung weak-point chain.

### Ember Warrens

Core idea: purification as violence.

Primary materials: ash, glass, clinker, white coal, fired clay, burned silk.

Architecture:

- kiln naves.
- bellows spines.
- ash confessionals.
- vitrified dormitories.
- fuel branches.
- furnace gates.

Threat fantasy:

- The Warrens burn records to free or erase the dead.
- Enemies are penitents, kiln workers, fused saints, and heat-shaped maintenance bodies.
- Fire is not evil by default. It can release what the Archive traps.

Mission verbs:

- douse, anoint, burn, carry, quench, vitrify, spare, purge.

Avoid:

- generic lava dungeon.
- fire cult stereotypes without practical motives.
- making heat only a damage number.

Sample names:

- Kiln Nurse.
- Glass Penitent.
- Ash Wasp Cloud.
- Bellows Acolyte.
- Clinker Butcher.
- White Furnace.

Sample voice:

- "The ash remembers less, and that may be mercy."
- "These fires were built to cleanse records. They learned to cleanse witnesses."
- "Glass keeps the shape and loses the life."

Sub-areas by tier:

- Tier I (Fuel Branch): kiln naves, bellows spines, scoutable fuel stores.
- Tier II (Vitrified Cloister): glass dormitories, ash confessionals, the Kiln Vicar's vitrifying procession.
- Tier III (White Furnace): furnace gate, prioress chamber, the Halo Vent weak-point chain.

## Mechanics-To-Lore Mapping

- AP: attention, breath, and authorization. Spending AP means forcing a body or tool through a procedure before the room completes its own.
- Movement: trespass path. A route is never just distance; it crosses claims, witness lanes, pressure seams, heat, water, and sight.
- Rotation: survey angle. Rotating the room exposes official marks, rear seals, cover faces, hidden lines, and sight gaps.
- Line of sight: recognition. If a procedure can see and name a target, it can act on that target.
- Cover: contested authority. Desks, shelves, valve blocks, barricades, bodies, and mobile shields interrupt recognition.
- Flanking: invalidated protection. A unit is flanked when its chosen authority is no longer between it and the claimant.
- Enemy intent: posted notice. The Stack and its factions declare many actions before resolving them. The horror is seeing the harm scheduled.
- Partial intent: redacted notice. Elites and bosses can hide exact footprints, but must show enough category information for planning.
- Push/pull/swap: misfiling bodies. Movement effects are not physics jokes; they are the party exploiting procedures and sight lines.
- Destructible terrain: broken record media. Destroying cover, floors, valves, shelves, or kilns changes what the room can prove.
- Hazards: active clauses. Flood, ash, heat, falling shelves, audit beams, and pressure lanes are tile rules with visible timing.
- Overwatch/threat zones: pending inspection. A watched tile is a place where movement becomes testimony.
- Objectives: people and machinery the Estate wants classified. Protecting both squad and objective creates the moral bind.
- Injuries: run-long constraints. They should change movement, AP, cover use, LoS, or loadout handling without stealing random turns.
- Loot capacity: extraction limit. Taking proof competes with rescue, repair, and tactical positioning.
- Dread: the Estate and Stack both worsening because of failed, greedy, or destructive boards.
- Renown: proof that the Estate can sell competence.

## Hero Class Hooks

### Warden

A former route guard or debt enforcer. Believes lines matter because people die when lines break.

Tactical angle: mobile cover, brace, shove, shield-line denial, and objective blocking. Strongest tension with Estate orders; may protect survivors even while serving survey contracts.

### Duelist

A paid blade from Estate patron circles or a debtor trained for spectacle.

Tactical angle: flank conversion, dash strikes, position swaps, and single-target repositioning. Treats the Stack as a stage until injuries make it personal.

### Apothecary

Field herbalist trained on salvage crews, more practical than holy. Carries tinctures, triage tools, and a working knowledge of which salts keep flesh from rotting.

Tactical angle: area stabilizers, smoke, cleanse hazards, rescue objectives, and controlled debuffs. Sees bodies as patients first and records second.

### Arcanist

Interpreter of old Stack signs, half scholar and half liability.

Tactical angle: LoS bending, reveal marks, intent disruption, seal reading, and tile permission tricks. Understands enough procedures to exploit them and enough to fear them.

### Thief

Scout, poacher, courier, and route thief. Has lifted from Estate caravans and Stack curios with equal patience.

Tactical angle: stealth lanes, trap disarm, hidden-tile reveal, objective extraction, and escape routes. Least loyal to official maps.

### Chirurgeon

Estate-trained wound specialist who knows preservation methods came from the Stack.

Tactical angle: repair bodies and machinery, stabilize injuries, convert wounds into predictable constraints, and keep objectives functioning. Most body-horror aware.

### Exile

Former enclave member, criminal, deserter, or failed surveyor.

Tactical angle: terrain break, throw, slam, hazard immunity pockets, and self-risk AP spikes. Gives the party a non-Estate view without making that view pure.

### Lamplighter

Route worker from the crews who keep expeditions possible.

Tactical angle: reveal, overwatch cones, light authority, route beacons, and hidden-intent reduction. Knows light is both comfort and signal.

### Merchant

Itinerant ledger-keeper contracted by the Estate to weigh, tally, and witness on the field. Carries scales, sealed coin, and the writ that lets the party draw against future salvage.

Tactical angle: objective insurance, debt trades, salvage drones, risk conversion, and delayed payment mechanics. The only class that profits as dread rises; turns mercy, salvage, and triage into transactions the party can refuse but rarely afford to.

## Enemy Design Rules

- Give every enemy a job in the place.
- Prefer two readable mechanics over four vague ones.
- Every enemy needs a board verb: move, shoot, push, pull, block, repair, summon, overwrite, reveal, hide, burn, flood, seal, or destroy.
- Basic enemies should show exact intent tiles.
- Elites may show partial intent, but their category must be clear.
- Bosses can rotate intent masks, alter terrain, expose weak points by angle, and threaten objectives across multiple turns.
- Elite parts should map to board functions by fiction: bell lung, ledger hand, crown seal, halo vent, valve throat.
- Swarms should threaten objectives, cover, LoS, AP tax, or extraction routes more than raw HP.
- Guards should alter targeting, cover, movement lanes, or route access.
- Casters should produce stress or redacted intent for legible reasons: audit call, hymn, pressure chant, bell note, furnace litany.
- Trappers should move units, mark tiles, bind AP, or create injury risk.
- Alphas should be visible on the run map or board before they force a fight.
- Bosses should embody the zone procedure, not just be larger enemies.

## Curio Design Rules

Each curio becomes either an interactable tile, objective anchor, hazard source, or destructible board object. Each needs:

- Surface read: what the player sees.
- Old function: what it was built to do.
- Safe use: AP/item/class-aware path.
- Greedy use: better loot or faster objective with higher board cost.
- Repair use: lower dread or faction gain with lower loot.
- Leave option: valid when supplies are low.
- Board consequence: cover, LoS, hazard, objective, spawn, intent, or extraction effect.

Good curio question:

- "Do we take the record, fix the machine, move the body, or leave the dead named?"

Bad curio question:

- "Click for random reward or damage."

## Mission Design Rules

Mission names should sound like Estate paperwork with dread underneath.

Good patterns:

- Scout the [place].
- Recover [record/object].
- Open [infrastructure].
- Silence [official title].
- Carry Out [dead/record].
- Douse [ritual object].
- Spare [people/system].

Mission outcomes should increasingly support:

- Extraction: more gold, heirlooms, trinkets, Estate favor, possible dread.
- Repair: less loot, lower dread, enclave favor, safer future routes.
- Abandonment: immediate survival, dread increase, possible town pressure.

Mission boards should be built around one main tactical question:

- Which objective can we afford to lose?
- Which attack must be redirected instead of stopped?
- Which cover must be destroyed now to survive later?
- Which hidden line appears only after rotation?
- Which enemy must live because killing it opens a worse route?
- Which unit extracts while the others hold the room?

Bad mission board:

- Empty floor, scattered enemies, no objective pressure, and damage as the only answer.

## Narration Voice

Voice should be terse, concrete, and morally aware.

Rules:

- One image per line.
- Prefer verbs over adjectives.
- No lore lectures in combat.
- No jokes in danger beats.
- Avoid "madness" as a catch-all.
- Let the Estate sound procedural.
- Let the Stack sound indifferent.
- Let survivors sound practical.

Good:

- "The gate counts them twice and welcomes neither count."
- "The wound is clean. That is not comfort."
- "The water gives back the boot, not the foot."

Bad:

- "The cosmic madness of the cursed archive overwhelms their minds."
- "This spooky library is full of evil books."
- "The heroes bravely save the day."

## Naming Guide

Use:

- office terms: audit, claim, seal, writ, docket, remand, witness, register.
- body terms: rib, lung, nerve, marrow, tendon, tooth, eye, skin.
- infrastructure terms: valve, sluice, pump, kiln, bellows, intake, gutter.
- material terms: salt, wax, ash, glass, vellum, clinker, brass, pearl.

Avoid:

- direct myth names for bosses unless heavily transformed.
- common fantasy filler like shadow, doom, blood, cursed, ancient, dark.
- too many nouns stacked without function.
- names that sound like parodies.

## UI And Player-Facing Copy

The UI should stay operational. It can imply lore without explaining it.

Examples:

- "repair route" instead of "good choice."
- "extract proof" instead of "loot item."
- "noise rising" instead of "random encounter chance increased."
- "alpha sighted" instead of "rare monster spawned."
- "injury: glass scarring" instead of "permanent mutilation."

Tooltips can be blunt:

- "Scouted rooms reduce ambush pressure."
- "Repair rewards less coin and lowers dread."
- "Alpha threats persist until defeated or avoided."

## Campaign Arc

Roguelite campaign spine:

1. The Estate selects a survey route and squad from incomplete intelligence.
2. Each board is a room-procedure with declared threats, objectives, and destructible record media.
3. Between boards, the player chooses routes, repairs, extractions, enclave bargains, and loadout changes.
4. The Buried Archive teaches names, cover, claims, hidden angles, and audit intent.
5. The Salt Cistern adds water pressure, floods, valves, moving cover, and route machinery.
6. The Ember Warrens adds fire, ash, glass, terrain conversion, and purge/repair choices.
7. Boss boards ask whether the player can preserve both people and procedure under visible pressure.
8. Final pressure asks whether the Estate seals the Stack for ownership, repairs selected systems, or keeps extracting until collapse.

Possible endings later:

- Estate Seal: bosses defeated, high renown, unresolved survivor cost.
- Repair Compact: enough repair choices and enclave favor, lower wealth, safer routes.
- Extraction Collapse: high dread or excessive deaths, Estate consumed by its own survey routes.
- Quiet Failure: week limit or debt pressure ends the campaign without a final confrontation.

## Campaign Pressure (Weeks And Dread)

The roguelite campaign uses readable timers and route pressure. Either reaching cap can end or warp the run.

- Week timer: hard cap of route cycles. Each board or route node advances time. Reaching the cap forces a final reckoning whether or not the player feels ready.
- Dread timer: rises with greedy extraction, objective loss, hero death, destructive board solutions, enclave betrayal, and certain events. Falls with repair objectives, clean extractions, enclave compacts, and quiet routes.
- Exposure: local board pressure. Exposure rises from noise, visible trespass, broken seals, failed stealth, and redacted intent. It should affect reinforcements and future board modifiers.
- Integrity: objective health for machinery, enclaves, civilians, route seals, or archive records. Integrity is the main non-squad failure pressure.

End conditions:

- Estate Seal: all three zone bosses defeated before either cap. Final mission unlocks; ending tier depends on dread.
- Repair Compact: dread stays low and enclave favor stays high. Final mission shifts to a repair objective.
- Extraction Collapse: dread reaches cap. Estate is consumed by its own routes; party may attempt one last escape mission.
- Quiet Failure: week cap reached without all bosses sealed. Campaign ends with the Stack growing beyond the Estate.

Pacing rules:

- The two timers should never both be hidden. At least one is always shown blunt in the UI.
- Late weeks should add board modifiers, not longer boards. Pressure is the cheap way to escalate.
- Dread should sometimes drop. A timer that only rises is a punishment timer, not a pressure timer.
- A 2-4 hour run should land near 8-12 boards including a finale. Pad with route choices and events, not longer rooms.

## Zone Sub-Tiers

Each zone deepens across the run rather than just swapping for a new tileset.

- Tier I: readable boards. Exact intents, basic cover, one objective, limited destructible terrain.
- Tier II: pressure boards. Partial intents, active hazards, multiple objectives, route machinery, enclave requests.
- Tier III: boss-route boards. Staged intents, rotating weak points, terrain conversion, hidden angle information, high objective pressure.

Tier transitions should be diegetic. The Stack has noticed the party. The route changes.

## Mini-Boss Wardens

Each zone has one mini-boss warden between normal boards and the final boss. They are visible alphas first. The party should see their board rule before fighting them.

- Buried Archive: Codex Reeve. Posts audit lines that disable AP on marked tiles unless the Open Register is broken.
- Salt Cistern: Pearl Choir. Refloods drained lanes and turns low ground into hostile movement unless choir throats are silenced.
- Ember Warrens: Kiln Vicar. Vitrifies the most exposed unit or objective unless halo vents are doused or line of sight is broken.

Wardens are not zone bosses. They guard a route or a record, not the procedure. Defeating one should change the zone's behavior, not end it.

## Estate Fixtures

A few named recurring figures give the Estate a face. Keep them procedural-cold, not warm. They speak the office's language. They sometimes lie by omission.

- The Surveyor: head of the Estate Survey Office. Signs contracts, sets quotas, refuses to enter the Stack. Speaks in survey verbs.
- Foreman Ott: chief of the Lamplighter crews. Former debtor. Knows which routes still kill. The only fixture who has seen the inside.
- Chirurgeon Major Vell: head of the infirmary. Knows which preservation techniques the Estate copied from the Stack and which it pretends it invented.
- Clerk of Debts: a position, not a person. Whoever holds it carries the seal. Tracks hero pay, contracts, and graveyard fees.
- Stage Master: runs the recruitment coach. Decides which survivors get screened in. Has quiet opinions about the Estate.
- Vault Keeper: handles heirloom trade and trinket appraisal. Treats every relic as evidence first, value second.

Fixture content should never explain everything. They should be useful, partial, and have their own quiet stakes.

## Enclave Leaders

One or two named enclave leaders per zone. They are not noble. They have already made compromises to keep their people alive.

### Buried Archive

- Page-Keeper Ilse: lives among shelves, knows which names unlock which doors. Will trade a route for a record left intact.
- Bound Scribe Cael: sutured to a ledger but still talks. Half-Custodian; useful, dangerous, possibly already lost.

### Salt Cistern

- Valve-Mother Tov: decides who drinks. Can flood a route or spare an enclave. Wants a child returned from a drowned market.
- Pressure Father Sett: former Estate dredger who defected after the Brine Midwives took his crew. Knows shortcut valves.

### Ember Warrens

- Ash Vicar Mira: believes purging frees the dead. Will help the party burn a record if it frees a name.
- Glass-Burnt Aron: skeptic; thinks the kilns lie. Wants the fires doused, even if it traps the dead.

Leaders should give the party choices the Estate would not offer.

## Found Documents And Lore Fragments

Lore reaches the player as found documents, not exposition. Documents stack in the Estate journal across runs.

Document types:

- Writ fragments: half-burned legal text. Reveal who owes what to whom, and what the Stack thinks "owe" means.
- Valve schematics: pressure diagrams. Reveal which routes flood, drain, or seal under load.
- Penitent confessions: ash-marked clay. Reveal which dead the kilns burned to free, and which they burned to hide.
- Intake colophons: stamped labels. Reveal what a room was used for before the Stack absorbed it.
- Survivor pages: hand-written. The only documents with proper names that are not Estate property.

Rules:

- One image per fragment. No lecture pages.
- Fragments should never be the only source of a mechanical fact. The mechanics teach themselves; documents add motive.
- Every fragment names a place, a person, or a procedure. None name three.

## Trinket Sets

Trinkets cluster into named sets. Wearing multiple from a set unlocks a small set bonus and a small set cost.

- Page-Keeper's Vow (Archive): scouting and weak-point bonus; stress vulnerability cost.
- Salt-Born Compact (Cistern): blight resist and rank-movement bonus; speed penalty.
- Vow of Cinders (Warrens): heat resist and burn damage bonus; morale penalty.
- Lamplighter's Token (Estate): torch efficiency and ambush resist; combat damage penalty.
- Debt-Clerk's Seal (Estate): rewards bonus; injury vulnerability cost.

Set design rules:

- Two-piece bonus should be readable; four-piece bonus should change one decision per fight.
- Set costs should never silently disable a class identity. They sting; they do not break.
- Sets should imply a faction or a place. Naming should never be generic stat words.

## Town Pressure And Faction States

Estate weeks should feel like attended time, not menu time.

- Weekly events should imply that the Estate runs without the party. Quotas rise. Survivors arrive. Bills come.
- Faction state should be visible: Custodians (Archive), Cistern Keepers, Ember Penitents, Lamplighters, Survey Office, and Survivor Enclaves.
- Faction meters move on mission result, not on dialogue. The party's behavior in the Stack is the conversation.
- Hostile faction state should produce concrete hazards in the field, not just a price hike: a Lamplighter strike that delays torch resupply, an Ember Penitent rite that raises heat fatigue, an Enclave embargo that closes a known route.

States should be reversible up to a threshold. Past the threshold, they should not be.

## Recruit Origins

When a hero arrives by stagecoach, they should imply a previous job, not a class fantasy.

- Warden: route guard discharged after a survey went bad.
- Duelist: paid blade from a patron circle; lost the patron.
- Apothecary: salvage-crew medic, recovered from disease.
- Arcanist: scribe who read too far and was sent up for air.
- Thief: poacher caught moving across Estate maps.
- Chirurgeon: infirmary apprentice who copied the wrong technique.
- Exile: enclave member sold for a route.
- Lamplighter: crew worker whose lamp finally paid out.
- Merchant: field accountant bought into Estate service after the last Survey ledger-keeper did not return.

Origin should be visible in one bark on arrival and one bark on first death. Nothing more.

## Content Acceptance Standard

New content fits if it answers these:

- What procedure or survival need created this?
- What does the Estate want from it?
- Who gets hurt if the party extracts it?
- What does repair cost?
- What does the player learn before danger triggers?
- How does the mechanic stay deterministic and readable?

If a content idea only sounds cool but has no role in place, cut it.

## Content Acceptance Standard v2

Use this stricter gate for the tactical pivot.

- It is deterministic after board load.
- It is previewable before commitment.
- It changes movement, position, cover, LoS, terrain, objective state, or future intent; pure number tuning is not enough.
- It has at least one counterplay path that does not require killing the source.
- It creates a squad/objective/route/resource tradeoff when possible.
- It has a Thoth explanation in procedural language, not source-game language.
- It has UI language short enough for a tile inspector.
- It has at least one replay fixture or fixed-seed validation case.
- It has a web-researched source pattern and a documented Thoth transformation when inspired by another game.

Cut it if:

- It adds hidden randomness to tactical resolution.
- It cannot be displayed clearly in all four rotations.
- It makes damage the only good answer.
- It copies a reference game's identity, fiction, or exact ability loop.
