class_name EncounterContract
extends RefCounted
## Validated, presentation-independent description of one dungeon encounter.

const VALID_NODE_KINDS: Array[String] = ["battle", "elite", "boss"]

var seed := 0
var enemy_id := "slime"
var objective_id := "defeat"
var modifier_ids: Array[String] = []
var reward_mult := 1.0
var node_kind := "battle"
var profile: Dictionary = {}


static func from_dict(raw: Dictionary) -> EncounterContract:
	var result := EncounterContract.new()
	result.seed = int(raw.get("seed", 0))
	result.enemy_id = str(raw.get("enemy", "slime"))
	if not GameState.enemies.has(result.enemy_id):
		result.enemy_id = "slime"

	result.objective_id = str(raw.get("objective", "defeat"))
	if not GameState.objectives.has(result.objective_id):
		result.objective_id = "defeat"

	var raw_modifiers: Array = raw.get("modifiers", [])
	for value in raw_modifiers:
		var modifier_id := str(value)
		if GameState.modifiers.has(modifier_id) and not modifier_id in result.modifier_ids:
			result.modifier_ids.append(modifier_id)

	result.reward_mult = clampf(float(raw.get("reward_mult", 1.0)), 0.5, 3.0)
	result.node_kind = str(raw.get("kind", "battle"))
	if not result.node_kind in VALID_NODE_KINDS:
		result.node_kind = "battle"
	result.profile = (raw.get("profile", {}) as Dictionary).duplicate(true)
	return result


func is_valid() -> bool:
	return GameState.enemies.has(enemy_id) \
			and GameState.objectives.has(objective_id) \
			and node_kind in VALID_NODE_KINDS


func to_dict() -> Dictionary:
	return {
		"seed": seed,
		"enemy": enemy_id,
		"objective": objective_id,
		"modifiers": modifier_ids.duplicate(),
		"reward_mult": reward_mult,
		"kind": node_kind,
		"profile": profile.duplicate(true),
	}
