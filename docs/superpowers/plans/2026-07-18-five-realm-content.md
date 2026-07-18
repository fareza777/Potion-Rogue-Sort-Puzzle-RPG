# Five-Realm Content Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Frostbound Reliquary, Abyssal Apothecary, and exactly fifteen individually illustrated enemies with authored tiers, mechanics, bosses, backgrounds, and music.

**Architecture:** Content stays JSON-driven. Area grammar and boss/signature controllers consume declared IDs, while VisualRegistry resolves one optimized sprite per enemy and background/music IDs per area.

**Tech Stack:** Godot 4.7.1, GDScript, JSON, built-in image generation, PNG/WebP/OGG import pipeline, headless visual/content tests.

## Global Constraints

- Exactly fifteen new enemy IDs from the approved specification, including two bosses.
- Early floors use only intro/T1 pools; no elite/T3/boss leakage.
- Full sprite silhouette with transparent perimeter; no atlas slicing or crop.
- Existing three areas, 27 enemy definitions, saves, and Ascension remain compatible.
- Image generation is followed by in-game capture inspection at both portrait widths.

---

### Task 1: Five-area campaign data contract

**Files:**
- Modify: `data/areas.json`
- Modify: `src/run/area_grammar.gd`
- Modify: `src/run/run_generator.gd`
- Modify: `src/autoload/save_system.gd`
- Modify: `src/run/meta_progression.gd`
- Modify: `tests/campaign_test.gd`
- Modify: `tests/run_generation_test.gd`
- Modify: `tests/save_migration_test.gd`

**Interfaces:**
- Area fields add `run_length`, `boss_depth`, `miniboss_depths`, `landmarks`, `guaranteed_kinds`, and `secret_branch_chance`.
- `AreaGrammar.for_area(area_id: String) -> Dictionary` supplies normalized defaults for old areas.

- [ ] Write RED tests for five ordered areas, unlock chain, rewards 100/130, Frost depth 8, Abyss depth 9, mandatory miniboss placement, and preservation of existing nonzero Ascension.
- [ ] Confirm current three-area data fails.
- [ ] Add both area records and normalize old areas through AreaGrammar.
- [ ] Generalize generator/linking/UI roman depth handling without hardcoded seven.
- [ ] Run campaign, generation, lifecycle, migration, map, and visual tests.
- [ ] Commit: `feat: expand campaign to five realm grammars`.

### Task 2: Fifteen-enemy mechanics and tier pools

**Files:**
- Modify: `data/enemies.json`
- Modify: `data/areas.json`
- Modify: `src/ui/visual_registry.gd`
- Create: `tests/five_realm_roster_test.gd`
- Create: `tests/five_realm_roster_test.tscn`

**Interfaces:**
- Enemy display metadata: `display_scale`, `baseline_offset`, `impact_anchor`, `projectile_anchor`, `motion_profile`.
- Frostbound Reliquary IDs: `frost_mite`, `rime_squire`, `icefang_wolf`, `hoarfrost_witch`, `crystal_yeti`, `reliquary_seraph`, `winter_lich`.
- Abyssal Apothecary IDs: `ink_slime`, `drowned_acolyte`, `brine_stalker`, `abyssal_crab`, `lantern_horror`, `plague_alchemist`, `deep_oracle`, `leviathan_apothecary`.

- [ ] Add RED tests asserting total enemy count 42, exact new-ID set, valid tier/family/stats/intents/signatures, unique sprite path, no atlas path, and correct area pool depth.
- [ ] Confirm missing roster failures.
- [ ] Add balanced records for seven Frost and eight Abyss enemies; T1 attack intervals remain forgiving and boss stats use threat scaling rather than extreme base damage.
- [ ] Add normalized visual registry fallback for the new metadata.
- [ ] Run roster, content validation, campaign, encounter, audio, and visual suites.
- [ ] Commit: `feat: author fifteen enemy combat identities`.

### Task 3: New signatures, intents, and area modifiers

**Files:**
- Modify: `data/intents.json`
- Modify: `data/modifiers.json`
- Modify: `src/battle/enemy_signature_controller.gd`
- Modify: `src/battle/enemy_intent_controller.gd`
- Modify: `src/puzzle/modifier_controller.gd`
- Modify: `tests/enemy_signature_test.gd`
- Modify: `tests/modifier_test.gd`

**Interfaces:**
- New signature IDs: `freeze`, `mutate`, `tide`; all emit solver-safe board command arrays.
- New modifiers: `permafrost`, `brittle_glass`, `rising_tide`, `abyssal_ink`.

