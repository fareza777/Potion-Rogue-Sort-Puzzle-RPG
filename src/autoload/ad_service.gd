extends Node
## Autoload: AdService
## Owns the Android AdMob boundary. The rest of the game only ever asks for a
## placement and listens for the result, so desktop, editor, headless and
## plugin-less builds keep running with every call turning into a safe no-op.
##
## The AdMob Android plugin is resolved through the configured runtime node,
## with Engine singleton names kept as a compatibility fallback. Desktop,
## editor, headless CI and plugin-less builds remain safe no-ops.
##
## Ad unit ids, frequency caps and the test-mode switch all live in
## `res://data/ads.json`.

## Names published by the common Godot AdMob Android plugins. The first one that
## resolves wins; anything else is treated as "no ads available".
const SINGLETON_CANDIDATES := ["AdmobPlugin", "AdMob", "Admob", "GodotAdMob"]

const DEFAULT_CONFIG := {
	"enabled": true,
	"test_mode": true,
	"android_app_id": "",
	"unit_ids": {"banner": "", "interstitial": "", "rewarded": "", "app_open": ""},
	"interstitial": {"min_battles_between": 3, "min_seconds_between": 150,
		"skip_first_battles": 3, "skip_boss_victory": true,
		"cooldown_after_fullscreen_seconds": 120},
	"rewarded": {"second_wind_hp_percent": 0.5, "second_wind_per_run": 1,
		"double_crystals_multiplier": 2, "rerolls_per_battle": 1},
	"banner": {"enabled": true, "position": "bottom"},
	"app_open": {"enabled": false, "skip_first_session": true,
		"min_background_seconds": 45, "min_seconds_between": 900,
		"cooldown_after_fullscreen_seconds": 120},
}

## Menus that may carry a banner. Everything else — battle, map, events, story
## and the tutorial — stays clean, so an ad can never cover the puzzle board.
const BANNER_SCENES := ["res://scenes/main_menu.tscn", "res://scenes/area_select.tscn",
		"res://scenes/run_history.tscn", "res://scenes/shop.tscn",
		"res://scenes/reaction_codex.tscn", "res://scenes/credits.tscn"]

## Longest a full-screen ad may run before the game stops waiting on it.
const AD_WATCHDOG_SECONDS := 60.0
## After the map is live, wait this long with the render loop stopped so
## Godot's GL thread is not inside onDrawFrame when AdMob takes the activity.
const FULLSCREEN_SETTLE_SECONDS := 0.15
const BANNER_RETRY_DELAYS := [5.0, 15.0, 30.0]
## Full-screen formats need the same courtesy the banner already had. Without a
## ladder, one failed fill at startup ended the format for the whole session:
## the rewarded offer sat on "PREPARING AD…" until the app was backgrounded.
const FULLSCREEN_RETRY_DELAYS := [5.0, 15.0, 45.0, 120.0]
## Viewport pixels of the banner strip itself, reserved under menu content so a
## bottom banner is not hidden behind the Hall dock. The system chrome the
## banner is anchored above is reserved separately by UiKit.safe_margin().
const BANNER_HEIGHT_PX := 100

## App Open ads are retired from the production surface.
const APP_OPEN_SCENES := []

## Placement ids the game asks for. Kept as constants so call sites cannot drift.
const PLACEMENT_SECOND_WIND := "second_wind"
const PLACEMENT_REALM_UNLOCK := "realm_unlock"
const PLACEMENT_REROLL := "reward_reroll"
const PLACEMENT_DOUBLE_CRYSTALS := "double_crystals"

signal ads_removed_changed(removed: bool)
signal rewarded_granted(placement: String)
signal rewarded_dismissed(placement: String)
signal interstitial_dismissed()
## Lets opt-in surfaces appear the moment an ad finishes loading, instead of
## only when the player happens to reopen the screen.
signal rewarded_availability_changed(ready: bool)

var config: Dictionary = {}

