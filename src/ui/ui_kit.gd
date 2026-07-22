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


static func layout_profile(viewport_size: Vector2) -> Dictionary:
	var aspect := viewport_size.y / maxf(viewport_size.x, 1.0)
	if aspect >= 2.05:
		return {
			"name": "tall",
			"safe_horizontal": 22.0,
			"safe_top": 34.0,
			"safe_bottom": 30.0,
			"hero_ratio": 0.39,
			"arena_ratio": 0.34,
			"status_ratio": 0.16,
			"board_ratio": 0.36,
			"controls_ratio": 0.14,
		}
	return {
		"name": "standard",
		"safe_horizontal": 24.0,
		"safe_top": 28.0,
		"safe_bottom": 24.0,
		"hero_ratio": 0.34,
		"arena_ratio": 0.36,
		"status_ratio": 0.17,
		"board_ratio": 0.33,
		"controls_ratio": 0.14,
	}


static func safe_margin(parent: Control, horizontal := 24,
		top := 28, bottom := 24) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", horizontal)
	margin.add_theme_constant_override("margin_right", horizontal)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_bottom", bottom)
	parent.add_child(margin)
	return margin


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


static func textured_panel(texture_path: String, margins := 26) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(0, 80)
	var texture := VisualRegistry.texture_or_null(texture_path)
	if texture == null:
		return panel()
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = 64.0
	style.texture_margin_right = 64.0
	style.texture_margin_top = 58.0
	style.texture_margin_bottom = 58.0
	style.content_margin_left = float(margins)
	style.content_margin_right = float(margins)
	style.content_margin_top = float(margins)
	style.content_margin_bottom = float(margins)
	p.add_theme_stylebox_override("panel", style)
	return p


static func icon_button(icon_path: String, count: int, tooltip: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(96, 96)
	b.tooltip_text = tooltip
	b.text = str(count) if count >= 0 else ""
	b.icon = VisualRegistry.texture_or_null(icon_path)
	b.expand_icon = true
	b.add_theme_font_override("font", title_font())
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", COLOR_GOLD)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color("675c6f"))
	b.add_theme_color_override("icon_hover_color", Color(1.15, 1.08, 0.88))
	b.add_theme_color_override("icon_pressed_color", Color(0.86, 0.74, 0.52))
	b.add_theme_constant_override("icon_max_width", 82 if "/controls/" in icon_path else 54)
	if "/controls/" in icon_path:
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			var empty := StyleBoxFlat.new()
			empty.bg_color = Color.TRANSPARENT
			b.add_theme_stylebox_override(state, empty)
		return b
	var ring := VisualRegistry.texture_or_null("res://assets/art/ui/button_round.png")
	if ring != null:
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			var style := StyleBoxTexture.new()
			style.texture = ring
			style.modulate_color = Color(1.15, 1.08, 0.92) if state == "hover" \
					else Color(0.72, 0.72, 0.72) if state == "disabled" else Color.WHITE
			style.content_margin_left = 18
			style.content_margin_right = 18
			style.content_margin_top = 18
			style.content_margin_bottom = 18
			b.add_theme_stylebox_override(state, style)
	return b


static func ornate_button(text: String, min_size := Vector2(340, 72),
		accent := COLOR_GOLD) -> Button:
	var b := button(text, min_size, accent)
	var texture := VisualRegistry.texture_or_null("res://assets/art/ui/battle_panel.png")
	if texture == null:
		return b
	# Expand-fill CTAs pass width 0; treat them as wide enough for the ornate
	# frame so they do not fall back to the flat purple box style.
	var frame_width := min_size.x if min_size.x > 0.0 else 340.0
	if frame_width < 200.0:
		return _accent_chip(b, accent)
	# Dark outline keeps gold text legible over the busy frame texture.
	b.add_theme_color_override("font_color", Color("fff6d8"))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color("f1d69a"))
	b.add_theme_color_override("font_disabled_color", Color("8a8198"))
	b.add_theme_color_override("font_outline_color", Color(0.07, 0.03, 0.11, 0.92))
	b.add_theme_constant_override("outline_size", 7)
	var warm := Color(accent.r * 0.35 + 0.65, accent.g * 0.28 + 0.55,
			accent.b * 0.18 + 0.40)
	var state_tints := {
		"normal": warm,
		"hover": warm.lightened(0.12),
		"pressed": warm.darkened(0.12),
		"focus": warm.lightened(0.12),
		"disabled": Color("6a6570"),
	}
	for state in state_tints:
		var style := StyleBoxTexture.new()
		style.texture = texture
		style.modulate_color = state_tints[state]
		style.texture_margin_left = 76.0
		style.texture_margin_right = 76.0
		style.texture_margin_top = 58.0
		style.texture_margin_bottom = 58.0
		style.content_margin_left = 22.0
		style.content_margin_right = 22.0
		style.content_margin_top = 10.0
		style.content_margin_bottom = 10.0
		b.add_theme_stylebox_override(state, style)
	return b


