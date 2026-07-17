extends Node

var checks := 0
var failures := 0

func _ready() -> void:
	var original := SaveSystem.data.duplicate(true)
	SaveSystem.data = SaveSystem.DEFAULT_DATA.duplicate(true)
	var director := TutorialDirector.new()
	director.configure()
	check(director.active and director.steps.size() == 10, "first run starts ten-step tutorial")
	check(not director.accept_action("wrong"), "incorrect action cannot advance tutorial")
	var actions := ["intro", "inspect_enemy", "inspect_intent", "select_source",
			"select_target", "undo", "complete_potion", "gain_mana", "cast_skill", "choose_path"]
	for action in actions: check(director.accept_action(action), "tutorial accepts " + action)
	check(SaveSystem.is_tutorial_done() and SaveSystem.data.tutorial_state == "complete",
			"completion persists")
	director.configure(true)
	check(director.active and director.index == 0 and not SaveSystem.is_tutorial_done(),
			"replay resets tutorial only")
	director.skip()
	check(SaveSystem.data.tutorial_skipped and SaveSystem.is_tutorial_done(), "skip persists separately")
	var migrated := SaveSystem.migrate({"version":2,"tutorial_done":true,"settings":{}})
	check(migrated.version == SaveSystem.SAVE_VERSION and migrated.tutorial_state == "complete",
			"v2 tutorial migrates to current save schema")
	SaveSystem.data = original
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS  ", label)
	else: failures += 1; print("FAIL  ", label)
