class_name AmbientParticles
extends Control
## Lightweight deterministic embers for menu atmosphere. Uses CanvasItem
## drawing so it adds no external runtime dependency.

var reduced_effects := false
var _motes: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xC0FFEE
	for i in 22:
		_motes.append({
			"x": rng.randf_range(0.06, 0.94),
			"y": rng.randf(),
			"speed": rng.randf_range(0.018, 0.052),
			"radius": rng.randf_range(1.0, 3.2),
			"phase": rng.randf_range(0.0, TAU),
			"purple": i % 5 == 0,
		})


func set_reduced_effects(value: bool) -> void:
	reduced_effects = value
	set_process(not value)
	queue_redraw()


func _process(delta: float) -> void:
	for i in _motes.size():
		var mote: Dictionary = _motes[i]
		mote.y = fmod(float(mote.y) - float(mote.speed) * delta + 1.0, 1.0)
		mote.phase = fmod(float(mote.phase) + delta * 1.4, TAU)
		_motes[i] = mote
	queue_redraw()


func _draw() -> void:
	var visible_count := 0 if reduced_effects else _motes.size()
	for i in visible_count:
		var mote: Dictionary = _motes[i]
		var alpha := 0.20 + 0.22 * (0.5 + 0.5 * sin(float(mote.phase)))
		var color := Color(0.62, 0.30, 1.0, alpha) if bool(mote.purple) \
				else Color(1.0, 0.58, 0.16, alpha)
		var point := Vector2(float(mote.x) * size.x, float(mote.y) * size.y)
		draw_circle(point, float(mote.radius) * 2.4, Color(color, alpha * 0.15))
		draw_circle(point, float(mote.radius), color)