var _plugin: Object = null
var _initialized := false
var _privacy_form_requested := false
var _banner_loaded := false
var _banner_wanted := false
var _banner_retry_attempt := 0
var _banner_retry_timer: Timer
var _interstitial_loaded := false
var _rewarded_loaded := false
var _rewarded_placement := ""
var _rewarded_earned := false
var _battles_since_interstitial := 0
var _last_interstitial_ms := -1_000_000
var _battles_completed := 0
var _boss_just_cleared := false
var _interstitial_open := false
var _ads_removed := false
var _current_scene_path := ""
var _banner_shown := false
var _banner_loading := false
var _app_open_loaded := false
var _app_open_loading := false
var _app_open_open := false
var _last_app_open_ms := -1_000_000
var _last_fullscreen_close_ms := -1_000_000
var _backgrounded_at_ms := 0
## Every banner ad id the plugin has handed back, so stale AdViews can be
## destroyed instead of lingering behind the newest one.
var _banner_ad_ids: Array[String] = []
var _retry_timers: Dictionary = {}
var _retry_attempts: Dictionary = {}
var _break_interstitial_pending := false
var _render_suspended := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	config = _merge_defaults(GameState.load_data_file("ads.json", DEFAULT_CONFIG))
	_ads_removed = SaveSystem.ads_removed()
	BillingService.entitlement_changed.connect(_on_entitlement_changed)
	SceneRouter.transition_finished.connect(_on_scene_changed)
	if not _should_run():
		return
	_plugin = _resolve_plugin()
	if _plugin == null:
		# Expected until the AdMob Android plugin is installed. Play continues
		# exactly as it does on desktop.
		print("AdService: no AdMob plugin present, running ad-free.")
		return
	_connect_plugin_signals()
	call_deferred("_initialize_plugin")


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_backgrounded_at_ms = Time.get_ticks_msec()
	elif what == NOTIFICATION_APPLICATION_RESUMED and _initialized:
		if _interstitial_open or _app_open_open or not _rewarded_placement.is_empty():
			return
		call_deferred("_refresh_ads_after_resume")


func _refresh_ads_after_resume() -> void:
	if _interstitial_open or _app_open_open or not _rewarded_placement.is_empty():
		return
	_request_interstitial()
	_request_rewarded()
	_request_app_open()
	if _banner_wanted:
		show_banner()
	if _app_open_due():
		call_deferred("_present_app_open")


# --- Public API -------------------------------------------------------------

## True when the player owns the Remove Ads purchase. Rewarded ads stay
## available to them as an opt-in, banners and interstitials never appear.
func ads_removed() -> bool:
	return _ads_removed


## True when a real ad could actually be shown right now.
func is_active() -> bool:
	return _initialized and _plugin != null


## True on Android when a live banner should occupy the bottom of menu scenes.
## Layout uses this even before the plugin finishes initializing so the Hall
## dock is already lifted when the ad appears.
func should_reserve_banner() -> bool:
	if _ads_removed or not bool(config.get("enabled", true)):
		return false
	if not bool(_section("banner").get("enabled", true)):
		return false
	return OS.has_feature("android")


func banner_reserve_px() -> int:
	return BANNER_HEIGHT_PX if should_reserve_banner() else 0


func is_banner_scene(path: String) -> bool:
	if path in BANNER_SCENES:
		return true
	var file := path.get_file()
	if file.is_empty():
		return false
	for scene in BANNER_SCENES:
		if str(scene).get_file() == file:
			return true
	return false


func show_banner() -> void:
	_banner_wanted = true
	if _ads_removed or not is_active() or not bool(_section("banner").get("enabled", true)):
		return
	if _interstitial_open:
		return
	if not _banner_loaded:
		# One request at a time, and only one banner for the whole session.
		# Every load_banner_ad() builds a fresh native AdView, but the vendor
		# only ever hides `last_key()`, so a second request leaves the first
		# banner stuck on screen across every scene — including battle, where
		# it covered the action row.
		if not _banner_loading:
			_banner_loading = true
			_call_plugin("load_banner_ad")
		return
	_call_plugin("show_banner_ad")
	_banner_shown = true


