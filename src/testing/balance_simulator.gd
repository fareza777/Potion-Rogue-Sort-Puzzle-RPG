class_name BalanceSimulator
extends RefCounted
## Deterministic, save-safe balance probes built from the production board rules.

const CAPACITY := BoardSolver.DEFAULT_CAPACITY
const MAX_BOARD_MOVES := 128
const MAX_ENCOUNTER_MOVES := 256
const BOARD_SEED_STEP := 104729

# BoardFactory's template has a finite set of shuffled layouts. Cache the
# solver-driven playthrough by layout, while still generating every requested
# seed through the production factory before looking it up.
static var _board_result_cache: Dictionary = {}


## Plays one factory board with a deterministic legal-pour heuristic. Every
## selected move reduces the production solver's distance estimate.
static func simulate_board(seed: int, band: String) -> Dictionary:
	var generated := BoardFactory.generate(seed, band)
	var state := _copy_state(generated.get("state", []))
	var cache_key := band + "|" + JSON.stringify(state)
	if _board_result_cache.has(cache_key):
		var cached: Dictionary = (_board_result_cache[cache_key] as Dictionary).duplicate(true)
		cached.seed = seed
		return cached
	var analysis: Dictionary = (generated.get("analysis", {}) as Dictionary).duplicate(true)
	if not bool(analysis.get("solvable", false)):
		return _dead_board_result(seed, band, analysis)
	var moves := 0
	var completions: Array[Dictionary] = []
	while int(analysis.get("estimated_moves", -1)) > 0 and moves < MAX_BOARD_MOVES:
		var choice := _best_legal_pour(state, analysis)
		if choice.is_empty():
			return _dead_board_result(seed, band, analysis, moves, completions)
		var completed := _pour(state, choice.move)
		moves += 1
		if not completed.is_empty():
			completions.append({"move": moves, "color": completed})
		analysis = BoardSolver.analyze(state)
	if int(analysis.get("estimated_moves", -1)) != 0:
		return _dead_board_result(seed, band, analysis, moves, completions)
	var result := {
		"seed": seed,
		"band": band,
		"solved": true,
		"dead_board": false,
		"moves": moves,
		"completions": completions,
		"solver_moves": int(generated.get("analysis", {}).get("estimated_moves", -1)),
		"visited_states": int(analysis.get("visited_states", 0)),
	}
	_board_result_cache[cache_key] = result.duplicate(true)
	return result


## Simulates repeated real board solves against a local, deterministic combat
## model. It reads authored enemy/area data but never starts a run or mutates
## SaveSystem / RunState.
static func simulate_encounter(enemy_id: String, area_id: String, ascension: int,
		seeds: int) -> Dictionary:
	var requested_samples := maxi(seeds, 0)
	var defeated_early := 0
	var dead_boards := 0
	var total_moves := 0
	var total_hp_delta := 0
	for sample in requested_samples:
		var result := _simulate_encounter_sample(enemy_id, area_id, ascension, sample)
		if bool(result.get("defeated", false)):
			defeated_early += 1
		if bool(result.get("dead_board", false)):
			dead_boards += 1
		total_moves += int(result.get("moves", 0))
		total_hp_delta += int(result.get("hp_delta", 0))
	return {
		"enemy_id": _valid_enemy_id(enemy_id),
		"area_id": _valid_area_id(area_id),
		"ascension": clampi(ascension, 0, 10),
		"samples": requested_samples,
		"early_defeat_rate": _ratio(defeated_early, requested_samples),
		"mean_moves": _mean(total_moves, requested_samples),
		"mean_hp_delta": _mean(total_hp_delta, requested_samples),
		"dead_board_rate": _ratio(dead_boards, requested_samples),
	}


