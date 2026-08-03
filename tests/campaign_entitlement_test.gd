extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	var original := SaveSystem.data.duplicate(true)
	SaveSystem.data = SaveSystem.DEFAULT_DATA.duplicate(true)
	check(not SaveSystem.full_campaign_unlocked(),
			"fresh profiles start without the full campaign entitlement")
	check(SaveSystem.is_area_unlocked("shadow_crypt"),
			"fresh profiles can enter Shadow Crypt")
	check(not SaveSystem.is_area_unlocked("verdant_catacombs"),
			"fresh profiles keep later realms locked")

	SaveSystem.set_full_campaign_unlocked(true)
	check(SaveSystem.full_campaign_unlocked(),
			"the full campaign entitlement persists in memory")
	for area_id in GameState.area_ids():
		check(SaveSystem.is_area_unlocked(str(area_id)),
			"entitlement unlocks authored realm %s" % str(area_id))
	check(SaveSystem.completed_areas().is_empty(),
			"entitlement does not mark realms as completed")
	check(not SaveSystem.is_area_unlocked("not_an_area"),
			"unknown area ids remain locked")

	var legacy := {"version": 11, "unlocked_areas": ["shadow_crypt"]}
	var migrated := SaveSystem.migrate(legacy)
	check(not bool(migrated.get("full_campaign_unlocked", true)),
			"version 11 saves default the entitlement to locked")

	SaveSystem.data = original
	SaveSystem.save()
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("PASS  ", label)
	else:
		failures += 1
		print("FAIL  ", label)
