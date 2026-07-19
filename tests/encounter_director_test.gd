extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	var context := {"floor": 1, "kind": "battle", "hp_ratio": 0.32,
			"ascension": 0, "early_defeat_streak": 2}
	var first := EncounterDirector.new().build_profile(context, 81231)
	var second := EncounterDirector.new().build_profile(context, 81231)
	check(first == second, "same seed and context produce an identical profile")
	check(str(first.format) == "duel", "intro floors always use the readable duel format")
	check(int(first.assistance_tier) in [0, 1, 2], "assistance is strictly bounded")
	check(float(first.reward_mult) >= 1.0, "assistance never reduces encounter rewards")
	var advanced := EncounterDirector.new().build_profile({"floor":5, "kind":"battle",
			"hp_ratio":1.0, "ascension":2, "early_defeat_streak":0}, 991)
	check(str(advanced.format) in EncounterDirector.ADVANCED_FORMATS,
			"advanced floors select a supported encounter format")
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS  ", label)
	else: failures += 1; print("FAIL  ", label)
