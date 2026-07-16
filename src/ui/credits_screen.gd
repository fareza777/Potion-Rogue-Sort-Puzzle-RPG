extends Control
## Full-height credits presentation matching the dungeon visual system.


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiKit.battle_background(self, "res://assets/art/backgrounds/shadow_crypt_battle.png")
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.005, 0.02, 0.46)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var profile := UiKit.layout_profile(get_viewport_rect().size)
	var margin := UiKit.safe_margin(self,
			int(profile.get("safe_horizontal", 24)),
			int(profile.get("safe_top", 28)),
			int(profile.get("safe_bottom", 24)))
	var panel := UiKit.textured_panel("res://assets/art/ui/battle_panel.png", 34)
	panel.name = "CreditsPanel"
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(panel)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	var spacer_top := Control.new()
	spacer_top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer_top)
	box.add_child(UiKit.title_label("POTION ROGUE", 45))
	box.add_child(UiKit.label("SORT  -  BREW  -  CONQUER", 17, UiKit.COLOR_GOLD))
	var portrait := UiKit.enemy_portrait("slime", Vector2(280, 220))
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(portrait)
	box.add_child(UiKit.title_label("CREDITS", 34))
	box.add_child(UiKit.label("GAME & DESIGN\nFAREZA GAMES", 22, UiKit.COLOR_TEXT))
	box.add_child(UiKit.label("Built with Godot Engine\nCinzel typeface by Natanael Gama (OFL)", 18, UiKit.COLOR_TEXT_DIM))
	var back := UiKit.ornate_button("RETURN TO HALL", Vector2(340, 66))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	box.add_child(back)
	var spacer_bottom := Control.new()
	spacer_bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer_bottom)
