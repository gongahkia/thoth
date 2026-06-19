# Thoth Content Todo

Loose Markdown backlog. Task lines keep todo-ish metadata for search/filter use.

## Global Content Rules

- [ ] (A) Define registry naming prefixes for Great Stack content +ContentBacklog @registry type:convention zone:global
- [ ] (A) Add content-review checklist that flags direct source cloning +ContentBacklog @docs type:review zone:global
- [ ] (A) Add gore ceiling notes for readable body horror copy +ContentBacklog @docs type:tone zone:global
- [ ] (A) Add item taxonomy for salvage, medicine, light, keys, and ritual reagents +ContentBacklog @registry type:item_taxonomy zone:global
- [ ] (B) Add enemy role taxonomy for scout, guard, caster, trapper, swarm, elite, support, alpha, boss +ContentBacklog @registry type:enemy_taxonomy zone:global
- [ ] (B) Add mission-tag taxonomy for survey, extract, repair, seal, rescue, cleanse, activate, boss +ContentBacklog @registry type:mission_taxonomy zone:global
- [ ] (B) Add curio outcome taxonomy for safe_use, greedy_use, repair_use, and leave_alone +ContentBacklog @registry type:curio_taxonomy zone:global
- [ ] (C) Add internal content IDs to narration lines for future localization +ContentBacklog @narration type:localization zone:global

## Buried Archive

- [ ] (A) Add archive room template called intake_desk with blocked sightlines and one visible threat anchor +BuriedArchive @worldgen type:room zone:buried_archive id:intake_desk
- [ ] (A) Add archive room template called debt_chancel with loop exit and stress curio +BuriedArchive @worldgen type:room zone:buried_archive id:debt_chancel
- [ ] (A) Add archive room template called misfiled_morgue with elite weak-point anchor +BuriedArchive @worldgen type:room zone:buried_archive id:misfiled_morgue
- [ ] (A) Add archive room template called evidence_well as optional reward dead-end +BuriedArchive @worldgen type:room zone:buried_archive id:evidence_well
- [ ] (B) Add archive corridor role called audit_lane with noise gain on backtracking +BuriedArchive @simulation type:corridor zone:buried_archive id:audit_lane
- [ ] (B) Add archive corridor role called shelf_crawl that bypasses a guard but costs torch +BuriedArchive @simulation type:corridor zone:buried_archive id:shelf_crawl
- [ ] (A) Add mission Recover Sealed Names with gather objective and extraction choice +BuriedArchive @registry type:mission zone:buried_archive id:archive_names
- [ ] (A) Add mission Burn the False Index with activation objective and dread tradeoff +BuriedArchive @registry type:mission zone:buried_archive id:archive_false_index
- [ ] (B) Add mission Escort the Page-Bearer with fragile NPC cargo represented as quest item +BuriedArchive @registry type:mission zone:buried_archive id:archive_page_bearer
- [ ] (B) Add mission Map the Intake Branch with required scout rooms and no boss gate +BuriedArchive @registry type:mission zone:buried_archive id:archive_intake_map
- [ ] (A) Add enemy Audit Hound as scout/pursuer that raises noise +BuriedArchive @registry type:enemy zone:buried_archive id:audit_hound
- [ ] (A) Add enemy Vellum Leech as back-rank stress caster and bleed source +BuriedArchive @registry type:enemy zone:buried_archive id:vellum_leech
- [ ] (A) Add enemy Staple Saint as armor guard that protects adjacent ranks +BuriedArchive @registry type:enemy zone:buried_archive id:staple_saint
- [ ] (A) Add enemy Footnote Snare as trapper that pulls marked heroes +BuriedArchive @registry type:enemy zone:buried_archive id:footnote_snare
- [ ] (B) Add enemy Errata Twins as two-body swarm with shared support behavior +BuriedArchive @registry type:enemy zone:buried_archive id:errata_twins
- [ ] (B) Add enemy Shelf Warden as visible alpha with pursuit pressure +BuriedArchive @registry type:enemy zone:buried_archive id:shelf_warden
- [ ] (A) Add elite Index Ossuary weak points named Open Register and Rib Clasps +BuriedArchive @combat type:weak_point zone:buried_archive id:index_ossuary_parts
- [ ] (A) Add boss variant Regent in Red with weak point that disables party stress skill +BuriedArchive @combat type:boss_variant zone:buried_archive id:regent_red
- [ ] (B) Add curio Witness Drawer with skeleton_key safe use and stress on greedy use +BuriedArchive @registry type:curio zone:buried_archive id:witness_drawer
- [ ] (B) Add curio Clerk Cocoon with bandage safe use and injury on failure +BuriedArchive @registry type:curio zone:buried_archive id:clerk_cocoon
- [ ] (B) Add curio Name Press with repair option that lowers dread but pays no loot +BuriedArchive @registry type:curio zone:buried_archive id:name_press
- [ ] (C) Add trinket Wax Seal of Remand for scout bonus and stress penalty +BuriedArchive @registry type:trinket zone:buried_archive id:wax_seal_remand
- [ ] (C) Add trinket Copper Folio Hook for weak-point damage and bleed risk +BuriedArchive @registry type:trinket zone:buried_archive id:copper_folio_hook
- [ ] (A) Add narration bank for archive visible threats, scouting, and weak-point breaks +BuriedArchive @narration type:voice zone:buried_archive id:archive_voice_v2

