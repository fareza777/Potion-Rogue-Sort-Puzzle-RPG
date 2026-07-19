extends Node

const FILES := [
	"res://src/ui/battle/encounter_coordinator.gd",
	"res://src/ui/battle/battle_hud_presenter.gd",
	"res://src/ui/battle/battle_overlay_controller.gd",
	"res://src/ui/battle/battle_navigation.gd",
]
var checks := 0
var failures := 0


func _ready() -> void:
	for path in FILES: check(FileAccess.file_exists(path), "battle collaborator exists: " + path.get_file())
	if failures > 0: finish(); return
	var encounter = load(FILES[0]).new()
	check(encounter.has_method("configure") and encounter.has_method("snapshot") \
			and encounter.has_method("restore"), "encounter owns snapshot round-trip")
	var hud = load(FILES[1]).new()
	check(hud.has_method("build") and hud.has_method("refresh"), "HUD owns build and refresh")
	var overlay = load(FILES[2]).new()
	check(overlay.has_method("show_reward") and overlay.has_method("show_pause") \
			and overlay.has_method("hide"), "overlay owns reward and pause states")
	var navigation = load(FILES[3]).new()
	check(navigation.has_method("go_to_map") and navigation.has_method("go_to_menu") \
			and navigation.has_method("go_to_area_select"), "navigation owns battle destinations")
	var source := FileAccess.get_file_as_string("res://src/ui/battle_screen.gd")
	for collaborator in ["EncounterCoordinator", "BattleHudPresenter", "BattleOverlayController", "BattleNavigation"]:
		check(source.contains(collaborator), "battle screen composes " + collaborator)
	check(source.contains("battle.on_move()") and source.contains("1 move spent"),
			"New Mix still consumes one combat move")
	finish()


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS  ", label)
	else: failures += 1; print("FAIL  ", label)


func finish() -> void:
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
