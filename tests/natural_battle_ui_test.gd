extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	var tube_source := FileAccess.get_file_as_string("res://src/puzzle/potion_tube.gd")
	var board_source := FileAccess.get_file_as_string("res://src/puzzle/puzzle_board.gd")
	check(not tube_source.contains("guidance_state"),
			"bottles expose no persistent target-guide state")
	check(not tube_source.contains('Color("ffd36b")'),
			"battle bottles draw no yellow focus box")
	check(not board_source.contains("_refresh_guidance()"),
			"selecting a bottle does not decorate legal targets")
	check(tube_source.contains("release_focus()"),
			"touch selection cannot leave a keyboard focus outline")
	check(tube_source.contains("play_invalid"),
			"invalid moves retain natural motion feedback")
	check(tube_source.contains("lift := -7.0 if selected"),
			"selection remains readable through physical lift")
	check(tube_source.contains("if is_locked()")
			and tube_source.contains('has_layer_effect(i, "cursed")'),
			"mechanical hazards remain visible")

	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("PASS  " + label)
	else:
		failures += 1
		push_error("FAIL  " + label)
