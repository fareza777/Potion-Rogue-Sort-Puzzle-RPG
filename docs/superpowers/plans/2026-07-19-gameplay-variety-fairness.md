# Gameplay Variety and Fairness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add disclosed adaptive pacing, five encounter formats, a fair New Mix economy, area mastery, and a deterministic weekly challenge.

**Architecture:** Generate an immutable encounter profile before entering battle and store it in the existing contract/checkpoint. Format and remix controllers own their own state while `BattleManager` remains authoritative for HP, attacks, and victory.

**Tech Stack:** Godot 4.7.1, GDScript, existing RunRng, RunGenerator, ObjectiveController, SaveSystem.

## Global Constraints

- Difficulty never changes enemy HP, attack, armor, or intent after an encounter starts.
- Intro floors use duel encounters only; advanced formats start at floor three.
- Ascension floors cannot be canceled by adaptive assistance.
- Emergency Mix always remains available when the board is recoverable.
- Weekly challenge is local-only and makes no online leaderboard claim.

---

### Task 1: Immutable encounter profiles

**Files:**
- Create: `src/run/encounter_director.gd`
- Modify: `src/run/encounter_contract.gd`
- Modify: `src/run/run_generator.gd:34-66,94-125`
- Modify: `src/autoload/run_state.gd:130-165`
- Test: `tests/encounter_director_test.gd`
- Test: `tests/encounter_director_test.tscn`

**Interfaces:**
- Consumes: floor, kind, area, ascension, run health context, and RunRng.
- Produces: `profile(context, rng) -> Dictionary` with `format`, `assistance_tier`, `board_band`, `countdown_bonus`, `reward_mult`, and `waves`.

- [ ] **Step 1: Write the failing deterministic/fairness test**

```gdscript
extends Node

func _ready() -> void:
	var first_rng := RunRng.new(); first_rng.configure(5001)
	var second_rng := RunRng.new(); second_rng.configure(5001)
	var context := {"floor":4,"kind":"battle","area_id":"shadow_crypt",
			"ascension":2,"hp_ratio":0.22,"recent_invalid":4,"recent_recovery":1}
	var first := EncounterDirector.new().profile(context, first_rng)
	var second := EncounterDirector.new().profile(context, second_rng)
	var intro_rng := RunRng.new(); intro_rng.configure(9)
	var intro := EncounterDirector.new().profile({"floor":1,"kind":"battle",
			"area_id":"shadow_crypt","ascension":0,"hp_ratio":1.0}, intro_rng)
	var ok := first == second and int(first.assistance_tier) <= 2 \
			and not first.has("enemy_hp_scale") and intro.format == "duel"
	print("PASS  encounter profile deterministic and disclosed" if ok else "FAIL  encounter profile")
	get_tree().quit(0 if ok else 1)
```

- [ ] **Step 2: Run and verify RED**

Expected: missing `EncounterDirector`.

- [ ] **Step 3: Implement the director and extend contracts**

```gdscript
class_name EncounterDirector
extends RefCounted

const FORMATS := ["duel", "survival", "multi_wave", "protect_cauldron", "elite_contract"]

func profile(context: Dictionary, rng: RunRng) -> Dictionary:
	var floor := maxi(int(context.get("floor", 1)), 1)
	var kind := str(context.get("kind", "battle"))
	var ascension := clampi(int(context.get("ascension", 0)), 0, 10)
	var pressure := int(context.get("recent_invalid", 0)) + int(context.get("recent_recovery", 0)) * 2
	var low_hp := float(context.get("hp_ratio", 1.0)) <= 0.35
	var assistance := mini((1 if low_hp else 0) + (1 if pressure >= 4 else 0), 2)
	var allowed: Array[String] = ["duel"]
	if floor >= 3:
		allowed.append_array(["survival", "multi_wave", "protect_cauldron"])
	if kind == "elite": allowed = ["elite_contract"]
	if kind == "boss": allowed = ["duel"]
	var format := allowed[rng.randi_range(0, allowed.size() - 1)]
	return {"version":1, "format":format, "assistance_tier":assistance,
			"board_band":"easy" if assistance >= 2 else "standard",
			"countdown_bonus":1 if assistance >= 1 and ascension < 3 else 0,
			"reward_mult":1.35 if format == "elite_contract" else 1.15 if format != "duel" else 1.0,
			"waves":2 if format == "multi_wave" else 1}
```