func hide_banner() -> void:
	_banner_wanted = false
	_banner_retry_attempt = 0
	if _banner_retry_timer != null:
		_banner_retry_timer.stop()
	if not is_active():
		_banner_shown = false
		return
	# Never touch a native view while a full-screen ad owns the activity: that
	# swap is the SIGSEGV in Godot's GL thread. Outside that window, hide any
	# banner the plugin still holds even when our own flag says it is down —
	# a desynced flag is what left a banner stranded over the battle board.
	if _interstitial_open or not _rewarded_placement.is_empty():
		_banner_shown = false
		return
	if not _banner_shown and not _banner_loaded:
		return
	_banner_shown = false
	_call_plugin("hide_banner_ad")


## True when returning to the foreground has earned an App Open ad. Every gate
## here exists to keep the format invisible to a normal player: never on the
## install session, never after a short glance at a notification, never on top
## of gameplay, and never straight after another full-screen ad — including the
## resume that fires when one of our own ads closes.
func _app_open_due() -> bool:
	var rules := _section("app_open")
	if _ads_removed or not is_active() or not bool(rules.get("enabled", true)):
		return false
	if not _app_open_loaded or _app_open_open or _interstitial_open:
		return false
	if not _rewarded_placement.is_empty():
		return false
	if bool(rules.get("skip_first_session", true)) and _is_install_session():
		return false
	if not _is_app_open_scene(_current_scene_path):
		return false
	var away := float(Time.get_ticks_msec() - _backgrounded_at_ms) / 1000.0
	if _backgrounded_at_ms <= 0 \
			or away < float(rules.get("min_background_seconds", 45)):
		return false
	var since_last := float(Time.get_ticks_msec() - _last_app_open_ms) / 1000.0
	if since_last < float(rules.get("min_seconds_between", 900)):
		return false
	var since_fullscreen := float(Time.get_ticks_msec() - _last_fullscreen_close_ms) / 1000.0
	return since_fullscreen >= float(rules.get("cooldown_after_fullscreen_seconds", 120))


## Battles won across the whole install, persisted by SaveSystem, so the
## interstitial grace period survives app restarts.
func _lifetime_battles_won() -> int:
	var stats: Dictionary = SaveSystem.data.get("stats", {})
	return maxi(int(stats.get("battles_won", 0)), _battles_completed)


func _is_app_open_scene(path: String) -> bool:
	if path.is_empty():
		return false
	var file := path.get_file()
	for scene in APP_OPEN_SCENES:
		if str(scene).get_file() == file:
			return true
	return false


## A player who has never finished a run is still deciding whether they like
## the game; an ad on their first return is the cheapest way to lose them.
func _is_install_session() -> bool:
	var stats: Dictionary = SaveSystem.data.get("stats", {})
	return int(stats.get("runs_started", 0)) <= 0


## Records that a battle ended. Kept separate from showing the ad so the
## interstitial can land on a natural break (leaving the reward screen) rather
## than on the victory beat itself.
func notify_battle_finished(is_boss: bool) -> void:
	_battles_completed += 1
	_battles_since_interstitial += 1
	_boss_just_cleared = is_boss


## Shows an interstitial when every frequency cap allows it. Returns true when
## an ad was actually presented, in which case `interstitial_dismissed` fires
## once the player closes it.
func maybe_show_interstitial() -> bool:
	if _boss_just_cleared and bool(_section("interstitial").get("skip_boss_victory", true)):
		return false
	return _try_interstitial()


## Marks that a gameplay break is coming. The interstitial is presented only
## after the next map scene is live, never from the battle node that is about
## to be freed while AdMob tears down the renderer.
func queue_break_interstitial() -> void:
	_break_interstitial_pending = false
	if _boss_just_cleared and bool(_section("interstitial").get("skip_boss_victory", true)):
		return
	# Only arm the break when an ad could genuinely run. Arming unconditionally
	# made every single battle win stop the Android render loop and pause the
	# tree for a moment on the map, then resume having shown nothing: the caps
	# hold off the first three wins, but the GL-thread churn ran anyway. That is
	# the same churn the comments below call out as the SIGSEGV, and it fired
	# from the very first victory.
	_break_interstitial_pending = _interstitial_eligible()


