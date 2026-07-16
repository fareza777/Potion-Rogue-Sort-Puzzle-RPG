extends Control
## Premium key-art main menu built from the same authored battle assets.


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiKit.battle_background(self,
			"res://assets/art/backgrounds/shadow_crypt_battle.png")
	_add_vignette()

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_top", 42)
	margin.add_theme_constant_override("margin_bottom", 34)
	add_child(margin)

	var root := VBoxContainer.new()
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 6)
	margin.add_child(root)

	root.add_child(UiKit.title_label("POTION ROGUE", 58))
	var subtitle := UiKit.label("SORT • BREW • CONQUER", 20, Color("d7b86f"))
	subtitle.add_theme_constant_override("outline_size", 5)
	subtitle.add_theme_color_override("font_outline_color", Color("160d16"))
	root.add_child(subtitle)

	var hero := Control.new()
	hero.custom_minimum_size = Vector2(0, 320)
	root.add_child(hero)
	_build_hero(hero)

	var pitch := UiKit.textured_panel("res://assets/art/ui/battle_panel.png", 18)
	pitch.custom_minimum_size = Vector2(0, 112)
	pitch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(pitch)
	var pitch_box := VBoxContainer.new()
	pitch_box.add_theme_constant_override("separation", 2)
	pitch.add_child(pitch_box)
	pitch_box.add_child(UiKit.title_label("THE DUNGEON AWAITS", 25))
	pitch_box.add_child(UiKit.label(
			"Sort enchanted potions. Build impossible combos.\nDefeat every guardian of the Shadow Crypt.",
			17, UiKit.COLOR_TEXT_DIM))

	var play := UiKit.ornate_button("ENTER THE DUNGEON", Vector2(500, 82))
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.pressed.connect(_on_play_pressed)
	root.add_child(play)

	var utility := HBoxContainer.new()
	utility.alignment = BoxContainer.ALIGNMENT_CENTER
	utility.add_theme_constant_override("separation", 10)
	root.add_child(utility)
	utility.add_child(_menu_button("UPGRADES", "res://scenes/shop.tscn"))
	utility.add_child(_menu_button("SETTINGS", "res://scenes/settings.tscn"))
	utility.add_child(_menu_button("CREDITS", "res://scenes/credits.tscn"))

	var currency := UiKit.label("◆  %d CRYSTALS" % SaveSystem.crystals(), 19,
			Color("75d4ff"))
	currency.add_theme_constant_override("outline_size", 4)
	currency.add_theme_color_override("font_outline_color", Color.BLACK)
	root.add_child(currency)
	AudioManager.play_music("dungeon")


func _add_vignette() -> void:
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.025, 0.015, 0.04, 0.3)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)


func _build_hero(parent: Control) -> void:
	var aura := TextureRect.new()
	aura.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	aura.texture = VisualRegistry.texture_or_null(
			"res://assets/art/enemies/slime/cave_slime_shadow.png")
	aura.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	aura.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	aura.modulate = Color(0.45, 0.18, 0.8, 0.62)
	parent.add_child(aura)

	var portrait := UiKit.enemy_portrait("slime", Vector2.ZERO)
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait.position.y = 4.0
	parent.add_child(portrait)
	portrait.pivot_offset = Vector2(326, 160)
	var idle := create_tween().set_loops()
	idle.tween_property(portrait, "position:y", -5.0, 1.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	idle.tween_property(portrait, "position:y", 5.0, 1.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _menu_button(text: String, scene_path: String) -> Button:
	var b := UiKit.ornate_button(text, Vector2(180, 58), UiKit.COLOR_TEXT_DIM)
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(func() -> void:
		get_tree().change_scene_to_file(scene_path))
	return b


func _on_play_pressed() -> void:
	RunState.start_new_run()
	get_tree().change_scene_to_file("res://scenes/map.tscn")
