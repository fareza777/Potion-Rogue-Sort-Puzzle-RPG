extends Control
## Settings: music/SFX volume, vibration toggle, reset progress (with confirm).

var _confirm_panel: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiKit.battle_background(self,
			"res://assets/art/backgrounds/shadow_crypt_battle.png")

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := UiKit.textured_panel("res://assets/art/ui/battle_panel.png", 34)
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	panel.add_child(box)

	box.add_child(UiKit.title_label("Settings", 44))

	box.add_child(_make_slider_row("Music", "music",
			func(v: float) -> void: AudioManager.set_music_volume(v)))
	box.add_child(_make_slider_row("Sound Effects", "sfx",
			func(v: float) -> void: AudioManager.set_sfx_volume(v)))

	var vib_row := HBoxContainer.new()
	vib_row.add_theme_constant_override("separation", 16)
	box.add_child(vib_row)
	var vib_label := UiKit.label("Vibration", 24)
	vib_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vib_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vib_row.add_child(vib_label)
	var vib := CheckButton.new()
	vib.button_pressed = bool(SaveSystem.setting("vibration"))
	vib.toggled.connect(func(on: bool) -> void:
		SaveSystem.set_setting("vibration", on)
		AudioManager.vibrate(40))
	vib_row.add_child(vib)

	var reset := UiKit.button("Reset Progress", Vector2(300, 60), Color("e05252"))
	reset.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reset.pressed.connect(_show_reset_confirm)
	box.add_child(reset)

	var back := UiKit.ornate_button("RETURN TO HALL", Vector2(340, 66))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	box.add_child(back)


func _make_slider_row(title: String, key: String, on_change: Callable) -> VBoxContainer:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var label := UiKit.label(title, 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = float(SaveSystem.setting(key))
	slider.custom_minimum_size = Vector2(0, 36)
	slider.value_changed.connect(func(v: float) -> void:
		SaveSystem.set_setting(key, v)
		on_change.call(v))
	row.add_child(slider)
	return row


func _show_reset_confirm() -> void:
	if _confirm_panel != null:
		return
	_confirm_panel = Control.new()
	_confirm_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_confirm_panel)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm_panel.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm_panel.add_child(center)

	var panel := UiKit.textured_panel("res://assets/art/ui/battle_panel.png", 32)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	box.add_child(UiKit.title_label("Reset everything?", 32))
	box.add_child(UiKit.label("Crystals, permanent upgrades and stats\nwill be lost forever.", 22))

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	var yes := UiKit.button("Reset", Vector2(180, 60), Color("e05252"))
	yes.pressed.connect(func() -> void:
		SaveSystem.reset_progress()
		_close_confirm())
	buttons.add_child(yes)
	var no := UiKit.button("Cancel", Vector2(180, 60))
	no.pressed.connect(_close_confirm)
	buttons.add_child(no)


func _close_confirm() -> void:
	if _confirm_panel != null:
		_confirm_panel.queue_free()
		_confirm_panel = null
