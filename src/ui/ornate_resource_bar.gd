class_name OrnateResourceBar
extends Control
## Layered dungeon-style vital bar with an integrated marker, numeric value,
## and optional status badge. Presentation only; callers own the state.

var _kind := "enemy"
var _title_text := "VITALITY"
var _progress: TextureProgressBar
var _title: Label
var _value: Label
var _marker: Label
var _badge: Label
var _built := false
var _value_tween: Tween


func _ready() -> void:
	_ensure_built()
	queue_redraw()


func configure(kind: String, title: String) -> void:
	_kind = kind
	_title_text = title
	_ensure_built()
	_apply_palette()


func set_values(value: float, maximum: float, animate := true) -> void:
	_ensure_built()
	_progress.max_value = maxf(maximum, 1.0)
	_value.text = "%d / %d" % [roundi(value), roundi(maximum)]
	if not animate or not is_inside_tree():
		_progress.value = value
		return
	if _value_tween != null and _value_tween.is_valid():
		_value_tween.kill()
	_value_tween = create_tween()
	_value_tween.tween_property(_progress, "value", value, 0.24) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func set_badge(text: String) -> void:
	_ensure_built()
	_badge.text = text
	_badge.visible = not text.is_empty()


func center_global() -> Vector2:
	return global_position + size * 0.5


func _ensure_built() -> void:
	if _built:
		return
	_built = true
	custom_minimum_size = Vector2(0, 58)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var frame := Panel.new()
	frame.name = "ObsidianFrame"
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.025, 0.018, 0.045, 0.96)
	frame_style.border_color = Color("98733a")
	frame_style.set_border_width_all(2)
	frame_style.set_corner_radius_all(13)
	frame_style.shadow_color = Color(0, 0, 0, 0.7)
	frame_style.shadow_size = 7
	frame.add_theme_stylebox_override("panel", frame_style)

	_title = Label.new()
	_title.anchor_left = 0.095
	_title.anchor_top = 0.03
	_title.anchor_right = 0.68
	_title.anchor_bottom = 0.36
	_title.add_theme_font_override("font", UiKit.title_font())
	_title.add_theme_font_size_override("font_size", 14)
	_title.add_theme_color_override("font_color", Color("d8c28e"))
	_title.add_theme_constant_override("outline_size", 3)
	_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	add_child(_title)

	_progress = TextureProgressBar.new()
	_progress.anchor_left = 0.095
	_progress.anchor_top = 0.40
	_progress.anchor_right = 0.78
	_progress.anchor_bottom = 0.82
	_progress.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
	_progress.nine_patch_stretch = true
	_progress.stretch_margin_left = 10
	_progress.stretch_margin_right = 10
	_progress.stretch_margin_top = 8
	_progress.stretch_margin_bottom = 8
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_progress)

	_value = Label.new()
	_value.anchor_left = 0.095
	_value.anchor_top = 0.34
	_value.anchor_right = 0.78
	_value.anchor_bottom = 0.88
	_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_value.add_theme_font_override("font", UiKit.title_font())
	_value.add_theme_font_size_override("font_size", 18)
	_value.add_theme_color_override("font_color", Color("fff0c2"))
	_value.add_theme_constant_override("outline_size", 5)
	_value.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	add_child(_value)

	_marker = Label.new()
	_marker.anchor_left = 0.005
	_marker.anchor_top = 0.08
	_marker.anchor_right = 0.09
	_marker.anchor_bottom = 0.92
	_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_marker.add_theme_font_size_override("font_size", 28)
	_marker.add_theme_color_override("font_color", Color("f2c45c"))
	_marker.add_theme_constant_override("outline_size", 4)
	_marker.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	add_child(_marker)

	_badge = Label.new()
	_badge.anchor_left = 0.79
	_badge.anchor_top = 0.18
	_badge.anchor_right = 0.985
	_badge.anchor_bottom = 0.82
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_badge.add_theme_font_override("font", UiKit.title_font())
	_badge.add_theme_font_size_override("font_size", 13)
	_badge.add_theme_color_override("font_color", Color("7dd5ff"))
	_badge.add_theme_constant_override("outline_size", 4)
	_badge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(0.03, 0.11, 0.18, 0.92)
	badge_style.border_color = Color("397ea8")
	badge_style.set_border_width_all(1)
	badge_style.set_corner_radius_all(8)
	_badge.add_theme_stylebox_override("normal", badge_style)
	_badge.visible = false
	add_child(_badge)
	_apply_palette()


func _apply_palette() -> void:
	if not _built:
		return
	_title.text = _title_text.to_upper()
	_marker.text = "☠" if _kind == "enemy" else "♥"
	var fill_color := Color("d83f46") if _kind == "enemy" else Color("39c96b")
	_progress.texture_under = _make_bar_texture(Color("100c16"), false)
	_progress.texture_progress = _make_bar_texture(fill_color, true)
	queue_redraw()


func _make_bar_texture(base: Color, jewel_fill: bool) -> ImageTexture:
	return ResourceTextureCache.bar_texture(_kind, base, jewel_fill) as ImageTexture


func _draw() -> void:
	var accent := Color("ff5a50") if _kind == "enemy" else Color("5be38b")
	draw_line(Vector2(size.x * 0.10, size.y * 0.86),
			Vector2(size.x * 0.77, size.y * 0.86), Color(accent, 0.45), 1.0)
	for x in [size.x * 0.014, size.x * 0.976]:
		draw_set_transform(Vector2(x, size.y * 0.5), PI / 4.0)
		draw_rect(Rect2(-5, -5, 10, 10), Color("c99b48"), true)
		draw_set_transform(Vector2.ZERO, 0.0)
