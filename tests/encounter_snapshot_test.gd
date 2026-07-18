extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	var original_save := SaveSystem.data.duplicate(true)
	SaveSystem.data = SaveSystem.DEFAULT_DATA.duplicate(true)
	RunState.start_new_run("ember_adept", "shadow_crypt")

	var board := PuzzleBoard.new()
	add_child(board)
	await get_tree().process_frame
	var battle := BattleManager.new()
	add_child(battle)
	battle.setup("slime")
	battle.enemy_hp = 17
	battle.player_hp = 31
	battle.shield = 8
	battle.moves_until_attack = 2
	battle.poison_damage = 4
	battle.poison_turns = 2
	board.tubes[0].locked_moves = 2

	check(battle.has_method("export_snapshot") and battle.has_method("restore_snapshot"),
			"battle exposes snapshot API")
	check(board.has_method("export_snapshot") and board.has_method("restore_snapshot"),
			"board exposes snapshot API")
	if battle.has_method("export_snapshot") and board.has_method("export_snapshot"):
		var payload := {
			"battle": battle.call("export_snapshot"),
			"board": board.call("export_snapshot"),
			"undo_left": 2,
		}
		RunState.checkpoint(RunState.PHASE_BATTLE, {"encounter": payload})
		battle.enemy_hp = 60
		battle.player_hp = 50
		board.generate_board()
		if battle.has_method("restore_snapshot"):
			check(battle.call("restore_snapshot", payload.battle), "battle snapshot restores")
		if board.has_method("restore_snapshot"):
			check(board.call("restore_snapshot", payload.board), "board snapshot restores")
		check(battle.enemy_hp == 17 and battle.player_hp == 31 and battle.shield == 8,
				"combat values resume exactly")
		check(battle.moves_until_attack == 2 and battle.poison_turns == 2,
				"turn counter and status resume exactly")
		check(board.tubes[0].locked_moves == 2,
				"puzzle hazards resume exactly")
		var persisted: Dictionary = SaveSystem.data.get("active_run", {})
		check(str(persisted.get("phase", "")) == RunState.PHASE_BATTLE,
				"save and exit retains battle phase")
		check(not (persisted.get("phase_payload", {}) as Dictionary).is_empty(),
				"save and exit persists encounter payload")

	var source := FileAccess.get_file_as_string("res://src/ui/battle_screen.gd")
	check(source.contains("_save_and_exit"), "pause menu offers explicit Save & Exit")
	check(source.contains("_confirm_abandon"), "abandon requires an explicit confirmation")
	check(not source.contains('["Abandon Run", _go_to_menu]'),
			"abandon can no longer masquerade as navigation")

	SaveSystem.data = original_save
	SaveSystem.save()
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("PASS  ", label)
	else:
		failures += 1
		print("FAIL  ", label)
