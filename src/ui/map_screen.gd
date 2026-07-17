extends Control
## Full-height illustrated dungeon route with persistent run status and CTA.


func _ready() -> void:
	if not RunState.active:
		RunState.start_new_run()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiKit.battle_background(self, "res://assets/art/backgrounds/shadow_crypt_battle.png")
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.005, 0.025, 0.42)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var margin := UiKit.safe_margin(self, 18, 22, 20)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	margin.add_child(root)
	root.add_child(_make_header())

	var route_panel := UiKit.textured_panel("res://assets/art/ui/battle_panel.png", 10)
	route_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(route_panel)
	var route := DungeonRoute.new()
	route.name = "DungeonRoute"
	route.custom_minimum_size = Vector2(0, 860)
	route_panel.add_child(route)
	if not RunState.run_graph.is_empty():
		route.configure_graph(RunState.run_graph, RunState.current_node_id,
				RunState.reachable_node_ids())
		route.node_selected.connect(_on_node_selected)
	else:
		route.configure(RunState.battles(), RunState.battle_index)

	root.add_child(_make_status_panel())
	var enter := UiKit.ornate_button("SELECT A GLOWING PATH", Vector2(440, 70))
	enter.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	enter.disabled = true
	root.add_child(enter)


func _on_node_selected(node_id: String) -> void:
	if not RunState.select_node(node_id): return
	var kind := str(RunState.current_node().get("kind", "battle"))
	if kind in ["battle", "elite", "boss"]:
		get_tree().change_scene_to_file("res://scenes/battle.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/event.tscn")


func _make_header() -> PanelContainer:
	var header := UiKit.textured_panel("res://assets/art/ui/battle_panel.png", 10)
	header.custom_minimum_size = Vector2(0, 78)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", -2)
	header.add_child(box)
	box.add_child(UiKit.title_label(str(RunState.run_config.get("area_name", "Shadow Crypt")).to_upper(), 31))
	box.add_child(UiKit.label("FLOOR I  -  CHOOSE YOUR PATH", 14, UiKit.COLOR_TEXT_DIM))
	return header


func _make_status_panel() -> PanelContainer:
	var panel := UiKit.textured_panel("res://assets/art/ui/battle_panel.png", 10)
	panel.custom_minimum_size = Vector2(0, 66)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	panel.add_child(box)
	var hp := RunState.player_hp
	var max_hp := int(RunState.stat("max_hp", float(GameState.player.get("max_hp", 50))))
	if hp < 0:
		hp = max_hp
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 30)
	box.add_child(row)
	row.add_child(UiKit.label("HP  %d / %d" % [hp, max_hp], 17, UiKit.COLOR_HP))
	row.add_child(UiKit.label("CRYSTALS  %d (+%d)" % [SaveSystem.crystals(), RunState.run_crystals], 17, Color("75d4ff")))
	var build_parts: Array[String] = []
	for id in RunState.relic_ids:
		build_parts.append(RunState.relic_name(str(id)))
	for id in RunState.upgrade_ids:
		build_parts.append(RunState.upgrade_name(str(id)))
	box.add_child(UiKit.label("BUILD: " + ("NONE YET" if build_parts.is_empty() else " - ".join(build_parts)), 12, UiKit.COLOR_TEXT_DIM))
	return panel