## Rewarded ads are always opt-in: only call this from a button the player
## pressed. Listen for `rewarded_granted` / `rewarded_dismissed` on the returned
## placement. Returns false when no ad could be shown, in which case neither
## signal fires and the caller should fall back gracefully.
func show_rewarded(placement: String) -> bool:
	if not is_active() or not _rewarded_loaded or not _rewarded_placement.is_empty():
		return false
	_rewarded_placement = placement
	_rewarded_earned = false
	_rewarded_loaded = false
	rewarded_availability_changed.emit(false)
	_start_watchdog(_finish_rewarded)
	call_deferred("_present_rewarded")
	return true


## True when a rewarded ad is loaded and no other rewarded flow is running, so
## UI can enable the offer instead of showing a button that does nothing.
func rewarded_ready() -> bool:
	return is_active() and _rewarded_loaded and _rewarded_placement.is_empty()


## True when rewarded ads could ever appear on this build. Screens use this to
## decide whether to render the offer at all; `rewarded_ready()` then decides
## whether it is pressable yet. Without the split, a slow first load hides the
## offer permanently, because the screen only tests availability once.
func rewarded_supported() -> bool:
	# Deliberately not gated on `_ads_removed`. Remove Ads buys freedom from
	# ads the player never asked for; rewarded ads are a benefit they opt into,
	# and Second Wind already stays available to them. Gating this here left
	# paying players unable to unlock a realm, reroll a reward or multiply
	# crystals — a worse deal than free players get.
	return OS.has_feature("android") and bool(config.get("enabled", true))


## True when UMP actually has a consent form for this device's region. Outside
## the EEA, the UK, Switzerland and the covered US states there is nothing to
## show, and the Settings button has to say so instead of looking broken.
func privacy_options_available() -> bool:
	if not is_active() or _plugin == null:
		return false
	if not _plugin.has_method("is_consent_form_available"):
		return false
	return bool(_plugin.call("is_consent_form_available"))


## Opens the AdMob/UMP privacy options form so players can change or withdraw
## their personalised-ads consent. Returns false when the form is unavailable.
func open_privacy_options() -> bool:
	if not is_active():
		return false
	if _call_plugin("show_privacy_options_form"):
		return true
	if _plugin.has_method("show_consent_form"):
		if _plugin.has_method("is_consent_form_available") \
				and not bool(_plugin.call("is_consent_form_available")):
			_privacy_form_requested = true
			return _call_plugin("load_consent_form")
		return _call_plugin("show_consent_form")
	return false


func second_wind_hp_percent() -> float:
	return clampf(float(_section("rewarded").get("second_wind_hp_percent", 0.5)), 0.1, 1.0)


## How many extra copies of a run's crystals a rewarded ad may grant. A value
## of 2 means the player ends up with twice what they earned.
func double_crystals_multiplier() -> int:
	return maxi(int(_section("rewarded").get("double_crystals_multiplier", 2)), 1)


func rerolls_per_battle() -> int:
	return maxi(int(_section("rewarded").get("rerolls_per_battle", 1)), 0)


func second_wind_per_run() -> int:
	return maxi(int(_section("rewarded").get("second_wind_per_run", 1)), 0)


func reset_frequency_caps() -> void:
	_battles_since_interstitial = 0
	_last_interstitial_ms = Time.get_ticks_msec()


func _on_scene_changed(path: String) -> void:
	_current_scene_path = path
	var show_break := _break_interstitial_pending and _is_break_scene(path)
	_break_interstitial_pending = false
	if show_break:
		# Do not hide/show a banner in the same beat as a full-screen ad; the
		# native view swap is what SIGSEGVs Godot's GL thread on Android.
		call_deferred("_present_queued_interstitial")
		return
	if is_banner_scene(path):
		show_banner()
	else:
		hide_banner()


func _is_break_scene(path: String) -> bool:
	return path.get_file() == "map.tscn"


func _present_queued_interstitial() -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	# Re-checked here as well: the map may have taken long enough to arrive that
	# the caps changed their mind, and arming the renderer for nothing is what
	# crashed the activity.
	if not _interstitial_eligible():
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if OS.has_feature("android"):
		await _arm_fullscreen_ad()
	if not _try_interstitial():
		_resume_render_after_fullscreen()


