class_name RuntimeBudgetProbe
extends RefCounted
## Bounded local-only development telemetry. No network or persistent output.

const MAX_FRAME_SAMPLES := 240

var _started_usec: Dictionary = {}
var _durations_ms := {"input":0.0, "remix":0.0, "scene":0.0}
var _frame_samples: Array[float] = []
var _peak_nodes := 0
var _cache_counts: Dictionary = {}


func begin_input() -> void:
	_begin("input")


func end_input() -> float:
	return _end("input")


func begin_remix() -> void:
	_begin("remix")


func end_remix() -> float:
	return _end("remix")


func begin_scene() -> void:
	_begin("scene")


func end_scene() -> float:
	return _end("scene")


func record_frame(frame_ms: float, presentation_nodes: int) -> void:
	_frame_samples.append(maxf(frame_ms, 0.0))
	if _frame_samples.size() > MAX_FRAME_SAMPLES:
		_frame_samples.pop_front()
	_peak_nodes = maxi(_peak_nodes, presentation_nodes)


func set_cache_count(cache_name: String, count: int) -> void:
	_cache_counts[cache_name] = maxi(count, 0)


func report() -> Dictionary:
	return {
		"input_ack_ms":float(_durations_ms.input),
		"remix_ms":float(_durations_ms.remix),
		"scene_ms":float(_durations_ms.scene),
		"frame_p95_ms":_percentile_95(),
		"peak_nodes":_peak_nodes,
		"cache_counts":_cache_counts.duplicate(true),
	}


func reset() -> void:
	_started_usec.clear()
	_durations_ms = {"input":0.0, "remix":0.0, "scene":0.0}
	_frame_samples.clear()
	_peak_nodes = 0
	_cache_counts.clear()


func _begin(metric: String) -> void:
	_started_usec[metric] = Time.get_ticks_usec()


func _end(metric: String) -> float:
	if not _started_usec.has(metric):
		return float(_durations_ms.get(metric, 0.0))
	var elapsed := maxf(float(Time.get_ticks_usec() - int(_started_usec[metric])) / 1000.0, 0.0)
	_durations_ms[metric] = elapsed
	_started_usec.erase(metric)
	return elapsed


func _percentile_95() -> float:
	if _frame_samples.is_empty():
		return 0.0
	var sorted := _frame_samples.duplicate()
	sorted.sort()
	var index := clampi(int(ceil(float(sorted.size()) * 0.95)) - 1, 0, sorted.size() - 1)
	return float(sorted[index])