Extend `EncounterContract` with validated `format`, `assistance_tier`, `board_band`, `countdown_bonus`, `waves`, and `profile_version`. `RunGenerator` stores only the authored base contract. Add this RunState boundary and call it for the start node and immediately after every successful `select_node()`:

```gdscript
func ensure_current_encounter_profile() -> Dictionary:
	var node := current_node()
	if node.is_empty() or str(node.get("kind", "")) not in ["battle","elite","boss"]: return {}
	var contract: Dictionary = node.get("contract", {})
	if not (contract.get("profile", {}) as Dictionary).is_empty(): return contract.profile
	var rng := RunRng.new()
	rng.configure(run_seed ^ str(node.get("id", "")).hash())
	var maximum := maxi(int(GameState.player.get("max_hp", 50)), 1)
	var hp_ratio := 1.0 if player_hp < 0 else float(player_hp) / float(maximum)
	contract["profile"] = EncounterDirector.new().profile({
		"floor":int(node.get("floor", 1)), "kind":str(node.get("kind", "battle")),
		"area_id":area_id, "ascension":run_ascension, "hp_ratio":hp_ratio,
		"recent_invalid":int(phase_payload.get("recent_invalid", 0)),
		"recent_recovery":int(phase_payload.get("recent_recovery", 0))}, rng)
	node["contract"] = contract
	return contract.profile
```

The resulting dictionary lives under `node.contract.profile` and is never recomputed when resuming.

- [ ] **Step 4: Run encounter/run determinism tests**

```powershell
& '.tools\Godot_v4.7.1-stable_win64.exe' --headless --path . res://tests/encounter_director_test.tscn
& '.tools\Godot_v4.7.1-stable_win64.exe' --headless --path . res://tests/run_determinism_test.tscn
& '.tools\Godot_v4.7.1-stable_win64.exe' --headless --path . res://tests/run_generation_test.tscn
```

Expected: zero failures.

- [ ] **Step 5: Commit**

```powershell
git add src/run/encounter_director.gd src/run/encounter_contract.gd src/run/run_generator.gd src/autoload/run_state.gd tests/encounter_director_test.*
git commit -m "gameplay: author immutable adaptive encounters"
```

### Task 2: Encounter format state machine

**Files:**
- Create: `src/battle/encounter_format_controller.gd`
- Modify: `src/battle/battle_manager.gd:45-115`
- Modify: `src/ui/battle_screen.gd:25-50,80-180,190-260,820-930`
- Modify: `src/ui/tactical_readout.gd:55-80`
- Test: `tests/encounter_format_test.gd`
- Test: `tests/encounter_format_test.tscn`

**Interfaces:**
- Produces: `configure(profile, enemies)`, `on_enemy_defeated()`, `on_enemy_action()`, `on_potion_completed()`, `damage_cauldron()`, `snapshot()`, and signals `wave_requested`, `format_completed`, `format_failed`, `progress_changed`.

- [ ] **Step 1: Write the failing format test**

```gdscript
extends Node

func _ready() -> void:
	var controller := EncounterFormatController.new()
	controller.configure({"format":"multi_wave","waves":2}, ["slime","skeleton"])
	var first := controller.on_enemy_defeated()
	var second := controller.on_enemy_defeated()
	var survival := EncounterFormatController.new()
	survival.configure({"format":"survival","target":3}, ["slime"])
	survival.on_enemy_action(); survival.on_enemy_action(); var survived := survival.on_enemy_action()
	var ok := first.action == "next_wave" and first.enemy == "skeleton" \
			and second.action == "complete" and survived.action == "complete"
	print("PASS  encounter formats advance" if ok else "FAIL  encounter formats")
	get_tree().quit(0 if ok else 1)
```

- [ ] **Step 2: Run and verify RED**

Expected: missing `EncounterFormatController`.

- [ ] **Step 3: Implement the state machine**

