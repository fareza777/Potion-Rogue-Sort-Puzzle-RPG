class_name ActionIconButton
extends Button

signal activated

func _init() -> void:
	custom_minimum_size = Vector2(88, 88)
	expand_icon = true
	add_theme_constant_override("icon_max_width", 78)
	add_theme_stylebox_override("focus", UiThemeTokens.focus_style(44))
	pressed.connect(func(): activated.emit())

func configure(icon_id: String, caption: String, hint := "") -> ActionIconButton:
	name = "Action_" + icon_id
	icon = VisualRegistry.texture_or_null(VisualRegistry.ui_icon(icon_id))
	tooltip_text = hint if not hint.is_empty() else caption
	text = ""
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color.TRANSPARENT
		style.set_corner_radius_all(44)
		if state == "hover": style.bg_color = Color(0.35, 0.18, 0.48, 0.28)
		if state == "pressed": style.bg_color = Color(0.08, 0.03, 0.14, 0.72)
		add_theme_stylebox_override(state, style)
	return self
