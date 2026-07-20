class_name PuzzleBoard
extends Control
## The water-sort puzzle board. Creates tubes, handles tap-to-select / tap-to-pour,
## undo, board generation and refills. Emits signals consumed by the battle layer.

signal move_made
signal tube_completed(color: String)
signal tube_selected
signal board_refilled
signal invalid_move
signal guidance_changed(message: String)
signal tube_locked
signal curse_cleansed(count: int)
signal pour_presented(from_global: Vector2, to_global: Vector2, color: String, count: int)

const COLORS: Array[String] = ["red", "green", "blue", "purple"]
const FILLED_TUBES := 4
const EMPTY_TUBES := 2
const TUBE_SIZE := Vector2(100, 220)
const LAYOUT_COLUMNS := 6

var tubes: Array[PotionTube] = []
var selected_tube: PotionTube = null
var enabled := true
var _tube_size := TUBE_SIZE

## Undo history entries: {"from": PotionTube, "to": PotionTube, "count": int}.
## Cleared whenever a tube completes (its effect already fired and can't be taken back).
var _undo_stack: Array[Dictionary] = []


func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var grid := GridContainer.new()
	grid.name = "PotionShelf"
	grid.columns = LAYOUT_COLUMNS
	grid.add_theme_constant_override("h_separation", 7)
	grid.add_theme_constant_override("v_separation", 0)
	center.add_child(grid)

	for i in FILLED_TUBES + EMPTY_TUBES:
		var tube := PotionTube.new()
		tube.name = "PotionTube%d" % i
		tube.custom_minimum_size = TUBE_SIZE
		tube.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tube.tapped.connect(_on_tube_tapped)
		grid.add_child(tube)
		tubes.append(tube)
	for i in tubes.size():
		tubes[i].focus_neighbor_left = tubes[i].get_path_to(tubes[(i - 1 + tubes.size()) % tubes.size()])
		tubes[i].focus_neighbor_right = tubes[i].get_path_to(tubes[(i + 1) % tubes.size()])

	generate_board()


func apply_layout_profile(profile: Dictionary) -> void:
	var tall := str(profile.get("name", "standard")) == "tall"
	_tube_size = Vector2(96, 212) if tall else TUBE_SIZE
	for tube in tubes:
		tube.custom_minimum_size = _tube_size


func layout_columns() -> int:
	return LAYOUT_COLUMNS


func tube_display_size() -> Vector2:
	return _tube_size


func export_state() -> Array:
	var state: Array = []
	for tube in tubes:
		state.append(tube.contents.duplicate())
	return state


func export_snapshot() -> Dictionary:
	var locks: Array[int] = []
	var capacities: Array[int] = []
	for tube in tubes:
		locks.append(tube.locked_moves)
		capacities.append(tube.capacity)
	return {"version": 1, "state": export_state(), "locks": locks,
			"capacities": capacities}


func integrity_report() -> Dictionary:
	return BoardIntegrityGuard.new().inspect(export_snapshot())


func restore_snapshot(snapshot: Dictionary) -> bool:
	if int(snapshot.get("version", 0)) != 1 or typeof(snapshot.get("state")) != TYPE_ARRAY:
		return false
	var capacities: Array = snapshot.get("capacities", [])
	for index in tubes.size():
		if index < capacities.size():
			tubes[index].capacity = clampi(int(capacities[index]), 1, 8)
	import_state(snapshot.get("state", []))
	var locks: Array = snapshot.get("locks", [])
	for index in tubes.size():
		tubes[index].locked_moves = maxi(int(locks[index]), 0) if index < locks.size() else 0
	return true


func import_state(state: Array) -> void:
	_deselect()
	_undo_stack.clear()
	for index in tubes.size():
		var contents: Array[String] = []
		if index < state.size() and typeof(state[index]) == TYPE_ARRAY:
			for value in state[index]:
				contents.append(str(value))
		if contents.size() <= tubes[index].capacity:
			tubes[index].set_contents(contents)
		else:
			tubes[index].set_contents([] as Array[String])


func legal_moves() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for from_index in tubes.size():
		var source := tubes[from_index]
		if source.contents.is_empty() or source.is_locked():
			continue
		for to_index in tubes.size():
			if from_index == to_index:
				continue
			var destination := tubes[to_index]
			if destination.is_locked() or destination.free_space() <= 0:
				continue
			if destination.contents.is_empty() \
					or destination.top_color() == source.top_color() \
					or destination.top_color() == "wild" \
					or source.top_color() == "wild":
				result.append(Vector2i(from_index, to_index))
	return result


