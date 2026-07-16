extends Control
## Credits screen.


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiKit.battle_background(self,
			"res://assets/art/backgrounds/shadow_crypt_battle.png")

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := UiKit.textured_panel("res://assets/art/ui/battle_panel.png", 38)
	panel.custom_minimum_size = Vector2(600, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)

	box.add_child(UiKit.title_label("Credits", 48))
	box.add_child(UiKit.label("Potion Rogue: Sort Puzzle RPG", 26))
	box.add_child(UiKit.label("Game & Design\nFareza Games", 22, UiKit.COLOR_TEXT_DIM))
	box.add_child(UiKit.label("Made with Godot Engine\ngodotengine.org", 22,
			UiKit.COLOR_TEXT_DIM))
	box.add_child(UiKit.label("Cinzel font by Natanael Gama (OFL)", 20,
			UiKit.COLOR_TEXT_DIM))

	var back := UiKit.ornate_button("RETURN TO HALL", Vector2(340, 66))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	box.add_child(back)
