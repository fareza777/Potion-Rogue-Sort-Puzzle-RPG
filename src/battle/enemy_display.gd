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
		queue_redraw()

var _flash := 0.0
var _bob := 0.0
var _shake := Vector2.ZERO


func configure(new_shape: String, color_hex: String) -> void:
	shape = new_shape
	body_color = Color(color_hex)
	queue_redraw()


func play_hit() -> void:
	_flash = 1.0
	var tween := create_tween()
	tween.tween_method(_set_shake, 12.0, 0.0, 0.35)
	tween.parallel().tween_method(_set_flash, 1.0, 0.0, 0.3)


func _set_shake(strength: float) -> void:
	_shake = Vector2(randf_range(-strength, strength), randf_range(-strength, strength) * 0.4)
	queue_redraw()


func _set_flash(value: float) -> void:
	_flash = value
	queue_redraw()


func _process(delta: float) -> void:
	_bob += delta
	queue_redraw()


func _draw() -> void:
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