func _present_app_open() -> void:
	if not _app_open_due():
		return
	_app_open_loaded = false
	_app_open_open = true
	_last_app_open_ms = Time.get_ticks_msec()
	if OS.has_feature("android"):
		await _arm_fullscreen_ad()
	if not _call_plugin("show_app_open_ad"):
		_close_app_open()
		return
	_start_watchdog(_close_app_open)


func _close_app_open() -> void:
	if not _app_open_open:
		return
	_app_open_open = false
	_last_fullscreen_close_ms = Time.get_ticks_msec()
	_resume_render_after_fullscreen()
	_request_app_open()


func _present_rewarded() -> void:
	if _rewarded_placement.is_empty():
		return
	if OS.has_feature("android"):
		await _arm_fullscreen_ad()
		if _rewarded_placement.is_empty():
			_resume_render_after_fullscreen()
			return
	if not _call_plugin("show_rewarded_ad"):
		_resume_render_after_fullscreen()
		_finish_rewarded()


## Stops Godot drawing before AdMob covers the activity. Calling show from a
## live GL frame is the SIGSEGV we saw on device (null deref in GodotLib.step).
func _arm_fullscreen_ad() -> void:
	var tree := get_tree()
	if tree == null:
		return
	while SceneRouter.is_transitioning():
		await tree.process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_suspend_render_for_fullscreen()
	await tree.create_timer(FULLSCREEN_SETTLE_SECONDS, true, true, true).timeout


func _suspend_render_for_fullscreen() -> void:
	if _render_suspended or not OS.has_feature("android"):
		return
	_render_suspended = true
	var tree := get_tree()
	if tree != null:
		tree.paused = true
	RenderingServer.render_loop_enabled = false


func _resume_render_after_fullscreen() -> void:
	if not _render_suspended:
		return
	_render_suspended = false
	RenderingServer.render_loop_enabled = true
	var tree := get_tree()
	if tree != null:
		tree.paused = false
	call_deferred("_sync_banner_for_current_scene")


func _on_plugin_initialized(_a: Variant = null, _b: Variant = null) -> void:
	if _initialized:
		return
	_initialized = true
	_call_plugin("set_app_pause_on_background", [true])
	_sync_banner_for_current_scene()
	_request_interstitial()
	_request_rewarded()
	_request_app_open()
	if _banner_wanted:
		show_banner()


func _on_consent_info_updated() -> void:
	if _plugin != null and _plugin.has_method("is_consent_form_available") \
			and bool(_plugin.call("is_consent_form_available")):
		_call_plugin("show_consent_form")


func _on_consent_form_loaded() -> void:
	if _privacy_form_requested:
		_privacy_form_requested = false
		_call_plugin("show_consent_form")


# --- Interstitial pacing ----------------------------------------------------

## Every gate an interstitial has to clear, decided without changing anything.
## Both the queue and the presenter consult this, so they can never disagree —
## and nothing suspends the renderer for an ad that was never going to run.
func _interstitial_eligible() -> bool:
	if _ads_removed or not is_active() or _interstitial_open:
		return false
	if not _plugin_has_interstitial():
		_interstitial_loaded = false
		return false
	var rules := _section("interstitial")
	# The onboarding grace period is a lifetime allowance, not a per-session one.
	# `_battles_completed` resets on every launch, so a player who plays two or
	# three battles per sitting would never clear this gate at all.
	if _lifetime_battles_won() <= int(rules.get("skip_first_battles", 3)):
		return false
	if _battles_since_interstitial < int(rules.get("min_battles_between", 3)):
		return false
	var elapsed := (Time.get_ticks_msec() - _last_interstitial_ms) / 1000.0
	if elapsed < float(rules.get("min_seconds_between", 150)):
		return false
	# What actually earns a one-star review is two full-screen ads inside a
	# minute, not the daily total. App Open already refuses to follow another
	# full-screen ad; this is the same guard in the other direction, and it also
	# stops an interstitial landing right after a rewarded ad the player chose
	# to watch — reroll a reward, pick it, and the map swap would otherwise
	# present one immediately.
	var since_fullscreen := (Time.get_ticks_msec() - _last_fullscreen_close_ms) / 1000.0
	return since_fullscreen >= float(rules.get("cooldown_after_fullscreen_seconds", 120))


