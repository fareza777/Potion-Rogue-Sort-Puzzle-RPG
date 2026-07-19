# Presentation and Audio Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make realm selection, potion interaction, combat motion, music, and haptics clearer and more premium without increasing gameplay ambiguity.

**Architecture:** Presentation consumes immutable gameplay results and never decides damage or turn order. Reusable controllers own scroll snapping, board guidance, animation sequencing, and feedback-state selection while existing UI components render them.

**Tech Stack:** Godot 4.7.1 Control/Tween APIs, existing UiKit, EnemyDisplay, BattleFx, AudioManager, FxPool.

## Global Constraints

- Potion layers remain color-only with no symbols.
- Reduced-effects mode removes camera displacement and caps particles while preserving readable feedback.
- Back navigation and the selected expedition action remain reachable outside scroll content.
- Music requests are idempotent and respect saved volume.
- Haptics remain silent when vibration is disabled.

---

### Task 1: Scrollable selected-realm browser

**Files:**
- Create: `src/ui/snap_scroll_controller.gd`
- Modify: `src/ui/area_select_screen.gd`
- Modify: `src/ui/ui_theme_tokens.gd`
- Test: `tests/area_browser_test.gd`
- Test: `tests/area_browser_test.tscn`

**Interfaces:**
- Produces: `configure(scroll, cards)`, `select(index)`, `release()`, `selected_index()`, and signal `selection_changed(index)`.
- Areas owns one persistent launch action bound to the selected unlocked realm.

- [ ] **Step 1: Write the failing snap/selection test**

```gdscript
extends Node

func _ready() -> void:
	var scroll := ScrollContainer.new(); scroll.size = Vector2(500, 500); add_child(scroll)
	var list := VBoxContainer.new(); scroll.add_child(list)
	var cards: Array[Control] = []
	for index in 3:
		var card := PanelContainer.new(); card.custom_minimum_size = Vector2(480, 220)
		list.add_child(card); cards.append(card)
	await get_tree().process_frame
	var controller := SnapScrollController.new(); controller.configure(scroll, cards)
	controller.select(2); await get_tree().process_frame
	var ok := controller.selected_index() == 2 and scroll.scroll_vertical > 0
	print("PASS  area browser selects and snaps" if ok else "FAIL  area browser")
	get_tree().quit(0 if ok else 1)
```

- [ ] **Step 2: Run and verify RED**

Expected: missing `SnapScrollController`.

- [ ] **Step 3: Implement snapping and restructure Areas**

```gdscript
class_name SnapScrollController
extends RefCounted

signal selection_changed(index: int)
var _scroll: ScrollContainer
var _cards: Array[Control] = []
var _selected := 0

func configure(scroll: ScrollContainer, cards: Array) -> void:
	_scroll = scroll
	_cards.clear()
	for card in cards:
		_cards.append(card as Control)

func select(index: int) -> void:
	if _cards.is_empty(): return
	_selected = clampi(index, 0, _cards.size() - 1)
	_scroll.scroll_vertical = roundi(_cards[_selected].position.y)
	selection_changed.emit(_selected)

func release() -> void:
	if _cards.is_empty(): return
	var nearest := 0
	var distance := INF
	for index in _cards.size():
		var candidate := absf(_cards[index].position.y - _scroll.scroll_vertical)
		if candidate < distance: distance = candidate; nearest = index
	select(nearest)

func selected_index() -> int: return _selected
```

Refactor `area_select_screen.gd` so cards select rather than launch directly. Add a themed vertical scrollbar, one `SWIPE TO EXPLORE` cue stored in `seen_scroll_cues`, selected glow, realm background preview, mastery bar, and one external `ENTER EXPEDITION` button. Keep `BACK TO HALL` outside the ScrollContainer.

- [ ] **Step 4: Run Areas and viewport tests**

Expected: touch fallback, snap selection, persistent back/launch actions, and all viewport matrix sizes pass.

- [ ] **Step 5: Commit**

```powershell
git add src/ui/snap_scroll_controller.gd src/ui/area_select_screen.gd src/ui/ui_theme_tokens.gd tests/area_browser_test.*
git commit -m "ui: turn Areas into a polished realm browser"
```

