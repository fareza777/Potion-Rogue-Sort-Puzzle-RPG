extends Control
## Run map: vertical node list (boss at the top, entrance at the bottom),
## current position, player HP, crystals and active upgrades.

func _ready() -> void:
	if not RunState.active:
		RunState.start_new_run()

	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiKit.background(self)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 48)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	root.add_child(UiKit.title_label(
			str(RunState.run_config.get("area_name", "Dungeon")), 42))
	root.add_child(UiKit.label("Floor 1", 20, UiKit.COLOR_TEXT_DIM))

	# Map nodes, boss first (top), walked bottom-up.
	var map_panel := UiKit.panel()
	map_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(map_panel)

	var nodes := VBoxContainer.new()
	nodes.alignment = BoxContainer.ALIGNMENT_CENTER
	nodes.add_theme_constant_override("separation", 8)
	map_panel.add_child(nodes)

	var battle_list := RunState.battles()
	for i in range(battle_list.size() - 1, -1, -1):
		nodes.add_child(_make_node_row(i, battle_list[i]))
		if i > 0:
			var link := UiKit.label("|", 16, Color("4a3f61"))
			nodes.add_child(link)

	root.add_child(_make_status_panel())

	var enter := UiKit.button("Enter Battle", Vector2(360, 76))
	enter.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	enter.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/battle.tscn"))
	root.add_child(enter)


func _make_node_row(index: int, entry: Dictionary) -> Label:
	var kind := str(entry.get("kind", "battle"))
	var enemy: Dictionary = GameState.enemies.get(str(entry.get("enemy", "")), {})
	var kind_tag: String = {"battle": "Battle", "elite": "ELITE", "boss": "BOSS"} \
			.get(kind, "Battle")
	var text := "%s — %s" % [kind_tag, str(enemy.get("name", "???"))]

	var color := UiKit.COLOR_TEXT_DIM
	var size := 22
	if index < RunState.battle_index:
		text = "cleared  " + text
		color = Color("5a7a5a")
	elif index == RunState.battle_index:
		text = ">  " + text + "  <"
		color = UiKit.COLOR_GOLD
		size = 26
	var l := UiKit.label(text, size, color)
	if kind == "boss":
		l.add_theme_font_override("font", UiKit.title_font())
	return l


func _make_status_panel() -> PanelContainer:
	var panel := UiKit.panel()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var hp := RunState.player_hp
	var max_hp := int(RunState.stat("max_hp",
			float(GameState.player.get("max_hp", 50))))
	if hp < 0:
		hp = max_hp
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 30)
	box.add_child(row)
	row.add_child(UiKit.label("HP  %d / %d" % [hp, max_hp], 22, UiKit.COLOR_HP))
	row.add_child(UiKit.label("Crystals  %d (+%d this run)"
			% [SaveSystem.crystals(), RunState.run_crystals], 22, Color("7fd4ff")))

	if not RunState.relic_ids.is_empty():
		var relic_names: Array[String] = []
		for id in RunState.relic_ids:
			relic_names.append(RunState.relic_name(str(id)))
		box.add_child(UiKit.label("Relics: " + ", ".join(relic_names), 19,
				Color("c07ce8")))

	if not RunState.upgrade_ids.is_empty():
		var names: Array[String] = []
		for id in RunState.upgrade_ids:
			names.append(RunState.upgrade_name(str(id)))
		var upgrades := UiKit.label("Upgrades: " + ", ".join(names), 18,
				UiKit.COLOR_TEXT_DIM)
		upgrades.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(upgrades)
	return panel
