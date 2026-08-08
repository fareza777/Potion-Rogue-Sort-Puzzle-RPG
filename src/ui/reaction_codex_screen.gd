extends Control

var _formula_scroll: ScrollContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiKit.battle_background(self, VisualRegistry.background("main_hall"))
	var margin := UiKit.safe_margin(self, 22, 34, 22)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)
	root.add_child(UiKit.title_label("FORMULA CODEX", 38, Color("f5d681")))
	root.add_child(UiKit.body_label(
			"Discover reactions naturally. The chamber records what you have mastered.",
			UiKit.COLOR_TEXT_DIM))
	root.add_child(UiKit.caption_label("%d / %d FORMULAS DISCOVERED" % [
			SaveSystem.discovered_formulas().size(), GameState.combos.size()], Color("8ee6ff")))
	_formula_scroll = ScrollContainer.new()
	_formula_scroll.name = "FormulaScrollContainer"
	_formula_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_formula_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_formula_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_formula_scroll.scroll_deadzone = 6
	root.add_child(_formula_scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	_formula_scroll.add_child(list)
	var known := SaveSystem.discovered_formulas()
	for formula_id in GameState.combos:
		var formula: Dictionary = GameState.combos[formula_id]
		list.add_child(_formula_card(str(formula_id), formula, formula_id in known))
	var back := UiKit.ornate_button("RETURN", Vector2(330, 62))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_return_from_codex)
	root.add_child(back)


func _input(event: InputEvent) -> void:
	if not is_instance_valid(_formula_scroll): return
	var distance := 0.0
	var pointer := Vector2.ZERO
	if event is InputEventScreenDrag:
		distance = -event.relative.y; pointer = event.position
	elif event is InputEventPanGesture:
		distance = event.delta.y * 64.0; pointer = event.position
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		distance = -event.relative.y; pointer = event.position
	else:
		return
	if not _formula_scroll.get_global_rect().has_point(pointer): return
	var bar := _formula_scroll.get_v_scroll_bar()
	var limit := maxi(roundi(bar.max_value - bar.page), 0)
	_formula_scroll.scroll_vertical = clampi(
			_formula_scroll.scroll_vertical + roundi(distance), 0, limit)
	get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	_input(event)


func _formula_card(formula_id: String, formula: Dictionary, discovered: bool) -> Control:
	return FormulaCard.new().configure(formula_id, formula, discovered)


func _return_from_codex() -> void:
	get_tree().change_scene_to_file(RunState.resume_scene() if RunState.active \
			else "res://scenes/main_menu.tscn")
