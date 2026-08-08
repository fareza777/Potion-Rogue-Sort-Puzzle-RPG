class_name EventResolver
extends RefCounted

var events := GameState.load_data_file("events.json", {})


func resolve_event_id(base_id: String, run: Node) -> String:
	var queued := str(run.get("pending_followup_event")) \
			if run != null and "pending_followup_event" in run else ""
	if not queued.is_empty() and events.has(queued):
		return queued
	return base_id if events.has(base_id) else "whispering_well"


func preview(event_id: String, choice_id: String) -> Dictionary:
	var choice := _choice(event_id, choice_id)
	if choice.is_empty(): return {"ok": false, "reason": "invalid_choice"}
	return {"ok": true, "cost": int(choice.get("cost", 0)),
		"effects": choice.get("effects", []).duplicate(true)}


func choice_summary(event_id: String, choice_id: String) -> String:
	var result := preview(event_id, choice_id)
	if not bool(result.get("ok", false)):
		return "Unavailable"
	var costs: Array[String] = []
	var gains: Array[String] = []
	if int(result.cost) > 0:
		costs.append("Cost: %d run crystals" % int(result.cost))
	for raw_effect in result.effects:
		var effect: Dictionary = raw_effect
		var value := int(effect.get("value", 0))
		match str(effect.get("op", "")):
			"heal": gains.append("Restore %d HP" % value)
			"heal_percent": gains.append("Restore %d%% max HP" % roundi(float(effect.get("value", 0.0)) * 100.0))
			"damage": costs.append("Lose: %d HP (cannot kill you)" % value)
			"crystals": gains.append("Gain: %d run crystals" % value)
			"cleanse": gains.append("Cleanse %d curse" % value)
			"curse": costs.append("Gain %d curse" % value)
			"add_mutation": gains.append("Gain: 1 random mutation")
			"add_relic": gains.append("Gain: 1 random relic")
			"add_catalyst": gains.append("Gain: 1 random catalyst")
			"set_story_flag": gains.append("Story: this decision will be remembered")
			"queue_followup": gains.append("Unlock: a future story encounter")
	var parts: Array[String] = []
	parts.append_array(costs)
	parts.append_array(gains)
	return "  •  ".join(parts) if not parts.is_empty() else "No mechanical effect"


func apply(event_id: String, choice_id: String, run: Node) -> Dictionary:
	var result := preview(event_id, choice_id)
	if not result.ok: return result
	var resolution_key := event_id + ":" + choice_id
	if resolution_key in run.resolved_event_ids:
		return {"ok": false, "reason": "already_resolved"}
	if int(result.cost) > run.run_crystals:
		return {"ok": false, "reason": "unaffordable"}
	run.run_crystals -= int(result.cost)
	if str(run.get("pending_followup_event")) == event_id:
		run.set("pending_followup_event", "")
	# "Withered Rest" and similar Ascension rules scale event healing down.
	var recovery_mult := AscensionRules.new().multiplier(int(run.run_ascension), "recovery_mult")
	for effect in result.effects:
		match str(effect.op):
			"heal": run.heal(roundi(int(effect.value) * recovery_mult))
			"heal_percent": run.heal(roundi(run.max_hp() * float(effect.value) * recovery_mult))
			"damage": run.player_hp = max(1, run.current_hp() - int(effect.value))
			"crystals": run.run_crystals += int(effect.value)
			"cleanse": run.cleanse_curse(int(effect.value))
			"curse": run.active_curses += int(effect.value)
			"add_mutation": run.add_mutation(_draft("mutation", run))
			"add_relic": run.add_relic(_draft("relic", run))
			"add_catalyst": run.add_catalyst(_draft("catalyst", run))
			"set_story_flag":
				var flags: Dictionary = run.get("story_flags").duplicate(true)
				flags[str(effect.get("key", "event_choice"))] = effect.get("value", true)
				run.set("story_flags", flags)
			"queue_followup":
				var followup := str(effect.get("value", ""))
				if events.has(followup):
					run.set("pending_followup_event", followup)
	run.resolved_event_ids.append(resolution_key)
	result["result_summary"] = choice_summary(event_id, choice_id)
	return result


func _draft(kind: String, run: Node) -> String:
	var ids := RewardGenerator.new().choices(kind, 1,
			run.run_seed + run.resolved_event_ids.size() * 31 + kind.hash(), run.reward_build())
	return "" if ids.is_empty() else ids[0]


func _choice(event_id: String, choice_id: String) -> Dictionary:
	return events.get(event_id, {}).get("choices", {}).get(choice_id, {})
