extends Node
## Headless presentation contract tests. These exercise resource lookup and
## presentation fallbacks without coupling visual code to battle outcomes.

var _failures := 0
var _checks := 0


func _ready() -> void:
	check(VisualRegistry.enemy("slime").get("sprite", "") != "",
			"slime sprite mapping")
	for enemy_id in GameState.enemies:
		var enemy_style := VisualRegistry.enemy(str(enemy_id))
		check(not enemy_style.is_empty(), "enemy mapping: " + str(enemy_id))
		check(str(enemy_style.get("sprite", "")) != "",
				"enemy sprite path: " + str(enemy_id))
		check(str(enemy_style.get("motion_profile", "")) in [
			"elastic", "brittle", "pounce", "heavy", "caster", "inferno",
		], "enemy motion profile: " + str(enemy_id))
	for color in GameState.potions:
		check(not VisualRegistry.potion(str(color)).is_empty(),
				"potion mapping: " + str(color))
	check(VisualRegistry.texture_or_null("res://missing.png") == null,
			"missing texture fallback")
	var missing := VisualRegistry.missing_runtime_assets()
	check(missing.is_empty(),
			"registered runtime assets exist: " + ", ".join(missing))
	for path in [
		"res://assets/art/app_icon.png",
		"res://assets/art/backgrounds/shadow_crypt_battle.png",
		"res://assets/art/potions/bottle_frame.png",
		"res://assets/art/ui/battle_panel.png",
		"res://assets/art/ui/banner_turn.png",
		"res://assets/art/ui/button_round.png",
		"res://assets/art/ui/icon_undo.png",
		"res://assets/art/ui/icon_remix.png",
		"res://assets/art/ui/icon_pause.png",
	]:
		check(ResourceLoader.exists(path), "loadable art: " + path)
	check(ProjectSettings.get_setting("application/config/icon", "") ==
			"res://assets/art/app_icon.png", "branded application icon configured")
	var enemy_view := EnemyDisplay.new()
	add_child(enemy_view)
	enemy_view.custom_minimum_size = Vector2(520, 300)
	check(enemy_view.has_method("configure_enemy"), "enemy configuration interface")
	check(enemy_view.has_method("play_intro"), "enemy intro interface")
	check(enemy_view.has_method("play_anticipate"), "enemy anticipate interface")
	check(enemy_view.has_method("play_attack"), "enemy attack interface")
	check(enemy_view.has_method("play_defeat"), "enemy defeat interface")
	if enemy_view.has_method("configure_enemy") and enemy_view.has_method("uses_sprite_art"):
		enemy_view.call("configure_enemy", "slime", "slime", "6fce4e")
		check(bool(enemy_view.call("uses_sprite_art")), "slime uses registered sprite")
	else:
		check(false, "slime uses registered sprite")
	var expected_profiles := {
		"slime": "elastic",
		"skeleton": "brittle",
		"poison_beast": "pounce",
		"stone_golem": "heavy",
		"dark_mage": "caster",
		"blood_slime": "elastic",
		"fire_golem": "inferno",
	}
	check(enemy_view.has_method("motion_profile"), "enemy motion profile interface")
	if enemy_view.has_method("motion_profile"):
		for enemy_id in expected_profiles:
			enemy_view.call("configure_enemy", enemy_id, enemy_id, "ffffff")
			check(enemy_view.call("motion_profile") == expected_profiles[enemy_id],
					"enemy display profile: " + enemy_id)
	enemy_view.queue_free()
	var potion_view := PotionTube.new()
	add_child(potion_view)
	check(potion_view.has_method("flash_complete"), "potion complete animation interface")
	check(potion_view.has_method("play_invalid"), "potion invalid animation interface")
	potion_view.queue_free()
	var fx := BattleFx.new()
	add_child(fx)
	check(fx.has_method("hit"), "battle hit effect interface")
	check(fx.has_method("pour"), "battle pour effect interface")
	check(fx.has_method("heal"), "battle heal effect interface")
	check(fx.has_method("shield"), "battle shield effect interface")
	check(fx.has_method("poison"), "battle poison effect interface")
	check(fx.has_method("set_reduced_effects"), "reduced effects interface")
	if fx.has_method("set_reduced_effects"):
		fx.call("set_reduced_effects", true)
		check(bool(fx.get("reduced_effects")), "reduced effects state")
	else:
		check(false, "reduced effects state")
	fx.queue_free()
	var textured_panel := UiKit.textured_panel(
			"res://assets/art/ui/battle_panel.png", 26)
	check(textured_panel.custom_minimum_size.y > 0.0,
			"textured panel has minimum size")
	var icon_control := UiKit.icon_button(
			"res://assets/art/ui/icon_undo.png", 3, "Undo last pour")
	check(icon_control.tooltip_text == "Undo last pour", "icon button tooltip")
	check(icon_control.custom_minimum_size.x >= 84.0, "icon button touch target")
	var kit := UiKit.new()
	check(kit.has_method("ornate_button"), "ornate button factory")
	check(kit.has_method("enemy_portrait"), "enemy portrait factory")
	check(kit.has_method("map_node_button"), "map node factory")
	check(kit.has_method("layout_profile"), "responsive layout profile interface")
	if kit.has_method("layout_profile"):
		var standard: Dictionary = kit.call("layout_profile", Vector2(720, 1280))
		var tall: Dictionary = kit.call("layout_profile", Vector2(576, 1280))
		check(standard.get("name") == "standard", "standard portrait profile")
		check(tall.get("name") == "tall", "tall phone profile")
		var ratio_sum := float(tall.get("arena_ratio", 0.0)) \
				+ float(tall.get("status_ratio", 0.0)) \
				+ float(tall.get("board_ratio", 0.0)) \
				+ float(tall.get("controls_ratio", 0.0))
		check(is_equal_approx(ratio_sum, 1.0), "responsive battle bands fill height")
		check(float(tall.get("safe_horizontal", 0.0)) >= 20.0,
				"tall profile keeps safe margins")
	textured_panel.queue_free()
	icon_control.queue_free()
	print("---")
	print("%d checks, %d failures" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func check(condition: bool, what: String) -> void:
	_checks += 1
	if condition:
		print("PASS  ", what)
	else:
		_failures += 1
		print("FAIL  ", what)
