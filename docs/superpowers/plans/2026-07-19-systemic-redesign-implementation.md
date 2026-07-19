# Potion Rogue Systemic Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver the complete July 19 engine, gameplay, visual, accessibility, and release redesign while preserving saves, solver safety, five-realm content, and exact battle resume.

**Architecture:** Keep pure combat/puzzle domain objects intact, introduce validated mutation and persistence boundaries, then make screen composition responsive and modular. All procedural decisions consume serialized run RNG. Presentation work uses bounded/cached runtime resources and one generated full-height Shadow Crypt background.

**Tech Stack:** Godot 4.7.1/GDScript, JSON content, headless scene tests, Android SDK 36, built-in image generation.

## Global Constraints

- Android portrait targets: 576×1280 and 720×1280.
- Minimum touch height: 56px; normal text minimum: 12px; normal text contrast target: 4.5:1.
- Preserve save migration and exact active-run resume.
- All puzzle mutations must be solver-safe and return an explicit result.
- Existing 42-enemy roster remains; depth comes from systems, events, builds, and authored motion.
- APK hard ceiling: 65 MiB; warning threshold: 60 MiB.
- Every behavior change follows red-green TDD and ends in an isolated commit.

---

### Task 1: Validated board-action boundary and corruption repair

**Files:**
- Create: `src/puzzle/board_action_resolver.gd`
- Modify: `src/puzzle/puzzle_board.gd:155-218`
- Modify: `src/battle/enemy_intent_controller.gd:64-82`
- Modify: `src/ui/battle_screen.gd:806-855`
- Test: `tests/board_action_wiring_test.gd`
- Test: `tests/board_action_wiring_test.tscn`

**Interfaces:**
- Produces: `BoardActionResolver.apply(action: Dictionary, board: PuzzleBoard) -> Dictionary` returning `{applied: bool, commands: Array, reason: String}`.
- Consumes: `PuzzleBoard.try_board_commands(commands: Array[Dictionary]) -> bool`.

- [ ] **Step 1: Write failing production-wiring tests**

```gdscript
extends Node
var failures := 0

func _ready() -> void:
	var board := PuzzleBoard.new(); add_child(board)
	var before := board.export_state()
	var resolver := BoardActionResolver.new()
	var result := resolver.apply({"id":"corruption", "seed":91}, board)
	check(result.applied, "corruption applies through resolver")
	check(board.export_state() != before, "corruption changes the board")
	check(BoardSolver.has_solution(board.export_state()), "corruption remains solvable")
	var invalid := resolver.apply({"id":"unknown"}, board)
	check(not invalid.applied and not invalid.reason.is_empty(), "unknown action fails explicitly")
	get_tree().quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print("PASS  " if ok else "FAIL  ", label)
```

- [ ] **Step 2: Run RED**

Run: `& '.tools\Godot_v4.7.1-stable_win64_console.exe' --headless --path . res://tests/board_action_wiring_test.tscn`

Expected: parser/class failure because `BoardActionResolver` does not exist.

- [ ] **Step 3: Implement resolver and supported append-corruption command**

```gdscript
class_name BoardActionResolver
extends RefCounted

func apply(action: Dictionary, board: PuzzleBoard) -> Dictionary:
	var id := str(action.get("id", ""))
	var commands: Array[Dictionary] = []
	match id:
		"corruption": commands = _corruption(board, int(action.get("seed", 0)))
		"heat_seal", "frost_bind": commands = _lock(board, int(action.get("moves", 1)))
		"gravity_shift", "tidal_rotate": commands = _rotate(board)
		"spore_corrupt", "mutate_pair": commands = _swap(board)
		_: return {"applied": false, "commands": [], "reason": "Unsupported board action: " + id}
	if commands.is_empty():
		return {"applied": false, "commands": [], "reason": "No eligible target for: " + id}
	var applied := board.try_board_commands(commands)
	return {"applied": applied, "commands": commands,
			"reason": "" if applied else "Action would make the board unsolvable"}
```

Add `append_corruption` handling in `PuzzleBoard.apply_board_command()` that appends a cursed effect to an eligible top layer without changing its color or capacity.

- [ ] **Step 4: Route intent and boss actions through resolver**

Replace direct command calls and ignored return values with resolver results; surface `reason` in debug output and player-facing battle message only for recoverable runtime failures.

- [ ] **Step 5: Run GREEN and regressions**

