extends Control
## Campaign expedition selector. Locked destinations remain visible so the
## player always understands long-term progression and first-clear rewards.


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiKit.battle_background(self, VisualRegistry.background("main_hall"))
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.008, 0.005, 0.02, 0.74)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var margin := UiKit.safe_margin(self, 22, 28, 22)
	var root := VBoxContainer.new()
	root.name = "ExpeditionStack"
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)
	var title := UiKit.title_label("CHOOSE EXPEDITION", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)
	var subtitle := UiKit.label("Each realm has its own roster, boss, hazards and rewards.", 16, UiKit.COLOR_TEXT_DIM)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(subtitle)
	for id in GameState.area_ids():
		root.add_child(_area_card(id))
	var back := UiKit.ornate_button("BACK TO HALL", Vector2(360, 62))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	root.add_child(back)


func _area_card(area_id: String) -> PanelContainer:
	var area := GameState.area(area_id)
	var unlocked := SaveSystem.is_area_unlocked(area_id)
	var cleared := area_id in SaveSystem.completed_areas()
	var card := UiKit.textured_panel("res://assets/art/ui/battle_panel.png", 18)
	card.name = "AreaCard_" + area_id
	card.custom_minimum_size = Vector2(0, 238)
	card.modulate = Color.WHITE if unlocked else Color(0.55, 0.56, 0.64, 0.88)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)
	var crest := TextureRect.new()
	crest.custom_minimum_size = Vector2(152, 190)
	crest.texture = VisualRegistry.enemy_texture(str(area.get("boss", "fire_golem")))
	crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crest.modulate = Color.WHITE if unlocked else Color(0.22, 0.22, 0.28, 1.0)
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(crest)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 5)
	row.add_child(info)
	info.add_child(UiKit.title_label(str(area.get("name", area_id)).to_upper(), 25,
			_area_color(area_id)))
	info.add_child(UiKit.label(str(area.get("subtitle", "Seven-depth expedition")), 14, UiKit.COLOR_TEXT))
	var progress := "CLEARED %d TIMES" % SaveSystem.area_wins(area_id) if cleared else (
			"BEST DEPTH %d / 7" % SaveSystem.best_depth(area_id) if unlocked else "LOCKED")
	info.add_child(UiKit.label(progress, 13, UiKit.COLOR_GOLD if unlocked else UiKit.COLOR_TEXT_DIM))
	if not cleared:
		info.add_child(UiKit.label("FIRST CLEAR  +%d CRYSTALS" % int(area.get("first_clear_reward", 0)),
				13, Color("77d8ff")))
	var action := UiKit.ornate_button("ENTER" if unlocked else "LOCKED", Vector2(142, 62),
			_area_color(area_id))
	action.disabled = not unlocked
	action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	action.pressed.connect(func() -> void:
		RunState.pending_area_id = area_id
		SaveSystem.set_selected_area(area_id)
		get_tree().change_scene_to_file("res://scenes/kit_select.tscn"))
	row.add_child(action)
	return card


func _area_color(area_id: String) -> Color:
	match area_id:
		"verdant_catacombs": return Color("67cf72")
		"astral_foundry": return Color("b77cff")
		_: return Color("e0b862")
