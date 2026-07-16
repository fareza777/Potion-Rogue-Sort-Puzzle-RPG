extends Control
## Full-height key-art menu. Flexible bands absorb extra-tall phone space so
## navigation never floats above an empty lower viewport.


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiKit.battle_background(self,
			"res://assets/art/backgrounds/shadow_crypt_battle.png")
	_add_vignette()
	var particles := AmbientParticles.new()
	particles.name = "AmbientEmbers"
	particles.set_anchors_preset(Control.PRESET_FULL_RECT)
	particles.set_reduced_effects(bool(ProjectSettings.get_setting(
			"potion_rogue/reduced_effects", false)))
	add_child(particles)
	var profile := UiKit.layout_profile(get_viewport_rect().size)
	var margin := UiKit.safe_margin(self, int(profile.safe_horizontal),
			int(profile.safe_top), maxi(int(profile.safe_bottom), 52))
	margin.name = "SafeContent"

	var root := VBoxContainer.new()
	root.name = "MainStack"
	root.add_theme_constant_override("separation", 7)
	margin.add_child(root)

	var title_band := VBoxContainer.new()
	title_band.name = "TitleBand"
	title_band.custom_minimum_size.y = 102
	title_band.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(title_band)
	title_band.add_child(UiKit.title_label("POTION ROGUE", 58))
	var subtitle := UiKit.label("SORT • BREW • CONQUER", 19, Color("d7b86f"))
	subtitle.add_theme_constant_override("outline_size", 5)
	subtitle.add_theme_color_override("font_outline_color", Color("160d16"))
	title_band.add_child(subtitle)

	var hero := Control.new()
	hero.name = "HeroBand"
	hero.custom_minimum_size.y = 390 if profile.name == "tall" else 330
	hero.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(hero)
	_build_hero(hero)

	var pitch := UiKit.textured_panel("res://assets/art/ui/battle_panel.png", 17)
	pitch.name = "PitchBand"
	pitch.custom_minimum_size.y = 122
	root.add_child(pitch)
	var pitch_box := VBoxContainer.new()
	pitch_box.alignment = BoxContainer.ALIGNMENT_CENTER
	pitch.add_child(pitch_box)
	pitch_box.add_child(UiKit.title_label("THE DUNGEON AWAITS", 22))
	var seals := HBoxContainer.new()
	seals.name = "FeatureSeals"
	seals.alignment = BoxContainer.ALIGNMENT_CENTER
	seals.add_theme_constant_override("separation", 8)
	pitch_box.add_child(seals)
	seals.add_child(_feature_seal("SORT", "MATCH COLORS"))
	seals.add_child(_feature_seal("BREW", "UNLEASH POWER"))
	seals.add_child(_feature_seal("CONQUER", "CLEAR THE CRYPT"))

	var action := VBoxContainer.new()
	action.name = "ActionBand"
	action.custom_minimum_size.y = 205
	action.alignment = BoxContainer.ALIGNMENT_CENTER
	action.add_theme_constant_override("separation", 7)
	root.add_child(action)
	var play := UiKit.ornate_button("ENTER THE DUNGEON", Vector2(500, 78))
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.pressed.connect(_on_play_pressed)
	action.add_child(play)
	var safe_nav := VBoxContainer.new()
	safe_nav.name = "SafeNavigation"
	safe_nav.alignment = BoxContainer.ALIGNMENT_CENTER
	safe_nav.add_theme_constant_override("separation", 5)
	action.add_child(safe_nav)
	var utility := HBoxContainer.new()
	utility.alignment = BoxContainer.ALIGNMENT_CENTER
	utility.add_theme_constant_override("separation", 8)
	safe_nav.add_child(utility)
	utility.add_child(_menu_button("UPGRADES", "res://scenes/shop.tscn"))
	utility.add_child(_menu_button("SETTINGS", "res://scenes/settings.tscn"))
	utility.add_child(_menu_button("CREDITS", "res://scenes/credits.tscn"))
	var currency := UiKit.label("◆  %d CRYSTALS" % SaveSystem.crystals(), 19,
			Color("75d4ff"))
	currency.add_theme_constant_override("outline_size", 4)
	currency.add_theme_color_override("font_outline_color", Color.BLACK)
	safe_nav.add_child(currency)
	AudioManager.play_music("dungeon")


func _add_vignette() -> void:
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.025, 0.015, 0.04, 0.26)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)


func _build_hero(parent: Control) -> void:
	var aura := TextureRect.new()
	aura.name = "HeroHalo"
	aura.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	aura.texture = VisualRegistry.texture_or_null(
			"res://assets/art/enemies/slime/cave_slime_shadow.png")
	aura.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	aura.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	aura.modulate = Color(0.48, 0.20, 0.82, 0.32)
	parent.add_child(aura)
	var portrait := UiKit.enemy_portrait("slime", Vector2.ZERO)
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(portrait)
	portrait.pivot_offset = Vector2(326, 190)
	var idle := create_tween().set_loops()
	idle.tween_property(portrait, "position:y", -7.0, 1.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	idle.tween_property(portrait, "position:y", 7.0, 1.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _feature_seal(title: String, detail: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(150, 43)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.025, 0.055, 0.86)
	style.border_color = Color("725b31")
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", -4)
	panel.add_child(box)
	box.add_child(UiKit.label(title, 13, UiKit.COLOR_GOLD))
	box.add_child(UiKit.label(detail, 9, UiKit.COLOR_TEXT_DIM))
	return panel


func _menu_button(text: String, scene_path: String) -> Button:
	var b := UiKit.ornate_button(text, Vector2(180, 58), UiKit.COLOR_TEXT_DIM)
	b.add_theme_font_size_override("font_size", 17)
	b.pressed.connect(func() -> void:
		get_tree().change_scene_to_file(scene_path))
	return b


func _on_play_pressed() -> void:
	RunState.start_new_run()
	get_tree().change_scene_to_file("res://scenes/map.tscn")
