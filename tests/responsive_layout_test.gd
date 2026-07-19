extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	check(UiThemeTokens.SPACE.has("xxl") and UiThemeTokens.TYPE.has("hero"),
			"authoritative spacing and type token maps exist")
	check(UiThemeTokens.REALM_ACCENTS.size() == 5,
			"all realms own a semantic accent token")
	check(UiThemeTokens.TOUCH_MIN >= 56, "touch target token is mobile safe")
	var route := DungeonRoute.new()
	route.size = Vector2(532, 840)
	var graph := {"nodes": [
		{"id":"start", "floor":0, "lane":1, "kind":"battle", "enemy":"slime", "links":["boss"]},
		{"id":"boss", "floor":9, "lane":1, "kind":"boss", "enemy":"fire_golem", "links":[]},
	]}
	route.configure(graph, "start", 9)
	add_child(route)
	await get_tree().process_frame
	var start := route.get_node_or_null("GraphNode_start") as Control
	var boss := route.get_node_or_null("GraphNode_boss") as Control
	check(start != null and start.position.x >= 0 and start.position.x + start.size.x <= route.size.x,
			"route nodes stay inside narrow viewport width")
	check(boss != null and boss.position.y >= 92.0,
			"boss node begins below protected map header")
	check(start != null and start.position.y + start.size.y <= route.size.y - 20.0,
			"start node remains above the lower status region")
	var area_source := FileAccess.get_file_as_string("res://src/ui/area_select_screen.gd")
	check(area_source.contains('name = "AreaAction"') and area_source.contains("VBoxContainer.new()"),
			"realm cards expose a full-width stacked action")
	check(area_source.contains("horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED"),
			"realm selector disables accidental horizontal scrolling")
	var menu_source := FileAccess.get_file_as_string("res://src/ui/main_menu.gd")
	for destination in ["areas", "build", "history", "credits"]:
		check(menu_source.contains('nav.add_item("' + destination + '"'),
				"bottom navigation exposes " + destination)
	route.queue_free()
	finish()


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS  ", label)
	else: failures += 1; print("FAIL  ", label)


func finish() -> void:
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
