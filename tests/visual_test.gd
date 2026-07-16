extends Node
## Headless presentation contract tests. These exercise resource lookup and
## presentation fallbacks without coupling visual code to battle outcomes.

var _failures := 0
var _checks := 0


func _ready() -> void:
	check(VisualRegistry.enemy("slime").get("sprite", "") != "",
			"slime sprite mapping")
	for enemy_id in GameState.enemies:
		check(not VisualRegistry.enemy(str(enemy_id)).is_empty(),
				"enemy mapping: " + str(enemy_id))
	for color in GameState.potions:
		check(not VisualRegistry.potion(str(color)).is_empty(),
				"potion mapping: " + str(color))
	check(VisualRegistry.texture_or_null("res://missing.png") == null,
			"missing texture fallback")
	var missing := VisualRegistry.missing_runtime_assets()
	check(missing.is_empty(),
			"registered runtime assets exist: " + ", ".join(missing))
	for path in [
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
