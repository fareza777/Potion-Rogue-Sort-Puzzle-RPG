class_name EnemyIntentController
extends RefCounted
## Seeded enemy action selection with a stable preview until resolution.

var enemy_id := "slime"

var _rng := RandomNumberGenerator.new()
var _pool: Array[Dictionary] = []
var _current: Dictionary = {}
var _attack := 0
var _crit_chance := 0.0
var _moves := 3


func configure(id: String, enemy_config: Dictionary, seed: int) -> void:
	enemy_id = id
	_rng.seed = seed
	_pool.clear()
	for raw_entry in enemy_config.get("intent_pool", []):
		if typeof(raw_entry) == TYPE_STRING:
			_pool.append({"id": str(raw_entry), "weight": 1})
		elif typeof(raw_entry) == TYPE_DICTIONARY:
			var entry: Dictionary = raw_entry
			var intent_id := str(entry.get("id", ""))
			if GameState.intents.has(intent_id):
				_pool.append({
					"id": intent_id,
					"weight": maxi(int(entry.get("weight", 1)), 1),
				})
	if _pool.is_empty():
		_pool.append({"id": "attack", "weight": 1})
	_pick_next()


func set_battle_values(attack: int, crit_chance: float, moves: int) -> void:
	_attack = maxi(attack, 0)
	_crit_chance = clampf(crit_chance, 0.0, 1.0)
	_moves = maxi(moves, 0)


func preview() -> Dictionary:
	var intent_id := str(_current.get("id", "attack"))
	var config: Dictionary = GameState.intents.get(intent_id, {})
	var multiplier := _attack_multiplier(config)
	var minimum := int(floor(_attack * multiplier)) if multiplier > 0.0 else 0
	var maximum := int(ceil(minimum * 1.5)) if _crit_chance > 0.0 else minimum
	return {
		"id": intent_id,
		"label": str(config.get("label", intent_id.capitalize())),
		"icon": str(config.get("icon", intent_id)),
		"damage_min": minimum,
		"damage_max": maximum,
		"moves": _moves,
		"reaction_counter": (config.get("reaction_counter", {}) as Dictionary).duplicate(true),
	}


func resolve(battle: BattleManager, board: PuzzleBoard) -> void:
	var intent_id := str(_current.get("id", "attack"))
	var config: Dictionary = GameState.intents.get(intent_id, {})
	for raw_action in config.get("actions", []):
		var action: Dictionary = raw_action
		match str(action.get("type", "")):
			"attack":
				battle.resolve_enemy_attack(float(action.get("multiplier", 1.0)))
			"armor":
				battle.add_enemy_armor(int(action.get("amount", 0)))
			"lock":
				battle.request_tube_lock(int(action.get("moves", 2)))
			"poison":
				battle.apply_player_poison(int(action.get("damage", 3)),
						int(action.get("turns", 2)))
			"corruption":
				var command := {"id": "corruption",
						"count": int(action.get("count", 1)), "seed": int(_rng.state)}
				if board != null:
					var result := BoardActionResolver.new().apply(command, board)
					if not bool(result.get("applied", false)):
						battle.request_board_hazard({"type": "hazard_failed",
								"reason": str(result.get("reason", "Corruption failed"))})
				else:
					battle.request_board_hazard(command)
			"enrage":
				battle.empower_enemy_attack(float(action.get("multiplier", 1.25)))
			"heal":
				battle.heal_enemy(int(action.get("amount", 0)))
			"shield_break":
				battle.shatter_player_shield(int(action.get("amount", 0)))
	battle.complete_enemy_action(intent_id)


func advance() -> void:
	_pick_next()


func _pick_next() -> void:
	var total := 0
	for entry in _pool:
		total += int(entry.weight)
	var roll := _rng.randi_range(1, maxi(total, 1))
	var running := 0
	for entry in _pool:
		running += int(entry.weight)
		if roll <= running:
			_current = entry.duplicate(true)
			return
	_current = _pool[0].duplicate(true)


func _attack_multiplier(config: Dictionary) -> float:
	for raw_action in config.get("actions", []):
		var action: Dictionary = raw_action
		if str(action.get("type", "")) == "attack":
			return maxf(float(action.get("multiplier", 1.0)), 0.0)
	return 0.0


func snapshot() -> Dictionary:
	return {"enemy_id": enemy_id, "current": _current.duplicate(true), "rng_state": _rng.state}


func restore(snapshot_data: Dictionary) -> void:
	if str(snapshot_data.get("enemy_id", "")) != enemy_id:
		return
	_current = (snapshot_data.get("current", _current) as Dictionary).duplicate(true)
	_rng.state = int(snapshot_data.get("rng_state", _rng.state))
