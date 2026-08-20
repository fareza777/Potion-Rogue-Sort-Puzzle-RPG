extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	var original := SaveSystem.data.duplicate(true)
	SaveSystem.data = SaveSystem.DEFAULT_DATA.duplicate(true)
	check(not SaveSystem.ads_removed(),
			"fresh profiles start with ads enabled")
	check(SaveSystem.is_area_unlocked("shadow_crypt"),
			"fresh profiles can enter Shadow Crypt")
	check(not SaveSystem.is_area_unlocked("verdant_catacombs"),
			"fresh profiles keep later realms locked")

	SaveSystem.set_ads_removed(true)
	check(SaveSystem.ads_removed(),
			"the Remove Ads entitlement persists in memory")
	check(not SaveSystem.is_area_unlocked("verdant_catacombs"),
			"Remove Ads never unlocks campaign content")
	check(SaveSystem.completed_areas().is_empty(),
			"the entitlement does not mark realms as completed")
	check(not SaveSystem.is_area_unlocked("not_an_area"),
			"unknown area ids remain locked")

	var ids := GameState.area_ids()
	check(SaveSystem.next_locked_area() == str(ids[1]),
			"the next sealed realm follows campaign order")
	check(not SaveSystem.unlock_area_early(str(ids[3])),
			"the rewarded shortcut refuses to skip ahead")
	check(SaveSystem.unlock_area_early(str(ids[1])),
			"the rewarded shortcut opens exactly the next realm")
	check(SaveSystem.is_area_unlocked(str(ids[1])),
			"the shortcut persists the newly opened realm")
	check(SaveSystem.next_locked_area() == str(ids[2]),
			"the shortcut advances the sealed frontier by one")

	var legacy := {"version": 11, "unlocked_areas": ["shadow_crypt"]}
	var migrated := SaveSystem.migrate(legacy)
	check(not bool(migrated.get("ads_removed", true)),
			"version 11 saves default to ads enabled")
	check(not migrated.has("full_campaign_unlocked"),
			"the retired campaign flag is dropped on migration")

	var paid := {"version": 12, "unlocked_areas": ["shadow_crypt"],
			"full_campaign_unlocked": true}
	var upgraded := SaveSystem.migrate(paid)
	check(bool(upgraded.get("ads_removed", false)),
			"campaign buyers keep an ad-free game")
	for area_id in GameState.area_ids():
		check(str(area_id) in (upgraded.get("unlocked_areas", []) as Array),
			"campaign buyers keep realm %s" % str(area_id))

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
