extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	var resolver := ComboResolver.new()
	check(resolver.push_essence("red").is_empty(),
			"first essence has no reaction")
	var two := resolver.push_essence("red")
	check(str(two.get("id", "")) == "fire_burst",
			"two-color suffix resolves")

	resolver = ComboResolver.new()
	resolver.push_essence("red")
	resolver.push_essence("purple")
	var three := resolver.push_essence("red")
	check(str(three.get("id", "")) == "inferno_catalyst",
			"longest three-color suffix wins")
	check(resolver.history() == ["red", "purple", "red"],
			"reaction does not erase the chamber")

	var restored := ComboResolver.new()
	check(restored.restore(resolver.snapshot()), "snapshot restores")
	check(restored.history() == resolver.history(),
			"snapshot preserves essence order")
	check(not restored.restore({"history":["orange"], "ultimate_charge":0}),
			"invalid essence is rejected")
	check(restored.history() == resolver.history(),
			"failed restore is atomic")

	var before := resolver.history()
	check(resolver.push_essence("orange").is_empty(),
			"unknown essence cannot resolve")
	check(resolver.history() == before,
			"unknown essence cannot mutate the chamber")
	var wild := ComboResolver.new()
	wild.push_essence("red")
	var wild_result := wild.push_essence("wild")
	check(str(wild_result.get("id", "")) == "fire_burst",
			"Wild essence substitutes for a formula color")

	for id in GameState.combos:
		var formula: Dictionary = GameState.combos[id]
		check(not str(formula.get("name", "")).is_empty(),
				str(id) + " has a display name")
		check(not str(formula.get("description", "")).is_empty(),
				str(id) + " has an exact description")
		check(not (formula.get("tags", []) as Array).is_empty(),
				str(id) + " has build tags")
		check(not str(formula.get("vfx", "")).is_empty(),
				str(id) + " has a VFX profile")

	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("PASS  " + label)
	else:
		failures += 1
		push_error("FAIL  " + label)
