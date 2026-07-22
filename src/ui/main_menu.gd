extends Control
## Full-height alchemy hall menu. Generated key art carries the hero scene while
## code-rendered controls remain crisp, localized, and touch accessible.


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiKit.battle_background(self, VisualRegistry.background("main_hall"))
	_add_readability_scrims()
	var particles := AmbientParticles.new()
	particles.name = "AmbientEmbers"
	particles.set_anchors_preset(Control.PRESET_FULL_RECT)
	particles.set_reduced_effects(bool(SaveSystem.setting("reduced_effects")))
	add_child(particles)
	_build_interface()
	AudioManager.play_music("dungeon")
	AudioManager.set_scene_state("hall")


func _build_interface() -> void:
	var profile := UiKit.layout_profile(get_viewport_rect().size)
	var view_w := get_viewport_rect().size.x
	var narrow := view_w < 640.0
	var margin := UiKit.safe_margin(self, 16 if narrow else 18,
			int(profile.safe_top * 0.55), 10)
	margin.name = "SafeContent"
	var root := VBoxContainer.new()
	root.name = "MainStack"
	root.add_theme_constant_override("separation", 6)
	margin.add_child(root)

	var logo := VBoxContainer.new()
	logo.name = "HallLogo"
	logo.custom_minimum_size.y = 176 if narrow else 200
	logo.alignment = BoxContainer.ALIGNMENT_CENTER
	logo.add_theme_constant_override("separation", -18 if narrow else -22)
	root.add_child(logo)
	_add_status_row(logo)
	logo.add_child(_logo_line("POTION", 58 if narrow else 68, Color("d8ecff"), Color("315c9b")))
	logo.add_child(_logo_line("ROGUE", 68 if narrow else 78, Color("ffd17a"), Color("8c3d08")))
	var subtitle := UiKit.label("SORT PUZZLE RPG", 15 if narrow else 17, Color("eee0ff"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_constant_override("outline_size", 6)
	subtitle.add_theme_color_override("font_outline_color", Color("24102f"))
	logo.add_child(subtitle)
	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(minf(280.0, view_w * 0.55), 2)
	rule.color = Color("e8c069", 0.55)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.add_child(rule)

	var hero := Control.new()
	hero.name = "HeroAlchemy"
	hero.custom_minimum_size.y = 300 if profile.name == "tall" else (260 if narrow else 310)
	hero.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hero)

	var commands := VBoxContainer.new()
	commands.name = "CommandStack"
	commands.custom_minimum_size.y = 300 if narrow else 292
	commands.alignment = BoxContainer.ALIGNMENT_END
	commands.add_theme_constant_override("separation", 8)
	root.add_child(commands)
	var btn_w := mini(520.0, view_w - 48.0)
	var new_run := _command_button("NEW RUN", Color("f6b61f"), btn_w, 76 if narrow else 72)
	new_run.pressed.connect(_on_new_run_pressed)
	commands.add_child(new_run)
	var continue_run := _command_button("CONTINUE" if RunState.active else "NO ACTIVE RUN",
			Color("2696e8"), btn_w, 64)
	continue_run.disabled = not RunState.active
	continue_run.pressed.connect(_on_continue_pressed)
	commands.add_child(continue_run)
	var secondary := HBoxContainer.new()
	secondary.alignment = BoxContainer.ALIGNMENT_CENTER
	secondary.add_theme_constant_override("separation", 10)
	commands.add_child(secondary)
	var guide := _command_button("GUIDE", Color("257fa9"), btn_w * 0.31, 58)
	guide.add_theme_font_size_override("font_size", 19)
	guide.pressed.connect(func() -> void:
		GuideScreen.return_scene = "res://scenes/main_menu.tscn"
		get_tree().change_scene_to_file("res://scenes/guide.tscn"))
	secondary.add_child(guide)
	var upgrades := _command_button("UPGRADES", Color("52a83f"), btn_w * 0.31, 58)
	upgrades.add_theme_font_size_override("font_size", 19)
	upgrades.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/shop.tscn"))
	secondary.add_child(upgrades)
	var settings := _command_button("SETTINGS", Color("7948aa"), btn_w * 0.31, 58)
	settings.add_theme_font_size_override("font_size", 19)
	settings.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/settings.tscn"))
	secondary.add_child(settings)

	var nav := BottomNav.new()
	nav.name = "BottomNavigation"
	root.add_child(nav)
	nav.add_item("home", "Home", Callable(), true)
	nav.add_item("areas", "Areas", func(): get_tree().change_scene_to_file("res://scenes/area_select.tscn"))
	nav.add_item("build", "Build", func(): get_tree().change_scene_to_file("res://scenes/shop.tscn"))
	nav.add_item("history", "History", func(): get_tree().change_scene_to_file("res://scenes/run_history.tscn"))
	nav.add_item("credits", "Credits", func(): get_tree().change_scene_to_file("res://scenes/credits.tscn"))


func _add_status_row(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 34
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var offline := UiKit.label("●  OFFLINE", 13, Color("8bea91"))
	offline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	offline.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(offline)
	var crystals := UiKit.label("◆  %d" % SaveSystem.crystals(), 17,
			Color("7ad7ff"))
	crystals.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(crystals)
	parent.add_child(row)


func _logo_line(text: String, size: int, face: Color, shadow: Color) -> Label:
	var line := UiKit.title_label(text, size, face)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.add_theme_constant_override("outline_size", 13)
	line.add_theme_color_override("font_outline_color", Color("120914"))
	line.add_theme_constant_override("shadow_offset_x", 0)
	line.add_theme_constant_override("shadow_offset_y", 6)
	line.add_theme_color_override("font_shadow_color", shadow)
	return line


func _command_button(text: String, accent: Color, width := 520.0,
		height := 68.0) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(width, height)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_override("font", UiKit.title_font())
	button.add_theme_font_size_override("font_size", 28 if height >= 70 else 24)
	button.add_theme_color_override("font_color", Color("fff7df"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color("f1d69a"))
	button.add_theme_constant_override("outline_size", 5)
	button.add_theme_color_override("font_outline_color", accent.darkened(0.7))
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = accent.darkened(0.45 if state == "normal" else 0.32)
		style.border_color = Color("f2cc68") if state != "pressed" \
				else Color("9f7a31")
		style.set_border_width_all(3)
		style.set_corner_radius_all(12)
		style.content_margin_left = 34
		style.content_margin_right = 34
		style.shadow_color = Color(accent, 0.42)
		style.shadow_size = 10 if state == "hover" else 6
		button.add_theme_stylebox_override(state, style)
	var ornament := TextureRect.new()
	ornament.name = "CommandOrnament"
	ornament.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ornament.texture = VisualRegistry.texture_or_null(
			"res://assets/art/ui/banner_turn.png")
	ornament.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ornament.stretch_mode = TextureRect.STRETCH_SCALE
	ornament.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ornament.modulate = Color("ffe4a0")
	ornament.material = _frame_cutout_material()
	button.add_child(ornament)
	return button


func _frame_cutout_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float lightness = max(tex.r, max(tex.g, tex.b));
	float frame_alpha = smoothstep(0.14, 0.30, lightness);
	COLOR = vec4(tex.rgb, tex.a * frame_alpha);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


func _nav_button(text: String, scene_path: String, starts_run := false) -> Button:
	var button := Button.new()
	button.text = "◆\n" + text
	button.custom_minimum_size = Vector2(102, 78)
	button.add_theme_font_override("font", UiKit.title_font())
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", Color("cbb26f"))
	button.add_theme_color_override("font_hover_color", Color("fff0b8"))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.018, 0.045, 0.92)
	style.border_color = Color("725629")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("focus", style)
	if not scene_path.is_empty():
		button.pressed.connect(func() -> void:
			if starts_run and not RunState.active:
				get_tree().change_scene_to_file("res://scenes/area_select.tscn")
			elif starts_run:
				get_tree().change_scene_to_file(RunState.resume_scene())
			else:
				get_tree().change_scene_to_file(scene_path))
	return button


func _add_readability_scrims() -> void:
	var top := ColorRect.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 250
	top.color = Color(0.015, 0.008, 0.03, 0.3)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	var bottom := ColorRect.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -455
	bottom.color = Color(0.01, 0.006, 0.02, 0.32)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom)


func _on_new_run_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/area_select.tscn")


func _on_continue_pressed() -> void:
	if not RunState.active:
		return
	get_tree().change_scene_to_file(RunState.resume_scene())