## Salt Cistern

- [ ] (A) Add cistern layout grammar with pump hub, valve loop, drowned shortcut, and sluice boss gate +SaltCistern @worldgen type:layout zone:salt_cistern id:cistern_grammar_v1
- [ ] (A) Add cistern room template called pump_forest with column cover and long sightline +SaltCistern @worldgen type:room zone:salt_cistern id:pump_forest
- [ ] (A) Add cistern room template called brine_intake with water hazard and visible alpha anchor +SaltCistern @worldgen type:room zone:salt_cistern id:brine_intake
- [ ] (B) Add cistern room template called drowned_market with survivor trace and reward curio +SaltCistern @worldgen type:room zone:salt_cistern id:drowned_market
- [ ] (B) Add cistern corridor role called pressure_walk that may flood after valve use +SaltCistern @simulation type:corridor zone:salt_cistern id:pressure_walk
- [ ] (B) Add cistern corridor role called maintenance_siphon that shortcuts at disease risk +SaltCistern @simulation type:corridor zone:salt_cistern id:maintenance_siphon
- [ ] (A) Add mission Bleed the Low Reservoir with valve activations and rising ambush odds +SaltCistern @registry type:mission zone:salt_cistern id:cistern_low_reservoir
- [ ] (A) Add mission Recover the Salt Register with gather objective behind flood route +SaltCistern @registry type:mission zone:salt_cistern id:cistern_salt_register
- [ ] (B) Add mission Spare the Gatekeepers with noncombat repair objective +SaltCistern @registry type:mission zone:salt_cistern id:cistern_gatekeepers
- [ ] (A) Add enemy Valve Thrall as armor guard that punishes front ranks +SaltCistern @registry type:enemy zone:salt_cistern id:valve_thrall
- [ ] (A) Add enemy Brine Midwife as stress caster and disease vector +SaltCistern @registry type:enemy zone:salt_cistern id:brine_midwife
- [ ] (A) Add enemy Sluice Eel as scout/pursuer that prefers marked back ranks +SaltCistern @registry type:enemy zone:salt_cistern id:sluice_eel
- [ ] (B) Add enemy Salt Choir as support that heals or buffs drowned units +SaltCistern @registry type:enemy zone:salt_cistern id:salt_choir
- [ ] (B) Add enemy Pearl Cyst as trapper that dazes and creates injury chance +SaltCistern @registry type:enemy zone:salt_cistern id:pearl_cyst
- [ ] (B) Add enemy Depth Bailiff as rare alpha guarding shortcuts +SaltCistern @registry type:enemy zone:salt_cistern id:depth_bailiff
- [ ] (A) Add boss variant Bell Diver Flood-Toll with weak point Bell Lung +SaltCistern @combat type:boss_variant zone:salt_cistern id:bell_diver_flood_toll
- [ ] (B) Add curio Shutoff Shrine with valve_key safe use and party stress heal +SaltCistern @registry type:curio zone:salt_cistern id:shutoff_shrine
- [ ] (B) Add curio Silted Cradle with salve safe use and brine_rot failure +SaltCistern @registry type:curio zone:salt_cistern id:silted_cradle
- [ ] (C) Add trinket Filtered Tooth for blight resist and speed penalty +SaltCistern @registry type:trinket zone:salt_cistern id:filtered_tooth
- [ ] (A) Add narration bank for valves, rising water, drowned bargains, and flood retreat +SaltCistern @narration type:voice zone:salt_cistern id:cistern_voice_v2

## Ember Warrens

