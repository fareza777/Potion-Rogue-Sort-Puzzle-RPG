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

var _last_potion := ""
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
	enemy_max_hp = int(e.get("hp", 60))
	enemy_hp = enemy_max_hp
	enemy_armor = int(e.get("armor", 0))
	enemy_attack = int(e.get("attack", 8))
	attack_every = int(e.get("attack_every", 3)) + int(RunState.stat("enemy_delay", 0.0)) \
			+ (1 if bool(SaveSystem.setting("assist_mode")) else 0)
	moves_until_attack = attack_every
	crystals_reward = int(e.get("crystals", 5))

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
	_last_potion = ""
	_last_remedy_used = false
	battle_over = false
	stats_changed.emit()


func undos_allowed() -> int:
	return int(RunState.stat("extra_undos",
			float(GameState.player.get("undos_per_battle", 3))))


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
			if _last_potion == "green":
				var bonus_hp: int = mini(5, player_max_hp - player_hp)
				player_hp += bonus_hp
				shield = mini(shield + 4, max_shield)
				combo_triggered.emit("Regeneration Guard! +%d HP, +4 shield" % bonus_hp)
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
	_last_potion = color
	stats_changed.emit()
	_check_victory()


func _activate_fire(data: Dictionary) -> void:
	var damage := int(RunState.stat("red_damage", float(data.get("damage", 20))))
	var notes: Array[String] = []

	if randf() < RunState.stat("crit_chance", 0.0):
		damage *= 2
		notes.append("CRITICAL!")
	if _last_potion == "red":
		damage = int(damage * 1.5)
		combo_triggered.emit("Fire Burst! +50% damage")
	elif _last_potion == "blue" and shield > 0:
		var converted := shield / 2
		shield -= converted
		damage += converted
		combo_triggered.emit("Shield Bash! +%d damage" % converted)
	elif _last_potion == "purple" and poison_turns > 0:
		var burst := poison_damage * poison_turns
		damage += burst
		poison_damage = 0
		poison_turns = 0
		combo_triggered.emit("Toxic Flame! +%d burst damage" % burst)

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
	_attacks_done += 1
	_check_defeat()
	_try_last_remedy()
	stats_changed.emit()
	return {"damage": damage, "blocked": blocked, "crit": crit}


func add_enemy_armor(amount: int) -> void:
	var applied := maxi(amount, 0)
	enemy_armor += applied
	armor_changed.emit(applied)
	stats_changed.emit()


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
