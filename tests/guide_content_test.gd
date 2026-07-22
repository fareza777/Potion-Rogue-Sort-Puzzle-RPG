extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	var ids: Array = GuideContent.sections().map(func(item: Dictionary): return item.id)
	check(ids == ["basics", "reactions", "skills", "battle", "expedition"],
			"Guide exposes five ordered learning sections")
	var reaction := GuideContent.section("reactions")
	check(str(reaction.get("body", "")).to_lower().contains("last three"),
			"Reaction guide explains the three colored dots")
	check(str(reaction.get("body", "")).to_lower().contains("order"),
			"Reaction guide explains ordered formulas")
	var kits := GuideContent.kit_cards()
	check(kits.size() == GameState.kits.size(), "Every playable kit has a guide card")
	for card in kits:
		check(card.has("cost") and card.has("cooldown") and card.has("ultimate"),
				str(card.get("name", "Kit")) + " explains skill cost, cooldown, and ultimate")
	var basics := GuideContent.section("basics")
	for color in ["Red", "Green", "Blue", "Purple"]:
		check(str(basics.get("body", "")).contains(color), color + " potion is explained")
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS  " + label)
	else: failures += 1; push_error("FAIL  " + label)
