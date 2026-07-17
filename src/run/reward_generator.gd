class_name RewardGenerator
extends RefCounted
## Deterministic, compatibility-biased reward drafting.

const FILES := {
	"mutation": "mutations.json",
	"relic": "relics.json",
	"catalyst": "catalysts.json",
	"upgrade": "upgrades.json",
}


func choices(kind: String, count: int, seed: int, build: Dictionary) -> Array[String]:
	var result: Array[String] = []
	if not FILES.has(kind) or count <= 0:
		return result
	var pool := GameState.load_data_file(FILES[kind], {})
	var owned: Array = build.get("owned", [])
	var build_tags: Array = build.get("tags", [])
	var weighted: Array[Dictionary] = []
	var neutral: Array[String] = []
	for raw_id in pool:
		var id := str(raw_id)
		var item: Dictionary = pool[raw_id]
		if id in owned and not bool(item.get("repeatable", false)):
			continue
		var compatible := false
		for tag in item.get("tags", []):
			if tag in build_tags:
				compatible = true
				break
		var weight := 3 if compatible else 1
		weighted.append({"id": id, "weight": weight, "neutral": not compatible})
		if not compatible:
			neutral.append(id)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	# Guarantee a discovery option instead of presenting only same-build rewards.
	if not neutral.is_empty() and count > 1:
		var neutral_id := neutral[rng.randi_range(0, neutral.size() - 1)]
		result.append(neutral_id)
		weighted = weighted.filter(func(entry: Dictionary) -> bool:
			return entry.id != neutral_id)
	while result.size() < count and not weighted.is_empty():
		var total := 0
		for entry in weighted:
			total += int(entry.weight)
		var roll := rng.randi_range(1, total)
		var cursor := 0
		for index in weighted.size():
			cursor += int(weighted[index].weight)
			if roll <= cursor:
				result.append(str(weighted[index].id))
				weighted.remove_at(index)
				break
	return result
