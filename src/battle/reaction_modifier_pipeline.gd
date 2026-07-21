class_name ReactionModifierPipeline
extends RefCounted
## Deterministic reaction hooks. Hook order is part of the save/replay contract.

const ORDER: Array[String] = ["kit", "relic", "catalyst", "mutation"]

var _hooks := {}
var _consumed_limits := {}


func configure(kit_id: String, relic_ids: Array, catalyst_ids: Array,
		mutation_ids: Array) -> void:
	_hooks = {"kit":[], "relic":[], "catalyst":[], "mutation":[]}
	_append_hooks("kit", kit_id, GameState.kits.get(kit_id, {}))
	var pools := {
		"relic": GameState.load_data_file("relics.json", {}),
		"catalyst": GameState.load_data_file("catalysts.json", {}),
		"mutation": GameState.load_data_file("mutations.json", {}),
	}
	for id in relic_ids:
		_append_hooks("relic", str(id), pools.relic.get(str(id), {}))
	for id in catalyst_ids:
		_append_hooks("catalyst", str(id), pools.catalyst.get(str(id), {}))
	for id in mutation_ids:
		_append_hooks("mutation", str(id), pools.mutation.get(str(id), {}))


func transform_essence(color: String) -> String:
	for source in ORDER:
		for hook in _hooks.get(source, []):
			if str(hook.get("trigger", "")) != "transform_essence":
				continue
			if str(hook.get("from", "")) != color or not _can_use(hook):
				continue
			_consume(hook)
			return str(hook.get("to", color))
	return color


func modify_result(result: Dictionary) -> Dictionary:
	var changed := result.duplicate(true)
	var tags: Array = changed.get("tags", [])
	var power := 1.0
	var charge_add := 0
	var charge_mult := 1.0
	var bonus_damage := 0
	var bonus_heal := 0
	var bonus_shield := 0
	var enemy_delay := 0
	var hp_cost := 0
	for source in ORDER:
		for hook in _hooks.get(source, []):
			if str(hook.get("trigger", "")) != "modify_reaction":
				continue
			var required_tag := str(hook.get("tag", ""))
			if not required_tag.is_empty() and not required_tag in tags:
				continue
			power *= maxf(float(hook.get("power_mult", 1.0)), 0.0)
			charge_add += int(hook.get("charge_add", 0))
			charge_mult *= maxf(float(hook.get("charge_mult", 1.0)), 0.0)
			bonus_damage += int(hook.get("damage_add", 0))
			bonus_heal += int(hook.get("heal_add", 0))
			bonus_shield += int(hook.get("shield_add", 0))
			enemy_delay += int(hook.get("enemy_delay", 0))
			hp_cost += int(hook.get("hp_cost", 0))
	changed["reaction_power"] = power
	if changed.has("damage"):
		changed["damage"] = maxi(roundi(float(changed.damage) * power) + bonus_damage, 0)
	elif str(changed.get("effect", "")) == "damage_multiplier":
		changed["value"] = 1.0 + maxf(float(changed.get("value", 1.0)) - 1.0, 0.0) * power
	if changed.has("heal"):
		changed["heal"] = maxi(roundi(float(changed.heal) * power) + bonus_heal, 0)
	elif bonus_heal > 0:
		changed["bonus_heal"] = bonus_heal
	if changed.has("shield"):
		changed["shield"] = maxi(roundi(float(changed.shield) * power) + bonus_shield, 0)
	elif bonus_shield > 0:
		changed["bonus_shield"] = bonus_shield
	changed["charge"] = maxi(roundi(float(int(changed.get("charge", 0))
			+ charge_add) * charge_mult), 0)
	if enemy_delay > 0: changed["enemy_delay"] = enemy_delay
	if hp_cost > 0: changed["hp_cost"] = hp_cost
	return changed


func snapshot() -> Dictionary:
	return {"consumed_limits":_consumed_limits.duplicate(true)}


func restore(data: Dictionary) -> bool:
	var raw: Variant = data.get("consumed_limits", {})
	if typeof(raw) != TYPE_DICTIONARY:
		return false
	var restored := {}
	for key in raw:
		var value := int(raw[key])
		if value < 0: return false
		restored[str(key)] = value
	_consumed_limits = restored
	return true


func _append_hooks(source: String, owner_id: String, config: Dictionary) -> void:
	for index in (config.get("reaction_hooks", []) as Array).size():
		var hook: Dictionary = config.reaction_hooks[index].duplicate(true)
		hook["_key"] = source + ":" + owner_id + ":" + str(index)
		(_hooks[source] as Array).append(hook)


func _can_use(hook: Dictionary) -> bool:
	var limit := int(hook.get("limit", 0))
	return limit <= 0 or int(_consumed_limits.get(str(hook._key), 0)) < limit


func _consume(hook: Dictionary) -> void:
	var key := str(hook._key)
	_consumed_limits[key] = int(_consumed_limits.get(key, 0)) + 1
