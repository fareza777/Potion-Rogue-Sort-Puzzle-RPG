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
	return {
		"version": 1,
		"format": format,
		"assistance_tier": assistance,
		"countdown_bonus": assistance,
		"board_band": maxi(0, floor / 2 - assistance),
		"reward_mult": 1.0 + reward_bonus,
		"waves": 2 if format == "multi_wave" else 1,
	}
