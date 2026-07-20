extends Control
## Three concise, skippable pages before the existing interactive tutorial.

const PAGES := [
	{"eyebrow":"THE ALCHEMY TABLE", "title":"SORT THE ESSENCE",
		"body":"Tap a bottle, then pour onto an empty bottle or the same top color. Complete four matching layers to brew a potion.",
		"accent":"62d8ff"},
	{"eyebrow":"BATTLE ALCHEMY", "title":"BREW YOUR ATTACK",
		"body":"Red strikes, green heals, blue shields, and purple poisons. Watch the enemy countdown—every pour advances the battle.",
		"accent":"f1c45c"},
	{"eyebrow":"ROGUELIKE EXPEDITION", "title":"CHOOSE YOUR FATE",
		"body":"Every run creates new hidden routes, enemies, events, relics, and battle formats. Your exact progress is saved automatically.",
		"accent":"be7cff"},
]

var _page := 0
var _eyebrow: Label
var _title: Label
var _body: Label
var _dots: Label
var _back: Button
var _next: Button
var _card: PanelContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiKit.battle_background(self, "res://assets/art/backgrounds/launch_splash_v2.jpg")
	var shade := ColorRect.new(); shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.005, 0.002, 0.02, 0.58); shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var margin := UiKit.safe_margin(self, 26, 54, 34)
	var root := VBoxContainer.new(); root.alignment = BoxContainer.ALIGNMENT_END
	root.add_theme_constant_override("separation", 14); margin.add_child(root)
	var skip := UiKit.button("SKIP", Vector2(118, 52), Color("b9a9c8"))
	skip.size_flags_horizontal = Control.SIZE_SHRINK_END; skip.pressed.connect(_finish)
	root.add_child(skip)
	var spacer := Control.new(); spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(spacer)
	_card = UiKit.textured_panel("res://assets/art/ui/battle_panel.png", 24)
	_card.custom_minimum_size = Vector2(0, 430); root.add_child(_card)
	var content := VBoxContainer.new(); content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 16); _card.add_child(content)
	_eyebrow = UiKit.label("", 13, Color("8edcff")); _eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_eyebrow)
	_title = UiKit.title_label("", 37); _title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_title)
	_body = UiKit.label("", 19, UiKit.COLOR_TEXT); _body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; _body.custom_minimum_size = Vector2(0, 132)
	content.add_child(_body)
	_dots = UiKit.label("", 20, Color("d8b6ff")); _dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_dots)
	var actions := HBoxContainer.new(); actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 14); content.add_child(actions)
	_back = UiKit.ornate_button("BACK", Vector2(190, 66), Color("8d70b8")); _back.pressed.connect(_previous)
	actions.add_child(_back)
	_next = UiKit.ornate_button("NEXT", Vector2(250, 66), Color("f1c45c")); _next.pressed.connect(_advance)
	actions.add_child(_next)
	_show_page()


func _show_page() -> void:
	var data: Dictionary = PAGES[_page]
	_eyebrow.text = str(data.eyebrow)
	_title.text = str(data.title)
	_title.add_theme_color_override("font_color", Color(str(data.accent)))
	_body.text = str(data.body)
	var page_marks: Array[String] = []
	for index in PAGES.size():
		page_marks.append("◆" if index == _page else "◇")
	_dots.text = "  ".join(page_marks)
	_back.disabled = _page == 0
	_next.text = "ENTER THE DUNGEON" if _page == PAGES.size() - 1 else "NEXT"
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
