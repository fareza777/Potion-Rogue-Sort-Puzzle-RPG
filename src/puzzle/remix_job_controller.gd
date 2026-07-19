class_name RemixJobController
extends RefCounted
## Runs solver-backed mixes away from the render thread. Generation IDs make
## completion order irrelevant: only the latest request may be consumed.

const TIMEOUT_MS := 1000

var _generation_id := 0
var _latest_task := -1
var _started_msec := 0
var _tasks := {}
var _results := {}
var _result_mutex := Mutex.new()


func request(state: Array, seed: int, band: String, capacity: int) -> int:
	_generation_id += 1
	var request_id := _generation_id
	var immutable_state := state.duplicate(true)
	var task_id := WorkerThreadPool.add_task(func() -> void:
		var payload := {"generation_id":request_id,
				"result":BoardFactory.remix(immutable_state, seed, band, capacity)}
		_result_mutex.lock()
		_results[request_id] = payload
		_result_mutex.unlock())
	_tasks[request_id] = task_id
	_latest_task = task_id
	_started_msec = Time.get_ticks_msec()
	return request_id


func poll() -> Dictionary:
	_reap_completed_stale_tasks()
	if _latest_task < 0:
		return {}
	if WorkerThreadPool.is_task_completed(_latest_task):
		WorkerThreadPool.wait_for_task_completion(_latest_task)
		_result_mutex.lock()
		var payload: Dictionary = _results.get(_generation_id, {}).duplicate(true)
		_results.erase(_generation_id)
		_result_mutex.unlock()
		_tasks.erase(_generation_id)
		_latest_task = -1
		if int(payload.get("generation_id", -1)) != _generation_id:
			return {}
		payload["ready"] = true
		return payload
	if Time.get_ticks_msec() - _started_msec >= TIMEOUT_MS:
		var timed_out_id := _generation_id
		_latest_task = -1
		return {"ready":true, "generation_id":timed_out_id, "error":"timeout"}
	return {}


func cancel() -> void:
	_generation_id += 1
	_latest_task = -1


func is_busy() -> bool:
	return _latest_task >= 0


func _reap_completed_stale_tasks() -> void:
	for raw_id in _tasks.keys().duplicate():
		var request_id := int(raw_id)
		var task_id := int(_tasks[request_id])
		if request_id != _generation_id and WorkerThreadPool.is_task_completed(task_id):
			WorkerThreadPool.wait_for_task_completion(task_id)
			_result_mutex.lock()
			_results.erase(request_id)
			_result_mutex.unlock()
			_tasks.erase(request_id)
