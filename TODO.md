# Thoth — Roadmap & Tasks

Locked 2026-06-19. Single source of truth. `TODO-CONTENT.md` merged into this file.

## Lock-in decisions

- **Engine:** stay LOVE2D + Lua. Add 3D lib (g3d or 3DreamEngine, TBD via Phase 0 spike).
- **Rendering:** HD-2D — 3D world geometry, billboarded 2D sprites for characters/enemies.
- **Camera:** isometric, 90° rotation snaps (Fez-style), no smooth 360°.
- **Distribution:** itch.io + GitHub releases. No Steam. Balatro polish bar (feel/UX/audio), not Balatro art bar.
- **Scope:** no cuts. All 3 zones (Buried Archive lead), 32 missions, 8 existing classes + new Merchant = 9 classes total.
- **Tone:** institutional horror preserved; classic-fantasy class names create deliberate dissonance.
- **Timeline:** grad +2yr is alpha milestone, 1.0 expected 4–6 yr from now. No hard deadline.
- **Audio:** royalty-free music (freepd.com, Pixabay Music). SFX from OGA or self-recorded.
- **Art:** OGA character sprites (billboarded). CC0 3D environment geometry (KayKit/Quaternius/Kenney). AI fill only as last resort after OGA exhausted.

## Class roster

| ID (code) | Display name | Status | Touch points |
|---|---|---|---|
| `warden` | Warden | unchanged | registry.lua:257 |
| `duelist` | Duelist | unchanged | registry.lua:264 |
| `mender` | **Apothecary** | **renamed** | registry.lua:271 |
| `arcanist` | Arcanist | unchanged | registry.lua:278 |
| `harrier` | **Thief** | **renamed** | registry.lua:285 |
| `chirurgeon` | Chirurgeon | unchanged | registry.lua:292 |
| `exile` | Exile | unchanged | registry.lua:299 |
| `lamplighter` | Lamplighter | unchanged | registry.lua:306 |
| `merchant` | **Merchant** | **new** | TBD — added after `lamplighter` |

Class IDs in code stay as `mender`/`harrier` for save-file compat. Display strings update.

## Merchant kit draft v0

Tone: the Stack's hand. Counts and weighs while others kill and salvage. Treats heroes as inventory entries. Lore tension: party benefits from Merchant economy while becoming Merchant's ledger.

**Skills (3, matching class-skill convention in registry.lua:255–312):**

1. `appraise_weak_point` — Ranks 3–4. Mark single target with ledger ink; next ally attack on marked target ignores armor and crits on 5+. Apply "marked" status, 2-turn duration.
2. `brokered_mercy` — Ranks 2–4. Heal one ally for moderate HP at cost of self stress (+3 stress to Merchant, +6 HP to target). Transactional heal — no free lunches.
3. `settle_accounts` — Ranks 1–2. Single-target attack scaling with target's missing HP (damage = base + missing_pct × multiplier). Executes the wounded; punishes long fights.

**Camp skills (2):**

- `audit_books` — Restores party stress (-4 each) at cost of 1 trinket drop.
- `cancel_debt` — Cures one disease on one hero. Consumes 2 faction standing with `faction_survey_office`.

**Passive (registry trait):**

- `merchant_cut` — At dread tier ≥2, +1 loot slot per mission. At dread tier ≥4, also +1 trinket-drop chance per fight. Reverse-pressure: as Estate degrades, Merchant profits more.

**Lore bark (registry.lua:1776 style):**

- `merchant = { origin = "The Merchant learned that mercy is an entry; debt outlasts the body." }`

**Class bark (registry.lua:2114 style):**

- arrival: `"A Merchant arrives with the ledger already opened."`
- firstDeath: `"The account closed at a loss."`
- factionShift: `"A Merchant marks faction weather as price movement."`

Kit subject to spike feedback. Balance pass after Phase 6 integration.

---

## Phase 0 — Engine spike (Week 1, ~20h total)

Goal: prove HD-2D rotatable iso works in LOVE2D + Lua at perf, or fail fast.

### Day 1 — Library bake-off setup (~4h)

### Day 2 — 3D world spike (~4h)

### Day 3 — Billboard sprite spike (~4h)
- [ ] 0.3.3 Load any OGA character PNG, texture the billboard (1h)
- [ ] 0.3.4 Verify sprite stays upright + camera-facing across all 4 rotation snaps (1h)