Run the new test plus `encounter_test`, `modifier_test`, `boss_test`, `board_transform_test`, and `encounter_snapshot_test`. Expected: zero failures.

- [ ] **Step 6: Commit**

`git commit -m "fix: validate every battle board action"`

---

### Task 2: Coalesced save journal and latency budget

**Files:**
- Create: `src/autoload/checkpoint_scheduler.gd`
- Modify: `project.godot:24-44`
- Modify: `src/autoload/run_state.gd:156-180`
- Modify: `src/autoload/save_system.gd:146-181,284-286`
- Modify: `src/ui/battle_screen.gd:109-159,1026-1060`
- Test: `tests/checkpoint_scheduler_test.gd`
- Test: `tests/checkpoint_scheduler_test.tscn`

**Interfaces:**
- Produces: `CheckpointScheduler.request(phase: String, payload: Dictionary)`, `flush(reason: String) -> bool`, `pending_count() -> int`.
- Consumes: `RunState.serialize_boundary()` and `SaveSystem.save_run_boundary()`.

- [ ] **Step 1: Write RED tests** asserting 20 move requests produce one coalesced write, forced flush writes immediately, and failed writes retain pending data.
- [ ] **Step 2: Run RED** and confirm the scheduler class is missing.
- [ ] **Step 3: Implement scheduler**

```gdscript
extends Node
var _pending := false
var _phase := ""
var _payload: Dictionary = {}
var _deadline_msec := 0
const QUIET_WINDOW_MSEC := 250

func request(phase: String, payload: Dictionary) -> void:
	_pending = true; _phase = phase; _payload = payload.duplicate(true)
	_deadline_msec = Time.get_ticks_msec() + QUIET_WINDOW_MSEC
	set_process(true)

func _process(_delta: float) -> void:
	if _pending and Time.get_ticks_msec() >= _deadline_msec: flush("coalesced")

func flush(_reason: String) -> bool:
	if not _pending: return true
	RunState.phase = _phase; RunState.phase_payload = _payload.duplicate(true)
	var ok := SaveSystem.save_run_boundary(RunState.serialize_boundary())
	if ok: _pending = false; set_process(false)
	return ok
```

Change `save_run_boundary`/`save` to return `bool`. Keep atomic backup validation unchanged.

- [ ] **Step 4: Force flush** on pause, app notification, enemy action, reward, scene exit, and abandonment; ordinary moves call `request`.
- [ ] **Step 5: Add latency assertion** for 100 coalesced requests and one forced write; target request path under 5ms desktop and one actual disk write.
- [ ] **Step 6: Run save recovery, lifecycle, snapshot, gameplay, and latency tests.**
- [ ] **Step 7: Commit** `git commit -m "perf: coalesce battle checkpoints"`.

---

### Task 3: Responsive tokens, area selector, and grammar-driven map

**Files:**
- Modify: `src/ui/ui_theme_tokens.gd`
- Modify: `src/ui/area_select_screen.gd:42-156`
- Modify: `src/ui/map_screen.gd:24-107`
- Modify: `src/ui/dungeon_route.gd:37-76,89-115,188-205`
- Modify: `src/ui/main_menu.gd:51-83`
- Modify: `src/ui/components/bottom_nav.gd`
- Test: `tests/responsive_layout_test.gd`
- Test: `tests/responsive_layout_test.tscn`

**Interfaces:**
- Produces: `DungeonRoute.configure(graph, current_id, boss_depth)` and authoritative token helpers.

- [ ] **Step 1: Write RED runtime-layout tests** for 576×1280 and 720×1280. Instantiate area selector and all five maps; assert every interactive global rect remains inside viewport and no horizontal scrollbar is visible.
- [ ] **Step 2: Add a Frost assertion** that every route node begins below header bottom and title text is not clipped.
- [ ] **Step 3: Run RED** against current fixed crest/action widths and fixed `6.0` normalization.
- [ ] **Step 4: Consolidate tokens**

```gdscript
const SPACE := {"xs":4, "sm":8, "md":12, "lg":16, "xl":24, "xxl":32}
const TYPE := {"caption":12, "body":14, "body_large":16,
		"subhead":18, "heading":22, "display":36, "hero":52}
const TOUCH_MIN := 56
const REALM_ACCENTS := {"shadow_crypt":Color("9f6bd2"),
		"verdant_catacombs":Color("65c98b"), "astral_foundry":Color("6bbff0"),
		"frostbound_reliquary":Color("77d9f5"), "abyssal_apothecary":Color("43d6c5")}
```

