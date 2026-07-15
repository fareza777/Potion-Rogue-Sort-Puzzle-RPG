class_name UiKit
extends RefCounted
## Shared visual language for all screens: colors, fonts and styled
## widget factories. Placeholder-art phase draws everything procedurally,
## but through this single file so a reskin later touches one place.

const COLOR_BG := Color("120d1d")
const COLOR_PANEL := Color("251a3a")
const COLOR_PANEL_BORDER := Color("8a6d3b")
const COLOR_GOLD := Color("e8c069")
const COLOR_GOLD_DIM := Color("b39555")
const COLOR_TEXT := Color("e8e2f5")
const COLOR_TEXT_DIM := Color("9c92b8")
const COLOR_HP := Color("58d873")
const COLOR_ENEMY_HP := Color("e05252")
const COLOR_SHIELD := Color("5aa7f0")
const COLOR_POISON := Color("b56ce8")
const COLOR_FIRE := Color("ff8a4a")

static var _title_font: FontFile


static func title_font() -> Font:
	if _title_font == null:
		_title_font = load("res://assets/fonts/Cinzel.ttf")
	return _title_font if _title_font != null else ThemeDB.fallback_font


static func panel(border_color: Color = COLOR_PANEL_BORDER) -> PanelContainer:
	var p := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.set_corner_radius_all(16)
	style.border_color = border_color
	style.set_border_width_all(2)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 8
	p.add_theme_stylebox_override("panel", style)
	return p


static func _audio() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("AudioManager") if tree != null else null


static func button(text: String, min_size := Vector2(180, 64),
		accent := COLOR_GOLD) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.pressed.connect(func() -> void:
		var audio := _audio()
		if audio != null:
			audio.play("click"))
	b.add_theme_font_override("font", title_font())
	b.add_theme_font_size_override("font_size", 26)
	b.add_theme_color_override("font_color", accent)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", COLOR_GOLD_DIM)
	b.add_theme_color_override("font_disabled_color", Color("5a5470"))

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("2e2148")
	normal.set_corner_radius_all(12)
	normal.border_color = accent.darkened(0.25)
	normal.set_border_width_all(2)
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	b.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate()
	hover.bg_color = Color("3a2a5c")
	hover.border_color = accent
	b.add_theme_stylebox_override("hover", hover)

	var pressed := normal.duplicate()
	pressed.bg_color = Color("1f1633")
	b.add_theme_stylebox_override("pressed", pressed)

	var disabled := normal.duplicate()
	disabled.bg_color = Color("221a33")
	disabled.border_color = Color("4a3f61")
	b.add_theme_stylebox_override("disabled", disabled)
	return b


static func title_label(text: String, size: int, color := COLOR_GOLD) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", title_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	return l


static func label(text: String, size: int, color := COLOR_TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func bar(fill_color: Color, height := 34.0) -> ProgressBar:
	var bar_widget := ProgressBar.new()
	bar_widget.show_percentage = false
	bar_widget.custom_minimum_size = Vector2(0, height)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("161022")
	bg.set_corner_radius_all(9)
	bg.border_color = Color("463a5e")
	bg.set_border_width_all(1)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(9)
	bar_widget.add_theme_stylebox_override("background", bg)
	bar_widget.add_theme_stylebox_override("fill", fill)
	return bar_widget


## Centered value label drawn on top of a bar ("45/60").
static func bar_label(target_bar: ProgressBar) -> Label:
	var l := Label.new()
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_constant_override("outline_size", 5)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	target_bar.add_child(l)
	return l


static func background(parent: Control) -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/dungeon_bg.gdshader")
	bg.material = mat
	parent.add_child(bg)


## Floating combat text that rises and fades, then frees itself.
static func float_text(parent: Control, at: Vector2, text: String,
		color: Color, size := 34) -> void:
	var l := Label.new()
	l.text = text
	l.position = at
	l.z_index = 50
	l.add_theme_font_override("font", title_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	parent.add_child(l)
	var tween := parent.create_tween()
	tween.tween_property(l, "position:y", at.y - 90.0, 0.9) \
			.set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(l, "modulate:a", 0.0, 0.9) \
			.set_ease(Tween.EASE_IN)
	tween.tween_callback(l.queue_free)