### Day 4 — Perf + integration spike (~4h)
- [ ] 0.4.1 Stencil 30 enemy billboards + 4 hero billboards into the scene (1h)
- [ ] 0.4.2 Add `love.timer.getFPS()` overlay; verify ≥60fps with full scene (1h)
- [ ] 0.4.3 Run existing `simulation.lua` headless (no render) alongside spike scene; verify game logic loop unaffected (1h)
- [ ] 0.4.4 Verify `Save.write` / `Save.read` (`src/game/save.lua`) still works with new app state. Roundtrip test (1h)

### Day 5 — Decision + writeup (~4h)
- [ ] 0.5.1 If all 4 days passed: commit spike branch, write `docs/engine-spike.md` with: chosen lib, perf numbers, integration approach for Phase 1 (2h)
- [ ] 0.5.2 If any day failed: document failure mode in `docs/engine-spike.md`, swap to other lib, retry the failed day (variable)
- [ ] 0.5.3 If both libs fail at perf or rotation: STOP. Re-open engine choice with user. Do not proceed to Phase 1. (n/a)
- [ ] 0.5.4 Tag commit `phase0-spike-complete` (0.5h)
- [ ] 0.5.5 Open Phase 1 by archiving spike branch and creating `phase1-engine-port` branch (0.5h)

**Phase 0 exit criteria:** all 5 spike days pass; engine lib chosen; ≥60fps with 34 billboards + 400 tiles + 4-snap rotation; existing save/load unaffected.

---

## Phase 1 — Engine port (~3 months, ~360h)

Goal: replace `src/app/render.lua` (1,458 lines, isometric 2D) with HD-2D render layer. Keep `simulation.lua` untouched.

- [ ] 1.1 Inventory all `Render.*` public methods used outside `render.lua` (`grep -r "Render\." src/`) — produce interface spec (2h)
- [ ] 1.2 Stub new `src/app/render3d.lua` exposing same interface, returning placeholders (4h)
- [ ] 1.3 Port `Render.load()` — engine init, asset preload (4h)
- [ ] 1.4 Port world tile rendering: convert iso tile draw to 3D quad mesh per tile (16h)
- [ ] 1.5 Port hero billboards (8h)
- [ ] 1.6 Port enemy billboards (8h)
- [ ] 1.7 Port lighting/torch effects (current `render.lua` has torch falloff math) (16h)
- [ ] 1.8 Port cutscene system (`Render.cutsceneForEvent`, 24 event types per `docs/cutscene-map.md`) (40h)
- [ ] 1.9 Port UI panels (current panel copy in `Registry.panelCopy`) (24h)
- [ ] 1.10 Wire rotation snaps to player input (replace existing `app.viewRotation` placeholder in `main.lua:91`) (4h)
- [ ] 1.11 Update `tests/run.lua` to run headless against new render layer (16h)
- [ ] 1.12 Update `make render-smoke` target to verify new render layer (4h)
- [ ] 1.13 Update `benchmarks/rpg_expedition.lua` to measure new render perf (4h)
- [ ] 1.14 Delete old `src/app/render.lua` once `render3d.lua` is at parity (1h)
- [ ] 1.15 Rename `render3d.lua` → `render.lua` (1h)
- [ ] 1.16 Update CI workflow (`.github/workflows/ci.yml`) to run new render smoke (2h)
- [ ] 1.17 Tag commit `phase1-engine-port-complete` (0.5h)

**Phase 1 exit criteria:** game boots into HD-2D world, all 24 cutscenes play, rotation works, all existing tests pass, save/load works, benchmarks ≥ old perf.

---

## Phase 2 — UI layer (~6 months, ~720h)

Goal: build every missing player-facing screen. Game must boot from title → load campaign → play → quit gracefully.

