class_name EnemyDisplay
extends Control
## Procedural placeholder enemy art: distinct silhouettes per enemy shape,
## idle bobbing, hit-shake, hurt-flash and an enrage tint.
## Swap for real sprite art in the polish phase without touching battle logic.

var shape := "slime"
var body_color := Color("6fce4e")
var enraged := false:
	set(value):
		enraged = value
		if _sprite_material != null:
			_sprite_material.set_shader_parameter("tint_color", Color("ff4b2e"))
			_sprite_material.set_shader_parameter("tint_amount", 0.28 if value else 0.0)
		queue_redraw()

var _flash := 0.0
var _bob := 0.0
var _shake := Vector2.ZERO
var _sprite_root: Control
var _shadow_texture: TextureRect
var _body_texture: TextureRect
var _sprite_material: ShaderMaterial
var _action_tween: Tween
var _motion_profile := "elastic"
var _base_scale := Vector2.ONE


func _ready() -> void:
	_ensure_sprite_nodes()
	resized.connect(_sync_pivots)
	_sync_pivots()


func configure(new_shape: String, color_hex: String) -> void:
	configure_enemy(new_shape, new_shape, color_hex)


func configure_enemy(enemy_id: String, fallback_shape: String, color_hex: String) -> void:
	shape = fallback_shape
	body_color = Color(color_hex)
	_ensure_sprite_nodes()
	var config := VisualRegistry.enemy(enemy_id)
	_body_texture.texture = VisualRegistry.enemy_texture(enemy_id)
	_shadow_texture.texture = VisualRegistry.texture_or_null(str(config.get("shadow", "")))
	_sprite_root.visible = _body_texture.texture != null
	_shadow_texture.visible = _shadow_texture.texture != null
	_motion_profile = str(config.get("motion_profile", "elastic"))
	_base_scale = Vector2.ONE * float(config.get("scale", 1.0))
	_sprite_root.scale = _base_scale
	_sprite_root.modulate = Color.WHITE
	queue_redraw()


func uses_sprite_art() -> bool:
	return _body_texture != null and _body_texture.texture != null \
			and _sprite_root != null and _sprite_root.visible


func motion_profile() -> String:
	return _motion_profile


func _ensure_sprite_nodes() -> void:
	if _sprite_root != null:
		return
	_sprite_root = Control.new()
	_sprite_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sprite_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sprite_root)

	_shadow_texture = TextureRect.new()
	_shadow_texture.anchor_left = 0.08
	_shadow_texture.anchor_top = 0.63
	_shadow_texture.anchor_right = 0.92
	_shadow_texture.anchor_bottom = 1.0
	_shadow_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_shadow_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_shadow_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sprite_root.add_child(_shadow_texture)

	_body_texture = TextureRect.new()
	_body_texture.anchor_left = 0.07
	_body_texture.anchor_top = -0.15
	_body_texture.anchor_right = 0.93
	_body_texture.anchor_bottom = 1.15
	_body_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_body_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_body_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body_texture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_sprite_material = ShaderMaterial.new()
	_sprite_material.shader = load("res://assets/shaders/enemy_hit.gdshader")
	_body_texture.material = _sprite_material
	_sprite_root.add_child(_body_texture)


func _sync_pivots() -> void:
	if _sprite_root == null:
		return
	_sprite_root.pivot_offset = size * 0.5
	_body_texture.pivot_offset = size * 0.5


func _kill_action_tween() -> void:
	if _action_tween != null and _action_tween.is_valid():
		_action_tween.kill()
	_action_tween = null
	if _sprite_root != null:
		_sprite_root.position = Vector2.ZERO
		_sprite_root.rotation = 0.0


