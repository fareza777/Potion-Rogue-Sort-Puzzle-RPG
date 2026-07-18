# Systems and Clarity Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make run continuation exact, expose every event/action trade-off, finish promised combat/replay systems, and upgrade the UI/accessibility/performance foundation without replacing the potion-sort core.

**Architecture:** `RunState` becomes the authoritative phase/checkpoint state machine. Focused snapshot, meta-progression, and UI-component classes keep persistence, rules, and presentation separate. Existing scenes remain orchestrators and consume authored JSON plus semantic theme tokens.

**Tech Stack:** Godot 4.7.1, GDScript, JSON content, PNG/WAV assets, PowerShell validation/export scripts, Android debug export.

## Global Constraints

- Preserve the one-row six-bottle puzzle and three-area campaign.
- New Mix costs exactly one move and may trigger an enemy action.
- Event costs spend run crystals, never banked crystals.
- Save version 2/3 runs migrate without silently advancing a node.
- Minimum touch target is 56 px; every interactive control has a visible focus state.
- Daily Challenge is offline and date-seeded; no backend or live-service dependency.
- Every production behavior starts with a failing test and ends with a focused commit.
- Preserve `.codex-remote-attachments/` and unrelated main-worktree changes.

---

### Task 1: Persisted run lifecycle and Continue routing

**Files:**
- Modify: `src/autoload/run_state.gd`
- Modify: `src/autoload/save_system.gd`
- Modify: `src/ui/main_menu.gd`
- Modify: `src/ui/map_screen.gd`
- Modify: `src/ui/event_screen.gd`
- Test: `tests/save_migration_test.gd`
- Create: `tests/run_lifecycle_test.gd`
- Create: `tests/run_lifecycle_test.tscn`

**Interfaces:**
- Produces: `RunState.phase`, `RunState.PHASE_*`, `RunState.checkpoint(phase, payload)`, `RunState.resume_scene()`, `RunState.abandon_run()`.
- Consumes: `SaveSystem.save_run_boundary()` and campaign serialization.

- [ ] **Step 1: Write lifecycle regression tests**

```gdscript
RunState.start_new_run("ember_adept", "shadow_crypt")
var node_before := RunState.current_node_id
RunState.checkpoint(RunState.PHASE_BATTLE)
check(RunState.resume_scene() == "res://scenes/battle.tscn", "battle checkpoint resumes battle")
RunState.abandon_run()
check(not RunState.active and SaveSystem.data.active_run.is_empty(), "abandon clears active run")
check(RunState.current_node_id == node_before, "abandon never advances node")
```

- [ ] **Step 2: Run RED tests**

Run: `Godot --headless --path . tests/run_lifecycle_test.tscn`
Expected: FAIL because lifecycle API does not exist.

- [ ] **Step 3: Implement lifecycle constants and serialization**

```gdscript
const PHASE_MAP := "MAP"
const PHASE_BATTLE := "BATTLE"
const PHASE_EVENT := "EVENT"
const PHASE_REWARD := "REWARD"
const PHASE_COMPLETE := "COMPLETE"
var phase := PHASE_MAP
var phase_payload: Dictionary = {}

func checkpoint(next_phase: String, payload := {}) -> void:
	phase = next_phase
	phase_payload = payload.duplicate(true)
	SaveSystem.save_run_boundary(serialize_boundary())

func resume_scene() -> String:
	return {
		PHASE_BATTLE: "res://scenes/battle.tscn",
		PHASE_EVENT: "res://scenes/event.tscn",
		PHASE_REWARD: "res://scenes/battle.tscn",
	}.get(phase, "res://scenes/map.tscn")

func abandon_run() -> void:
	active = false
	phase = PHASE_COMPLETE
	phase_payload = {}
	SaveSystem.clear_active_run()
```

- [ ] **Step 4: Route Continue and node entry by phase**

`main_menu.gd` calls `RunState.resume_scene()`. `select_node()` checkpoints `BATTLE` or `EVENT` before navigation. Map never exposes links while the current phase is an unresolved encounter.

- [ ] **Step 5: Migrate version 2/3 boundaries to version 4 MAP state**

Add `phase`/`phase_payload` defaults and preserve graph/current node/build arrays.

- [ ] **Step 6: Run GREEN tests and commit**

Run lifecycle, migration, campaign, and visual suites. Commit: `fix: make continue resume exact run phase`.

---

### Task 2: Exact battle snapshot, Save & Exit, and Abandon confirmation

