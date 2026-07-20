extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	_test_emergency_mix_is_immediate()
	_test_selection_has_no_extra_marker()
	await _test_route_receives_drag_before_buttons_consume_it()
	_test_launch_transition_contract()
	_test_realm_two_uses_fungal_enemies()
	_test_saved_routes_are_rethemed()
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _test_emergency_mix_is_immediate() -> void:
	var remainder: Array = [["red"], ["green"], [], [], [], []]
	var started := Time.get_ticks_msec()
	var result := BoardFactory.remix(remainder, 1907, "standard")
	var elapsed := Time.get_ticks_msec() - started
	check(elapsed < 100,
			"two-color emergency New Mix finishes within one mobile frame budget")
	check(result.get("state", []) != remainder
			and bool(result.get("analysis", {}).get("solvable", false)),
			"two-color emergency New Mix visibly creates a playable board")
	var three_color: Array = [["red"], ["green"], ["blue"], [], [], []]
	started = Time.get_ticks_msec()
	result = BoardFactory.remix(three_color, 1941, "standard")
	elapsed = Time.get_ticks_msec() - started
	var independent := BoardSolver.analyze(result.get("state", []))
	check(elapsed < 100 and result.get("state", []) != three_color
			and bool(result.get("analysis", {}).get("solvable", false))
			and bool(independent.get("solvable", false))
			and int(independent.get("estimated_moves", -1)) > 0,
			"three-color emergency New Mix is also immediate and playable")


func _test_selection_has_no_extra_marker() -> void:
	var source := FileAccess.get_file_as_string("res://src/puzzle/potion_tube.gd")
	check(not source.contains("if selected or has_focus():"),
			"selecting a bottle adds no line or ring marker")


func _test_route_receives_drag_before_buttons_consume_it() -> void:
	var original := RunState.serialize_boundary()
	RunState.pending_area_id = "shadow_crypt"
	RunState.start_new_run("ember_adept", "shadow_crypt", "normal", 883102)
	var screen := preload("res://scenes/map.tscn").instantiate() as Control
	add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	var scroll := screen.find_child("DungeonRouteScroll", true, false) as ScrollContainer
	var route_button := screen.find_child("GraphNode_*", true, false) as Button
	check(route_button != null and route_button.mouse_filter == Control.MOUSE_FILTER_PASS,
			"route node buttons pass gestures to the kinetic scroll container")
	var drag := InputEventScreenDrag.new()
	drag.position = scroll.global_position + scroll.size * 0.5
	drag.relative = Vector2(0, -120)
	if screen.has_method("_input"):
		screen.call("_input", drag)
	await get_tree().process_frame
	check(screen.has_method("_input") and scroll.scroll_vertical > 0,
			"dungeon drag is captured before route buttons consume it")
	screen.queue_free()
	await get_tree().process_frame
	RunState.resume_from_save(original)


func _test_launch_transition_contract() -> void:
	var project := FileAccess.get_file_as_string("res://project.godot")
	var boot := FileAccess.get_file_as_string("res://src/ui/boot_screen.gd")
	check(project.contains("boot_splash/fullsize=false")
			and not boot.contains("create_timer(1.15)"),
			"native splash stays proportional and has no awkward handoff pause")
	check(FileAccess.file_exists("res://assets/art/backgrounds/launch_splash_v3.jpg"),
			"premium replacement splash artwork is stored in the project")


func _test_realm_two_uses_fungal_enemies() -> void:
	var areas: Dictionary = GameState.load_data_file("areas.json", {})
	var enemies: Dictionary = GameState.load_data_file("enemies.json", {})
	var pools: Dictionary = areas.get("verdant_catacombs", {}).get("enemy_pools", {})
	var verdant_themed := true
	for pool in pools.values():
		for enemy_id in pool:
			verdant_themed = verdant_themed \
					and str(enemies.get(str(enemy_id), {}).get("family", "")) == "fungal"
	check(verdant_themed and "slime" not in pools.get("intro", []),
			"Verdant Catacombs never reuses the Shadow Crypt slime")
	var every_realm_themed := true
	for area in areas.values():
		var allowed: Array = area.get("enemy_families", [])
		every_realm_themed = every_realm_themed and not allowed.is_empty()
		for pool in area.get("enemy_pools", {}).values():
			for enemy_id in pool:
				every_realm_themed = every_realm_themed and str(
						enemies.get(str(enemy_id), {}).get("family", "")) in allowed
	check(every_realm_themed,
			"every dungeon draws enemies only from its authored theme families")


func _test_saved_routes_are_rethemed() -> void:
	var original := RunState.serialize_boundary()
	RunState.start_new_run("ember_adept", "shadow_crypt", "normal", 77831)
	var saved := RunState.serialize_boundary()
	saved["area_id"] = "verdant_catacombs"
	saved["graph"] = RunGenerator.new().generate(77831, "verdant_catacombs", 0)
	saved["current_node_id"] = str(saved.graph.get("start", "f0_l1"))
	for node in saved.graph.get("nodes", []):
		if str(node.get("kind", "")) in ["battle", "elite"]:
			node["enemy"] = "slime"
			node.get("contract", {})["enemy_id"] = "slime"
			break
	RunState.resume_from_save(saved)
	var repaired := true
	for node in RunState.run_graph.get("nodes", []):
		if str(node.get("kind", "")) not in ["battle", "elite"]:
			continue
		repaired = repaired and str(GameState.enemies.get(
				str(node.get("enemy", "")), {}).get("family", "")) == "fungal"
	check(repaired, "existing Verdant saves replace legacy slime encounters")
	RunState.resume_from_save(original)


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("PASS  ", label)
	else:
		failures += 1
		print("FAIL  ", label)
