extends Control
## Permanent upgrades shop: spend crystals on account-wide upgrade levels.
## Rows are generated from data/perma_upgrades.json.

var _crystals_label: Label
var _rows_box: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiKit.battle_background(self, VisualRegistry.background("main_hall"))
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.012, 0.008, 0.03, 0.62)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var profile := UiKit.layout_profile(get_viewport_rect().size)
	var margin := UiKit.safe_margin(self,
			int(profile.get("safe_horizontal", 24)),
			int(profile.get("safe_top", 28)),
			int(profile.get("safe_bottom", 24)))

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	var header := UiKit.textured_panel("res://assets/art/ui/battle_panel.png", 16)
	header.name = "WorkshopHeader"
	header.custom_minimum_size = Vector2(0, 112)
	root.add_child(header)
	var header_box := VBoxContainer.new()
	header.add_child(header_box)
	header_box.add_child(UiKit.title_label("ARCANE WORKSHOP", 37))
	header_box.add_child(UiKit.label("PERMANENT UPGRADES", 16, UiKit.COLOR_TEXT_DIM))
	_crystals_label = UiKit.label("", 24, Color("7fd4ff"))
	header_box.add_child(_crystals_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	_rows_box = VBoxContainer.new()
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_box.add_theme_constant_override("separation", 10)
	scroll.add_child(_rows_box)

	var back := UiKit.ornate_button("RETURN TO HALL", Vector2(340, 66))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	root.add_child(back)

	_rebuild()


func _rebuild() -> void:
	_crystals_label.text = "◆  %d CRYSTALS AVAILABLE" % SaveSystem.crystals()
	for child in _rows_box.get_children():
		child.queue_free()
	for id in RunState.perma_pool:
		_rows_box.add_child(_make_row(str(id)))


func _make_row(id: String) -> PanelContainer:
	var up: Dictionary = RunState.perma_pool[id]
	var level := SaveSystem.perma_level(id)
	var max_level := int(up.get("max_level", 1))
	var maxed := level >= max_level

	var panel := UiKit.textured_panel("res://assets/art/ui/battle_panel.png", 18)
	panel.custom_minimum_size = Vector2(0, 138)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	row.add_child(_upgrade_sigil(id))

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)

	var name_label := UiKit.label("%s   (Lv %d/%d)"
			% [str(up.get("name", id)), level, max_level], 21, UiKit.COLOR_GOLD)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	info.add_child(name_label)
	var desc := UiKit.label(str(up.get("description", "")), 16, UiKit.COLOR_TEXT_DIM)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(desc)

	var buy := UiKit.ornate_button("MAX" if maxed else "BUY  %d" % RunState.perma_cost(id),
			Vector2(132, 58), UiKit.COLOR_GOLD)
	buy.add_theme_font_size_override("font_size", 17)
	buy.disabled = maxed or SaveSystem.crystals() < RunState.perma_cost(id)
	buy.pressed.connect(func() -> void:
		if RunState.buy_perma(id):
			AudioManager.play("complete")
			_rebuild())
	row.add_child(buy)
	return panel


func _upgrade_sigil(id: String) -> Control:
	var holder := Control.new()
	holder.name = "UpgradeSigil"
	holder.custom_minimum_size = Vector2(84, 84)
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var accent := _upgrade_accent(id)
	var ring := TextureRect.new()
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ring.texture = VisualRegistry.texture_or_null("res://assets/art/ui/button_round.png")
	ring.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ring.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ring.modulate = accent
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(ring)
	var bottle := TextureRect.new()
	bottle.set_anchors_preset(Control.PRESET_FULL_RECT)
	bottle.offset_left = 21
	bottle.offset_right = -21
	bottle.offset_top = 13
	bottle.offset_bottom = -13
	bottle.texture = VisualRegistry.texture_or_null(
			"res://assets/art/potions/bottle_frame.png")
	bottle.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bottle.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bottle.modulate = accent.lightened(0.2)
	bottle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(bottle)
	return holder


func _upgrade_accent(id: String) -> Color:
	if "fire" in id:
		return Color("ff7446")
	if "shield" in id or "body" in id:
		return Color("55b8ff")
	if "heal" in id:
		return Color("71d65d")
	if "venom" in id:
		return Color("c36eff")
	return Color("f0c568")
