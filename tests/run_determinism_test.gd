extends Node

const RNG_PATH := "res://src/run/run_rng.gd"
var checks := 0
var failures := 0


func _ready() -> void:
	check(FileAccess.file_exists(RNG_PATH), "serialized RunRng exists")
	if not FileAccess.file_exists(RNG_PATH): finish(); return
	var script := load(RNG_PATH) as Script
	var first = script.new(); first.configure(8675309)
	var prefix: Array = []
	for index in 8: prefix.append(first.randi_range(0, 9999))
	var checkpoint: Dictionary = first.snapshot()
	var future: Array = []
	for index in 20: future.append(first.randi_range(0, 9999))
	var resumed = script.new(); resumed.configure(8675309, int(checkpoint.state))
	var resumed_future: Array = []
	for index in 20: resumed_future.append(resumed.randi_range(0, 9999))
	check(future == resumed_future, "RNG future survives save and resume exactly")
	var a = script.new(); a.configure(42)
	var b = script.new(); b.configure(42)
	var shuffled_a: Array = a.permute_serialized([1,2,3,4,5,6])
	var shuffled_b: Array = b.permute_serialized([1,2,3,4,5,6])
	check(shuffled_a == shuffled_b,
			"shuffle is deterministic")
	var generator_source := FileAccess.get_file_as_string("res://src/run/run_generator.gd")
	var reward_source := FileAccess.get_file_as_string("res://src/run/reward_generator.gd")
	var state_source := FileAccess.get_file_as_string("res://src/autoload/run_state.gd")
	check(not generator_source.contains("RandomNumberGenerator"), "route generation uses serialized RNG")
	check(not reward_source.contains("RandomNumberGenerator"), "reward generation uses serialized RNG")
	check(not state_source.contains("candidates.shuffle()") and state_source.contains('"rng_state"'),
			"run rewards advance a persisted RNG state")
	var director := RunDirector.new()
	var recovery_low := 0
	var recovery_high := 0
	for seed in 300:
		var low = script.new(); low.configure(seed + 100)
		var high = script.new(); high.configure(seed + 100)
		if director.assign_kind(3, 0, 0, {"hp_ratio":0.30}, low) == "campfire": recovery_low += 1
		if director.assign_kind(3, 0, 0, {"hp_ratio":1.0}, high) == "campfire": recovery_high += 1
	check(recovery_low > recovery_high, "low HP increases recovery availability deterministically")
	finish()


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS  ", label)
	else: failures += 1; print("FAIL  ", label)


func finish() -> void:
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
