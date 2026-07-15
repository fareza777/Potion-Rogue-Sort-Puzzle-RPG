extends Node
## Autoload: GameState
## Loads all data definitions (potions, enemies, player) from res://data/*.json
## with hardcoded fallbacks so a missing/corrupt data file can never crash the game.
## Later phases will add: run state, crystals, permanent upgrades, save/load.

const DATA_DIR := "res://data/"

# Fallback defaults mirror the JSON files in res://data/.
const DEFAULT_POTIONS := {
	"red": {"name": "Fire Potion", "damage": 20},
	"green": {"name": "Healing Potion", "heal": 15},
	"blue": {"name": "Shield Potion", "shield": 12},
	"purple": {"name": "Poison Potion", "poison_damage": 5, "poison_turns": 3},
}
const DEFAULT_ENEMIES := {
	"slime": {"name": "Cave Slime", "hp": 60, "attack": 8, "attack_every": 3, "color": "6fce4e"},
}
const DEFAULT_PLAYER := {"max_hp": 50, "max_shield": 30, "undos_per_battle": 3}

var potions: Dictionary = {}
var enemies: Dictionary = {}
var player: Dictionary = {}


func _ready() -> void:
	potions = _load_json("potions.json", DEFAULT_POTIONS)
	enemies = _load_json("enemies.json", DEFAULT_ENEMIES)
	player = _load_json("player.json", DEFAULT_PLAYER)


func _load_json(file_name: String, fallback: Dictionary) -> Dictionary:
	var path := DATA_DIR + file_name
	if not FileAccess.file_exists(path):
		push_warning("Data file missing, using defaults: " + path)
		return fallback.duplicate(true)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Could not open data file, using defaults: " + path)
		return fallback.duplicate(true)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Invalid JSON, using defaults: " + path)
		return fallback.duplicate(true)
	return parsed
