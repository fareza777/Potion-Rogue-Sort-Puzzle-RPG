extends Node
## Autoload: SaveSystem
## Persistent local save (crystals, permanent upgrades, settings, stats,
## tutorial flag) in user://save.json. Versioned, with corrupt-file fallback
## so a bad save can never crash the game.

const SAVE_PATH := "user://save.json"
const AREA_GRAMMAR := preload("res://src/run/area_grammar.gd")
const SAVE_TEMP_PATH := SAVE_PATH + ".tmp"
const SAVE_BACKUP_PATH := SAVE_PATH + ".bak"
const SAVE_VERSION := 10

const DEFAULT_DATA := {
	"version": SAVE_VERSION,
	"crystals": 0,
	"perma": {},
	"tutorial_done": false,
	"onboarding_done": false,
	"tutorial_state": "new",
	"tutorial_step": 0,
	"tutorial_skipped": false,
	"settings": {"music": 0.8, "sfx": 0.8, "vibration": true, "assist_mode": false,
		"color_patterns": false, "reduced_effects": false, "text_scale": 1.0,
		"high_contrast": false},
	"stats": {"runs_started": 0, "runs_won": 0, "battles_won": 0},
	"active_run": {},
	"legacy_run_compensated": false,
	"early_defeat_streak": 0,
	"unlocked_areas": ["shadow_crypt"],
	"completed_areas": [],
	"selected_area": "shadow_crypt",
	"area_stats": {},
	"mastery": {},
	"area_mastery": {},
	"weekly_records": {},
	"seen_scroll_cues": [],
	"daily": {"last_claim": "", "last_played": "", "best_depth": 0,
		"score": 0, "streak": 0},
	"run_history": [],
	"max_ascension": 0,
	"selected_ascension": 0,
}

## Frequent low-stakes mutations (crystals, stats, settings sliders) mark the
## save dirty and are written once per quiet window instead of once per call.
## Run boundaries and app lifecycle events always flush immediately.
const SAVE_DEBOUNCE_MS := 800

var data: Dictionary = {}
var _dirty := false
var _dirty_since_ms := 0


func _ready() -> void:
	load_save()
	set_process(true)


func _process(_delta: float) -> void:
	if _dirty and Time.get_ticks_msec() - _dirty_since_ms >= SAVE_DEBOUNCE_MS:
		save()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST]:
		if _dirty:
			save()


func request_save() -> void:
	if not _dirty:
		_dirty_since_ms = Time.get_ticks_msec()
	_dirty = true


func load_save() -> void:
	data = DEFAULT_DATA.duplicate(true)
	var parsed := load_from_paths(SAVE_PATH, SAVE_BACKUP_PATH)
	if parsed.is_empty():
		if FileAccess.file_exists(SAVE_PATH):
			push_warning("Save and backup are unreadable, starting fresh.")
		return
	# Merge over defaults so keys missing from older saves keep default values.
	for key in parsed: data[key] = parsed[key]
	for key in DEFAULT_DATA["settings"]:
		if not (data["settings"] as Dictionary).has(key):
			data["settings"][key] = DEFAULT_DATA["settings"][key]
	data["version"] = SAVE_VERSION
	# A valid backup is immediately promoted so the next launch is healthy too.
	if not parse_save_text(_read_text(SAVE_PATH)).is_empty():
		return
	write_atomic(data, SAVE_PATH)


func parse_save_text(text: String) -> Dictionary:
	if text.strip_edges().is_empty(): return {}
	var parser := JSON.new()
	if parser.parse(text) != OK: return {}
	var parsed: Variant = parser.data
	if typeof(parsed) != TYPE_DICTIONARY: return {}
	return migrate(parsed as Dictionary)


func load_from_paths(primary_path: String, backup_path: String) -> Dictionary:
	var primary := parse_save_text(_read_text(primary_path))
	if not primary.is_empty(): return primary
	var backup := parse_save_text(_read_text(backup_path))
	if not backup.is_empty():
		push_warning("Primary save is corrupt; recovered the previous checkpoint.")
	return backup


func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path): return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return ""
	return file.get_as_text()


