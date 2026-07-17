class_name RunGenerator
extends RefCounted

const REGULAR_KINDS := ["battle", "battle", "event", "shop", "treasure", "campfire", "elite"]
const ENEMIES := ["slime", "skeleton", "poison_beast", "stone_golem", "dark_mage", "blood_slime"]


func generate(seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var nodes: Array = []
	nodes.append(_node("f0_l1", 0, 1, "start", "slime"))
	for floor in range(1, 6):
		for slot in 2:
			var lane := 0 if slot == 0 else 2
			if rng.randi() % 3 == 0:
				lane = 1 if slot == 0 else 2
			var kind := "battle" if slot == 0 else str(REGULAR_KINDS[rng.randi_range(0, REGULAR_KINDS.size() - 1)])
			# The left route is always safe; it cannot force consecutive elites.
			if slot == 0 and kind == "elite": kind = "battle"
			var enemy: String = str(ENEMIES[mini(floor, ENEMIES.size() - 1)])
			var created := _node("f%d_s%d" % [floor, slot], floor, lane, kind, enemy)
			_decorate_contract(created, rng)
			nodes.append(created)
	nodes.append(_node("f6_boss", 6, 1, "boss", "fire_golem"))
	for node in nodes:
		var floor := int(node.floor)
		if floor == 6: continue
		for target in nodes:
			if int(target.floor) == floor + 1:
				node.links.append(str(target.id))
	return {"seed": seed, "nodes": nodes, "start": "f0_l1", "boss": "f6_boss"}


func _node(id: String, floor: int, lane: int, kind: String, enemy: String) -> Dictionary:
	var budget := ThreatBudget.new().for_node(floor, kind)
	return {"id": id, "floor": floor, "lane": lane, "kind": kind,
		"enemy": enemy, "links": [], "visited": false,
		"contract": {"enemy_id": enemy, "objective_id": "defeat",
			"modifier_ids": [], "threat": budget}}


func _decorate_contract(node: Dictionary, rng: RandomNumberGenerator) -> void:
	var kind := str(node.kind); var floor := int(node.floor)
	if kind not in ["battle", "elite"]: return
	var intro := ["hidden_layer", "frozen_tube"]
	var advanced := ["cursed_layer", "volatile_liquid", "wild_essence",
			"chain_lock", "corruption", "unstable_flask"]
	var pool: Array = intro if floor <= 2 else advanced
	var count := 2 if kind == "elite" else 1
	for _pick in count:
		var id := str(pool[rng.randi_range(0, pool.size() - 1)])
		if id not in node.contract.modifier_ids: node.contract.modifier_ids.append(id)
	var objectives := ["defeat", "survive", "brew_order", "armor_break", "cleanse"]
	node.contract.objective_id = objectives[(floor + int(node.lane)) % objectives.size()]
