extends Control

const AREA_GRAMMAR := preload("res://src/run/area_grammar.gd")
## Campaign expedition selector. Locked destinations remain visible so the
## player always understands long-term progression and first-clear rewards.

var _ascension_label: Label
var _ascension_rules_label: Label
var _area_scroll: ScrollContainer
var _preview_background: TextureRect
var _preview_label: Label
var _background_tween: Tween


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_preview_background = UiKit.battle_background(self, VisualRegistry.background("main_hall"))
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.008, 0.005, 0.02, 0.74)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var narrow := get_viewport_rect().size.x < 640.0
	var side := 14 if narrow else 22
	var margin := UiKit.safe_margin(self, side, 24 if narrow else 28, side)
	var root := VBoxContainer.new()
	root.name = "ExpeditionStack"
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 10 if narrow else 12)
	margin.add_child(root)
	var title := UiKit.title_label("CHOOSE EXPEDITION", 34 if narrow else 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)
	var subtitle := UiKit.label("Each realm has its own roster, boss, hazards and rewards.",
			14 if narrow else 16, UiKit.COLOR_TEXT_DIM)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(subtitle)
	_preview_label = UiKit.label("SELECT A REALM TO PREVIEW", 12 if narrow else 13, UiKit.COLOR_GOLD)
	_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_preview_label)
	var modes := HBoxContainer.new(); modes.alignment = BoxContainer.ALIGNMENT_CENTER
	modes.add_theme_constant_override("separation", 4 if narrow else 6); root.add_child(modes)
	var meta := MetaProgression.new()
	var utc_date := Time.get_date_string_from_system(true)
	var daily_spec := meta.daily_spec(utc_date)
	var daily_caption := "DAILY  •  CLAIMED" if meta.daily_claimed(utc_date) \
			else "DAILY  +15"
	var mode_w := 118.0 if narrow else 152.0
	var daily := UiKit.ornate_button(daily_caption, Vector2(mode_w, 58), Color("62b9ff"))
	daily.name = "DailyChallenge"
	daily.add_theme_font_size_override("font_size", 14 if narrow else 17)
	daily.clip_text = true
	daily.pressed.connect(_start_daily); modes.add_child(daily)
	var week_key := meta.current_week_key()
	var weekly_spec := meta.weekly_spec(week_key)
	var weekly_claimed: bool = (SaveSystem.data.get("weekly_records", {})
			as Dictionary).has(week_key)
	var weekly := UiKit.ornate_button("WEEKLY  •  DONE" if weekly_claimed
			else "WEEKLY  +25", Vector2(mode_w, 58), Color("e88cff"))
	weekly.name = "WeeklyChallenge"
	weekly.add_theme_font_size_override("font_size", 14 if narrow else 16)
	weekly.clip_text = true
	weekly.pressed.connect(_start_weekly); modes.add_child(weekly)
	var history := UiKit.ornate_button("HISTORY", Vector2(mode_w, 58), Color("b67cff"))
	history.name = "RunHistory"
	history.add_theme_font_size_override("font_size", 14 if narrow else 17)
	history.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/run_history.tscn")); modes.add_child(history)
	# The authored identity of today's challenges, spelled out honestly.
	var daily_area := str(GameState.area(str(daily_spec.area_id)).get("name",
			daily_spec.area_id))
	var weekly_area := str(GameState.area(str(weekly_spec.area_id)).get("name",
			weekly_spec.area_id))
	var weekly_kit := str(GameState.kits.get(str(weekly_spec.kit_id), {}).get(
			"name", weekly_spec.kit_id))
	var mode_help := UiKit.label(
			"Today: %s + %s twist   •   Week: %s with %s" % [daily_area,
			str(daily_spec.twist_name), weekly_area, weekly_kit],
			12, UiKit.COLOR_TEXT_DIM)
	mode_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(mode_help)
	if MetaProgression.new().ascension_unlocked():
		root.add_child(_make_ascension_selector())
	_area_scroll = ScrollContainer.new(); _area_scroll.name = "ExpeditionScroll"
	_area_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_area_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_area_scroll.scroll_deadzone = 8
	_area_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; root.add_child(_area_scroll)
	var area_list := VBoxContainer.new(); area_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	area_list.add_theme_constant_override("separation", 10); _area_scroll.add_child(area_list)
	for id in GameState.area_ids():
		area_list.add_child(_area_card(id))
	var scroll_cue := UiKit.label("⌄  SWIPE TO EXPLORE EVERY REALM  ⌄", 12, Color("d8b6ff"))
	scroll_cue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(scroll_cue)
	var cue_tween := create_tween().set_loops()
	cue_tween.tween_property(scroll_cue, "modulate:a", 0.38, 0.8).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	cue_tween.tween_property(scroll_cue, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	var back := UiKit.ornate_button("BACK TO HALL", Vector2(360, 62))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	root.add_child(back)


func _input(event: InputEvent) -> void:
	if not is_instance_valid(_area_scroll): return
	var distance := 0.0
	var pointer := Vector2.ZERO
	if event is InputEventScreenDrag:
		distance = -event.relative.y
		pointer = event.position
	elif event is InputEventPanGesture:
		distance = event.delta.y * 64.0
		pointer = event.position
	else:
		return
	if not _area_scroll.get_global_rect().has_point(pointer): return
	var bar := _area_scroll.get_v_scroll_bar()
	var limit := maxi(roundi(bar.max_value - bar.page), 0)
	if limit <= 0: return
	_area_scroll.scroll_vertical = clampi(
			_area_scroll.scroll_vertical + roundi(distance), 0, limit)
	get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	_input(event)


func _area_card(area_id: String) -> PanelContainer:
	var area := GameState.area(area_id)
	var unlocked := SaveSystem.is_area_unlocked(area_id)
	var cleared := area_id in SaveSystem.completed_areas()
	var narrow := get_viewport_rect().size.x < 640.0
	var card := UiKit.textured_panel("res://assets/art/ui/battle_panel.png",
			12 if narrow else 18)
	card.name = "AreaCard_" + area_id
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 200 if narrow else 218)
	card.modulate = Color.WHITE if unlocked else Color(0.55, 0.56, 0.64, 0.88)
	card.mouse_entered.connect(_preview_area.bind(area_id))
	card.focus_entered.connect(_preview_area.bind(area_id))
	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventScreenTouch and event.pressed: _preview_area(area_id))
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", UiThemeTokens.SPACE.sm)
	card.add_child(stack)
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10 if narrow else 16)
	stack.add_child(row)
	var crest := TextureRect.new()
	crest.custom_minimum_size = Vector2(110 if narrow else 152, 150 if narrow else 190)
	crest.texture = VisualRegistry.enemy_texture(str(area.get("boss", "fire_golem")))
	crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crest.modulate = Color.WHITE if unlocked else Color(0.22, 0.22, 0.28, 1.0)
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(crest)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 4 if narrow else 5)
	row.add_child(info)
	var name_lbl := UiKit.title_label(str(area.get("name", area_id)).to_upper(),
			20 if narrow else 25, _area_color(area_id))
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(name_lbl)
	var sub_lbl := UiKit.label(str(area.get("subtitle", "Seven-depth expedition")),
			12 if narrow else 14, UiKit.COLOR_TEXT)
	sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(sub_lbl)
	var run_length := int(AREA_GRAMMAR.for_area(area_id).get("run_length", 7))
	var progress := "CLEARED %d TIMES" % SaveSystem.area_wins(area_id) if cleared else (
			"BEST DEPTH %d / %d" % [SaveSystem.best_depth(area_id), run_length]
			if unlocked else "LOCKED")
	info.add_child(UiKit.label(progress, 12 if narrow else 13,
			UiKit.COLOR_GOLD if unlocked else UiKit.COLOR_TEXT_DIM))
	if unlocked:
		var meta_info := MetaProgression.new()
		var mastery := UiKit.label("MASTERY RANK %d / 10  •  %s" % [
				meta_info.area_mastery_rank(area_id),
				meta_info.next_mastery_unlock(area_id)], 11 if narrow else 12, Color("d8b6ff"))
		mastery.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(mastery)
	if not cleared:
		info.add_child(UiKit.label("FIRST CLEAR  +%d CRYSTALS" % int(area.get("first_clear_reward", 0)),
				12 if narrow else 13, Color("77d8ff")))
	elif unlocked:
		var rematch := UiKit.cta_bar("BOSS REMATCH", Color("d06b63"), 52)
		rematch.add_theme_font_size_override("font_size", 16 if narrow else 18)
		rematch.pressed.connect(func() -> void:
			RunState.pending_area_id = area_id; RunState.pending_run_mode = "rematch"
			get_tree().change_scene_to_file("res://scenes/kit_select.tscn"))
		info.add_child(rematch)
	var action := UiKit.cta_bar("ENTER" if narrow and unlocked else (
			"ENTER EXPEDITION" if unlocked else "LOCKED"),
			_area_color(area_id) if unlocked else Color("5a5470"),
			58 if narrow else 62)
	action.name = "AreaAction"
	action.mouse_filter = Control.MOUSE_FILTER_PASS
	action.disabled = not unlocked
	action.add_theme_font_size_override("font_size", 22 if narrow else 24)
	action.pressed.connect(func() -> void:
		RunState.pending_area_id = area_id
		RunState.pending_run_mode = "normal"
		RunState.pending_ascension = SaveSystem.selected_ascension()
		SaveSystem.set_selected_area(area_id)
		get_tree().change_scene_to_file("res://scenes/kit_select.tscn"))
	stack.add_child(action)
	return card


