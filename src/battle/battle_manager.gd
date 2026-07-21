class_name BattleManager
extends Node
## Pure battle logic: player/enemy stats, move counter, enemy turns, potion
## effects, status effects, enemy abilities (armor, crit, tube locks, enrage,
## player poison) and potion combos. All tunable values come from JSON data
## modified by the run's upgrades (RunState.stat). No UI code here.

signal stats_changed
signal potion_activated(color: String, text: String)
signal combo_triggered(text: String)
signal enemy_damaged(amount: int)
signal enemy_attacked(damage: int, blocked: int, crit: bool)
signal armor_changed(delta: int)
signal enemy_action_resolved(intent_id: String)
signal board_hazard_requested(command: Dictionary)
signal enemy_enraged
signal poison_ticked(damage: int)
signal player_poison_ticked(damage: int)
signal tube_lock_requested(moves: int)
signal last_remedy_triggered(heal: int)
signal battle_won
signal battle_lost

var player_hp := 0
var player_max_hp := 0
var shield := 0
var max_shield := 0

var enemy_id := ""
var enemy_name := ""
var enemy_shape := "slime"
var enemy_color := "6fce4e"
var enemy_hp := 0
var enemy_max_hp := 0
var enemy_armor := 0
var enemy_attack := 0
var attack_every := 3
var moves_until_attack := 3
var intent_controller: EnemyIntentController
var intent_board: PuzzleBoard
var crystals_reward := 5

var _enemy_crit_chance := 0.0
var _lock_every_attacks := 0
var _lock_moves := 2
var _poison_player_cfg: Dictionary = {}
var _enrage_cfg: Dictionary = {}
var _attacks_done := 0
var enraged := false

# Poison on the enemy (from purple potions)
var poison_damage := 0
var poison_turns := 0
# Poison on the player (from Poison Beast)
var player_poison_damage := 0
var player_poison_turns := 0
var reaction_reflect_ratio := 0.0
var reaction_regen_amount := 0
var reaction_regen_turns := 0
var reaction_retaliation_damage := 0

var _last_remedy_used := false
var battle_over := false


func setup(new_enemy_id: String) -> void:
	var p: Dictionary = GameState.player
	player_max_hp = int(RunState.stat("max_hp", float(p.get("max_hp", 50))))
	if RunState.active and RunState.player_hp > 0:
		player_hp = mini(RunState.player_hp, player_max_hp)
	else:
		player_hp = player_max_hp
	max_shield = int(RunState.stat("max_shield", float(p.get("max_shield", 30))))
	shield = int(RunState.stat("start_shield", 0.0))

	enemy_id = new_enemy_id
	var e: Dictionary = GameState.enemies.get(
			new_enemy_id, GameState.DEFAULT_ENEMIES["slime"])
	enemy_name = str(e.get("name", "Slime"))
	enemy_shape = str(e.get("shape", "slime"))
	enemy_color = str(e.get("color", "6fce4e"))
	var threat_scale := maxf(float(RunState.current_contract().get("threat", {}).get(
			"enemy_scale", 1.0)), 0.5)
	# Authored Ascension rules (data/ascension_rules.json) apply on top of the
	# generic threat curve so each ladder level changes real decisions.
	var ascension := AscensionRules.new().active(RunState.run_ascension)
	var kind := str(RunState.current_battle().get("kind", "battle"))
	enemy_max_hp = roundi(float(e.get("hp", 60)) * threat_scale \
			* float(ascension.enemy_hp_mult))
	enemy_hp = enemy_max_hp
	enemy_armor = roundi(float(e.get("armor", 0)) * float(ascension.enemy_armor_mult))
	# Damage rises more gently than vitality so later realms require stronger
	# builds without turning a single unlucky enemy action into a run killer.
	var damage_scale := 1.0 + (threat_scale - 1.0) * 0.35
	enemy_attack = roundi(float(e.get("attack", 8)) * damage_scale) \
			+ int(ascension.enemy_damage_add) \
			+ (int(ascension.boss_damage_add) if kind == "boss" else 0)
	attack_every = int(e.get("attack_every", 3)) + int(RunState.stat("enemy_delay", 0.0)) \
			+ (1 if bool(SaveSystem.setting("assist_mode")) else 0) \
			+ int(RunState.ensure_current_encounter_profile().get("countdown_bonus", 0)) \
			+ (int(ascension.elite_delay_add) if kind == "elite" else 0)
	attack_every = maxi(attack_every, 1)
	moves_until_attack = attack_every
	crystals_reward = int(e.get("crystals", 5))
	crystals_reward = roundi(float(crystals_reward) * float(
			RunState.current_contract().get("profile", {}).get("reward_mult", 1.0)))

	_enemy_crit_chance = float(e.get("crit_chance", 0.0))
	_lock_every_attacks = int(e.get("lock_every_attacks", 0))
	_lock_moves = int(e.get("lock_moves", 2))
	_poison_player_cfg = e.get("poison_player", {})
	_enrage_cfg = e.get("enrage", {})
	_attacks_done = 0
	enraged = false

	poison_damage = 0
	poison_turns = 0
	player_poison_damage = 0
	player_poison_turns = 0
	reaction_reflect_ratio = 0.0
	reaction_regen_amount = 0
	reaction_regen_turns = 0
	reaction_retaliation_damage = 0
	_last_remedy_used = false
	battle_over = false
	stats_changed.emit()


