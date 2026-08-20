extends Node
## Autoload: AdService
## Owns the Android AdMob boundary. The rest of the game only ever asks for a
## placement and listens for the result, so desktop, editor, headless and
## plugin-less builds keep running with every call turning into a safe no-op.
##
## The AdMob Android plugin is resolved at runtime through `Engine.get_singleton`
## rather than a hard dependency: dropping the .aar into `addons/` switches real
## ads on with no code change, and removing it can never break a build.
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

## Placement ids the game asks for. Kept as constants so call sites cannot drift.
const PLACEMENT_SECOND_WIND := "second_wind"
const PLACEMENT_REALM_UNLOCK := "realm_unlock"

signal ads_removed_changed(removed: bool)
signal rewarded_granted(placement: String)
signal rewarded_dismissed(placement: String)
signal interstitial_dismissed()

var config: Dictionary = {}

var _plugin: Object = null
var _initialized := false
var _banner_loaded := false
var _banner_wanted := false
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
	_initialize_plugin()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED and _initialized:
		_request_interstitial()
		_request_rewarded()


# --- Public API -------------------------------------------------------------

## True when the player owns the Remove Ads purchase. Rewarded ads stay
## available to them as an opt-in, banners and interstitials never appear.
func ads_removed() -> bool:
	return _ads_removed


## True when a real ad could actually be shown right now.
func is_active() -> bool:
	return _initialized and _plugin != null


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
	if not is_active():
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
	_call_plugin("show_rewarded_ad")
	_start_watchdog(_finish_rewarded)
	return true


## True when a rewarded ad is loaded and no other rewarded flow is running, so
## UI can hide the offer instead of showing a button that does nothing.
func rewarded_ready() -> bool:
	return is_active() and _rewarded_loaded and _rewarded_placement.is_empty()


## Opens the AdMob/UMP privacy options form so players can change or withdraw
## their personalised-ads consent. Returns false when the form is unavailable.
func open_privacy_options() -> bool:
	if not is_active():
		return false
	return _call_plugin("show_privacy_options_form")


func second_wind_hp_percent() -> float:
	return clampf(float(_section("rewarded").get("second_wind_hp_percent", 0.5)), 0.1, 1.0)


func second_wind_per_run() -> int:
	return maxi(int(_section("rewarded").get("second_wind_per_run", 1)), 0)


func reset_frequency_caps() -> void:
	_battles_since_interstitial = 0
	_last_interstitial_ms = Time.get_ticks_msec()


func _on_scene_changed(path: String) -> void:
	if path in BANNER_SCENES:
		show_banner()
	else:
		hide_banner()


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
	for candidate in SINGLETON_CANDIDATES:
		if Engine.has_singleton(candidate):
			return Engine.get_singleton(candidate)
	return null


func _initialize_plugin() -> void:
	# Plugin builds differ in whether initialize() takes the test-mode flag.
	if not _call_plugin("initialize", [bool(config.get("test_mode", true))]):
		_call_plugin("initialize")
	_initialized = true
	_request_interstitial()
	_request_rewarded()
	if _banner_wanted:
		show_banner()


func _connect_plugin_signals() -> void:
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

func _on_banner_loaded(_a: Variant = null) -> void:
	_banner_loaded = true
	if _banner_wanted and not _ads_removed:
		_call_plugin("show_banner_ad")


func _on_banner_failed(_a: Variant = null, _b: Variant = null) -> void:
	_banner_loaded = false


func _on_interstitial_loaded(_a: Variant = null) -> void:
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


func _on_rewarded_loaded(_a: Variant = null) -> void:
	_rewarded_loaded = true


func _on_rewarded_failed(_a: Variant = null, _b: Variant = null) -> void:
	_rewarded_loaded = false
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
