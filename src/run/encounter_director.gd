class_name EncounterDirector
extends RefCounted
## Builds one immutable, deterministic difficulty/format profile per combat node.

const ADVANCED_FORMATS: Array[String] = [
	"duel", "survival", "multi_wave", "protect_cauldron", "elite_contract"]


func build_profile(context: Dictionary, seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var floor := maxi(int(context.get("floor", 0)), 0)
	var kind := str(context.get("kind", "battle"))
	var hp_ratio := clampf(float(context.get("hp_ratio", 1.0)), 0.0, 1.0)
	var defeat_streak := maxi(int(context.get("early_defeat_streak", 0)), 0)
	var assistance := 0
	if hp_ratio < 0.45: assistance += 1
	if defeat_streak >= 2: assistance += 1
	assistance = mini(assistance, 2)
	var format := "duel"
	if kind == "boss":
		format = "duel"
	elif kind == "elite":
		format = "elite_contract"
	elif floor >= 3:
		var pool: Array[String] = ["duel", "survival", "multi_wave", "protect_cauldron"]
		format = pool[rng.randi_range(0, pool.size() - 1)]
	var reward_bonus := 0.15 if format in ["multi_wave", "protect_cauldron"] else 0.0
	var waves := 2 if format == "multi_wave" else 1
	var wave_enemy_ids := _wave_roster(context, rng, waves)
	return {
		"version": 1,
		"format": format,
		"assistance_tier": assistance,
		"countdown_bonus": assistance,
		"board_band": maxi(0, floor / 2 - assistance),
		"reward_mult": 1.0 + reward_bonus,
		"waves": waves,
		"wave_enemy_ids": wave_enemy_ids,
		"formation": "relay assault" if waves > 1 else "single guardian",
	}


func _wave_roster(context: Dictionary, rng: RandomNumberGenerator,
		waves: int) -> Array[String]:
	var area_id := str(context.get("area_id", "shadow_crypt"))
	var area: Dictionary = GameState.area(area_id)
	var floor := maxi(int(context.get("floor", 0)), 0)
	var kind := str(context.get("kind", "battle"))
	var pool_name := "elite" if kind == "elite" else (
			"intro" if floor <= 1 else "tier_1" if floor == 2 else
			"tier_2" if floor in [3, 4] else "tier_3")
	var raw_candidates: Array = area.get("enemy_pools", {}).get(pool_name, [])
	if raw_candidates.is_empty():
		raw_candidates = area.get("enemy_pools", {}).get("intro", ["slime"])
	var candidates: Array[String] = []
	for raw_id in raw_candidates:
		var id := str(raw_id)
		if GameState.enemies.has(id) and id not in candidates:
			candidates.append(id)
	var current := str(context.get("enemy_id", ""))
	if current.is_empty() or current not in candidates:
		current = candidates[0] if not candidates.is_empty() else "slime"
	var result: Array[String] = [current]
	candidates.erase(current)
	while result.size() < waves:
		if candidates.is_empty():
			result.append(current)
		else:
			var index := rng.randi_range(0, candidates.size() - 1)
			result.append(candidates.pop_at(index))
	return result
