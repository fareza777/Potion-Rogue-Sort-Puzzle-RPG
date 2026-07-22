extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	var tutorial := FileAccess.get_file_as_string("res://data/tutorial_steps.json")
	check(tutorial.contains("last three completed potion"), "Tutorial names the three colored dots")
	check(tutorial.contains("Order matters"), "Tutorial explains ordered reactions")
	check(tutorial.contains("Ultimate charge") and tutorial.contains("Mana"),
			"Tutorial distinguishes Mana from Ultimate charge")
	check(tutorial.contains("first normal New Mix") and tutorial.contains("one move"),
			"Tutorial explains New Mix economy")
	var chamber := FileAccess.get_file_as_string("res://src/ui/components/reaction_chamber.gd")
	check(chamber.contains("Last three completed potion essences") and chamber.contains("Order creates reactions"),
			"Reaction Chamber tooltip is explicit")
	var battle := FileAccess.get_file_as_string("res://src/ui/battle_screen.gd")
	check(battle.contains("GuideContent.skill_effect") and battle.contains("GuideContent.ultimate_effect"),
			"Battle skill tooltips use authoritative guide copy")
	for id in GameState.kits:
		var kit: Dictionary = GameState.kits[id]
		check(not GuideContent.skill_effect(str(kit.get("active", ""))).is_empty(),
				str(id) + " active skill has exact help copy")
		check(not GuideContent.ultimate_effect(str(id)).is_empty(),
				str(id) + " ultimate has exact help copy")
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS  " + label)
	else: failures += 1; push_error("FAIL  " + label)
