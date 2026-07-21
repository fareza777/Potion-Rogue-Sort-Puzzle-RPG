class_name ReactionEffectExecutor
extends RefCounted
## Applies one already-resolved formula. It never mutates the puzzle board and
## never emits another essence, so reaction chains cannot recurse for free.


func apply(result: Dictionary, battle: BattleManager) -> Dictionary:
	if battle == null or battle.battle_over:
		return {"ok":false, "reason":"battle_inactive"}
	var formula_id := str(result.get("id", "reaction"))
	match str(result.get("effect", "")):
		"damage_multiplier":
			var base := int(RunState.stat("red_damage",
					float(GameState.potions.get("red", {}).get("damage", 20))))
			var bonus := maxi(roundi(float(base) *
					(maxf(float(result.get("value", 1.0)), 1.0) - 1.0)), 0)
			return _damage_result(battle, bonus, formula_id)
		"heal_and_shield":
			return _sustain_result(battle, int(result.get("heal", 0)),
					int(result.get("shield", 0)), formula_id)
		"shield_to_damage":
			var converted := battle.convert_shield_to_damage(
					clampf(float(result.get("ratio", 0.5)), 0.0, 1.0))
			return {"ok":true, "id":formula_id, "damage":converted,
					"summary":"%d reflected damage" % converted}
		"consume_poison":
			var burst := battle.consume_enemy_poison()
			return {"ok":true, "id":formula_id, "damage":burst,
					"summary":"%d poison damage detonated" % burst}
		"burning_poison":
			var added := battle.empower_enemy_poison(int(result.get("value", 0)))
			return {"ok":true, "id":formula_id, "poison":added,
					"summary":"Poison strengthened by %d" % added}
		"fortify":
			var ward := battle.grant_player_shield(6)
			battle.set_reaction_reflect(float(result.get("reflect", 0.0)))
			return {"ok":true, "id":formula_id, "shield":ward,
					"summary":"+%d shield, next block reflects" % ward}
		"regeneration":
			battle.set_reaction_regeneration(4, int(result.get("turns", 0)))
			return {"ok":true, "id":formula_id,
					"summary":"Regenerate 4 HP for %d turns" % int(result.get("turns", 0))}
		"venom_ward":
			battle.set_reaction_retaliation(int(result.get("damage", 0)))
			return {"ok":true, "id":formula_id,
					"summary":"Next enemy attack takes %d damage" % int(result.get("damage", 0))}
		"ultimate_inferno":
			var poison_burst := battle.consume_enemy_poison()
			var direct := battle.deal_reaction_damage(int(result.get("damage", 24)), true)
			return {"ok":true, "id":formula_id, "damage":poison_burst + direct,
					"summary":"Inferno erupts for %d" % (poison_burst + direct)}
		"ultimate_sanctuary":
			var sustain := _sustain_result(battle, int(result.get("heal", 12)),
					int(result.get("shield", 16)), formula_id)
			battle.delay_enemy_attack(1)
			sustain["summary"] = str(sustain.summary) + ", attack delayed"
			return sustain
		"ultimate_plague":
			battle.empower_enemy_poison(int(result.get("damage", 5)))
			var nova := battle.trigger_poison_tick()
			return {"ok":true, "id":formula_id, "damage":nova,
					"summary":"Plague Nova deals %d" % nova}
		_:
			push_warning("Unknown reaction effect: " + str(result.get("effect", "")))
			return {"ok":false, "id":formula_id, "reason":"unknown_effect"}


func _damage_result(battle: BattleManager, damage: int, formula_id: String) -> Dictionary:
	var dealt := battle.deal_reaction_damage(maxi(damage, 0))
	return {"ok":true, "id":formula_id, "damage":dealt,
			"summary":"+%d reaction damage" % dealt}


func _sustain_result(battle: BattleManager, heal: int, shield: int,
		formula_id: String) -> Dictionary:
	var restored := battle.restore_player_hp(maxi(heal, 0))
	var ward := battle.grant_player_shield(maxi(shield, 0))
	return {"ok":true, "id":formula_id, "heal":restored, "shield":ward,
			"summary":"+%d HP, +%d shield" % [restored, ward]}
