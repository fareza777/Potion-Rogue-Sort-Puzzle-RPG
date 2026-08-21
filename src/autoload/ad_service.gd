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
	"unit_ids": {"banner": "", "interstitial": "", "rewarded": ""},
	"interstitial": {"min_battles_between": 3, "min_seconds_between": 150,
		"skip_first_battles": 3, "skip_boss_victory": true},
	"rewarded": {"second_wind_hp_percent": 0.5, "second_wind_per_run": 1},
	"banner": {"enabled": true, "position": "bottom"},
}

## Menus that may carry a banner. Everything else — battle, map, events, story
## and the tutorial — stays clean, so an ad can never cover the puzzle board.
const BANNER_SCENES := ["res://scenes/main_menu.tscn", "res://scenes/area_select.tscn",
	"res://scenes/run_history.tscn", "res://scenes/shop.tscn",
	"res://scenes/reaction_codex.tscn", "res://scenes/credits.tscn"]

## Longest a full-screen ad may run before the game stops waiting on it.
const AD_WATCHDOG_SECONDS := 60.0
const BANNER_RETRY_DELAYS := [5.0, 15.0, 30.0]
## Viewport pixels reserved under menu content so a bottom banner is not hidden
## behind the Hall dock or covered by edge-to-edge system chrome.
const BANNER_HEIGHT_PX := 100

## Placement ids the game asks for. Kept as constants so call sites cannot drift.
const PLACEMENT_SECOND_WIND := "second_wind"
const PLACEMENT_REALM_UNLOCK := "realm_unlock"

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


func _ready() -> void:
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
	if what == NOTIFICATION_APPLICATION_RESUMED and _initialized:
		_request_interstitial()
		_request_rewarded()
		if _banner_wanted:
			show_banner()


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
	if not _banner_loaded:
		_call_plugin("load_banner_ad")
		return
	_call_plugin("show_banner_ad")


func hide_banner() -> void:
	_banner_wanted = false
	_banner_retry_attempt = 0
	if _banner_retry_timer != null:
		_banner_retry_timer.stop()
	if not is_active() or not _banner_loaded:
		return
	_call_plugin("hide_banner_ad")


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
	_call_plugin("show_rewarded_ad")
	_start_watchdog(_finish_rewarded)
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
	return OS.has_feature("android") and bool(config.get("enabled", true)) 			and not _ads_removed


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


func second_wind_per_run() -> int:
	return maxi(int(_section("rewarded").get("second_wind_per_run", 1)), 0)


func reset_frequency_caps() -> void:
	_battles_since_interstitial = 0
	_last_interstitial_ms = Time.get_ticks_msec()


func _on_scene_changed(path: String) -> void:
	_current_scene_path = path
	if is_banner_scene(path):
		show_banner()
	else:
		hide_banner()


func _on_plugin_initialized(_a: Variant = null, _b: Variant = null) -> void:
	if _initialized:
		return
	_initialized = true
	_sync_banner_for_current_scene()
	_request_interstitial()
	_request_rewarded()
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

func _try_interstitial() -> bool:
	if _ads_removed or not is_active() or not _interstitial_loaded:
		return false
	var rules := _section("interstitial")
	if _battles_completed <= int(rules.get("skip_first_battles", 3)):
		return false
	if _battles_since_interstitial < int(rules.get("min_battles_between", 3)):
		return false
	var elapsed := (Time.get_ticks_msec() - _last_interstitial_ms) / 1000.0
	if elapsed < float(rules.get("min_seconds_between", 150)):
		return false
	_interstitial_loaded = false
	_interstitial_open = true
	reset_frequency_caps()
	_call_plugin("show_interstitial_ad")
	_start_watchdog(_close_interstitial)
	return true


## A full-screen ad that never reports back would leave the caller awaiting a
## signal forever, freezing the player on a reward or defeat overlay. Every
## full-screen present is therefore backed by a watchdog that closes the flow
## itself; the real callbacks are idempotent, so whichever fires first wins.
func _start_watchdog(closer: Callable) -> void:
	get_tree().create_timer(AD_WATCHDOG_SECONDS, true, false, true).timeout.connect(closer)


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


func _request_rewarded() -> void:
	if _rewarded_loaded:
		return
	_call_plugin("load_rewarded_ad")


# --- Plugin callbacks -------------------------------------------------------

func _on_banner_loaded(_a: Variant = null, _b: Variant = null) -> void:
	_banner_loaded = true
	_banner_retry_attempt = 0
	if _banner_retry_timer != null:
		_banner_retry_timer.stop()
	if _banner_wanted and not _ads_removed:
		_call_plugin("show_banner_ad")


func _on_banner_failed(_a: Variant = null, _b: Variant = null) -> void:
	_banner_loaded = false
	_schedule_banner_retry()


func _sync_banner_for_current_scene() -> void:
	var path := _current_scene_path
	if path.is_empty() and get_tree() != null and get_tree().current_scene != null:
		path = get_tree().current_scene.scene_file_path
	if path.is_empty():
		return
	_banner_wanted = is_banner_scene(path)


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


func _on_interstitial_loaded(_a: Variant = null, _b: Variant = null) -> void:
	_interstitial_loaded = true


func _on_interstitial_failed(_a: Variant = null, _b: Variant = null) -> void:
	_interstitial_loaded = false


func _on_interstitial_closed(_a: Variant = null, _b: Variant = null) -> void:
	_close_interstitial()


func _close_interstitial() -> void:
	if not _interstitial_open:
		return
	_interstitial_open = false
	interstitial_dismissed.emit()
	_request_interstitial()


func _on_rewarded_loaded(_a: Variant = null, _b: Variant = null) -> void:
	_rewarded_loaded = true
	rewarded_availability_changed.emit(rewarded_ready())


func _on_rewarded_failed(_a: Variant = null, _b: Variant = null) -> void:
	_rewarded_loaded = false
	rewarded_availability_changed.emit(false)
	_finish_rewarded()


func _on_rewarded_earned(_a: Variant = null, _b: Variant = null) -> void:
	_rewarded_earned = true


func _on_rewarded_closed(_a: Variant = null, _b: Variant = null) -> void:
	_finish_rewarded()
	_request_rewarded()


func _finish_rewarded() -> void:
	if _rewarded_placement.is_empty():
		return
	var placement := _rewarded_placement
	_rewarded_placement = ""
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
		_interstitial_loaded = false
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
