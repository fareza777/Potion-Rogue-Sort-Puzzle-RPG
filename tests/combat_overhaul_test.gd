extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	var objective := ObjectiveController.new()
	objective.configure("brew_order", {"label":"Brew in order", "event":"potion_completed",
			"sequence":["red", "blue", "green"]})
	check(objective.has_method("display_payload"), "objectives expose structured HUD payload")
	if objective.has_method("display_payload"):
		var display: Dictionary = objective.call("display_payload")
		check(display.get("sequence", []) == ["red", "blue", "green"] and display.current == 0,
				"brew order is visible before progress")

	var expected := {
		"ember_adept": "inferno_break",
		"verdant_warden": "guardian_bloom",
		"void_brewer": "void_distill",
	}
	for kit_id in expected:
		var skill := SkillController.new()
		skill.configure(kit_id)
		skill.gain_ultimate(100)
		check(skill.has_method("cast_ultimate"), "%s exposes authored ultimate" % kit_id)
		if skill.has_method("cast_ultimate"):
			var result: Dictionary = skill.call("cast_ultimate", {})
			check(result.get("effect_id", "") == expected[kit_id],
					"%s ultimate has a distinct gameplay identity" % kit_id)

	var source := FileAccess.get_file_as_string("res://src/battle/battle_manager.gd")
	check(source.contains("armor_changed.emit(-absorbed)"), "real armor loss emits objective progress")
	var screen := FileAccess.get_file_as_string("res://src/ui/battle_screen.gd")
	check(screen.contains("cast_ultimate") and screen.contains("break_armor"),
			"battle screen applies authored ultimate payloads")

	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS  ", label)
	else:
		failures += 1
		print("FAIL  ", label)