## Samples each requested area at every requested Ascension with that area's
## authored boss, which makes the matrix a compact realm-level regression lab.
static func matrix(area_ids: Array[String], ascensions: Array[int], seed_count: int) -> Dictionary:
	var rows: Array[Dictionary] = []
	for raw_area_id in area_ids:
		var area_id := _valid_area_id(raw_area_id)
		var area := GameState.area(area_id)
		var enemy_id := _valid_enemy_id(str(area.get("boss", "slime")))
		for ascension in ascensions:
			rows.append(simulate_encounter(enemy_id, area_id, ascension, seed_count))
	return {"samples": rows.size(), "seed_count": maxi(seed_count, 0), "rows": rows}


static func _simulate_encounter_sample(enemy_id: String, area_id: String,
		ascension: int, sample: int) -> Dictionary:
	var id := _valid_enemy_id(enemy_id)
	var area := GameState.area(_valid_area_id(area_id))
	var enemy: Dictionary = GameState.enemies.get(id, GameState.DEFAULT_ENEMIES["slime"])
	var tier := clampi(int(enemy.get("tier", 1)), 1, 4)
	var budget := ThreatBudget.new().for_node(tier + 1,
			"elite" if tier >= 4 else "battle", area.get("threat_multiplier", 1.0),
			clampi(ascension, 0, 10))
	var scale := float(budget.get("enemy_scale", 1.0))
	var combat := {
		"player_hp": int(GameState.player.get("max_hp", 50)),
		"player_max_hp": int(GameState.player.get("max_hp", 50)),
		"shield": 0,
		"enemy_hp": roundi(float(enemy.get("hp", 60)) * scale),
		"enemy_max_hp": roundi(float(enemy.get("hp", 60)) * scale),
		"enemy_armor": int(enemy.get("armor", 0)),
		"enemy_attack": roundi(float(enemy.get("attack", 8)) * (1.0 + (scale - 1.0) * 0.35)),
		"crit_chance": clampf(float(enemy.get("crit_chance", 0.0)), 0.0, 1.0),
		"moves_until_attack": maxi(int(enemy.get("attack_every", 3)), 1),
		"attack_every": maxi(int(enemy.get("attack_every", 3)), 1),
		"poison_damage": 0, "poison_turns": 0,
		"player_poison_damage": 0, "player_poison_turns": 0,
		"last_potion": "", "attacks_done": 0, "enraged": false,
		"enrage_multiplier": float((enemy.get("enrage", {}) as Dictionary).get("attack_mult", 1.5)),
		"poison_player": (enemy.get("poison_player", {}) as Dictionary).duplicate(true),
	}
	var intent := EnemyIntentController.new()
	intent.configure(id, enemy, _stable_seed(id + area_id, ascension, sample))
	var rng := RandomNumberGenerator.new()
	rng.seed = _stable_seed(area_id + id, ascension, sample)
	var moves := 0
	var board_index := 0
	var dead_board := false
	while int(combat.enemy_hp) > 0 and int(combat.player_hp) > 0 and moves < MAX_ENCOUNTER_MOVES:
		var board_seed := _stable_seed(id + area_id, ascension, sample) + board_index * BOARD_SEED_STEP
		var board := simulate_board(board_seed, "standard")
		if not bool(board.get("solved", false)):
			dead_board = true
			break
		var events: Array = board.get("completions", [])
		var completion_at := {}
		for event in events:
			completion_at[int(event.get("move", 0))] = str(event.get("color", ""))
		for board_move in int(board.get("moves", 0)):
			moves += 1
			_advance_turn(combat, intent, rng)
			if int(combat.player_hp) <= 0 or int(combat.enemy_hp) <= 0:
				break
			if completion_at.has(board_move + 1):
				_apply_potion(combat, str(completion_at[board_move + 1]))
			if int(combat.player_hp) <= 0 or int(combat.enemy_hp) <= 0 or moves >= MAX_ENCOUNTER_MOVES:
				break
		board_index += 1
	var hp_delta := int(combat.player_hp) - int(combat.player_max_hp)
	return {"defeated": int(combat.player_hp) <= 0, "dead_board": dead_board,
			"moves": moves, "hp_delta": hp_delta}


