extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	var guide := BoardGuidance.new()
	var state := [["red"], ["red", "green"], [], ["blue", "blue", "blue", "blue"]]
	var result := guide.for_selection(state, 0, 4)
	check(2 in result.valid_targets, "rules recognize an empty tube as legal")
	check(1 not in result.valid_targets, "rules reject a different top color")
	check(3 not in result.valid_targets, "rules reject a full tube")
	check(guide.invalid_reason(state, 0, 1, 4) == "Only matching colors can be poured together",
			"invalid move explains the color rule")
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS  ", label)
	else: failures += 1; print("FAIL  ", label)
