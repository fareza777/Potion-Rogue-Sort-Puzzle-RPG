extends Control
## Main menu (Phase 1: title + Play). Upgrades/Settings/Credits arrive in later phases.

const BG_COLOR := Color("14101f")


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 24)
	add_child(box)

	var title := Label.new()
	title.text = "Potion Rogue"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color("b9a7e8"))
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Sort Puzzle RPG"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 30)
	subtitle.add_theme_color_override("font_color", Color("ffd77a"))
	box.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	box.add_child(spacer)

	var play := Button.new()
	play.text = "Play"
	play.custom_minimum_size = Vector2(320, 80)
	play.add_theme_font_size_override("font_size", 32)
	play.pressed.connect(_on_play_pressed)
	box.add_child(play)

	var version := Label.new()
	version.text = "Prototype v0.1.0"
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version.add_theme_font_size_override("font_size", 18)
	version.add_theme_color_override("font_color", Color("6b5f8a"))
	box.add_child(version)


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/battle.tscn")