## Compact mode chips (Daily / Weekly / History) — gold rim, no flat purple slab.
static func _accent_chip(b: Button, accent: Color) -> Button:
	b.add_theme_color_override("font_color", Color("fff4dc"))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_outline_color", accent.darkened(0.55))
	b.add_theme_constant_override("outline_size", 5)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = accent.darkened(0.55 if state == "normal" else 0.42)
		if state == "disabled":
			style.bg_color = Color(0.12, 0.09, 0.16, 0.9)
		style.border_color = Color("e8c069") if state != "pressed" else Color("9f7a31")
		style.set_border_width_all(2)
		style.set_corner_radius_all(14)
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		style.shadow_color = Color(accent, 0.35)
		style.shadow_size = 6 if state == "hover" else 3
		b.add_theme_stylebox_override(state, style)
	return b


## Full-width call-to-action for use INSIDE an ornate panel. Avoids stacking
## a second battle_panel frame on top of the card frame.
static func cta_bar(text: String, accent := COLOR_GOLD, height := 58.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, maxf(height, UiThemeTokens.TOUCH_MIN))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_text = true
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func() -> void:
		var audio := _audio()
		if audio != null:
			audio.play("click"))
	b.add_theme_font_override("font", title_font())
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", Color("fff7df"))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color("f1d69a"))
	b.add_theme_color_override("font_disabled_color", Color("675c6f"))
	b.add_theme_color_override("font_outline_color", accent.darkened(0.65))
	b.add_theme_constant_override("outline_size", 6)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		match state:
			"hover":
				style.bg_color = accent.darkened(0.28)
			"pressed":
				style.bg_color = accent.darkened(0.48)
			"disabled":
				style.bg_color = Color(0.10, 0.07, 0.14, 0.92)
			_:
				style.bg_color = accent.darkened(0.38)
		style.border_color = Color("f2cc68") if state != "disabled" \
				else Color("5a4f3a")
		style.set_border_width_all(2)
		style.set_corner_radius_all(11)
		style.content_margin_left = 18
		style.content_margin_right = 18
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		style.shadow_color = Color(accent, 0.40)
		style.shadow_size = 8 if state == "hover" else 4
		b.add_theme_stylebox_override(state, style)
	# Thin gold filigree line via banner overlay when available.
	var ornament := TextureRect.new()
	ornament.name = "CtaOrnament"
	ornament.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ornament.texture = VisualRegistry.texture_or_null(
			"res://assets/art/ui/banner_turn.png")
	ornament.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ornament.stretch_mode = TextureRect.STRETCH_SCALE
	ornament.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ornament.modulate = Color(1.0, 0.92, 0.70, 0.55)
	b.add_child(ornament)
	return b


static func enemy_portrait(enemy_id: String,
		min_size := Vector2(300, 300)) -> TextureRect:
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = min_size
	portrait.texture = VisualRegistry.enemy_texture(enemy_id)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return portrait


static func map_node_button(text: String, kind: String,
		is_current := false, is_cleared := false) -> Button:
	var accent := COLOR_GOLD
	if kind == "boss":
		accent = Color("ff7048")
	elif kind == "elite":
		accent = Color("c778ff")
	elif is_cleared:
		accent = Color("708a68")
	var node := ornate_button(text, Vector2(430, 68), accent)
	node.disabled = not is_current
	node.add_theme_color_override("font_disabled_color", accent.darkened(0.3))
	if is_current:
		node.text = "◆  " + text + "  ◆"
	elif is_cleared:
		node.text = "✓  " + text
	return node


static func battle_background(parent: Control, texture_path: String) -> TextureRect:
	var bg := TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.texture = VisualRegistry.texture_or_null(texture_path)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)
	return bg


static func _audio() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("AudioManager") if tree != null else null


static func button(text: String, min_size := Vector2(180, 64),
		accent := COLOR_GOLD) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_size.x, maxf(min_size.y, UiThemeTokens.TOUCH_MIN))
	b.focus_mode = Control.FOCUS_ALL
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
	b.add_theme_stylebox_override("focus", UiThemeTokens.focus_style(12))
	return b


static func scaled_text_size(size: int) -> int:
	var scale := 1.0
	var tree := Engine.get_main_loop() as SceneTree
	var save := tree.root.get_node_or_null("SaveSystem") if tree != null else null
	if save != null: scale = clampf(float(save.setting("text_scale")), 0.85, 1.30)
	return maxi(roundi(float(size) * scale), 10)


static func accessible_color(color: Color) -> Color:
	var tree := Engine.get_main_loop() as SceneTree
	var save := tree.root.get_node_or_null("SaveSystem") if tree != null else null
	if save != null and bool(save.setting("high_contrast")):
		return color.lightened(0.22)
	return color


static func title_label(text: String, size: int, color := COLOR_GOLD) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", title_font())
	l.add_theme_font_size_override("font_size", scaled_text_size(size))
	l.add_theme_color_override("font_color", accessible_color(color))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	return l


static func label(text: String, size: int, color := COLOR_TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Body copy receives one restrained readability step without inflating
	# display titles or changing the player's saved text-scale preference.
	l.add_theme_font_size_override("font_size", scaled_text_size(size + 1))
	l.add_theme_color_override("font_color", accessible_color(color))
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
