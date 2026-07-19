extends Node

const SCHEDULER_PATH := "res://src/autoload/checkpoint_scheduler.gd"
var checks := 0
var failures := 0
var writes := 0
var fail_writes := false
var last_phase := ""
var last_payload: Dictionary = {}


func _ready() -> void:
	check(FileAccess.file_exists(SCHEDULER_PATH),
			"checkpoint scheduler exists")
	if not FileAccess.file_exists(SCHEDULER_PATH):
		finish()
		return
	var scheduler = (load(SCHEDULER_PATH) as Script).new()
	scheduler.configure(_write_boundary)
	for index in 20:
		scheduler.request("BATTLE", {"move": index})
	check(scheduler.pending_count() == 20,
			"twenty rapid checkpoints remain one pending coalesced boundary")
	check(writes == 0, "request path performs no synchronous disk write")
	check(scheduler.flush("test"), "forced flush succeeds")
	check(writes == 1 and last_phase == "BATTLE" and int(last_payload.move) == 19,
			"forced flush writes only the newest boundary once")

	fail_writes = true
	scheduler.request("BATTLE", {"move": 20})
	check(not scheduler.flush("failure") and scheduler.pending_count() == 1,
			"failed write retains pending boundary for retry")
	fail_writes = false
	check(scheduler.flush("retry") and writes == 3 and scheduler.pending_count() == 0,
			"retry clears the journal after a successful write")
	check(RunState.has_method("request_checkpoint") and RunState.has_method("flush_checkpoint"),
			"RunState exposes coalesced and forced checkpoint paths")
	var battle_source := FileAccess.get_file_as_string("res://src/ui/battle_screen.gd")
	check(battle_source.contains("RunState.request_checkpoint") \
			and battle_source.contains("RunState.flush_checkpoint"),
			"battle moves coalesce while save-and-exit forces a flush")
	finish()


func _write_boundary(phase: String, payload: Dictionary) -> bool:
	writes += 1
	last_phase = phase
	last_payload = payload.duplicate(true)
	return not fail_writes


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS  ", label)
	else: failures += 1; print("FAIL  ", label)


func finish() -> void:
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
