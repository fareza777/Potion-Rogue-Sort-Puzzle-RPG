extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	var board := PuzzleBoard.new()
	add_child(board)
	var initial: Array = BoardFactory.generate(31337, "standard").state
	board.import_state(initial)
	var battle := BattleManager.new()
	add_child(battle)
	battle.setup("slime")
	var intent := EnemyIntentController.new()
	intent.configure("slime", {"intent_pool": [{"id": "corruption", "weight": 1}]}, 7)
	intent.set_battle_values(1, 0.0, 3)
	intent.resolve(battle, board)
	check(_effect_count(board, "cursed") == 1,
			"production corruption intent reaches a real PuzzleBoard")
	check(board.export_state() == initial,
			"production corruption preserves the verified color layout")
	var intent_source := FileAccess.get_file_as_string(
			"res://src/battle/enemy_intent_controller.gd")
	check(intent_source.contains("BoardActionResolver") \
			and not intent_source.contains('"type": "append_corruption"'),
			"enemy intents route mutations through the validated resolver")
	var invalid := BoardActionResolver.new().apply({"id": "unknown"}, board)
	check(not bool(invalid.get("applied", true)) \
			and not str(invalid.get("reason", "")).is_empty(),
			"unknown board actions fail with an explicit reason")

	board.queue_free()
	battle.queue_free()
	finish()


func _effect_count(board: PuzzleBoard, effect: String) -> int:
	var total := 0
	for tube in board.tubes:
		total += tube.effect_count(effect)
	return total


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("PASS  ", label)
	else:
		failures += 1
		print("FAIL  ", label)


func finish() -> void:
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