func migrate(source: Dictionary) -> Dictionary:
	var migrated := source.duplicate(true)
	if int(migrated.get("version", 1)) < 2:
		var legacy_run: Dictionary = migrated.get("active_run", {})
		if bool(legacy_run.get("active", false)) and not bool(migrated.get("legacy_run_compensated", false)):
			migrated["crystals"] = int(migrated.get("crystals", 0)) + 10
			migrated["legacy_run_compensated"] = true
		legacy_run["active"] = false
		migrated["active_run"] = legacy_run
	if int(migrated.get("version", 1)) < 3:
		var was_done := bool(migrated.get("tutorial_done", false))
		migrated["tutorial_state"] = "complete" if was_done else "new"
		migrated["tutorial_step"] = 0
		migrated["tutorial_skipped"] = false
	if int(migrated.get("version", 1)) < 4:
		migrated["unlocked_areas"] = migrated.get("unlocked_areas", ["shadow_crypt"])
		migrated["completed_areas"] = migrated.get("completed_areas", [])
		migrated["selected_area"] = migrated.get("selected_area", "shadow_crypt")
		migrated["area_stats"] = migrated.get("area_stats", {})
	if int(migrated.get("version", 1)) < 5:
		migrated["mastery"] = migrated.get("mastery", {})
		migrated["daily"] = migrated.get("daily", {"last_claim":"", "best_depth":0})
		migrated["run_history"] = migrated.get("run_history", [])
	var daily: Dictionary = migrated.get("daily", {}).duplicate(true)
	for key in DEFAULT_DATA.daily:
		if not daily.has(key): daily[key] = DEFAULT_DATA.daily[key]
	migrated["daily"] = daily
	if int(migrated.get("version", 1)) < 6:
		var migrated_settings: Dictionary = migrated.get("settings", {})
		migrated_settings["color_patterns"] = false
		migrated["settings"] = migrated_settings
	if int(migrated.get("version", 1)) < 7:
		# Preserve prototype/preview Ascension progress when present. New players
		# still receive the safe zero defaults.
		migrated["max_ascension"] = int(migrated.get("max_ascension", 0))
		migrated["selected_ascension"] = int(migrated.get("selected_ascension", 0))
	if int(migrated.get("version", 1)) < 8:
		var unlocked: Array = migrated.get("unlocked_areas", ["shadow_crypt"])
		var completed: Array = migrated.get("completed_areas", [])
		for area_id in GameState.area_ids():
			var area_data := GameState.area(area_id)
			var prerequisite := str(area_data.get("unlock_after", ""))
			if not prerequisite.is_empty() and prerequisite in completed \
					and area_id not in unlocked:
				unlocked.append(area_id)
		migrated["unlocked_areas"] = unlocked
	if int(migrated.get("version", 1)) < 9:
		migrated["area_mastery"] = migrated.get("area_mastery", {})
		migrated["weekly_records"] = migrated.get("weekly_records", {})
		migrated["seen_scroll_cues"] = migrated.get("seen_scroll_cues", [])
	if int(migrated.get("version", 1)) < 10:
		# Existing players go straight to the Hall; only fresh installs see onboarding.
		migrated["onboarding_done"] = bool(migrated.get("tutorial_done", false)) \
				or int(migrated.get("stats", {}).get("runs_started", 0)) > 0
	var history: Array = migrated.get("run_history", [])
	if history.size() > 20: history.resize(20)
	migrated["run_history"] = history
	var settings: Dictionary = migrated.get("settings", {})
	if not settings.has("assist_mode"): settings["assist_mode"] = false
	if not settings.has("color_patterns"): settings["color_patterns"] = false
	if not settings.has("reduced_effects"): settings["reduced_effects"] = false
	if not settings.has("text_scale"): settings["text_scale"] = 1.0
	if not settings.has("high_contrast"): settings["high_contrast"] = false
	settings["text_scale"] = clampf(float(settings["text_scale"]), 0.85, 1.30)
	migrated["settings"] = settings
	migrated["max_ascension"] = clampi(int(migrated.get("max_ascension", 0)), 0, 10)
	migrated["selected_ascension"] = clampi(int(migrated.get("selected_ascension", 0)),
			0, int(migrated["max_ascension"]))
	migrated["version"] = SAVE_VERSION
	return migrated


