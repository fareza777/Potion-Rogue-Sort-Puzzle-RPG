extends Node

var checks := 0
var failures := 0

func _ready() -> void:
	var original := SaveSystem.data.duplicate(true)
	SaveSystem.data = SaveSystem.DEFAULT_DATA.duplicate(true)
	check(SaveSystem.setting("color_patterns") == false, "clean potion liquids default without symbols")
	var tube_source := FileAccess.get_file_as_string("res://src/puzzle/potion_tube.gd")
	check(tube_source.contains("_draw_color_sigil") and tube_source.contains("ui_accept"),
			"potion tubes offer opt-in colorblind sigils and keyboard activation")
	check(tube_source.contains("color_patterns"),
			"sigils are gated behind the saved accessibility setting")
	var board_source := FileAccess.get_file_as_string("res://src/puzzle/puzzle_board.gd")
	check(board_source.contains("focus_neighbor_left") and board_source.contains("focus_neighbor_right"),
			"potion row exposes an explicit focus graph")
	var battle_source := FileAccess.get_file_as_string("res://src/ui/battle_screen.gd")
	check(battle_source.contains("ui_cancel") and battle_source.contains("_show_pause"),
			"Android Back and controller cancel pause battle")
	var settings_source := FileAccess.get_file_as_string("res://src/ui/settings_screen.gd")
	check(settings_source.contains("POTION SIGILS") and settings_source.contains("REDUCED EFFECTS"),
			"settings expose Potion Sigils alongside Reduced Effects")
	SaveSystem.data = original; SaveSystem.save()
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS  ", label)
	else: failures += 1; print("FAIL  ", label)
