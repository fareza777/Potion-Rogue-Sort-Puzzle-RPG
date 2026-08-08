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
	check(meta.weekly_seed("2026-W29") == meta.weekly_seed("2026-W29"),
			"weekly seed is stable for the same week")
	check(meta.weekly_seed("2026-W29") != meta.weekly_seed("2026-W30"),
			"weekly seed rotates between weeks")
	for index in 25:
		meta.record_run({"seed": index, "result": "defeat"})
	var history := meta.history()
	check(history.size() == 20 and int(history[0].seed) == 24 and int(history[-1].seed) == 5,
			"history is capped at 20 newest-first records")
	check(meta.complete_mastery("shadow_crypt", "first_clear") == 10,
			"first mastery completion rewards crystals")
	check(meta.complete_mastery("shadow_crypt", "first_clear") == 0,
			"mastery rewards are idempotent")
	check(meta.add_area_mastery("shadow_crypt", 35) == 35,
			"area mastery XP is recorded")
	check(meta.area_mastery_rank("shadow_crypt") == 1,
			"mastery XP unlocks a visible rank")
	var horizontal_ids := ["field_satchel", "scout_lens", "formula_primer",
			"emergency_cork", "wayfinder_seal"]
	for id in horizontal_ids:
		var perk: Dictionary = RunState.perma_pool.get(id, {})
		check(str(perk.get("category", "")) == "horizontal"
				and int(perk.get("max_level", 0)) == 1,
				"horizontal mastery is one-level and non-stat: " + id)
	SaveSystem.data.perma = {"field_satchel":1}
	RunState.run_mode = "normal"
	check(RunState.horizontal_perk("field_satchel"),
			"horizontal mastery applies to normal expeditions")
	RunState.run_mode = "daily"
	check(not RunState.horizontal_perk("field_satchel"),
			"horizontal mastery stays out of comparable challenge modes")
	check(meta.complete_weekly("2026-W29", 1440) > 0,
			"weekly clear records a one-time reward")
	check(meta.complete_weekly("2026-W29", 9999) == 0,
			"weekly reward cannot be claimed twice")
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
	check(SaveSystem.DEFAULT_DATA.has("daily") and SaveSystem.DEFAULT_DATA.has("run_history")
			and SaveSystem.DEFAULT_DATA.has("area_mastery")
			and SaveSystem.DEFAULT_DATA.has("weekly_records"),
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
