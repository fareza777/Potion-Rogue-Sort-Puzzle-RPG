extends Node
## Real battle-screen pours at the final enemy-countdown step.

var checks := 0
var failures := 0
var attacks := 0


func _ready() -> void:
	var original_save: Dictionary = SaveSystem.data.duplicate(true)
	var original_run: Dictionary = RunState.serialize_boundary()
	for fixture in [
		{"color":"red", "hp":5, "enemy_hp":10, "want_hp":5, "want_shield":0, "want_attacks":0},
		{"color":"green", "hp":5, "enemy_hp":100, "want_hp":12, "want_shield":0, "want_attacks":1},
		{"color":"blue", "hp":5, "enemy_hp":100, "want_hp":5, "want_shield":4, "want_attacks":1},
		{"color":"purple", "hp":5, "enemy_hp":5, "want_hp":5, "want_shield":0, "want_attacks":0},
	]:
		var screen := await _fresh_screen(int(fixture.hp), int(fixture.enemy_hp))
		_complete(screen, str(fixture.color))
		check(screen.battle.player_hp == fixture.want_hp and screen.battle.shield == fixture.want_shield,
				"%s potion protects or wins before the final-countdown attack" % fixture.color)
		check(attacks == fixture.want_attacks, "%s completion resolves at most one enemy attack" % fixture.color)
		check(not screen.board.can_undo(), "completed %s potion cannot be undone" % fixture.color)
		await _close_screen(screen)
	await _test_reaction_kills_before_attack()
	await _test_reaction_shields_before_attack()
	await _test_reaction_delays_final_attack()
	await _test_ordinary_pour_still_spends_move()
	await _test_cursed_completion_spends_move_without_potion()
	await _test_final_potion_does_not_refill_after_victory()
	await _test_wave_kill_cannot_spend_incoming_enemy_move()
	RunState.resume_from_save(original_run)
	SaveSystem.data = original_save
	await get_tree().create_timer(2.0).timeout
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _fresh_screen(hp: int, enemy_hp: int, attack := 8) -> Control:
	SaveSystem.data = SaveSystem.DEFAULT_DATA.duplicate(true)
	SaveSystem.data.tutorial_done = true
	SaveSystem.data.tutorial_state = "complete"
	SaveSystem.data.settings.reduced_effects = true
	RunState.start_new_run("ember_adept", "shadow_crypt", "normal", 90210)
	var screen := preload("res://scenes/battle.tscn").instantiate() as Control
	add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	screen.encounter_format.configure({"format":"duel"})
	screen.battle.setup("slime")
	screen.battle.player_hp = hp
	screen.battle.shield = 0
	screen.battle.enemy_hp = enemy_hp
	screen.battle.enemy_max_hp = enemy_hp
	screen.battle.enemy_armor = 0
	screen.battle.enemy_attack = attack
	screen.battle.attack_every = 4
	screen.battle.moves_until_attack = 1
	screen.intent_controller.configure("slime", {"intent_pool":["attack"]}, 1)
	screen.intent_controller.set_battle_values(attack, 0.0, 4)
	screen.signature_controller.configure("slime", {}, 1)
	screen.modifier_controller.configure([] as Array[String], 1, screen.board)
	screen.reaction_pipeline.configure("", [] as Array[String], [] as Array[String], [] as Array[String])
	attacks = 0
	screen.battle.enemy_attacked.connect(func(_damage: int, _blocked: int, _crit: bool) -> void: attacks += 1)
	return screen


func _complete(screen: Control, color: String, keep_other_layers := true) -> void:
	screen.board.import_state([[color], [color, color, color], ["green"] if keep_other_layers else [], [], [], []])
	check(screen.board._try_pour(screen.board.tubes[0], screen.board.tubes[1]), "final %s pour is legal" % color)


func _test_reaction_kills_before_attack() -> void:
	var screen := await _fresh_screen(5, 25)
	screen.combo_resolver.push_essence("red")
	_complete(screen, "red")
	check(screen.battle.enemy_hp == 0 and screen.battle.player_hp == 5 and attacks == 0,
			"Fire Burst finishes a surviving enemy before its lethal queued attack")
	await _close_screen(screen)


func _test_reaction_shields_before_attack() -> void:
	var screen := await _fresh_screen(5, 100, 20)
	screen.combo_resolver.push_essence("green")
	_complete(screen, "blue")
	check(screen.battle.player_hp == 6 and screen.battle.shield == 0 and attacks == 1,
			"Restorative Barrier heals and adds shield before a lethal queued attack")
	await _close_screen(screen)


func _test_reaction_delays_final_attack() -> void:
	var screen := await _fresh_screen(5, 100)
	screen.combo_resolver.push_essence("blue")
	screen.combo_resolver.push_essence("green")
	_complete(screen, "blue")
	check(attacks == 0 and screen.battle.moves_until_attack == 1 and screen.battle.player_hp == 17,
			"Sanctuary delays the queued attack while the completing pour still spends one move")
	await _close_screen(screen)


func _test_ordinary_pour_still_spends_move() -> void:
	var screen := await _fresh_screen(15, 100)
	screen.board.import_state([["red"], [], ["green"], [], [], []])
	screen.board._try_pour(screen.board.tubes[0], screen.board.tubes[1])
	check(attacks == 1 and screen.battle.player_hp == 7 and screen.battle.moves_until_attack == 4,
			"a non-completing pour triggers exactly one due attack and resets the countdown")
	check(screen.board.can_undo(), "an ordinary pour retains undo history")
	await _close_screen(screen)


func _test_cursed_completion_spends_move_without_potion() -> void:
	var screen := await _fresh_screen(15, 100)
	screen.board.import_state([["blue"], ["blue", "blue", "blue"], ["green"], [], [], []])
	screen.board.tubes[1].add_layer_effect(0, "cursed")
	screen.board._try_pour(screen.board.tubes[0], screen.board.tubes[1])
	check(attacks == 1 and screen.battle.player_hp == 7 and screen.battle.shield == 0,
			"cleansing a cursed flask spends one move without granting a shield potion")
	await _close_screen(screen)


func _test_final_potion_does_not_refill_after_victory() -> void:
	var screen := await _fresh_screen(5, 10)
	_complete(screen, "red", false)
	check(screen.battle.battle_over and screen.battle.enemy_hp == 0
			and not screen.board.enabled and screen.board.total_units() == 0,
			"the last potion wins without generating another puzzle behind the victory screen")
	await _close_screen(screen)


func _test_wave_kill_cannot_spend_incoming_enemy_move() -> void:
	var screen := await _fresh_screen(15, 10)
	screen.encounter_format.configure({"format":"multi_wave", "waves":2})
	var profile := RunState.ensure_current_encounter_profile()
	profile["wave_enemy_ids"] = ["slime", "skeleton"]
	screen.combo_resolver.push_essence("red")
	_complete(screen, "red")
	check(screen.encounter_format.wave == 2 and not screen.battle.battle_over,
			"a lethal potion advances to the next wave")
	check(screen.battle.player_hp == 15 and screen.battle.moves_until_attack == screen.battle.attack_every
			and screen.battle.enemy_hp == screen.battle.enemy_max_hp and attacks == 0,
			"wave entry preserves the full countdown and does not receive the previous potion's reaction")
	await _close_screen(screen)


func _close_screen(screen: Control) -> void:
	screen.queue_free()
	await get_tree().process_frame


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS  " + label)
	else: failures += 1; print("FAIL  " + label)
