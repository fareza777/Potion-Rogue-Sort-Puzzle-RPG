class_name EventResolver
extends RefCounted

var events := GameState.load_data_file("events.json", {})


func preview(event_id: String, choice_id: String) -> Dictionary:
	var choice := _choice(event_id, choice_id)
	if choice.is_empty(): return {"ok": false, "reason": "invalid_choice"}
	return {"ok": true, "cost": int(choice.get("cost", 0)),
		"effects": choice.get("effects", []).duplicate(true)}


func apply(event_id: String, choice_id: String, run: Node) -> Dictionary:
	var result := preview(event_id, choice_id)
	if not result.ok: return result
	var resolution_key := event_id + ":" + choice_id
	if resolution_key in run.resolved_event_ids:
		return {"ok": false, "reason": "already_resolved"}
	if int(result.cost) > run.run_crystals:
		return {"ok": false, "reason": "unaffordable"}
	run.run_crystals -= int(result.cost)
	for effect in result.effects:
		match str(effect.op):
			"heal": run.heal(int(effect.value))
			"heal_percent": run.heal(int(run.max_hp() * float(effect.value)))
			"damage": run.player_hp = max(1, run.current_hp() - int(effect.value))
			"crystals": run.run_crystals += int(effect.value)
			"cleanse": run.cleanse_curse(int(effect.value))
			"curse": run.active_curses += int(effect.value)
			"add_mutation": run.add_mutation(_draft("mutation", run))
			"add_relic": run.add_relic(_draft("relic", run))
			"add_catalyst": run.add_catalyst(_draft("catalyst", run))
	run.resolved_event_ids.append(resolution_key)
	return result


func _draft(kind: String, run: Node) -> String:
	var ids := RewardGenerator.new().choices(kind, 1,
			run.run_seed + run.resolved_event_ids.size() * 31 + kind.hash(), run.reward_build())
	return "" if ids.is_empty() else ids[0]


func _choice(event_id: String, choice_id: String) -> Dictionary:
	return events.get(event_id, {}).get("choices", {}).get(choice_id, {})
