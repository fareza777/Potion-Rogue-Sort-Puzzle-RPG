extends Node

const SHADOW_V2 := "res://assets/art/backgrounds/shadow_crypt_battle_v2.png"
var checks := 0
var failures := 0


func _ready() -> void:
	check(ResourceLoader.exists(SHADOW_V2), "Shadow Crypt v2 asset imports")
	if ResourceLoader.exists(SHADOW_V2):
		var texture := load(SHADOW_V2) as Texture2D
		check(texture != null and texture.get_height() > texture.get_width(),
				"Shadow Crypt v2 is portrait full-height art")
		check(texture.get_width() >= 576 and texture.get_height() >= 1024,
				"Shadow Crypt v2 meets phone rendering resolution")
	var area := GameState.area("shadow_crypt")
	check(str(area.get("background", "")) == SHADOW_V2, "first realm uses v2 art")
	var readability: Dictionary = area.get("readability", {})
	check(float(readability.get("center_quiet_width", 0.0)) >= 0.42 \
			and str(readability.get("foreground", "")) == "detailed",
			"area records central readability and detailed foreground contract")
	check(ResourceLoader.exists("res://assets/art/backgrounds/shadow_crypt_battle.png"),
			"original Shadow art remains available as fallback")
	finish()


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS  ", label)
	else: failures += 1; print("FAIL  ", label)


func finish() -> void:
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