func save() -> bool:
	_dirty = false
	var succeeded := write_atomic(data, SAVE_PATH)
	if not succeeded:
		push_warning("Could not write save file.")
	return succeeded


func write_atomic(payload: Dictionary, path := SAVE_PATH) -> bool:
	var temp_path: String = path + ".tmp"
	var backup_path: String = path + ".bak"
	var temp := FileAccess.open(temp_path, FileAccess.WRITE)
	if temp == null: return false
	# Compact JSON: pretty-printing roughly doubles write size for zero
	# player value, and this file is rewritten at every checkpoint.
	temp.store_string(JSON.stringify(payload))
	temp.flush()
	temp.close()
	if parse_save_text(_read_text(temp_path)).is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
		return false
	# Never replace the recovery point with corrupt data.
	var previous_text := _read_text(path)
	if not parse_save_text(previous_text).is_empty():
		var backup_temp := FileAccess.open(backup_path + ".tmp", FileAccess.WRITE)
		if backup_temp == null: return false
		backup_temp.store_string(previous_text)
		backup_temp.flush()
		backup_temp.close()
		_replace_file(backup_path + ".tmp", backup_path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path),
			ProjectSettings.globalize_path(path)) == OK


func _replace_file(source: String, destination: String) -> bool:
	if FileAccess.file_exists(destination):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(destination))
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(source),
			ProjectSettings.globalize_path(destination)) == OK


func reset_progress() -> void:
	data = DEFAULT_DATA.duplicate(true)
	save()


# --- Crystals ---------------------------------------------------------------

func crystals() -> int:
	return int(data.get("crystals", 0))


func add_crystals(amount: int) -> void:
	data["crystals"] = crystals() + amount
	request_save()


func spend_crystals(amount: int) -> bool:
	if crystals() < amount:
		return false
	data["crystals"] = crystals() - amount
	request_save()
	return true


# --- Permanent upgrades ------------------------------------------------------

func perma_level(id: String) -> int:
	return int((data.get("perma", {}) as Dictionary).get(id, 0))


func raise_perma_level(id: String) -> void:
	var perma: Dictionary = data.get("perma", {})
	perma[id] = perma_level(id) + 1
	data["perma"] = perma
	request_save()


# --- Settings & flags ---------------------------------------------------------

func setting(key: String) -> Variant:
	return (data.get("settings", {}) as Dictionary).get(
			key, DEFAULT_DATA["settings"].get(key))


func set_setting(key: String, value: Variant) -> void:
	var settings: Dictionary = data.get("settings", {})
	settings[key] = value
	data["settings"] = settings
	request_save()


func is_tutorial_done() -> bool:
	return bool(data.get("tutorial_done", false))


func is_onboarding_done() -> bool:
	return bool(data.get("onboarding_done", false))


func mark_onboarding_done() -> void:
	data["onboarding_done"] = true
	save()


func mark_tutorial_done() -> void:
	complete_tutorial()


func tutorial_step() -> int:
	return int(data.get("tutorial_step", 0))


func set_tutorial_step(step: int) -> void:
	data["tutorial_state"] = "active"
	data["tutorial_step"] = maxi(step, 0)
	request_save()


func complete_tutorial() -> void:
	data["tutorial_done"] = true
	data["tutorial_state"] = "complete"
	data["tutorial_step"] = 0
	data["tutorial_skipped"] = false
	save()


func skip_tutorial() -> void:
	data["tutorial_done"] = true
	data["tutorial_state"] = "skipped"
	data["tutorial_skipped"] = true
	data["tutorial_step"] = 0
	save()


func replay_tutorial() -> void:
	data["tutorial_done"] = false
	data["tutorial_state"] = "active"
	data["tutorial_skipped"] = false
	data["tutorial_step"] = 0
	save()


