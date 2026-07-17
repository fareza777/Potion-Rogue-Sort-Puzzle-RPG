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
const DEFAULT_INTENTS := {
	"attack": {"label": "Attack", "icon": "attack",
		"actions": [{"type": "attack", "multiplier": 1.0}]},
}
const DEFAULT_COMBOS := {
	"fire_burst": {"pattern": ["red", "red"],
		"effect": "damage_multiplier", "value": 1.5, "charge": 20},
}
const DEFAULT_AREAS := {
	"shadow_crypt": {"id":"shadow_crypt", "order":0, "name":"Shadow Crypt",
		"boss":"fire_golem", "background":"res://assets/art/backgrounds/shadow_crypt_battle.png",
		"threat_multiplier":1.0, "enemy_pools":{"intro":["slime"], "tier_1":["slime"],
		"tier_2":["slime"], "tier_3":["slime"], "elite":["slime"]}},
}

var potions: Dictionary = {}
var enemies: Dictionary = {}
var player: Dictionary = {}
var objectives: Dictionary = {}
var modifiers: Dictionary = {}
var intents: Dictionary = {}
var combos: Dictionary = {}
var kits: Dictionary = {}
var areas: Dictionary = {}


func _ready() -> void:
	potions = load_data_file("potions.json", DEFAULT_POTIONS)
	enemies = load_data_file("enemies.json", DEFAULT_ENEMIES)
	player = load_data_file("player.json", DEFAULT_PLAYER)
	objectives = load_data_file("objectives.json", DEFAULT_OBJECTIVES)
	modifiers = load_data_file("modifiers.json", DEFAULT_MODIFIERS)
	intents = load_data_file("intents.json", DEFAULT_INTENTS)
	combos = load_data_file("combos.json", DEFAULT_COMBOS)
	kits = load_data_file("kits.json", {"ember_adept":{"active":"flash_boil","cost":50}})
	areas = load_data_file("areas.json", DEFAULT_AREAS)


func area(id: String) -> Dictionary:
	return areas.get(id, areas.get("shadow_crypt", DEFAULT_AREAS.shadow_crypt)).duplicate(true)


func area_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in areas: ids.append(str(id))
	ids.sort_custom(func(a: String, b: String) -> bool:
		return int(areas[a].get("order", 99)) < int(areas[b].get("order", 99)))
	return ids


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
