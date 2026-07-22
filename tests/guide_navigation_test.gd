extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	check(ResourceLoader.exists("res://scenes/guide.tscn"), "Guide scene exists")
	if ResourceLoader.exists("res://scenes/guide.tscn"):
		var guide: Control = load("res://scenes/guide.tscn").instantiate()
		add_child(guide)
		await get_tree().process_frame
		check(guide.find_child("GuideScroll", true, false) is ScrollContainer,
				"Guide content has a vertical scroll viewport")
		check(guide.find_child("GuideTabs", true, false) != null, "Guide exposes section tabs")
		check(guide.find_child("FormulaCodexButton", true, false) != null,
				"Reaction guide links to Formula Codex")
		check(guide.find_child("ReturnButton", true, false) != null, "Guide has a clear return action")
		guide.queue_free()
	var menu_source := FileAccess.get_file_as_string("res://src/ui/main_menu.gd")
	var battle_source := FileAccess.get_file_as_string("res://src/ui/battle_screen.gd")
	check(menu_source.contains('"GUIDE"'), "Main hall exposes Guide")
	check(battle_source.contains('name = "BattleGuideButton"'), "Battle exposes contextual help")
	check(battle_source.contains("_checkpoint_encounter()") and battle_source.contains("guide.tscn"),
			"Battle checkpoints before opening Guide")
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS  " + label)
	else: failures += 1; push_error("FAIL  " + label)
