extends Node
## Autoload: SaveSystem
## Persistent local save (crystals, stats) in user://save.json.
## Versioned, with corrupt-file fallback so a bad save can never crash the game.

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1

const DEFAULT_DATA := {
	"version": SAVE_VERSION,
	"crystals": 0,
	"stats": {"runs_started": 0, "runs_won": 0, "battles_won": 0},
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
	# Merge over defaults so missing keys (older versions) get default values.
	for key in parsed:
		data[key] = parsed[key]
	data["version"] = SAVE_VERSION


func save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write save file.")
		return
	file.store_string(JSON.stringify(data, "\t"))


func crystals() -> int:
	return int(data.get("crystals", 0))


func add_crystals(amount: int) -> void:
	data["crystals"] = crystals() + amount
	save()


func bump_stat(stat_name: String, amount := 1) -> void:
	var stats: Dictionary = data.get("stats", {})
	stats[stat_name] = int(stats.get(stat_name, 0)) + amount
	data["stats"] = stats
	save()
