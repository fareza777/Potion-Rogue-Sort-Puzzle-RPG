extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	var enemies := GameState.load_data_file("enemies.json", {})
	var authored := 0
	for enemy_id in enemies:
		var signature_data: Dictionary = enemies[enemy_id].get("signature", {})
		if str(signature_data.get("id", "")) in ["mark", "seal", "hunt", "corrupt",
				"siphon", "split", "shift", "ward"]:
			authored += 1
	check(authored == enemies.size(), "every enemy owns a valid puzzle signature")
	var path := "res://src/battle/enemy_signature_controller.gd"
	check(ResourceLoader.exists(path),
			"enemy signature controller is registered")
	if ResourceLoader.exists(path):
		var controller_script := load(path)
		var signature = controller_script.new()
		signature.configure("slime",
				{"signature":{"id":"mark","label":"Watching Flask",
				"every_moves":3}}, 77)
		check(str(signature.preview().get("id", "")) == "mark",
				"signature is visible before trigger")
		check(not bool(signature.on_player_move(null).get("triggered", false)),
				"signature waits for authored cadence")
		signature.on_player_move(null)
		var saved: Dictionary = signature.snapshot()
		var restored = controller_script.new()
		restored.configure("slime",
				{"signature":{"id":"mark","label":"Watching Flask",
				"every_moves":3}}, 77)
		check(restored.restore(saved), "signature snapshot restores")
		check(restored.snapshot() == saved, "signature restore is exact")
		check(bool(restored.on_player_move(null).get("triggered", false)),
				"restored signature triggers on the same move")
		var malformed = controller_script.new()
		malformed.configure("broken", {"signature":{"id":"unknown"}}, 1)
		check(str(malformed.on_player_move(null).get("fallback", "")) == "attack",
				"unknown signature falls back harmlessly")
	var battle_source := FileAccess.get_file_as_string("res://src/ui/battle_screen.gd")
	check(battle_source.contains('"signature": signature_controller.snapshot()'),
			"encounter snapshots persist enemy signature state")
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("PASS  ", label)
	else:
		failures += 1
		print("FAIL  ", label)
