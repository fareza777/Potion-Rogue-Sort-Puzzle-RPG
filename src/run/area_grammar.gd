class_name AreaGrammar
extends RefCounted
## Normalizes legacy and five-realm campaign records for route generation.

const DEFAULT_RUN_LENGTH := 7


static func for_area(area_id: String) -> Dictionary:
	var area := GameState.area(area_id)
	var run_length := maxi(int(area.get("run_length", DEFAULT_RUN_LENGTH)), 2)
	area["run_length"] = run_length
	area["boss_depth"] = clampi(int(area.get("boss_depth", run_length)), 2, run_length)
	var miniboss_depths: Array[int] = []
	for depth in area.get("miniboss_depths", []):
		miniboss_depths.append(int(depth))
	area["miniboss_depths"] = miniboss_depths
	area["landmarks"] = (area.get("landmarks", []) as Array).duplicate()
	area["guaranteed_kinds"] = (area.get("guaranteed_kinds", {}) as Dictionary).duplicate(true)
	area["secret_branch_chance"] = clampf(float(area.get("secret_branch_chance", 0.0)), 0.0, 1.0)
	return area
