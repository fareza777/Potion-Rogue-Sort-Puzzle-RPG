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
const DEFAULT_OBJECTIVES := {
	"defeat": {"label": "Defeat the enemy", "event": "enemy_defeated", "target": 1},
}
const DEFAULT_MODIFIERS := {
	"hidden_layer": {"name": "Hidden Layer", "tier": "intro"},
}

var potions: Dictionary = {}
var enemies: Dictionary = {}
var player: Dictionary = {}
var objectives: Dictionary = {}
var modifiers: Dictionary = {}


func _ready() -> void:
	potions = load_data_file("potions.json", DEFAULT_POTIONS)
	enemies = load_data_file("enemies.json", DEFAULT_ENEMIES)
	player = load_data_file("player.json", DEFAULT_PLAYER)
	objectives = load_data_file("objectives.json", DEFAULT_OBJECTIVES)
	modifiers = load_data_file("modifiers.json", DEFAULT_MODIFIERS)


## Loads a JSON dictionary from res://data/ with a fallback on any failure.
## Also used by other autoloads (RunState) for their own data files.
func load_data_file(file_name: String, fallback: Dictionary) -> Dictionary:
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
