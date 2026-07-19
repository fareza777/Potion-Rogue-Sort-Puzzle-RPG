extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	var settings: Dictionary = SaveSystem.DEFAULT_DATA.settings
	check(settings.has("text_scale") and settings.has("high_contrast"),
			"text scale and high contrast persist in save data")
	var button := UiKit.button("TEST", Vector2(20, 20))
	check(button.custom_minimum_size.y >= 56 and button.focus_mode == Control.FOCUS_ALL,
			"primary buttons enforce touch and keyboard minimums")
	check(button.has_theme_stylebox_override("focus"), "primary buttons have explicit focus art")
	var dim_ratio := UiThemeTokens.contrast_ratio(UiKit.COLOR_TEXT_DIM, UiKit.COLOR_BG)
	check(dim_ratio >= 4.5, "normal secondary text token reaches 4.5:1 contrast")
	var kit := UiKit.new()
	check(kit.has_method("scaled_text_size") and kit.has_method("accessible_color"),
			"UI factories expose saved text and contrast policy")
	var settings_source := FileAccess.get_file_as_string("res://src/ui/settings_screen.gd")
	check(settings_source.contains('name = "TextScaleRow"') \
			and settings_source.contains('name = "HighContrastRow"'),
			"settings presents text scale and high contrast controls")
	var ambient := AmbientParticles.new(); add_child(ambient)
	ambient.set_reduced_effects(true)
	check(not ambient.is_processing(), "Reduced Effects stops continuous ambient motion")
	var enemy := EnemyDisplay.new(); add_child(enemy); enemy.set_reduced_effects(true)
	check(not enemy.is_processing(), "Reduced Effects stops continuous enemy idle motion")
	var tube_source := FileAccess.get_file_as_string("res://src/puzzle/potion_tube.gd")
	check(tube_source.contains("has_focus()"), "potion tube renders authored keyboard focus")
	button.free(); ambient.queue_free(); enemy.queue_free()
	finish()


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS  ", label)
	else: failures += 1; print("FAIL  ", label)


func finish() -> void:
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
