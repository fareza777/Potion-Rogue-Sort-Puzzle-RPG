extends Node

var checks := 0
var failures := 0
var _original_run: Dictionary


func _ready() -> void:
	_test_remix_wait_budget()
	_test_clean_bottle_rendering()
	await _test_dungeon_route_scrolls_on_touch()
	_test_launch_experience_contract()
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _test_remix_wait_budget() -> void:
	var jobs := RemixJobController.new()
	var budget: Variant = jobs.get("timeout_ms")
	check(typeof(budget) == TYPE_INT and budget >= 6000,
			"mobile remix keeps waiting long enough for the solver")


func _test_clean_bottle_rendering() -> void:
	var source := FileAccess.get_file_as_string("res://src/puzzle/potion_tube.gd")
	# Valid pour targets may glow, but darkening masks over other tubes are
	# still banned: absence of glow is the signal for illegal targets.
	check(source.contains('guidance_state == "valid"')
			and not source.contains('guidance_state == "dim"'),
			"potion guidance glows valid targets and never draws black masks")


func _test_dungeon_route_scrolls_on_touch() -> void:
	_original_run = RunState.serialize_boundary()
	RunState.pending_area_id = "shadow_crypt"
	RunState.start_new_run("ember_adept", "shadow_crypt", "normal", 774411)
	var screen := preload("res://scenes/map.tscn").instantiate() as Control
	add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	var scroll := screen.find_child("DungeonRouteScroll", true, false) as ScrollContainer
	var bar := scroll.get_v_scroll_bar() if scroll else null
	check(scroll != null and bar != null and bar.max_value > bar.page,
			"dungeon route owns a real vertical scroll range")
	if scroll and bar:
		check(scroll.scroll_vertical > 0,
				"dungeon route opens near the current chamber instead of the hidden boss")
		scroll.scroll_vertical = 0
		var drag := InputEventScreenDrag.new()
		drag.position = scroll.global_position + scroll.size * 0.5
		drag.relative = Vector2(0, -180)
		screen.call("_unhandled_input", drag)
		await get_tree().process_frame
		check(scroll.scroll_vertical > 0,
				"touch drag scrolls the dungeon route even over node buttons")
	screen.queue_free()
	RunState.resume_from_save(_original_run)


func _test_launch_experience_contract() -> void:
	check(FileAccess.file_exists("res://assets/art/app_icon_v2.png"),
			"generated premium app icon is stored in the project")
	check(FileAccess.file_exists("res://assets/art/backgrounds/launch_splash_v2.jpg"),
			"generated portrait splash art is stored in the project")
	check(FileAccess.file_exists("res://scenes/boot.tscn")
			and FileAccess.file_exists("res://scenes/onboarding.tscn"),
			"boot splash and onboarding scenes exist")
	var onboarding_script := load("res://src/ui/onboarding_screen.gd") as Script
	check(onboarding_script != null and onboarding_script.can_instantiate(),
			"onboarding controller parses and can instantiate")
	check(SaveSystem.DEFAULT_DATA.has("onboarding_done"),
			"onboarding completion is persisted")
	var project := FileAccess.get_file_as_string("res://project.godot")
	check(project.contains('run/main_scene="res://scenes/boot.tscn"')
			and project.contains('config/icon="res://assets/art/app_icon_v2.png"'),
			"project launches through the new branded boot flow")


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS  ", label)
	else: failures += 1; print("FAIL  ", label)
