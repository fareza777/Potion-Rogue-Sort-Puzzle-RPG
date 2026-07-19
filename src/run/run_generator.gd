class_name RunGenerator
extends RefCounted

const AREA_GRAMMAR := preload("res://src/run/area_grammar.gd")
const INTRO_MODIFIERS := ["hidden_layer", "frozen_tube"]
const ADVANCED_MODIFIERS := ["cursed_layer", "volatile_liquid", "wild_essence", "chain_lock", "corruption", "unstable_flask"]
var _ascension := 0


func generate(seed: int, area_id := "shadow_crypt", ascension := 0) -> Dictionary:
	_ascension = clampi(ascension, 0, 10)
	var area: Dictionary = AREA_GRAMMAR.for_area(area_id)
	if area.is_empty():
		area_id = "shadow_crypt"
		area = AREA_GRAMMAR.for_area(area_id)
	var boss_floor := int(area.get("boss_depth", area.get("run_length", 7))) - 1
	var rng := RunRng.new()
	rng.configure(seed)
	var director := RunDirector.new()
	var intro_pool: Array = area.get("enemy_pools", {}).get("intro", ["slime"])
	var nodes: Array = [_node("f0_l1", 0, 1, "start", str(intro_pool[0]), area)]
	var expanded_floors: Array[int] = []
	var extra_count := rng.randi_range(0, 3)
	while expanded_floors.size() < extra_count:
		var candidate := rng.randi_range(1, boss_floor - 1)
		if candidate not in expanded_floors:
			expanded_floors.append(candidate)
	var guaranteed: Dictionary = area.get("guaranteed_kinds", {})
	var miniboss_depths: Array = area.get("miniboss_depths", [])
	for floor in range(1, boss_floor):
		var lanes := _lanes_for_floor(rng, floor in expanded_floors)
		var depth := floor + 1
		var authored_kind := str(guaranteed.get(str(depth), ""))
		var is_miniboss := depth in miniboss_depths or authored_kind == "miniboss"
		var noncombat_slot := rng.randi_range(0, lanes.size() - 1) \
				if (floor in [2, 4] or authored_kind == "recovery") and not is_miniboss else -1
		var secret_slot := -1
		if authored_kind.is_empty() and float(area.get("secret_branch_chance", 0.0)) > 0.0 \
				and rng.randf() < float(area.secret_branch_chance):
			secret_slot = rng.randi_range(0, lanes.size() - 1)
		for slot in lanes.size():
			var lane: int = int(lanes[slot])
			var context := {"hp_ratio": 1.0, "power": float(_ascension)}
			var kind := ("elite" if is_miniboss else "event" if authored_kind == "event" else
					"campfire" if authored_kind == "recovery" and slot == noncombat_slot else
					"treasure" if slot == secret_slot else
					director.assign_kind(floor, slot, noncombat_slot, context, rng))
			var enemy := _enemy_for_floor(floor, kind, rng, area)
			var created := _node("f%d_l%d" % [floor, lane], floor, lane, kind, enemy, area)
			if is_miniboss:
				created["miniboss"] = true
			if slot == secret_slot:
				created["secret"] = true
				created["risk"] = 4
			_decorate_contract(created, rng, area)
			_decorate_event(created, rng)
			nodes.append(created)
	var boss_id := "f%d_boss" % boss_floor
	var boss := _node(boss_id, boss_floor, 1, "boss", str(area.get("boss", "fire_golem")), area)
	boss.contract.objective_id = "defeat"
	nodes.append(boss)
	_link_floors(nodes, boss_floor + 1)
	return {"seed": seed, "area_id": area_id, "nodes": nodes, "start": "f0_l1",
			"boss": boss_id, "director_version": RunDirector.VERSION,
			"ascension": _ascension}


func _lanes_for_floor(rng: RunRng, expanded: bool) -> Array[int]:
	if expanded:
		return [0, 1, 2]
	var pairs: Array = [[0, 1], [1, 2], [0, 2]]
	var picked: Array = pairs[rng.randi_range(0, pairs.size() - 1)]
	return [int(picked[0]), int(picked[1])]


func _enemy_for_floor(floor: int, kind: String, rng: RunRng,
		area: Dictionary) -> String:
	if kind not in ["battle", "elite"]:
		return str((area.get("enemy_pools", {}).get("intro", ["slime"]) as Array)[0])
	var pool_name := "elite" if kind == "elite" else (
			"intro" if floor <= 1 else "tier_1" if floor == 2 else
			"tier_2" if floor in [3, 4] else "tier_3")
	var candidates: Array = area.get("enemy_pools", {}).get(pool_name, [])
	if candidates.is_empty():
		candidates = area.get("enemy_pools", {}).get("intro", ["slime"])
	return str(candidates[rng.randi_range(0, candidates.size() - 1)])


func _node(id: String, floor: int, lane: int, kind: String, enemy: String,
		area: Dictionary) -> Dictionary:
	var budget := ThreatBudget.new().for_node(floor, kind,
			area.get("threat_multiplier", 1.0), _ascension)
	var director := RunDirector.new()
	return {"id": id, "floor": floor, "lane": lane, "kind": kind,
		"enemy": enemy, "links": [], "visited": false,
		"reveal_kind": director.reveal_for(kind),
		"risk": director.risk_for(floor, kind),
		"contract": {"enemy_id": enemy, "objective_id": "defeat",
			"modifier_ids": [], "threat": budget}}


func _decorate_contract(node: Dictionary, rng: RunRng,
		area: Dictionary) -> void:
	var kind := str(node.kind)
	var floor := int(node.floor)
	if kind not in ["battle", "elite"]: return
	var pool: Array = INTRO_MODIFIERS.duplicate() if floor <= 2 else ADVANCED_MODIFIERS.duplicate()
	if floor >= 3: pool.append_array(INTRO_MODIFIERS)
	for modifier_id in area.get("area_modifiers", []):
		if str(modifier_id) not in pool:
			pool.append(str(modifier_id))
	var count := 2 if kind == "elite" else (1 if floor <= 2 else rng.randi_range(1, 2))
	if _ascension >= 3 and floor >= 3:
		count = mini(count + 1, 3)
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


func _decorate_event(node: Dictionary, rng: RunRng) -> void:
	var kind := str(node.kind)
	match kind:
		"treasure": node.event_id = "cursed_chest"
		"campfire": node.event_id = "ember_camp"
		"shop": node.event_id = "bound_alchemist"
		"event":
			var pool := ["whispering_well", "mirror_cauldron", "bone_oracle"]
			node.event_id = pool[rng.randi_range(0, pool.size() - 1)]


func _link_floors(nodes: Array, floor_count: int) -> void:
	var by_floor := {}
	for node in nodes:
		if not by_floor.has(node.floor): by_floor[node.floor] = []
		by_floor[node.floor].append(node)
	for floor in range(floor_count - 1):
		var current: Array = by_floor[floor]
		var next: Array = by_floor[floor + 1]
		for node in current:
			if current.size() == 1 or next.size() == 1:
				for target in next: node.links.append(str(target.id))
				continue
			var ordered: Array = next.duplicate()
			ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return absi(int(a.lane) - int(node.lane)) < absi(int(b.lane) - int(node.lane)))
			node.links.append(str(ordered[0].id))
			if int(node.lane) == 1 and ordered.size() > 1 and absi(int(ordered[1].lane) - 1) <= 1:
				node.links.append(str(ordered[1].id))
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
