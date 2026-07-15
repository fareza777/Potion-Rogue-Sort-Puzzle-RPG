extends Control
## Permanent upgrades shop: spend crystals on account-wide upgrade levels.
## Rows are generated from data/perma_upgrades.json.

var _crystals_label: Label
var _rows_box: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiKit.background(self)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 48)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	root.add_child(UiKit.title_label("Permanent Upgrades", 40))
	_crystals_label = UiKit.label("", 24, Color("7fd4ff"))
	root.add_child(_crystals_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	_rows_box = VBoxContainer.new()
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_box.add_theme_constant_override("separation", 10)
	scroll.add_child(_rows_box)

	var back := UiKit.button("Back", Vector2(300, 64))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	root.add_child(back)

	_rebuild()


func _rebuild() -> void:
	_crystals_label.text = "Crystals: %d" % SaveSystem.crystals()
	for child in _rows_box.get_children():
		child.queue_free()
	for id in RunState.perma_pool:
		_rows_box.add_child(_make_row(str(id)))


func _make_row(id: String) -> PanelContainer:
	var up: Dictionary = RunState.perma_pool[id]
	var level := SaveSystem.perma_level(id)
	var max_level := int(up.get("max_level", 1))
	var maxed := level >= max_level

	var panel := UiKit.panel()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)

	var name_label := UiKit.label("%s   (Lv %d/%d)"
			% [str(up.get("name", id)), level, max_level], 24, UiKit.COLOR_GOLD)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	info.add_child(name_label)
	var desc := UiKit.label(str(up.get("description", "")), 19, UiKit.COLOR_TEXT_DIM)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(desc)

	var buy := UiKit.button("MAX" if maxed else "Buy  %d" % RunState.perma_cost(id),
			Vector2(170, 60))
	buy.disabled = maxed or SaveSystem.crystals() < RunState.perma_cost(id)
	buy.pressed.connect(func() -> void:
		if RunState.buy_perma(id):
			AudioManager.play("complete")
			_rebuild())
	row.add_child(buy)
	return panel
