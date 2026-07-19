class_name FxPool
extends Node
## Hard presentation budget. Oldest transient visuals are retired first.

const MAX_ACTIVE := 48
var _active: Array[Node] = []


func track(effect: Node) -> Node:
	_prune()
	while _active.size() >= MAX_ACTIVE:
		var oldest: Node = _active.pop_front() as Node
		if is_instance_valid(oldest): oldest.queue_free()
	_active.append(effect)
	effect.tree_exited.connect(_forget.bind(effect), CONNECT_ONE_SHOT)
	return effect


func active_count() -> int:
	_prune()
	return _active.size()


func _forget(effect: Node) -> void:
	_active.erase(effect)


func _prune() -> void:
	_active = _active.filter(func(effect: Node): return is_instance_valid(effect) and not effect.is_queued_for_deletion())
