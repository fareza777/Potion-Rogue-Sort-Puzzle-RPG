extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	var original_save := SaveSystem.data.duplicate(true)
	SaveSystem.data = SaveSystem.DEFAULT_DATA.duplicate(true)
	check(RunState.has_method("checkpoint") and RunState.has_method("resume_scene"),
			"run lifecycle API exists")
	check(RunState.has_method("abandon_run") and SaveSystem.has_method("clear_active_run"),
			"abandon API exists")
	if RunState.has_method("checkpoint"):
		RunState.start_new_run("ember_adept", "shadow_crypt")
		check(str(RunState.get("phase")) == "MAP", "new run starts at map phase")
		check(not (SaveSystem.data.get("active_run", {}) as Dictionary).is_empty(),
				"new run immediately persists a resumable boundary")
		var node_before := RunState.current_node_id
		RunState.call("checkpoint", "BATTLE", {"encounter": "snapshot"})
		check(RunState.call("resume_scene") == "res://scenes/battle.tscn",
				"battle checkpoint resumes the battle scene")
		var saved := RunState.serialize_boundary()
		check(int(saved.get("version", 0)) == 4 and saved.get("phase", "") == "BATTLE",
				"version four boundary persists phase")
		check((saved.get("phase_payload", {}) as Dictionary).get("encounter", "") == "snapshot",
				"phase payload survives serialization")
		RunState.phase = "MAP"
		check(RunState.resume_from_save(saved) and RunState.phase == "BATTLE",
				"resume restores exact unresolved phase")
		RunState.run_crystals = 9
		var banked_before := SaveSystem.crystals()
		var kept: int = RunState.call("abandon_run")
		check(kept == 4 and SaveSystem.crystals() == banked_before + 4,
				"abandon banks the documented half-run amount")
		check(not RunState.active and (SaveSystem.data.active_run as Dictionary).is_empty(),
				"abandon disables Continue and clears active save")
		check(RunState.current_node_id == node_before, "abandon never advances the selected node")
	var legacy := RunGenerator.new().generate(77, "shadow_crypt")
	var legacy_boundary := {"version":3,"active":true,"seed":77,"area_id":"shadow_crypt",
			"graph":legacy,"current_node_id":legacy.start,"kit_id":"ember_adept"}
	check(RunState.resume_from_save(legacy_boundary) and str(RunState.get("phase")) == "MAP",
			"version three boundaries migrate to safe map phase")
	var menu_source := FileAccess.get_file_as_string("res://src/ui/main_menu.gd")
	check(menu_source.contains("RunState.resume_scene()"), "Continue routes through lifecycle state")
	check(not menu_source.contains('_on_continue_pressed() -> void:\n\tif not RunState.active:\n\t\treturn\n\tget_tree().change_scene_to_file("res://scenes/map.tscn")'),
			"Continue no longer hardcodes map navigation")
	SaveSystem.data = original_save
	SaveSystem.save()
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("PASS  ", label)
	else:
		failures += 1
		print("FAIL  ", label)