### Task 2: Potion destination guidance and blocked reasons

**Files:**
- Create: `src/puzzle/board_guidance.gd`
- Modify: `src/puzzle/puzzle_board.gd:5-20,315-395`
- Modify: `src/puzzle/potion_tube.gd`
- Modify: `src/ui/battle_fx.gd`
- Test: `tests/board_guidance_test.gd`
- Test: `tests/board_guidance_test.tscn`

**Interfaces:**
- Produces: `BoardGuidance.describe(state, source_index, locks, capacity) -> Dictionary` with `legal`, `reasons`; new signal `guidance_changed(payload)`.
- `PotionTube.set_guidance(state: String)` accepts `source`, `legal`, `blocked`, or `none`.

- [ ] **Step 1: Write the failing legal-target/reason test**

```gdscript
extends Node

func _ready() -> void:
	var state: Array = [["red","green"],["blue"],[],["green"],[],[]]
	var result := BoardGuidance.describe(state, 0, [0,0,0,0,0,0], 4)
	var ok := 2 in result.legal and 3 in result.legal \
			and str(result.reasons.get(1, "")) == "COLOR MISMATCH"
	print("PASS  board guidance explains targets" if ok else "FAIL  board guidance")
	get_tree().quit(0 if ok else 1)
```

- [ ] **Step 2: Run and verify RED**

Expected: missing `BoardGuidance`.

- [ ] **Step 3: Implement pure guidance and visual states**

```gdscript
class_name BoardGuidance
extends RefCounted

static func describe(state: Array, source_index: int, locks: Array, capacity: int) -> Dictionary:
	var legal: Array[int] = []
	var reasons := {}
	if source_index < 0 or source_index >= state.size() or state[source_index].is_empty():
		return {"legal":legal,"reasons":reasons}
	var color := str(state[source_index].back())
	for index in state.size():
		if index == source_index: continue
		if index < locks.size() and int(locks[index]) > 0: reasons[index] = "SEALED"; continue
		if state[index].size() >= capacity: reasons[index] = "FLASK FULL"; continue
		if not state[index].is_empty() and str(state[index].back()) not in [color, "wild"] \
				and color != "wild": reasons[index] = "COLOR MISMATCH"; continue
		legal.append(index)
	return {"legal":legal,"reasons":reasons}
```

On source selection, `PuzzleBoard` emits the payload, applies tube guidance states, and asks `BattleFx` to draw one restrained arc toward the currently hovered/tapped legal target. Invalid actions emit exactly one of the three reasons. Clear all states after pour, deselect, remix, restore, pause, or victory.

- [ ] **Step 4: Run board guidance and accessibility tests**

Expected: reasons are stable, legal targets match `PuzzleBoard.legal_moves()`, no potion layer glyph is added, and high-contrast/reduced-effects tests pass.

- [ ] **Step 5: Commit**

```powershell
git add src/puzzle/board_guidance.gd src/puzzle/puzzle_board.gd src/puzzle/potion_tube.gd src/ui/battle_fx.gd tests/board_guidance_test.*
git commit -m "ui: clarify potion moves without layer symbols"
```

### Task 3: Battle presentation sequence director

**Files:**
- Create: `src/ui/battle/battle_presentation_director.gd`
- Modify: `src/ui/battle_screen.gd:35-50,750-880`
- Modify: `src/battle/enemy_display.gd`
- Modify: `src/ui/battle_fx.gd`
- Test: `tests/battle_presentation_test.gd`
- Test: `tests/battle_presentation_test.tscn`

**Interfaces:**
- Produces: `configure(bindings, reduced_effects)`, `present(payload)`, `cancel()`, `is_busy()`, and signal `phase_changed(phase)`.
- Consumes immutable payload keys `kind`, `source`, `target`, `damage`, `blocked`, `critical`, `defeated`.

- [ ] **Step 1: Write the failing ordering test**

