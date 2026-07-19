extends Node
## Headless gameplay logic tests. Run with:
##   godot --headless --path . res://tests/logic_test.tscn
## Exits 0 when all assertions pass, 1 otherwise.

var _failures := 0
var _checks := 0


func _ready() -> void:
	_test_battle_basics()
	_test_fire_burst_combo()
	_test_shield_and_enemy_turn()
	_test_poison_flow()
	_test_armor()
	_test_defeat()
	_test_board_rules()
	_test_tutorial_opening()
	_test_upgrades()
	_test_relics_and_perma()
	_test_last_remedy()
	print("---")
	print("%d checks, %d failures" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func check(condition: bool, what: String) -> void:
	_checks += 1
	if condition:
		print("PASS  ", what)
	else:
		_failures += 1
		print("FAIL  ", what)


func _fresh_battle(enemy := "slime") -> BattleManager:
	RunState.start_new_run()
	var b := BattleManager.new()
	add_child(b)
	b.setup(enemy)
	return b


func _test_battle_basics() -> void:
	var b := _fresh_battle()
	check(b.player_hp == 50 and b.enemy_hp == 60, "initial stats from JSON")
	b.on_potion_completed("red")
	check(b.enemy_hp == 40, "fire potion deals 20")
	b.on_potion_completed("green")
	check(b.player_hp == 50, "heal capped at max HP")
	b.free()


func _test_fire_burst_combo() -> void:
	var b := _fresh_battle()
	b.on_potion_completed("red")
	b.on_potion_completed("red")
	check(b.enemy_hp == 60 - 20 - 30, "Fire Burst: second red deals 30")
	b.free()


func _test_shield_and_enemy_turn() -> void:
	var b := _fresh_battle()
	b.on_potion_completed("blue")
	check(b.shield == 12, "shield potion grants 12")
	for i in 4:
		b.on_move()
	check(b.shield == 7 and b.player_hp == 50, "opening attack of 5 absorbed by shield")
	check(b.moves_until_attack == 4, "opening attack counter resets")
	b.free()


func _test_poison_flow() -> void:
	var b := _fresh_battle()
	b.on_potion_completed("purple")
	check(b.poison_damage == 5 and b.poison_turns == 3, "poison applied 5x3")
	for i in 4:
		b.on_move()
	check(b.enemy_hp == 55 and b.poison_turns == 2, "poison ticks before attack")
	b.free()


func _test_tutorial_opening() -> void:
	var board := PuzzleBoard.new()
	add_child(board)
	check(board.has_method("generate_tutorial_board"), "tutorial board generator interface")
	if board.has_method("generate_tutorial_board"):
		board.call("generate_tutorial_board")
		var green_tops := 0
		var blue_tops := 0
		for tube in board.tubes:
			if not tube.contents.is_empty():
				green_tops += 1 if tube.contents.back() == "green" else 0
				blue_tops += 1 if tube.contents.back() == "blue" else 0
		check(green_tops >= 2 or blue_tops >= 2,
				"tutorial starts with defensive matching progress")
	board.free()


func _test_armor() -> void:
	var b := _fresh_battle("stone_golem")
	check(b.enemy_armor == 25, "golem starts with 25 armor")
	b.on_potion_completed("red")
	check(b.enemy_armor == 5 and b.enemy_hp == 90, "armor absorbs fire damage")
	b.on_potion_completed("purple")
	for i in 4:  # golem attacks every 4 moves
		b.on_move()
	check(b.enemy_hp == 85 and b.enemy_armor == 5, "poison bypasses armor")
	b.free()


func _test_defeat() -> void:
	var b := _fresh_battle()
	var lost := [false]
	b.battle_lost.connect(func() -> void: lost[0] = true)
	b.player_hp = 5
	for i in b.attack_every:
		b.on_move()
	check(lost[0] and b.battle_over, "player death emits battle_lost")
	b.free()


func _test_board_rules() -> void:
	var board := PuzzleBoard.new()
	add_child(board)
	var presented := [false, "", 0]
	if board.has_signal("pour_presented"):
		board.connect("pour_presented", func(_from: Vector2, _to: Vector2,
				color: String, count: int) -> void:
			presented[0] = true
			presented[1] = color
			presented[2] = count)
	var a := board.tubes[0]
	var c := board.tubes[1]
	a.set_contents(["red", "blue"] as Array[String])
	c.set_contents(["green"] as Array[String])
	check(not board._try_pour(a, c), "cannot pour blue onto green")
	c.set_contents(["blue", "blue"] as Array[String])
	check(board._try_pour(a, c), "pour blue onto blue")
	check(a.contents == (["red"] as Array[String])
			and c.contents.size() == 3, "one unit moved")
	check(presented[0] and presented[1] == "blue" and presented[2] == 1,
			"pour emits presentation metadata")
	check(board.undo(), "undo available")
	check(a.contents.size() == 2 and c.contents.size() == 2, "undo restores tubes")

	var completed := [""]
	board.tube_completed.connect(func(color: String) -> void: completed[0] = color)
	a.set_contents(["red", "blue", "blue", "blue"] as Array[String])
	c.set_contents(["blue"] as Array[String])
	board._try_pour(a, c)
	check(completed[0] == "blue", "completing 4 blue emits tube_completed")
	check(c.contents.is_empty(), "completed tube empties")

	for tube in board.tubes:
		tube.set_contents([] as Array[String])
	a.set_contents(["purple"] as Array[String])
	c.set_contents(["purple", "purple", "purple"] as Array[String])
	var refilled := [false]
	board.board_refilled.connect(func() -> void: refilled[0] = true)
	board.tube_completed.connect(func(_color: String) -> void: board.enabled = false)
	board.enabled = true
	board._try_pour(a, c)
	check(not refilled[0] and board.total_units() == 0,
			"winning final potion resolves before and skips an unused board refill")

	a.set_contents(["red"] as Array[String])
	board.lock_random_tube(2)
	var locked_count := 0
	for tube in board.tubes:
		if tube.is_locked():
			locked_count += 1
	check(locked_count == 1, "lock_random_tube locks exactly one tube")
	board.free()


func _test_upgrades() -> void:
	RunState.start_new_run()
	RunState.pick_upgrade("flame_mastery")
	RunState.pick_upgrade("flame_mastery")
	check(int(RunState.stat("red_damage", 20)) == 30, "stacked upgrades add up")
	var choices := RunState.roll_upgrade_choices()
	check(choices.size() == 3, "three upgrade choices rolled")

	var b := BattleManager.new()
	add_child(b)
	b.setup("slime")
	b.on_potion_completed("red")
	check(b.enemy_hp == 30, "upgraded fire potion deals 30")
	b.free()
	RunState.start_new_run()


func _test_relics_and_perma() -> void:
	RunState.start_new_run()
	RunState.pick_relic("molten_core")
	check(int(RunState.stat("red_damage", 20)) == 28, "relic adds to stat pipeline")
	var relic_choices := RunState.roll_relic_choices()
	check(relic_choices.size() == 3 and not "molten_core" in relic_choices,
			"owned relics excluded from choices")

	SaveSystem.data["perma"] = {"fire_affinity": 3}
	check(int(RunState.stat("red_damage", 20)) == 31, "perma levels stack with relic")
	check(RunState.perma_cost("fire_affinity") == 15 * 4, "perma cost scales with level")
	SaveSystem.data["perma"] = {}
	RunState.start_new_run()


func _test_last_remedy() -> void:
	var b := _fresh_battle()
	RunState.pick_upgrade("last_remedy")
	var triggered := [0]
	b.last_remedy_triggered.connect(func(heal: int) -> void: triggered[0] = heal)
	b.player_hp = 12  # slime hits for 5 -> 7 HP = below 20% of 50
	for i in b.attack_every:
		b.on_move()
	check(triggered[0] == 10 and b.player_hp == 17, "Last Remedy heals once below 20%")
	b.player_hp = 12
	for i in b.attack_every:
		b.on_move()
	check(b.player_hp == 7, "Last Remedy only fires once per battle")
	b.free()
	RunState.start_new_run()
