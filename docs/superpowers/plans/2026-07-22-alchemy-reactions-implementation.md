# Alchemy Reactions and Natural Battle UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make ordered Alchemy Reactions the tactical battle core, integrate them with Hero Schools and enemy intent, remove normal-battle move guides, and enlarge the main-menu dock icons without breaking saves or mobile layouts.

**Architecture:** `ComboResolver` becomes the deterministic reaction-domain authority and returns one typed result per completed bottle. A focused `ReactionEffectExecutor` applies combat payloads, while a `ReactionModifierPipeline` applies Hero/build hooks in a fixed order. UI consumes read-only reaction state through a reusable chamber component; battle state commits independently of animation.

**Tech Stack:** Godot 4.7.1, GDScript, JSON-authored content, headless Godot scene tests, Android debug export, PowerShell release validation.

## Global Constraints

- Preserve the existing color-sort pour rules and all active-run resume data.
- A bottle completion resolves its base potion effect before at most one reaction.
- Resolve the longest matching suffix first; three-color formulas beat two-color formulas.
- Reactions spend no extra move and cannot trigger recursively without another completed bottle.
- Normal battle must show no legal-target circles, yellow focus rectangles, or move-suggestion outlines.
- Locked, cursed, volatile, hidden, tutorial, keyboard-focus, and color-accessibility states remain distinguishable.
- Dock icons target 70–76 px, preserve aspect ratio, fit 576×1280 and 720×1280, and retain at least a 56 px touch target.
- Unknown reaction content falls back to the base potion effect without corrupting board or battle state.
- Preserve unrelated dirty-worktree files and stage only paths named by each task.
- Android package remains `com.farezagames.potionrogue`; release target is version `1.5.0`, version code `20`, and APK size at most 65 MiB.

---

### Task 1: Establish deterministic reaction-domain behavior

**Files:**
- Create: `tests/alchemy_reaction_test.gd`
- Create: `tests/alchemy_reaction_test.tscn`
- Modify: `src/battle/combo_resolver.gd`
- Modify: `data/combos.json`
- Modify: `src/autoload/game_state.gd`

**Interfaces:**
- Consumes: `GameState.combos: Dictionary`.
- Produces: `ComboResolver.push_essence(color: String, context := {}) -> Dictionary`, `history() -> Array[String]`, `snapshot() -> Dictionary`, and `restore(data: Dictionary) -> bool`.

- [ ] **Step 1: Write the failing resolver tests**

```gdscript
extends Node
var checks := 0
var failures := 0

func _ready() -> void:
	var resolver := ComboResolver.new()
	check(resolver.push_essence("red").is_empty(), "first essence has no reaction")
	var two := resolver.push_essence("red")
	check(str(two.get("id", "")) == "fire_burst", "two-color suffix resolves")
	resolver = ComboResolver.new()
	resolver.push_essence("red"); resolver.push_essence("purple")
	var three := resolver.push_essence("red")
	check(str(three.get("id", "")) == "inferno_catalyst",
			"longest three-color suffix wins")
	check(resolver.history() == ["red", "purple", "red"],
			"reaction does not erase chamber")
	var restored := ComboResolver.new()
	check(restored.restore(resolver.snapshot()), "snapshot restores")
	check(restored.history() == resolver.history(), "snapshot preserves order")
	check(not restored.restore({"history":["orange"], "ultimate_charge":0}),
			"invalid essence is rejected")
	print("%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("FAIL  " + label)
```

```ini
[gd_scene load_steps=2 format=3]

[ext_resource path="res://tests/alchemy_reaction_test.gd" type="Script" id="1"]

[node name="AlchemyReactionTest" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 2: Run the test and verify RED**

Run:

```powershell
.\.tools\Godot_v4.7.1-stable_win64_console.exe --headless --path . res://tests/alchemy_reaction_test.tscn
```

Expected: FAIL because `push_essence` does not exist and `restore` does not return validation status.

- [ ] **Step 3: Implement the minimal authoritative resolver**

```gdscript
const HISTORY_LIMIT := 3
const VALID_ESSENCES := ["red", "green", "blue", "purple", "wild"]

func push_essence(color: String, context := {}) -> Dictionary:
	if not color in VALID_ESSENCES:
		return {}
	_history.append(color)
	while _history.size() > HISTORY_LIMIT:
		_history.pop_front()
	for config in _patterns:
		var pattern: Array = config.get("pattern", [])
		if _matches_suffix(pattern):
			var result := config.duplicate(true)
			result["history"] = _history.duplicate()
			result["context"] = context.duplicate(true)
			combo_resolved.emit(str(result.id), result.duplicate(true))
			return result
	return {}

