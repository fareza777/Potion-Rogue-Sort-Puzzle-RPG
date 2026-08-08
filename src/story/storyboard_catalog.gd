class_name StoryboardCatalog
extends RefCounted
## Read-only adapter around the authored offline story grammar.

const PATH := "res://data/storyboards.json"
var data: Dictionary = {}


func _init() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(parsed) == TYPE_DICTIONARY:
		data = (parsed as Dictionary).duplicate(true)


func trigger(trigger_id: String) -> Dictionary:
	return (data.get("triggers", {}) as Dictionary).get(trigger_id, {}).duplicate(true)


func area(area_id: String) -> Dictionary:
	var areas: Dictionary = data.get("areas", {})
	return areas.get(area_id, areas.get("shadow_crypt", {})).duplicate(true)


func kit(kit_id: String) -> Dictionary:
	var kits: Dictionary = data.get("kits", {})
	return kits.get(kit_id, kits.get("ember_adept", {})).duplicate(true)


func layouts() -> Array[String]:
	var result: Array[String] = []
	for value in data.get("layouts", []):
		result.append(str(value))
	return result
