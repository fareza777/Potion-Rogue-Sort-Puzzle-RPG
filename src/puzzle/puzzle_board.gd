class_name PuzzleBoard
extends Control
## The water-sort puzzle board. Creates tubes, handles tap-to-select / tap-to-pour,
## undo, board generation and refills. Emits signals consumed by the battle layer.

signal move_made
signal tube_completed(color: String)
signal tube_selected
signal board_refilled
signal invalid_move
signal tube_locked
signal pour_presented(from_global: Vector2, to_global: Vector2, color: String, count: int)

const COLORS: Array[String] = ["red", "green", "blue", "purple"]
const FILLED_TUBES := 4
const EMPTY_TUBES := 2
const TUBE_SIZE := Vector2(84, 168)
const LAYOUT_COLUMNS := 3

var tubes: Array[PotionTube] = []
var selected_tube: PotionTube = null
var enabled := true
var _tube_size := TUBE_SIZE
var _tray: PanelContainer

## Undo history entries: {"from": PotionTube, "to": PotionTube, "count": int}.
## Cleared whenever a tube completes (its effect already fired and can't be taken back).
var _undo_stack: Array[Dictionary] = []


func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_tray = PanelContainer.new()
	_tray.name = "AlchemyTray"
	_tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_tray_style()
	center.add_child(_tray)

	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 8)
	_tray.add_child(stack)
	var caption := Label.new()
	caption.text = "ALCHEMY TABLE"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_override("font", UiKit.title_font())
	caption.add_theme_font_size_override("font_size", 15)
	caption.add_theme_color_override("font_color", Color("bba064"))
	caption.add_theme_constant_override("outline_size", 4)
	caption.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	stack.add_child(caption)

	var grid := GridContainer.new()
	grid.name = "PotionGrid"
	grid.columns = LAYOUT_COLUMNS
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 6)
	stack.add_child(grid)

	for i in FILLED_TUBES + EMPTY_TUBES:
		var tube := PotionTube.new()
		tube.custom_minimum_size = TUBE_SIZE
		tube.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tube.tapped.connect(_on_tube_tapped)
		grid.add_child(tube)
		tubes.append(tube)

	generate_board()


func apply_layout_profile(profile: Dictionary) -> void:
	var tall := str(profile.get("name", "standard")) == "tall"
	_tube_size = Vector2(84, 168) if tall else Vector2(88, 176)
	for tube in tubes:
		tube.custom_minimum_size = _tube_size


func layout_columns() -> int:
	return LAYOUT_COLUMNS


func tube_display_size() -> Vector2:
	return _tube_size


func _apply_tray_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.018, 0.045, 0.82)
	style.border_color = Color("80632e")
	style.set_border_width_all(2)
	style.set_corner_radius_all(26)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 12
	style.content_margin_bottom = 18
	style.shadow_color = Color(0.17, 0.04, 0.28, 0.72)
	style.shadow_size = 16
	_tray.add_theme_stylebox_override("panel", style)


## Deals CAPACITY units of each color randomly into the filled tubes.
## Rerolls if any tube starts already complete.
func generate_board() -> void:
	_undo_stack.clear()
	_deselect()

	var units: Array[String] = []
	for color in COLORS:
		for i in PotionTube.CAPACITY:
			units.append(color)

	var layouts: Array = []
	for attempt in 20:
		units.shuffle()
		layouts = []
		var ok := true
		for t in FILLED_TUBES:
			var slice: Array[String] = []
			for u in PotionTube.CAPACITY:
				slice.append(units[t * PotionTube.CAPACITY + u])
			# A tube must not start as a single solid color.
			if slice.count(slice[0]) == slice.size():
				ok = false
				break
			layouts.append(slice)
		if ok:
			break

	for t in tubes.size():
		if t < layouts.size():
			tubes[t].set_contents(layouts[t])
		else:
			tubes[t].set_contents([] as Array[String])


