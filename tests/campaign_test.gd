extends Node

var failures := 0
var checks := 0


func _ready() -> void:
	check(GameState.get("areas") is Dictionary, "game state exposes campaign areas")
	check(GameState.has_method("area"), "game state exposes area lookup")
	check(GameState.has_method("area_ids"), "game state exposes ordered area ids")
	if GameState.has_method("area_ids") and GameState.get("areas") is Dictionary:
		var ids: Array[String] = GameState.call("area_ids")
		check(ids == ["shadow_crypt", "verdant_catacombs", "astral_foundry"],
				"campaign has three ordered expeditions")
		var backgrounds := {}
		var previous_threat := 0.0
		for id in ids:
			var area: Dictionary = GameState.call("area", id)
			check(str(area.get("name", "")) != "", "area has name: " + id)
			check(GameState.enemies.has(str(area.get("boss", ""))), "area boss exists: " + id)
			var background := str(area.get("background", ""))
			check(not background.is_empty() and not backgrounds.has(background),
					"area background is distinct: " + id)
			backgrounds[background] = true
			var threat := float(area.get("threat_multiplier", 0.0))
			check(threat > previous_threat, "area threat increases: " + id)
			previous_threat = threat
			for pool_name in ["intro", "tier_1", "tier_2", "tier_3", "elite"]:
				var pool: Array = area.get("enemy_pools", {}).get(pool_name, [])
				check(not pool.is_empty(), "area pool exists: %s/%s" % [id, pool_name])
				for enemy_id in pool:
					check(GameState.enemies.has(str(enemy_id)),
							"area enemy exists: %s/%s" % [id, enemy_id])
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL  ", label)
