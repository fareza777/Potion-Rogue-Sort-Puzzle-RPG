class_name StoryArtCatalog
extends RefCounted
## Resolves authored full-scene story paintings without any network dependency.
## Exact encounter/event mappings win before a realm-and-tier fallback.

const MANIFEST_PATH := "res://data/story_art_manifest.json"

var _manifest: Dictionary = {}


func _init() -> void:
	_manifest = _load_manifest()


func resolve(trigger: String, context: Dictionary) -> Dictionary:
	var area_id := str(context.get("area_id", ""))
	var areas: Dictionary = _manifest.get("areas", {})
	if area_id.is_empty() or not areas.has(area_id):
		return {}
	var area: Dictionary = areas[area_id]
	var scene_key := ""
	match trigger:
		"run_intro":
			scene_key = str(area.get("aftermath", ""))
		"realm_arrival", "route_choice":
			scene_key = str(area.get("arrival", ""))
		"battle_intro", "battle_escalation":
			scene_key = _encounter_scene(area, context)
		"event_reveal", "event_resolution":
			var events: Dictionary = _manifest.get("events", {})
			scene_key = str(events.get(str(context.get("event_id", "")),
					area.get("arrival", "")))
		"battle_victory", "battle_defeat":
			scene_key = str(area.get("aftermath", ""))
		"run_epilogue":
			scene_key = str(area.get("arrival", ""))
		_:
			return {}
	return _scene(scene_key)


func _encounter_scene(area: Dictionary, context: Dictionary) -> String:
	var enemies: Dictionary = _manifest.get("enemies", {})
	var enemy_id := str(context.get("enemy_id", ""))
	if not enemy_id.is_empty() and enemies.has(enemy_id):
		return str(enemies[enemy_id])
	var tier := int(context.get("enemy_tier", 0))
	var kind := str(context.get("kind", "battle"))
	if kind == "boss":
		tier = 4
	elif kind in ["elite", "miniboss"]:
		tier = maxi(tier, 3)
	if tier <= 0:
		var floor := maxi(int(context.get("floor", 1)), 1)
		tier = 3 if floor >= 5 else (2 if floor >= 3 else 1)
	var tiers: Dictionary = area.get("tiers", {})
	return str(tiers.get(str(clampi(tier, 1, 4)), ""))


func _scene(scene_key: String) -> Dictionary:
	if scene_key.is_empty():
		return {}
	var scenes: Dictionary = _manifest.get("scenes", {})
	if not scenes.has(scene_key):
		return {}
	var config: Dictionary = scenes[scene_key]
	var path := str(config.get("path", ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return {}
	return {
		"path":path,
		"scene_key":scene_key,
		"focal_point":config.get("focal_point", [0.5, 0.42]),
	}


func _load_manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