## Applies a batch atomically and rejects puzzle states the solver cannot finish.
## Enemy and boss hazards must use this boundary instead of mutating tubes directly.
func try_board_commands(commands: Array[Dictionary]) -> bool:
	if commands.is_empty():
		return false
	var before := export_snapshot()
	for command in commands:
		if not apply_board_command(command):
			restore_snapshot(before)
			return false
	if not BoardSolver.has_solution(export_state(), PotionTube.CAPACITY):
		restore_snapshot(before)
		return false
	_undo_stack.clear()
	return true


func apply_board_command(command: Dictionary) -> bool:
	var command_type := str(command.get("type", ""))
	if command_type == "rotate_top":
		var indices: Array = command.get("tubes", [])
		if indices.size() < 2:
			return false
		var colors: Array[String] = []
		var seen := {}
		for raw_index in indices:
			var candidate := int(raw_index)
			if candidate < 0 or candidate >= tubes.size() or seen.has(candidate) \
					or tubes[candidate].contents.is_empty():
				return false
			seen[candidate] = true
			colors.append(str(tubes[candidate].contents.back()))
		for position in indices.size():
			var target := tubes[int(indices[position])]
			target.contents[target.contents.size() - 1] = colors[
					(position - 1 + colors.size()) % colors.size()]
			target.queue_redraw()
		return true
	var index := int(command.get("tube", -1))
	if index < 0 or index >= tubes.size():
		return false
	var tube := tubes[index]
	match command_type:
		"append_corruption":
			if tube.contents.is_empty():
				return false
			return tube.add_layer_effect(tube.contents.size() - 1, "cursed")
		"lock_tube":
			tube.locked_moves = maxi(int(command.get("moves", 1)), 1)
		"unlock_tube":
			tube.locked_moves = 0
		"replace_top":
			if tube.contents.is_empty():
				return false
			tube.contents[tube.contents.size() - 1] = str(command.get("color", ""))
			tube.queue_redraw()
		"append_layer":
			if tube.free_space() <= 0:
				return false
			tube.contents.append(str(command.get("color", "")))
			tube.layer_effects.append([])
			tube.queue_redraw()
		"swap_top":
			var other_index := int(command.get("other", -1))
			if other_index < 0 or other_index >= tubes.size() or other_index == index:
				return false
			var other := tubes[other_index]
			if tube.contents.is_empty() or other.contents.is_empty():
				return false
			var color := str(tube.contents.back())
			tube.contents[tube.contents.size() - 1] = str(other.contents.back())
			other.contents[other.contents.size() - 1] = color
			tube.queue_redraw()
			other.queue_redraw()
		"reveal_top":
			tube.queue_redraw()
		"set_capacity":
			var new_capacity := int(command.get("capacity", 0))
			if new_capacity < 1 or new_capacity > 8 \
					or tube.contents.size() > new_capacity:
				return false
			tube.capacity = new_capacity
		_:
			return false
	return true


## Deals a solver-verified board while retaining the existing board/UI lifecycle.
func generate_board() -> void:
	_undo_stack.clear()
	_deselect()
	_apply_factory_result(BoardFactory.generate(int(randi()), "standard", COLORS.size(),
			PotionTube.CAPACITY, tubes.size()))


func remix_board(seed := int(randi()), band := "standard") -> void:
	_undo_stack.clear()
	_deselect()
	_apply_factory_result(BoardFactory.remix(export_state(), seed, band,
			PotionTube.CAPACITY))


func apply_remix_result(result: Dictionary) -> bool:
	if typeof(result.get("state")) != TYPE_ARRAY \
			or not bool(result.get("analysis", {}).get("solvable", false)):
		return false
	var layouts: Array = result.get("state", [])
	if layouts.size() != tubes.size():
		return false
	var before := export_snapshot()
	# New Mix is a board reset boundary. Capacity-changing and locking hazards
	# must be cleared before dealing, otherwise a valid four-layer result can land
	# in a three-slot/locked flask and be rejected only for some random seeds.
	for tube in tubes:
		tube.capacity = PotionTube.CAPACITY
		tube.locked_moves = 0
	_undo_stack.clear()
	_deselect()
	_apply_factory_result(result)
	if _remix_shape_is_valid():
		return true
	restore_snapshot(before)
	return false