func _preview_area(area_id: String) -> void:
	var area := GameState.area(area_id)
	_preview_label.text = "%s  •  %s" % [str(area.get("name", area_id)).to_upper(),
			str(area.get("subtitle", "DUNGEON EXPEDITION")).to_upper()]
	var texture := VisualRegistry.texture_or_null(str(area.get("background", "")))
	if texture == null or _preview_background.texture == texture: return
	if _background_tween != null and _background_tween.is_valid(): _background_tween.kill()
	_background_tween = create_tween()
	_background_tween.tween_property(_preview_background, "modulate:a", 0.25, 0.18) \
			.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_background_tween.tween_callback(func() -> void: _preview_background.texture = texture)
	_background_tween.tween_property(_preview_background, "modulate:a", 1.0, 0.42) \
			.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)


func _area_color(area_id: String) -> Color:
	return UiThemeTokens.REALM_ACCENTS.get(area_id, UiKit.COLOR_GOLD)


func _start_daily() -> void:
	var spec := MetaProgression.new().daily_spec(Time.get_date_string_from_system(true))
	RunState.pending_area_id = str(spec.area_id)
	RunState.pending_run_mode = "daily"
	RunState.pending_ascension = 0
	RunState.pending_run_seed = int(spec.seed)
	get_tree().change_scene_to_file("res://scenes/kit_select.tscn")


