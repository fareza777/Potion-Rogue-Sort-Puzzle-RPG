extends Node

var failures := 0
var checks := 0

func _ready() -> void:
	var signatures := {}
	for seed in 2000:
		var graph := RunGenerator.new().generate(seed)
		var repeat := RunGenerator.new().generate(seed)
		var nodes: Array = graph.nodes
		assert_check(nodes.size() >= 12 and nodes.size() <= 15, "node count")
		assert_check(JSON.stringify(graph) == JSON.stringify(repeat), "seed determinism")
		var bosses := nodes.filter(func(n: Dictionary) -> bool: return n.kind == "boss")
		assert_check(bosses.size() == 1, "single boss")
		var reachable := _reachable(graph)
		assert_check(reachable.has(graph.boss), "boss reachable")
		assert_check(reachable.size() == nodes.size(), "all choices reachable")
		assert_check(_has_safe_route(graph), "continuous safe route")
		assert_check(_contracts_are_compatible(graph), "compatible contracts")
		signatures[JSON.stringify(nodes)] = true
	assert_check(signatures.size() > 1900, "cross-seed route variation")
	_test_events()
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)

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