- [ ] 2.1 Design pass: sketch all 10 screens on paper (title, new game, estate, party, equipment, trinkets, expedition HUD, pause, settings, game over, credits) (8h)
- [ ] 2.2 Build title screen: animated background, new game / continue / settings / quit (16h)
- [ ] 2.3 Build settings screen: volume sliders, keybind remap, accessibility toggles (40h)
- [ ] 2.4 Build estate hub screen: building list, hero roster, expedition launch (40h)
- [ ] 2.5 Build party formation screen: drag-drop rank assignment, party preview (24h)
- [ ] 2.6 Build equipment screen: hero gear slots, trinket assignment (24h)
- [ ] 2.7 Build trinket detail tooltips with set bonus visualization (`Registry.trinketSets`) (16h)
- [ ] 2.8 Build expedition HUD overlay: stress meter, torch level, party HP/HP, current room (24h)
- [ ] 2.9 Build combat HUD: turn order, skill selection, target picker, rank indicators (40h)
- [ ] 2.10 Build curio interaction modal: 4 choices (safe/greedy/repair/leave), outcome reveal (16h)
- [ ] 2.11 Build camp screen: 7 camp skills selection (`Registry.campSkillOrder`), hero assignments (24h)
- [ ] 2.12 Build pause menu: resume / settings / save / quit-to-title (8h)
- [ ] 2.13 Build game-over screen: campaign summary, dread tier, faction states, restart option (16h)
- [ ] 2.14 Build credits screen: asset attributions (CC-BY OGA assets, royalty-free music sources) (8h)
- [ ] 2.15 Add quit-confirmation dialog if mid-expedition (4h)
- [ ] 2.16 Wire keyboard-only navigation across all UI (tab order, enter to select, esc to back) (24h)
- [ ] 2.17 Add controller support enable in `conf.lua:9` (`t.modules.joystick = true`); map gamepad to UI nav + game input (40h)
- [ ] 2.18 Build journal screen: found documents (`Registry.documents`), epitaphs (`Registry.graveyardEpitaphs`) (16h)
- [ ] 2.19 Add tutorial system: first-expedition guided overlay explaining torch/stress/rank (40h)
- [ ] 2.20 Add achievement scaffolding (in-game, not Steam) — display unlock toasts (24h)
- [ ] 2.21 Polish pass: micro-animations on every button, juice on every interaction (Balatro feel) (80h)
- [ ] 2.22 Tag commit `phase2-ui-complete` (0.5h)

**Phase 2 exit criteria:** every player decision currently in code is accessible via UI. No keyboard-shortcut-only features. Controller can play the game start to finish.

---

## Phase 3 — Asset integration (~4 months, ~480h)

Goal: replace `assets/sprites/thoth_atlas.png` (single 128×80 placeholder) with cohesive OGA pack + CC0 3D world geometry.

- [ ] 3.1 Survey OGA for billboard-friendly fantasy character packs (8h)
  - candidate: LPC collection (CC-BY-SA)
  - candidate: DawnLike 16×16 (CC-BY 4.0)
  - candidate: 2DPIXX fantasy isometric (CC0)
- [ ] 3.2 Pick one primary character pack; document license in `docs/asset-licenses.md` (2h)
- [ ] 3.3 Build sprite-import pipeline: PNG → atlas → billboard texture (8h)
- [ ] 3.4 Map 8 hero classes to OGA sprite candidates (1h per class × 8 = 8h)
- [ ] 3.5 Map 59 enemy types (`Registry.enemyOrder`, line 800+) to OGA sprites or fill gaps with AI/edits (1h per enemy × 59 = 59h)
- [ ] 3.6 Survey CC0 3D dungeon model packs (KayKit, Quaternius, Kenney) (4h)
- [ ] 3.7 Pick primary 3D model pack; document license (2h)
- [ ] 3.8 Build 3D model import pipeline (.gltf/.obj loader for chosen 3D lib) (16h)
- [ ] 3.9 Build tile→model mapping (which model used for each tile type in `Registry.tileOrder`) (8h)
- [ ] 3.10 Replace placeholder `assets/sprites/thoth_atlas.png` references with OGA atlas references in `render.lua` (8h)
- [ ] 3.11 Source ambient music: estate, expedition tense, expedition calm, combat normal, combat boss, victory sting, death sting, credits (8h source-hunting)
- [ ] 3.12 Wire music tracks into `src/app/audio.lua` with crossfade between scene contexts (16h)
- [ ] 3.13 Expand SFX library: combat hits per damage type, footsteps per tile type, UI clicks, dialogue chirps (20h)
- [ ] 3.14 Build asset-attribution generator: auto-emit credits screen text from `docs/asset-licenses.md` (4h)
- [ ] 3.15 Verify no asset license violations (no CC-BY without attribution, no CC-NC, no questionable AI-generated content if any) (2h)
- [ ] 3.16 Tag commit `phase3-assets-complete` (0.5h)

