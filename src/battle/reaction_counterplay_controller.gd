class_name ReactionCounterplayController
extends RefCounted
## Applies only counterplay that is explicitly disclosed by the current intent/phase.

var _intent_rule: Dictionary = {}
var _phase_rule: Dictionary = {}


func configure(intent: Dictionary, phase: Dictionary) -> void:
	_intent_rule = (intent.get("reaction_counter", {}) as Dictionary).duplicate(true)
	_phase_rule = (phase.get("reaction_counter", {}) as Dictionary).duplicate(true)


func preview() -> Dictionary:
	var rule := _effective_rule()
	return {
		"counter_tag": str(rule.get("tag", "")),
		"result": str(rule.get("result", "")),
		"moves": maxi(int(rule.get("moves", 0)), 0),
		"label": str(rule.get("label", "")),
	}


func modify_reaction(result: Dictionary) -> Dictionary:
	var changed := result.duplicate(true)
	for rule in [_intent_rule, _phase_rule]:
		var required := str(rule.get("tag", ""))
		if required.is_empty() or required not in changed.get("tags", []): continue
		match str(rule.get("result", "")):
			"delay":
				changed["enemy_delay"] = int(changed.get("enemy_delay", 0)) \
						+ maxi(int(rule.get("moves", 0)), 0)
			"damage":
				changed["damage"] = int(changed.get("damage", 0)) \
						+ maxi(int(rule.get("damage", 0)), 0)
		changed["countered_intent"] = true
	return changed


func snapshot() -> Dictionary:
	return {"version": 1, "intent_rule": _intent_rule.duplicate(true),
			"phase_rule": _phase_rule.duplicate(true)}


func restore(data: Dictionary) -> bool:
	if int(data.get("version", 0)) != 1: return false
	_intent_rule = (data.get("intent_rule", {}) as Dictionary).duplicate(true)
	_phase_rule = (data.get("phase_rule", {}) as Dictionary).duplicate(true)
	return true


func _effective_rule() -> Dictionary:
	return _phase_rule if not _phase_rule.is_empty() else _intent_rule
