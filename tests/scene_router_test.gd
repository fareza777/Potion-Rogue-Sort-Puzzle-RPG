extends Node
## Guards the transition layer that removed the grey flash between scenes:
## every screen must route through SceneRouter, and the veil must always end
## fully transparent so a failed load can never strand the player behind it.

const ROUTED_SCREENS := ["main_menu", "area_select_screen", "settings_screen",
	"shop_screen", "run_history_screen", "credits_screen", "guide_screen",
	"map_screen", "event_screen", "kit_select_screen", "reaction_codex_screen",
	"onboarding_screen", "battle_screen", "battle/battle_navigation"]

var checks := 0
var failures := 0


func _ready() -> void:
	check(ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color")
			!= null, "the project pins an explicit clear colour")
	var clear: Color = ProjectSettings.get_setting(
			"rendering/environment/defaults/default_clear_color", Color(0.3, 0.3, 0.3))
	# Godot's stock clear colour is a mid grey. Leaving it in place is exactly
	# what flashed between scenes on device.
	check(clear.get_luminance() < 0.06,
			"the clear colour matches the game's ink, not engine grey")

	for screen in ROUTED_SCREENS:
		var path := "res://src/ui/%s.gd" % screen
		check(ResourceLoader.exists(path), "%s exists to be checked" % screen)
		if not ResourceLoader.exists(path):
			continue
		var source := FileAccess.get_file_as_string(path)
		check(not source.contains("change_scene_to_file"),
				"%s routes scene changes through SceneRouter" % screen)

	var veil := SceneRouter.get_node_or_null("TransitionVeil") as ColorRect
	check(veil != null, "the router owns a full-screen veil")
	check(veil != null and not veil.visible and is_zero_approx(veil.modulate.a),
			"the veil starts hidden")

	await SceneRouter.reveal(0.05)
	check(is_zero_approx(veil.modulate.a), "reveal ends fully transparent")

	# The router streams the destination itself; a real go_to() would replace
	# this very test scene, so only the loader is exercised directly here.
	var streamed: PackedScene = await SceneRouter.call("_load_threaded",
			"res://scenes/main_menu.tscn")
	check(streamed is PackedScene, "the router streams a real scene off-thread")
	var missing: Variant = await SceneRouter.call("_load_threaded",
			"res://scenes/does_not_exist.tscn")
	check(missing == null, "a missing scene fails cleanly instead of hanging")

	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("PASS  ", label)
	else:
		failures += 1
		print("FAIL  ", label)