**Phase 3 exit criteria:** zero placeholder art remaining. All audio/visual assets attributed in credits. License audit clean.

---

## Phase 4 — Vertical slice alpha (~3 months, ~360h)

Goal: full playthrough of Buried Archive Tier I (3 missions) end-to-end, with 4 starter classes (Warden, Duelist, Apothecary, Thief).

- [ ] 4.1 Implement renames in `registry.lua`: Mender→Apothecary, Harrier→Thief (display strings only, IDs unchanged) (4h)
- [ ] 4.2 Update all class barks, lore text, mission text referencing old names (8h)
- [ ] 4.3 Run full test suite (`make test`) — all green (1h)
- [ ] 4.4 Build Buried Archive Tier I content polish pass: 3 missions (`archive_scout`, `archive_cleansing`, `archive_gather`) (40h)
- [ ] 4.5 Playtest end-to-end: title → estate → recruit 4 heroes → first mission → camp → return → recover → second mission (24h)
- [ ] 4.6 Bug bash: log every defect during playtest (16h)
- [ ] 4.7 Fix top 30 bugs by severity (120h)
- [ ] 4.8 Performance pass: profile, identify slowest 10 functions, optimize (40h)
- [ ] 4.9 Accessibility pass: colorblind mode, font scaling, audio cue subtitles, motion-reduced toggle (40h)
- [ ] 4.10 Build itch.io alpha page: description, screenshots, GIF, download link (8h)
- [ ] 4.11 Drop free alpha on itch.io; share to 3 communities (r/love2d, r/IndieDev, RPG Maker horror Discord) (4h)
- [ ] 4.12 Collect feedback for 4 weeks. Categorize: bug / balance / feel / scope (16h)
- [ ] 4.13 Triage feedback; write `docs/alpha-feedback-triage.md` (8h)
- [ ] 4.14 Tag commit `phase4-alpha-released` (0.5h)

**Phase 4 exit criteria:** ≥50 unique alpha downloads, ≥10 feedback responses, ≥1 full playthrough recorded by a stranger.

---

## Phase 5 — Content scale-up (~12 months, ~1500h)

Goal: fill out Buried Archive (12 missions), Salt Cistern (10 missions), Ember Warrens (9 missions) with hand-tuned polish.

- [ ] 5.1 Buried Archive Tier II content polish: 4 missions (`archive_names`, `archive_false_index`, `archive_page_bearer`, `archive_intake_map`) (80h)
- [ ] 5.2 Buried Archive Tier III content polish: 5 missions (`archive_audit_page_bearer`, `archive_silence_reeve`, `archive_witness_confession`, `archive_remand_scribe`, `archive_regent`) (120h)
- [ ] 5.3 Buried Archive boss fight polish (`archive_regent`): weak-point readability, multi-phase, dialogue (40h)
- [ ] 5.4 Salt Cistern Tier I–III content polish: 10 missions (`cistern_*` in `registry.lua:1682+`) (240h)
- [ ] 5.5 Salt Cistern boss fight polish (`cistern_bell`) (40h)
- [ ] 5.6 Ember Warrens Tier I–III content polish: 9 missions (`ember_*` and `warrens_*`) (200h)
- [ ] 5.7 Ember Warrens boss fight polish (`ember_prioress`) (40h)
- [ ] 5.8 Class unlock progression UX: clear gating from Buried Archive → Cistern → Warrens classes (16h)
- [ ] 5.9 Faction state pressure tuning: dread/faction interactions across all 32 missions (60h)
- [ ] 5.10 Ending route polish: 4 routes (`Registry.endingRoutes`) — `seal`, `repair`, `collapse`, `quiet_failure` (80h)
- [ ] 5.11 Document/lore fragment authoring: write text for all 50+ documents in `Registry.documents` (40h)
- [ ] 5.12 NPC bark scripting: enclave leaders per zone (`Registry.enclaveLeaders`) (40h)
- [ ] 5.13 Town event content polish (`Registry.townEventOrder`) (40h)
- [ ] 5.14 Beta itch.io drop (24h)
- [ ] 5.15 Collect 8 weeks of beta feedback (16h)
- [ ] 5.16 Triage + fix top 50 bugs from beta (160h)
- [ ] 5.17 Tag commit `phase5-content-complete` (0.5h)

**Phase 5 exit criteria:** all 32 missions playable, all 4 endings reachable, beta feedback triaged.