func play_intro() -> void:
	if not uses_sprite_art():
		return
	_kill_action_tween()
	_sprite_root.modulate.a = 0.0
	var intro_scale := Vector2(0.72, 0.62)
	var intro_drop := 42.0
	if _motion_profile in ["heavy", "inferno"]:
		intro_scale = Vector2(0.9, 0.78)
		intro_drop = 28.0
	elif _motion_profile == "caster":
		intro_scale = Vector2(0.82, 0.82)
		intro_drop = 58.0
	elif _motion_profile == "brittle":
		_sprite_root.rotation = -0.08
	_sprite_root.scale = intro_scale * _base_scale
	_sprite_root.position.y = intro_drop
	_action_tween = create_tween().set_parallel(true)
	_action_tween.tween_property(_sprite_root, "modulate:a", 1.0, 0.34)
	_action_tween.tween_property(_sprite_root, "position:y", 0.0, 0.42) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_sprite_root, "scale", _base_scale, 0.42) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_sprite_root, "rotation", 0.0, 0.34)


func play_anticipate() -> void:
	if not uses_sprite_art():
		return
	_kill_action_tween()
	_action_tween = create_tween()
	var windup := Vector2(0.92, 1.08)
	if _motion_profile == "pounce":
		windup = Vector2(1.1, 0.82)
	elif _motion_profile in ["heavy", "inferno"]:
		windup = Vector2(1.06, 0.94)
	elif _motion_profile == "caster":
		windup = Vector2(1.04, 1.04)
	elif _motion_profile == "brittle":
		windup = Vector2(0.96, 1.04)
	_action_tween.tween_property(_sprite_root, "scale", windup * _base_scale, 0.13) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_sprite_root, "scale", _base_scale, 0.2) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func play_attack() -> void:
	if not uses_sprite_art():
		return
	_kill_action_tween()
	_action_tween = create_tween().set_parallel(true)
	var lift := -20.0
	var strike_scale := Vector2(1.11, 0.9)
	var windup_time := 0.14
	if _motion_profile == "pounce":
		lift = 28.0
		strike_scale = Vector2(1.2, 0.8)
		windup_time = 0.1
	elif _motion_profile in ["heavy", "inferno"]:
		lift = -8.0
		strike_scale = Vector2(1.08, 0.94)
		windup_time = 0.2
	elif _motion_profile == "caster":
		lift = -34.0
		strike_scale = Vector2(1.08, 1.08)
	elif _motion_profile == "brittle":
		lift = -14.0
		strike_scale = Vector2(1.04, 0.96)
		_sprite_root.rotation = -0.05
	_action_tween.tween_property(_sprite_root, "position:y", lift, windup_time) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(_sprite_root, "scale", strike_scale * _base_scale, windup_time)
	_action_tween.chain().tween_property(_sprite_root, "position:y", 0.0, 0.22) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.parallel().tween_property(_sprite_root, "scale", _base_scale, 0.22)
	_action_tween.parallel().tween_property(_sprite_root, "rotation", 0.0, 0.18)


func play_defeat() -> void:
	if not uses_sprite_art():
		return
	_kill_action_tween()
	_action_tween = create_tween().set_parallel(true)
	var defeated_scale := Vector2(1.24, 0.12)
	if _motion_profile == "brittle":
		defeated_scale = Vector2(1.08, 0.06)
	elif _motion_profile == "caster":
		defeated_scale = Vector2(0.72, 1.18)
	elif _motion_profile in ["heavy", "inferno"]:
		defeated_scale = Vector2(1.18, 0.2)
	_action_tween.tween_property(_sprite_root, "scale", defeated_scale * _base_scale, 0.55) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_action_tween.tween_property(_sprite_root, "position:y", size.y * 0.34, 0.55)
	_action_tween.tween_property(_sprite_root, "modulate:a", 0.0, 0.55).set_delay(0.18)


func play_hit() -> void:
	_flash = 1.0
	if _sprite_material != null:
		_sprite_material.set_shader_parameter("flash_amount", 1.0)
	var tween := create_tween()
	tween.tween_method(_set_shake, 12.0, 0.0, 0.35)
	tween.parallel().tween_method(_set_flash, 1.0, 0.0, 0.3)


func _set_shake(strength: float) -> void:
	_shake = Vector2(randf_range(-strength, strength), randf_range(-strength, strength) * 0.4)
	if _sprite_root != null:
		_sprite_root.position = _shake
	queue_redraw()


