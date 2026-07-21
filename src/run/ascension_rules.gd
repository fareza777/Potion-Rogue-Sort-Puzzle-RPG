class_name AscensionRules
extends RefCounted
## Runtime reader for data/ascension_rules.json. Rules are CUMULATIVE: playing
## Ascension N applies every rule from 1 to N, so each level is strictly harder
## than the last and the authored identities all stay relevant.

const NUMERIC_MULT_KEYS := ["enemy_hp_mult", "recovery_mult", "enemy_armor_mult"]
const NUMERIC_ADD_KEYS := ["enemy_damage_add", "elite_delay_add",
		"boss_damage_add", "extra_modifier", "reward_curse", "late_hidden_layer"]

var _rules: Dictionary = {}


func _init() -> void:
	_rules = GameState.load_data_file("ascension_rules.json", {})


## Merged cumulative effects for levels 1..level. Multipliers multiply,
## additive keys sum. Level 0 returns all-neutral values.
func active(level: int) -> Dictionary:
	var merged := {}
	for key in NUMERIC_MULT_KEYS:
		merged[key] = 1.0
	for key in NUMERIC_ADD_KEYS:
		merged[key] = 0
	for step in range(1, clampi(level, 0, 10) + 1):
		var rule: Dictionary = _rules.get(str(step), {})
		for key in NUMERIC_MULT_KEYS:
			if rule.has(key):
				merged[key] = float(merged[key]) * float(rule[key])
		for key in NUMERIC_ADD_KEYS:
			if rule.has(key):
				merged[key] = int(merged[key]) + int(rule[key])
	return merged


func multiplier(level: int, key: String) -> float:
	return float(active(level).get(key, 1.0))


func addition(level: int, key: String) -> int:
	return int(active(level).get(key, 0))


## Names of every rule active at the given level, for honest UI labeling.
func active_names(level: int) -> Array[String]:
	var names: Array[String] = []
	for step in range(1, clampi(level, 0, 10) + 1):
		var rule: Dictionary = _rules.get(str(step), {})
		if rule.has("name"):
			names.append(str(rule.name))
	return names


func description(level: int) -> String:
	return str(_rules.get(str(level), {}).get("description", ""))
