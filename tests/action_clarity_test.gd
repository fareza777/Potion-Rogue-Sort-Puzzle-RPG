extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	var resolver := EventResolver.new()
	check(resolver.has_method("choice_summary"), "events expose player-facing previews")
	if resolver.has_method("choice_summary"):
		var paid: String = resolver.call("choice_summary", "whispering_well", "offer")
		check(paid.contains("Cost: 5") and paid.contains("Gain:"),
				"paid event preview names both cost and benefit")
		var risky: String = resolver.call("choice_summary", "mirror_cauldron", "gaze")
		check(risky.contains("Lose: 8 HP") and risky.contains("Gain:"),
				"risky event preview names downside and reward")
		var heal: String = resolver.call("choice_summary", "ember_camp", "rest")
		check(heal.contains("Restore 30% max HP"), "percentage healing is explicit")

	var source := FileAccess.get_file_as_string("res://src/ui/battle_screen.gd")
	check(source.contains("battle.on_move()") and source.contains("Potions remixed — 1 move spent"),
			"New Mix spends one enemy-countdown move and explains it")
	check(source.contains('"New Mix\\n1 Move"'), "New Mix button communicates its cost before tapping")
	var event_source := FileAccess.get_file_as_string("res://src/ui/event_screen.gd")
	check(event_source.contains("choice_summary"), "event cards render concrete effect summaries")
	check(event_source.contains("result_summary"), "event result confirms the applied outcome")
	var route_source := FileAccess.get_file_as_string("res://src/ui/dungeon_route.gd")
	check(route_source.contains('node.get("reveal_kind"') and route_source.contains("_risk_pips"),
			"reachable route cards expose class and coarse risk without enemy identity")
	var map_source := FileAccess.get_file_as_string("res://src/ui/map_screen.gd")
	check(map_source.contains("MORE FLAMES MEAN MORE RISK"),
			"map legend explains route risk before selection")

	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS  ", label)
	else:
		failures += 1
		print("FAIL  ", label)
