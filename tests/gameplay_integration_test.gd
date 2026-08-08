extends Node

var failures := 0
var checks := 0

func _ready() -> void:
	RunState.start_new_run("ember_adept")
	var battle := BattleManager.new(); add_child(battle); battle.setup("slime")
	var board := PuzzleBoard.new(); add_child(board); board.generate_tutorial_board()
	var objective := ObjectiveController.new(); objective.configure("defeat", GameState.objectives.defeat)
	var intent := EnemyIntentController.new(); intent.configure("slime", GameState.enemies.slime, 77)
	intent.set_battle_values(battle.enemy_attack, 0.0, battle.attack_every)
	battle.intent_controller = intent; battle.intent_board = board
	var skill := SkillController.new(); skill.configure("ember_adept", board); skill.gain_mana(50)
	assert_check(skill.cast("flash_boil", {}).ok, "active skill casts in encounter")
	assert_check(not intent.preview().is_empty(), "enemy intent remains previewable")
	battle.battle_won.connect(objective.on_enemy_defeated)
	battle.deal_skill_damage(999)
	assert_check(battle.battle_over and objective.is_completed(), "defeat encounter completes once")
	assert_check(RunState.active, "reward transition has not ended run early")
	var project := FileAccess.get_file_as_string("res://project.godot")
	assert_check(project.contains("StoryboardService="),
			"global storyboard service is registered")
	var kit_source := FileAccess.get_file_as_string("res://src/ui/kit_select_screen.gd")
	assert_check(kit_source.contains('StoryboardService.play("run_intro"')
			and kit_source.contains('StoryboardService.play("realm_arrival"'),
			"new expedition plays its vow and realm arrival")
	var map_source := FileAccess.get_file_as_string("res://src/ui/map_screen.gd")
	assert_check(map_source.contains('StoryboardService.play("route_choice"')
			and map_source.contains('StoryboardService.play("battle_intro"'),
			"route and battle transitions are cinematic")
	var event_source := FileAccess.get_file_as_string("res://src/ui/event_screen.gd")
	assert_check(event_source.contains('StoryboardService.play("event_reveal"')
			and event_source.contains('StoryboardService.play("event_resolution"'),
			"event reveal and consequence are cinematic")
	var battle_source := FileAccess.get_file_as_string("res://src/ui/battle_screen.gd")
	for trigger in ["battle_escalation", "battle_victory", "battle_defeat", "run_epilogue"]:
		assert_check(battle_source.contains('StoryboardService.play("' + trigger + '"'),
				"battle flow integrates " + trigger)
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func assert_check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS  ", label)
	else: failures += 1; print("FAIL  ", label)
