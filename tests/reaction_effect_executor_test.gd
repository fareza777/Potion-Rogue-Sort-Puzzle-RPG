extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	RunState.start_new_run("ember_adept")
	var battle := BattleManager.new()
	add_child(battle)
	battle.setup("slime")
	var executor := ReactionEffectExecutor.new()

	var hp_before := battle.enemy_hp
	var fire := executor.apply({"id":"fire_burst", "effect":"damage_multiplier",
			"value":1.5}, battle)
	check(bool(fire.get("ok", false)) and battle.enemy_hp == hp_before - 10,
			"Fire Burst adds half of base Fire damage exactly once")

	battle.player_hp = 20
	battle.shield = 0
	var barrier := executor.apply({"id":"restorative_barrier",
			"effect":"heal_and_shield", "heal":5, "shield":4}, battle)
	check(bool(barrier.get("ok", false)) and battle.player_hp == 25
			and battle.shield == 4, "Restorative Barrier applies exact values")

	battle.poison_damage = 5
	battle.poison_turns = 3
	var poison := executor.apply({"id":"toxic_detonation",
			"effect":"consume_poison"}, battle)
	check(bool(poison.get("ok", false)) and int(poison.get("damage", 0)) == 15
			and battle.poison_turns == 0, "Toxic Detonation consumes poison once")

	var unknown := executor.apply({"id":"broken", "effect":"not_registered"}, battle)
	check(not bool(unknown.get("ok", true)) and str(unknown.get("reason", "")) \
			== "unknown_effect", "unknown effect fails safely")

	var source := FileAccess.get_file_as_string("res://src/battle/battle_manager.gd")
	check(not source.contains('_last_potion =='),
			"legacy hidden combo branches are removed")

	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("PASS  " + label)
	else:
		failures += 1
		push_error("FAIL  " + label)
