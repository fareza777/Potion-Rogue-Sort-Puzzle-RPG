extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	check(ResourceLoader.exists("res://src/testing/runtime_budget_probe.gd"),
			"runtime budget probe exists")
	if failures > 0:
		finish()
		return
	var probe = load("res://src/testing/runtime_budget_probe.gd").new()
	probe.begin_input()
	probe.end_input()
	probe.begin_remix()
	probe.end_remix()
	probe.begin_scene()
	probe.end_scene()
	for frame_ms in [12.0, 17.0, 21.0, 15.0, 28.0, 14.0, 16.0, 18.0, 13.0, 20.0]:
		probe.record_frame(frame_ms, 42)
	probe.set_cache_count("storyboards", 7)
	var report: Dictionary = probe.report()
	for field in ["input_ack_ms", "remix_ms", "scene_ms", "frame_p95_ms", "peak_nodes", "cache_counts"]:
		check(report.has(field), "runtime report owns " + field)
	check(float(report.get("frame_p95_ms", 0.0)) >= 20.0,
			"frame p95 is calculated from bounded samples")
	check(int(report.get("peak_nodes", 0)) == 42,
			"runtime report records peak presentation nodes")
	check(not probe.has_method("send") and not probe.has_method("upload"),
			"development telemetry has no network output")
	finish()


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS  ", label)
	else: failures += 1; print("FAIL  ", label)


func finish() -> void:
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
