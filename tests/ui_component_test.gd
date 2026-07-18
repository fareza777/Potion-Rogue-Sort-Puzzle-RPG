extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	check(UiThemeTokens.TOUCH_TARGET >= 56, "semantic touch target is at least 56 px")
	check(UiThemeTokens.type_size("display") > UiThemeTokens.type_size("title"),
			"semantic type scale has clear hierarchy")
	var action := ActionIconButton.new()
	action.configure("undo", "Undo", "Undo last pour")
	check(action.custom_minimum_size.x >= 72 and action.icon != null,
			"action icon button is large and illustrated")
	check(action.has_theme_stylebox_override("focus"), "action buttons have visible focus state")
	var nav := BottomNav.new()
	for id in ["hero", "upgrades", "home", "map", "settings"]:
		nav.add_item(id, id.capitalize(), Callable(), id == "home")
	check(nav.get_child_count() == 5, "Hall nav owns five consistently aligned destinations")
	var registry := VisualRegistry
	check(ResourceLoader.exists(registry.ui_icon("undo")) and ResourceLoader.exists(registry.ui_icon("home")),
			"generated Hall and battle art resolves")
	var hall := FileAccess.get_file_as_string("res://src/ui/main_menu.gd")
	check(hall.contains("BottomNav.new()"), "Hall consumes reusable bottom navigation")
	var tactical_path := "res://src/ui/tactical_readout.gd"
	check(ResourceLoader.exists(tactical_path), "battle owns reusable tactical readout")
	if ResourceLoader.exists(tactical_path):
		var tactical_script := load(tactical_path)
		var tactical = tactical_script.new()
		add_child(tactical)
		check(tactical.custom_minimum_size.y >= 56,
				"tactical readout preserves readable mobile height")
		for node_name in ["ObjectiveText", "EnemyIntent", "EnemyTrick"]:
			check(tactical.find_child(node_name, true, false) != null,
					"tactical readout exposes " + node_name)
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS  ", label)
	else:
		failures += 1
		print("FAIL  ", label)
