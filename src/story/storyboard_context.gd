class_name StoryboardContext
extends RefCounted
## Converts authoritative run state into compact, presentation-only story data.


static func from_run(trigger: String, overrides := {}) -> Dictionary:
	var node: Dictionary = RunState.current_node() if RunState.active else {}
	var area: Dictionary = RunState.current_area() if RunState.active \
			else GameState.area("shadow_crypt")
	var battle: Dictionary = RunState.current_battle() if RunState.active else {}
	var enemy_id := str(overrides.get("enemy_id", battle.get("enemy", node.get("enemy", ""))))
	var enemy: Dictionary = GameState.enemies.get(enemy_id, {})
	var result := {
		"trigger":trigger,
		"seed":RunState.run_seed if RunState.active else 1,
		"node_id":RunState.current_node_id if RunState.active else "preview",
		"area_id":RunState.area_id if RunState.active else "shadow_crypt",
		"area_name":str(area.get("name", "Shadow Crypt")),
		"kit_id":RunState.kit_id if RunState.active else "ember_adept",
		"enemy_id":enemy_id,
		"enemy_name":str(enemy.get("name", enemy_id.replace("_", " ").capitalize())),
		"event_id":str(node.get("event_id", "")),
		"event_name":"",
		"kind":str(node.get("kind", battle.get("kind", "battle"))),
		"floor":int(node.get("floor", 0)) + 1,
		"hp_ratio":float(RunState.current_hp()) / float(maxi(RunState.max_hp(), 1))
				if RunState.active else 1.0,
		"story_flags":RunState.story_flags.duplicate(true) if RunState.active else {},
		"result_summary":"The choice has been applied.",
	}
	var event_data: Dictionary = GameState.load_data_file("events.json", {}).get(
			str(result.event_id), {})
	result.event_name = str(event_data.get("name",
			str(result.event_id).replace("_", " ").capitalize()))
	result.merge((overrides as Dictionary).duplicate(true), true)
	return result
