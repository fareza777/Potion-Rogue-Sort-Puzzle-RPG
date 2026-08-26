extends Admob
## Runtime configuration node for the Godot AdMob Android plugin.
##
## The game-facing AdService stays independent from the vendor API. This node
## owns the vendor IDs and switches debug builds to Google's test units while
## release builds use the production values from data/ads.json.

const ADS_CONFIG_PATH := "res://data/ads.json"
const DEBUG_APP_ID := "ca-app-pub-3940256099942544~3347511713"
const DEBUG_BANNER_ID := "ca-app-pub-3940256099942544/2014213617"
const DEBUG_INTERSTITIAL_ID := "ca-app-pub-3940256099942544/1033173712"
const DEBUG_REWARDED_ID := "ca-app-pub-3940256099942544/5224354917"
const DEBUG_APP_OPEN_ID := "ca-app-pub-3940256099942544/9257395921"


func _init() -> void:
	# GDScript does NOT chain _init() implicitly: declaring one here replaces
	# Admob._init() outright. Skipping this call leaves every AdCache null, and
	# each ad callback then dies on "Nonexistent function 'cache' in base 'Nil'"
	# before it can emit its signal — so no ad ever reports as loaded.
	super()
	var config := _load_ads_config()
	var production_mode := not bool(config.get("test_mode", true))
	# Never serve live ads from a local/debug run, even when the production
	# config is checked into the project for the release export.
	is_real = production_mode and not OS.has_feature("debug")

	android_debug_application_id = DEBUG_APP_ID
	android_debug_banner_id = DEBUG_BANNER_ID
	android_debug_interstitial_id = DEBUG_INTERSTITIAL_ID
	android_debug_rewarded_id = DEBUG_REWARDED_ID
	android_debug_app_open_id = DEBUG_APP_OPEN_ID
	android_real_application_id = str(config.get("android_app_id", ""))
	var unit_ids: Dictionary = config.get("unit_ids", {})
	android_real_banner_id = str(unit_ids.get("banner", ""))
	android_real_interstitial_id = str(unit_ids.get("interstitial", ""))
	android_real_rewarded_id = str(unit_ids.get("rewarded", ""))
	# App Open is retired from the production surface; the empty release id
	# prevents the runtime from requesting the format.
	android_real_app_open_id = str(unit_ids.get("app_open", ""))

	banner_position = LoadAdRequest.AdPosition.BOTTOM
	banner_size = LoadAdRequest.RequestedAdSize.ADAPTIVE
	banner_anchor_to_safe_area = true
	remove_interstitial_ads_after_displayed = true
	remove_rewarded_ads_after_displayed = true
	remove_banner_ads_after_scene = false
	remove_interstitial_ads_after_scene = false
	remove_rewarded_ads_after_scene = false
	# AdService owns this boundary; the production policy currently retires
	# App Open and therefore never requests or presents it.
	# The vendor exposes no remove_app_open_* switches, so AdService reloads the
	# next App Open itself after each dismissal.
	auto_show_on_resume = false


func _ready() -> void:
	if OS.has_feature("android") or OS.has_feature("ios"):
		super._ready()


func _load_ads_config() -> Dictionary:
	var file := FileAccess.open(ADS_CONFIG_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}
