extends Node

var failures := 0
var checks := 0

func _ready() -> void:
	var signatures := {}
	var director_metadata_safe := true
	for seed in 2000:
		var graph := RunGenerator.new().generate(seed)
		var repeat := RunGenerator.new().generate(seed)
		var nodes: Array = graph.nodes
		director_metadata_safe = director_metadata_safe \
				and graph.has("director_version") and int(graph.director_version) == 1
		for node in nodes:
			director_metadata_safe = director_metadata_safe and node.has("reveal_kind") \
					and int(node.get("risk", 0)) in range(1, 5)
			if str(node.kind) in ["battle", "elite"]:
				director_metadata_safe = director_metadata_safe \
						and str(node.get("reveal_kind", "")) in ["BATTLE", "ELITE"]
		assert_check(nodes.size() >= 12 and nodes.size() <= 15, "node count")
		assert_check(JSON.stringify(graph) == JSON.stringify(repeat), "seed determinism")
		var bosses := nodes.filter(func(n: Dictionary) -> bool: return n.kind == "boss")
		assert_check(bosses.size() == 1, "single boss")
		var reachable := _reachable(graph)
		assert_check(reachable.has(graph.boss), "boss reachable")
		assert_check(reachable.size() == nodes.size(), "all choices reachable")
		assert_check(_has_safe_route(graph), "continuous safe route")
		assert_check(_floor_cadence_is_combat_heavy(graph), "combat-heavy floor cadence")
		assert_check(_every_route_has_three_battles(graph), "every route has three battles")
		assert_check(_enemy_progression_is_ordered(graph), "enemy progression follows floor depth")
		assert_check(_contracts_are_compatible(graph), "compatible contracts")
		signatures[JSON.stringify(nodes)] = true
	assert_check(signatures.size() > 1900, "cross-seed route variation")
	assert_check(director_metadata_safe,
			"all seeded graphs expose safe route metadata from director v1")
	_test_area_identity()
	_test_ascension()
	_test_events()
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func _test_area_identity() -> void:
	for area_id in GameState.area_ids():
		var area := GameState.area(area_id)
		for seed in range(120):
			var graph := RunGenerator.new().generate(seed, area_id)
			assert_check(str(graph.get("area_id", "")) == area_id, "graph retains area identity")
			var boss: Dictionary = graph.nodes.filter(func(n: Dictionary) -> bool: return n.kind == "boss")[0]
			assert_check(str(boss.enemy) == str(area.boss), "graph uses authored area boss")
			for node in graph.nodes:
				if str(node.kind) not in ["battle", "elite"]: continue
				var pool_name := "elite" if str(node.kind) == "elite" else (
						"intro" if int(node.floor) == 1 else "tier_1" if int(node.floor) == 2 else
						"tier_2" if int(node.floor) in [3, 4] else "tier_3")
				assert_check(str(node.enemy) in area.enemy_pools[pool_name],
						"enemy belongs to authored area/depth pool")
				var expected_scale: float = (1.0 + max(0, int(node.floor) - 1) * 0.12 +
						(0.22 if str(node.kind) == "elite" else 0.0)) * float(area.threat_multiplier)
				assert_check(is_equal_approx(float(node.contract.threat.enemy_scale), expected_scale),
						"area threat multiplier is applied")


func _test_ascension() -> void:
	var normal := RunGenerator.new().generate(991, "shadow_crypt", 0)
	var ascended := RunGenerator.new().generate(991, "shadow_crypt", 5)
	assert_check(int(normal.get("ascension", -1)) == 0
			and int(ascended.get("ascension", -1)) == 5,
			"graph stores bounded Ascension identity")
	var normal_battle: Dictionary = normal.nodes.filter(func(node: Dictionary) -> bool:
		return str(node.kind) == "battle")[0]
	var ascended_battle: Dictionary = ascended.nodes.filter(func(node: Dictionary) -> bool:
		return str(node.id) == str(normal_battle.id))[0]
	assert_check(float(ascended_battle.contract.threat.enemy_scale)
			> float(normal_battle.contract.threat.enemy_scale),
			"Ascension increases threat without replacing route topology")