func _set_flash(value: float) -> void:
	_flash = value
	if _sprite_material != null:
		_sprite_material.set_shader_parameter("flash_amount", value)
	queue_redraw()


func _process(delta: float) -> void:
	_bob += delta
	if uses_sprite_art() and (_action_tween == null or not _action_tween.is_running()):
		_sprite_root.position.y = sin(_bob * 2.2) * 4.0
		var breath := sin(_bob * 2.0) * 0.012
		_body_texture.scale = Vector2(1.0 + breath, 1.0 - breath)
	queue_redraw()


func _draw() -> void:
	if uses_sprite_art():
		return
	var center := size / 2.0 + _shake
	center.y += sin(_bob * 2.2) * 4.0
	var r: float = minf(size.x, size.y) * 0.36
	var col := body_color.lerp(Color.WHITE, _flash)
	if enraged:
		col = col.lerp(Color("ff3a2a"), 0.35)
		draw_circle(center, r * 1.6, Color(1.0, 0.2, 0.1, 0.10))

	# Soft ground shadow
	draw_circle(Vector2(center.x, size.y - 8.0), r * 0.9, Color(0, 0, 0, 0.35))

	match shape:
		"skeleton":
			_draw_skeleton(center, r, col)
		"golem":
			_draw_golem(center, r, col, false)
		"fire_golem":
			_draw_golem(center, r, col, true)
		"mage":
			_draw_mage(center, r, col)
		"beast":
			_draw_beast(center, r, col)
		_:
			_draw_slime(center, r, col)


func _draw_slime(c: Vector2, r: float, col: Color) -> void:
	draw_circle(c + Vector2(0, r * 0.25), r, col)
	draw_rect(Rect2(c.x - r, c.y + r * 0.25, r * 2.0, r * 0.85), col)
	draw_circle(c + Vector2(-r * 0.35, -r * 0.1), r * 0.16, Color(1, 1, 1, 0.35))
	var eye_y := c.y + r * 0.1
	draw_circle(Vector2(c.x - r * 0.34, eye_y), r * 0.11, Color("14101f"))
	draw_circle(Vector2(c.x + r * 0.34, eye_y), r * 0.11, Color("14101f"))
	draw_arc(c + Vector2(0, r * 0.45), r * 0.25, 0.3, PI - 0.3, 10, Color("14101f"), 3.0)


func _draw_skeleton(c: Vector2, r: float, col: Color) -> void:
	# Skull
	draw_circle(c + Vector2(0, -r * 0.25), r * 0.62, col)
	draw_rect(Rect2(c.x - r * 0.34, c.y + r * 0.1, r * 0.68, r * 0.35), col)
	# Eye sockets + nose
	draw_circle(c + Vector2(-r * 0.24, -r * 0.3), r * 0.15, Color("14101f"))
	draw_circle(c + Vector2(r * 0.24, -r * 0.3), r * 0.15, Color("14101f"))
	draw_circle(c + Vector2(-r * 0.24, -r * 0.3), r * 0.05, Color("ff4d3d"))
	draw_circle(c + Vector2(r * 0.24, -r * 0.3), r * 0.05, Color("ff4d3d"))
	# Jaw lines
	for i in 3:
		var x := c.x - r * 0.2 + i * r * 0.2
		draw_line(Vector2(x, c.y + r * 0.12), Vector2(x, c.y + r * 0.4), Color("14101f"), 3.0)
	# Ribs
	for i in 3:
		var y := c.y + r * (0.6 + i * 0.18)
		draw_line(Vector2(c.x - r * 0.4, y), Vector2(c.x + r * 0.4, y), col, 5.0)


