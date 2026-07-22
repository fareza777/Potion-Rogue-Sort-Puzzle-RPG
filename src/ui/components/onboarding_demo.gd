class_name OnboardingDemo
extends Control
## Procedural teaching animation. It never touches run or combat state.

const COLORS := {"red":Color("ff5548"), "green":Color("55df72"),
	"blue":Color("4ba8ff"), "purple":Color("b85cff")}

var _chapter := "sort"
var _progress := 1.0:
	set(value):
		_progress = clampf(value, 0.0, 1.0)
		queue_redraw()
var _chapter_tween: Tween


func _ready() -> void:
	name = "OnboardingDemo"
	custom_minimum_size = Vector2(0, 250)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_chapter(id: String, reduced_effects: bool) -> void:
	_chapter = id
	if _chapter_tween != null and _chapter_tween.is_valid(): _chapter_tween.kill()
	_progress = 1.0 if reduced_effects else 0.0
	if not reduced_effects:
		_chapter_tween = create_tween()
		_chapter_tween.tween_property(self, "_progress", 1.0, 1.25) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	queue_redraw()


func _draw() -> void:
	var center := size * Vector2(0.5, 0.50)
	draw_circle(center, minf(size.x, size.y) * 0.43, Color(0.08, 0.025, 0.14, 0.72))
	draw_arc(center, minf(size.x, size.y) * 0.41, 0, TAU, 64, Color("a86ce8", 0.42), 2.0)
	match _chapter:
		"sort": _draw_sort(center)
		"brew": _draw_brew(center)
		"survive": _draw_survive(center)
		"react": _draw_react(center)
		"cast": _draw_cast(center)
		"explore": _draw_explore(center)


func _draw_sort(center: Vector2) -> void:
	var source := center + Vector2(-105, -4); var target := center + Vector2(105, -4)
	_draw_flask(source, [COLORS.red, COLORS.blue, COLORS.blue])
	_draw_flask(target, [COLORS.blue])
	var bead := source.lerp(target, _progress) + Vector2(0, -62 - sin(_progress * PI) * 28)
	draw_circle(bead, 14, COLORS.blue); draw_circle(bead, 7, Color("b9f2ff", 0.7))
	_caption(center, "MATCH THE TOP COLOR")


func _draw_brew(center: Vector2) -> void:
	var labels := ["FIRE", "HEAL", "SHIELD", "POISON"]; var ids := ["red", "green", "blue", "purple"]
	for index in 4:
		var x := center.x + (index - 1.5) * 88.0
		_draw_flask(Vector2(x, center.y - 8), [COLORS[ids[index]]])
		_text(Vector2(x - 36, center.y + 88), labels[index], COLORS[ids[index]], 72)
	_caption(center, "FOUR LAYERS BREW ONE POTION")


func _draw_survive(center: Vector2) -> void:
	draw_circle(center + Vector2(0, -25), 54, Color("70d44f"))
	draw_circle(center + Vector2(-18, -33), 7, Color("241426")); draw_circle(center + Vector2(18, -33), 7, Color("241426"))
	var active := mini(int(floor(_progress * 4.0)), 3)
	for index in 4:
		draw_circle(center + Vector2((index - 1.5) * 42.0, 63), 12,
				Color("ff765f") if index <= active else Color("4d394c"))
	_caption(center, "EACH POUR ADVANCES THE INTENT")


func _draw_react(center: Vector2) -> void:
	var filled := mini(int(ceil(_progress * 3.0)), 3)
	for index in 3:
		var position := center + Vector2((index - 1.0) * 76.0, -8)
		draw_circle(position, 26, COLORS.red if index < filled else Color("33293f"))
		draw_arc(position, 28, 0, TAU, 32, Color("fff0bc"), 3)
	if _progress > 0.70: draw_arc(center, 78, 0, TAU, 42, Color("ff9448", 0.8), 5)
	_caption(center, "RED  →  RED  =  FIRE BURST")


func _draw_cast(center: Vector2) -> void:
	var width := 250.0
	draw_rect(Rect2(center + Vector2(-width * 0.5, -50), Vector2(width, 24)), Color("201b38"), true)
	draw_rect(Rect2(center + Vector2(-width * 0.5, -50), Vector2(width * _progress, 24)), Color("3aa8e8"), true)
	var lit := _progress > 0.72
	draw_circle(center + Vector2(-78, 36), 38, Color("267ba7") if lit else Color("3b3447"))
	draw_circle(center + Vector2(78, 36), 38, Color("d98936") if lit else Color("3b3447"))
	_text(center + Vector2(-108, 43), "SKILL", Color.WHITE, 60)
	_text(center + Vector2(48, 43), "ULT", Color.WHITE, 60)
	_caption(center, "MANA CASTS SKILLS • REACTIONS CHARGE ULT")


func _draw_explore(center: Vector2) -> void:
	var nodes := [Vector2(0, 70), Vector2(-82, 8), Vector2(82, 8), Vector2(-42, -70), Vector2(42, -70)]
	for edge in [[0,1],[0,2],[1,3],[2,4],[3,4]]:
		draw_line(center + nodes[edge[0]], center + nodes[edge[1]], Color("c481ed", 0.78), 5)
	for index in nodes.size():
		var reveal := _progress >= float(index + 1) / float(nodes.size())
		draw_circle(center + nodes[index], 21, Color("f0bf53") if reveal else Color("362d43"))
		draw_arc(center + nodes[index], 23, 0, TAU, 28, Color("fff0be"), 2)
	_caption(center, "NEW HIDDEN ROUTES EVERY RUN")


func _draw_flask(at: Vector2, layers: Array) -> void:
	var style := StyleBoxFlat.new(); style.bg_color = Color("151322", 0.94)
	style.border_color = Color("d7bd85"); style.set_border_width_all(3); style.set_corner_radius_all(22)
	draw_style_box(style, Rect2(at + Vector2(-30, -62), Vector2(60, 126)))
	for index in layers.size():
		draw_rect(Rect2(at.x - 23, at.y + 45 - index * 24, 46, 22), layers[index], true)
	draw_rect(Rect2(at.x - 18, at.y - 82, 36, 24), Color("2a1d24"), true)
	draw_line(at + Vector2(-13, -50), at + Vector2(-13, 45), Color(1, 1, 1, 0.45), 4)


func _caption(center: Vector2, value: String) -> void:
	_text(Vector2(center.x - 225, center.y + 111), value, Color("f2d17d"), 450)


func _text(position: Vector2, value: String, color: Color, width: float) -> void:
	draw_string(UiKit.title_font(), position, value, HORIZONTAL_ALIGNMENT_CENTER, width, 14, color)