func _try_interstitial() -> bool:
	if not _interstitial_eligible():
		return false
	_interstitial_loaded = false
	_interstitial_open = true
	reset_frequency_caps()
	if OS.has_feature("android") and not _render_suspended:
		_suspend_render_for_fullscreen()
	if not _call_plugin("show_interstitial_ad"):
		_interstitial_open = false
		_resume_render_after_fullscreen()
		return false
	_start_watchdog(_close_interstitial)
	return true


func _plugin_has_interstitial() -> bool:
	if _plugin != null and _plugin.has_method("is_interstitial_ad_loaded"):
		return bool(_plugin.call("is_interstitial_ad_loaded"))
	return _interstitial_loaded


## A full-screen ad that never reports back would leave the caller awaiting a
## signal forever, freezing the player on a reward or defeat overlay. Every
## full-screen present is therefore backed by a watchdog that closes the flow
## itself; the real callbacks are idempotent, so whichever fires first wins.
func _start_watchdog(closer: Callable) -> void:
	get_tree().create_timer(AD_WATCHDOG_SECONDS, true, true, true).timeout.connect(closer)


# --- Plugin boundary --------------------------------------------------------

func _should_run() -> bool:
	if not bool(config.get("enabled", true)):
		return false
	return OS.has_feature("android")


func _resolve_plugin() -> Object:
	var runtime_node := get_node_or_null("/root/AdmobRuntime")
	if runtime_node != null and runtime_node.has_method("initialize"):
		return runtime_node
	for candidate in SINGLETON_CANDIDATES:
		if Engine.has_singleton(candidate):
			return Engine.get_singleton(candidate)
	return null


func _initialize_plugin() -> void:
	# UMP consent is handled by the Admob node before ad requests are made.
	_call_plugin("update_consent_info")
	if not _call_plugin("initialize"):
		_on_plugin_initialized()
	elif not _plugin.has_signal("initialization_completed"):
		_on_plugin_initialized()


func _connect_plugin_signals() -> void:
	_try_connect("initialization_completed", _on_plugin_initialized)
	_try_connect("banner_ad_loaded", _on_banner_loaded)
	_try_connect("banner_ad_failed_to_load", _on_banner_failed)
	_try_connect("interstitial_ad_loaded", _on_interstitial_loaded)
	_try_connect("interstitial_ad_failed_to_load", _on_interstitial_failed)
	_try_connect("interstitial_ad_dismissed_full_screen_content", _on_interstitial_closed)
	_try_connect("interstitial_ad_failed_to_show_full_screen_content", _on_interstitial_closed)
	_try_connect("rewarded_ad_loaded", _on_rewarded_loaded)
	_try_connect("rewarded_ad_failed_to_load", _on_rewarded_failed)
	_try_connect("rewarded_ad_dismissed_full_screen_content", _on_rewarded_closed)
	_try_connect("rewarded_ad_failed_to_show_full_screen_content", _on_rewarded_closed)
	_try_connect("user_earned_rewarded", _on_rewarded_earned)
	_try_connect("rewarded_ad_user_earned_reward", _on_rewarded_earned)
	_try_connect("app_open_ad_loaded", _on_app_open_loaded)
	_try_connect("app_open_ad_failed_to_load", _on_app_open_failed)
	_try_connect("app_open_ad_dismissed_full_screen_content", _on_app_open_closed)
	_try_connect("app_open_ad_failed_to_show_full_screen_content", _on_app_open_closed)
	_try_connect("consent_form_loaded", _on_consent_form_loaded)
	_try_connect("consent_info_updated", _on_consent_info_updated)


func _try_connect(signal_name: String, target: Callable) -> void:
	if _plugin != null and _plugin.has_signal(signal_name):
		_plugin.connect(signal_name, target)


## Calls a plugin method when it exists. Returns whether the call happened, so
## callers can try an alternative signature without spamming errors.
func _call_plugin(method: String, args: Array = []) -> bool:
	if _plugin == null or not _plugin.has_method(method):
		return false
	_plugin.callv(method, args)
	return true


