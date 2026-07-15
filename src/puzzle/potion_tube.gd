class_name PotionTube
extends Control
## A single potion tube. Holds up to CAPACITY liquid units (bottom -> top)
## and draws itself procedurally as a glass vial with a rounded bottom,
## glowing liquid, glass shine and a rim. Swap for sprite art in polish phase.

signal tapped(tube: PotionTube)

const CAPACITY := 4

const COLOR_MAP := {
	"red": Color("ff4d3d"),
	"green": Color("46e065"),
	"blue": Color("3d9bff"),
	"purple": Color("b04dff"),
}

## Liquid colors from bottom (index 0) to top.
var contents: Array[String] = []

## Moves remaining while this tube is magically locked (0 = unlocked).
var locked_moves := 0:
	set(value):
		locked_moves = maxi(value, 0)
		queue_redraw()

var selected := false:
	set(value):
		selected = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
			and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tapped.emit(self)


func is_locked() -> bool:
	return locked_moves > 0


func top_color() -> String:
	return "" if contents.is_empty() else contents[contents.size() - 1]


## Number of contiguous same-color units at the top.
func top_run_count() -> int:
	if contents.is_empty():
		return 0
	var color := top_color()
	var count := 0
	for i in range(contents.size() - 1, -1, -1):
		if contents[i] != color:
			break
		count += 1
	return count


func free_space() -> int:
	return CAPACITY - contents.size()


func is_complete() -> bool:
	return contents.size() == CAPACITY and top_run_count() == CAPACITY


func set_contents(new_contents: Array[String]) -> void:
	contents = new_contents.duplicate()
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var wall := 6.0
	var rim_h := 16.0                       # glass rim band at the top
	var inner_left := wall
	var inner_w := w - wall * 2.0
	var bottom_r := inner_w * 0.5           # rounded flask bottom
	var body_top := rim_h + 4.0
	var liquid_area_h := h - body_top - 6.0
	var seg_h := liquid_area_h / float(CAPACITY)
	var cx := w * 0.5

	# Soft glow behind the tube from its dominant liquid color
	if not contents.is_empty():
		var glow: Color = COLOR_MAP.get(top_color(), Color.WHITE)
		glow.a = 0.10 if not selected else 0.22
		draw_circle(Vector2(cx, h * 0.68), w * 0.55, glow)

	# Glass body (dark translucent) with rounded bottom
	var glass := Color(0.75, 0.8, 1.0, 0.07)
	draw_rect(Rect2(inner_left, body_top, inner_w, h - body_top - bottom_r), glass)
	draw_circle(Vector2(cx, h - bottom_r - 1.0), bottom_r, glass)

	# Liquid segments, bottom-up. Bottom segment fills the rounded base.
	for i in contents.size():
		var color: Color = COLOR_MAP.get(contents[i], Color.WHITE)
		var seg_top := h - 6.0 - seg_h * float(i + 1)
		if i == 0:
			draw_circle(Vector2(cx, h - bottom_r - 1.0), bottom_r - 2.0, color)
			draw_rect(Rect2(inner_left + 2.0, seg_top + 1.0,
					inner_w - 4.0, seg_h - bottom_r + 4.0), color)
		else:
			draw_rect(Rect2(inner_left + 2.0, seg_top + 1.0,
					inner_w - 4.0, seg_h - 1.0), color)
		# Brighter surface line on top of the topmost unit of each run
		if i == contents.size() - 1:
			draw_rect(Rect2(inner_left + 2.0, seg_top + 1.0, inner_w - 4.0, 4.0),
					color.lightened(0.45))

	# Glass shine: vertical highlight strip
	draw_rect(Rect2(inner_left + 4.0, body_top + 6.0, 6.0, h - body_top - 20.0),
			Color(1, 1, 1, 0.16))

	# Outline + rim
	var outline := Color("e8c069") if selected else Color("6b5f8a")
	var width := 4.0 if selected else 2.5
	draw_rect(Rect2(2, rim_h, w - 4, h - rim_h - 2), outline, false, width)
	var rim_color := outline.lightened(0.2)
	draw_rect(Rect2(0, 0, w, rim_h), Color("2e2148"))
	draw_rect(Rect2(0, 0, w, rim_h), rim_color, false, 2.5)

	# Magical lock overlay
	if is_locked():
		draw_rect(Rect2(2, rim_h, w - 4, h - rim_h - 2), Color(0.05, 0.02, 0.12, 0.62))
		var lock_c := Vector2(cx, h * 0.5)
		var lock_col := Color("c07ce8")
		draw_rect(Rect2(lock_c.x - 13, lock_c.y - 4, 26, 22), lock_col)
		draw_arc(lock_c + Vector2(0, -4), 9.0, PI, TAU, 12, lock_col, 4.0)
		var turns_label := str(locked_moves)
		draw_string(ThemeDB.fallback_font, lock_c + Vector2(-5, 40), turns_label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
