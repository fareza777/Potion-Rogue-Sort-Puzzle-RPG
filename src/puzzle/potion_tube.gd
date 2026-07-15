class_name PotionTube
extends Control
## A single potion tube. Holds up to CAPACITY liquid units (bottom -> top)
## and draws itself procedurally (placeholder art, easy to swap for sprites later).

signal tapped(tube: PotionTube)

const CAPACITY := 4

const COLOR_MAP := {
	"red": Color("e84545"),
	"green": Color("4ecf6a"),
	"blue": Color("4a9de8"),
	"purple": Color("a05ce8"),
}

## Liquid colors from bottom (index 0) to top.
var contents: Array[String] = []

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
	var wall := 5.0
	var neck := 14.0  # empty space above the top segment for the tube "mouth"
	var seg_h := (h - neck - wall) / float(CAPACITY)

	# Glass background
	draw_rect(Rect2(wall, wall, w - wall * 2.0, h - wall * 2.0), Color(1, 1, 1, 0.05))

	# Liquid segments, bottom-up
	for i in contents.size():
		var color: Color = COLOR_MAP.get(contents[i], Color.WHITE)
		var y := h - wall - seg_h * float(i + 1)
		draw_rect(Rect2(wall + 1.0, y, w - (wall + 1.0) * 2.0, seg_h - 2.0), color)
		# Subtle glow highlight strip on the left edge of each segment
		draw_rect(Rect2(wall + 3.0, y + 2.0, 5.0, seg_h - 6.0),
				Color(1, 1, 1, 0.22))

	# Outline (brighter + thicker when selected)
	var outline := Color("efe6ff") if selected else Color("6b5f8a")
	var width := 4.0 if selected else 2.5
	draw_rect(Rect2(2, 2, w - 4, h - 4), outline, false, width)
