extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	var jobs := RemixJobController.new()
	var state: Array = [["red"], ["green"], [], [], [], []]
	var snapshot := {"version":1, "state":state,
			"capacities":[4, 4, 4, 4, 4, 4]}
	var started := Time.get_ticks_msec()
	var first := jobs.request(snapshot, 10, "standard", 4)
	var request_ms := Time.get_ticks_msec() - started
	var second := jobs.request(snapshot, 11, "standard", 4)
	var payload := {}
	var deadline := Time.get_ticks_msec() + 2000
	while payload.is_empty() and Time.get_ticks_msec() < deadline:
		payload = jobs.poll()
		await get_tree().process_frame
	check(first < second, "generation IDs increase monotonically")
	check(request_ms < 50,
			"request acknowledges before integrity analysis can block the render thread")
	check(not payload.is_empty() and int(payload.get("generation_id", -1)) == second,
			"only the newest generation is accepted")
	check(str(payload.get("integrity", {}).get("status", "")) == "recoverable",
			"background job returns the integrity decision with its remix")
	var result: Dictionary = payload.get("result", {})
	check(bool(result.get("analysis", {}).get("solvable", false)),
			"background remix produces a solver-verified board")
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS  ", label)
	else: failures += 1; print("FAIL  ", label)