```gdscript
extends Node

func _ready() -> void:
	var director := BattlePresentationDirector.new()
	add_child(director)
	var phases: Array[String] = []
	director.phase_changed.connect(func(phase: String): phases.append(phase))
	director.configure({}, true)
	await director.present({"kind":"enemy_attack","damage":8,"blocked":2,"defeated":false})
	var expected := ["anticipation","action","impact","resources","stagger","recovery","handoff"]
	var ok := phases == expected and not director.is_busy()
	print("PASS  battle presentation ordering" if ok else "FAIL  battle presentation")
	get_tree().quit(0 if ok else 1)
```

- [ ] **Step 2: Run and verify RED**

Expected: missing `BattlePresentationDirector`.

- [ ] **Step 3: Implement phase sequencing**

```gdscript
class_name BattlePresentationDirector
extends Node

signal phase_changed(phase: String)
var _bindings := {}
var _reduced := false
var _serial := 0
var _busy := false

func configure(bindings: Dictionary, reduced_effects: bool) -> void:
	_bindings = bindings
	_reduced = reduced_effects

func present(payload: Dictionary) -> void:
	_serial += 1; var serial := _serial; _busy = true
	for phase in ["anticipation","action","impact","resources","stagger","recovery"]:
		if serial != _serial: return
		phase_changed.emit(phase)
		await get_tree().create_timer(_duration(phase), true, false, true).timeout
	if bool(payload.get("defeated", false)): phase_changed.emit("death")
	phase_changed.emit("handoff"); _busy = false

func cancel() -> void:
	_serial += 1; _busy = false
	for value in _bindings.values():
		if value is Node and value.has_method("release_transient_effects"):
			value.call_deferred("release_transient_effects")

func is_busy() -> bool: return _busy

func _duration(phase: String) -> float:
	if _reduced: return 0.03
	return {"anticipation":0.16,"action":0.14,"impact":0.06,
			"resources":0.08,"stagger":0.16,"recovery":0.12}.get(phase, 0.08)
```

Move direct attack/hit tween calls from `battle_screen.gd` into bindings driven by `phase_changed`. The battle result remains resolved before presentation starts; board input re-enables only on `handoff`. `cancel()` runs on pause, scene exit, defeat, and reward overlay. Camera displacement is zero and particle counts use current `FxPool` caps in reduced-effects mode.

- [ ] **Step 4: Run presentation, budget, and battle integration tests**

Expected: phase order is stable, cancel returns all transient FX, reduced mode is shorter, and gameplay state remains identical with or without presentation.

- [ ] **Step 5: Commit**

```powershell
git add src/ui/battle/battle_presentation_director.gd src/ui/battle_screen.gd src/battle/enemy_display.gd src/ui/battle_fx.gd tests/battle_presentation_test.*
git commit -m "ui: stage readable battle animation phases"
```

### Task 4: Adaptive music states and named haptic patterns

**Files:**
- Modify: `src/autoload/audio_manager.gd:8-190,260-360`
- Modify: `src/ui/battle_screen.gd:105-130,300-340,750-880`
- Modify: `src/ui/map_screen.gd`
- Modify: `src/ui/main_menu.gd`
- Test: `tests/adaptive_feedback_test.gd`
- Test: `tests/adaptive_feedback_test.tscn`

**Interfaces:**
- Produces: `AudioManager.set_music_state(state) -> bool`, `music_state() -> String`, and `haptic(pattern) -> bool`.
- Valid music states: `hall`, `exploration`, `battle`, `danger`, `elite`, `boss_phase_1`, `boss_phase_2`, `boss_phase_3`, `victory`.

- [ ] **Step 1: Write the failing idempotence/settings test**

```gdscript
extends Node

func _ready() -> void:
	var accepted := AudioManager.set_music_state("battle")
	var stable := AudioManager.set_music_state("battle")
	var rejected := AudioManager.set_music_state("unknown")
	var previous := SaveSystem.data.settings.vibration
	SaveSystem.data.settings.vibration = false
	var silent := not AudioManager.haptic("player_hit")
	SaveSystem.data.settings.vibration = previous
	var ok := accepted and stable and not rejected and silent \
			and AudioManager.music_state() == "battle"
	print("PASS  adaptive feedback contract" if ok else "FAIL  adaptive feedback")
	get_tree().quit(0 if ok else 1)
```

