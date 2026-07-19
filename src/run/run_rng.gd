class_name RunRng
extends RefCounted
## Compact deterministic RNG whose complete future is one serializable integer.

const MASK := 0xffffffff
const RANGE := 4294967296.0
var _state := 1


func configure(seed: int, state := 0) -> void:
	_state = int(state) & MASK
	if _state == 0:
		_state = (seed ^ (seed >> 32) ^ 0x9e3779b9) & MASK
	if _state == 0: _state = 1


func snapshot() -> Dictionary:
	return {"version": 1, "state": _state}


func next_u32() -> int:
	var value := _state
	value = (value ^ ((value << 13) & MASK)) & MASK
	value = (value ^ (value >> 17)) & MASK
	value = (value ^ ((value << 5) & MASK)) & MASK
	_state = value if value != 0 else 1
	return _state


func randi_range(from: int, to: int) -> int:
	if to <= from: return from
	return from + next_u32() % (to - from + 1)


func randf() -> float:
	return float(next_u32()) / RANGE


func shuffled(values: Array) -> Array:
	var result := values.duplicate(true)
	for index in range(result.size() - 1, 0, -1):
		var other := self.randi_range(0, index)
		var held: Variant = result[index]
		result[index] = result[other]
		result[other] = held
	return result


func permute_serialized(values: Array) -> Array:
	var result := values.duplicate(true)
	for index in range(result.size() - 1, 0, -1):
		var other := self.randi_range(0, index)
		var held: Variant = result[index]
		result[index] = result[other]
		result[other] = held
	return result


func pick_weighted(entries: Array) -> Variant:
	var total := 0
	for entry in entries: total += maxi(int(entry.get("weight", 0)), 0)
	if total <= 0: return null
	var roll := self.randi_range(1, total)
	for entry in entries:
		roll -= maxi(int(entry.get("weight", 0)), 0)
		if roll <= 0: return entry.get("value", entry.get("id"))
	return null
