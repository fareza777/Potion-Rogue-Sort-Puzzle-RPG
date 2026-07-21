extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	for kit_id in GameState.kits:
		check(not (GameState.kits[kit_id].get("reaction_hooks", []) as Array).is_empty(),
				str(kit_id) + " defines a reaction identity")

	var pipeline := ReactionModifierPipeline.new()
	pipeline.configure("ember_adept", ["molten_core"], ["salamander_salt"], [])
	var boosted := pipeline.modify_result({"id":"inferno_catalyst",
			"tags":["fire"], "damage":20, "charge":45})
	check(is_equal_approx(float(boosted.get("reaction_power", 0.0)), 1.45475),
			"Hero, Relic, and Catalyst hooks use fixed ordering")
	check(int(boosted.get("damage", 0)) == 29,
			"reaction power modifies authored damage once")

	var void_pipeline := ReactionModifierPipeline.new()
	void_pipeline.configure("void_brewer", [], [], [])
	check(void_pipeline.transform_essence("purple") == "wild",
			"Void Brewer transforms its first Venom essence")
	check(void_pipeline.transform_essence("purple") == "purple",
			"limited transform cannot recurse or repeat")
	var restored := ReactionModifierPipeline.new()
	restored.configure("void_brewer", [], [], [])
	check(restored.restore(void_pipeline.snapshot()), "hook limits restore")
	check(restored.transform_essence("purple") == "purple",
			"restored limit prevents a free extra transform")

	var build := {"kit_id":"ember_adept", "relics":["molten_core"],
			"catalysts":["salamander_salt"], "mutations":[]}
	var rows := BuildSynergy.new().reaction_synergies(build)
	check(rows.size() == 3, "Build Summary receives exact reaction hooks")
	var preview := RewardGenerator.new().describe_choice("relic", "molten_core", build)
	check(bool(preview.get("compatible", false))
			and not str(preview.get("reaction_delta", "")).is_empty(),
			"reward preview exposes compatibility and exact reaction delta")

	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("PASS  " + label)
	else:
		failures += 1
		push_error("FAIL  " + label)
