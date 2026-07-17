extends Node

var _failures := 0
var _checks := 0


func _ready() -> void:
	_test_combos()
	_test_skills()
	_test_rewards()
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


func _test_skills() -> void:
	RunState.start_new_run("void_brewer")
	check(RunState.kit_id == "void_brewer", "new run persists selected starting kit")
	RunState.start_new_run("missing_kit")
	check(RunState.kit_id == "ember_adept", "invalid starting kit uses ember fallback")
	var ember := SkillController.new()
	ember.configure("ember_adept")
	ember.gain_mana(150)
	check(ember.mana == 100, "mana is capped at one hundred")
	check(ember.can_cast("flash_boil"), "ember active becomes castable")
	var cast := ember.cast("flash_boil", {})
	check(bool(cast.get("ok", false)) and ember.mana == 50,
			"valid skill spends its exact mana cost")
	check(not ember.can_cast("flash_boil"), "active skill enters cooldown")
	ember.tick_cooldowns()
	check(ember.can_cast("flash_boil"), "cooldown advances explicitly")

	var board := PuzzleBoard.new()
	add_child(board)
	board.generate_tutorial_board()
	var void_brewer := SkillController.new()
	void_brewer.configure("void_brewer", board)
	void_brewer.gain_mana(100)
	var mana_before := void_brewer.mana
	var invalid := void_brewer.cast("transmute", {"tube": 99})
	check(not bool(invalid.get("ok", true)) and void_brewer.mana == mana_before,
			"invalid skill target does not spend mana")
	var valid := void_brewer.cast("transmute", {"tube": 0})
	check(bool(valid.get("ok", false)) and board.tubes[0].top_color() == "wild",
			"transmute creates wild essence through board commands")
	void_brewer.gain_ultimate(100)
	check(void_brewer.ultimate_ready() and void_brewer.consume_ultimate(),
			"ultimate charge can be consumed at full")
	board.free()


func _test_rewards() -> void:
	var mutations := GameState.load_data_file("mutations.json", {})
	var relics := GameState.load_data_file("relics.json", {})
	var catalysts := GameState.load_data_file("catalysts.json", {})
	check(mutations.size() == 24, "content includes twenty-four mutations")
	check(relics.size() == 18, "content includes eighteen relics")
	check(catalysts.size() == 12, "content includes twelve catalysts")
	var generator := RewardGenerator.new()
	var build := {"tags": ["fire"], "owned": []}
	var first := generator.choices("mutation", 3, 4412, build)
	var second := generator.choices("mutation", 3, 4412, build)
	check(first == second, "reward choices are deterministic by seed")
	check(first.size() == 3 and first[0] != first[1] and first[1] != first[2]
			and first[0] != first[2], "reward draft contains three unique choices")
	RunState.mutation_ids = ["emberheart"]
	RunState.relic_ids = ["molten_core"]
	RunState.catalyst_ids = ["salamander_salt"]
	var value := RunState.resolve_effect_value("red_damage", 20.0,
			[{"stat": "red_damage", "op": "add", "value": 5}])
	check(is_equal_approx(value, 45.0),
			"effects stack base, mutation, relic, catalyst, then temporary")


func check(condition: bool, what: String) -> void:
	_checks += 1
	if condition:
		print("PASS  ", what)
	else:
		_failures += 1
		print("FAIL  ", what)