## Deterministic first-run layout. Three exposed green units teach legal
## matching immediately while preserving the complete four-color puzzle.
func generate_tutorial_board() -> void:
	_undo_stack.clear()
	_deselect()
	var layouts: Array[Array] = [
		["red", "purple", "blue", "green"],
		["purple", "red", "blue", "green"],
		["blue", "purple", "red", "green"],
		["green", "blue", "purple", "red"],
	]
	for t in tubes.size():
		if t < layouts.size():
			var contents: Array[String] = []
			contents.assign(layouts[t])
			tubes[t].set_contents(contents)
		else:
			tubes[t].set_contents([] as Array[String])


func undo() -> bool:
	if _undo_stack.is_empty():
		return false
	var move: Dictionary = _undo_stack.pop_back()
	var from_tube: PotionTube = move["from"]
	var to_tube: PotionTube = move["to"]
	var count: int = move["count"]
	for i in count:
		from_tube.contents.append(to_tube.contents.pop_back())
	from_tube.queue_redraw()
	to_tube.queue_redraw()
	_deselect()
	return true


func can_undo() -> bool:
	return not _undo_stack.is_empty()


func total_units() -> int:
	var total := 0
	for tube in tubes:
		total += tube.contents.size()
	return total


## Locks a random tube that has liquid in it for the given number of moves
## (Dark Mage / Fire Golem ability). Locked tubes can't be poured from or into.
func lock_random_tube(moves: int) -> void:
	var candidates: Array[PotionTube] = []
	for tube in tubes:
		if not tube.contents.is_empty() and not tube.is_locked():
			candidates.append(tube)
	if candidates.is_empty():
		return
	var target: PotionTube = candidates.pick_random()
	target.locked_moves = moves
	if selected_tube == target:
		_deselect()
	tube_locked.emit()


func _tick_locks() -> void:
	for tube in tubes:
		if tube.is_locked():
			tube.locked_moves -= 1


func _on_tube_tapped(tube: PotionTube) -> void:
	if not enabled:
		return
	if tube.is_locked():
		tube.play_invalid()
		invalid_move.emit()
		return
	if selected_tube == null:
		if not tube.contents.is_empty():
			selected_tube = tube
			tube.selected = true
			tube_selected.emit()
		return
	if selected_tube == tube:
		_deselect()
		return
	if _try_pour(selected_tube, tube):
		_deselect()
	else:
		# Invalid pour: treat the tap as selecting the new tube instead.
		tube.play_invalid()
		_deselect()
		if not tube.contents.is_empty():
			selected_tube = tube
			tube.selected = true
		invalid_move.emit()


func _try_pour(from_tube: PotionTube, to_tube: PotionTube) -> bool:
	if from_tube.contents.is_empty() or to_tube.free_space() == 0:
		return false
	var color := from_tube.top_color()
	if not to_tube.contents.is_empty() and to_tube.top_color() != color:
		return false

	var count: int = mini(from_tube.top_run_count(), to_tube.free_space())
	var from_global := from_tube.global_position + from_tube.size * 0.5
	var to_global := to_tube.global_position + to_tube.size * 0.5
	for i in count:
		to_tube.contents.append(from_tube.contents.pop_back())
	from_tube.queue_redraw()
	to_tube.queue_redraw()

	_undo_stack.append({"from": from_tube, "to": to_tube, "count": count})
	_tick_locks()
	move_made.emit()
	pour_presented.emit(from_global, to_global, color, count)

	if to_tube.is_complete():
		_undo_stack.clear()
		var completed_color := to_tube.top_color()
		_flash_and_empty(to_tube)
		tube_completed.emit(completed_color)
	return true


func _flash_and_empty(tube: PotionTube) -> void:
	tube.flash_complete()
	tube.set_contents([] as Array[String])
	# Each color exists exactly once per board, so the board only runs dry
	# when every color has been completed -> brew a fresh batch.
	if total_units() == 0:
		generate_board()
		board_refilled.emit()


func _deselect() -> void:
	if selected_tube != null:
		selected_tube.selected = false
		selected_tube = null
