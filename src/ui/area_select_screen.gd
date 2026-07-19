extends Control

const AREA_GRAMMAR := preload("res://src/run/area_grammar.gd")
## Campaign expedition selector. Locked destinations remain visible so the
## player always understands long-term progression and first-clear rewards.

var _ascension_label: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiKit.battle_background(self, VisualRegistry.background("main_hall"))
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.008, 0.005, 0.02, 0.74)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var margin := UiKit.safe_margin(self, 22, 28, 22)
	var root := VBoxContainer.new()
	root.name = "ExpeditionStack"
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)
	var title := UiKit.title_label("CHOOSE EXPEDITION", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)
	var subtitle := UiKit.label("Each realm has its own roster, boss, hazards and rewards.", 16, UiKit.COLOR_TEXT_DIM)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(subtitle)
	var modes := HBoxContainer.new(); modes.alignment = BoxContainer.ALIGNMENT_CENTER
	modes.add_theme_constant_override("separation", 10); root.add_child(modes)
	var utc_date := Time.get_date_string_from_system(true)
	var daily_caption := "LOCAL DAILY  •  CLAIMED" if MetaProgression.new().daily_claimed(utc_date) \
			else "LOCAL DAILY  +15"
	var daily := UiKit.ornate_button(daily_caption, Vector2(250, 58), Color("62b9ff"))
	daily.add_theme_font_size_override("font_size", 17)
	daily.pressed.connect(_start_daily); modes.add_child(daily)
	var history := UiKit.ornate_button("RUN HISTORY", Vector2(220, 58), Color("b67cff"))
	history.add_theme_font_size_override("font_size", 17)
	history.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/run_history.tscn")); modes.add_child(history)
	var mode_help := UiKit.label("Daily: same challenge for everyone today  •  History: latest 20 runs",
			12, UiKit.COLOR_TEXT_DIM); root.add_child(mode_help)
	if MetaProgression.new().ascension_unlocked():
		root.add_child(_make_ascension_selector())
	var scroll := ScrollContainer.new(); scroll.name = "ExpeditionScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; root.add_child(scroll)
	var area_list := VBoxContainer.new(); area_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	area_list.add_theme_constant_override("separation", 10); scroll.add_child(area_list)
	for id in GameState.area_ids():
		area_list.add_child(_area_card(id))
	var back := UiKit.ornate_button("BACK TO HALL", Vector2(360, 62))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	root.add_child(back)


func _area_card(area_id: String) -> PanelContainer:
	var area := GameState.area(area_id)
	var unlocked := SaveSystem.is_area_unlocked(area_id)
	var cleared := area_id in SaveSystem.completed_areas()
	var card := UiKit.textured_panel("res://assets/art/ui/battle_panel.png", 18)
	card.name = "AreaCard_" + area_id
	card.custom_minimum_size = Vector2(0, 218)
	card.modulate = Color.WHITE if unlocked else Color(0.55, 0.56, 0.64, 0.88)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", UiThemeTokens.SPACE.sm)
	card.add_child(stack)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	stack.add_child(row)
	var crest := TextureRect.new()
	crest.custom_minimum_size = Vector2(152, 190)
	crest.texture = VisualRegistry.enemy_texture(str(area.get("boss", "fire_golem")))
	crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crest.modulate = Color.WHITE if unlocked else Color(0.22, 0.22, 0.28, 1.0)
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(crest)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 5)
	row.add_child(info)
	info.add_child(UiKit.title_label(str(area.get("name", area_id)).to_upper(), 25,
			_area_color(area_id)))
	info.add_child(UiKit.label(str(area.get("subtitle", "Seven-depth expedition")), 14, UiKit.COLOR_TEXT))
	var run_length := int(AREA_GRAMMAR.for_area(area_id).get("run_length", 7))
	var progress := "CLEARED %d TIMES" % SaveSystem.area_wins(area_id) if cleared else (
			"BEST DEPTH %d / %d" % [SaveSystem.best_depth(area_id), run_length]
			if unlocked else "LOCKED")
	info.add_child(UiKit.label(progress, 13, UiKit.COLOR_GOLD if unlocked else UiKit.COLOR_TEXT_DIM))
	if not cleared:
		info.add_child(UiKit.label("FIRST CLEAR  +%d CRYSTALS" % int(area.get("first_clear_reward", 0)),
				13, Color("77d8ff")))
	elif unlocked:
		var rematch := UiKit.ornate_button("BOSS REMATCH", Vector2(190, 58), Color("d06b63"))
		rematch.pressed.connect(func() -> void:
			RunState.pending_area_id = area_id; RunState.pending_run_mode = "rematch"
			get_tree().change_scene_to_file("res://scenes/kit_select.tscn"))
		info.add_child(rematch)
	var action := UiKit.ornate_button("ENTER EXPEDITION" if unlocked else "LOCKED", Vector2(0, 62),
			_area_color(area_id))
	action.name = "AreaAction"
	action.disabled = not unlocked
	action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action.pressed.connect(func() -> void:
		RunState.pending_area_id = area_id
		RunState.pending_run_mode = "normal"
		RunState.pending_ascension = SaveSystem.selected_ascension()
		SaveSystem.set_selected_area(area_id)
		get_tree().change_scene_to_file("res://scenes/kit_select.tscn"))
	stack.add_child(action)
	return card


func _area_color(area_id: String) -> Color:
	return UiThemeTokens.REALM_ACCENTS.get(area_id, UiKit.COLOR_GOLD)


func _start_daily() -> void:
	var date := Time.get_date_string_from_system(true)
	RunState.pending_area_id = SaveSystem.selected_area()
	RunState.pending_run_mode = "daily"
	RunState.pending_ascension = 0
	RunState.pending_run_seed = MetaProgression.new().daily_seed(date)
	get_tree().change_scene_to_file("res://scenes/kit_select.tscn")


func _make_ascension_selector() -> PanelContainer:
	var panel := UiKit.panel(Color("b67cff"))
	panel.name = "AscensionSelector"
	panel.custom_minimum_size = Vector2(0, 62)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	var down := UiKit.ornate_button("−", Vector2(58, 56), Color("8d70b8"))
	down.pressed.connect(func(): _change_ascension(-1))
	row.add_child(down)
	_ascension_label = UiKit.title_label("", 18, Color("d9b7ff"))
	_ascension_label.custom_minimum_size = Vector2(250, 0)
	_ascension_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_ascension_label)
	var up := UiKit.ornate_button("+", Vector2(58, 56), Color("8d70b8"))
	up.pressed.connect(func(): _change_ascension(1))
	row.add_child(up)
	_refresh_ascension_label()
	return panel


func _change_ascension(delta: int) -> void:
	SaveSystem.set_selected_ascension(SaveSystem.selected_ascension() + delta)
	RunState.pending_ascension = SaveSystem.selected_ascension()
	_refresh_ascension_label()


func _refresh_ascension_label() -> void:
	if _ascension_label:
		_ascension_label.text = "ASCENSION  %d / %d" % [SaveSystem.selected_ascension(),
				SaveSystem.max_ascension()]
		var rules := GameState.load_data_file("ascension_rules.json", {})
		var level := SaveSystem.selected_ascension()
		_ascension_label.tooltip_text = "No modifiers" if level == 0 else \
				str(rules.get(str(level), {}).get("description", "Unknown modifier"))
