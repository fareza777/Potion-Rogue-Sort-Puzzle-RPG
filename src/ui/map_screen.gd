extends Control
## Illustrated dungeon progression map. The battle list remains data-driven;
## this screen only adds visual hierarchy and path presentation.


func _ready() -> void:
	if not RunState.active:
		RunState.start_new_run()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiKit.battle_background(self,
			"res://assets/art/backgrounds/shadow_crypt_battle.png")
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.01, 0.025, 0.46)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)
	root.add_child(_make_header())

	var map_panel := UiKit.textured_panel(
			"res://assets/art/ui/battle_panel.png", 22)
	map_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(map_panel)
	var nodes := VBoxContainer.new()
	nodes.alignment = BoxContainer.ALIGNMENT_CENTER
	nodes.add_theme_constant_override("separation", 1)
	map_panel.add_child(nodes)

	var battle_list := RunState.battles()
	for i in range(battle_list.size() - 1, -1, -1):
		nodes.add_child(_make_node_row(i, battle_list[i]))
		if i > 0:
			var link := UiKit.label("◆", 15,
					UiKit.COLOR_GOLD if i == RunState.battle_index else Color("675271"))
			nodes.add_child(link)

	root.add_child(_make_status_panel())
	var enter := UiKit.ornate_button("ENTER CURRENT BATTLE", Vector2(440, 72))
	enter.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	enter.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/battle.tscn"))
	root.add_child(enter)


func _make_header() -> PanelContainer:
	var header := UiKit.textured_panel("res://assets/art/ui/battle_panel.png", 16)
	header.custom_minimum_size = Vector2(0, 94)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	header.add_child(box)
	box.add_child(UiKit.title_label(
			str(RunState.run_config.get("area_name", "Shadow Crypt")).to_upper(), 35))
	box.add_child(UiKit.label("FLOOR I  •  CHOOSE YOUR PATH", 16,
			UiKit.COLOR_TEXT_DIM))
	return header


func _make_node_row(index: int, entry: Dictionary) -> Control:
	var kind := str(entry.get("kind", "battle"))
	var enemy: Dictionary = GameState.enemies.get(str(entry.get("enemy", "")), {})
	var kind_tag: String = {"battle": "BATTLE", "elite": "ELITE", "boss": "BOSS"} \
			.get(kind, "BATTLE")
	var text := "%s  •  %s" % [kind_tag, str(enemy.get("name", "???")).to_upper()]
	var button := UiKit.map_node_button(text, kind,
			index == RunState.battle_index, index < RunState.battle_index)
	button.add_theme_font_size_override("font_size", 18 if kind != "boss" else 20)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.custom_minimum_size = Vector2(0, 57)
	var offset := 52 if index % 2 == 0 else -52
	var spacer_left := Control.new()
	spacer_left.custom_minimum_size.x = max(offset, 0)
	row.add_child(spacer_left)
	row.add_child(button)
	var spacer_right := Control.new()
	spacer_right.custom_minimum_size.x = max(-offset, 0)
	row.add_child(spacer_right)
	return row


func _make_status_panel() -> PanelContainer:
	var panel := UiKit.textured_panel("res://assets/art/ui/battle_panel.png", 16)
	panel.custom_minimum_size = Vector2(0, 88)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)

	var hp := RunState.player_hp
	var max_hp := int(RunState.stat("max_hp",
			float(GameState.player.get("max_hp", 50))))
	if hp < 0:
		hp = max_hp
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 32)
	box.add_child(row)
	row.add_child(UiKit.label("♥  %d / %d" % [hp, max_hp], 19, UiKit.COLOR_HP))
	row.add_child(UiKit.label("◆  %d  (+%d)" % [
			SaveSystem.crystals(), RunState.run_crystals], 19, Color("75d4ff")))
	var build_parts: Array[String] = []
	for id in RunState.relic_ids:
		build_parts.append(RunState.relic_name(str(id)))
	for id in RunState.upgrade_ids:
		build_parts.append(RunState.upgrade_name(str(id)))
	box.add_child(UiKit.label(
			"BUILD: " + ("NONE YET" if build_parts.is_empty() else " • ".join(build_parts)),
			14, UiKit.COLOR_TEXT_DIM))
	return panel