```gdscript
class_name EncounterFormatController
extends RefCounted

var format := "duel"
var target := 1
var progress := 0
var wave_index := 0
var enemies: Array[String] = []
var cauldron_hp := 30

func configure(profile: Dictionary, enemy_ids: Array) -> void:
	format = str(profile.get("format", "duel"))
	target = maxi(int(profile.get("target", 3 if format == "survival" else 1)), 1)
	enemies.clear()
	for value in enemy_ids:
		enemies.append(str(value))
	cauldron_hp = maxi(int(profile.get("cauldron_hp", 30)), 1)

func on_enemy_defeated() -> Dictionary:
	if format == "multi_wave" and wave_index + 1 < enemies.size():
		wave_index += 1
		return {"action":"next_wave", "enemy":enemies[wave_index]}
	return {"action":"complete"}

func on_enemy_action() -> Dictionary:
	if format != "survival": return {"action":"continue"}
	progress += 1
	return {"action":"complete"} if progress >= target else {"action":"continue"}

func on_potion_completed() -> Dictionary:
	if format != "protect_cauldron": return {"action":"continue"}
	progress += 1
	return {"action":"complete"} if progress >= target else {"action":"continue"}

func damage_cauldron(amount: int) -> Dictionary:
	cauldron_hp = maxi(cauldron_hp - maxi(amount, 0), 0)
	return {"action":"fail"} if cauldron_hp == 0 else {"action":"continue"}

func snapshot() -> Dictionary:
	return {"version":1,"format":format,"target":target,"progress":progress,
			"wave_index":wave_index,"enemies":enemies.duplicate(),"cauldron_hp":cauldron_hp}
```

Add a player-state-preserving wave boundary to `BattleManager`:

```gdscript
func setup_next_wave(new_enemy_id: String) -> void:
	var carried := {"hp":player_hp,"shield":shield,
			"player_poison_damage":player_poison_damage,
			"player_poison_turns":player_poison_turns,
			"last_remedy_used":_last_remedy_used}
	setup(new_enemy_id)
	player_hp = clampi(int(carried.hp), 1, player_max_hp)
	shield = clampi(int(carried.shield), 0, max_shield)
	player_poison_damage = maxi(int(carried.player_poison_damage), 0)
	player_poison_turns = maxi(int(carried.player_poison_turns), 0)
	_last_remedy_used = bool(carried.last_remedy_used)
	stats_changed.emit()
```

In `battle_screen.gd`, intercept `battle_won`: request the next authored wave and call `setup_next_wave()` when returned, preserving mana, board, modifiers, and controller state; only enter reward flow when the format controller returns `complete`. Feed format progress into `TacticalReadout` and checkpoint its snapshot.

- [ ] **Step 4: Run focused battle suites**

Run encounter format, encounter snapshot, battle composition, and gameplay integration scenes. Expected: zero failures and no direct format logic inside `BattleManager`.

- [ ] **Step 5: Commit**

```powershell
git add src/battle/encounter_format_controller.gd src/battle/battle_manager.gd src/ui/battle_screen.gd src/ui/tactical_readout.gd tests/encounter_format_test.*
git commit -m "gameplay: add varied encounter formats"
```

### Task 3: Standard and emergency remix economy

**Files:**
- Create: `src/puzzle/remix_economy.gd`
- Modify: `src/battle/skill_controller.gd:20-45,70-82`
- Modify: `src/ui/battle_screen.gd:35-50,610-625,1058-1067`
- Test: `tests/remix_economy_test.gd`
- Test: `tests/remix_economy_test.tscn`

**Interfaces:**
- Produces: `quote(integrity_status, mix_count, mana) -> Dictionary`, `commit(kind)`, `snapshot()`, and `restore()`.
- Adds `SkillController.spend_mana(amount: int) -> bool`.

- [ ] **Step 1: Write the failing cost test**

```gdscript
extends Node

func _ready() -> void:
	var economy := RemixEconomy.new()
	var first := economy.quote("valid", 0, 0)
	var repeat_blocked := economy.quote("valid", 1, 19)
	var repeat_ready := economy.quote("valid", 1, 20)
	var emergency := economy.quote("recoverable", 9, 0)
	var ok := first.allowed and first.mana == 0 and not repeat_blocked.allowed \
			and repeat_ready.mana == 20 and emergency.allowed and emergency.mana == 0
	print("PASS  remix costs are fair" if ok else "FAIL  remix economy")
	get_tree().quit(0 if ok else 1)
```

- [ ] **Step 2: Run and verify RED**

Expected: missing `RemixEconomy`.

- [ ] **Step 3: Implement economy and mana spending**

```gdscript
class_name RemixEconomy
extends RefCounted

var mix_count := 0

func quote(integrity_status: String, used: int, mana: int) -> Dictionary:
	if integrity_status == "recoverable":
		return {"allowed":true,"kind":"emergency","moves":1,"mana":0,
				"caption":"Emergency • 1 Move"}
	var mana_cost := 0 if used == 0 else 20
	return {"allowed":mana >= mana_cost,"kind":"standard","moves":1,"mana":mana_cost,
			"caption":"1 Move" if mana_cost == 0 else "1 Move + 20 Mana"}

func commit(_kind: String) -> void:
	mix_count += 1

func snapshot() -> Dictionary: return {"mix_count":mix_count}
func restore(data: Dictionary) -> void: mix_count = maxi(int(data.get("mix_count", 0)), 0)
```