func setup_next_wave(wave_number: int) -> void:
	var carried_hp := player_hp
	var carried_shield := shield
	var carried_max_hp := player_max_hp
	var carried_max_shield := max_shield
	setup(enemy_id)
	player_max_hp = carried_max_hp
	player_hp = clampi(carried_hp, 1, player_max_hp)
	max_shield = carried_max_shield
	shield = clampi(carried_shield, 0, max_shield)
	var scale := 1.0 + 0.12 * float(maxi(wave_number - 1, 0))
	enemy_max_hp = roundi(float(enemy_max_hp) * scale)
	enemy_hp = enemy_max_hp
	enemy_attack = roundi(float(enemy_attack) * (1.0 + (scale - 1.0) * 0.5))
	enemy_name += "  •  WAVE %d" % wave_number
	stats_changed.emit()


func complete_by_objective() -> void:
	if battle_over: return
	enemy_hp = 0
	battle_over = true
	stats_changed.emit()
	battle_won.emit()


func fail_by_objective() -> void:
	if battle_over: return
	player_hp = 0
	battle_over = true
	stats_changed.emit()
	battle_lost.emit()


func undos_allowed() -> int:
	var mastery_bonus := 0
	if RunState.run_mode in ["normal", "rematch"]:
		mastery_bonus = int(MetaProgression.new().mastery_perks(
				RunState.area_id).get("extra_undos", 0))
	return int(RunState.stat("extra_undos",
			float(GameState.player.get("undos_per_battle", 3)))) + mastery_bonus


func export_snapshot() -> Dictionary:
	return {
		"version": 1,
		"enemy_id": enemy_id,
		"player_hp": player_hp,
		"player_max_hp": player_max_hp,
		"shield": shield,
		"max_shield": max_shield,
		"enemy_hp": enemy_hp,
		"enemy_max_hp": enemy_max_hp,
		"enemy_armor": enemy_armor,
		"enemy_attack": enemy_attack,
		"attack_every": attack_every,
		"moves_until_attack": moves_until_attack,
		"crystals_reward": crystals_reward,
		"poison_damage": poison_damage,
		"poison_turns": poison_turns,
		"player_poison_damage": player_poison_damage,
		"player_poison_turns": player_poison_turns,
		"last_potion": "",
		"reaction_reflect_ratio": reaction_reflect_ratio,
		"reaction_regen_amount": reaction_regen_amount,
		"reaction_regen_turns": reaction_regen_turns,
		"reaction_retaliation_damage": reaction_retaliation_damage,
		"last_remedy_used": _last_remedy_used,
		"attacks_done": _attacks_done,
		"enraged": enraged,
	}


