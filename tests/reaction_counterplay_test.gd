extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	var controller := ReactionCounterplayController.new()
	controller.configure({"reaction_counter":{"tag":"ward", "result":"delay", "moves":1}}, {})
	var preview := controller.preview()
	check(str(preview.get("counter_tag", "")) == "ward", "intent declares counterplay")
	var result := controller.modify_reaction({"id":"fortify", "tags":["ward"]})
	check(int(result.get("enemy_delay", 0)) == 1, "matching formula earns declared response")
	check(int(controller.modify_reaction({"id":"fire_burst", "tags":["fire"]}).get("enemy_delay", 0)) == 0,
			"unrelated formula is unchanged")
	var saved := controller.snapshot()
	var restored := ReactionCounterplayController.new()
	check(restored.restore(saved), "counterplay state restores safely")
	check(str(restored.preview().get("counter_tag", "")) == "ward", "restore preserves declared rule")
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS  " + label)
	else: failures += 1; push_error("FAIL  " + label)
