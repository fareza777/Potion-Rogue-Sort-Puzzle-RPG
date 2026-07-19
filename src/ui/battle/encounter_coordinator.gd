class_name EncounterCoordinator
extends RefCounted
## Owns the durable combat/puzzle boundary. Tactical modules may append their
## own snapshots, while these two state machines always restore atomically.

var _battle: Object
var _board: Object
var _entry: Dictionary = {}


func configure(battle: Object, board: Object, entry: Dictionary) -> void:
	_battle = battle
	_board = board
	_entry = entry.duplicate(true)


func snapshot() -> Dictionary:
	if _battle == null or _board == null:
		return {}
	return {"version": 1, "battle": _battle.export_snapshot(),
		"board": _board.export_snapshot(), "entry": _entry.duplicate(true)}


func restore(data: Dictionary) -> bool:
	if int(data.get("version", 0)) != 1 or _battle == null or _board == null:
		return false
	return bool(_battle.restore_snapshot(data.get("battle", {}))) \
			and bool(_board.restore_snapshot(data.get("board", {})))