func restore_snapshot(snapshot: Dictionary) -> bool:
	if int(snapshot.get("version", 0)) != 1 or str(snapshot.get("enemy_id", "")) != enemy_id:
		return false
	player_max_hp = maxi(int(snapshot.get("player_max_hp", player_max_hp)), 1)
	player_hp = clampi(int(snapshot.get("player_hp", player_hp)), 0, player_max_hp)
	max_shield = maxi(int(snapshot.get("max_shield", max_shield)), 0)
	shield = clampi(int(snapshot.get("shield", shield)), 0, max_shield)
	enemy_max_hp = maxi(int(snapshot.get("enemy_max_hp", enemy_max_hp)), 1)
	enemy_hp = clampi(int(snapshot.get("enemy_hp", enemy_hp)), 0, enemy_max_hp)
	enemy_armor = maxi(int(snapshot.get("enemy_armor", enemy_armor)), 0)
	enemy_attack = maxi(int(snapshot.get("enemy_attack", enemy_attack)), 1)
	attack_every = maxi(int(snapshot.get("attack_every", attack_every)), 1)
	moves_until_attack = clampi(int(snapshot.get("moves_until_attack", moves_until_attack)), 0, attack_every)
	crystals_reward = maxi(int(snapshot.get("crystals_reward", crystals_reward)), 0)
	poison_damage = maxi(int(snapshot.get("poison_damage", 0)), 0)
	poison_turns = maxi(int(snapshot.get("poison_turns", 0)), 0)
	player_poison_damage = maxi(int(snapshot.get("player_poison_damage", 0)), 0)
	player_poison_turns = maxi(int(snapshot.get("player_poison_turns", 0)), 0)
	reaction_reflect_ratio = clampf(float(snapshot.get("reaction_reflect_ratio", 0.0)), 0.0, 1.0)
	reaction_regen_amount = maxi(int(snapshot.get("reaction_regen_amount", 0)), 0)
	reaction_regen_turns = maxi(int(snapshot.get("reaction_regen_turns", 0)), 0)
	reaction_retaliation_damage = maxi(int(snapshot.get("reaction_retaliation_damage", 0)), 0)
	_last_remedy_used = bool(snapshot.get("last_remedy_used", false))
	_attacks_done = maxi(int(snapshot.get("attacks_done", 0)), 0)
	enraged = bool(snapshot.get("enraged", false))
	battle_over = false
	stats_changed.emit()
	return true


## Called for every liquid pour the player makes.
func on_move() -> void:
	if battle_over:
		return
	moves_until_attack -= 1
	if moves_until_attack <= 0:
		_enemy_turn()
	stats_changed.emit()


## Undo refunds the move on the enemy attack counter (capped at the full interval).
func on_undo() -> void:
	if battle_over:
		return
	moves_until_attack = mini(moves_until_attack + 1, attack_every)
	stats_changed.emit()


## Called when the player completes a tube of the given color.
func on_potion_completed(color: String) -> void:
	if battle_over:
		return
	var data: Dictionary = GameState.potions.get(color, {})
	match color:
		"red":
			_activate_fire(data)
		"green":
			var heal := int(RunState.stat("green_heal", float(data.get("heal", 15))))
			var healed: int = mini(heal, player_max_hp - player_hp)
			player_hp += healed
			potion_activated.emit(color, "Healing Potion  +%d HP" % healed)
		"blue":
			var amount := int(RunState.stat("blue_shield", float(data.get("shield", 12))))
			shield = mini(shield + amount, max_shield)
			potion_activated.emit(color, "Shield Potion  +%d shield" % amount)
		"purple":
			# Re-applying poison refreshes the duration (no stacking in MVP).
			poison_damage = int(RunState.stat("purple_damage",
					float(data.get("poison_damage", 5))))
			poison_turns = int(RunState.stat("purple_turns",
					float(data.get("poison_turns", 3))))
			potion_activated.emit(color, "Poison!  %d dmg / %d turns"
					% [poison_damage, poison_turns])
		_:
			push_warning("Unknown potion color: " + color)
	stats_changed.emit()
	_check_victory()


func _activate_fire(data: Dictionary) -> void:
	var damage := int(RunState.stat("red_damage", float(data.get("damage", 20))))
	var notes: Array[String] = []

	if randf() < RunState.stat("crit_chance", 0.0):
		damage *= 2
		notes.append("CRITICAL!")
	var dealt := _damage_enemy(damage, false)
	var text := "Fire Potion  %d damage" % dealt
	if not notes.is_empty():
		text = " ".join(notes) + " " + text
	potion_activated.emit("red", text)


