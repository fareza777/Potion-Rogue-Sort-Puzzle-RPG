class_name BottomNav
extends PanelContainer
## Ornate bottom dock: one shared metal plate, medallion icons, no ugly boxes.

signal destination_selected(id: String)

var _row: HBoxContainer


func _init() -> void:
	name = "BottomNavigation"
	custom_minimum_size = Vector2(0, 130)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_dock_style()
	_row = HBoxContainer.new()
	_row.name = "NavRow"
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 2)
	_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_row)


func _apply_dock_style() -> void:
	var texture := VisualRegistry.texture_or_null("res://assets/art/ui/nav_dock.png")
	if texture == null:
		texture = VisualRegistry.texture_or_null("res://assets/art/ui/battle_panel.png")
	if texture != null:
		var style := StyleBoxTexture.new()
		style.texture = texture
		style.texture_margin_left = 72.0
		style.texture_margin_right = 72.0
		style.texture_margin_top = 48.0
		style.texture_margin_bottom = 52.0
		style.content_margin_left = 10.0
		style.content_margin_right = 10.0
		style.content_margin_top = 8.0
		style.content_margin_bottom = 10.0
		style.modulate_color = Color("eee5d4")
		add_theme_stylebox_override("panel", style)
	else:
		var flat := StyleBoxFlat.new()
		flat.bg_color = Color(0.04, 0.02, 0.08, 0.92)
		flat.border_color = Color("c9a45a")
		flat.set_border_width_all(2)
		flat.set_corner_radius_all(14)
		flat.content_margin_left = 8
		flat.content_margin_right = 8
		flat.content_margin_top = 6
		flat.content_margin_bottom = 8
		add_theme_stylebox_override("panel", flat)


func add_item(id: String, caption: String, action: Callable, active := false) -> Button:
	var button := Button.new()
	button.name = "Nav_" + id
	button.custom_minimum_size = Vector2(72, 112)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.flat = true
	button.clip_text = true
	button.icon = VisualRegistry.texture_or_null(VisualRegistry.ui_icon(id))
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	button.text = caption.to_upper()
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_constant_override("icon_max_width",
			icon_width_for(get_viewport_rect().size.x))
	button.add_theme_constant_override("h_separation", 0)
	button.add_theme_font_override("font", UiKit.title_font())
	button.add_theme_font_size_override("font_size", UiKit.scaled_text_size(14))
	button.add_theme_color_override("font_color",
			Color("ffe28a") if active else Color("cbb26f"))
	button.add_theme_color_override("font_hover_color", Color("fff3c0"))
	button.add_theme_color_override("font_pressed_color", Color("e8c069"))
	button.add_theme_color_override("font_disabled_color", Color("ffe28a"))
	button.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.08, 0.9))
	button.add_theme_constant_override("outline_size", 4)
	# Invisible chrome — the dock plate is the only frame. Active tab gets a
	# soft gold wash so it still reads as selected without becoming a box.
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1, 1, 1, 0.06 if state == "hover" else 0.0)
		style.border_color = Color(0, 0, 0, 0)
		style.set_border_width_all(0)
		style.set_corner_radius_all(12)
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		style.content_margin_left = 2
		style.content_margin_right = 2
		button.add_theme_stylebox_override(state, style)
	button.disabled = active
	button.modulate = Color(1.08, 1.05, 0.95) if active else Color.WHITE
	button.pressed.connect(func():
		destination_selected.emit(id)
		if action.is_valid():
			action.call())
	_row.add_child(button)
	return button


func icon_width_for(viewport_width: float) -> int:
	return 70 if viewport_width < 640.0 else 76
