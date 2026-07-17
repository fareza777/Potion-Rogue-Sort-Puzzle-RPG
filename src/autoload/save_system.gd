extends Node
## Autoload: SaveSystem
## Persistent local save (crystals, permanent upgrades, settings, stats,
## tutorial flag) in user://save.json. Versioned, with corrupt-file fallback
## so a bad save can never crash the game.

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 2

const DEFAULT_DATA := {
	"version": SAVE_VERSION,
	"crystals": 0,
	"perma": {},
	"tutorial_done": false,
	"settings": {"music": 0.8, "sfx": 0.8, "vibration": true, "assist_mode": false},
	"stats": {"runs_started": 0, "runs_won": 0, "battles_won": 0},
	"active_run": {},
	"legacy_run_compensated": false,
	"early_defeat_streak": 0,
}

var data: Dictionary = {}


func _ready() -> void:
	load_save()


func load_save() -> void:
	data = DEFAULT_DATA.duplicate(true)
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("Save file unreadable, starting fresh.")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Save file corrupt, starting fresh.")
		return
	parsed = migrate(parsed)
	# Merge over defaults so keys missing from older saves keep default values.
	for key in parsed: data[key] = parsed[key]
	for key in DEFAULT_DATA["settings"]:
		if not (data["settings"] as Dictionary).has(key):
			data["settings"][key] = DEFAULT_DATA["settings"][key]
	data["version"] = SAVE_VERSION


func migrate(source: Dictionary) -> Dictionary:
	var migrated := source.duplicate(true)
	if int(migrated.get("version", 1)) < 2:
		var legacy_run: Dictionary = migrated.get("active_run", {})
		if bool(legacy_run.get("active", false)) and not bool(migrated.get("legacy_run_compensated", false)):
			migrated["crystals"] = int(migrated.get("crystals", 0)) + 10
			migrated["legacy_run_compensated"] = true
		legacy_run["active"] = false
		migrated["active_run"] = legacy_run
	var settings: Dictionary = migrated.get("settings", {})
	if not settings.has("assist_mode"): settings["assist_mode"] = false
	migrated["settings"] = settings
	migrated["version"] = SAVE_VERSION
	return migrated


func save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write save file.")
		return
	file.store_string(JSON.stringify(data, "\t"))


func reset_progress() -> void:
	data = DEFAULT_DATA.duplicate(true)
	save()


# --- Crystals ---------------------------------------------------------------

func crystals() -> int:
	return int(data.get("crystals", 0))


func add_crystals(amount: int) -> void:
	data["crystals"] = crystals() + amount
	save()


func spend_crystals(amount: int) -> bool:
	if crystals() < amount:
		return false
	data["crystals"] = crystals() - amount
	save()
	return true


# --- Permanent upgrades ------------------------------------------------------

func perma_level(id: String) -> int:
	return int((data.get("perma", {}) as Dictionary).get(id, 0))


func raise_perma_level(id: String) -> void:
	var perma: Dictionary = data.get("perma", {})
	perma[id] = perma_level(id) + 1
	data["perma"] = perma
	save()


# --- Settings & flags ---------------------------------------------------------

func setting(key: String) -> Variant:
	return (data.get("settings", {}) as Dictionary).get(
			key, DEFAULT_DATA["settings"].get(key))


func set_setting(key: String, value: Variant) -> void:
	var settings: Dictionary = data.get("settings", {})
	settings[key] = value
	data["settings"] = settings
	save()


func is_tutorial_done() -> bool:
	return bool(data.get("tutorial_done", false))


func mark_tutorial_done() -> void:
	data["tutorial_done"] = true
	save()


func bump_stat(stat_name: String, amount := 1) -> void:
	var stats: Dictionary = data.get("stats", {})
	stats[stat_name] = int(stats.get(stat_name, 0)) + amount
	data["stats"] = stats
	save()


func save_run_boundary(run_data: Dictionary) -> void:
	data["active_run"] = run_data.duplicate(true)
	save()


func record_early_defeat(early: bool) -> int:
	data["early_defeat_streak"] = int(data.get("early_defeat_streak", 0)) + 1 if early else 0
	save()
	return int(data.early_defeat_streak)
