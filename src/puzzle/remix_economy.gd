class_name RemixEconomy
extends RefCounted
## Fair remix pricing. Recovery from an unfinishable board is never paywalled.

const REPEAT_MANA_COST := 20
var mix_count := 0


func quote(integrity_status: String, used_count: int, available_mana: int) -> Dictionary:
	var emergency := integrity_status != "valid"
	var mana_cost := 0 if emergency or used_count == 0 else REPEAT_MANA_COST
	return {"allowed": emergency or available_mana >= mana_cost,
			"emergency": emergency, "move_cost": 1, "mana_cost": mana_cost}


func commit(_quote: Dictionary) -> void:
	mix_count += 1


func snapshot() -> Dictionary:
	return {"mix_count": mix_count}


func restore(data: Dictionary) -> void:
	mix_count = maxi(int(data.get("mix_count", 0)), 0)
