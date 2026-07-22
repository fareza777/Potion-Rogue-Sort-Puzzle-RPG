extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	get_viewport().size = Vector2i(576, 1280)
	var guide: Control = load("res://scenes/guide.tscn").instantiate()
	add_child(guide)
	await get_tree().process_frame
	await get_tree().process_frame
	var tab_scroll := guide.find_child("GuideTabScroll", true, false) as ScrollContainer
	var content_scroll := guide.find_child("GuideScroll", true, false) as ScrollContainer
	check(tab_scroll != null and tab_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER,
			"Guide tabs hide the horizontal scrollbar")
	check(content_scroll != null and content_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER,
			"Guide content hides the vertical scrollbar")
	check(guide.has_method("_input"), "Guide provides whole-area drag scrolling")
	if guide.has_method("open_section"):
		await guide.call("open_section", "reactions")
		await get_tree().process_frame
	if guide.has_method("_input") and tab_scroll != null and content_scroll != null:
		var horizontal := InputEventScreenDrag.new()
		horizontal.position = tab_scroll.get_global_rect().get_center()
		horizontal.relative = Vector2(-120, 0)
		guide.call("_input", horizontal)
		check(tab_scroll.scroll_horizontal > 0, "Dragging anywhere on tabs scrolls horizontally")
		var vertical := InputEventScreenDrag.new()
		vertical.position = content_scroll.get_global_rect().get_center()
		vertical.relative = Vector2(0, -140)
		guide.call("_input", vertical)
		check(content_scroll.scroll_vertical > 0, "Dragging anywhere on Guide cards scrolls vertically")
	else:
		check(false, "Dragging anywhere on tabs scrolls horizontally")
		check(false, "Dragging anywhere on Guide cards scrolls vertically")
	var codex_source := FileAccess.get_file_as_string("res://src/ui/reaction_codex_screen.gd")
	check(codex_source.contains("SCROLL_MODE_SHOW_NEVER")
			and codex_source.contains("InputEventScreenDrag"),
			"Formula Codex also hides its bar and accepts whole-area drag")
	check(codex_source.contains("description, 17"),
			"Formula descriptions use the larger Guide narrative size")
	var nav := BottomNav.new(); add_child(nav)
	var nav_button := nav.add_item("home", "Home", Callable(), true)
	check(nav_button.get_theme_font_size("font_size") >= 14,
			"Bottom navigation captions use a readable font")
	var narrative := UiKit.label("Readable narrative", 16)
	check(narrative.get_theme_font_size("font_size") >= 17,
			"Standard narrative text receives a moderate global increase")
	guide.queue_free(); nav.queue_free(); narrative.queue_free()
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS  " + label)
	else: failures += 1; push_error("FAIL  " + label)
