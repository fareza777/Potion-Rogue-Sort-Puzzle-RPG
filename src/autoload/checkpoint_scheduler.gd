class_name CheckpointScheduler
extends RefCounted
## Coalesces rapid battle snapshots so gameplay never waits on every move.
## A failed atomic write remains pending and can be retried at the next boundary.

const QUIET_WINDOW_MSEC := 250

var _writer: Callable
var _phase := ""
var _payload: Dictionary = {}
var _request_count := 0
var _deadline_msec := 0


func configure(writer: Callable) -> void:
	_writer = writer


func request(next_phase: String, payload: Dictionary) -> void:
	_phase = next_phase
	_payload = payload.duplicate(true)
	_request_count += 1
	_deadline_msec = Time.get_ticks_msec() + QUIET_WINDOW_MSEC


func pending_count() -> int:
	return _request_count


func is_due(now_msec := -1) -> bool:
	var now := Time.get_ticks_msec() if now_msec < 0 else now_msec
	return _request_count > 0 and now >= _deadline_msec


func flush(_reason := "manual") -> bool:
	if _request_count == 0:
		return true
	if not _writer.is_valid():
		return false
	if not bool(_writer.call(_phase, _payload)):
		return false
	_request_count = 0
	_phase = ""
	_payload = {}
	_deadline_msec = 0
	return true
