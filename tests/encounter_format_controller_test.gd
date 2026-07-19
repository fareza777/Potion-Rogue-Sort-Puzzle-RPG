extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	var multi := EncounterFormatController.new()
	multi.configure({"format":"multi_wave", "waves":2})
	check(multi.title() == "TWIN ASSAULT", "multi-wave has clear player-facing title")
	check(multi.on_enemy_defeated() == "next_wave", "first defeat advances the wave")
	check(multi.on_enemy_defeated() == "victory", "last wave completes the encounter")
	var survival := EncounterFormatController.new()
	survival.configure({"format":"survival"})
	check(survival.on_enemy_action() == "continue", "survival tracks early attacks")
	survival.on_enemy_action()
	check(survival.on_enemy_action() == "victory", "survival ends after three enemy actions")
	var cauldron := EncounterFormatController.new()
	cauldron.configure({"format":"protect_cauldron"})
	cauldron.on_potion_completed(); cauldron.on_potion_completed()
	check(cauldron.on_potion_completed() == "victory", "three potions protect the cauldron")
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS  ", label)
	else: failures += 1; print("FAIL  ", label)
