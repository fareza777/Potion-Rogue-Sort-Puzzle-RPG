extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	var jobs := RemixJobController.new()
	var state: Array = [["red"], ["green"], [], [], [], []]
	var first := jobs.request(state, 10, "standard", 4)
	var second := jobs.request(state, 11, "standard", 4)
	var payload := {}
	var deadline := Time.get_ticks_msec() + 2000
	while payload.is_empty() and Time.get_ticks_msec() < deadline:
		payload = jobs.poll()
		await get_tree().process_frame
	check(first < second, "generation IDs increase monotonically")
	check(not payload.is_empty() and int(payload.get("generation_id", -1)) == second,
			"only the newest generation is accepted")
	var result: Dictionary = payload.get("result", {})
	check(bool(result.get("analysis", {}).get("solvable", false)),
			"background remix produces a solver-verified board")
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS  ", label)
	else: failures += 1; print("FAIL  ", label)