- [ ] (A) Add warrens layout grammar with kiln nave, ash bypass, fuel branch, penitent loop, and furnace boss gate +EmberWarrens @worldgen type:layout zone:ember_warrens id:ember_grammar_v1
- [ ] (A) Add warrens room template called kiln_nave with heat hazard and central curio +EmberWarrens @worldgen type:room zone:ember_warrens id:kiln_nave
- [ ] (A) Add warrens room template called vitrified_dormitory with injury trap and reward cache +EmberWarrens @worldgen type:room zone:ember_warrens id:vitrified_dormitory
- [ ] (B) Add warrens room template called ash_confessional with stress tradeoff and repair objective +EmberWarrens @worldgen type:room zone:ember_warrens id:ash_confessional
- [ ] (B) Add warrens corridor role called clinker_run that costs light but avoids combat +EmberWarrens @simulation type:corridor zone:ember_warrens id:clinker_run
- [ ] (B) Add warrens corridor role called bellows_spine that increases heat fatigue after backtracking +EmberWarrens @simulation type:corridor zone:ember_warrens id:bellows_spine
- [ ] (A) Add mission Douse the Vow Kilns with ember_oil objective inversion and dread choice +EmberWarrens @registry type:mission zone:ember_warrens id:ember_vow_kilns
- [ ] (A) Add mission Carry Out the Ash Names with gather objective and pack pressure +EmberWarrens @registry type:mission zone:ember_warrens id:ember_ash_names
- [ ] (B) Add mission Spare the Warm Dead with repair objective and lower loot +EmberWarrens @registry type:mission zone:ember_warrens id:ember_warm_dead
- [ ] (A) Add enemy Kiln Nurse as support that cauterizes enemies and burns heroes +EmberWarrens @registry type:enemy zone:ember_warrens id:kiln_nurse
- [ ] (A) Add enemy Glass Penitent as armor guard with reflect-style chip damage +EmberWarrens @registry type:enemy zone:ember_warrens id:glass_penitent
- [ ] (A) Add enemy Ash Wasp Cloud as swarm that pressures torch and back ranks +EmberWarrens @registry type:enemy zone:ember_warrens id:ash_wasp_cloud
- [ ] (B) Add enemy Bellows Acolyte as stress caster that scales with low torch +EmberWarrens @registry type:enemy zone:ember_warrens id:bellows_acolyte
- [ ] (B) Add enemy Clinker Butcher as trapper that causes cracked_ribs injury chance +EmberWarrens @registry type:enemy zone:ember_warrens id:clinker_butcher
- [ ] (B) Add enemy White Furnace as rare alpha that blocks repair routes +EmberWarrens @registry type:enemy zone:ember_warrens id:white_furnace
- [ ] (A) Add boss variant Cinder Prioress Glass-Crowned with weak point Halo Vent +EmberWarrens @combat type:boss_variant zone:ember_warrens id:prioress_glass
- [ ] (B) Add curio Ash Lung Reliquary with laudanum safe use and stress-risk greedy use +EmberWarrens @registry type:curio zone:ember_warrens id:ash_lung_reliquary
- [ ] (B) Add curio Fuse Saint with ward_charm repair use and ember_fever failure +EmberWarrens @registry type:curio zone:ember_warrens id:fuse_saint
- [ ] (C) Add trinket Cinder Lens for stress damage and injury vulnerability +EmberWarrens @registry type:trinket zone:ember_warrens id:cinder_lens
- [ ] (A) Add narration bank for heat fatigue, kiln rites, vitrified enemies, and ash retreat +EmberWarrens @narration type:voice zone:ember_warrens id:ember_voice_v2

## Estate And Campaign

- [ ] (A) Add Estate Survey Office building copy that frames expeditions as paid salvage +Estate @ui type:copy zone:estate id:survey_office_copy
- [ ] (A) Add campaign pressure event where Estate demands deeper extraction after failures +Estate @registry type:town_event zone:estate id:survey_quota
- [ ] (A) Add campaign pressure event where survivor enclave asks party to repair instead of loot +Estate @registry type:town_event zone:estate id:enclave_petition
- [ ] (B) Add town event Archive Tithe that trades heirlooms for reduced dread +Estate @registry type:town_event zone:estate id:archive_tithe_v2
- [ ] (B) Add town event Salt Rationing that changes provision prices for cistern week +Estate @registry type:town_event zone:estate id:salt_rationing
- [ ] (B) Add town event Ash Vigil Demand that increases stress recovery cost but lowers dread +Estate @registry type:town_event zone:estate id:ash_vigil_demand
- [ ] (A) Add survivor enclave faction meter with neutral, indebted, and hostile states +Estate @simulation type:faction zone:estate id:enclave_meter
- [ ] (B) Add repair-versus-extract mission result flag to campaign progress +Estate @simulation type:campaign_flag zone:estate id:repair_extract
- [ ] (B) Add class origin copy for Warden, Duelist, Mender, Arcanist, Harrier, Chirurgeon, Exile, Lamplighter +Estate @registry type:class_lore zone:estate id:class_origins
- [ ] (C) Add recruit barks that reveal class attitude toward the Great Stack +Estate @narration type:bark zone:estate id:recruit_barks
- [ ] (C) Add graveyard epitaph templates tied to zone and injury source +Estate @narration type:epitaph zone:estate id:zone_epitaphs

