extends Node

var _failures := 0
var _checks := 0


func _ready() -> void:
	_test_combos()
	print("---")
	print("%d checks, %d failures" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _test_combos() -> void:
	var cases := {
		"fire_burst": ["red", "red"],
		"restorative_barrier": ["green", "blue"],
		"reflected_blaze": ["blue", "red"],
		"toxic_detonation": ["purple", "red"],
		"burning_venom": ["red", "purple"],
		"fortify": ["blue", "blue"],
		"regeneration": ["green", "green"],
		"venom_ward": ["purple", "blue"],
		"inferno_catalyst": ["red", "purple", "red"],
		"sanctuary": ["blue", "green", "blue"],
		"plague_nova": ["purple", "purple", "red"],
	}
	for expected_id in cases:
		var resolver := ComboResolver.new()
		var result: Dictionary = {}
		for color in cases[expected_id]:
			result = resolver.push_potion(color)
		check(str(result.get("id", "")) == expected_id,
				"combo resolves: " + expected_id)

	var longest := ComboResolver.new()
	longest.push_potion("red")
	longest.push_potion("purple")
	var ultimate := longest.push_potion("red")
	check(str(ultimate.get("id", "")) == "inferno_catalyst",
			"longest combo pattern wins")
	longest.push_potion("green")
	check(longest.history().size() == 3, "combo history is limited to three")
	check(longest.ultimate_charge() > 0, "resolved combos build ultimate charge")


func check(condition: bool, what: String) -> void:
	_checks += 1
	if condition:
		print("PASS  ", what)
	else:
		_failures += 1
		print("FAIL  ", what)
