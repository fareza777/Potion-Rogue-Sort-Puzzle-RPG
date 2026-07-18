extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	var original := SaveSystem.data.duplicate(true)
	SaveSystem.data = SaveSystem.DEFAULT_DATA.duplicate(true)
	var meta := MetaProgression.new()
	check(meta.daily_seed("2026-07-18") == meta.daily_seed("2026-07-18"),
			"daily seed is stable for a calendar day")
	check(meta.daily_seed("2026-07-18") != meta.daily_seed("2026-07-19"),
			"daily seed rotates the next day")
	for index in 25:
		meta.record_run({"seed": index, "result": "defeat"})
	var history := meta.history()
	check(history.size() == 20 and int(history[0].seed) == 24 and int(history[-1].seed) == 5,
			"history is capped at 20 newest-first records")
	check(meta.complete_mastery("shadow_crypt", "first_clear") == 10,
			"first mastery completion rewards crystals")
	check(meta.complete_mastery("shadow_crypt", "first_clear") == 0,
			"mastery rewards are idempotent")
	check(meta.can_rematch("shadow_crypt") == false, "boss rematch starts locked")
	check(meta.has_method("ascension_unlocked") and not meta.call("ascension_unlocked"),
			"Ascension starts locked before the campaign is cleared")
	SaveSystem.data.completed_areas = ["shadow_crypt"]
	check(meta.can_rematch("shadow_crypt"), "cleared boss unlocks rematch")
	SaveSystem.data.completed_areas = GameState.area_ids()
	check(meta.has_method("record_ascension_clear"), "Ascension exposes bounded unlock progress")
	if meta.has_method("ascension_unlocked") and meta.has_method("record_ascension_clear"):
		check(meta.call("ascension_unlocked"), "clearing all realms unlocks Ascension")
		check(int(meta.call("record_ascension_clear", 0)) == 1,
				"first Ascension clear unlocks level one")
		SaveSystem.data.max_ascension = 10
		check(int(meta.call("record_ascension_clear", 10)) == 10,
				"Ascension progression is capped at ten")
	check(SaveSystem.DEFAULT_DATA.has("daily") and SaveSystem.DEFAULT_DATA.has("run_history"),
			"new replay systems have migrated save defaults")
	SaveSystem.data = original
	SaveSystem.save()
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS  ", label)
	else:
		failures += 1
		print("FAIL  ", label)