- [ ] Write RED tests for countdown, preview copy, exact snapshot/restore, solver rejection fallback, reduced-effects telegraph, and no hidden decision-critical state.
- [ ] Confirm missing-ID failures.
- [ ] Implement signatures using `PuzzleBoard.try_board_commands`; a rejected mutation displays a fizzle and does not consume or duplicate its trigger.
- [ ] Implement modifier state export/restore and readable labels.
- [ ] Run signature, modifier, board transform, snapshot, combat depth, and accessibility suites.
- [ ] Commit: `feat: add frost and abyss board pressure`.

### Task 4: Boss phase content and snapshots

**Files:**
- Modify: `data/bosses.json`
- Modify: `src/battle/boss_phase_controller.gd`
- Modify: `src/ui/battle_screen.gd`
- Modify: `tests/boss_test.gd`
- Modify: `tests/encounter_snapshot_test.gd`

**Interfaces:**
- New board actions: `frost_bind`, `tidal_rotate`, `mutate_pair`.
- Boss snapshot retains `phase_index`, `applied_phase_actions`, and pending action ID.

- [ ] Add RED tests for both three-phase definitions, one-time action application, resume idempotence, ultimate windows, and solver-safe mutation.
- [ ] Confirm missing boss definitions/actions fail.
- [ ] Add Winter Lich and Leviathan Apothecary phases exactly as specified.
- [ ] Route action presentation through the decomposed battle coordinator.
- [ ] Run boss, snapshot, board, audio, combat, and lifecycle suites.
- [ ] Commit: `feat: add two multi-phase realm bosses`.

### Task 5: Generate and integrate seventeen visual assets

**Files:**
- Create: `assets/art/enemies/frost/*.png` (7 files)
- Create: `assets/art/enemies/abyss/*.png` (8 files)
- Create: `assets/art/backgrounds/frostbound_reliquary_battle.png`
- Create: `assets/art/backgrounds/abyssal_apothecary_battle.png`
- Modify: `src/ui/visual_registry.gd`
- Modify: `tests/visual_test.gd`
- Modify: `tests/five_realm_roster_test.gd`

**Interfaces:**
- One file per approved enemy ID.
- Background IDs: `frostbound_reliquary`, `abyssal_apothecary`.

- [ ] Add RED resource/dimension/alpha/non-atlas tests before generation.
- [ ] Use built-in image generation with the approved premium painterly mobile-RPG style, full silhouette, centered subject, chroma/transparent background, no text/watermark.
- [ ] Inspect every generated image before processing. Reject cropped limbs, duplicate designs, unreadable silhouettes, or inconsistent light direction.
- [ ] Remove chroma with the imagegen skill helper, downscale runtime copies, import in Godot, and capture every enemy at 720×1280.
- [ ] Iterate individual failures; do not accept one atlas crop as multiple enemies.
- [ ] Capture both backgrounds at 576×1280 and 720×1280 with T1 and boss overlays.
- [ ] Run visual, roster, release budget, and mobile suites.
- [ ] Commit: `art: add frostbound and abyssal enemy roster`.

### Task 6: New realm audio

**Files:**
- Create: `assets/audio/frost_ambient.ogg`
- Create: `assets/audio/frost_boss.ogg`
- Create: `assets/audio/abyss_ambient.ogg`
- Create: `assets/audio/abyss_boss.ogg`
- Modify: `src/autoload/audio_manager.gd`
- Modify: `tests/audio_test.gd`
- Modify: `tools/validate_release.ps1`

**Interfaces:**
- Track IDs: `frost`, `frost_boss`, `abyss`, `abyss_boss`.

- [ ] Add RED load/loop/audibility/crossfade tests.
- [ ] Produce seamless area-specific loops, normalize phone-speaker loudness against existing tracks, and encode OGG.
- [ ] Register explicit fallback drones only for missing development assets.
- [ ] Listen/capture loop boundaries and test all battle layer transitions.
- [ ] Commit: `audio: score frostbound and abyssal realms`.

### Task 7: Slice B gate

- [ ] Run content validation and every test scene.
- [ ] Generate 10,000 graphs across five areas and verify encounter tier/cadence.
- [ ] Capture all 15 enemies plus two bosses and two maps at both widths.
- [ ] Export a checkpoint APK and validate resource budgets/signature.
- [ ] Commit gate fixes as `test: verify five-realm content expansion`.