static func _advance_turn(combat: Dictionary, intent: EnemyIntentController,
		rng: RandomNumberGenerator) -> void:
	combat.moves_until_attack = int(combat.moves_until_attack) - 1
	if int(combat.moves_until_attack) > 0:
		return
	combat.moves_until_attack = int(combat.attack_every)
	if int(combat.poison_turns) > 0:
		_damage_enemy(combat, int(combat.poison_damage), true)
		combat.poison_turns = int(combat.poison_turns) - 1
		if int(combat.poison_turns) == 0:
			combat.poison_damage = 0
	if int(combat.enemy_hp) <= 0:
		return
	if int(combat.player_poison_turns) > 0:
		combat.player_hp = maxi(int(combat.player_hp) - int(combat.player_poison_damage), 0)
		combat.player_poison_turns = int(combat.player_poison_turns) - 1
		if int(combat.player_poison_turns) == 0:
			combat.player_poison_damage = 0
	if int(combat.player_hp) <= 0:
		return
	intent.set_battle_values(int(combat.enemy_attack), 0.0, int(combat.attack_every))
	var config: Dictionary = GameState.intents.get(str(intent.preview().get("id", "attack")), {})
	for action in config.get("actions", []):
		_apply_enemy_action(combat, action, rng)
		if int(combat.player_hp) <= 0:
			break
	intent.advance()
	var poison_player: Dictionary = combat.poison_player
	var every := int(poison_player.get("every_attacks", 0))
	if every > 0 and int(combat.attacks_done) > 0 and int(combat.attacks_done) % every == 0:
		combat.player_poison_damage = maxi(int(poison_player.get("damage", 3)), 0)
		combat.player_poison_turns = maxi(int(poison_player.get("turns", 2)), 0)


static func _apply_enemy_action(combat: Dictionary, action: Dictionary,
		rng: RandomNumberGenerator) -> void:
	match str(action.get("type", "")):
		"attack":
			var damage := int(float(combat.enemy_attack) * maxf(float(action.get("multiplier", 1.0)), 0.0))
			if rng.randf() < float(combat.crit_chance):
				damage = int(damage * 1.5)
			var blocked := mini(int(combat.shield), damage)
			combat.shield = int(combat.shield) - blocked
			combat.player_hp = maxi(int(combat.player_hp) - (damage - blocked), 0)
			combat.attacks_done = int(combat.attacks_done) + 1
		"armor": combat.enemy_armor = int(combat.enemy_armor) + maxi(int(action.get("amount", 0)), 0)
		"poison":
			combat.player_poison_damage = maxi(int(action.get("damage", 3)), 0)
			combat.player_poison_turns = maxi(int(action.get("turns", 2)), 0)
		"enrage": combat.enemy_attack = maxi(int(ceil(float(combat.enemy_attack) * maxf(float(action.get("multiplier", 1.25)), 1.0))), 1)
		"heal": combat.enemy_hp = mini(int(combat.enemy_hp) + maxi(int(action.get("amount", 0)), 0), int(combat.enemy_max_hp))
		"shield_break": combat.shield = maxi(int(combat.shield) - maxi(int(action.get("amount", 0)), 0), 0)


static func _apply_potion(combat: Dictionary, color: String) -> void:
	match color:
		"red":
			var damage := 20
			if str(combat.last_potion) == "red":
				damage = int(damage * 1.5)
			elif str(combat.last_potion) == "blue" and int(combat.shield) > 0:
				var converted := int(combat.shield) / 2
				combat.shield = int(combat.shield) - converted
				damage += converted
			elif str(combat.last_potion) == "purple" and int(combat.poison_turns) > 0:
				damage += int(combat.poison_damage) * int(combat.poison_turns)
				combat.poison_damage = 0
				combat.poison_turns = 0
			_damage_enemy(combat, damage, false)
		"green": combat.player_hp = mini(int(combat.player_hp) + 15, int(combat.player_max_hp))
		"blue": combat.shield = mini(int(combat.shield) + 12, int(GameState.player.get("max_shield", 30)))
		"purple":
			combat.poison_damage = 5
			combat.poison_turns = 3
	combat.last_potion = color


