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