## Applies damage to the enemy; armor absorbs first unless bypassed (poison).
## Returns the total amount applied (armor + HP).
func _damage_enemy(amount: int, bypass_armor: bool) -> int:
	var remaining := amount
	if not bypass_armor and enemy_armor > 0:
		var absorbed: int = mini(enemy_armor, remaining)
		enemy_armor -= absorbed
		remaining -= absorbed
		if absorbed > 0:
			armor_changed.emit(-absorbed)
	enemy_hp = maxi(enemy_hp - remaining, 0)
	enemy_damaged.emit(amount)
	_check_enrage()
	return amount


func _check_enrage() -> void:
	if enraged or _enrage_cfg.is_empty() or enemy_hp <= 0:
		return
	var threshold := float(_enrage_cfg.get("threshold", 0.4))
	if float(enemy_hp) / float(enemy_max_hp) <= threshold:
		enraged = true
		enemy_attack = int(enemy_attack * float(_enrage_cfg.get("attack_mult", 1.5)))
		enemy_enraged.emit()


func _enemy_turn() -> void:
	moves_until_attack = attack_every
	if reaction_regen_turns > 0:
		restore_player_hp(reaction_regen_amount)
		reaction_regen_turns -= 1
		if reaction_regen_turns == 0:
			reaction_regen_amount = 0

	# Status effects tick first: poison can kill the enemy before it attacks.
	if poison_turns > 0:
		_damage_enemy(poison_damage, true)
		poison_turns -= 1
		poison_ticked.emit(poison_damage)
		if poison_turns == 0:
			poison_damage = 0
		if _check_victory():
			return

	if player_poison_turns > 0:
		player_hp = maxi(player_hp - player_poison_damage, 0)
		player_poison_turns -= 1
		player_poison_ticked.emit(player_poison_damage)
		if player_poison_turns == 0:
			player_poison_damage = 0
		if _check_defeat():
			return
		_try_last_remedy()

	if intent_controller != null:
		intent_controller.set_battle_values(enemy_attack, _enemy_crit_chance, attack_every)
		intent_controller.resolve(self, intent_board)
		intent_controller.advance()
	else:
		resolve_enemy_attack()
	if battle_over:
		return

	# Post-attack abilities
	if _lock_every_attacks > 0 and _attacks_done % _lock_every_attacks == 0:
		tube_lock_requested.emit(_lock_moves)
	if not _poison_player_cfg.is_empty():
		var every := int(_poison_player_cfg.get("every_attacks", 2))
		if every > 0 and _attacks_done % every == 0:
			player_poison_damage = int(_poison_player_cfg.get("damage", 3))
			player_poison_turns = int(_poison_player_cfg.get("turns", 2))
			player_poison_ticked.emit(0)


func resolve_enemy_attack(multiplier := 1.0) -> Dictionary:
	if battle_over:
		return {}
	var damage := int(enemy_attack * maxf(multiplier, 0.0))
	var crit := false
	if randf() < _enemy_crit_chance:
		damage = int(damage * 1.5)
		crit = true
	damage = maxi(damage - int(RunState.stat("damage_reduction", 0.0)), 1)
	var blocked: int = mini(shield, damage)
	shield -= blocked
	player_hp = maxi(player_hp - (damage - blocked), 0)
	enemy_attacked.emit(damage, blocked, crit)
	if blocked > 0 and reaction_reflect_ratio > 0.0:
		_damage_enemy(maxi(roundi(float(blocked) * reaction_reflect_ratio), 1), true)
		reaction_reflect_ratio = 0.0
	if reaction_retaliation_damage > 0:
		_damage_enemy(reaction_retaliation_damage, true)
		reaction_retaliation_damage = 0
	_attacks_done += 1
	if _check_victory():
		return {"damage": damage, "blocked": blocked, "crit": crit}
	_check_defeat()
	_try_last_remedy()
	stats_changed.emit()
	return {"damage": damage, "blocked": blocked, "crit": crit}


func add_enemy_armor(amount: int) -> void:
	var applied := maxi(amount, 0)
	enemy_armor += applied
	armor_changed.emit(applied)
	stats_changed.emit()


func break_enemy_armor(amount: int) -> int:
	var removed := mini(enemy_armor, maxi(amount, 0))
	if removed > 0:
		enemy_armor -= removed
		armor_changed.emit(-removed)
		stats_changed.emit()
	return removed