func _draw_golem(c: Vector2, r: float, col: Color, fiery: bool) -> void:
	# Stacked rock body
	draw_rect(Rect2(c.x - r * 0.9, c.y - r * 0.1, r * 1.8, r * 1.1), col.darkened(0.15))
	draw_rect(Rect2(c.x - r * 0.65, c.y - r * 0.8, r * 1.3, r * 0.75), col)
	# Arms
	draw_rect(Rect2(c.x - r * 1.25, c.y - r * 0.05, r * 0.35, r * 0.9), col.darkened(0.25))
	draw_rect(Rect2(c.x + r * 0.9, c.y - r * 0.05, r * 0.35, r * 0.9), col.darkened(0.25))
	# Eyes
	var eye := Color("ffb347") if fiery else Color("7fd4ff")
	draw_circle(c + Vector2(-r * 0.25, -r * 0.45), r * 0.1, eye)
	draw_circle(c + Vector2(r * 0.25, -r * 0.45), r * 0.1, eye)
	if fiery:
		# Glowing magma cracks
		var crack := Color("ff6a2a")
		draw_line(c + Vector2(-r * 0.5, r * 0.2), c + Vector2(-r * 0.15, r * 0.65), crack, 3.5)
		draw_line(c + Vector2(r * 0.35, r * 0.05), c + Vector2(r * 0.6, r * 0.55), crack, 3.5)
		draw_line(c + Vector2(-r * 0.1, -r * 0.6), c + Vector2(0.0, -r * 0.2), crack, 3.5)


func _draw_mage(c: Vector2, r: float, col: Color) -> void:
	# Hooded cloak (triangle)
	var points := PackedVector2Array([
		c + Vector2(0, -r * 1.05),
		c + Vector2(-r * 0.95, r * 1.1),
		c + Vector2(r * 0.95, r * 1.1),
	])
	draw_colored_polygon(points, col)
	# Shadowed face + glowing eyes
	draw_circle(c + Vector2(0, -r * 0.25), r * 0.4, Color("0d0a16"))
	draw_circle(c + Vector2(-r * 0.15, -r * 0.28), r * 0.07, Color("c07ce8"))
	draw_circle(c + Vector2(r * 0.15, -r * 0.28), r * 0.07, Color("c07ce8"))
	# Floating orb
	var orb_y := sin(_bob * 3.0) * 6.0
	draw_circle(c + Vector2(r * 0.95, -r * 0.4 + orb_y), r * 0.16, Color("c07ce8"))
	draw_circle(c + Vector2(r * 0.95, -r * 0.4 + orb_y), r * 0.26, Color(0.75, 0.49, 0.91, 0.25))


func _draw_beast(c: Vector2, r: float, col: Color) -> void:
	# Ears
	var left_ear := PackedVector2Array([
		c + Vector2(-r * 0.75, -r * 0.4),
		c + Vector2(-r * 0.55, -r * 1.05),
		c + Vector2(-r * 0.2, -r * 0.55),
	])
	var right_ear := PackedVector2Array([
		c + Vector2(r * 0.75, -r * 0.4),
		c + Vector2(r * 0.55, -r * 1.05),
		c + Vector2(r * 0.2, -r * 0.55),
	])
	draw_colored_polygon(left_ear, col.darkened(0.15))
	draw_colored_polygon(right_ear, col.darkened(0.15))
	# Head
	draw_circle(c, r * 0.85, col)
	# Eyes + fangs
	draw_circle(c + Vector2(-r * 0.3, -r * 0.15), r * 0.12, Color("ffd77a"))
	draw_circle(c + Vector2(r * 0.3, -r * 0.15), r * 0.12, Color("ffd77a"))
	draw_circle(c + Vector2(-r * 0.3, -r * 0.15), r * 0.05, Color("14101f"))
	draw_circle(c + Vector2(r * 0.3, -r * 0.15), r * 0.05, Color("14101f"))
	var fang_l := PackedVector2Array([
		c + Vector2(-r * 0.3, r * 0.35), c + Vector2(-r * 0.18, r * 0.7),
		c + Vector2(-r * 0.08, r * 0.35),
	])
	var fang_r := PackedVector2Array([
		c + Vector2(r * 0.3, r * 0.35), c + Vector2(r * 0.18, r * 0.7),
		c + Vector2(r * 0.08, r * 0.35),
	])
	draw_colored_polygon(fang_l, Color("f0ead8"))
	draw_colored_polygon(fang_r, Color("f0ead8"))
