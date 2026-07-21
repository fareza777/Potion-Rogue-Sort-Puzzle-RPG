extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	var nav := BottomNav.new(); add_child(nav)
	check(nav.has_method("icon_width_for"), "dock exposes responsive icon sizing")
	if nav.has_method("icon_width_for"):
		check(nav.icon_width_for(576.0) == 70, "narrow dock uses 70 px icons")
		check(nav.icon_width_for(720.0) == 76, "wide dock uses 76 px icons")
	var button := nav.add_item("home", "Home", Callable(), true)
	check(button.custom_minimum_size.y >= 104, "icon and caption receive vertical room")
	check(button.get_theme_stylebox("normal").border_width_left == 0,
			"active item does not use a box border")
	check(button.expand_icon, "dock preserves icon aspect ratio")
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS  " + label)
	else: failures += 1; push_error("FAIL  " + label)
