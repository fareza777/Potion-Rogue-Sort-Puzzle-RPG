extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	var original: Dictionary = SaveSystem.data.duplicate(true)
	SaveSystem.data = SaveSystem.DEFAULT_DATA.duplicate(true)
	check(SaveSystem.has_method("discover_formula"), "save exposes formula discovery")
	if SaveSystem.has_method("discover_formula"):
		check(SaveSystem.call("discover_formula", "fire_burst"), "first discovery is reported")
		check(not SaveSystem.call("discover_formula", "fire_burst"), "repeat discovery is idempotent")
		check(SaveSystem.call("discovered_formulas") == ["fire_burst"], "discovery is persisted once")
	var legacy := SaveSystem.migrate({"version": 10, "settings": {}})
	check(legacy.has("discovered_formulas"), "legacy saves migrate with a formula collection")
	var scene := load("res://scenes/reaction_codex.tscn")
	check(scene != null, "Formula Codex scene loads")
	var source := FileAccess.get_file_as_string("res://src/ui/reaction_codex_screen.gd")
	check(source.contains("ScrollContainer"), "Formula Codex is scrollable")
	var card_source := FileAccess.get_file_as_string(
			"res://src/ui/components/formula_card.gd")
	check(card_source.contains("UNDISCOVERED FORMULA"),
			"undiscovered formulas hide their details")
	check(ResourceLoader.exists("res://src/ui/components/formula_socket.gd"),
			"Formula Codex owns a reusable jewel socket component")
	check(ResourceLoader.exists("res://src/ui/components/formula_card.gd"),
			"Formula Codex owns a reusable formula card component")
	check(not source.contains("ColorRect.new()") and source.contains("FormulaCard.new()"),
			"Formula Codex no longer renders essences as raw black rectangles")
	if scene != null:
		var codex: Control = scene.instantiate()
		add_child(codex)
		await get_tree().process_frame
		check(codex.find_child("FormulaCard_*", true, false) != null,
				"Formula cards expose stable semantic node names")
		check(codex.find_child("FormulaSocket_*", true, false) != null,
				"formula recipes render illustrated jewel sockets")
		codex.queue_free()
	SaveSystem.data = original
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS  " + label)
	else: failures += 1; push_error("FAIL  " + label)
