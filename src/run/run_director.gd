class_name RunDirector
extends RefCounted
## Deterministic pacing policy applied after route topology is chosen.

const VERSION := 1
const NONCOMBAT := ["event", "event", "shop", "treasure", "campfire"]


func assign_kind(floor: int, slot: int, noncombat_slot: int,
		context: Dictionary, rng: RandomNumberGenerator) -> String:
	if slot == noncombat_slot:
		var pool := NONCOMBAT.duplicate()
		if float(context.get("hp_ratio", 1.0)) <= 0.35:
			pool.append_array(["campfire", "campfire"])
		return str(pool[rng.randi_range(0, pool.size() - 1)])
	var elite_chance := clampf(0.18 + float(context.get("power", 0.0)) * 0.01,
			0.18, 0.30)
	if floor >= 3 and rng.randf() < elite_chance:
		return "elite"
	return "battle"


func reveal_for(kind: String) -> String:
	return str({
		"start": "START",
		"battle": "BATTLE",
		"elite": "ELITE",
		"event": "EVENT",
		"shop": "SHOP",
		"treasure": "TREASURE",
		"campfire": "REST",
		"boss": "BOSS",
	}.get(kind, "UNCHARTED"))


func risk_for(floor: int, kind: String) -> int:
	return clampi(1 + floor / 2 + (1 if kind == "elite" else 0), 1, 4)