---

## Phase 6 — Merchant integration (~3 months, ~360h)

Goal: ship 9th class. Late-game design choice: introduce dissonance at the point players have made peace with the institutional tone.

- [ ] 6.1 Finalize Merchant kit design (review v0 draft above, iterate based on Phase 5 balance learnings) (16h)
- [ ] 6.2 Add `merchant` class to `Registry.heroClasses` (registry.lua:255–312) and `Registry.heroClassOrder` (registry.lua:313) (4h)
- [ ] 6.3 Implement Merchant 3 skills in `Registry.skills` (registry.lua:315): `appraise_weak_point`, `brokered_mercy`, `settle_accounts` (24h)
- [ ] 6.4 Implement Merchant 2 camp skills: `audit_books`, `cancel_debt` (16h)
- [ ] 6.5 Implement Merchant passive: `merchant_cut` (dread-tier-gated loot bonus) (16h)
- [ ] 6.6 Add Merchant lore in `Registry.classLoreBank` (registry.lua:~1770) (2h)
- [ ] 6.7 Add Merchant class barks: arrival/firstDeath/factionShift (registry.lua:~2107) (2h)
- [ ] 6.8 Add Merchant recruit bark in `Registry.recruitBarks` (4h)
- [ ] 6.9 Add Merchant graveyard epitaphs in `Registry.graveyardEpitaphs` (4h)
- [ ] 6.10 Source Merchant billboard sprite (OGA or commission) (8h)
- [ ] 6.11 Design Merchant unlock condition: post-Buried Archive Tier III completion (8h)
- [ ] 6.12 Add Merchant unlock event + cutscene (`docs/cutscene-map.md` update) (16h)
- [ ] 6.13 Write Merchant-specific document fragments + faction text (16h)
- [ ] 6.14 Balance pass: 10 playthroughs with Merchant in party at various tiers (80h)
- [ ] 6.15 Balance pass: 10 playthroughs without Merchant — verify game still tuned for 8-class roster (60h)
- [ ] 6.16 Add Merchant-specific interactions with enclave leaders (Merchant as faction-broker NPC reactions) (32h)
- [ ] 6.17 Add Merchant-specific endings or ending modifier: if Merchant alive at finale, ending text shifts (32h)
- [ ] 6.18 Test suite: Merchant skill tests, save-load with Merchant in party, deterministic replay (24h)
- [ ] 6.19 Tag commit `phase6-merchant-complete` (0.5h)

**Phase 6 exit criteria:** Merchant integrated, balanced, no regressions in 8-class playthroughs, save/replay deterministic.

---

## Phase 7 — Polish & audio (~6 months, ~720h)

Goal: Balatro-feel polish on every interaction. Audio mix. Final accessibility pass.

- [ ] 7.1 Micro-animation pass on every UI element (hover, press, success, error) — Balatro reference (120h)
- [ ] 7.2 Combat juice pass: hit pause, screen shake (toggleable), damage numbers, crit feedback (80h)
- [ ] 7.3 Audio mix pass: layer ambient + music + SFX, sidechain duck on critical events (40h)
- [ ] 7.4 Voice barks: short text-to-speech or sampled stings for class arrivals, deaths, crits (40h opt., skip if cost-prohibitive)
- [ ] 7.5 Localization scaffolding: extract all strings to `src/game/data/i18n/en.lua`; add `i18n.t(key)` calls in render layer (80h)
- [ ] 7.6 Community translation onboarding: README section, contribution guide, sample translation (8h)
- [ ] 7.7 Accessibility final pass: colorblind palettes, high-contrast UI, font scale, motion-reduced toggle, screen-reader-friendly text exports (40h)
- [ ] 7.8 Performance final pass: cold-boot time <3s, expedition load <1s, frame time <16ms 99th percentile (80h)
- [ ] 7.9 Memory profiling: ensure <500MB resident (Balatro reference) (16h)
- [ ] 7.10 Save format final lock: bump to version 4, write migration from v3 (16h)
- [ ] 7.11 Settings persistence: separate settings file from save file (16h)
- [ ] 7.12 Replay viewer UI: load replay from `Replay.write` output, view it as cutscene (40h opt.)
- [ ] 7.13 Modding hooks: expose `Registry` as override-friendly Lua table; document override pattern (40h opt.)
- [ ] 7.14 Final asset audit: every file in `assets/` traceable to a license in `docs/asset-licenses.md` (8h)
- [ ] 7.15 Tag commit `phase7-polish-complete` (0.5h)

