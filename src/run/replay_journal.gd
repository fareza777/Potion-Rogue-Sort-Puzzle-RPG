class_name ReplayJournal
extends RefCounted
## Compact deterministic action trail used for diagnostics and local replay.

const LIMIT := 300

var _events: Array[Dictionary] = []


func record(kind: String, payload := {}) -> void:
	_events.append({"kind":kind, "payload":(payload as Dictionary).duplicate(true)})
	if _events.size() > LIMIT:
		_events.pop_front()


func checksum() -> int:
	return JSON.stringify(_events).hash()


func snapshot() -> Dictionary:
	return {"version":1, "events":_events.duplicate(true), "checksum":checksum()}


func restore(data: Dictionary) -> bool:
	if int(data.get("version", 0)) != 1 or typeof(data.get("events")) != TYPE_ARRAY:
		return false
	var candidate: Array = data.get("events", []).duplicate(true)
	if candidate.size() > LIMIT:
		return false
	_events.clear()
	for raw_event in candidate:
		if typeof(raw_event) != TYPE_DICTIONARY:
			_events.clear()
			return false
		_events.append((raw_event as Dictionary).duplicate(true))
	if checksum() != int(data.get("checksum", checksum())):
		_events.clear()
		return false
	return true


func clear() -> void:
	_events.clear()