func push_potion(color: String) -> Dictionary:
	return push_essence(color)

func restore(data: Dictionary) -> bool:
	var candidate: Array = data.get("history", [])
	if candidate.size() > HISTORY_LIMIT:
		return false
	for color in candidate:
		if not str(color) in VALID_ESSENCES:
			return false
	_history.assign(candidate)
	_ultimate_charge = clampi(int(data.get("ultimate_charge", 0)), 0, 100)
	return true
```

Add `name`, `description`, `tags`, and `vfx` to every entry in `data/combos.json`; validate that every pattern has length 2 or 3 and only known essence IDs when `GameState` loads content. Reject negative damage/heal/shield/charge values and unknown effect IDs during loading:

```gdscript
func _valid_combo(id: String, config: Dictionary) -> bool:
	var pattern: Array = config.get("pattern", [])
	if pattern.size() < 2 or pattern.size() > 3: return false
	for color in pattern:
		if not str(color) in ComboResolver.VALID_ESSENCES: return false
	if not str(config.get("effect", "")) in REACTION_EFFECT_IDS: return false
	for key in ["damage", "heal", "shield", "charge", "value"]:
		if config.has(key) and float(config[key]) < 0.0: return false
	return not id.is_empty() and not str(config.get("name", "")).is_empty()
```

- [ ] **Step 4: Run focused and existing combat tests**

```powershell
.\.tools\Godot_v4.7.1-stable_win64_console.exe --headless --path . res://tests/alchemy_reaction_test.tscn
.\.tools\Godot_v4.7.1-stable_win64_console.exe --headless --path . res://tests/combat_depth_test.tscn
```

Expected: both exit 0; reaction test reports zero failures.

- [ ] **Step 5: Commit the domain change**

```powershell
git add -- data/combos.json src/autoload/game_state.gd src/battle/combo_resolver.gd tests/alchemy_reaction_test.gd tests/alchemy_reaction_test.gd.uid tests/alchemy_reaction_test.tscn
git commit -m "feat: make alchemy reactions deterministic"
```

### Task 2: Apply typed reaction effects and remove duplicate legacy combos

**Files:**
- Create: `src/battle/reaction_effect_executor.gd`
- Create: `tests/reaction_effect_executor_test.gd`
- Create: `tests/reaction_effect_executor_test.tscn`
- Modify: `src/battle/battle_manager.gd`
- Modify: `src/ui/battle_screen.gd`

**Interfaces:**
- Consumes: reaction dictionary returned by `ComboResolver.push_essence`.
- Produces: `ReactionEffectExecutor.apply(result: Dictionary, battle: BattleManager) -> Dictionary` with `{ok, summary, damage, heal, shield}`.

- [ ] **Step 1: Write failing effect tests**

```gdscript
func test_effects() -> void:
	var battle := BattleManager.new(); add_child(battle); battle.setup("slime")
	var executor := ReactionEffectExecutor.new()
	var hp_before := battle.enemy_hp
	var fire := executor.apply({"id":"fire_burst", "effect":"bonus_damage", "damage":10}, battle)
	check(bool(fire.get("ok", false)) and battle.enemy_hp == hp_before - 10,
			"fire reaction applies exactly once")
	var unknown := executor.apply({"id":"broken", "effect":"not_registered"}, battle)
	check(not bool(unknown.get("ok", true)), "unknown effect fails safely")
```

- [ ] **Step 2: Run the test and verify RED**

Expected: parser/load failure because `ReactionEffectExecutor` does not exist.

- [ ] **Step 3: Implement explicit handlers**

```gdscript
class_name ReactionEffectExecutor
extends RefCounted

func apply(result: Dictionary, battle: BattleManager) -> Dictionary:
	match str(result.get("effect", "")):
		"bonus_damage", "ultimate_inferno":
			var dealt := battle.deal_skill_damage(maxi(int(result.get("damage", 0)), 0))
			return {"ok":true, "damage":dealt, "summary":"+%d damage" % dealt}
		"heal_and_shield", "ultimate_sanctuary":
			var heal := battle.restore_player_hp(maxi(int(result.get("heal", 0)), 0))
			var ward := battle.grant_player_shield(maxi(int(result.get("shield", 0)), 0))
			return {"ok":true, "heal":heal, "shield":ward,
					"summary":"+%d HP  +%d shield" % [heal, ward]}
		"consume_poison", "ultimate_plague":
			return battle.resolve_poison_reaction(result)
		_:
			push_warning("Unknown reaction effect: " + str(result.get("effect", "")))
			return {"ok":false, "reason":"unknown_effect"}
