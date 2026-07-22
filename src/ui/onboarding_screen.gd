extends Control
## Six animated, skippable chapters before the interactive battle tutorial.

const PAGES := [
	{"id":"sort", "eyebrow":"THE ALCHEMY TABLE", "title":"SORT THE ESSENCE",
		"body":"Tap a source flask, then an empty flask or one with the same top color. Only connected top layers pour.", "accent":"62d8ff"},
	{"id":"brew", "eyebrow":"POTION EFFECTS", "title":"BREW YOUR POWER",
		"body":"Complete four matching layers. Red damages, Green heals, Blue shields, and Purple poisons through Armor.", "accent":"f1c45c"},
	{"id":"survive", "eyebrow":"ENEMY INTENT", "title":"COUNT EVERY POUR",
		"body":"Each successful pour spends one move. When the intent countdown reaches zero, the enemy performs its shown action.", "accent":"ff8a68"},
	{"id":"react", "eyebrow":"ALCHEMY REACTIONS", "title":"THE THREE COLORED DOTS",
		"body":"The dots remember your last three completed potion colors. Their order forms reactions: Red then Red triggers Fire Burst.", "accent":"d99aff"},
	{"id":"cast", "eyebrow":"HERO POWERS", "title":"MANA, SKILL & ULTIMATE",
		"body":"Potions generate Mana for your active Skill. Reactions separately charge your Ultimate; at 100% it becomes available.", "accent":"70d9ff"},
	{"id":"explore", "eyebrow":"ROGUELIKE EXPEDITION", "title":"CHOOSE YOUR FATE",
		"body":"Every run creates new hidden routes, enemies, events, relics, and battle formats. Your exact progress is saved automatically.", "accent":"be7cff"},
]

var _page := 0
var _eyebrow: Label
var _title: Label
var _body: Label
var _dots: Label
var _back: Button
var _next: Button
var _card: PanelContainer
var _demo: OnboardingDemo


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiKit.battle_background(self, "res://assets/art/backgrounds/launch_splash_v3.jpg")
	var shade := ColorRect.new(); shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.005, 0.002, 0.02, 0.42); shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var margin := UiKit.safe_margin(self, 26, 44, 26)
	var root := VBoxContainer.new(); root.alignment = BoxContainer.ALIGNMENT_END
	root.add_theme_constant_override("separation", 8); margin.add_child(root)
	var skip := UiKit.button("SKIP", Vector2(118, 50), Color("b9a9c8"))
	skip.size_flags_horizontal = Control.SIZE_SHRINK_END; skip.pressed.connect(_finish); root.add_child(skip)
	var brand := UiKit.title_label("POTION ROGUE", 42, Color("f1cf79"))
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brand.add_theme_color_override("font_shadow_color", Color(0.1, 0.02, 0.18, 0.95))
	brand.add_theme_constant_override("shadow_offset_x", 3); brand.add_theme_constant_override("shadow_offset_y", 4)
	root.add_child(brand)
	var legend := UiKit.label("A ROGUE ALCHEMIST'S JOURNEY", 13, Color("cdb5ef"))
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; root.add_child(legend)
	var spacer := Control.new(); spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL; root.add_child(spacer)
	_demo = OnboardingDemo.new(); root.add_child(_demo)
	_card = UiKit.textured_panel("res://assets/art/ui/battle_panel.png", 22)
	_card.custom_minimum_size = Vector2(0, 340); root.add_child(_card)
	var content := VBoxContainer.new(); content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 12); _card.add_child(content)
	_eyebrow = UiKit.label("", 13, Color("8edcff")); _eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_eyebrow)
	_title = UiKit.title_label("", 33); _title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; content.add_child(_title)
	_body = UiKit.label("", 17, UiKit.COLOR_TEXT); _body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; _body.custom_minimum_size = Vector2(0, 92); content.add_child(_body)
	_dots = UiKit.label("", 18, Color("d8b6ff")); _dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; content.add_child(_dots)
	var actions := HBoxContainer.new(); actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12); content.add_child(actions)
	_back = UiKit.ornate_button("BACK", Vector2(180, 62), Color("8d70b8")); _back.pressed.connect(_previous); actions.add_child(_back)
	_next = UiKit.ornate_button("NEXT", Vector2(240, 62), Color("f1c45c")); _next.pressed.connect(_advance); actions.add_child(_next)
	_show_page()


func _show_page() -> void:
	var data: Dictionary = PAGES[_page]
	_eyebrow.text = str(data.eyebrow); _title.text = str(data.title)
	_title.add_theme_color_override("font_color", Color(str(data.accent))); _body.text = str(data.body)
	var page_marks: Array[String] = []
	for index in PAGES.size(): page_marks.append("◆" if index == _page else "◇")
	_dots.text = "  ".join(page_marks); _back.disabled = _page == 0
	_next.text = "ENTER THE DUNGEON" if _page == PAGES.size() - 1 else "NEXT"
	_demo.show_chapter(str(data.id), bool(SaveSystem.setting("reduced_effects")))
	_card.modulate.a = 0.35; _card.scale = Vector2(0.97, 0.97); _card.pivot_offset = _card.size * 0.5
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_card, "modulate:a", 1.0, 0.32).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.tween_property(_card, "scale", Vector2.ONE, 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _advance() -> void:
	if _page >= PAGES.size() - 1: _finish(); return
	_page += 1; _show_page()


func _previous() -> void:
	_page = maxi(_page - 1, 0); _show_page()


func _finish() -> void:
	SaveSystem.mark_onboarding_done()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
