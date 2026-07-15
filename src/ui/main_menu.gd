extends Control
## Main menu: title, decorative potion flask, Play (starts a new run),
## crystal total. Permanent upgrades/settings/credits arrive in later phases.


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiKit.background(self)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 22)
	center.add_child(box)

	box.add_child(UiKit.title_label("Potion Rogue", 74))
	box.add_child(UiKit.label("Sort Puzzle RPG", 28, UiKit.COLOR_TEXT_DIM))

	var flask := _make_flask()
	box.add_child(flask)

	var play := UiKit.button("Play", Vector2(340, 84))
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.pressed.connect(_on_play_pressed)
	box.add_child(play)

	box.add_child(UiKit.label("Crystals: %d" % SaveSystem.crystals(), 22,
			Color("7fd4ff")))
	box.add_child(UiKit.label("Prototype v0.2.0", 16, Color("5a5470")))


## Decorative animated flask drawn with a big PotionTube.
func _make_flask() -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(140, 300)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var tube := PotionTube.new()
	tube.set_anchors_preset(Control.PRESET_FULL_RECT)
	tube.set_contents(["red", "red", "blue", "purple"] as Array[String])
	tube.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(tube)
	return holder


func _on_play_pressed() -> void:
	RunState.start_new_run()
	get_tree().change_scene_to_file("res://scenes/map.tscn")
