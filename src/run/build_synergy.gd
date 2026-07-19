class_name BuildSynergy
extends RefCounted
## Evaluates named build identities from authored tags and reports exact deltas.

const RECIPES := [
	{"name":"Ember Cascade", "requires":{"fire":2},
		"effects":[{"stat":"red_damage", "op":"add", "value":6}]},
	{"name":"Verdant Bulwark", "requires":{"healing":2, "shield":1},
		"effects":[{"stat":"post_battle_heal", "op":"add", "value":5}]},
	{"name":"Venom Bloom", "requires":{"poison":2, "healing":1},
		"effects":[{"stat":"purple_damage", "op":"add", "value":2}]},
	{"name":"Chrono Fortress", "requires":{"shield":2, "control":1},
		"effects":[{"stat":"enemy_delay", "op":"add", "value":1}]},
	{"name":"Wild Crucible", "requires":{"wild":1, "fire":1},
		"effects":[{"stat":"combo_damage", "op":"multiply", "value":1.15}]},
]


func evaluate(build: Dictionary) -> Array[Dictionary]:
	var counts := {}
	for tag in _collect_tags(build): counts[str(tag)] = int(counts.get(str(tag), 0)) + 1
	var active: Array[Dictionary] = []
	for recipe in RECIPES:
		var matches := true
		for tag in recipe.requires:
			if int(counts.get(tag, 0)) < int(recipe.requires[tag]): matches = false; break
		if matches:
			active.append((recipe as Dictionary).duplicate(true))
	return active


func _collect_tags(build: Dictionary) -> Array:
	var tags: Array = build.get("tags", []).duplicate()
	var pools := {
		"relics": GameState.load_data_file("relics.json", {}),
		"mutations": GameState.load_data_file("mutations.json", {}),
		"catalysts": GameState.load_data_file("catalysts.json", {}),
		"upgrades": GameState.load_data_file("upgrades.json", {}),
	}
	for group in pools:
		for id in build.get(group, []):
			tags.append_array(pools[group].get(str(id), {}).get("tags", []))
	return tags