**Files:**
- Create: `src/battle/encounter_snapshot.gd`
- Modify: `src/battle/battle_manager.gd`
- Modify: `src/puzzle/puzzle_board.gd`
- Modify: `src/puzzle/potion_tube.gd`
- Modify: `src/battle/objective_controller.gd`
- Modify: `src/battle/enemy_intent_controller.gd`
- Modify: `src/battle/skill_controller.gd`
- Modify: `src/ui/battle_screen.gd`
- Test: `tests/gameplay_integration_test.gd`
- Test: `tests/run_lifecycle_test.gd`

**Interfaces:**
- Produces: `EncounterSnapshot.capture(...) -> Dictionary`, `EncounterSnapshot.restore(...) -> bool`, board/battle/controller snapshot methods.

- [ ] **Step 1: Write RED round-trip test**

```gdscript
var snapshot := EncounterSnapshot.capture(battle, board, objective, intent, skill, 2)
battle.player_hp = 1
board.generate_board()
check(EncounterSnapshot.restore(snapshot, battle, board, objective, intent, skill), "snapshot restores")
check(battle.player_hp == 37 and battle.moves_until_attack == 2, "battle values round-trip")
check(board.serialize_state() == snapshot.board, "board and undo history round-trip")
```

- [ ] **Step 2: Run RED test**

Expected: missing `EncounterSnapshot` and serialization APIs.

- [ ] **Step 3: Implement pure dictionary snapshots**

Snapshot validates `version`, `enemy_id`, arrays, nonnegative counters, and current node enemy before mutation. Restore failure returns false and leaves the caller able to recover to MAP.

- [ ] **Step 4: Checkpoint after every legal battle state change**

Battle screen captures after pour resolution, undo, New Mix, skill, ultimate, enemy action, and pause Save & Exit.

- [ ] **Step 5: Replace pause actions**

```gdscript
_show_overlay("Paused", "Battle progress can be saved exactly.", [
	["Save & Exit", _save_and_exit],
	["Abandon Run", _confirm_abandon],
	["Resume", _hide_overlay],
])
```

`_confirm_abandon()` presents a second confirm panel. Confirm calls `RunState.abandon_run()`; cancel returns to pause.

- [ ] **Step 6: Verify same enemy/board/HP/move counter resumes and commit**

Commit: `fix: save and restore active battle exactly`.

---

### Task 3: New Mix cost and transparent event economy

**Files:**
- Modify: `data/events.json`
- Modify: `src/run/event_resolver.gd`
- Create: `src/ui/components/event_choice_card.gd`
- Modify: `src/ui/event_screen.gd`
- Modify: `src/ui/battle_screen.gd`
- Test: `tests/encounter_test.gd`
- Test: `tests/visual_test.gd`

**Interfaces:**
- Produces: `EventResolver.describe_choice()`, result dictionaries with `before`, `after`, `deltas`, `granted`, `summary`; `EventChoiceCard.configure()`.

- [ ] **Step 1: Write RED event/new-mix tests**

```gdscript
var moves_before := battle.moves_until_attack
battle_screen.call("_on_restart_pressed")
check(battle.moves_until_attack == moves_before - 1, "New Mix costs one move")
var preview := resolver.describe_choice("mirror_cauldron", "gaze", RunState)
check(preview.cost_text == "8 HP" and preview.gain_text.contains("Mutation"), "event exposes tradeoff")
```

- [ ] **Step 2: Run RED tests**

- [ ] **Step 3: Make New Mix call `battle.on_move()` exactly once**

Regenerate the board first, resolve the move/enemy action, show `New Mix - 1 move`, checkpoint, and disable input during resolution.

- [ ] **Step 4: Author explicit event copy**

Every choice receives `summary`, `cost_text`, `gain_text`, and `risk_text`. Labels use plain English and name run crystals.

- [ ] **Step 5: Return concrete event deltas and render choice/result cards**

Unaffordable cards are disabled. Post-choice result names drafted items and exact HP/crystal/curse changes.

- [ ] **Step 6: Verify and commit**

Commit: `feat: expose event outcomes and charge remix moves`.

---

### Task 4: Objective wiring and distinct kit ultimates

**Files:**
- Modify: `data/kits.json`
- Modify: `src/battle/objective_controller.gd`
- Modify: `src/battle/skill_controller.gd`
- Modify: `src/battle/battle_manager.gd`
- Modify: `src/ui/battle_screen.gd`
- Test: `tests/combat_depth_test.gd`
- Test: `tests/gameplay_integration_test.gd`

**Interfaces:**
- Produces: objective display payload with sequence/progress; `SkillController.cast_ultimate(context) -> Dictionary`.

