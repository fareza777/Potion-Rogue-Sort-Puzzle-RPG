class_name EnemyDisplay
extends Control
## Procedural placeholder enemy sprite (a slime blob) with hit-shake
## and hurt-flash feedback. Swap for real sprites in the polish phase.

var body_color := Color("6fce4e")
var _flash := 0.0


func set_enemy_color(hex: String) -> void:
	body_color = Color(hex)
	queue_redraw()


func play_hit() -> void:
	_flash = 1.0
	queue_redraw()
	var tween := create_tween()
	var origin := position
	tween.tween_property(self, "position", origin + Vector2(10, 0), 0.05)
	tween.tween_property(self, "position", origin - Vector2(10, 0), 0.05)
	tween.tween_property(self, "position", origin, 0.05)
	tween.parallel().tween_method(_set_flash, 1.0, 0.0, 0.3)


func _set_flash(value: float) -> void:
	_flash = value
	queue_redraw()


func _draw() -> void:
	var center := size / 2.0
	var radius: float = minf(size.x, size.y) * 0.38
	var color := body_color.lerp(Color.WHITE, _flash)

	# Body: squashed blob (wide ellipse approximated with two circles + rect)
	draw_circle(center + Vector2(0, radius * 0.25), radius, color)
	draw_rect(Rect2(center.x - radius, center.y + radius * 0.25,
			radius * 2.0, radius * 0.9), color)
	# Shine
	draw_circle(center + Vector2(-radius * 0.35, -radius * 0.15),
			radius * 0.18, Color(1, 1, 1, 0.35))
	# Eyes
	var eye_y := center.y + radius * 0.05
	draw_circle(Vector2(center.x - radius * 0.35, eye_y), radius * 0.10, Color("1a1226"))
	draw_circle(Vector2(center.x + radius * 0.35, eye_y), radius * 0.10, Color("1a1226"))