**Phase 7 exit criteria:** Balatro-feel polish bar met (subjective; verify via 5 external playtesters' "feel" ratings). No accessibility regressions. Perf budget hit.

---

## Phase 8 — Release candidate + 1.0 (~3 months, ~360h)

Goal: ship 1.0 on itch.io + GitHub releases.

- [ ] 8.1 Build pipeline: GitHub Actions release workflow building `thoth.love`, Windows .exe (via love-release or makelove), macOS .app, Linux .AppImage (40h)
- [ ] 8.2 itch.io upload via butler CLI integration in release workflow (16h)
- [ ] 8.3 GitHub release: auto-tag, auto-attach builds, auto-generate changelog from commits (16h)
- [ ] 8.4 Verify clean install on Windows, macOS, Linux from scratch (24h)
- [ ] 8.5 Content rating self-assessment: ESRB/PEGI/IARC — document body-horror scope per `WORLD-LORE.md` § Content Acceptance Standard (8h)
- [ ] 8.6 itch.io store page final: 5 screenshots, 1 trailer (record from gameplay), description copy, tags (16h)
- [ ] 8.7 Trailer production: 60–90s gameplay edit + music (40h)
- [ ] 8.8 RC1 → 6-week paid-beta on itch.io for feedback ($0–5 suggested donation, no required purchase) (n/a)
- [ ] 8.9 Triage RC feedback; fix top 20 bugs (120h)
- [ ] 8.10 RC2 → final regression sweep (16h)
- [ ] 8.11 Press kit: presskit() format, screenshots at 1080p/4K, logo at multiple sizes (16h)
- [ ] 8.12 Launch announcement: r/love2d, r/IndieDev, RPG-horror Discords, Bluesky/Mastodon (4h)
- [ ] 8.13 Set `conf.lua` version to `1.0.0`. Bump save version. Tag commit `v1.0.0` (1h)
- [ ] 8.14 Launch (0h — let it happen)
- [ ] 8.15 Post-launch monitor: first-week bug intake, hotfix patch within 7 days if critical bugs (40h)

**Phase 8 exit criteria:** 1.0 live on itch.io + GitHub releases. Hotfix patch deployable within 24h of critical bug report.

---

## Crosscutting / continuous tasks

- [ ] C.1 Weekly: write down 3 things learned, 1 risk introduced (use `docs/dev-log.md`, append-only)
- [ ] C.2 Monthly: full test suite run + benchmark; record perf delta vs prior month
- [ ] C.3 Per-phase: verify CI workflow still green (`.github/workflows/ci.yml`)
- [ ] C.4 Per-feature: write a deterministic replay test under `tests/` proving the feature works
- [ ] C.5 Per-asset-add: append license entry to `docs/asset-licenses.md`

---

## Known risks (track and revisit)

- **R1 Engine perf:** g3d/3DreamEngine may not hit 60fps with full mission scene. Phase 0 falsifies this. Mitigation if fails: reduce visible tile count, LOD-cull distant tiles, swap to 3D model batching.
- **R2 Billboard angle:** OGA sprites drawn for top-down may look wrong at 30° iso camera. Mitigation: pick packs drawn for 3/4-view characters specifically (DawnLike, 2DPIXX), or commission angle-correct redraws.
- **R3 Rotation puzzle design conflict:** 90° rotation works mechanically, but Fez-style rotation-as-puzzle conflicts with procgen mission grammar. Mitigation: rotation is exploration aid (view occluded tiles), not puzzle mechanic, in initial design. Revisit if a rotation-as-puzzle pillar emerges.
- **R4 Scope creep:** "as long as needed" can extend indefinitely. Mitigation: every 6 months, evaluate whether 1.0 cut is closer; if not, examine which phase is bleeding time.
- **R5 Solo burnout:** 4–6 years solo is long. Mitigation: 1 day/week off-project minimum; alpha drops at Phase 4 and beta at Phase 5 for external motivation; do not skip the playtest community feedback loops.
- **R6 Post-grad income loss:** project must survive transition to part-time when grad employment kicks in. Mitigation: front-load Phase 0–4 (engine + UI + alpha) into the 2-year full-time window; treat Phase 5+ as part-time-compatible.
