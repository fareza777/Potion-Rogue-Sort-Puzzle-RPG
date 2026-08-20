extends Node
## AdService has to be inert wherever the AdMob plugin is absent — editor,
## desktop, headless CI — and it has to keep its frequency caps honest so
## interstitials can never stack up on a player.

var checks := 0
var failures := 0


func _ready() -> void:
	var original := SaveSystem.data.duplicate(true)
	SaveSystem.data = SaveSystem.DEFAULT_DATA.duplicate(true)

	check(not AdService.is_active(),
			"no AdMob plugin means no ads and no crashes")
	check(not AdService.rewarded_ready(),
			"rewarded offers stay hidden without a loaded ad")
	check(not AdService.show_rewarded(AdService.PLACEMENT_SECOND_WIND),
			"a rewarded request without a plugin fails instead of pretending")
	AdService.notify_battle_finished(false)
	check(not AdService.maybe_show_interstitial(),
			"an interstitial is never claimed without a plugin")
	check(not AdService.open_privacy_options(),
			"the privacy form reports honestly when it is unavailable")
	# Every one of these is a no-op here; the point is that none of them throw.
	AdService.show_banner()
	AdService.hide_banner()
	check(true, "banner calls are safe with no plugin present")

	var config := AdService.config
	check(config.has("unit_ids") and config.has("interstitial"),
			"ad configuration loads from res://data/ads.json")
	var interstitial: Dictionary = config.get("interstitial", {})
	check(int(interstitial.get("min_battles_between", 0)) >= 2,
			"interstitials are spaced at least two battles apart")
	check(int(interstitial.get("min_seconds_between", 0)) >= 60,
			"interstitials are spaced at least a minute apart")
	check(int(interstitial.get("skip_first_battles", 0)) >= 1,
			"a brand new player is not shown an interstitial immediately")
	check(bool(interstitial.get("skip_boss_victory", false)),
			"a boss clear is never interrupted by an interstitial")
	check(AdService.second_wind_per_run() >= 1
			and AdService.second_wind_hp_percent() > 0.0,
			"the rewarded revive is configured with a real benefit")

	for scene in AdService.BANNER_SCENES:
		check(ResourceLoader.exists(str(scene)),
				"banner scene %s exists" % str(scene))
	for forbidden in ["res://scenes/battle.tscn", "res://scenes/map.tscn",
			"res://scenes/event.tscn", "res://scenes/storyboard_player.tscn"]:
		check(forbidden not in AdService.BANNER_SCENES,
				"%s never carries a banner" % forbidden)

	# Entitlement flows from Billing through AdService without the game asking.
	SaveSystem.set_ads_removed(true)
	BillingService.refresh_entitlement_from_save()
	check(AdService.ads_removed(),
			"buying Remove Ads switches the ad surface off everywhere")

	var battle_source := FileAccess.get_file_as_string("res://src/ui/battle_screen.gd")
	check(battle_source.contains("_second_wind_available"),
			"defeat offers the rewarded revive before failing the run")
	check(battle_source.contains("AdService.maybe_show_interstitial()"),
			"the interstitial lands on the reward-to-map break")
	check(not battle_source.contains("AdService.show_banner"),
			"battle never asks for a banner")

	SaveSystem.data = original
	BillingService.refresh_entitlement_from_save()
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