func bump_stat(stat_name: String, amount := 1) -> void:
	var stats: Dictionary = data.get("stats", {})
	stats[stat_name] = int(stats.get(stat_name, 0)) + amount
	data["stats"] = stats
	request_save()


func save_run_boundary(run_data: Dictionary) -> bool:
	data["active_run"] = run_data.duplicate(true)
	return save()


func clear_active_run() -> void:
	data["active_run"] = {}
	save()


func record_early_defeat(early: bool) -> int:
	data["early_defeat_streak"] = int(data.get("early_defeat_streak", 0)) + 1 if early else 0
	save()
	return int(data.early_defeat_streak)


# --- Campaign progression ---------------------------------------------------

func is_area_unlocked(area_id: String) -> bool:
	return area_id in (data.get("unlocked_areas", ["shadow_crypt"]) as Array)


func selected_area() -> String:
	var candidate := str(data.get("selected_area", "shadow_crypt"))
	return candidate if is_area_unlocked(candidate) else "shadow_crypt"


func set_selected_area(area_id: String) -> bool:
	if not is_area_unlocked(area_id) or GameState.area(area_id).is_empty():
		return false
	data["selected_area"] = area_id
	save()
	return true


func max_ascension() -> int:
	return clampi(int(data.get("max_ascension", 0)), 0, 10)


func selected_ascension() -> int:
	return clampi(int(data.get("selected_ascension", 0)), 0, max_ascension())


func set_selected_ascension(level: int) -> void:
	data["selected_ascension"] = clampi(level, 0, max_ascension())
	save()


func completed_areas() -> Array:
	return (data.get("completed_areas", []) as Array).duplicate()


func area_wins(area_id: String) -> int:
	var all_stats: Dictionary = data.get("area_stats", {})
	return int((all_stats.get(area_id, {}) as Dictionary).get("wins", 0))


func best_depth(area_id: String) -> int:
	var all_stats: Dictionary = data.get("area_stats", {})
	return int((all_stats.get(area_id, {}) as Dictionary).get("best_depth", 0))


func record_area_depth(area_id: String, depth: int) -> void:
	if GameState.area(area_id).is_empty():
		return
	var all_stats: Dictionary = data.get("area_stats", {})
	var stats: Dictionary = (all_stats.get(area_id, {}) as Dictionary).duplicate()
	stats["best_depth"] = maxi(int(stats.get("best_depth", 0)), depth)
	all_stats[area_id] = stats
	data["area_stats"] = all_stats
	request_save()


func complete_area(area_id: String) -> Dictionary:
	var area_data := GameState.area(area_id)
	if area_data.is_empty():
		return {"first_clear": false, "unlocked_area": "", "reward": 0, "campaign_complete": false}
	var completed: Array = data.get("completed_areas", [])
	var first_clear := area_id not in completed
	var reward := 0
	if first_clear:
		completed.append(area_id)
		reward = int(area_data.get("first_clear_reward", 0))
		data["crystals"] = crystals() + reward
	data["completed_areas"] = completed

	var all_stats: Dictionary = data.get("area_stats", {})
	var stats: Dictionary = (all_stats.get(area_id, {}) as Dictionary).duplicate()
	stats["wins"] = int(stats.get("wins", 0)) + 1
	stats["best_depth"] = maxi(int(stats.get("best_depth", 0)),
			int(AREA_GRAMMAR.for_area(area_id).get("run_length", 7)))
	all_stats[area_id] = stats
	data["area_stats"] = all_stats

	var ids := GameState.area_ids()
	var current_index := ids.find(area_id)
	var unlocked_area := ""
	if first_clear and current_index >= 0 and current_index + 1 < ids.size():
		unlocked_area = str(ids[current_index + 1])
		var unlocked: Array = data.get("unlocked_areas", ["shadow_crypt"])
		if unlocked_area not in unlocked:
			unlocked.append(unlocked_area)
		data["unlocked_areas"] = unlocked
		data["selected_area"] = unlocked_area
	save()
	return {
		"first_clear": first_clear,
		"unlocked_area": unlocked_area,
		"reward": reward,
		"campaign_complete": first_clear and current_index == ids.size() - 1,
	}
