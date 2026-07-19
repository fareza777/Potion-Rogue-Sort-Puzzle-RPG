extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	var events: Dictionary = GameState.load_data_file("events.json", {})
	check(events.size() >= 15, "at least fifteen mechanical events are authored")
	var resolver := EventResolver.new()
	for event_id in events:
		for choice_id in events[event_id].get("choices", {}):
			var summary := resolver.choice_summary(str(event_id), str(choice_id))
			check(not summary.is_empty() and summary != "No mechanical effect",
					"event choice states exact effect: %s/%s" % [event_id, choice_id])
	check(ResourceLoader.exists("res://src/run/build_synergy.gd"), "build synergy evaluator exists")
	if ResourceLoader.exists("res://src/run/build_synergy.gd"):
		var synergy = load("res://src/run/build_synergy.gd").new()
		var result: Array = synergy.evaluate({"tags":["fire", "fire", "wild"]})
		check(not result.is_empty() and result[0].has("name") and result[0].has("effects"),
				"tag synergy reports its name and exact mechanical effects")
	var ascension: Dictionary = GameState.load_data_file("ascension_rules.json", {})
	check(ascension.size() == 10, "every Ascension level has an authored rule")
	for level in range(1, 11):
		check(ascension.has(str(level)) and not str(ascension[str(level)].get("description", "")).is_empty(),
				"Ascension %d explains its modifier" % level)
	var defaults: Dictionary = SaveSystem.DEFAULT_DATA
	var daily: Dictionary = defaults.get("daily", {})
	check(daily.has("score") and daily.has("streak") and daily.has("last_played"),
			"Daily stores identity, score, and streak")
	var state_source := FileAccess.get_file_as_string("res://src/autoload/run_state.gd")
	check(state_source.contains('"relics":relic_ids') and state_source.contains('"mutations":mutation_ids'),
			"run history records the completed build")
	finish()


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS  ", label)
	else: failures += 1; print("FAIL  ", label)


func finish() -> void:
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
