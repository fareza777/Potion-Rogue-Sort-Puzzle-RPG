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
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func assert_check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS  ", label)
	else: failures += 1; print("FAIL  ", label)
