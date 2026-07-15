class_name BattleManager
extends Node
## Pure battle logic: player/enemy stats, move counter, enemy turns,
## potion effects and status effects. No UI code — the battle screen
## listens to these signals and renders the results.

signal stats_changed
signal potion_activated(color: String, text: String)
signal enemy_attacked(damage: int, blocked: int)
signal poison_ticked(damage: int)
signal battle_won
signal battle_lost

var player_hp := 0
var player_max_hp := 0
var shield := 0
var max_shield := 0

var enemy_id := ""
var enemy_name := ""
var enemy_hp := 0
var enemy_max_hp := 0
var enemy_attack := 0
var attack_every := 3
var moves_until_attack := 3

var poison_damage := 0
var poison_turns := 0

var battle_over := false


func setup(new_enemy_id: String) -> void:
	var p: Dictionary = GameState.player
	player_max_hp = int(p.get("max_hp", 50))
	player_hp = player_max_hp
	max_shield = int(p.get("max_shield", 30))
	shield = 0

	enemy_id = new_enemy_id
	var e: Dictionary = GameState.enemies.get(
			new_enemy_id, GameState.DEFAULT_ENEMIES["slime"])
	enemy_name = str(e.get("name", "Slime"))
	enemy_max_hp = int(e.get("hp", 60))
	enemy_hp = enemy_max_hp
	enemy_attack = int(e.get("attack", 8))
	attack_every = int(e.get("attack_every", 3))
	moves_until_attack = attack_every

	poison_damage = 0
	poison_turns = 0
	battle_over = false
	stats_changed.emit()


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
			var damage := int(data.get("damage", 20))
			enemy_hp = maxi(enemy_hp - damage, 0)
			potion_activated.emit(color, "Fire Potion! %d damage" % damage)
		"green":
			var heal := int(data.get("heal", 15))
			var healed: int = mini(heal, player_max_hp - player_hp)
			player_hp += healed
			potion_activated.emit(color, "Healing Potion! +%d HP" % healed)
		"blue":
			var amount := int(data.get("shield", 12))
			var gained: int = mini(amount, max_shield - shield)
			shield += gained
			potion_activated.emit(color, "Shield Potion! +%d shield" % gained)
		"purple":
			# Applying poison again refreshes the duration (no stacking in MVP).
			poison_damage = int(data.get("poison_damage", 5))
			poison_turns = int(data.get("poison_turns", 3))
			potion_activated.emit(color, "Poison! %d dmg for %d turns"
					% [poison_damage, poison_turns])
		_:
			push_warning("Unknown potion color: " + color)
	stats_changed.emit()
	_check_victory()


func _enemy_turn() -> void:
	moves_until_attack = attack_every

	# Status effects tick first: poison can kill the enemy before it attacks.
	if poison_turns > 0:
		enemy_hp = maxi(enemy_hp - poison_damage, 0)
		poison_turns -= 1
		poison_ticked.emit(poison_damage)
		if poison_turns == 0:
			poison_damage = 0
		if _check_victory():
			return

	# Shield absorbs damage first, the rest hits HP.
	var blocked: int = mini(shield, enemy_attack)
	shield -= blocked
	player_hp = maxi(player_hp - (enemy_attack - blocked), 0)
	enemy_attacked.emit(enemy_attack, blocked)

	if player_hp <= 0:
		battle_over = true
		battle_lost.emit()


func _check_victory() -> bool:
	if enemy_hp <= 0 and not battle_over:
		battle_over = true
		battle_won.emit()
		return true
	return false
