class_name FormulaSocket
extends Control
## Faceted alchemy socket used by the Formula Codex. It is drawn from clean
## vector geometry so it stays crisp on every supported phone resolution.

const COLORS := {
	"red": Color("ff5a4d"),
	"green": Color("59e17b"),
	"blue": Color("55b5ff"),
	"purple": Color("c06aff"),
	"wild": Color("f4ca62"),
}

var essence := "wild"
var discovered := true


func _init() -> void:
	custom_minimum_size = Vector2(42, 42)
	mouse_default_cursor_shape = Control.CURSOR_HELP
	mouse_filter = Control.MOUSE_FILTER_PASS


func configure(value: String, is_discovered: bool) -> FormulaSocket:
	essence = value
	discovered = is_discovered
	name = "FormulaSocket_" + (essence if discovered else "unknown")
	tooltip_text = (essence.capitalize() + " essence") if discovered \
			else "Unknown essence — discover this formula in battle"
	queue_redraw()
	return self


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.43
	var shadow := _octagon(center + Vector2(0, 2), radius + 2.0)
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.58))
	var rim := _octagon(center, radius)
	draw_colored_polygon(rim, Color("d8b95f") if discovered else Color("625773"))
	var color: Color = COLORS.get(essence, Color("8a7b99")) if discovered \
			else Color("262031")
	var gem := _octagon(center, radius - 4.0)
	draw_colored_polygon(gem, color.darkened(0.25))
	var facet := PackedVector2Array([
		center + Vector2(0, -radius + 5),
		center + Vector2(radius - 6, 0),
		center + Vector2(0, radius - 5),
		center + Vector2(-radius + 6, 0),
	])
	draw_colored_polygon(facet, color)
	draw_polyline(PackedVector2Array([facet[0], facet[1], facet[2], facet[3], facet[0]]),
			Color(1, 1, 1, 0.38), 1.5, true)
	if discovered:
		draw_circle(center - Vector2(radius * 0.22, radius * 0.25),
				maxf(radius * 0.12, 2.0), Color(1, 1, 1, 0.70))
	else:
		draw_string(ThemeDB.fallback_font, center + Vector2(-5, 7), "?",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("b8aeca"))


func _octagon(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in 8:
		var angle := -PI * 0.5 + TAU * float(index) / 8.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points