- [ ] **Step 1: Write RED tests for armor loss, visible brew order, and three ultimate payloads**

```gdscript
armor.on_armor_broken(7)
check(armor.current == 7, "armor objective follows real armor loss")
check(brew.display_payload().sequence == ["red", "blue", "green"], "brew order visible")
check(ember.cast_ultimate({}).effect_id == "inferno_break", "ember identity")
check(verdant.cast_ultimate({}).effect_id == "guardian_bloom", "verdant identity")
check(void.cast_ultimate({}).effect_id == "void_distill", "void identity")
```

- [ ] **Step 2: Run RED tests**

- [ ] **Step 3: Wire armor signal and objective payloads**

Connect `armor_changed(delta)` where negative delta advances Armor Break. Render ordered potion sigils and current index.

- [ ] **Step 4: Implement authored ultimate effects**

Battle screen applies returned payload fields (`damage`, `break_armor`, `heal`, `shield`, `cleanse`, `poison`, `delay`, `wild_layer`) through existing manager/board APIs.

- [ ] **Step 5: Align kit data, tutorial, and button copy; verify and commit**

Commit: `feat: finish objectives and kit ultimates`.

---

### Task 5: Mastery, Daily Challenge, Boss Rematch, and Run History

**Files:**
- Create: `src/run/meta_progression.gd`
- Modify: `src/autoload/save_system.gd`
- Modify: `src/autoload/run_state.gd`
- Modify: `src/ui/area_select_screen.gd`
- Create: `src/ui/run_history_screen.gd`
- Create: `scenes/run_history.tscn`
- Test: `tests/campaign_test.gd`
- Create: `tests/meta_progression_test.gd`
- Create: `tests/meta_progression_test.tscn`

**Interfaces:**
- Produces: `MetaProgression.daily_seed(date)`, `record_run(summary)`, `history()`, `complete_mastery()`, `start_rematch()`, `start_daily()`.

- [ ] **Step 1: Write RED idempotence, stable seed, history cap, and rematch tests**

```gdscript
check(meta.daily_seed("2026-07-18") == meta.daily_seed("2026-07-18"), "daily seed stable")
for i in 25: meta.record_run({"seed": i})
check(meta.history().size() == 20 and meta.history()[0].seed == 24, "history capped newest-first")
check(meta.complete_mastery("shadow_crypt", "clear") == 10, "first mastery rewards")
check(meta.complete_mastery("shadow_crypt", "clear") == 0, "mastery idempotent")
```

- [ ] **Step 2: Run RED tests**

- [ ] **Step 3: Migrate save schema and implement MetaProgression**

Add `mastery`, `daily`, and `run_history` defaults; validate imported arrays and cap history.

- [ ] **Step 4: Add expedition mode cards and history screen**

Normal run, Daily Challenge, and Boss Rematch display reward rules before confirmation.

- [ ] **Step 5: Record victory/defeat/abandon summaries; verify and commit**

Commit: `feat: add offline replay and run history modes`.

---

### Task 6: Semantic theme and reusable navigation/action components

**Files:**
- Create: `src/ui/ui_theme_tokens.gd`
- Create: `src/ui/components/screen_header.gd`
- Create: `src/ui/components/bottom_nav.gd`
- Create: `src/ui/components/action_icon_button.gd`
- Create: `src/ui/components/status_band.gd`
- Create: `src/ui/components/confirm_panel.gd`
- Create: `src/ui/components/run_summary_card.gd`
- Modify: `src/ui/ui_kit.gd`
- Modify: `src/ui/main_menu.gd`
- Modify: `src/ui/battle_screen.gd`
- Modify: `src/ui/map_screen.gd`
- Modify: `src/ui/settings_screen.gd`
- Modify: `src/ui/shop_screen.gd`
- Modify: `src/ui/credits_screen.gd`
- Modify: `src/ui/visual_registry.gd`
- Add: `assets/art/ui/nav/*.png`
- Test: `tests/visual_test.gd`

**Interfaces:**
- Produces reusable components with `configure()` methods and `activated` signals; semantic palette/type/spacing APIs.

- [ ] **Step 1: Write RED component/token contracts**

Assert six type sizes, five Hall nav icons, three battle icons, 56 px targets, active/pressed/focus styles, and scene use of `BottomNav`/`ActionIconButton`.

- [ ] **Step 2: Run RED visual suite**

- [ ] **Step 3: Generate coherent custom icon assets**

Use built-in image generation for one transparent-ready gold-brass/violet-jewel icon sheet, split into Hero, Upgrades, Home, Map, Settings, Undo, Remix, and Pause. Validate alpha/optical bounds and preserve source prompt in the delivery report.

