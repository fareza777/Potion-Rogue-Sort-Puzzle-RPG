extends Node

var checks := 0
var failures := 0

func _ready() -> void:
	var legacy := {"version":1,"crystals":5,"perma":{"hp":2},"settings":{},"active_run":{"active":true}}
	var once := SaveSystem.migrate(legacy); var twice := SaveSystem.migrate(once)
	check(once == twice, "migration is idempotent")
	check(once.crystals == 15 and once.legacy_run_compensated and not once.active_run.active,
			"legacy active run receives one compensation")
	RunState.start_new_run("void_brewer"); var boundary := RunState.serialize_boundary()
	check(RunState.resume_from_save(boundary), "v2 run resumes at map boundary")
	check(RunState.kit_id == "void_brewer" and not RunState.run_graph.is_empty(), "resume restores kit and graph")
	boundary.mutations = ["emberheart", "corrupt_id"]
	check(RunState.resume_from_save(boundary) and RunState.mutation_ids == ["emberheart"], "resume discards corrupt content ids")
	check(once.get("unlocked_areas", []) == ["shadow_crypt"], "legacy saves unlock Shadow Crypt")
	check(once.get("completed_areas", []) == [] and once.get("selected_area", "") == "shadow_crypt",
			"legacy saves receive campaign progress defaults")
	check((once.get("area_stats", {}) as Dictionary).is_empty(), "legacy saves receive empty per-area stats")
	check(SaveSystem.has_method("complete_area") and SaveSystem.has_method("record_area_depth"),
			"campaign progression API is available")
	if SaveSystem.has_method("complete_area"):
		var original: Dictionary = SaveSystem.data.duplicate(true)
		SaveSystem.data = SaveSystem.DEFAULT_DATA.duplicate(true)
		var clear: Dictionary = SaveSystem.call("complete_area", "shadow_crypt")
		check(clear.get("unlocked_area", "") == "verdant_catacombs", "first clear unlocks the next area")
		check(SaveSystem.call("is_area_unlocked", "verdant_catacombs"), "unlocked area persists in campaign state")
		check(int(clear.get("reward", 0)) == 30 and SaveSystem.crystals() == 30,
				"first clear grants its authored crystal reward once")
		var replay: Dictionary = SaveSystem.call("complete_area", "shadow_crypt")
		check(int(replay.get("reward", -1)) == 0 and SaveSystem.crystals() == 30,
				"replaying an area cannot duplicate first-clear rewards")
		SaveSystem.call("record_area_depth", "verdant_catacombs", 4)
		SaveSystem.call("record_area_depth", "verdant_catacombs", 2)
		check(SaveSystem.call("best_depth", "verdant_catacombs") == 4, "best depth only moves forward")
		SaveSystem.data = original
		SaveSystem.save()
	print("---\n%d checks, %d failures" % [checks, failures]); get_tree().quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS  ", label)
	else: failures += 1; print("FAIL  ", label)
