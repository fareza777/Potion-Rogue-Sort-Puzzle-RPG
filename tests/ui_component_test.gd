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
	add_child(nav)
	for id in ["hero", "upgrades", "home", "map", "settings"]:
		nav.add_item(id, id.capitalize(), Callable(), id == "home")
	var nav_row := nav.get_node_or_null("NavRow") as HBoxContainer
	check(nav_row != null and nav_row.get_child_count() == 5,
			"Hall nav owns five consistently aligned destinations")
	check(ResourceLoader.exists(VisualRegistry.ui_icon("areas")) \
			and ResourceLoader.exists(VisualRegistry.ui_icon("build")) \
			and ResourceLoader.exists(VisualRegistry.ui_icon("history")) \
			and ResourceLoader.exists(VisualRegistry.ui_icon("credits")),
			"generated expedition nav medallions resolve")
	check(ResourceLoader.exists(VisualRegistry.ui_icon("undo")) \
			and ResourceLoader.exists(VisualRegistry.ui_icon("home")),
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
	var summary_path := "res://src/ui/build_summary.gd"
	check(ResourceLoader.exists(summary_path), "map owns reusable build summary")
	if ResourceLoader.exists(summary_path):
		var summary = load(summary_path).new()
		add_child(summary)
		summary.configure("ember_adept", ["molten_core"], ["flame_mastery"], ["emberheart"])
		for node_name in ["BuildKit", "BuildCounts", "BuildSynergy"]:
			check(summary.find_child(node_name, true, false) != null,
					"build summary exposes " + node_name)
	var area_source := FileAccess.get_file_as_string("res://src/ui/area_select_screen.gd")
	check(area_source.contains("AscensionSelector") and area_source.contains("set_selected_ascension"),
			"expedition selector exposes persistent Ascension controls")
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS  ", label)
	else:
		failures += 1
		print("FAIL  ", label)
