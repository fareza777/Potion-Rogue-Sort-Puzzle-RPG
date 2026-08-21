extends Node
## AdService has to be inert wherever the AdMob plugin is absent — editor,
## desktop, headless CI — and it has to keep its frequency caps honest so
## interstitials can never stack up on a player.

var checks := 0
var failures := 0


class FakeAdmob:
	extends Node
	var banner_load_calls := 0
	var banner_hide_calls := 0

	func load_banner_ad() -> void:
		banner_load_calls += 1

	func hide_banner_ad() -> void:
		banner_hide_calls += 1


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
	check(not bool(config.get("test_mode", true)),
			"release ad configuration uses production mode")
	check(config.get("android_app_id", "") == "ca-app-pub-6279186647593327~2300822678",
			"release ad configuration uses the Potion Rogue AdMob app id")
	var unit_ids: Dictionary = config.get("unit_ids", {})
	check(unit_ids.get("banner", "") == "ca-app-pub-6279186647593327/2085929206"
			and unit_ids.get("interstitial", "") == "ca-app-pub-6279186647593327/5833602524"
			and unit_ids.get("rewarded", "") == "ca-app-pub-6279186647593327/6763540816",
			"release ad configuration uses all three Potion Rogue ad units")
	# The vendor Admob._init() builds every AdCache. GDScript does not chain
	# _init() implicitly, so an override that forgets super() leaves them null
	# and every ad callback dies before it can emit — ads silently never load.
	var runtime = load("res://src/autoload/admob_runtime.gd").new()
	var caches_built := true
	for cache_name in ["_active_banner_ads", "_active_interstitial_ads",
			"_active_rewarded_ads"]:
		caches_built = caches_built and runtime.get(cache_name) != null
	check(caches_built,
			"AdmobRuntime chains super() so the vendor ad caches exist")
	runtime.free()

	var project_source := FileAccess.get_file_as_string("res://project.godot")
	check(project_source.contains("res://addons/AdmobPlugin/plugin.cfg"),
			"the AdMob Android export plugin is enabled")
	check(ResourceLoader.exists("res://scenes/admob_runtime.tscn"),
			"the runtime Admob node is present in the project")
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

	check(AdService.has_method("should_reserve_banner")
			and AdService.has_method("banner_reserve_px")
			and AdService.has_method("is_banner_scene"),
			"banner layout can ask whether to reserve bottom space")
	check(not AdService.should_reserve_banner() and AdService.banner_reserve_px() == 0,
			"desktop/headless never reserves a native banner strip")
	check(AdService.is_banner_scene("res://scenes/main_menu.tscn")
			and AdService.is_banner_scene("main_menu.tscn"),
			"banner scenes match by path or filename")
	check(not AdService.is_banner_scene("res://scenes/battle.tscn"),
			"battle is never treated as a banner scene")
	for scene in AdService.BANNER_SCENES:
		check(ResourceLoader.exists(str(scene)),
				"banner scene %s exists" % str(scene))
	for forbidden in ["res://scenes/battle.tscn", "res://scenes/map.tscn",
			"res://scenes/event.tscn", "res://scenes/storyboard_player.tscn"]:
		check(forbidden not in AdService.BANNER_SCENES,
				"%s never carries a banner" % forbidden)

	var retry_service = load("res://src/autoload/ad_service.gd").new()
	add_child(retry_service)
	await get_tree().process_frame
	var fake_admob := FakeAdmob.new()
	retry_service.add_child(fake_admob)
	retry_service._plugin = fake_admob
	retry_service._initialized = true
	retry_service._ads_removed = false
	retry_service._banner_wanted = true
	retry_service._on_banner_failed()
	var retry_timer := retry_service.find_child("BannerRetryTimer", true, false) as Timer
	check(retry_timer != null and not retry_timer.is_stopped(),
			"a failed banner load schedules a bounded retry")
	if retry_timer != null:
		retry_timer.timeout.emit()
	check(fake_admob.banner_load_calls == 1,
			"banner retry asks the real plugin boundary to load again")
	retry_service._banner_loaded = false
	retry_service.hide_banner()
	check(fake_admob.banner_hide_calls == 0,
			"hiding an unloaded banner does not call the plugin")
	retry_service.queue_free()

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
	check(battle_source.contains("_restore_battle_clock"),
			"battle restores time scale before leaving the fight")
	var log_source := FileAccess.get_file_as_string("res://src/ui/battle/battle_log.gd")
	check(not log_source.contains("PopupPanel.new()")
			and not log_source.contains("extends PopupPanel"),
			"battle history never uses a native PopupPanel window")

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