func _request_interstitial() -> void:
	if _ads_removed or _interstitial_loaded:
		return
	_call_plugin("load_interstitial_ad")


## Release builds without an App Open unit id simply never request one, so the
## format stays dormant until the AdMob console has it.
func _request_app_open() -> void:
	if _ads_removed or _app_open_loaded or _app_open_loading:
		return
	if not bool(_section("app_open").get("enabled", true)):
		return
	if not _app_open_unit_configured():
		return
	_app_open_loading = true
	if not _call_plugin("load_app_open_ad"):
		_app_open_loading = false


func _app_open_unit_configured() -> bool:
	if OS.has_feature("debug"):
		return true
	return not str((config.get("unit_ids", {}) as Dictionary).get("app_open", "")).is_empty()


func _request_rewarded() -> void:
	if _rewarded_loaded:
		return
	_call_plugin("load_rewarded_ad")


# --- Plugin callbacks -------------------------------------------------------

func _on_banner_loaded(_a: Variant = null, _b: Variant = null) -> void:
	_banner_loading = false
	_banner_loaded = true
	_banner_retry_attempt = 0
	if _banner_retry_timer != null:
		_banner_retry_timer.stop()
	_retire_stale_banners(_banner_id_from(_a))
	if _banner_wanted and not _ads_removed and not _interstitial_open:
		_call_plugin("show_banner_ad")
		_banner_shown = true


## Destroys every banner except the newest. Hiding is not enough: the vendor
## hides only its most recent ad, so any older AdView keeps drawing over the
## game forever. Removal has to happen while the id is still cached, because
## `remove_banner_ad` refuses ids it can no longer find.
func _retire_stale_banners(current_id: String) -> void:
	for previous_id in _banner_ad_ids:
		if previous_id != current_id and not previous_id.is_empty():
			_call_plugin("remove_banner_ad", [previous_id])
	_banner_ad_ids.clear()
	if not current_id.is_empty():
		_banner_ad_ids.append(current_id)


func _banner_id_from(ad_info: Variant) -> String:
	if ad_info != null and typeof(ad_info) == TYPE_OBJECT \
			and (ad_info as Object).has_method("get_ad_id"):
		return str((ad_info as Object).call("get_ad_id"))
	return ""


func _on_banner_failed(_a: Variant = null, _b: Variant = null) -> void:
	_banner_loading = false
	_banner_loaded = false
	_schedule_banner_retry()


func _sync_banner_for_current_scene() -> void:
	var path := _current_scene_path
	if path.is_empty() and get_tree() != null and get_tree().current_scene != null:
		path = get_tree().current_scene.scene_file_path
	if path.is_empty():
		return
	if _interstitial_open or not _rewarded_placement.is_empty():
		_banner_wanted = false
		return
	if is_banner_scene(path):
		show_banner()
	else:
		hide_banner()


## Bounded, backing-off retry shared by the full-screen formats. Rewarded ads
## are never gated on `_ads_removed`: a Remove Ads owner still opts into them.
func _schedule_ad_retry(kind: String, action: Callable) -> void:
	var attempt := int(_retry_attempts.get(kind, 0))
	if not is_active() or attempt >= FULLSCREEN_RETRY_DELAYS.size():
		return
	if kind == "interstitial" and _ads_removed:
		return
	var timer: Timer = _retry_timers.get(kind)
	if timer == null:
		timer = Timer.new()
		timer.name = "%sRetryTimer" % kind
		timer.one_shot = true
		add_child(timer)
		_retry_timers[kind] = timer
	if not timer.timeout.is_connected(action):
		timer.timeout.connect(action)
	timer.start(float(FULLSCREEN_RETRY_DELAYS[attempt]))
	_retry_attempts[kind] = attempt + 1


func _clear_ad_retry(kind: String) -> void:
	_retry_attempts[kind] = 0
	var timer: Timer = _retry_timers.get(kind)
	if timer != null:
		timer.stop()


