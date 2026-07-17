class_name RunGenerator
extends RefCounted

const FLOOR_COUNT := 7
const SAFE_KINDS := ["battle", "event", "shop", "treasure", "campfire"]
const REGULAR_KINDS := ["battle", "battle", "battle", "event", "shop", "treasure", "campfire", "elite"]
const INTRO_MODIFIERS := ["hidden_layer", "frozen_tube"]
const ADVANCED_MODIFIERS := ["cursed_layer", "volatile_liquid", "wild_essence", "chain_lock", "corruption", "unstable_flask"]


func generate(seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var nodes: Array = [_node("f0_l1", 0, 1, "start", "slime")]
	var expanded_floors: Array[int] = []
	var extra_count := rng.randi_range(0, 3)
	while expanded_floors.size() < extra_count:
		var candidate := rng.randi_range(1, 5)
		if candidate not in expanded_floors:
			expanded_floors.append(candidate)
	var previous_safe_lane := 1
	for floor in range(1, 6):
		var lanes := _lanes_for_floor(rng, floor in expanded_floors)
		var safe_lane: int = lanes[rng.randi_range(0, lanes.size() - 1)]
		# Keep a continuous non-elite route within one lane step.
		var nearest_distance := 99
		for lane in lanes:
			var distance: int = absi(int(lane) - previous_safe_lane)
			if distance < nearest_distance:
				nearest_distance = distance
				safe_lane = int(lane)
		previous_safe_lane = safe_lane
		for slot in lanes.size():
			var lane: int = int(lanes[slot])
			var kind := str(SAFE_KINDS[rng.randi_range(0, SAFE_KINDS.size() - 1)]) if lane == safe_lane else str(REGULAR_KINDS[rng.randi_range(0, REGULAR_KINDS.size() - 1)])
			var enemy := _enemy_for_floor(floor, kind, rng)
			var created := _node("f%d_l%d" % [floor, lane], floor, lane, kind, enemy)
			_decorate_contract(created, rng)
			_decorate_event(created, rng)
			nodes.append(created)
	var boss := _node("f6_boss", 6, 1, "boss", "fire_golem")
	boss.contract.objective_id = "defeat"
	nodes.append(boss)
	_link_floors(nodes)
	return {"seed": seed, "nodes": nodes, "start": "f0_l1", "boss": "f6_boss"}


func _lanes_for_floor(rng: RandomNumberGenerator, expanded: bool) -> Array[int]:
	if expanded:
		return [0, 1, 2]
	var pairs: Array = [[0, 1], [1, 2], [0, 2]]
	var picked: Array = pairs[rng.randi_range(0, pairs.size() - 1)]
	return [int(picked[0]), int(picked[1])]


func _enemy_for_floor(floor: int, kind: String, rng: RandomNumberGenerator) -> String:
	var target_tier := clampi(1 + int((floor - 1) / 2), 1, 3)
	if kind == "elite": target_tier = mini(target_tier + 1, 4)
	if floor >= 4 and rng.randf() < 0.35: target_tier = mini(target_tier + 1, 4)
	var candidates: Array[String] = []
	var ids: Array = GameState.enemies.keys()
	ids.sort()
	for raw_id in ids:
		var id := str(raw_id)
		if id == "fire_golem": continue
		if int(GameState.enemies[id].get("tier", 1)) == target_tier:
			candidates.append(id)
	if candidates.is_empty(): return "slime"
	return candidates[rng.randi_range(0, candidates.size() - 1)]


func _node(id: String, floor: int, lane: int, kind: String, enemy: String) -> Dictionary:
	var budget := ThreatBudget.new().for_node(floor, kind)
	return {"id": id, "floor": floor, "lane": lane, "kind": kind,
		"enemy": enemy, "links": [], "visited": false,
		"contract": {"enemy_id": enemy, "objective_id": "defeat",
			"modifier_ids": [], "threat": budget}}


func _decorate_contract(node: Dictionary, rng: RandomNumberGenerator) -> void:
	var kind := str(node.kind)
	var floor := int(node.floor)
	if kind not in ["battle", "elite"]: return
	var pool: Array = INTRO_MODIFIERS.duplicate() if floor <= 2 else ADVANCED_MODIFIERS.duplicate()
	if floor >= 3: pool.append_array(INTRO_MODIFIERS)
	var count := 2 if kind == "elite" else (1 if floor <= 2 else rng.randi_range(1, 2))
	while node.contract.modifier_ids.size() < count:
		var id := str(pool[rng.randi_range(0, pool.size() - 1)])
		if id not in node.contract.modifier_ids: node.contract.modifier_ids.append(id)
	var objectives := ["defeat", "survive", "brew_order"]
	var enemy: Dictionary = GameState.enemies.get(str(node.enemy), {})
	if int(enemy.get("armor", 0)) > 0 or _enemy_has_intent(enemy, "guard"):
		objectives.append("armor_break")
	if "cursed_layer" in node.contract.modifier_ids or "corruption" in node.contract.modifier_ids:
		objectives.append("cleanse")
	node.contract.objective_id = str(objectives[rng.randi_range(0, objectives.size() - 1)])


func _enemy_has_intent(enemy: Dictionary, intent_id: String) -> bool:
	for intent in enemy.get("intent_pool", []):
		if str(intent.get("id", "")) == intent_id: return true
	return false


func _decorate_event(node: Dictionary, rng: RandomNumberGenerator) -> void:
	var kind := str(node.kind)
	match kind:
		"treasure": node.event_id = "cursed_chest"
		"campfire": node.event_id = "ember_camp"
		"shop": node.event_id = "bound_alchemist"
		"event":
			var pool := ["whispering_well", "mirror_cauldron", "bone_oracle"]
			node.event_id = pool[rng.randi_range(0, pool.size() - 1)]


func _link_floors(nodes: Array) -> void:
	var by_floor := {}
	for node in nodes:
		if not by_floor.has(node.floor): by_floor[node.floor] = []
		by_floor[node.floor].append(node)
	for floor in range(FLOOR_COUNT - 1):
		var current: Array = by_floor[floor]
		var next: Array = by_floor[floor + 1]
		for node in current:
			for target in next:
				if current.size() == 1 or next.size() == 1 or absi(int(node.lane) - int(target.lane)) <= 1:
					node.links.append(str(target.id))
			if node.links.is_empty():
				var nearest: Dictionary = next[0]
				for target in next:
					if absi(int(target.lane) - int(node.lane)) < absi(int(nearest.lane) - int(node.lane)):
						nearest = target
				node.links.append(str(nearest.id))
		# Guarantee that every generated choice is reachable from the prior floor.
		for target in next:
			var has_incoming := false
			for node in current:
				if str(target.id) in node.links: has_incoming = true
			if not has_incoming:
				var nearest: Dictionary = current[0]
				for node in current:
					if absi(int(node.lane) - int(target.lane)) < absi(int(nearest.lane) - int(target.lane)):
						nearest = node
				nearest.links.append(str(target.id))
