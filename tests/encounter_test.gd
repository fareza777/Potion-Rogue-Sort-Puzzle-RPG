extends Node
## Headless contracts for generated encounter data.

var _failures := 0
var _checks := 0


func _ready() -> void:
	_test_contract_validation()
	_test_objectives()
	_test_enemy_intents()
	_test_expanded_roster()
	print("---")
	print("%d checks, %d failures" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _test_contract_validation() -> void:
	var valid := EncounterContract.from_dict({
		"seed": 42,
		"enemy": "slime",
		"objective": "defeat",
		"modifiers": ["hidden_layer"],
		"reward_mult": 1.0,
		"kind": "battle",
	})
	check(valid.is_valid(), "valid encounter contract")
	check(valid.seed == 42 and valid.modifier_ids == (["hidden_layer"] as Array[String]),
			"contract preserves typed encounter data")

	var fallback := EncounterContract.from_dict({
		"enemy": "missing_enemy",
		"objective": "missing_objective",
		"modifiers": ["hidden_layer", "missing_modifier"],
		"reward_mult": 99.0,
		"kind": "unknown",
	})
	check(fallback.enemy_id == "slime", "invalid enemy uses slime fallback")
	check(fallback.objective_id == "defeat", "invalid objective uses defeat fallback")
	check(fallback.modifier_ids == (["hidden_layer"] as Array[String]),
			"invalid modifiers are discarded")
	check(fallback.reward_mult == 3.0, "reward multiplier is bounded")
	check(fallback.node_kind == "battle", "invalid node kind uses battle fallback")
	check(fallback.is_valid(), "fallback encounter remains valid")


func _test_objectives() -> void:
	var defeat := _objective("defeat")
	defeat.on_enemy_defeated()
	check(defeat.is_completed(), "defeat objective completes on enemy defeat")

	var survive := _objective("survive")
	for i in 2:
		survive.on_enemy_attacked()
	check(not survive.is_completed() and survive.current == 2,
			"survive objective tracks enemy attacks")
	survive.on_enemy_attacked()
	check(survive.is_completed(), "survive objective completes at target")

	var brew := _objective("brew_order")
	brew.on_potion_completed("red")
	brew.on_potion_completed("green")
	check(brew.current == 0, "wrong brew color resets ordered progress")
	for color in ["red", "blue", "purple"]:
		brew.on_potion_completed(color)
	check(brew.is_completed(), "brew order completes exact sequence")

	var armor := _objective("armor_break")
	armor.on_armor_damaged(7)
	armor.on_armor_damaged(13)
	check(armor.is_completed(), "armor objective accumulates broken armor")

	var cleanse := _objective("cleanse")
	var completions := [0]
	cleanse.completed.connect(func() -> void: completions[0] += 1)
	cleanse.on_curse_cleansed(2)
	cleanse.on_curse_cleansed(1)
	cleanse.on_curse_cleansed(5)
	check(cleanse.is_completed() and completions[0] == 1,
			"objective completion emits exactly once")


func _objective(id: String) -> ObjectiveController:
	var objective := ObjectiveController.new()
	objective.configure(id, GameState.objectives[id])
	return objective


func _test_enemy_intents() -> void:
	var pool := {
		"intent_pool": [
			{"id": "attack", "weight": 2},
			{"id": "guard", "weight": 1},
			{"id": "lock", "weight": 1},
		]
	}
	var first := EnemyIntentController.new()
	var second := EnemyIntentController.new()
	first.configure("skeleton", pool, 77)
	second.configure("skeleton", pool, 77)
	var first_order: Array[String] = []
	var second_order: Array[String] = []
	for i in 8:
		first_order.append(str(first.preview().get("id", "")))
		second_order.append(str(second.preview().get("id", "")))
		first.advance()
		second.advance()
	check(first_order == second_order, "intent order is deterministic for a seed")

	var battle := _fresh_battle("skeleton")
	var attack := EnemyIntentController.new()
	attack.configure("skeleton", {"intent_pool": [{"id": "attack", "weight": 1}]}, 5)
	attack.set_battle_values(battle.enemy_attack, 0.25, battle.moves_until_attack)
	var preview := attack.preview()
	var hp_before := battle.player_hp
	attack.resolve(battle, null)
	var received := hp_before - battle.player_hp
	check(received >= int(preview.damage_min) and received <= int(preview.damage_max),
			"attack resolution stays inside previewed damage range")
	battle.free()

	var ability_battle := _fresh_battle("slime")
	var locked := [0]
	var corrupted := [0]
	ability_battle.tube_lock_requested.connect(func(_moves: int) -> void: locked[0] += 1)
	ability_battle.board_hazard_requested.connect(func(_command: Dictionary) -> void:
		corrupted[0] += 1)
	for id in ["guard", "lock", "poison", "corruption", "enrage"]:
		var controller := EnemyIntentController.new()
		controller.configure("slime", {"intent_pool": [{"id": id, "weight": 1}]}, 1)
		controller.set_battle_values(ability_battle.enemy_attack, 0.0, 3)
		controller.resolve(ability_battle, null)
	check(ability_battle.enemy_armor >= 8, "guard intent grants enemy armor")
	check(locked[0] == 1, "lock intent requests a tube lock")
	check(ability_battle.player_poison_turns == 2, "poison intent applies player poison")
	check(corrupted[0] == 1, "corruption intent requests a board hazard")
	check(ability_battle.enemy_attack > 5, "enrage intent increases enemy attack")
	ability_battle.free()


func _fresh_battle(enemy_id: String) -> BattleManager:
	RunState.start_new_run()
	var battle := BattleManager.new()
	add_child(battle)
	battle.setup(enemy_id)
	return battle


func _test_expanded_roster() -> void:
	check(GameState.enemies.size() == 42, "roster contains forty-two enemies")
	for family in ["crypt", "fungal", "arcane", "infernal"]:
		var illustrated := 0
		for enemy in GameState.enemies.values():
			if (str(enemy.get("family", "")) == family
					and not str(enemy.get("sprite", "")).is_empty()
					and not enemy.has("atlas")):
				illustrated += 1
		check(illustrated == 5, family + " has five individual enemy sprites")
	for enemy_id in GameState.enemies:
		var enemy: Dictionary = GameState.enemies[enemy_id]
		check(int(enemy.get("tier", 0)) in [1, 2, 3, 4], "enemy tier: " + str(enemy_id))
		check(not str(enemy.get("family", "")).is_empty(), "enemy family: " + str(enemy_id))
	var effect_battle := _fresh_battle("slime")
	effect_battle.shield = 12
	check(effect_battle.shatter_player_shield(10) == 10 and effect_battle.shield == 2,
			"shatter intent removes previewed shield")
	effect_battle.enemy_hp = 30
	check(effect_battle.heal_enemy(8) == 8 and effect_battle.enemy_hp == 38,
			"drain and heal intents restore enemy vitality")
	effect_battle.free()


func check(condition: bool, what: String) -> void:
	_checks += 1
	if condition:
		print("PASS  ", what)
	else:
		_failures += 1
		print("FAIL  ", what)