- [ ] **Step 4: Implement tokens and reusable components**

`UiThemeTokens` exposes only semantic names; components use consistent optical centering, focus borders, press scale, and captions.

- [ ] **Step 5: Migrate Hall and battle controls first, then remaining screens**

Keep layouts portrait-safe and remove duplicated control factory code where migrated.

- [ ] **Step 6: Capture Hall/battle screenshots, iterate, verify, and commit**

Commit: `feat: install premium semantic UI component system`.

---

### Task 7: Accessibility, input, and area presentation completion

**Files:**
- Modify: `project.godot`
- Modify: `src/puzzle/potion_tube.gd`
- Modify: `src/puzzle/puzzle_board.gd`
- Modify: `src/ui/settings_screen.gd`
- Modify: `src/ui/battle_screen.gd`
- Modify: `src/ui/map_screen.gd`
- Modify: `src/ui/event_screen.gd`
- Modify: `src/ui/ambient_particles.gd`
- Modify: `src/ui/battle_fx.gd`
- Modify: `data/areas.json`
- Test: `tests/visual_test.gd`
- Test: `tests/gameplay_integration_test.gd`

- [ ] **Step 1: Write RED tests for pattern IDs, focus neighbors, keyboard tube actions, Android Back, and area phase colors**

- [ ] **Step 2: Run RED tests**

- [ ] **Step 3: Add potion flame/leaf/wave/spiral overlays and pattern setting**

Patterns are deterministic by potion color and controlled by `pattern_intensity`.

- [ ] **Step 4: Add explicit focus graph and puzzle keyboard/controller navigation**

Directional input moves selected tube; accept selects/pours; cancel clears selection. Android Back closes overlays or pauses battle.

- [ ] **Step 5: Consume particle/route/boss intro/phase-light data per area**

Reduced Effects uses shortened fades and disables shake/high-density particles.

- [ ] **Step 6: Verify standard/tall screenshots and commit**

Commit: `feat: add accessible input and authored area feedback`.

---

### Task 8: Runtime and package optimization with budgets

**Files:**
- Modify: `src/autoload/audio_manager.gd`
- Modify: `src/ui/battle_fx.gd`
- Modify: `src/ui/dungeon_route.gd`
- Modify: `src/battle/enemy_display.gd`
- Modify: `export_presets.cfg`
- Create: `tools/validate_release.ps1`
- Modify: `tests/audio_test.gd`
- Modify: `tests/visual_test.gd`
- Remove only if unreferenced: `assets/art/enemies/generated/atlas_*.png`

- [ ] **Step 1: Write RED cache/resource/budget tests**

Assert repeated layer selection reuses stem instances, all registered resources resolve, dead atlases have no references, and validation script reports explicit size/dimension budgets.

- [ ] **Step 2: Run RED tests**

- [ ] **Step 3: Cache stems and pool reusable FX**

Cache key is `area_music + ":" + combat_layer`; cap cache and FX pool deterministically.

- [ ] **Step 4: Stop idle process/redraw and validate atlas references before deletion**

- [ ] **Step 5: Switch export from all resources to dependency-based package and add explicit JSON/audio/font includes**

- [ ] **Step 6: Run validation script, compare APK size, verify, and commit**

Commit: `perf: cache runtime media and enforce release budgets`.

---

### Task 9: Complete regression, live QA, APK, merge, and push

**Files:**
- Modify as required by screenshot findings only.
- Produce: `builds/PotionRogue-v10-debug.apk`
- Update: `README.md`
- Update: `DESIGN-IS-2026-07-17/05-recommendations.md` only by adding an implementation-status appendix; preserve unrelated local edits on main.

- [ ] **Step 1: Run every headless suite and `git diff --check`**

Expected: all checks, zero failures.

- [ ] **Step 2: Capture live portrait QA**

Capture Hall, event preview/result, map, saved/resumed normal battle, all three bosses, mastery/daily/rematch/history, settings, and tall-phone variants. Inspect text clipping, optical centering, focus, touch targets, patterns, backgrounds, and action costs.

- [ ] **Step 3: Iterate on screenshot findings and rerun affected tests**

- [ ] **Step 4: Build and validate APK**

Export `PotionRogue-v10-debug.apk`; verify package ID, SHA-256, APK v2/v3 signature, and release budget script.

- [ ] **Step 5: Finish branch**

Run full suite again on merged `main`, push `main`, copy APK to the main workspace, remove owned worktree/branch, and confirm origin parity.
