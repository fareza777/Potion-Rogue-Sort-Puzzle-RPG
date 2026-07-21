extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	var chamber := ReactionChamber.new()
	add_child(chamber)
	chamber.set_history(["red", "blue"])
	check(chamber.essence_ids() == ["red", "blue"],
			"ordered essence state is visible")
	check(chamber.get_node("Sockets").get_child_count() == 3,
			"Reaction Chamber owns exactly three sockets")
	check(not chamber.has_method("suggest_next"),
			"Reaction Chamber exposes no move-hint API")
	check(chamber.custom_minimum_size.x >= 132 and chamber.custom_minimum_size.y >= 54,
			"Chamber remains legible on a narrow phone")
	var state := {"requested": false}
	chamber.codex_requested.connect(func(): state.requested = true)
	chamber.emit_signal("pressed")
	check(state.requested, "tapping chamber requests the Formula Codex")
	chamber.free()
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS  " + label)
	else: failures += 1; push_error("FAIL  " + label)
