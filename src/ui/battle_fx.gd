class_name BattleFx
extends Control
## Lightweight presentation-only effects. This node never reads or mutates
## BattleManager state; callers pass screen positions and colors explicitly.

var reduced_effects := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 40


func set_reduced_effects(value: bool) -> void:
	reduced_effects = value


func hit(target: Control, strength: float = 1.0) -> void:
	if target == null or not is_instance_valid(target):
		return
	var amplitude := minf(8.0, 8.0 * strength)
	if reduced_effects:
		amplitude = minf(amplitude, 3.0)
	var base := target.position
	var tween := create_tween()
	for offset in [
		Vector2(-amplitude, 0), Vector2(amplitude * 0.7, -amplitude * 0.2),
		Vector2(-amplitude * 0.45, amplitude * 0.15), Vector2.ZERO,
	]:
		tween.tween_property(target, "position", base + offset, 0.035)


func pour(from: Vector2, to: Vector2, color: Color, count: int) -> void:
	var arc := Line2D.new()
	arc.width = 6.0 if reduced_effects else 10.0
	arc.default_color = color
	arc.begin_cap_mode = Line2D.LINE_CAP_ROUND
	arc.end_cap_mode = Line2D.LINE_CAP_ROUND
	arc.antialiased = true
	var control := (from + to) * 0.5 + Vector2(0, -54.0)
	for i in 17:
		var t := float(i) / 16.0
		arc.add_point(_quadratic(from, control, to, t))
	add_child(arc)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(arc, "modulate:a", 0.0, 0.24)
	tween.tween_property(arc, "width", 1.0, 0.24)
	tween.chain().tween_callback(arc.queue_free)
	_burst(to, color, mini(4 + count * 3, 7 if reduced_effects else 16), 34.0)


func heal(at: Vector2) -> void:
	_burst(at, Color("8eea5c"), 6 if reduced_effects else 16, 48.0, true)


func shield(at: Vector2) -> void:
	_ring(at, Color("67c7ff"), 42.0 if reduced_effects else 66.0)
	_burst(at, Color("7bd5ff"), 5 if reduced_effects else 12, 40.0)


func poison(at: Vector2) -> void:
	_burst(at, Color("b65ce8"), 6 if reduced_effects else 15, 44.0, true)


func fire(at: Vector2) -> void:
	_burst(at, Color("ff8a42"), 7 if reduced_effects else 18, 52.0)


func projectile(from: Vector2, to: Vector2, color := Color("ff9b45")) -> void:
	var orb := Polygon2D.new()
	orb.polygon = _circle_points(10.0 if reduced_effects else 16.0, 18)
	orb.color = color
	orb.position = from
	orb.scale = Vector2(0.4, 0.4)
	add_child(orb)
	var trail := Line2D.new()
	trail.width = 8.0
	trail.default_color = Color(color, 0.55)
	trail.antialiased = true
	trail.add_point(from)
	trail.add_point(from)
	add_child(trail)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(orb, "position", to, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(orb, "scale", Vector2(1.25, 1.25), 0.20)
	tween.tween_method(func(p: Vector2) -> void:
		trail.set_point_position(1, p), from, to, 0.28)
	tween.chain().tween_callback(func() -> void:
		_burst(to, color, 6 if reduced_effects else 18, 56.0)
		orb.queue_free()
		var fade := create_tween()
		fade.tween_property(trail, "modulate:a", 0.0, 0.16)
		fade.tween_callback(trail.queue_free))


func enemy_strike(from: Vector2, to: Vector2) -> void:
	var warning := Line2D.new()
	warning.width = 5.0
	warning.default_color = Color(1.0, 0.18, 0.12, 0.78)
	warning.antialiased = true
	warning.add_point(from)
	warning.add_point(to)
	add_child(warning)
	var flash := create_tween()
	flash.tween_property(warning, "modulate:a", 0.15, 0.07)
	flash.tween_property(warning, "modulate:a", 1.0, 0.07)
	flash.tween_property(warning, "width", 18.0, 0.08)
	flash.tween_property(warning, "modulate:a", 0.0, 0.12)
	flash.tween_callback(warning.queue_free)
	_burst(to, Color("ff4938"), 5 if reduced_effects else 14, 38.0)


func warning_pulse(target: Control) -> void:
	if target == null or not is_instance_valid(target):
		return
	target.pivot_offset = target.size * 0.5
	var peak := Vector2(1.008, 1.008) if reduced_effects else Vector2(1.025, 1.025)
	var tween := create_tween()
	for i in (1 if reduced_effects else 2):
		tween.tween_property(target, "scale", peak, 0.10)
		tween.parallel().tween_property(target, "modulate", Color(1.25, 0.72, 0.65), 0.10)
		tween.tween_property(target, "scale", Vector2.ONE, 0.14)
		tween.parallel().tween_property(target, "modulate", Color.WHITE, 0.14)


func _quadratic(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	var inverse := 1.0 - t
	return inverse * inverse * a + 2.0 * inverse * t * b + t * t * c


func _circle_points(radius: float, sides := 12) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in sides:
		var angle := TAU * float(i) / float(sides)
		points.append(Vector2.from_angle(angle) * radius)
	return points


func _burst(at: Vector2, color: Color, amount: int, spread: float,
		float_up := false) -> void:
	for i in amount:
		var particle := Polygon2D.new()
		particle.polygon = _circle_points(randf_range(2.0, 5.5), 10)
		particle.color = color.lightened(randf_range(0.0, 0.28))
		particle.position = at
		add_child(particle)
		var angle := randf_range(PI * 0.15, PI * 0.85) if float_up \
				else randf_range(0.0, TAU)
		var distance := randf_range(spread * 0.45, spread)
		var destination := at + Vector2.from_angle(-angle) * distance
		var tween := create_tween().set_parallel(true)
		tween.tween_property(particle, "position", destination, randf_range(0.22, 0.42)) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "modulate:a", 0.0, 0.32).set_delay(0.06)
		tween.tween_property(particle, "scale", Vector2(0.2, 0.2), 0.32)
		tween.chain().tween_callback(particle.queue_free)


func _ring(at: Vector2, color: Color, radius: float) -> void:
	var ring := Line2D.new()
	ring.closed = true
	ring.width = 5.0
	ring.default_color = color
	ring.antialiased = true
	for point in _circle_points(radius, 32):
		ring.add_point(at + point * 0.55)
	add_child(ring)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(1.8, 1.8), 0.34) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.34)
	tween.chain().tween_callback(ring.queue_free)
