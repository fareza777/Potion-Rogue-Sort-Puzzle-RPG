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
	var interstitial_show_calls := 0
	var interstitial_ready := true

	var banner_remove_calls: Array[String] = []

	func load_banner_ad() -> void:
		banner_load_calls += 1

	func hide_banner_ad() -> void:
		banner_hide_calls += 1

	func remove_banner_ad(ad_id: String = "") -> void:
		banner_remove_calls.append(ad_id)

	func is_interstitial_ad_loaded() -> bool:
		return interstitial_ready

	func show_interstitial_ad() -> void:
		interstitial_show_calls += 1

	func load_interstitial_ad() -> void:
		pass


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
	check(unit_ids.get("banner", "") == ""
			and unit_ids.get("app_open", "") == ""
			and unit_ids.get("interstitial", "") == "ca-app-pub-6279186647593327/5833602524"
			and unit_ids.get("rewarded", "") == "ca-app-pub-6279186647593327/6763540816",
			"release ad configuration keeps only the interstitial and rewarded units")
	check(not bool(config.get("banner", {}).get("enabled", true)),
			"release ad configuration disables banner ads")
	check(not bool(config.get("app_open", {}).get("enabled", true)),
			"release ad configuration disables App Open ads")
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
	check(not AdService.is_banner_scene("res://scenes/main_menu.tscn")
			and not AdService.is_banner_scene("main_menu.tscn"),
			"retired banner scenes never reserve or show a banner")
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
	retry_service.config["banner"]["enabled"] = true
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
	# A banner the plugin still holds is always taken down, even when our own
	# flag says it is already hidden: a desynced flag is exactly what stranded
	# a banner over the battle board.
	retry_service._banner_loaded = true
	retry_service._banner_shown = false
	retry_service.hide_banner()
	check(fake_admob.banner_hide_calls == 1,
			"a loaded banner is hidden even if the shown flag desynced")
	fake_admob.banner_hide_calls = 0
	retry_service._interstitial_open = true
	retry_service._banner_shown = true
	retry_service.hide_banner()
	check(fake_admob.banner_hide_calls == 0,
			"no native view swap while a full-screen ad owns the activity")
	retry_service._interstitial_open = false

	# Only one banner request may be in flight. A second AdView would keep
	# drawing forever, because the vendor only ever hides its newest ad.
	retry_service._banner_loaded = false
	retry_service._banner_loading = false
	fake_admob.banner_load_calls = 0
	retry_service.show_banner()
	retry_service.show_banner()
	retry_service.show_banner()
	check(fake_admob.banner_load_calls == 1,
			"repeated show_banner calls never stack a second banner request")

	# Whatever slipped through before is destroyed, not merely hidden.
	retry_service._banner_ad_ids = ["stale-a", "stale-b"] as Array[String]
	retry_service._retire_stale_banners("fresh")
	var removed: Array = fake_admob.banner_remove_calls
	check(removed.size() == 2 and removed[0] == "stale-a" and removed[1] == "stale-b",
			"older banner AdViews are removed instead of left on screen")
	var tracked: Array = retry_service._banner_ad_ids
	check(tracked.size() == 1 and tracked[0] == "fresh",
			"only the newest banner id is tracked afterwards")
	retry_service.queue_free()

	var gate = load("res://src/autoload/ad_service.gd").new()
	add_child(gate)
	await get_tree().process_frame
	var presenter := FakeAdmob.new()
	gate._plugin = presenter
	gate._initialized = true
	gate._ads_removed = false
	gate._interstitial_loaded = true
	# The grace period counts lifetime wins, so a restart cannot reset it.
	SaveSystem.data["stats"] = {"battles_won": 4}
	gate._battles_completed = 0
	gate._battles_since_interstitial = 3
	gate._last_interstitial_ms = Time.get_ticks_msec() - 200_000
	gate.queue_break_interstitial()
	check(presenter.interstitial_show_calls == 0,
			"a queued interstitial does not show from the dying battle scene")
	check(gate._break_interstitial_pending,
			"an eligible break is armed for the map")

	# Winning while the caps still hold must not arm anything. Arming anyway
	# suspended the Android render loop and paused the tree for an ad that was
	# never going to run, from the very first victory onward.
	var blocked = load("res://src/autoload/ad_service.gd").new()
	add_child(blocked)
	await get_tree().process_frame
	var idle := FakeAdmob.new()
	blocked._plugin = idle
	blocked._initialized = true
	blocked._ads_removed = false
	blocked._interstitial_loaded = true
	SaveSystem.data["stats"] = {"battles_won": 1}
	blocked._battles_since_interstitial = 1
	blocked.notify_battle_finished(false)
	blocked.queue_break_interstitial()
	check(not blocked._break_interstitial_pending,
			"a win inside the grace period never arms the full-screen path")
	blocked._on_scene_changed("res://scenes/map.tscn")
	for _frame in 4:
		await get_tree().process_frame
	check(idle.interstitial_show_calls == 0 and not blocked._render_suspended,
			"the renderer is never suspended when no interstitial can run")
	blocked.queue_free()
	SaveSystem.data["stats"] = {"battles_won": 9}
	gate._on_scene_changed("res://scenes/map.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	check(presenter.interstitial_show_calls == 1,
			"the interstitial presents only after the map is live")
	presenter.interstitial_ready = false
	gate._interstitial_open = false
	gate._interstitial_loaded = true
	SaveSystem.data["stats"] = {"battles_won": 8}
	gate._battles_since_interstitial = 3
	gate._last_interstitial_ms = Time.get_ticks_msec() - 200_000
	check(not gate.maybe_show_interstitial(),
			"a stale loaded flag cannot show an empty interstitial cache")
	# A fresh launch must not hand a veteran player the newcomer grace period.
	presenter.interstitial_ready = true
	gate._interstitial_open = false
	gate._interstitial_loaded = true
	gate._battles_completed = 0
	SaveSystem.data["stats"] = {"battles_won": 2}
	check(not gate.maybe_show_interstitial(),
			"a newcomer under the lifetime grace period sees no interstitial")
	SaveSystem.data["stats"] = {"battles_won": 9}
	gate._battles_since_interstitial = 3
	gate._last_interstitial_ms = Time.get_ticks_msec() - 200_000
	check(gate.maybe_show_interstitial(),
			"a veteran clears the grace period even right after a restart")

	# Two full-screen ads inside a minute is what earns a one-star review, so
	# an interstitial must not follow an App Open or a rewarded ad either.
	gate._interstitial_open = false
	gate._interstitial_loaded = true
	gate._battles_since_interstitial = 3
	gate._last_interstitial_ms = Time.get_ticks_msec() - 200_000
	gate._last_fullscreen_close_ms = Time.get_ticks_msec()
	check(not gate.maybe_show_interstitial(),
			"an interstitial never lands right after another full-screen ad")
	gate._last_fullscreen_close_ms = Time.get_ticks_msec() - 200_000
	check(gate.maybe_show_interstitial(),
			"once the shared cooldown passes the interstitial is allowed again")
	gate.queue_free()

	# App Open is retired from the release surface. Keep this regression guard
	# close to the service boundary so a future config change cannot re-enable it
	# accidentally.
	var opener = load("res://src/autoload/ad_service.gd").new()
	add_child(opener)
	await get_tree().process_frame
	opener._plugin = FakeAdmob.new()
	opener._initialized = true
	opener._ads_removed = false
	opener._app_open_loaded = true
	opener._current_scene_path = "res://scenes/main_menu.tscn"
	opener.config["app_open"]["enabled"] = false
	opener.config["app_open"]["min_background_seconds"] = 0
	opener._backgrounded_at_ms = 1
	SaveSystem.data["stats"] = {"runs_started": 3}
	check(not opener._app_open_due(), "App Open stays disabled even when a cached ad exists")
	opener.queue_free()
	SaveSystem.data = SaveSystem.DEFAULT_DATA.duplicate(true)

	# Entitlement flows from Billing through AdService without the game asking.
	SaveSystem.set_ads_removed(true)
	BillingService.refresh_entitlement_from_save()
	check(AdService.ads_removed(),
			"buying Remove Ads switches the forced ad surface off")
	# Remove Ads must not strip the opt-in offers: gating them here left paying
	# players unable to unlock a realm, reroll a reward or multiply crystals.
	var paid = load("res://src/autoload/ad_service.gd").new()
	add_child(paid)
	await get_tree().process_frame
	paid._ads_removed = true
	paid.config["enabled"] = true
	check(paid.rewarded_supported() == OS.has_feature("android"),
			"Remove Ads owners keep every opt-in rewarded offer")
	paid.queue_free()

	var battle_source := FileAccess.get_file_as_string("res://src/ui/battle_screen.gd")
	check(battle_source.contains("_second_wind_available"),
			"defeat offers the rewarded revive before failing the run")
	check(battle_source.contains("AdService.queue_break_interstitial()"),
			"the interstitial is queued for the reward-to-map break")
	check(not battle_source.contains("await AdService.interstitial_dismissed"),
			"battle never awaits a native full-screen ad on the dying scene")
	var ad_source := FileAccess.get_file_as_string("res://src/autoload/ad_service.gd")
	check(ad_source.contains("render_loop_enabled")
			and ad_source.contains("_arm_fullscreen_ad"),
			"full-screen ads stop the Godot render loop after the current GL frame")
	check(ad_source.contains("set_app_pause_on_background"),
			"AdMob pauses Godot when a full-screen ad covers the activity")
	check(not battle_source.contains("AdService.show_banner"),
			"battle never asks for a banner")
	check(battle_source.contains("_restore_battle_clock"),
			"battle restores time scale before leaving the fight")
	var log_source := FileAccess.get_file_as_string("res://src/ui/battle/battle_log.gd")
	check(not log_source.contains("PopupPanel.new()")
			and not log_source.contains("extends PopupPanel"),
			"battle history never uses a native PopupPanel window")
	# Asserted by behaviour, not by matching source text: the previous version
	# compared a literal "\n\t" against the file and broke the moment the line
	# endings changed, while the code it guarded was still correct.
	check(UiKit.banner_bottom_pad(24) == 24 and UiKit.banner_bottom_pad(40) == 40,
			"menu layout no longer reserves space for a banner")

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
