class_name BottomNav
extends HBoxContainer

signal destination_selected(id: String)

func _init() -> void:
	name = "BottomNavigation"
	custom_minimum_size.y = 98
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 4)

func add_item(id: String, caption: String, action: Callable, active := false) -> Button:
	var button := Button.new()
	button.name = "Nav_" + id
	button.custom_minimum_size = Vector2(88, 94)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.icon = VisualRegistry.texture_or_null(VisualRegistry.ui_icon(id))
	button.expand_icon = true
	button.text = "\n\n" + caption.to_upper()
	button.add_theme_constant_override("icon_max_width", 64)
	button.add_theme_font_override("font", UiKit.title_font())
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", Color("d8bc72"))
	button.add_theme_color_override("font_disabled_color", Color("ffe28a"))
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.20, 0.09, 0.30, 0.94) if active else Color(0.018, 0.01, 0.035, 0.88)
		style.border_color = Color("e7bc59") if active else Color("76572c")
		style.set_border_width_all(2); style.set_corner_radius_all(10)
		button.add_theme_stylebox_override(state, style)
	button.add_theme_stylebox_override("focus", UiThemeTokens.focus_style(10))
	button.disabled = active
	button.pressed.connect(func():
		destination_selected.emit(id)
		if action.is_valid(): action.call())
	add_child(button)
	return button
