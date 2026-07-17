extends Node
## Headless contracts for generated encounter data.

var _failures := 0
var _checks := 0


func _ready() -> void:
	_test_contract_validation()
	_test_objectives()
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


func check(condition: bool, what: String) -> void:
	_checks += 1
	if condition:
		print("PASS  ", what)
	else:
		_failures += 1
		print("FAIL  ", what)
