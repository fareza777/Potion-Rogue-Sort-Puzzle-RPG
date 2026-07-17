extends Node
## Headless contracts for generated encounter data.

var _failures := 0
var _checks := 0


func _ready() -> void:
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

	print("---")
	print("%d checks, %d failures" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func check(condition: bool, what: String) -> void:
	_checks += 1
	if condition:
		print("PASS  ", what)
	else:
		_failures += 1
		print("FAIL  ", what)