- [ ] **Step 5: Reflow area cards** into a responsive VBox: crest/info row plus full-width Enter/Locked action. Disable horizontal scrolling.
- [ ] **Step 6: Normalize map by boss depth**

```gdscript
var usable_top := 92.0
var usable_bottom := size.y - 92.0
var denominator := maxf(float(_boss_depth), 1.0)
var progress := clampf(float(node.floor) / denominator, 0.0, 1.0)
var y := lerpf(usable_bottom, usable_top, progress)
```

Stop the 25Hz redraw when hidden/reduced; use tweened node glow or 10Hz maximum.

- [ ] **Step 7: Remove duplicated menu destinations** and make bottom navigation Home/Areas/Build/History/Credits.
- [ ] **Step 8: Run responsive, visual, accessibility, run-generation, and mobile regression tests.**
- [ ] **Step 9: Commit** `git commit -m "ui: make campaign screens fully responsive"`.

---

### Task 4: Decompose battle presentation without behavior changes

**Files:**
- Create: `src/ui/battle/encounter_coordinator.gd`
- Create: `src/ui/battle/battle_hud_presenter.gd`
- Create: `src/ui/battle/battle_overlay_controller.gd`
- Create: `src/ui/battle/battle_navigation.gd`
- Modify: `src/ui/battle_screen.gd`
- Test: `tests/battle_composition_test.gd`
- Test: `tests/battle_composition_test.tscn`

**Interfaces:**
- `EncounterCoordinator.configure(battle, board, entry)`, `snapshot()`, `restore(data)`.
- `BattleHudPresenter.build(parent, profile)`, `refresh(model)`.
- `BattleOverlayController.show_reward(kind, choices)`, `show_pause()`, `hide()`.
- `BattleNavigation.go_to_map/menu/area_select()`.

- [ ] **Step 1: Write RED composition tests** requiring the four collaborators and asserting old snapshot round-trip, victory choice, pause/resume, and New Mix behavior.
- [ ] **Step 2: Extract one responsibility at a time**, running `encounter_snapshot_test`, `gameplay_integration_test`, and `mobile_feedback_regression_test` after each extraction.
- [ ] **Step 3: Keep `battle_screen.gd` below 450 lines** and prohibit direct `SaveSystem` access outside navigation/coordinator boundaries.
- [ ] **Step 4: Run the full battle-related suite.**
- [ ] **Step 5: Commit** `git commit -m "refactor: split battle screen responsibilities"`.

---

### Task 5: Serialized run RNG and adaptive director

**Files:**
- Create: `src/run/run_rng.gd`
- Modify: `src/autoload/run_state.gd`
- Modify: `src/run/run_generator.gd:10-65`
- Modify: `src/run/run_director.gd`
- Modify: `src/run/reward_generator.gd`
- Modify: `src/autoload/save_system.gd` migration
- Test: `tests/run_determinism_test.gd`
- Test: `tests/run_determinism_test.tscn`

**Interfaces:**
- `RunRng.configure(seed, state := 0)`, `pick_weighted(entries)`, `shuffle(values)`, `snapshot() -> Dictionary`.
- `RunDirector.context` contains `hp_ratio`, `build_power`, `recent_families`, `previous_kinds`, `floor`, `area_id`, `ascension`.

- [ ] **Step 1: Write RED tests** proving same seed/action sequence yields identical route, enemies, rewards, events, and future adaptation after save/resume.
- [ ] **Step 2: Add an adaptive recovery test**: HP ≤35% increases recovery availability without changing revealed nodes.
- [ ] **Step 3: Implement xorshift/PCG-style serialized RNG** with no calls to global `shuffle()` or `pick_random()` in run/reward paths.
- [ ] **Step 4: Resolve unrevealed future nodes at checkpoint boundaries** from current context; preserve selected/revealed node data.
- [ ] **Step 5: Run 2,000-seed topology/pacing simulation plus run lifecycle/migration tests.**
- [ ] **Step 6: Commit** `git commit -m "feat: make procedural runs adaptive and replayable"`.

---

### Task 6: Build semantics, events, Mastery, Daily, and Ascension

