extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	_test_stuck_remainder_gets_a_playable_remix()
	await _test_area_list_has_a_real_scroll_range()
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _test_stuck_remainder_gets_a_playable_remix() -> void:
	var stuck: Array = [["red"], ["green"], [], [], [], []]
	var result := BoardFactory.remix(stuck, 1907, "standard")
	var remixed: Array = result.get("state", [])
	var analysis := BoardSolver.analyze(remixed)
	check(remixed != stuck,
			"New Mix visibly replaces an unrecoverable two-color remainder")
	check(bool(analysis.get("solvable", false)) and int(analysis.get("estimated_moves", -1)) > 0,
			"New Mix recovery always produces a playable unsolved board")


func _test_area_list_has_a_real_scroll_range() -> void:
	var screen := preload("res://scenes/area_select.tscn").instantiate() as Control
	add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	var scroll := screen.find_child("ExpeditionScroll", true, false) as ScrollContainer
	var list := scroll.get_child(0) as Control if scroll and scroll.get_child_count() else null
	var bar := scroll.get_v_scroll_bar() if scroll else null
	check(scroll != null and list != null and bar != null,
			"Areas builds an explicit vertical scroll viewport")
	if scroll and list and bar:
		check(scroll.size.y > 0.0 and list.size.y > scroll.size.y \
				and bar.max_value > bar.page,
				"Areas content exceeds the viewport and exposes scroll range")
		var target := int(bar.max_value - bar.page)
		scroll.scroll_vertical = target
		await get_tree().process_frame
		check(target > 0 and scroll.scroll_vertical > 0,
				"Areas viewport can move away from the top position")
		scroll.scroll_vertical = 0
		var drag := InputEventScreenDrag.new()
		drag.position = scroll.global_position + scroll.size * 0.5
		drag.relative = Vector2(0, -180)
		var has_touch_fallback := screen.has_method("_unhandled_input")
		if has_touch_fallback:
			screen.call("_unhandled_input", drag)
		await get_tree().process_frame
		check(has_touch_fallback and scroll.scroll_vertical > 0,
				"Areas has a touch-drag fallback when card controls intercept the swipe")
	screen.queue_free()


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("PASS  ", label)
	else:
		failures += 1
		print("FAIL  ", label)