Add to `SkillController`:

```gdscript
func spend_mana(amount: int) -> bool:
	var cost := maxi(amount, 0)
	if mana < cost: return false
	mana -= cost
	mana_changed.emit(mana, 100)
	return true
```

Battle integration must quote before tapping, deduct mana only after a successful current-generation remix, then consume exactly one `battle.on_move()`.

- [ ] **Step 4: Verify remix, snapshot, and action-copy tests**

Expected: emergency with zero mana succeeds; failed worker charges nothing; resumed battle restores mix count and button caption.

- [ ] **Step 5: Commit**

```powershell
git add src/puzzle/remix_economy.gd src/battle/skill_controller.gd src/ui/battle_screen.gd tests/remix_economy_test.*
git commit -m "gameplay: make remix recovery tactical and fair"
```

### Task 4: Area mastery and weekly seeded challenge

**Files:**
- Modify: `src/autoload/save_system.gd:8-45,80-165`
- Modify: `src/run/meta_progression.gd`
- Modify: `src/autoload/run_state.gd:70-125,430-470`
- Modify: `src/ui/area_select_screen.gd:20-60`
- Test: `tests/mastery_weekly_test.gd`
- Test: `tests/mastery_weekly_test.tscn`

**Interfaces:**
- Produces: `MetaProgression.add_area_mastery(area_id, xp)`, `area_mastery(area_id)`, `weekly_seed(week_text)`, `weekly_record(week_text, summary)`.
- Save version increments from 8 to 9 with `area_mastery`, `weekly_records`, and `seen_scroll_cues` defaults.

- [ ] **Step 1: Write failing migration and deterministic-seed tests**

```gdscript
extends Node

func _ready() -> void:
	var migrated := SaveSystem.migrate({"version":8,"settings":{},"active_run":{}})
	var meta := MetaProgression.new()
	var seed_a := meta.weekly_seed("2026-W29")
	var seed_b := meta.weekly_seed("2026-W29")
	var ok := migrated.has("area_mastery") and migrated.has("weekly_records") \
			and migrated.has("seen_scroll_cues") and seed_a == seed_b and seed_a != 0
	print("PASS  mastery weekly migration" if ok else "FAIL  mastery weekly")
	get_tree().quit(0 if ok else 1)
```

- [ ] **Step 2: Run and verify RED**

Expected: missing version-9 fields or weekly method.

- [ ] **Step 3: Add migration and progression APIs**

```gdscript
func weekly_seed(week_text: String) -> int:
	return absi(("POTION_ROGUE_WEEKLY_V1:" + week_text).hash()) + 1

func area_mastery(area_id: String) -> int:
	return maxi(int((SaveSystem.data.get("area_mastery", {}) as Dictionary).get(area_id, 0)), 0)

func add_area_mastery(area_id: String, amount: int) -> int:
	var mastery: Dictionary = SaveSystem.data.get("area_mastery", {}).duplicate(true)
	mastery[area_id] = area_mastery(area_id) + maxi(amount, 0)
	SaveSystem.data["area_mastery"] = mastery
	SaveSystem.save()
	return int(mastery[area_id])

func weekly_record(week_text: String, summary: Dictionary) -> void:
	var records: Dictionary = SaveSystem.data.get("weekly_records", {}).duplicate(true)
	var score := int(summary.get("score", 0))
	if score > int(records.get(week_text, {}).get("score", -1)):
		records[week_text] = summary.duplicate(true)
	SaveSystem.data["weekly_records"] = records
	SaveSystem.save()
```

Add the version-9 defaults and migration. Award mastery from existing battle/area completion boundaries; add a local weekly button beside Daily that starts a fixed seed and stores only local best results.

- [ ] **Step 4: Run save, meta, campaign, and deterministic tests**

Expected: old saves migrate, same ISO week produces the same graph, and no online leaderboard wording appears.

- [ ] **Step 5: Commit**

```powershell
git add src/autoload/save_system.gd src/run/meta_progression.gd src/autoload/run_state.gd src/ui/area_select_screen.gd tests/mastery_weekly_test.*
git commit -m "progression: add realm mastery and weekly runs"
```
