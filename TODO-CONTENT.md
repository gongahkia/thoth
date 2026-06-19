# Thoth Content Todo

Loose Markdown backlog. Task lines keep todo-ish metadata for search/filter use.

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
- [ ] (A) Add timer panel copy that shows week countdown and dread bar in blunt language +Narrative @ui type:panel_copy zone:estate id:timer_panel_copy
- [ ] (B) Add ending screen copy for Estate Seal, Repair Compact, Extraction Collapse, and Quiet Failure +Narrative @ui type:ending_copy zone:estate id:ending_screen_copy
- [ ] (B) Add fixture greeting and farewell barks per visit to keep Estate weeks legible +Narrative @narration type:bark zone:estate id:fixture_visit_barks
- [ ] (B) Add enclave leader greeting barks tied to faction state and current week +Narrative @narration type:bark zone:global id:enclave_leader_barks
- [ ] (B) Add mini-boss warden intro and defeat lines for Codex Reeve, Pearl Choir, and Kiln Vicar +Narrative @narration type:voice zone:global id:warden_voice_v1
- [ ] (C) Add document quotation popups when a fragment is found mid-survey +Narrative @ui type:popup zone:global id:document_popup
- [ ] (C) Add origin barks per hero class for arrival, first death, and faction-state shift +Narrative @narration type:bark zone:estate id:origin_barks_v1

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
- [ ] (A) Add campaign timer tests for week cap, dread cap, and either-cap end routing +Tests @test type:campaign zone:global id:twin_timer_tests
- [ ] (A) Add mini-boss warden tests for visible-alpha pursuit and zone behavior change after defeat +Tests @test type:combat zone:global id:warden_v1_tests
- [ ] (A) Add zone tier tests that Tier II rooms unlock after first mission cleared and Tier III after warden +Tests @test type:worldgen zone:global id:zone_tier_tests
- [ ] (B) Add faction-state tests for Custodians, Cistern Keepers, Ember Penitents, and Lamplighters transitions +Tests @test type:faction zone:global id:faction_state_tests
- [ ] (B) Add trinket-set tests for two-piece and four-piece bonus activation and cost +Tests @test type:trinket zone:global id:trinket_set_tests
- [ ] (B) Add document tests that every found fragment appears in the journal panel and clears on new campaign +Tests @test type:narrative zone:global id:document_tests
- [ ] (B) Add fixture barks tests that visiting each fixture once per week produces unique lines +Tests @test type:narration zone:global id:fixture_bark_tests
- [ ] (C) Add ending-router tests for Seal, Repair, Collapse, and Quiet routes based on flags +Tests @test type:ending zone:global id:ending_router_tests
- [ ] (C) Add late-week pressure tests that scale noise and ambush correctly past week eight +Tests @test type:campaign zone:global id:late_week_pressure_tests