func _reachable(graph: Dictionary) -> Dictionary:
	var by_id := {}; for n in graph.nodes: by_id[n.id] = n
	var seen := {}; var queue := [graph.start]
	while not queue.is_empty():
		var id: String = queue.pop_front()
		if seen.has(id): continue
		seen[id] = true
		for link in by_id[id].links: queue.append(link)
	return seen

func _has_safe_route(graph: Dictionary) -> bool:
	var by_id := {}; for node in graph.nodes: by_id[str(node.id)] = node
	var queue := [{"id": str(graph.start), "last_elite": false}]
	var seen := {}
	while not queue.is_empty():
		var state: Dictionary = queue.pop_front()
		var node: Dictionary = by_id[state.id]
		if state.id == str(graph.boss): return true
		for next_id in node.links:
			var next: Dictionary = by_id[str(next_id)]
			var elite := str(next.kind) == "elite"
			if bool(state.last_elite) and elite: continue
			var key := "%s:%s" % [next_id, elite]
			if not seen.has(key): seen[key] = true; queue.append({"id":str(next_id), "last_elite":elite})
	return false

func _floor_cadence_is_combat_heavy(graph: Dictionary) -> bool:
	for floor in range(1, 6):
		var floor_nodes: Array = graph.nodes.filter(func(n: Dictionary) -> bool: return int(n.floor) == floor)
		var noncombat := floor_nodes.filter(func(n: Dictionary) -> bool: return str(n.kind) not in ["battle", "elite"])
		if floor in [1, 3, 5] and not noncombat.is_empty(): return false
		if floor in [2, 4] and noncombat.size() != 1: return false
	return true

func _every_route_has_three_battles(graph: Dictionary) -> bool:
	var by_id := {}; for node in graph.nodes: by_id[str(node.id)] = node
	return _route_cadence_ok(str(graph.start), by_id, str(graph.boss), 0, 0)

func _route_cadence_ok(id: String, by_id: Dictionary, boss_id: String,
		combat_count: int, noncombat_streak: int) -> bool:
	var node: Dictionary = by_id[id]
	var kind := str(node.kind)
	if kind in ["battle", "elite"]:
		combat_count += 1; noncombat_streak = 0
	elif kind not in ["start", "boss"]:
		noncombat_streak += 1
	if noncombat_streak > 1: return false
	if id == boss_id: return combat_count >= 3
	for next_id in node.links:
		if not _route_cadence_ok(str(next_id), by_id, boss_id, combat_count, noncombat_streak):
			return false
	return true

func _contracts_are_compatible(graph: Dictionary) -> bool:
	for node in graph.nodes:
		var contract: Dictionary = node.contract
		var objective := str(contract.objective_id)
		var enemy: Dictionary = GameState.enemies.get(str(node.enemy), {})
		if objective == "armor_break" and int(enemy.get("armor", 0)) <= 0:
			var guards: Array = enemy.get("intent_pool", []).filter(func(i: Dictionary) -> bool: return str(i.get("id", "")) == "guard")
			if guards.is_empty(): return false
		if objective == "cleanse" and "cursed_layer" not in contract.modifier_ids and "corruption" not in contract.modifier_ids:
			return false
	return true

func _enemy_progression_is_ordered(graph: Dictionary) -> bool:
	var area := GameState.area(str(graph.get("area_id", "shadow_crypt")))
	for node in graph.nodes:
		var floor := int(node.floor)
		var kind := str(node.kind)
		if kind not in ["battle", "elite"]: continue
		var pool_name := "elite" if kind == "elite" else (
				"intro" if floor == 1 else "tier_1" if floor == 2 else
				"tier_2" if floor in [3, 4] else "tier_3")
		if str(node.enemy) not in area.enemy_pools[pool_name]: return false
	return true

func _test_events() -> void:
	RunState.start_new_run("ember_adept")
	RunState.run_crystals = 100
	var resolver := EventResolver.new()
	for event_id in resolver.events:
		var choice_id := str(resolver.events[event_id].choices.keys()[0])
		var before := resolver.preview(str(event_id), choice_id)
		var applied := resolver.apply(str(event_id), choice_id, RunState)
		assert_check(before.ok and applied.ok and before.effects == applied.effects,
				"event preview parity: " + str(event_id))

func assert_check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL ", label)