**Files:**
- Create: `src/run/build_synergy.gd`
- Modify: `data/events.json`, `data/relics.json`, `data/mutations.json`, `data/catalysts.json`, `data/upgrades.json`
- Create: `data/ascension_rules.json`
- Modify: `src/ui/build_summary.gd`
- Modify: `src/ui/event_screen.gd`
- Modify: `src/ui/run_history_screen.gd`
- Modify: `src/ui/area_select_screen.gd`
- Modify: `src/run/meta_progression.gd`
- Modify: `src/autoload/save_system.gd`
- Test: `tests/progression_depth_test.gd`
- Test: `tests/progression_depth_test.tscn`

- [ ] **Step 1: Write RED tests** requiring ≥15 events, exact effect copy, genuine tag synergy, production Mastery progress, UTC Daily identity/claimed state/score/streak, authored Ascension rule per level, and rich history records.
- [ ] **Step 2: Add structured tags/effects** to every reward and implement `BuildSynergy.evaluate(build) -> Array[Dictionary]` returning named interactions with contributing IDs and exact values.
- [ ] **Step 3: Make Build Summary tap-open** and show relic/upgrades/mutations/catalysts plus exact deltas.
- [ ] **Step 4: Expand events** across realm tags with explicit cost, risk, and result copy.
- [ ] **Step 5: Wire Mastery/Daily/Ascension/history** into actual run completion and migration-safe save fields.
- [ ] **Step 6: Run progression, event, action-clarity, campaign, simulation, and migration tests.**
- [ ] **Step 7: Commit** `git commit -m "feat: deepen builds and long-term progression"`.

---

### Task 7: Accessibility, honest copy, and complete reduced motion

**Files:**
- Modify: `src/ui/settings_screen.gd`
- Modify: `src/autoload/save_system.gd`
- Modify: `src/ui/ui_kit.gd`
- Modify: `src/ui/main_menu.gd`
- Modify: `src/ui/battle_fx.gd`
- Modify: `src/battle/enemy_display.gd`
- Modify: `src/puzzle/potion_tube.gd`
- Modify: `src/ui/ambient_particles.gd`
- Modify: `src/ui/dungeon_route.gd`
- Test: `tests/accessibility_complete_test.gd`
- Test: `tests/accessibility_complete_test.tscn`

- [ ] **Step 1: Write RED tests** for ≥56px touch targets, explicit focus styles/order, 4.5:1 normal text tokens, text scale, high contrast, tap-open detail, and zero continuous idle motion in Reduced Effects.
- [ ] **Step 2: Add saved settings** `text_scale`, `high_contrast`, and migrate/remove dead `color_patterns`.
- [ ] **Step 3: Apply settings from SaveSystem at startup**, not transient ProjectSettings state.
- [ ] **Step 4: Correct copy**: Credits, Local Daily, Claimed, Ascension rule summary, real synergy names, and exact reward effects.
- [ ] **Step 5: Add focus neighbors/styles** for all primary surfaces and authored focused tube rendering.
- [ ] **Step 6: Gate every idle/tween system** behind reduced-effects policy.
- [ ] **Step 7: Run accessibility, visual, action clarity, settings, and mobile suites.**
- [ ] **Step 8: Commit** `git commit -m "accessibility: unify touch focus copy and motion"`.

---

### Task 8: Runtime presentation budgets

**Files:**
- Create: `src/ui/fx_pool.gd`
- Create: `src/ui/resource_texture_cache.gd`
- Modify: `src/ui/battle_fx.gd`
- Modify: `src/ui/ornate_resource_bar.gd`
- Modify: `src/autoload/audio_manager.gd`
- Modify: `src/ui/map_screen.gd`, `src/ui/event_screen.gd`, `src/ui/main_menu.gd`
- Test: `tests/presentation_budget_test.gd`
- Test: `tests/presentation_budget_test.tscn`

- [ ] **Step 1: Write RED budget tests** for FX concurrent-node ceiling 48, shared bar textures, no eager fallback synthesis when music exists, music continuity across every scene state, and audio first-use budget.
- [ ] **Step 2: Implement bounded pools** for particles, rings, trails, and float labels; recycle on tween completion.
- [ ] **Step 3: Cache gradient/bar textures** by kind, dimensions, and palette.
- [ ] **Step 4: Lazy-load audio** and move fallback creation behind `ResourceLoader.exists()` failure.
- [ ] **Step 5: Add explicit hall/explore/event/battle/elite/boss/victory/defeat music state transitions.**
- [ ] **Step 6: Run audio, presentation, mobile, and gameplay tests.**
- [ ] **Step 7: Commit** `git commit -m "perf: bound visual and audio presentation cost"`.