static func _damage_enemy(combat: Dictionary, amount: int, bypass_armor: bool) -> void:
	var remaining := maxi(amount, 0)
	if not bypass_armor:
		var absorbed := mini(int(combat.enemy_armor), remaining)
		combat.enemy_armor = int(combat.enemy_armor) - absorbed
		remaining -= absorbed
	combat.enemy_hp = maxi(int(combat.enemy_hp) - remaining, 0)
	if not bool(combat.enraged) and int(combat.enemy_hp) > 0 \
			and float(combat.enemy_hp) / float(maxi(int(combat.enemy_max_hp), 1)) <= 0.4:
		combat.enraged = true
		combat.enemy_attack = maxi(int(float(combat.enemy_attack)
				* float(combat.enrage_multiplier)), 1)


static func _best_legal_pour(state: Array, current: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := int(current.get("estimated_moves", 1_000_000))
	var target_distance := best_distance - 1
	for move in _legal_moves(state):
		var candidate := _copy_state(state)
		_pour(candidate, move)
		var analysis := BoardSolver.analyze(candidate)
		var distance := int(analysis.get("estimated_moves", -1))
		if bool(analysis.get("solvable", false)) and distance >= 0 and distance < best_distance:
			best = {"move": move, "analysis": analysis}
			best_distance = distance
			# A shortest-path reduction is optimal. Returning immediately keeps the
			# 5,000-board local sweep practical without weakening the solver rule.
			if distance == target_distance:
				return best
	return best


static func _legal_moves(state: Array) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	for from_index in state.size():
		var source: Array = state[from_index]
		if source.is_empty():
			continue
		for to_index in state.size():
			if from_index == to_index:
				continue
			var destination: Array = state[to_index]
			if destination.size() < CAPACITY and (destination.is_empty() or str(destination.back()) == str(source.back())):
				moves.append(Vector2i(from_index, to_index))
	return moves


static func _pour(state: Array, move: Vector2i) -> String:
	var source: Array = state[move.x]
	var destination: Array = state[move.y]
	var color := str(source.back())
	var run := 0
	for index in range(source.size() - 1, -1, -1):
		if str(source[index]) != color:
			break
		run += 1
	for _unit in mini(run, CAPACITY - destination.size()):
		destination.append(source.pop_back())
	if destination.size() == CAPACITY and str(destination[0]) == str(destination.back()):
		for value in destination:
			if str(value) != color:
				return ""
		destination.clear()
		return color
	return ""


static func _dead_board_result(seed: int, band: String, analysis: Dictionary,
		moves := 0, completions: Array = []) -> Dictionary:
	return {"seed": seed, "band": band, "solved": false, "dead_board": true,
		"moves": moves, "completions": completions,
		"solver_moves": int(analysis.get("estimated_moves", -1)),
		"visited_states": int(analysis.get("visited_states", 0))}


static func _copy_state(state: Array) -> Array:
	var copy: Array = []
	for tube in state:
		var raw_tube: Array = tube
		copy.append(raw_tube.duplicate())
	return copy


static func _valid_enemy_id(enemy_id: String) -> String:
	return enemy_id if GameState.enemies.has(enemy_id) else "slime"


static func _valid_area_id(area_id: String) -> String:
	return area_id if GameState.areas.has(area_id) else "shadow_crypt"


static func _stable_seed(text: String, ascension: int, sample: int) -> int:
	var value := 17 + clampi(ascension, 0, 10) * 101 + sample * 7919
	for index in text.length():
		value = (value * 31 + text.unicode_at(index)) % 2147483647
	return value


static func _ratio(numerator: int, denominator: int) -> float:
	return float(numerator) / float(denominator) if denominator > 0 else 0.0


static func _mean(total: int, count: int) -> float:
	return float(total) / float(count) if count > 0 else 0.0