func request_tube_lock(moves: int) -> void:
	tube_lock_requested.emit(maxi(moves, 1))


func apply_player_poison(damage: int, turns: int) -> void:
	player_poison_damage = maxi(damage, 0)
	player_poison_turns = maxi(turns, 0)
	player_poison_ticked.emit(0)
	stats_changed.emit()


func request_board_hazard(command: Dictionary) -> void:
	board_hazard_requested.emit(command.duplicate(true))


func empower_enemy_attack(multiplier: float) -> void:
	enemy_attack = maxi(int(ceil(enemy_attack * maxf(multiplier, 1.0))), 1)
	enemy_enraged.emit()
	stats_changed.emit()


func heal_enemy(amount: int) -> int:
	var healed := mini(maxi(amount, 0), enemy_max_hp - enemy_hp)
	enemy_hp += healed; stats_changed.emit(); return healed


func shatter_player_shield(amount: int) -> int:
	var removed := mini(shield, maxi(amount, 0))
	shield -= removed; stats_changed.emit(); return removed


func complete_enemy_action(intent_id: String) -> void:
	enemy_action_resolved.emit(intent_id)


func deal_skill_damage(amount: int) -> int:
	if battle_over: return 0
	var dealt := _damage_enemy(maxi(amount, 0), false)
	stats_changed.emit()
	_check_victory()
	return dealt


func deal_reaction_damage(amount: int, bypass_armor := false) -> int:
	if battle_over: return 0
	var dealt := _damage_enemy(maxi(amount, 0), bypass_armor)
	stats_changed.emit()
	_check_victory()
	return dealt


func restore_player_hp(amount: int) -> int:
	if battle_over: return 0
	var restored := mini(maxi(amount, 0), player_max_hp - player_hp)
	player_hp += restored
	stats_changed.emit()
	return restored


func grant_player_shield(amount: int) -> int:
	if battle_over: return 0
	var granted := mini(maxi(amount, 0), max_shield - shield)
	shield += granted
	stats_changed.emit()
	return granted


func convert_shield_to_damage(ratio: float) -> int:
	var converted := mini(shield, maxi(roundi(float(shield) *
			clampf(ratio, 0.0, 1.0)), 0))
	shield -= converted
	return deal_reaction_damage(converted)


func consume_enemy_poison() -> int:
	if battle_over: return 0
	var burst := poison_damage * poison_turns
	poison_damage = 0
	poison_turns = 0
	return deal_reaction_damage(burst, true)


func empower_enemy_poison(amount: int) -> int:
	if poison_turns <= 0:
		return 0
	var added := maxi(amount, 0)
	poison_damage += added
	stats_changed.emit()
	return added


func trigger_poison_tick() -> int:
	if poison_turns <= 0: return 0
	return deal_reaction_damage(poison_damage, true)


func set_reaction_reflect(ratio: float) -> void:
	reaction_reflect_ratio = clampf(ratio, 0.0, 1.0)
	stats_changed.emit()


func set_reaction_regeneration(amount: int, turns: int) -> void:
	reaction_regen_amount = maxi(amount, 0)
	reaction_regen_turns = maxi(turns, 0)
	stats_changed.emit()


func set_reaction_retaliation(amount: int) -> void:
	reaction_retaliation_damage = maxi(amount, 0)
	stats_changed.emit()


func delay_enemy_attack(moves: int) -> void:
	moves_until_attack = mini(moves_until_attack + maxi(moves, 0), attack_every + 2)
	stats_changed.emit()


## Last Remedy upgrade: once per battle, dropping below 20% HP auto-heals.
func _try_last_remedy() -> void:
	if _last_remedy_used or player_hp <= 0:
		return
	var heal := int(RunState.stat("last_remedy", 0.0))
	if heal > 0 and player_hp <= int(player_max_hp * 0.2):
		_last_remedy_used = true
		player_hp = mini(player_hp + heal, player_max_hp)
		last_remedy_triggered.emit(heal)


func _check_victory() -> bool:
	if enemy_hp <= 0 and not battle_over:
		battle_over = true
		battle_won.emit()
		return true
	return false


func _check_defeat() -> bool:
	if player_hp <= 0 and not battle_over:
		battle_over = true
		battle_lost.emit()
		return true
	return false
