class_name QuietSurface
extends PanelContainer
## A restrained inset surface for supporting information. Major ornamental
## frames stay reserved for the screen title and primary call to action.


func _init() -> void:
	name = "QuietSurface"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(UiThemeTokens.SURFACE, 0.88)
	style.border_color = Color(UiThemeTokens.BORDER, 0.58)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = UiThemeTokens.space("lg")
	style.content_margin_right = UiThemeTokens.space("lg")
	style.content_margin_top = UiThemeTokens.space("md")
	style.content_margin_bottom = UiThemeTokens.space("md")
	style.shadow_color = Color(0, 0, 0, 0.30)
	style.shadow_size = 4
	add_theme_stylebox_override("panel", style)


func set_accent(accent: Color, strength := 0.55) -> QuietSurface:
	var style := get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style.border_color = Color(accent, clampf(strength, 0.0, 1.0))
	add_theme_stylebox_override("panel", style)
	return self