## Exploration And Encounters

- [ ] (A) Add visible threat behavior table for idle, stalk, guard, flee, and call_help +Encounter @simulation type:threat_ai zone:global id:visible_threat_behaviors
- [ ] (A) Add alpha threat rule that creates a persistent map marker after first sighting +Encounter @simulation type:alpha zone:global id:alpha_marker
- [ ] (A) Add scouted-room modifier text for ambush odds and visible threat preview +Encounter @ui type:tooltip zone:global id:scout_odds_tooltip
- [ ] (B) Add stealth approach command that spends torch to reduce visible threat opening advantage +Encounter @input type:command zone:global id:stealth_approach
- [ ] (B) Add bait provision item that can lure one visible threat from a required route +Encounter @registry type:item zone:global id:bait_chime
- [ ] (B) Add noise decay on camp and high torch so pressure is readable +Encounter @simulation type:pressure zone:global id:noise_decay
- [ ] (A) Add injury definitions for crushed_hand, salt_bloat, glass_scarring, and nerve_burn +Encounter @registry type:injury zone:global id:injury_v2
- [ ] (B) Add injury cure copy to provision tooltips for bandage, salve, laudanum, ward_charm +Encounter @ui type:tooltip zone:global id:injury_cure_tooltips
- [ ] (A) Add weak-point label copy that states disabled skill in combat log +Encounter @combat type:weak_point zone:global id:part_disable_log
- [ ] (B) Add enemy support action that restores a disabled weak point once per elite fight +Encounter @combat type:support_skill zone:global id:part_repair_skill
- [ ] (B) Add combat reward bump for defeating alpha threats without retreat +Encounter @simulation type:reward zone:global id:alpha_reward
- [ ] (C) Add defeat recovery event where survivors retrieve one fallen trinket for a debt +Encounter @simulation type:recovery zone:global id:survivor_trinket_debt

## Narrative And UI Text

- [ ] (A) Add mission intro text field with one-line operational brief and one-line moral sting +Narrative @registry type:mission_copy zone:global id:mission_intro
- [ ] (A) Add curio copy field with observe, safe_use, greedy_use, repair_use, and result text +Narrative @registry type:curio_copy zone:global id:curio_copy_fields
- [ ] (A) Add enemy bestiary copy field with behavior hint and weak-point hint +Narrative @registry type:bestiary zone:global id:bestiary_fields
- [ ] (B) Add location loading barks for Archive, Cistern, Warrens, and Estate +Narrative @narration type:loading_bark zone:global id:location_barks
- [ ] (B) Add low-torch voice lines that differ by current zone +Narrative @narration type:voice zone:global id:low_torch_zone_voice
- [ ] (B) Add camp voice lines that reveal party complicity rather than pure relief +Narrative @narration type:voice zone:global id:camp_complicity_voice
- [ ] (B) Add victory voice lines that distinguish extraction, repair, and boss sealing +Narrative @narration type:voice zone:global id:victory_result_voice
- [ ] (C) Add short UI glossary for dread, noise, injury, alpha, repair, extraction +Narrative @ui type:glossary zone:global id:terms_v1
- [ ] (C) Add estate panel copy for faction debt and survivor enclave status +Narrative @ui type:panel_copy zone:estate id:faction_panel_copy

## Tests And Validation

- [ ] (A) Add registry tests for new content IDs, enemy skills, part locks, mission rewards, and curio items +Tests @test type:registry zone:global id:content_registry_tests
- [ ] (A) Add deterministic layout tests for Salt Cistern and Ember Warrens generated grammars +Tests @test type:worldgen zone:global id:layout_grammar_tests
- [ ] (A) Add encounter tests for visible threat behaviors and alpha persistence +Tests @test type:encounter zone:global id:visible_threat_tests
- [ ] (A) Add weak-point tests for part repair, disabled skill lock, and combat log text +Tests @test type:combat zone:global id:weak_point_v2_tests
- [ ] (A) Add injury tests for new injuries, provision clears, camp clears, and estate recovery clears +Tests @test type:injury zone:global id:injury_v2_tests
- [ ] (B) Add mission-result tests for extraction versus repair campaign flags +Tests @test type:campaign zone:global id:repair_extract_tests
- [ ] (B) Add narration tests that every new event key has at least two lines +Tests @test type:narration zone:global id:narration_coverage_tests
- [ ] (B) Add balance smoke test that alpha encounter reward does not exceed boss reward +Tests @test type:balance zone:global id:alpha_reward_balance
- [ ] (C) Add docs lint that confirms TODO-CONTENT task lines include +Project and @context metadata +Tests @test type:docs zone:global id:todo_content_lint