- [ ] **Step 2: Run and verify RED**

Expected: missing `set_music_state`, `music_state`, or `haptic`.

- [ ] **Step 3: Extend AudioManager without restarting unchanged music**

```gdscript
const HAPTICS := {"select":12,"pour":18,"blocked":28,"player_hit":60,
		"enemy_hit":35,"elite_warning":75,"victory":120}
var _music_state := ""

func set_music_state(state: String) -> bool:
	if state not in ["hall","exploration","battle","danger","elite",
			"boss_phase_1","boss_phase_2","boss_phase_3","victory"]: return false
	if state == _music_state and music_is_audible(): return true
	_music_state = state
	match state:
		"hall", "exploration": set_combat_layer("explore")
		"battle": set_combat_layer("battle")
		"danger": set_combat_layer("elite")
		"elite": set_combat_layer("elite")
		"boss_phase_1", "boss_phase_2", "boss_phase_3": set_combat_layer(state)
		"victory": play("victory"); set_combat_layer("explore")
	return true

func music_state() -> String: return _music_state

func haptic(pattern: String) -> bool:
	if not bool(SaveSystem.setting("vibration")) or not HAPTICS.has(pattern): return false
	Input.vibrate_handheld(int(HAPTICS[pattern]))
	return true
```

Route hall/map/battle/elite/boss/victory through the new API. Battle switches to `danger` only when refreshed player HP crosses below 30%, and restores the encounter state after healing above 30%. Replace raw millisecond calls with named patterns.

- [ ] **Step 4: Run audio and battle feedback tests**

```powershell
& '.tools\Godot_v4.7.1-stable_win64.exe' --headless --path . res://tests/adaptive_feedback_test.tscn
& '.tools\Godot_v4.7.1-stable_win64.exe' --headless --path . res://tests/audio_test.tscn
& '.tools\Godot_v4.7.1-stable_win64.exe' --headless --path . res://tests/mobile_feedback_regression_test.tscn
```

Expected: zero failures, unchanged states do not restart playback, muted music stays muted, and disabled vibration emits no haptic request.

- [ ] **Step 5: Commit**

```powershell
git add src/autoload/audio_manager.gd src/ui/battle_screen.gd src/ui/map_screen.gd src/ui/main_menu.gd tests/adaptive_feedback_test.*
git commit -m "audio: adapt music and haptics to combat state"
```

### Task 5: Release verification and Android handoff

**Files:**
- Modify: `project.godot`
- Modify: `export_presets.cfg`
- Modify: `.github/workflows/android-ci.yml`

**Interfaces:**
- Consumes all prior tasks.
- Produces version 1.4.0 / Android version code 16 debug APK and verification record.

- [ ] **Step 1: Run every test scene**

```powershell
$godot = '.tools\Godot_v4.7.1-stable_win64.exe'
Get-ChildItem tests -Filter '*_test.tscn' | ForEach-Object {
	& $godot --headless --path . $_.FullName
	if ($LASTEXITCODE -ne 0) { throw "Failed: $($_.Name)" }
}
```

Expected: every scene reports zero failures.

- [ ] **Step 2: Run import and Android export**

```powershell
& $godot --headless --editor --quit --path .
& $godot --headless --path . --export-debug 'Android Debug' 'builds/PotionRogue-v16-debug.apk'
```

Expected: import and export exit zero.

- [ ] **Step 3: Verify artifact and signature**

```powershell
Get-Item 'builds\PotionRogue-v16-debug.apk' | Select-Object FullName,Length,LastWriteTime
Get-FileHash 'builds\PotionRogue-v16-debug.apk' -Algorithm SHA256
& "$env:LOCALAPPDATA\Android\Sdk\build-tools\36.0.0\apksigner.bat" verify --verbose 'builds\PotionRogue-v16-debug.apk'
```

Expected: APK exists, SHA-256 prints, and APK Signature Scheme v2/v3 verification succeeds.

- [ ] **Step 4: Commit the release boundary**

```powershell
git add project.godot export_presets.cfg .github/workflows/android-ci.yml
git commit -m "release: prepare systemic polish build"
```
