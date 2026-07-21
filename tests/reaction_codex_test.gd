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
	check(source.contains("LOCKED FORMULA"), "undiscovered formulas hide their details")
	SaveSystem.data = original
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS  " + label)
	else: failures += 1; push_error("FAIL  " + label)