```

Add focused `BattleManager` methods `restore_player_hp`, `grant_player_shield`, and `resolve_poison_reaction`. Remove `_last_potion` combo branches from `on_potion_completed` and `_activate_fire`; base colors must no longer resolve a second hidden combo path.

In `_on_depth_potion_completed`, resolve base potion first through the existing signal order, then call `push_essence`, apply at most one returned result, grant charge once, and record one replay entry.

- [ ] **Step 4: Run reaction, combat, and snapshot tests**

Expected: all exit 0 and the test proves one formula produces one effect.

- [ ] **Step 5: Commit**

```powershell
git add -- src/battle/reaction_effect_executor.gd src/battle/reaction_effect_executor.gd.uid src/battle/battle_manager.gd src/ui/battle_screen.gd tests/reaction_effect_executor_test.gd tests/reaction_effect_executor_test.gd.uid tests/reaction_effect_executor_test.tscn
git commit -m "feat: apply typed reaction effects"
```

### Task 3: Add deterministic Hero School and build reaction hooks

**Files:**
- Create: `src/battle/reaction_modifier_pipeline.gd`
- Create: `tests/reaction_modifier_pipeline_test.gd`
- Create: `tests/reaction_modifier_pipeline_test.tscn`
- Modify: `src/battle/skill_controller.gd`
- Modify: `src/ui/battle_screen.gd`
- Modify: `data/kits.json`
- Modify: `data/relics.json`
- Modify: `data/catalysts.json`
- Modify: `data/mutations.json`
- Modify: `src/run/build_synergy.gd`
- Modify: `src/run/reward_generator.gd`
- Modify: `src/ui/build_summary.gd`
- Modify: `tests/progression_depth_test.gd`

**Interfaces:**
- Consumes: `{kit_id, relics, catalysts, mutations}` and one incoming essence/result.
- Produces: `transform_essence(color: String) -> String`, `modify_result(result: Dictionary) -> Dictionary`, `snapshot() -> Dictionary`, and `restore(data: Dictionary) -> bool`.

- [ ] **Step 1: Write RED tests for hook ordering and loop prevention**

```gdscript
var pipeline := ReactionModifierPipeline.new()
pipeline.configure("void_brewer", ["first_fire_echo"], [], [])
check(pipeline.transform_essence("purple") == "wild", "Void active transforms one essence")
check(pipeline.transform_essence("purple") == "purple", "limited transform cannot loop")
var boosted := pipeline.modify_result({"id":"fire_burst", "tags":["fire"], "damage":10})
check(int(boosted.damage) == 12, "tagged modifier applies in deterministic order")
```

- [ ] **Step 2: Run and verify RED**

Expected: missing class failure.

- [ ] **Step 3: Implement a fixed hook order**

```gdscript
const ORDER := ["kit", "relic", "catalyst", "mutation"]
var _consumed_limits := {}

func transform_essence(color: String) -> String:
	for source in ORDER:
		for hook in _hooks.get(source, []):
			if str(hook.get("trigger", "")) == "transform_essence" \
					and _can_use(hook, color):
				_consume(hook)
				return str(hook.get("to", color))
	return color

func modify_result(result: Dictionary) -> Dictionary:
	var changed := result.duplicate(true)
	for source in ORDER:
		for hook in _hooks.get(source, []):
			_apply_result_hook(changed, hook)
	return changed
