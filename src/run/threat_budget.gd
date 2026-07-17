class_name ThreatBudget
extends RefCounted


func for_node(floor: int, kind: String) -> Dictionary:
	var tier := "intro" if floor <= 2 else "advanced"
	var modifier_count := 0
	if kind == "battle": modifier_count = 1
	elif kind == "elite": modifier_count = 2
	return {
		"tier": tier,
		"modifier_count": modifier_count,
		"enemy_scale": 1.0 + max(0, floor - 1) * 0.12 + (0.22 if kind == "elite" else 0.0),
	}
