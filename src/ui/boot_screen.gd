extends Control
## Short branded handoff after the native splash, then routes first-time players.


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var art := UiKit.battle_background(self,
			"res://assets/art/backgrounds/launch_splash_v2.jpg")
	art.modulate = Color(0.82, 0.86, 1.0, 1.0)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.004, 0.002, 0.018, 0.22)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var stack := VBoxContainer.new()
	stack.set_anchors_preset(Control.PRESET_CENTER_TOP)
	stack.position = Vector2(-300, 70)
	stack.size = Vector2(600, 180)
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(stack)
	var title := UiKit.title_label("POTION ROGUE", 58, Color("f1cf79"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(title)
	var subtitle := UiKit.label("SORT  •  BREW  •  CONQUER", 17, Color("d8b6ff"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(subtitle)
	var loading := UiKit.label("DISTILLING THE DUNGEON…", 13, Color("8edcff"))
	loading.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	loading.position = Vector2(-220, -100)
	loading.size = Vector2(440, 42)
	loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(loading)
	var tween := create_tween().set_loops()
	tween.tween_property(loading, "modulate:a", 0.35, 0.55).set_trans(Tween.TRANS_QUINT)
	tween.tween_property(loading, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_QUINT)
	await get_tree().create_timer(1.15).timeout
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn" if
			SaveSystem.is_onboarding_done() else "res://scenes/onboarding.tscn")