```

Author exact hooks for all five kits. Any essence duplication must be represented as a virtual chamber append with a per-battle limit and `allow_chain:false`; it never calls bottle-completion signals.

Expose the same structured hook fields to build and reward UI instead of reconstructing effects from prose:

```gdscript
func reaction_synergies(build: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for source in _reaction_sources(build):
		for hook in source.get("reaction_hooks", []):
			rows.append({"source":source.get("name", "Unknown"),
					"trigger":hook.get("trigger", ""), "tag":hook.get("tag", ""),
					"value":hook.get("value", 0), "limit":hook.get("limit", 0)})
	return rows
```

`BuildSummary` renders these exact rows. `RewardGenerator` includes `reaction_delta`, `affected_tags`, and `compatible` in each reaction-aware choice so the reward card can state the numerical change before selection.

- [ ] **Step 4: Run pipeline, skill, replay, and snapshot tests**

Expected: zero failures; repeated input cannot produce an unbounded reaction, and build/reward copy is derived from structured hook values.

- [ ] **Step 5: Commit**

```powershell
git add -- data/kits.json data/relics.json data/catalysts.json data/mutations.json src/battle/reaction_modifier_pipeline.gd src/battle/reaction_modifier_pipeline.gd.uid src/battle/skill_controller.gd src/run/build_synergy.gd src/run/reward_generator.gd src/ui/build_summary.gd src/ui/battle_screen.gd tests/reaction_modifier_pipeline_test.gd tests/reaction_modifier_pipeline_test.gd.uid tests/reaction_modifier_pipeline_test.tscn tests/progression_depth_test.gd
git commit -m "feat: connect hero schools to reactions"
```

### Task 4: Remove battle guides while preserving natural and accessible feedback

**Files:**
- Create: `tests/natural_battle_ui_test.gd`
- Create: `tests/natural_battle_ui_test.tscn`
- Modify: `src/puzzle/potion_tube.gd`
- Modify: `src/puzzle/puzzle_board.gd`
- Modify: `src/ui/battle_screen.gd`
- Modify: `tests/accessibility_complete_test.gd`
- Modify: `tests/board_guidance_test.gd`

**Interfaces:**
- Consumes: bottle selection, invalid move, keyboard focus, tutorial state.
- Produces: selection lift/glow, invalid shake/audio, and no normal target decoration.

- [ ] **Step 1: Write the failing visual-contract test**

```gdscript
var tube_source := FileAccess.get_file_as_string("res://src/puzzle/potion_tube.gd")
var board_source := FileAccess.get_file_as_string("res://src/puzzle/puzzle_board.gd")
check(not tube_source.contains('guidance_state == "valid"'), "no legal-target ring")
check(not tube_source.contains('Color("ffd36b")'), "no yellow focus rectangle")
check(not board_source.contains("_refresh_guidance()"), "board does not decorate targets")
check(tube_source.contains("play_invalid"), "invalid move keeps natural feedback")
check(tube_source.contains("release_focus()"), "touch selection does not leave keyboard focus")
```

- [ ] **Step 2: Run and verify RED**

Expected: failures for target ring, yellow focus, refresh call, and touch focus release.

- [ ] **Step 3: Remove guidance drawing at its source**

```gdscript
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		release_focus()
		tapped.emit(self)
	elif event.is_action_pressed("ui_accept"):
		tapped.emit(self)
		accept_event()
```

Delete `guidance_state`, the valid-target circle/arc drawing, and `_refresh_guidance`. Keep `BoardGuidance.invalid_reason` for rule explanations and invalid-action messaging. Replace the yellow rectangle with a neutral inner glint rendered only while keyboard/controller navigation owns focus.

- [ ] **Step 4: Run natural UI, accessibility, tutorial, and guidance tests**

Expected: all exit 0; tutorial spotlight remains explicit while normal target rings are absent.

- [ ] **Step 5: Commit**

```powershell
git add -- src/puzzle/potion_tube.gd src/puzzle/puzzle_board.gd src/ui/battle_screen.gd tests/natural_battle_ui_test.gd tests/natural_battle_ui_test.gd.uid tests/natural_battle_ui_test.tscn tests/accessibility_complete_test.gd tests/board_guidance_test.gd
git commit -m "fix: remove battle move guides"
```

### Task 5: Build the factual Reaction Chamber HUD

**Files:**
- Create: `src/ui/components/reaction_chamber.gd`
- Create: `tests/reaction_chamber_test.gd`
- Create: `tests/reaction_chamber_test.tscn`
- Modify: `src/ui/battle_screen.gd`
- Modify: `src/ui/battle_fx.gd`

**Interfaces:**
- Consumes: `history: Array[String]` and formula activation payload.
- Produces: `ReactionChamber.set_history(colors: Array[String])`, `play_activation(payload: Dictionary)`, and `codex_requested` signal.

- [ ] **Step 1: Write RED component tests**

```gdscript
var chamber := ReactionChamber.new(); add_child(chamber)
chamber.set_history(["red", "blue"])
check(chamber.essence_ids() == ["red", "blue"], "ordered essence state is visible")
check(chamber.get_node("Sockets").get_child_count() == 3, "three factual sockets")
check(not chamber.has_method("suggest_next"), "chamber exposes no move hint API")
```

- [ ] **Step 2: Run and verify RED**

Expected: missing class failure.

- [ ] **Step 3: Implement three neutral sockets and activation feedback**

```gdscript
class_name ReactionChamber
extends Button
signal codex_requested
var _history: Array[String] = []

func set_history(colors: Array[String]) -> void:
	_history = colors.slice(maxi(colors.size() - 3, 0))
	_render_sockets()

func essence_ids() -> Array[String]:
	return _history.duplicate()

func _pressed() -> void:
	codex_requested.emit()
```

Use circular gem textures/colors with neutral empty sockets. Do not add recipe arrows, recommended colors, pulsing target bottles, or tutorial behavior to this component.

- [ ] **Step 4: Run chamber, battle composition, responsive layout, and Reduced Effects tests**

Expected: zero failures at 576×1280 and 720×1280.

- [ ] **Step 5: Commit**

```powershell
git add -- src/ui/components/reaction_chamber.gd src/ui/components/reaction_chamber.gd.uid src/ui/battle_screen.gd src/ui/battle_fx.gd tests/reaction_chamber_test.gd tests/reaction_chamber_test.gd.uid tests/reaction_chamber_test.tscn
git commit -m "feat: add reaction chamber HUD"
```

### Task 6: Add formula discovery and Codex

**Files:**
- Create: `src/ui/reaction_codex_screen.gd`
- Create: `scenes/reaction_codex.tscn`
- Create: `tests/reaction_codex_test.gd`
- Create: `tests/reaction_codex_test.tscn`
- Modify: `src/autoload/save_system.gd`
- Modify: `src/ui/battle_screen.gd`
- Modify: `src/ui/battle/battle_overlay_controller.gd`
- Modify: `src/ui/main_menu.gd`

**Interfaces:**
- Consumes: formula data and activation IDs.
- Produces: `SaveSystem.discover_formula(id: String) -> bool`, `discovered_formulas() -> Array[String]`, `BattleOverlayController.show_notice(kicker: String, title: String, body: String)`, and a scrollable Codex scene.

- [ ] **Step 1: Write RED persistence and display tests**

```gdscript
SaveSystem.data["discovered_formulas"] = []
check(SaveSystem.discover_formula("fire_burst"), "first discovery is new")
check(not SaveSystem.discover_formula("fire_burst"), "repeat discovery is idempotent")
check(SaveSystem.discovered_formulas() == ["fire_burst"], "discovery persists")
var screen_source := FileAccess.get_file_as_string("res://src/ui/reaction_codex_screen.gd")
check(screen_source.contains("ScrollContainer"), "Codex is vertically scrollable")
```

- [ ] **Step 2: Run and verify RED**

Expected: missing SaveSystem methods and Codex source.

- [ ] **Step 3: Implement migration-safe discovery**

```gdscript
func discover_formula(id: String) -> bool:
	if not GameState.combos.has(id): return false
	var known: Array = data.get("discovered_formulas", [])
	if id in known: return false
	known.append(id); data["discovered_formulas"] = known; save_game()
	return true

func discovered_formulas() -> Array[String]:
	var result: Array[String] = []
	for id in data.get("discovered_formulas", []):
		if GameState.combos.has(str(id)): result.append(str(id))
	return result
```

Render discovered formulas with exact effects and silhouettes for locked formulas. Connect chamber tap to the Codex without changing battle state; preserve an exact encounter checkpoint before navigation.

When `discover_formula` returns `true`, show one concise post-resolution discovery card using the actual result payload:

```gdscript
func _present_reaction(result: Dictionary) -> void:
	var first_time := SaveSystem.discover_formula(str(result.get("id", "")))
	if first_time:
		overlay_controller.show_notice("NEW FORMULA",
				str(result.get("name", "Reaction")),
				str(result.get("description", "")))
	else:
		_set_message(str(result.get("name", "Reaction")))
```

The discovery card appears after state resolution, does not replay for known formulas, and cannot consume a move or alter the chamber.

Add the focused overlay method instead of reaching into overlay nodes from battle code:

```gdscript
func show_notice(kicker: String, title: String, body: String) -> void:
	_overlay.visible = true
	_title.text = kicker + "\n" + title
	_body.text = body
	_choices.visible = false
	_buttons.visible = true
```

- [ ] **Step 4: Run Codex, save migration, save recovery, and battle resume tests**

Expected: zero failures and no duplicated discovery records.

- [ ] **Step 5: Commit**

```powershell
git add -- scenes/reaction_codex.tscn src/autoload/save_system.gd src/ui/reaction_codex_screen.gd src/ui/reaction_codex_screen.gd.uid src/ui/battle_screen.gd src/ui/battle/battle_overlay_controller.gd src/ui/main_menu.gd tests/reaction_codex_test.gd tests/reaction_codex_test.gd.uid tests/reaction_codex_test.tscn
git commit -m "feat: add formula discovery codex"
```

### Task 7: Integrate reactions with enemy intent and boss phases

**Files:**
- Create: `src/battle/reaction_counterplay_controller.gd`
- Create: `tests/reaction_counterplay_test.gd`
- Create: `tests/reaction_counterplay_test.tscn`
- Modify: `src/battle/enemy_intent_controller.gd`
- Modify: `src/battle/boss_phase_controller.gd`
- Modify: `src/ui/battle_screen.gd`
- Modify: `data/intents.json`
- Modify: `data/bosses.json`

**Interfaces:**
- Consumes: current intent, boss phase rule, and resolved formula tags.
- Produces: `preview() -> Dictionary`, `modify_reaction(result: Dictionary) -> Dictionary`, and snapshot state.

- [ ] **Step 1: Write RED counterplay tests**

```gdscript
var controller := ReactionCounterplayController.new()
controller.configure({"reaction_counter":{"tag":"ward", "result":"delay", "moves":1}}, {})
var preview := controller.preview()
check(str(preview.get("counter_tag", "")) == "ward", "intent declares counterplay")
var result := controller.modify_reaction({"id":"fortify", "tags":["ward"]})
check(int(result.get("enemy_delay", 0)) == 1, "matching formula earns declared response")
check(controller.modify_reaction({"id":"fire_burst", "tags":["fire"]}).get("enemy_delay", 0) == 0,
			"unrelated formula is unchanged")
```

- [ ] **Step 2: Run and verify RED**

Expected: missing controller failure.

- [ ] **Step 3: Implement declared, snapshot-safe counterplay**

```gdscript
func modify_reaction(result: Dictionary) -> Dictionary:
	var changed := result.duplicate(true)
	var required := str(_intent_rule.get("tag", ""))
	if not required.is_empty() and required in changed.get("tags", []):
		changed["enemy_delay"] = int(_intent_rule.get("moves", 0))
		changed["countered_intent"] = true
	return changed
```

Author single-interaction teaching intents for the first realm and combined interactions only in later realms. Boss phase changes must appear in tactical readout before activation and restore exactly from snapshots.

- [ ] **Step 4: Run intent, boss, encounter snapshot, and five-realm tests**

Expected: zero failures; no hidden random recipe disable exists.

- [ ] **Step 5: Commit**

```powershell
git add -- data/intents.json data/bosses.json src/battle/reaction_counterplay_controller.gd src/battle/reaction_counterplay_controller.gd.uid src/battle/enemy_intent_controller.gd src/battle/boss_phase_controller.gd src/ui/battle_screen.gd tests/reaction_counterplay_test.gd tests/reaction_counterplay_test.gd.uid tests/reaction_counterplay_test.tscn
git commit -m "feat: add reaction counterplay to encounters"
```

### Task 8: Enlarge and rebalance the main-menu dock

**Files:**
- Create: `tests/bottom_nav_responsive_test.gd`
- Create: `tests/bottom_nav_responsive_test.tscn`
- Modify: `src/ui/components/bottom_nav.gd`
- Modify: `src/ui/main_menu.gd`
- Modify: `tests/ui_component_test.gd`

**Interfaces:**
- Consumes: viewport width and five existing medallion assets.
- Produces: `BottomNav.icon_width_for(viewport_width: float) -> int` returning 70–76.

- [ ] **Step 1: Write RED size and styling tests**

```gdscript
var nav := BottomNav.new(); add_child(nav)
check(nav.icon_width_for(576.0) == 70, "narrow dock uses 70 px icons")
check(nav.icon_width_for(720.0) == 76, "wide dock uses 76 px icons")
var button := nav.add_item("home", "Home", Callable(), true)
check(button.custom_minimum_size.y >= 104, "icon and caption receive vertical room")
check(not button.get_theme_stylebox("normal").border_width_left > 0,
			"active item does not use a box border")
```

- [ ] **Step 2: Run and verify RED**

Expected: missing responsive method and old 88 px button height fail.

- [ ] **Step 3: Implement responsive sizing**

```gdscript
func icon_width_for(viewport_width: float) -> int:
	return 70 if viewport_width < 640.0 else 76

func add_item(id: String, caption: String, action: Callable, active := false) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(72, 106)
	button.add_theme_constant_override("icon_max_width",
			icon_width_for(get_viewport_rect().size.x))
	# Keep existing signal/action wiring and use glow/modulate for active state.
	return _finish_item(button, id, caption, action, active)
```

Raise dock minimum height to 124 px, remove the active border/background box, and preserve icon aspect ratio through `expand_icon` plus `icon_max_width`.

- [ ] **Step 4: Run bottom-nav, main-menu, responsive-layout, and mobile viewport tests**

Expected: zero failures and no clipping at either reference viewport.

- [ ] **Step 5: Commit**

```powershell
git add -- src/ui/components/bottom_nav.gd src/ui/main_menu.gd tests/bottom_nav_responsive_test.gd tests/bottom_nav_responsive_test.gd.uid tests/bottom_nav_responsive_test.tscn tests/ui_component_test.gd
git commit -m "polish: enlarge main menu dock icons"
```

### Task 9: Teach one reaction without restoring persistent guides

**Files:**
- Modify: `data/tutorial_steps.json`
- Modify: `src/tutorial/tutorial_director.gd`
- Modify: `src/ui/tutorial.gd`
- Modify: `src/ui/battle_screen.gd`
- Modify: `tests/tutorial_test.gd`
- Modify: `tests/natural_battle_ui_test.gd`

**Interfaces:**
- Consumes: tutorial-only authored board and completion events.
- Produces: one Fire Burst lesson; normal battle remains guide-free after completion or skip.

- [ ] **Step 1: Add RED tutorial lifecycle assertions**

```gdscript
check(tutorial_steps.any(func(step): return str(step.get("action", "")) == "trigger_reaction"),
		"tutorial teaches one reaction")
check(tutorial_source.contains("queue_free"), "tutorial overlay is removed after completion")
check(not tube_source.contains("tutorial_target_ring"), "lesson does not bake guides into bottles")
```

- [ ] **Step 2: Run and verify RED**

Expected: missing `trigger_reaction` step.

- [ ] **Step 3: Add an authored Red→Red completion lesson**

```json
{
  "title": "REACTION: FIRE BURST",
  "body": "Complete a second Fire Potion. The order of completed colors creates an Alchemy Reaction.",
  "target": "reaction_chamber",
  "action": "trigger_reaction"
}
```

Advance this step only from the real `fire_burst` activation event. The tutorial spotlight may target the chamber, never a legal destination bottle.

- [ ] **Step 4: Run tutorial, natural UI, and accessibility tests**

Expected: zero failures; skip and completion remove every tutorial overlay.

- [ ] **Step 5: Commit**

```powershell
git add -- data/tutorial_steps.json src/tutorial/tutorial_director.gd src/ui/tutorial.gd src/ui/battle_screen.gd tests/tutorial_test.gd tests/natural_battle_ui_test.gd
git commit -m "feat: teach the first alchemy reaction"
```

### Task 10: Balance, capture, release, and push version 1.5.0

**Files:**
- Modify: `src/testing/balance_simulator.gd`
- Modify: `tests/balance_simulation_test.gd`
- Create: `tests/alchemy_release_test.gd`
- Create: `tests/alchemy_release_test.tscn`
- Modify: `project.godot`
- Modify: `export_presets.cfg`
- Modify: `.github/workflows/android-ci.yml`
- Create: `builds/PotionRogue-v20-debug.apk` (generated, not committed unless repository policy already tracks APKs)

**Interfaces:**
- Consumes: finished reaction system and all regression scenes.
- Produces: measured balance report, responsive captures, signed APK v20, and pushed `main`.

- [ ] **Step 1: Write RED release assertions**

```gdscript
var project := FileAccess.get_file_as_string("res://project.godot")
var export := FileAccess.get_file_as_string("res://export_presets.cfg")
check(project.contains('config/version="1.5.0"'), "project version is 1.5.0")
check(export.contains("version/code=20"), "Android version code is 20")
check(export.contains('version/name="1.5.0"'), "Android version name is 1.5.0")
```

- [ ] **Step 2: Run release and balance tests to verify RED**

Expected: version assertions fail before the bump; new reaction balance assertions fail until simulation is extended.

- [ ] **Step 3: Extend simulation and tune data**

Record base-only and reaction-aware win rate, turns, HP remaining, reaction frequency, and loop violations per area/Ascension. Fail the test if any simulated run reports an essence loop, if early-area reaction use is mandatory for survival, or if three-color average value is lower than its two-color counterpart.

```gdscript
check(int(report.get("loop_violations", 1)) == 0, "no free reaction loop")
check(float(report.early_base_win_rate) >= 0.65, "early game remains base-potion viable")
check(float(report.three_color_value) > float(report.two_color_value),
		"three-color formula earns its sequencing cost")
```

- [ ] **Step 4: Bump version and run the focused plus full registered regression suite**

```powershell
.\.tools\Godot_v4.7.1-stable_win64_console.exe --headless --path . res://tests/alchemy_release_test.tscn
Get-ChildItem tests -Filter *.tscn | Sort-Object Name | ForEach-Object {
  & .\.tools\Godot_v4.7.1-stable_win64_console.exe --headless --path . ("res://tests/" + $_.Name)
  if ($LASTEXITCODE -ne 0) { throw "Failed: $($_.Name)" }
}
```

Expected: every registered scene exits 0. Record exact check and failure counts; do not claim a clean suite from partial output.

- [ ] **Step 5: Capture both mobile reference sizes**

```powershell
New-Item -ItemType Directory -Force review_shots\alchemy-v20 | Out-Null
.\.tools\Godot_v4.7.1-stable_win64_console.exe --path . --resolution 576x1280 --position 30,30 -- --capture=review_shots/alchemy-v20/hall-576.png
.\.tools\Godot_v4.7.1-stable_win64_console.exe --path . --resolution 720x1280 --position 640,30 -- --capture=review_shots/alchemy-v20/battle-720.png --capture-phase=battle
```

Inspect captures for guide residue, icon clipping, chamber overlap, legibility, and bottle cleanliness before export.

- [ ] **Step 6: Export and validate APK**

```powershell
.\.tools\Godot_v4.7.1-stable_win64_console.exe --headless --path . --export-debug "Android Debug" "builds\PotionRogue-v20-debug.apk"
& .\tools\validate_release.ps1 -ProjectRoot . -ApkPath 'builds\PotionRogue-v20-debug.apk'
& 'C:\Android\Sdk\build-tools\36.0.0\apksigner.bat' verify --verbose 'builds\PotionRogue-v20-debug.apk'
& 'C:\Android\Sdk\build-tools\36.0.0\aapt.exe' dump badging 'builds\PotionRogue-v20-debug.apk' | Select-Object -First 3
Get-FileHash 'builds\PotionRogue-v20-debug.apk' -Algorithm SHA256
```

Expected: export exit 0, release budgets pass, v2/v3 signature verifies, package is `com.farezagames.potionrogue`, version code is 20, and version name is 1.5.0.

- [ ] **Step 7: Commit only owned release files and push**

```powershell
git add -- .github/workflows/android-ci.yml export_presets.cfg project.godot src/testing/balance_simulator.gd tests/balance_simulation_test.gd tests/alchemy_release_test.gd tests/alchemy_release_test.gd.uid tests/alchemy_release_test.tscn
git commit -m "release: prepare alchemy reactions v20"
git push origin main
```

Expected: push succeeds; unrelated pre-existing worktree changes remain unstaged.

## Final verification checklist

- [ ] A completed bottle resolves one base potion and at most one longest reaction.
- [ ] Legacy `_last_potion` combat combos are removed, preventing double application.
- [ ] All five Hero Schools change reaction decisions and cannot create free loops.
- [ ] Exact battle resume preserves chamber, modifiers, boss rules, and discovery state.
- [ ] Normal battle has no yellow boxes, target rings, or persistent move guides.
- [ ] Tutorial, mechanical hazards, keyboard focus, and accessibility patterns remain readable.
- [ ] Main-menu icons render at 70–76 px without clipping at both reference sizes.
- [ ] Formula Codex is scrollable and never changes current battle state.
- [ ] Full registered regression, balance simulation, capture review, Android export, signature, package, size, and hash checks have fresh evidence.
