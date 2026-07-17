extends Node

var failures := 0
var checks := 0

func _ready() -> void:
	for seed in 1000:
		var graph := RunGenerator.new().generate(seed)
		var nodes: Array = graph.nodes
		assert_check(nodes.size() >= 10 and nodes.size() <= 12, "node count")
		var bosses := nodes.filter(func(n: Dictionary) -> bool: return n.kind == "boss")
		assert_check(bosses.size() == 1, "single boss")
		var reachable := _reachable(graph)
		assert_check(reachable.has(graph.boss), "boss reachable")
		assert_check(_has_safe_route(graph), "safe route")
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
	var by_floor := {}
	for node in graph.nodes:
		if not by_floor.has(node.floor): by_floor[node.floor] = []
		by_floor[node.floor].append(node)
	for floor in range(1, 6):
		if not by_floor[floor].any(func(n: Dictionary) -> bool: return n.kind != "elite"):
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