---

### Task 9: Generate and integrate premium Shadow Crypt background

**Files:**
- Preserve: `assets/art/backgrounds/shadow_crypt_battle.png`
- Create: `assets/art/backgrounds/shadow_crypt_battle_v2.png`
- Modify: `data/areas.json`
- Modify: `src/ui/visual_registry.gd`
- Test: `tests/content_asset_test.gd`
- Test: `tests/visual_test.gd`

- [ ] **Step 1: Add RED asset contract** requiring the v2 path, portrait aspect, loadable texture, central readability metadata, and no missing runtime assets.
- [ ] **Step 2: Generate artwork with built-in image generation** using this final prompt:

```text
Use case: stylized-concept
Asset type: premium portrait mobile-game battle background for Shadow Crypt, first realm of Potion Rogue
Primary request: a full-height ancient ossuary-alchemy dungeon interior matching the density and finish of the existing Verdant Catacombs, Astral Foundry, Frostbound Reliquary, and Abyssal Apothecary backgrounds
Scene/backdrop: vast gothic crypt corridor with bone-and-stone pillars, hanging chains, carved skull reliquaries, distant Crucible Gate, violet and blue soul flames, restrained amber torchlight, circular combat sigil and stone dais
Style/medium: polished high-detail dark-fantasy game illustration, realistic materials, premium Play Store key-art quality
Composition/framing: symmetrical portrait composition, strong depth, detailed from top to bottom; central 42 percent lower contrast for enemy/UI readability; detailed foreground floor around potion area
Lighting/mood: mysterious but readable, richer midtones than the old crypt, luminous purple-blue focal depth
Constraints: no characters, enemies, potions, UI, text, logo, watermark, frame, cropped architecture, or black empty lower half
Avoid: flat darkness, generic cave, excessive fog, blown highlights, busy high-contrast center
```

- [ ] **Step 3: Inspect the generated image**, iterate once on only the largest mismatch, then copy final output into the asset path.
- [ ] **Step 4: Import and optimize** to project portrait dimensions, preserve v1 fallback, update area/registry paths.
- [ ] **Step 5: Capture Shadow battle at 576×1280** and assert enemy, bars, bottles, and text remain readable with no clipping.
- [ ] **Step 6: Run content asset, visual, mobile, and release budget tests.**
- [ ] **Step 7: Commit** `git commit -m "art: replace Shadow Crypt with full-height battle art"`.

---

### Task 10: Asset cleanup, CI, release gates, and APK

**Files:**
- Remove after reference proof: `assets/art/enemies/atlas_crypt.png`, `atlas_fungal.png`, `atlas_infernal.png`, `atlas_arcane.png`
- Modify: `export_presets.cfg`
- Modify: `tools/validate_release.ps1`
- Create: `.github/workflows/android-regression.yml`
- Modify: `tests/release_budget_test.gd`
- Modify: `project.godot`, `export_presets.cfg` version fields

- [ ] **Step 1: Write RED release tests** requiring referenced-only export, automatic newest APK discovery, 60 MiB warning, 65 MiB failure, aggregate art/audio budgets, and current version agreement.
- [ ] **Step 2: Prove legacy atlases have zero runtime references**, delete them, and switch export filtering to production resources/exclusions.
- [ ] **Step 3: Convert remaining long WAV ambience to streaming OGG** while retaining short SFX WAV only where latency benefits.
- [ ] **Step 4: Add CI workflow** that imports Godot, runs every `*_test.tscn`, exports Android debug, validates signature/version/size, and uploads the APK artifact.
- [ ] **Step 5: Run all 28+ suites sequentially**, then deterministic visual captures and `tools/validate_release.ps1`.
- [ ] **Step 6: Bump version**, export signed debug APK, verify v2/v3 signature, package metadata, size, and SHA-256; copy to root `builds/`.
- [ ] **Step 7: Commit** `git commit -m "release: ship systemic redesign build"`.

---

## Self-review

- Coverage: all ten audit recommendations plus the Shadow Crypt background are assigned to Tasks 1–10.
- Compatibility: save migration, exact resume, solver safety, five-realm content, and old background fallback are explicit.
- Type consistency: board action, checkpoint scheduler, run RNG, and battle collaborator interfaces are defined before consumers.
- Verification: every task has a RED test, GREEN run, focused regressions, and commit boundary.
- Scope: no additional enemy roster expansion, online backend, monetization, or multiplayer work is included.