func _schedule_banner_retry() -> void:
	if not _banner_wanted or _ads_removed or not is_active() \
			or _banner_retry_attempt >= BANNER_RETRY_DELAYS.size():
		return
	if _banner_retry_timer == null:
		_banner_retry_timer = Timer.new()
		_banner_retry_timer.name = "BannerRetryTimer"
		_banner_retry_timer.one_shot = true
		_banner_retry_timer.timeout.connect(_on_banner_retry_timeout)
		add_child(_banner_retry_timer)
	_banner_retry_timer.start(float(BANNER_RETRY_DELAYS[_banner_retry_attempt]))
	_banner_retry_attempt += 1


func _on_banner_retry_timeout() -> void:
	if _banner_wanted and not _ads_removed and is_active():
		show_banner()


func _on_app_open_loaded(_a: Variant = null, _b: Variant = null) -> void:
	_app_open_loading = false
	_app_open_loaded = true


func _on_app_open_failed(_a: Variant = null, _b: Variant = null) -> void:
	_app_open_loading = false
	_app_open_loaded = false


func _on_app_open_closed(_a: Variant = null, _b: Variant = null) -> void:
	_close_app_open()


func _on_interstitial_loaded(_a: Variant = null, _b: Variant = null) -> void:
	_interstitial_loaded = true
	_clear_ad_retry("interstitial")


func _on_interstitial_failed(_a: Variant = null, _b: Variant = null) -> void:
	_interstitial_loaded = false
	_schedule_ad_retry("interstitial", _request_interstitial)


func _on_interstitial_closed(_a: Variant = null, _b: Variant = null) -> void:
	_close_interstitial()


func _close_interstitial() -> void:
	if not _interstitial_open:
		return
	_interstitial_open = false
	_last_fullscreen_close_ms = Time.get_ticks_msec()
	_resume_render_after_fullscreen()
	interstitial_dismissed.emit()
	call_deferred("_request_interstitial")


func _on_rewarded_loaded(_a: Variant = null, _b: Variant = null) -> void:
	_rewarded_loaded = true
	_clear_ad_retry("rewarded")
	rewarded_availability_changed.emit(rewarded_ready())


func _on_rewarded_failed(_a: Variant = null, _b: Variant = null) -> void:
	_rewarded_loaded = false
	rewarded_availability_changed.emit(false)
	_finish_rewarded()
	_schedule_ad_retry("rewarded", _request_rewarded)


func _on_rewarded_earned(_a: Variant = null, _b: Variant = null) -> void:
	_rewarded_earned = true


func _on_rewarded_closed(_a: Variant = null, _b: Variant = null) -> void:
	_finish_rewarded()
	_request_rewarded()


func _finish_rewarded() -> void:
	if _rewarded_placement.is_empty():
		_resume_render_after_fullscreen()
		return
	var placement := _rewarded_placement
	_rewarded_placement = ""
	_last_fullscreen_close_ms = Time.get_ticks_msec()
	_resume_render_after_fullscreen()
	if _rewarded_earned:
		_rewarded_earned = false
		rewarded_granted.emit(placement)
	else:
		rewarded_dismissed.emit(placement)


# --- Entitlement ------------------------------------------------------------

func _on_entitlement_changed(removed: bool) -> void:
	if _ads_removed == removed:
		return
	_ads_removed = removed
	if removed:
		hide_banner()
		_banner_wanted = false
		_banner_shown = false
		_interstitial_loaded = false
		_break_interstitial_pending = false
		if not _call_plugin("remove_banner_ad"):
			_call_plugin("destroy_banner_ad")
	ads_removed_changed.emit(removed)


# --- Config -----------------------------------------------------------------

func _section(name: String) -> Dictionary:
	return config.get(name, DEFAULT_CONFIG[name]) as Dictionary


func _merge_defaults(raw: Dictionary) -> Dictionary:
	var merged := DEFAULT_CONFIG.duplicate(true)
	for key in raw:
		var value: Variant = raw[key]
		if value is Dictionary and merged.get(key) is Dictionary:
			var section: Dictionary = merged[key]
			for inner in (value as Dictionary):
				section[inner] = (value as Dictionary)[inner]
			merged[key] = section
		else:
			merged[key] = value
	return merged
