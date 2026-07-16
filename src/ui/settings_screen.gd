extends Control
## Full-height aligned settings surface with a coherent icon-led row system.

var _confirm_panel: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiKit.battle_background(self,
			"res://assets/art/backgrounds/shadow_crypt_battle.png")
	var profile := UiKit.layout_profile(get_viewport_rect().size)
	var margin := UiKit.safe_margin(self, int(profile.safe_horizontal),
			int(profile.safe_top), int(profile.safe_bottom))
	margin.name = "SafeContent"

	var panel := UiKit.textured_panel("res://assets/art/ui/battle_panel.png", 34)
	panel.name = "SettingsPanel"
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(panel)
	var rows := VBoxContainer.new()
	rows.name = "SettingsRows"
	rows.alignment = BoxContainer.ALIGNMENT_CENTER
	rows.add_theme_constant_override("separation", 14)
	panel.add_child(rows)
	rows.add_child(UiKit.title_label("SETTINGS", 46))
	rows.add_child(UiKit.label("AUDIO & ACCESSIBILITY", 16, UiKit.COLOR_TEXT_DIM))

	var music_row := _make_slider_row("MUSIC", "music", "music",
			func(v: float) -> void: AudioManager.set_music_volume(v))
	music_row.name = "MusicRow"
	rows.add_child(music_row)
	var sound_row := _make_slider_row("SOUND EFFECTS", "sfx", "sound",
			func(v: float) -> void: AudioManager.set_sfx_volume(v))
	sound_row.name = "SoundRow"
	rows.add_child(sound_row)
	var vibration_row := _make_vibration_row()
	vibration_row.name = "VibrationRow"
	rows.add_child(vibration_row)

	var separator := HSeparator.new()
	separator.modulate = Color("8a6d3b")
	rows.add_child(separator)
	var reset := UiKit.button("RESET PROGRESS", Vector2(320, 60), Color("e96a67"))
	reset.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reset.pressed.connect(_show_reset_confirm)
	rows.add_child(reset)
	var back := UiKit.ornate_button("RETURN TO HALL", Vector2(360, 68))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	rows.add_child(back)


func _row_icon(icon_id: String) -> TextureRect:
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(82, 82)
	icon.texture = VisualRegistry.texture_or_null(VisualRegistry.ui_icon(icon_id))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _make_slider_row(title: String, key: String, icon_id: String,
		on_change: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 118
	row.add_theme_constant_override("separation", 16)
	row.add_child(_row_icon(icon_id))
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	var label := UiKit.label(title, 21, UiKit.COLOR_GOLD)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(label)
	var value_label := UiKit.label("", 17, UiKit.COLOR_TEXT_DIM)
	header.add_child(value_label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = float(SaveSystem.setting(key))
	slider.custom_minimum_size = Vector2(0, 42)
	_style_slider(slider)
	value_label.text = "%d%%" % int(slider.value * 100.0)
	slider.value_changed.connect(func(v: float) -> void:
		SaveSystem.set_setting(key, v)
		value_label.text = "%d%%" % int(v * 100.0)
		on_change.call(v))
	content.add_child(slider)
	return row


func _make_vibration_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 104
	row.add_theme_constant_override("separation", 16)
	row.add_child(_row_icon("vibration"))
	var label := UiKit.label("VIBRATION", 21, UiKit.COLOR_GOLD)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var vib := CheckButton.new()
	vib.custom_minimum_size = Vector2(96, 58)
	vib.button_pressed = bool(SaveSystem.setting("vibration"))
	vib.toggled.connect(func(on: bool) -> void:
		SaveSystem.set_setting("vibration", on)
		AudioManager.vibrate(40))
	row.add_child(vib)
	return row


func _style_slider(slider: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color("17121f")
	track.set_corner_radius_all(8)
	track.border_color = Color("6f542c")
	track.set_border_width_all(2)
	track.content_margin_top = 9
	track.content_margin_bottom = 9
	slider.add_theme_stylebox_override("slider", track)
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = UiKit.COLOR_GOLD
	grabber.set_corner_radius_all(13)
	grabber.content_margin_left = 13
	grabber.content_margin_right = 13
	grabber.content_margin_top = 13
	grabber.content_margin_bottom = 13
	slider.add_theme_icon_override("grabber", _stylebox_texture(grabber))
	slider.add_theme_icon_override("grabber_highlight", _stylebox_texture(grabber))


func _stylebox_texture(style: StyleBoxFlat) -> Texture2D:
	var image := Image.create(30, 30, false, Image.FORMAT_RGBA8)
	image.fill(style.bg_color)
	return ImageTexture.create_from_image(image)


func _show_reset_confirm() -> void:
	if _confirm_panel != null:
		return
	_confirm_panel = Control.new()
	_confirm_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_confirm_panel)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
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
	box.add_child(UiKit.title_label("RESET EVERYTHING?", 31))
	box.add_child(UiKit.label("Crystals, permanent upgrades and stats\nwill be lost forever.", 21))
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	var yes := UiKit.button("RESET", Vector2(180, 60), Color("e05252"))
	yes.pressed.connect(func() -> void:
		SaveSystem.reset_progress()
		_close_confirm())
	buttons.add_child(yes)
	var no := UiKit.button("CANCEL", Vector2(180, 60))
	no.pressed.connect(_close_confirm)
	buttons.add_child(no)


func _close_confirm() -> void:
	if _confirm_panel != null:
		_confirm_panel.queue_free()
		_confirm_panel = null