func _remix_shape_is_valid() -> bool:
	var counts := {}
	var total := 0
	for tube in tubes:
		if tube.contents.size() > tube.capacity or tube.is_complete():
			return false
		for value in tube.contents:
			var color := str(value)
			if color.is_empty():
				return false
			counts[color] = int(counts.get(color, 0)) + 1
			total += 1
	if total <= 0:
		return false
	for color in counts:
		if int(counts[color]) % PotionTube.CAPACITY != 0:
			return false
	return true


func _apply_factory_result(result: Dictionary) -> void:
	var layouts: Array = result.get("state", [])
	for index in tubes.size():
		var contents: Array[String] = []
		if index < layouts.size() and typeof(layouts[index]) == TYPE_ARRAY:
			for value in layouts[index]:
				contents.append(str(value))
		tubes[index].set_contents(contents)


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
		from_tube.layer_effects.append(to_tube.layer_effects.pop_back())
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
			_refresh_guidance()
			tube_selected.emit()
		return
	if selected_tube == tube:
		_deselect()
		return
	if _try_pour(selected_tube, tube):
		_deselect()
	else:
		# Invalid pour: treat the tap as selecting the new tube instead.
		var from_index := tubes.find(selected_tube)
		var reason := BoardGuidance.new().invalid_reason(export_state(), from_index,
				tubes.find(tube), tube.capacity)
		tube.play_invalid()
		_deselect()
		if not tube.contents.is_empty():
			selected_tube = tube
			tube.selected = true
			_refresh_guidance()
		invalid_move.emit()
		guidance_changed.emit(reason)


func _try_pour(from_tube: PotionTube, to_tube: PotionTube) -> bool:
	if from_tube.contents.is_empty() or to_tube.free_space() == 0:
		return false
	var color := from_tube.top_color()
	var destination_color := to_tube.top_color()
	if not to_tube.contents.is_empty() and destination_color != color \
			and destination_color != "wild" and color != "wild":
		return false
	var poured_color := destination_color if color == "wild" \
			and not destination_color.is_empty() else color
	if destination_color == "wild" and color != "wild":
		for index in range(to_tube.contents.size() - 1, -1, -1):
			if to_tube.contents[index] != "wild":
				break
			to_tube.contents[index] = color
		poured_color = color

	var count: int = mini(from_tube.top_run_count(), to_tube.free_space())
	var from_global := from_tube.global_position + from_tube.size * 0.5
	var to_global := to_tube.global_position + to_tube.size * 0.5
	for i in count:
		var moved_color: String = from_tube.contents.pop_back()
		var moved_effects: Array = from_tube.layer_effects.pop_back()
		to_tube.contents.append(poured_color if moved_color == "wild" \
				and poured_color != "wild" else moved_color)
		to_tube.layer_effects.append(moved_effects)
	from_tube.queue_redraw()
	to_tube.queue_redraw()

	_undo_stack.append({"from": from_tube, "to": to_tube, "count": count})
	_tick_locks()
	move_made.emit()
	pour_presented.emit(from_global, to_global, poured_color, count)

	if to_tube.is_complete():
		_undo_stack.clear()
		var completed_color := to_tube.top_color()
		var cursed_count := to_tube.effect_count("cursed")
		_flash_and_empty(to_tube)
		if cursed_count > 0:
			curse_cleansed.emit(cursed_count)
		else:
			tube_completed.emit(completed_color)
		# Completion listeners resolve combat synchronously. Do not generate an
		# unused puzzle behind a victory overlay; refill only if battle continues.
		if total_units() == 0 and enabled:
			generate_board()
			board_refilled.emit()
	return true


func _flash_and_empty(tube: PotionTube) -> void:
	tube.flash_complete()
	tube.set_contents([] as Array[String])


func _deselect() -> void:
	if selected_tube != null:
		selected_tube.selected = false
		selected_tube = null
	for tube in tubes: tube.guidance_state = "neutral"


func _refresh_guidance() -> void:
	if selected_tube == null: return
	var source_index := tubes.find(selected_tube)
	var valid: Array = BoardGuidance.new().for_selection(export_state(), source_index,
			selected_tube.capacity).get("valid_targets", [])
	for index in tubes.size():
		tubes[index].guidance_state = "neutral" if index == source_index else (
				"valid" if index in valid else "dim")