func _start_weekly() -> void:
	var meta := MetaProgression.new()
	var spec := meta.weekly_spec(meta.current_week_key())
	RunState.pending_area_id = str(spec.area_id)
	RunState.pending_run_mode = "weekly"
	RunState.pending_ascension = 0
	RunState.pending_run_seed = int(spec.seed)
	# The weekly kit is fixed by RunState.start_new_run; skip kit selection so
	# the identity cannot be dodged.
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
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	panel.remove_child(row)
	column.add_child(row)
	_ascension_rules_label = UiKit.label("", 12, Color("d8b6ff"))
	_ascension_rules_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ascension_rules_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_ascension_rules_label)
	panel.add_child(column)
	panel.custom_minimum_size = Vector2(0, 86)
	_refresh_ascension_label()
	return panel


func _change_ascension(delta: int) -> void:
	SaveSystem.set_selected_ascension(SaveSystem.selected_ascension() + delta)
	RunState.pending_ascension = SaveSystem.selected_ascension()
	_refresh_ascension_label()


func _refresh_ascension_label() -> void:
	if _ascension_label:
		var level := SaveSystem.selected_ascension()
		_ascension_label.text = "ASCENSION  %d / %d" % [level, SaveSystem.max_ascension()]
		# Rules stack, so the tooltip lists everything the player will face.
		var rules := AscensionRules.new()
		var lines: Array[String] = []
		for step in range(1, level + 1):
			var line := rules.description(step)
			if not line.is_empty():
				lines.append("%d. %s" % [step, line])
		_ascension_label.tooltip_text = "No modifiers" if lines.is_empty() \
				else "\n".join(lines)
	if _ascension_rules_label:
		var level := SaveSystem.selected_ascension()
		var names := AscensionRules.new().active_names(level)
		_ascension_rules_label.text = "No extra rules — the base expedition." \
				if names.is_empty() else "ACTIVE RULES:  " + "  •  ".join(names)
